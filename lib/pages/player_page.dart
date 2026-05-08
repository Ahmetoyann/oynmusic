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
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:muzik_app/pages/artist_detail_page.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  static void show(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false, // Arka planın görünmesini sağlar
        pageBuilder: (_, __, ___) => const PlayerPage(),
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

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final ScrollController _scrollController = ScrollController();

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

    return Dismissible(
      key: const Key('player_page_dismiss'),
      direction: DismissDirection.down,
      onDismissed: (_) => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Arka planı şeffaf yapıyoruz
        extendBodyBehindAppBar: true, // AppBar'ın arkasına içerik taşsın
        appBar: AppBar(
          backgroundColor: Colors.transparent,
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
            // 1. ve 2. KATMAN: Video Arka Planı VEYA Fallback Resim Katmanı
            _VideoBackgroundLayer(song: currentSong),

            // 3. KATMAN: İçerik (Spotify tarzı kaydırılabilir ekran ve alt bölüm)
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
                                // Ekran yüksekliğine göre kapağı dinamik küçülterek overflow (taşma) hatasını önlüyoruz
                                size: math.min(
                                  screenWidth * 0.84,
                                  MediaQuery.of(context).size.height * 0.4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // İndirme ve Paylaş Butonları
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const SizedBox(
                                width: 48,
                              ), // İndirme butonunu tam ortalamak için sol tarafa eklenen görünmez dengeleyici
                              _buildDownloadButton(
                                context,
                                songProvider,
                                currentSong,
                              ),
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
                          const Spacer(), // Alanı eşit dağıtmak için varsayılan esnekliğe alındı
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
                              AnimatedSwitcher(
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
                                        inactiveTrackColor: Colors.white
                                            .withOpacity(0.3),
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
                              ClipRRect(
                                borderRadius: BorderRadius.circular(37.5),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 15,
                                    sigmaY: 15,
                                  ),
                                  child: Container(
                                    width: 75,
                                    height: 75,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 15,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: _buildAudioPlayPauseButton(
                                      songProvider,
                                    ),
                                  ),
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
                                        color:
                                            songProvider.loopMode ==
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
                                      MediaQuery.of(context).size.height,
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
                                          langProvider.t('they_will_play_next'),
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
                                        _showSleepTimerDialog(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const CustomBannerAd(),
                        ],
                      ),
                    ),
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
                                  ? Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.15)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCurrent
                                    ? Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.4)
                                    : Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      (song.localImagePath != null &&
                                              File(
                                                song.localImagePath!,
                                              ).existsSync())
                                          ? Transform.scale(
                                              scale:
                                                  (song.coverUrl.contains(
                                                        'ytimg.com',
                                                      ) ||
                                                      song.coverUrl.contains(
                                                        'youtube.com',
                                                      ))
                                                  ? 1.35
                                                  : 1.0,
                                              child: Image.file(
                                                File(song.localImagePath!),
                                                fit: BoxFit.cover,
                                                cacheHeight: 200,
                                              ),
                                            )
                                          : Transform.scale(
                                              scale:
                                                  (song.coverUrl.contains(
                                                        'ytimg.com',
                                                      ) ||
                                                      song.coverUrl.contains(
                                                        'youtube.com',
                                                      ))
                                                  ? 1.35
                                                  : 1.0,
                                              child: CachedNetworkImage(
                                                imageUrl: song.coverUrl,
                                                fit: BoxFit.cover,
                                                memCacheHeight: 200,
                                                errorWidget:
                                                    (
                                                      context,
                                                      url,
                                                      error,
                                                    ) => Container(
                                                      color:
                                                          Colors.grey.shade800,
                                                      child:
                                                          CustomIcons.svgIcon(
                                                            CustomIcons
                                                                .musicNote,
                                                            color:
                                                                Colors.white54,
                                                            size: 24,
                                                          ),
                                                    ),
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
                                  fontSize: 15,
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
                                  fontSize: 13,
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
    final shareText =
        '${song.title} - ${song.artist}\n\n'
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
    CustomBottomSheet.showContent(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          Text(
            langProvider.t('add_to_playlist'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          if (songProvider.folders.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                langProvider.t('no_lists'),
                style: const TextStyle(color: Colors.grey),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: songProvider.folders.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final folder = songProvider.folders[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CustomIcons.svgIcon(
                        CustomIcons.folderOpenRounded,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      ),
                      title: Text(
                        folder.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${folder.songs.length} ${langProvider.t('song')}',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                      onTap: () {
                        songProvider.addSongsToFolder(folder, [song]);
                        Navigator.pop(context);
                        CustomSnackBar.showSuccess(
                          context: context,
                          message: 'Şarkı ${folder.name} listesine eklendi.',
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 32),
        ],
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(12),
        child: Transform.scale(
          scale:
              (song.coverUrl.contains('ytimg.com') ||
                  song.coverUrl.contains('youtube.com'))
              ? 1.35
              : 1.0,
          child:
              (song.localImagePath != null &&
                  File(song.localImagePath!).existsSync())
              ? Image.file(
                  File(song.localImagePath!),
                  width: size,
                  height: size,
                  cacheHeight: 600,
                  fit: BoxFit.cover,
                )
              : CachedNetworkImage(
                  imageUrl: song.coverUrl,
                  width: size,
                  height: size,
                  memCacheHeight: 600,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) =>
                      Container(color: Colors.grey.shade800),
                ),
        ),
      ),
    );
  }
}

/// YouTube müziklerinin 30 saniyelik klip önizlemesini arka planda (Canvas gibi) oynatır
class _VideoBackgroundLayer extends StatefulWidget {
  final Song song;
  const _VideoBackgroundLayer({Key? key, required this.song}) : super(key: key);

  @override
  State<_VideoBackgroundLayer> createState() => _VideoBackgroundLayerState();
}

class _VideoBackgroundLayerState extends State<_VideoBackgroundLayer> {
  VideoPlayerController? _controller;
  bool _hasVideo = false;
  final _yt = YoutubeExplode();

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didUpdateWidget(covariant _VideoBackgroundLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _disposeController();
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    final currentId = widget.song.id;
    setState(() {
      _hasVideo = false;
    });

    // Eğer başka bir platformdan geliyorsa (Audius vs) işlem yapma
    if (widget.song.audioUrl.contains('audius.co')) return;

    try {
      final manifest = await _yt.videos.streamsClient.getManifest(
        widget.song.id,
      );

      if (!mounted || widget.song.id != currentId) return;

      VideoStreamInfo? streamInfo;
      final videoOnlyStreams = manifest.videoOnly
          .where((s) => s.container.name.toString().toLowerCase() == 'mp4')
          .toList();

      if (videoOnlyStreams.isNotEmpty) {
        videoOnlyStreams.sort(
          (a, b) => a.size.totalBytes.compareTo(b.size.totalBytes),
        );
        streamInfo = videoOnlyStreams.first;
      } else {
        final muxedStreams = manifest.muxed
            .where((s) => s.container.name.toString().toLowerCase() == 'mp4')
            .toList();
        if (muxedStreams.isNotEmpty) {
          muxedStreams.sort(
            (a, b) => a.size.totalBytes.compareTo(b.size.totalBytes),
          );
          streamInfo = muxedStreams.first;
        }
      }

      if (streamInfo != null) {
        _controller = VideoPlayerController.networkUrl(
          streamInfo.url,
          httpHeaders: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            'Referer': 'https://www.youtube.com/',
          },
        );
        await _controller!.initialize();
        if (!mounted || widget.song.id != currentId) {
          _disposeController();
          return;
        }
        await _controller!.setVolume(
          0.0,
        ); // Şarkı already just_audio üzerinden çalındığı için bu 0 olmalı
        await _controller!.play(); // Beklemeden hemen başlat

        _controller!.addListener(() {
          if (!mounted ||
              _controller == null ||
              !_controller!.value.isInitialized)
            return;

          // 30 saniyelik klip limiti kontrolü ve otomatik başa sarması
          if (_controller!.value.position.inSeconds >= 30) {
            _controller!.seekTo(Duration.zero);
          } else if (_controller!.value.position >=
              _controller!.value.duration) {
            _controller!.seekTo(Duration.zero);
            _controller!.play();
          }
        });

        if (mounted) {
          setState(() {
            _hasVideo = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Arka plan video hatası: $e");
    }
  }

  void _disposeController() {
    if (_controller != null) {
      _controller!.pause();
      _controller!.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _disposeController();
    _yt.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Klipli Video Arka Planı
    if (_hasVideo && _controller != null && _controller!.value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),
          // UI okunabilir kalsın diye sadece siyah bir karartma filtresi (Blur değil)
          Container(color: Colors.black.withOpacity(0.6)),
        ],
      );
    }

    // Video yüklenene kadar veya video yoksa Klasik Fallback (Resim + Blur)
    return Stack(
      fit: StackFit.expand,
      children: [
        (widget.song.localImagePath != null &&
                File(widget.song.localImagePath!).existsSync())
            ? Image.file(
                File(widget.song.localImagePath!),
                fit: BoxFit.cover,
                cacheHeight: 800,
                errorBuilder: (ctx, err, stack) =>
                    Container(color: const Color(0xFF121212)),
              )
            : CachedNetworkImage(
                imageUrl: widget.song.coverUrl,
                fit: BoxFit.cover,
                memCacheHeight: 800,
                errorWidget: (context, url, error) =>
                    Container(color: const Color(0xFF121212)),
              ),
        RepaintBoundary(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40.0, sigmaY: 40.0),
            child: Container(color: Colors.black.withOpacity(0.75)),
          ),
        ),
      ],
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

void _showSleepTimerDialog(BuildContext context) {
  final langProvider = context.read<LanguageProvider>();

  CustomBottomSheet.showContent(
    context: context,
    child: Consumer<SongProvider>(
      builder: (consumerContext, provider, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomIcons.svgIcon(
                  CustomIcons.timerRounded,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  langProvider.t('sleep_timer'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (provider.isSleepTimerActive &&
                provider.sleepTimerEndTime != null) ...[
              const SizedBox(height: 8),
              Text(
                "Kapanış: ${provider.sleepTimerEndTime!.hour.toString().padLeft(2, '0')}:${provider.sleepTimerEndTime!.minute.toString().padLeft(2, '0')}",
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
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
            ),
            const SizedBox(height: 24),
            if (provider.isSleepTimerActive)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      provider.cancelSleepTimer();
                      Navigator.pop(context);
                      CustomSnackBar.showInfo(
                        context: context,
                        message: 'Zamanlayıcı kapatıldı.',
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      langProvider.t('cancel'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 24),
          ],
        );
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
        width: (MediaQuery.of(context).size.width - 64) / 3,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
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
  Song song,
) {
  final primaryColor = Theme.of(context).primaryColor;
  final langProvider = context.read<LanguageProvider>();
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
        // İndiriliyor & Duraklatıldı Durumu
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
            const SizedBox(width: 12),
            Text(
              isPaused
                  ? langProvider.t('paused')
                  : langProvider.t('downloading'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
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
        // İndirildi Durumu
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
            const SizedBox(width: 8),
            Text(
              langProvider.t('downloaded'),
              style: const TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
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
        // Varsayılan İndir Durumu
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
            const SizedBox(width: 8),
            Text(
              langProvider.t('download'), // "İndir" anlamında kullanıyoruz
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        );
        onTap = () {
          if (!provider.isFirebaseLoggedIn) {
            _showLoginBottomSheet(context);
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

      return ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: borderColor.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
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
          ),
        ),
      );
    },
  );
}
