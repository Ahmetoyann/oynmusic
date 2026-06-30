import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:muzik_app/pages/login_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:muzik_app/widgets/custom_app_bar.dart';
import 'package:muzik_app/widgets/song_card.dart';
import 'package:muzik_app/widgets/custom_banner_ad.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:muzik_app/providers/language_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:muzik_app/widgets/device_cover_placeholder.dart';
import 'package:muzik_app/pages/artist_detail_page.dart';
import 'package:muzik_app/widgets/mini_player.dart';
import 'package:muzik_app/services/custom_winning_add.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  static void show(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (pageContext, animation, secondaryAnimation) => Container(
          color: Theme.of(pageContext).scaffoldBackgroundColor,
          child: const PlayerPage(),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOut;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  static void showModernMenu(BuildContext context, Song song) {
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    final bool isDeviceSong =
        song.localPath != null && song.audioUrl == song.localPath;

    CustomBottomSheet.showContent(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          ListTile(
            leading: CustomIcons.svgIcon(
              CustomIcons.playlistPlay,
              color: Colors.white,
              size: 24,
            ),
            title: Text(
              langProvider.t('add_to_playlist'),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            onTap: () {
              Navigator.pop(context);
              _showAddToPlaylistSheetStatic(
                context,
                song,
                songProvider,
                langProvider,
              );
            },
          ),
          if (!isDeviceSong)
            ListTile(
              leading: CustomIcons.svgIcon(
                CustomIcons.person,
                color: Colors.white,
                size: 24,
              ),
              title: Text(
                langProvider.t('go_to_artist'),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ArtistDetailPage(
                      artistName: song.artist,
                      songs: [song],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static void _showAddToPlaylistSheetStatic(
    BuildContext context,
    Song song,
    SongProvider songProvider,
    LanguageProvider langProvider,
  ) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (pageContext, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Theme.of(pageContext).scaffoldBackgroundColor,
            body: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 32),
                        onPressed: () => Navigator.pop(pageContext),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(Icons.playlist_add_check_circle_rounded,
                      size: 64, color: Theme.of(context).primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    langProvider.t('add_to_playlist'),
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (songProvider.folders.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          langProvider.t('no_playlists'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: songProvider.folders.length,
                        itemBuilder: (context, index) {
                          final folder = songProvider.folders[index];
                          final isAlreadyAdded =
                              folder.songs.any((s) => s.id == song.id);
                          return ListTile(
                            title: Text(
                              folder.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                            trailing: isAlreadyAdded
                                ? const Icon(Icons.check, color: Colors.green)
                                : null,
                            onTap: isAlreadyAdded
                                ? null
                                : () {
                                    songProvider.addSongsToFolder(
                                      folder,
                                      [song],
                                    );
                                    Navigator.pop(pageContext);
                                    CustomSnackBar.showSuccess(
                                      context: context,
                                      message: langProvider.t('song_added'),
                                    );
                                  },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final ScrollController _scrollController = ScrollController();
  Color? _dominantColor;
  String? _currentSongId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentSong = context.watch<SongProvider>().currentSong;
    if (currentSong != null && currentSong.id != _currentSongId) {
      _currentSongId = currentSong.id;
      _loadDominantColor(currentSong);
    }
  }

  Future<void> _loadDominantColor(Song song) async {
    final color = await MiniPlayer.getDominantColor(song);
    if (mounted && _currentSongId == song.id) {
      setState(() {
        _dominantColor = color;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = context.watch<SongProvider>();
    final currentSong = songProvider.currentSong;
    final primaryColor = Theme.of(context).primaryColor;
    final screenWidth = MediaQuery.of(context).size.width;
    final langProvider = context.watch<LanguageProvider>();

    // Eğer şarkı seçili değilse boş ekran dön
    if (currentSong == null) {
      return Scaffold(body: Center(child: Text(langProvider.t('error'))));
    }

    // Cihaz şarkılarında audioUrl ve localPath aynıdır (ikisi de yerel dosya yoludur)
    final bool isDeviceSong = currentSong.localPath != null &&
        currentSong.audioUrl == currentSong.localPath;

    return Dismissible(
      key: const Key('player_page_dismiss'),
      direction: DismissDirection.down,
      onDismissed: (_) => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        extendBodyBehindAppBar: true, // AppBar'ın arkasına içerik taşsın
        appBar: AppBar(
          backgroundColor:
              Colors.white.withOpacity(0.0001), // Düz hafif beyaz şeffaflık
          scrolledUnderElevation: 0, // Material 3 kaydırma efektini kapatır
          surfaceTintColor:
              Colors.transparent, // Primary rengin sızmasını engeller
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: CustomIcons.svgIcon(
              CustomIcons.keyboardArrowDownRounded,
              size: 28,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                langProvider.t('song_playing_title').toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                currentSong.artist,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: CustomIcons.svgIcon(
                CustomIcons.menuRounded,
                size: 24,
                color: Colors.white,
              ),
              tooltip: langProvider.t('options'),
              onPressed: () {
                _showPlayerMenu(
                  context,
                  currentSong,
                  songProvider,
                  langProvider,
                );
              },
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Şarkının Baskın Rengine Göre Arka Plan (Renk Geçişi)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (_dominantColor ?? primaryColor).withOpacity(0.35),
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
            CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ANA OYNATICI ALANI (Ekran boyutu kadar yer kaplar)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top:
                            MediaQuery.of(context).padding.top + kToolbarHeight,
                        bottom: MediaQuery.of(context).padding.bottom + 12,
                        left: screenWidth * 0.025,
                        right: screenWidth * 0.025,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(),

                          // Büyük Kapak Resmi (Işıltılı Çerçeve ile)
                          Center(
                            child: RepaintBoundary(
                              child: _GlowingAlbumCover(
                                song: currentSong,
                                provider: songProvider,
                                // Ekran genişliğinin %90'ı kadar genişlik (Yükseklik 16:9 oranına göre içeride hesaplanacak)
                                size: screenWidth * 0.9,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // İndirme ve Paylaş Butonları (Aynı Hizada)
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (!isDeviceSong) ...[
                                _buildDownloadButton(
                                    context, songProvider, currentSong,
                                    isMp4: false),
                                _buildDownloadButton(
                                    context, songProvider, currentSong,
                                    isMp4: true),
                              ],
                              IconButton(
                                icon: Icon(
                                  Icons.ios_share,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 24,
                                ),
                                onPressed: () => _shareSong(currentSong),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Şarkı Başlığı ve Sanatçı
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                child: TextScroll(
                                  currentSong.title,
                                  key: ValueKey('${currentSong.id}_title'),
                                  mode: TextScrollMode.bouncing,
                                  velocity: const Velocity(
                                    pixelsPerSecond: Offset(30, 0),
                                  ),
                                  delayBefore: const Duration(seconds: 2),
                                  pauseBetween: const Duration(seconds: 2),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: (screenWidth * 0.045).clamp(
                                      16.0,
                                      22.0,
                                    ),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: isDeviceSong
                                    ? null
                                    : () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ArtistDetailPage(
                                              artistName: currentSong.artist,
                                              songs: [currentSong],
                                            ),
                                          ),
                                        );
                                      },
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 400),
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeIn,
                                  child: TextScroll(
                                    currentSong.artist,
                                    key: ValueKey('${currentSong.id}_artist'),
                                    mode: TextScrollMode.bouncing,
                                    velocity: const Velocity(
                                      pixelsPerSecond: Offset(30, 0),
                                    ),
                                    delayBefore: const Duration(seconds: 2),
                                    pauseBetween: const Duration(seconds: 2),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: (screenWidth * 0.035).clamp(
                                        11.0,
                                        15.0,
                                      ),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 12),
                          // İlerleme Çubuğu (Slider)
                          RepaintBoundary(
                            child: StreamBuilder<Duration>(
                              stream: songProvider.positionStream,
                              builder: (context, snapshot) {
                                final position = songProvider.isSongLoading
                                    ? Duration.zero
                                    : (snapshot.data ?? Duration.zero);
                                final duration = songProvider.isSongLoading
                                    ? Duration.zero
                                    : (songProvider.audioPlayer.duration ??
                                        Duration.zero);
                                final maxDuration =
                                    duration.inSeconds.toDouble() > 0
                                        ? duration.inSeconds.toDouble()
                                        : 1.0;

                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                          overlayRadius: 14,
                                        ),
                                        thumbColor: Colors.white,
                                        trackHeight: 4,
                                        activeTrackColor: Colors.white,
                                        inactiveTrackColor:
                                            Colors.white.withOpacity(0.3),
                                      ),
                                      child: Slider(
                                        value: position.inSeconds
                                            .toDouble()
                                            .clamp(0.0, maxDuration),
                                        min: 0,
                                        max: maxDuration,
                                        onChanged: (value) {
                                          songProvider.audioPlayer.seek(
                                            Duration(seconds: value.toInt()),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatDuration(position),
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.7,
                                            ),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          _formatDuration(duration),
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.7,
                                            ),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Kontrol Butonları
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                decoration: BoxDecoration(
                                  color: songProvider.isShuffleEnabled
                                      ? primaryColor.withOpacity(0.15)
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.shuffle_rounded,
                                        size: 24,
                                        color: songProvider.isShuffleEnabled
                                            ? primaryColor
                                            : Colors.white.withOpacity(0.6),
                                      ),
                                      if (songProvider.isShuffleEnabled)
                                        Container(
                                          margin: const EdgeInsets.only(top: 2),
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: primaryColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  onPressed: songProvider.toggleShuffle,
                                ),
                              ),
                              IconButton(
                                icon: CustomIcons.svgIcon(
                                  CustomIcons.skipPreviousRounded,
                                  color: Colors.white,
                                  size: 45,
                                ),
                                onPressed: () => songProvider.playPrevious(),
                              ),
                              Container(
                                width: 75,
                                height: 75,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    width: 1.5,
                                  ),
                                ),
                                child: _buildAudioPlayPauseButton(
                                  songProvider,
                                ),
                              ),
                              IconButton(
                                icon: CustomIcons.svgIcon(
                                  CustomIcons.skipNextRounded,
                                  color: Colors.white,
                                  size: 45,
                                ),
                                onPressed: () => songProvider.playNext(),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                decoration: BoxDecoration(
                                  color: songProvider.loopMode != LoopMode.off
                                      ? primaryColor.withOpacity(0.15)
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CustomIcons.svgIcon(
                                        songProvider.loopMode == LoopMode.one
                                            ? CustomIcons.repeatOneRounded
                                            : CustomIcons.repeatRounded,
                                        size: 24,
                                        color: songProvider.loopMode ==
                                                LoopMode.off
                                            ? Colors.white.withOpacity(0.6)
                                            : primaryColor,
                                      ),
                                      if (songProvider.loopMode != LoopMode.off)
                                        Container(
                                          margin: const EdgeInsets.only(top: 2),
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: primaryColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  onPressed: songProvider.cycleLoopMode,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Alt İkonlar (Favori, Sıradaki Şarkılar ve Uyku Zamanlayıcısı)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: IconButton(
                                    icon: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      transitionBuilder: (child, animation) =>
                                          ScaleTransition(
                                        scale: animation,
                                        child: child,
                                      ),
                                      child: Icon(
                                        currentSong.isFavorite
                                            ? Icons.check_circle_rounded
                                            : Icons.add_circle_outline_rounded,
                                        key: ValueKey<bool>(
                                          currentSong.isFavorite,
                                        ),
                                        color: currentSong.isFavorite
                                            ? Colors.greenAccent
                                            : Colors.white.withOpacity(0.7),
                                        size: 28,
                                      ),
                                    ),
                                    onPressed: () => songProvider
                                        .toggleFavorite(currentSong),
                                  ),
                                ),
                              ),

                              // Ortadaki Sıradaki Şarkılar Göstergesi
                              Expanded(
                                flex: 2,
                                child: GestureDetector(
                                  onTap: () {
                                    _scrollController.animateTo(
                                      // Kaydırdığında AppBar'ın hemen altına (şarkı sözleri alanına) tam oturtur
                                      MediaQuery.of(context).size.height -
                                          (MediaQuery.of(context).padding.top +
                                              kToolbarHeight),
                                      duration: const Duration(
                                        milliseconds: 500,
                                      ),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal:
                                              8, // Ekranı rahatlatmak için padding biraz kısıldı
                                          vertical: 6,
                                        ),
                                        child: Text(
                                          isDeviceSong
                                              ? langProvider
                                                  .t('they_will_play_next')
                                              : langProvider
                                                  .t('lyrics_and_up_next'),
                                          maxLines:
                                              1, // Tek satırda kalmasını zorunlu kılar
                                          overflow: TextOverflow
                                              .ellipsis, // Sığmazsa sonuna ... koyar
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.8,
                                            ),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: _PulsingTimerIcon(
                                    isActive: songProvider.isSleepTimerActive,
                                    activeColor: primaryColor,
                                    inactiveColor: Colors.white.withOpacity(
                                      0.7,
                                    ),
                                    tooltip: langProvider.t('sleep_timer'),
                                    onPressed: () =>
                                        _showSleepTimerFullScreen(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Reklamlar geçici olarak kapatıldığı için gizlendi. Daha sonra açmak isterseniz alttaki satırın yorumunu kaldırabilirsiniz.
                          // const CustomBannerAd(),
                        ],
                      ),
                    ),
                  ),
                ),

                // ŞARKI SÖZLERİ BÖLÜMÜ
                if (!isDeviceSong)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        screenWidth * 0.025,
                        0,
                        screenWidth * 0.025,
                        16,
                      ),
                      child: _LyricsBlock(song: currentSong),
                    ),
                  ),

                // SIRADAKİ ŞARKILAR (QUEUE) BÖLÜMÜ
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      screenWidth * 0.025,
                      24,
                      screenWidth * 0.025,
                      16,
                    ),
                    child: Text(
                      langProvider.t('they_will_play_next'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.025,
                  ),
                  sliver: SliverReorderableList(
                    itemCount: songProvider.playlist.length,
                    onReorder: (oldIndex, newIndex) {
                      songProvider.reorderPlaylist(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final song = songProvider.playlist[index];
                      final isCurrent = song.id == songProvider.currentSong?.id;

                      return Padding(
                        key: ValueKey(song.id),
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.2)
                                  : Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isCurrent
                                    ? Theme.of(context)
                                        .primaryColor
                                        .withOpacity(0.5)
                                    : Colors.white.withOpacity(0.05),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  width: 71, // 16:9 Oranı için genişletildi
                                  height: 40,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: <Widget>[
                                      if (song.localImagePath != null &&
                                          File(song.localImagePath!)
                                              .existsSync())
                                        Image.file(
                                          File(song.localImagePath!),
                                          fit: BoxFit.cover,
                                          cacheHeight: 200,
                                        )
                                      else if (song.coverUrl.isEmpty)
                                        DeviceCoverPlaceholder(
                                          width: 71,
                                          height: 40,
                                          borderRadius: 6,
                                          logoColor:
                                              Theme.of(context).primaryColor,
                                        )
                                      else
                                        CachedNetworkImage(
                                          imageUrl: song.coverUrl,
                                          fit: BoxFit.cover,
                                          memCacheHeight: 200,
                                          errorWidget: (
                                            context,
                                            url,
                                            error,
                                          ) =>
                                              DeviceCoverPlaceholder(
                                            width: 71,
                                            height: 40,
                                            borderRadius: 6,
                                            logoColor:
                                                Theme.of(context).primaryColor,
                                          ),
                                        ),
                                      if (isCurrent)
                                        Container(
                                          color: Colors.black.withOpacity(0.6),
                                          child: Center(
                                            child: CustomIcons.svgIcon(
                                              CustomIcons.graphicEq,
                                              color: Theme.of(
                                                context,
                                              ).primaryColor,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              title: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isCurrent
                                      ? Theme.of(context).primaryColor
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isCurrent
                                      ? Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.7)
                                      : Colors.grey.shade400,
                                  fontSize: 11,
                                ),
                              ),
                              trailing: ReorderableDragStartListener(
                                index: index,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: CustomIcons.svgIcon(
                                    CustomIcons.dragHandleRounded,
                                    color: Colors.grey.shade500,
                                    size: 24,
                                  ),
                                ),
                              ),
                              onTap: () {
                                if (!isCurrent) {
                                  songProvider.playSong(
                                    song,
                                    songProvider.playlist,
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // En alt kısma ekstra kaydırma payı
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareSong(Song song) async {
    final shareText = '${song.title} - ${song.artist}\n\n'
        'OYN Müzik\'te dinle: https://play.google.com/store/apps/details?id=com.ahmed.oyn_music';

    try {
      String? imagePath;

      // 1. Şarkı indirilmişse veya kapak resmi zaten yerelde varsa onu kullan
      if (song.localImagePath != null &&
          File(song.localImagePath!).existsSync()) {
        imagePath = song.localImagePath!;
      } else if (song.coverUrl.isNotEmpty) {
        // 2. Yoksa kapak resmini hızlıca geçici klasöre indir
        final tempDir = await getTemporaryDirectory();
        imagePath = '${tempDir.path}/share_${song.id}.jpg';
        final file = File(imagePath);

        if (!file.existsSync()) {
          final dio = Dio();
          await dio.download(song.coverUrl, imagePath);
        }
      }

      // 3. Resim hazırsa resim + metin olarak paylaş (WhatsApp vb. bunu harika gösterir)
      if (imagePath != null && File(imagePath).existsSync()) {
        await Share.shareXFiles([XFile(imagePath)], text: shareText);
      } else {
        await Share.share(shareText); // Resim bulunamazsa sadece metin paylaş
      }
    } catch (e) {
      debugPrint("Paylaşım hatası: $e");
      await Share.share(
        shareText,
      ); // Herhangi bir hata olursa uygulamanın çökmemesi için metinle devam et
    }
  }

  void _showPlayerMenu(
    BuildContext context,
    Song currentSong,
    SongProvider songProvider,
    LanguageProvider langProvider,
  ) {
    final bool isDeviceSong = currentSong.localPath != null &&
        currentSong.audioUrl == currentSong.localPath;

    CustomBottomSheet.showContent(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          ListTile(
            leading: CustomIcons.svgIcon(
              CustomIcons.playlistPlay,
              color: Colors.white,
              size: 24,
            ),
            title: Text(
              langProvider.t('add_to_playlist'),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            onTap: () {
              Navigator.pop(context);
              _showAddToPlaylistSheet(
                context,
                currentSong,
                songProvider,
                langProvider,
              );
            },
          ),
          if (!isDeviceSong)
            ListTile(
              leading: CustomIcons.svgIcon(
                CustomIcons.person,
                color: Colors.white,
                size: 24,
              ),
              title: Text(
                langProvider.t('go_to_artist'),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ArtistDetailPage(
                      artistName: currentSong.artist,
                      songs: [currentSong],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showAddToPlaylistSheet(
    BuildContext context,
    Song song,
    SongProvider songProvider,
    LanguageProvider langProvider,
  ) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (pageContext, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Theme.of(pageContext).scaffoldBackgroundColor,
            body: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 32),
                        onPressed: () => Navigator.pop(pageContext),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(Icons.playlist_add_check_circle_rounded,
                      size: 64, color: Theme.of(context).primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    langProvider.t('add_to_playlist'),
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (songProvider.folders.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CustomIcons.svgIcon(
                              CustomIcons.folderOpenRounded,
                              size: 48,
                              color: Colors.grey.shade800,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              langProvider.t('no_lists'),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        itemCount: songProvider.folders.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final folder = songProvider.folders[index];

                          Widget coverWidget;
                          if (folder.customImagePath != null &&
                              File(folder.customImagePath!).existsSync()) {
                            coverWidget = Image.file(
                              File(folder.customImagePath!),
                              fit: BoxFit.cover,
                            );
                          } else if (folder.songs.isNotEmpty) {
                            final firstSong = folder.songs.first;
                            if (firstSong.localImagePath != null &&
                                File(firstSong.localImagePath!).existsSync()) {
                              coverWidget = Image.file(
                                File(firstSong.localImagePath!),
                                fit: BoxFit.cover,
                              );
                            } else {
                              coverWidget = CachedNetworkImage(
                                imageUrl: firstSong.coverUrl,
                                fit: BoxFit.cover,
                                errorWidget: (c, e, s) => Container(
                                  color: Colors.grey.shade800,
                                  child: CustomIcons.svgIcon(
                                    CustomIcons.musicNote,
                                    color: Colors.white54,
                                    size: 24,
                                  ),
                                ),
                              );
                            }
                          } else {
                            coverWidget = Container(
                              color: Colors.grey.shade800,
                              child: folder.isFromDownloads
                                  ? CustomIcons.svgIcon(
                                      CustomIcons.downloadingRounded,
                                      color: Colors.white70,
                                      size: 24,
                                    )
                                  : CustomIcons.svgIcon(
                                      CustomIcons.musicNoteRounded,
                                      color: Colors.white70,
                                      size: 24,
                                    ),
                            );
                          }

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.1)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(8),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 71,
                                  height: 40,
                                  child: coverWidget,
                                ),
                              ),
                              title: Text(
                                folder.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                '${folder.songs.length} ${langProvider.t('song')}',
                                style: TextStyle(
                                    color: Colors.grey.shade400, fontSize: 13),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: CustomIcons.svgIcon(
                                  CustomIcons.arrowForwardIosRounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                              onTap: () {
                                if (folder.songs.any((s) => s.id == song.id)) {
                                  Navigator.pop(pageContext);
                                  CustomSnackBar.showInfo(
                                    context: context,
                                    message:
                                        'Bu şarkı zaten ${folder.name} listesinde var.',
                                  );
                                } else {
                                  songProvider.addSongsToFolder(folder, [song]);
                                  Navigator.pop(pageContext);
                                  CustomSnackBar.showSuccess(
                                    context: context,
                                    message:
                                        'Şarkı ${folder.name} listesine eklendi.',
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
              position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  /// Oynatma durumuna göre ikonları ve eylemi yöneten genel bir widget.
  Widget _buildPlayPauseIcon({
    required bool isPlaying,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: isPlaying
          ? CustomIcons.svgIcon(
              CustomIcons.pauseRounded,
              color: Colors.white,
              size: 45,
            )
          : CustomIcons.svgIcon(
              CustomIcons.playArrowRounded,
              color: Colors.white,
              size: 45,
            ),
      onPressed: onPressed,
    );
  }
}

/// Arka plan ses oynatıcısı (just_audio) için Oynat/Duraklat butonu oluşturan widget.
Widget _buildAudioPlayPauseButton(SongProvider songProvider) {
  // Şarkı bağlantısı çözülüyorsa veya reklam bekleniyorsa (motor henüz başlamadıysa)
  // direkt olarak yükleme (indikatör) animasyonunu gösteriyoruz.
  if (songProvider.isSongLoading) {
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }

  return StreamBuilder<PlayerState>(
    stream: songProvider.playerStateStream,
    builder: (context, snapshot) {
      final playerState = snapshot.data;
      final processingState = playerState?.processingState;
      final playing = playerState?.playing ?? false;

      if (processingState == ProcessingState.loading ||
          processingState == ProcessingState.buffering) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }

      return _buildPlayPauseIcon(
        isPlaying: playing,
        onPressed: () {
          if (playing) {
            songProvider.audioPlayer.pause();
          } else {
            songProvider.audioPlayer.play();
          }
        },
        context: context,
      );
    },
  );
}

/// Şarkı sözlerini (Lyrics) ekranda kaydırılabilir modern bir blok içerisinde gösteren widget.
class _LyricsBlock extends StatefulWidget {
  final Song song;

  const _LyricsBlock({Key? key, required this.song}) : super(key: key);

  @override
  State<_LyricsBlock> createState() => _LyricsBlockState();
}

class _LyricsBlockState extends State<_LyricsBlock> {
  @override
  void initState() {
    super.initState();
    _fetchLyricsIfNeeded();
  }

  @override
  void didUpdateWidget(_LyricsBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _fetchLyricsIfNeeded();
    }
  }

  void _fetchLyricsIfNeeded() {
    if (widget.song.lyrics == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<SongProvider>().fetchLyrics(widget.song);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = context.watch<LanguageProvider>();
    final provider = context.watch<SongProvider>();
    final currentSong = provider.currentSong?.id == widget.song.id
        ? provider.currentSong!
        : widget.song;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                langProvider.t('lyrics'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (currentSong.lyrics == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else if (currentSong.lyrics!.isEmpty)
            Text(
              langProvider.t('lyrics_not_found'),
              style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 350),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  currentSong.lyrics!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 2.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Şarkı çalarken kapak resminin etrafında dönen ışık efekti oluşturan widget.
class _GlowingAlbumCover extends StatelessWidget {
  final Song song;
  final SongProvider provider;
  final double size;

  const _GlowingAlbumCover({
    super.key,
    required this.song,
    required this.provider,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    bool isYoutube = song.coverUrl.contains('ytimg.com') ||
        song.coverUrl.contains('youtube.com');
    // YouTube görsellerini orijinal dikdörtgen formatında (16:9) göstermek için yüksekliği hesaplıyoruz.
    double height = isYoutube ? (size * 9 / 16) : size;

    // Oynatıcı sayfasında en yüksek çözünürlüğü (1080p/MaxRes) çekmek için URL'i değiştiriyoruz
    String highResUrl = song.coverUrl;
    if (isYoutube) {
      highResUrl = highResUrl
          .replaceAll('mqdefault.jpg', 'maxresdefault.jpg')
          .replaceAll('hqdefault.jpg', 'maxresdefault.jpg')
          .replaceAll('sddefault.jpg', 'maxresdefault.jpg')
          .replaceAll('default.jpg', 'maxresdefault.jpg');
    } else if (highResUrl.contains('audius.co')) {
      highResUrl = highResUrl
          .replaceAll('150x150', '1000x1000')
          .replaceAll('480x480', '1000x1000');
    }

    return Container(
      width: size,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        // Orijinal formatta göstermek için kırpan Transform.scale'i kaldırıyoruz
        child: (song.localImagePath != null &&
                File(song.localImagePath!).existsSync())
            ? Image.file(
                File(song.localImagePath!),
                width: size,
                height: height,
                fit: BoxFit.cover,
              )
            : (highResUrl.isEmpty
                ? DeviceCoverPlaceholder(
                    width: size,
                    height: height,
                    borderRadius: 6,
                    logoColor: Theme.of(context).primaryColor,
                  )
                : CachedNetworkImage(
                    imageUrl: highResUrl,
                    width: size,
                    height: height,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) {
                      return CachedNetworkImage(
                        imageUrl: song.coverUrl,
                        width: size,
                        height: height,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            DeviceCoverPlaceholder(
                          width: size,
                          height: height,
                          borderRadius: 6,
                          logoColor: Theme.of(context).primaryColor,
                        ),
                      );
                    },
                  )),
      ),
    );
  }
}

/// Oynatma durumuna göre ikonları ve eylemi yöneten genel bir widget.
Widget _buildPlayPauseIcon({
  required bool isPlaying,
  required VoidCallback onPressed,
  required BuildContext context,
}) {
  return IconButton(
    icon: isPlaying
        ? CustomIcons.svgIcon(
            CustomIcons.pauseRounded,
            color: Colors.white,
            size: 45,
          )
        : CustomIcons.svgIcon(
            CustomIcons.playArrowRounded,
            color: Colors.white,
            size: 45,
          ),
    onPressed: onPressed,
  );
}

void _showSleepTimerFullScreen(BuildContext context) {
  final langProvider = context.read<LanguageProvider>();

  Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (pageContext, animation, secondaryAnimation) {
        return Scaffold(
          backgroundColor: Theme.of(pageContext).scaffoldBackgroundColor,
          body: SafeArea(
            child: Consumer<SongProvider>(
              builder: (context, provider, child) {
                final primaryColor = Theme.of(context).primaryColor;
                return Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 32),
                          onPressed: () => Navigator.pop(pageContext),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(Icons.timer_rounded, size: 64, color: primaryColor),
                    const SizedBox(height: 16),
                    Text(
                      langProvider.t('sleep_timer'),
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (provider.isSleepTimerActive &&
                        provider.sleepTimerEndTime != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        "Kapanış: ${provider.sleepTimerEndTime!.hour.toString().padLeft(2, '0')}:${provider.sleepTimerEndTime!.minute.toString().padLeft(2, '0')}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            alignment: WrapAlignment.center,
                            children: [
                              _buildModernTimerOption(context, 15),
                              _buildModernTimerOption(context, 30),
                              _buildModernTimerOption(context, 45),
                              _buildModernTimerOption(context, 60),
                              _buildModernTimerOption(context, 90),
                              _buildModernTimerOption(context, 120),
                            ],
                          ),
                          const SizedBox(height: 40),
                          if (provider.isSleepTimerActive)
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: InkWell(
                                    onTap: () {
                                      provider.cancelSleepTimer();
                                      Navigator.pop(pageContext);
                                      CustomSnackBar.showInfo(
                                        context: context,
                                        message: 'Zamanlayıcı kapatıldı.',
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.redAccent.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color:
                                              Colors.redAccent.withOpacity(0.5),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          langProvider.t('cancel'),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;
        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    ),
  );
}

/// Uyku zamanlayıcısı aktifken ikonun etrafında yayılan hafif nabız (pulse) efekti
class _PulsingTimerIcon extends StatefulWidget {
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onPressed;
  final String tooltip;

  const _PulsingTimerIcon({
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  State<_PulsingTimerIcon> createState() => _PulsingTimerIconState();
}

class _PulsingTimerIconState extends State<_PulsingTimerIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        seconds: 2,
      ), // Animasyonun hızı (ne kadar sürede bir dalga yayılacak)
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = Tween<double>(
      begin: 0.5,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.isActive) _controller.repeat();
  }

  @override
  void didUpdateWidget(_PulsingTimerIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.tooltip,
      onPressed: widget.onPressed,
      icon: Stack(
        alignment: Alignment.center,
        children: [
          // Sadece aktifken arkadaki dalgayı oluşturur
          if (widget.isActive)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.activeColor.withOpacity(0.5),
                      ),
                    ),
                  ),
                );
              },
            ),
          // Ana İkon
          CustomIcons.svgIcon(
            CustomIcons.timerRounded,
            size: 24,
            color: widget.isActive ? widget.activeColor : widget.inactiveColor,
          ),
        ],
      ),
    );
  }
}

Widget _buildModernTimerOption(BuildContext context, int minutes) {
  final langProvider = context.read<LanguageProvider>();

  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () {
        context.read<SongProvider>().setSleepTimer(minutes);
        Navigator.pop(context);
        CustomSnackBar.showInfo(
          context: context,
          message: 'Müzik $minutes dakika sonra duracak.',
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: (MediaQuery.of(context).size.width - 80) / 3,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(
              "$minutes",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              langProvider.t('duration').substring(0, 2), // Kisaltma icin
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
  return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds"
      .replaceFirst("00:", "");
}

void _showLoginBottomSheet(BuildContext context) {
  CustomBottomSheet.show(
    context: context,
    title: "İndirmek için Giriş Yapın",
    message:
        "Şarkıları cihazınıza indirmek ve çevrimdışı dinlemek için lütfen giriş yapın.",
    icon: CustomIcons.svgIcon(
      CustomIcons.downloadingRounded,
      size: 60,
      color: Colors.white70,
    ),
    primaryButtonText: "Giriş Yap",
    primaryButtonColor: Colors.white,
    primaryButtonTextColor: Colors.black,
    secondaryButtonText: "İptal",
    onPrimaryButtonTap: () {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    },
  );
}

Widget _buildDownloadButton(
  BuildContext context,
  SongProvider provider,
  Song song, {
  bool isMp4 = false,
}) {
  final primaryColor = Theme.of(context).primaryColor;

  if (isMp4) {
    return ValueListenableBuilder<double?>(
      valueListenable: provider.getVideoDownloadProgressNotifier(song.id),
      builder: (context, progress, child) {
        final isDownloading = progress != null && progress < 1.0;
        final isDownloaded = progress != null && progress >= 1.0;

        Widget content;
        VoidCallback? onTap;
        Color borderColor;
        Color bgColor;

        if (isDownloading) {
          borderColor = primaryColor.withOpacity(0.8);
          bgColor = primaryColor.withOpacity(0.2);
          content = Row(
            key: const ValueKey('downloading_mp4'),
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  value: progress == 0.0 ? null : progress,
                  strokeWidth: 2.5,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "Video",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          );
          onTap = () {};
        } else if (isDownloaded) {
          borderColor = Colors.greenAccent.withOpacity(0.5);
          bgColor = Colors.greenAccent.withOpacity(0.1);
          content = Row(
            key: const ValueKey('downloaded_mp4'),
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomIcons.svgIcon(
                CustomIcons.check,
                color: Colors.greenAccent,
                size: 20,
              ),
              const SizedBox(width: 6),
              const Text(
                "Video",
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          );
          onTap = () {
            CustomSnackBar.showInfo(
              context: context,
              message: "Video İndirilenler klasörüne kaydedildi.",
            );
          };
        } else {
          borderColor = Colors.white.withOpacity(0.2);
          bgColor = Colors.black.withOpacity(0.4);
          content = Row(
            key: const ValueKey('download_mp4'),
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomIcons.svgIcon(
                CustomIcons.downloadingRounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 6),
              const Text(
                "Video",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.14),
                  ),
                ),
                child: Row(
                  children: const [
                    Text(
                      '3',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.monetization_on_rounded,
                      color: Colors.amber,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          );
          onTap = () {
            if (!provider.isFirebaseLoggedIn) {
              _showLoginBottomSheet(context);
              return;
            }
            if (!provider.canAfford(3)) {
              CustomSnackBar.showError(
                  context: context,
                  message:
                      "Yetersiz jeton! Lütfen reklam izleyerek jeton kazanın.");
              CustomWinningAd.showCoinScreen(context);
              return;
            }
            if (provider.askVideoQuality) {
              SongCard.showVideoQualityFullScreen(context, song, provider);
            } else {
              provider.downloadVideoToDevice(song);
            }
          };
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(30),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: content,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // MP3 Butonu Mantığı
  final isDownloaded = provider.isSongDownloaded(song.id);
  final isPaused = provider.isPaused(song.id);

  return ValueListenableBuilder<double?>(
    valueListenable: provider.getDownloadProgressNotifier(song.id),
    builder: (context, progress, child) {
      final bool isDownloading = provider.downloadProgress.containsKey(song.id);
      Widget content;
      VoidCallback? onTap;
      Color borderColor;
      Color bgColor;

      if (isDownloading) {
        borderColor = primaryColor.withOpacity(0.8);
        bgColor = primaryColor.withOpacity(0.2);
        content = Row(
          key: const ValueKey('downloading'),
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: isPaused
                  ? CustomIcons.svgIcon(
                      CustomIcons.pauseRounded,
                      color: primaryColor,
                      size: 20,
                    )
                  : CircularProgressIndicator(
                      value: progress == 0.0 && !isPaused ? null : progress,
                      strokeWidth: 2.5,
                      color: primaryColor,
                    ),
            ),
            const SizedBox(width: 8),
            const Text(
              "Müzik",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        );
        onTap = () {
          if (isPaused) {
            provider.downloadSong(song);
          } else {
            provider.pauseDownload(song);
          }
        };
      } else if (isDownloaded) {
        borderColor = Colors.greenAccent.withOpacity(0.5);
        bgColor = Colors.greenAccent.withOpacity(0.1);
        content = Row(
          key: const ValueKey('downloaded'),
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomIcons.svgIcon(
              CustomIcons.check,
              color: Colors.greenAccent,
              size: 20,
            ),
            const SizedBox(width: 6),
            const Text(
              "Müzik",
              style: TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        );
        onTap = () {
          CustomSnackBar.showInfo(
            context: context,
            message: "Bu şarkı zaten cihazınızda bulunuyor.",
          );
        };
      } else {
        borderColor = Colors.white.withOpacity(0.2);
        bgColor = Colors.black.withOpacity(0.4);
        content = Row(
          key: const ValueKey('download'),
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomIcons.svgIcon(
              CustomIcons.downloadingRounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 6),
            const Text(
              "Müzik",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.14),
                ),
              ),
              child: Row(
                children: const [
                  Text(
                    '2',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.monetization_on_rounded,
                    color: Colors.amber,
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        );
        onTap = () {
          if (!provider.isFirebaseLoggedIn) {
            _showLoginBottomSheet(context);
            return;
          }
          if (!provider.canAfford(2)) {
            CustomSnackBar.showError(
                context: context,
                message:
                    "Yetersiz jeton! Lütfen reklam izleyerek jeton kazanın.");
            CustomWinningAd.showCoinScreen(context);
            return;
          }

          provider.downloadSong(song).catchError((e) {
            if (context.mounted) {
              CustomSnackBar.showError(
                context: context,
                message: "İndirme başarısız: $e",
              );
            }
          });
        };
      }

      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(30),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 14,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: content,
              ),
            ),
          ),
        ),
      );
    },
  );
}
