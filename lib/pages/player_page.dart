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
        appBar: CustomAppBar(
          title: '',
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: CustomIcons.svgIcon(
              CustomIcons.keyboardArrowDownRounded,
              size: 28,
            ),
            onPressed: () => Navigator.pop(context),
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
                SongCard.showModernMenu(
                  context,
                  currentSong,
                  onTap: () {
                    if (songProvider.audioPlayer.playing) {
                      songProvider.audioPlayer.pause();
                    } else {
                      songProvider.audioPlayer.play();
                    }
                  },
                );
              },
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. KATMAN: Arka Plan Resmi
            (currentSong.localImagePath != null &&
                    File(currentSong.localImagePath!).existsSync())
                ? Image.file(
                    File(currentSong.localImagePath!),
                    fit: BoxFit.cover,
                    cacheHeight: 800,
                    errorBuilder: (ctx, err, stack) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.grey.shade800,
                            const Color(0xFF121212),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: currentSong.coverUrl,
                    fit: BoxFit.cover,
                    memCacheHeight: 800,
                    errorWidget: (context, url, error) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.grey.shade800,
                            const Color(0xFF121212),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),

            // 2. KATMAN: Sabit Siyah Bulanıklık Efekti
            RepaintBoundary(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40.0, sigmaY: 40.0),
                child: Container(
                  color: Colors.black.withOpacity(
                    0.75,
                  ), // Koyu ve sabit bir arka plan sağlar
                ),
              ),
            ),

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
                        left: 24.0,
                        right: 24.0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(flex: 2),

                          // Şarkı yüklenirken kapak resminin üstünde gösterilecek animasyon
                          AnimatedOpacity(
                            opacity: songProvider.isSongLoading ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: const Center(child: _AnimatedLoadingText()),
                          ),
                          const SizedBox(height: 16),

                          // Büyük Kapak Resmi (Işıltılı Çerçeve ile)
                          Center(
                            child: RepaintBoundary(
                              child: _GlowingAlbumCover(
                                song: currentSong,
                                provider: songProvider,
                                size: screenWidth * 0.85,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
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
                          const Spacer(),

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
                                    fontSize: (screenWidth * 0.06).clamp(
                                      20.0,
                                      30.0,
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
                                    fontSize: (screenWidth * 0.045).clamp(
                                      14.0,
                                      22.0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

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

                                return Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _formatDuration(position),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          thumbShape:
                                              SliderComponentShape.noThumb,
                                          overlayShape:
                                              SliderComponentShape.noOverlay,
                                          trackHeight: 4,
                                          activeTrackColor: primaryColor,
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
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _formatDuration(duration),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),

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
                                  icon: CustomIcons.svgIcon(
                                    CustomIcons.shuffleRounded,
                                    size: 24,
                                    color: songProvider.isShuffleEnabled
                                        ? primaryColor
                                        : Colors.white.withOpacity(0.6),
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
                                    sigmaX: 10,
                                    sigmaY: 10,
                                  ),
                                  child: Container(
                                    width: 75,
                                    height: 75,
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: primaryColor.withOpacity(0.5),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryColor.withOpacity(0.2),
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
                                  icon: CustomIcons.svgIcon(
                                    songProvider.loopMode == LoopMode.one
                                        ? CustomIcons.repeatOneRounded
                                        : CustomIcons.repeatRounded,
                                    size: 24,
                                    color: songProvider.loopMode == LoopMode.off
                                        ? Colors.white.withOpacity(0.6)
                                        : primaryColor,
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
                                    icon: CustomIcons.svgIcon(
                                      currentSong.isFavorite
                                          ? CustomIcons.favoriteRounded
                                          : CustomIcons.favoriteBorder,
                                      color: currentSong.isFavorite
                                          ? primaryColor
                                          : Colors.white.withOpacity(0.7),
                                      size: 28,
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
                                          langProvider.t('play_next'),
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
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Text(
                      langProvider.t('play_next'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
class _GlowingAlbumCover extends StatefulWidget {
  final Song song;
  final SongProvider provider;
  final double size;

  const _GlowingAlbumCover({
    required this.song,
    required this.provider,
    required this.size,
  });

  @override
  State<_GlowingAlbumCover> createState() => _GlowingAlbumCoverState();
}

class _GlowingAlbumCoverState extends State<_GlowingAlbumCover>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // Işığın 1 tam turu atma süresi
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return StreamBuilder<PlayerState>(
      stream: widget.provider.playerStateStream,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;

        if (playing && !_controller.isAnimating) {
          _controller.repeat();
        } else if (!playing && _controller.isAnimating) {
          _controller.stop();
        }

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              width: widget.size,
              height: widget.size,
              padding: playing ? const EdgeInsets.all(3) : EdgeInsets.zero,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(playing ? 23 : 20),
                gradient: playing
                    ? SweepGradient(
                        colors: [
                          Colors.transparent,
                          primaryColor.withOpacity(0.2),
                          primaryColor,
                          primaryColor.withOpacity(0.2),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
                        transform: GradientRotation(
                          _controller.value * 2 * math.pi,
                        ),
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: playing
                        ? primaryColor.withOpacity(
                            0.3,
                          ) // Çalarken dışa doğru yayılmış neon gölge
                        : Colors.black.withOpacity(
                            0.5,
                          ), // Duraklatıldığında normal gölge
                    blurRadius: playing ? 40 : 30,
                    spreadRadius: playing ? 5 : 0,
                    offset: playing ? Offset.zero : const Offset(0, 15),
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(
                0xFF121212,
              ), // Çerçevenin altından arka planın sızmasını engeller
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Transform.scale(
                scale:
                    (widget.song.coverUrl.contains('ytimg.com') ||
                        widget.song.coverUrl.contains('youtube.com'))
                    ? 1.35
                    : 1.0,
                child:
                    (widget.song.localImagePath != null &&
                        File(widget.song.localImagePath!).existsSync())
                    ? Image.file(
                        File(widget.song.localImagePath!),
                        width: widget.size,
                        height: widget.size,
                        cacheHeight: 600,
                        fit: BoxFit.cover,
                      )
                    : CachedNetworkImage(
                        imageUrl: widget.song.coverUrl,
                        width: widget.size,
                        height: widget.size,
                        memCacheHeight: 600,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            Container(color: Colors.grey.shade800),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Şarkı yüklenirken üç noktanın yanıp sönmesini (animasyonlu) sağlayan widget
class _AnimatedLoadingText extends StatefulWidget {
  const _AnimatedLoadingText();

  @override
  State<_AnimatedLoadingText> createState() => _AnimatedLoadingTextState();
}

class _AnimatedLoadingTextState extends State<_AnimatedLoadingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  int _currentIndex = 0;
  Timer? _timer;
  final List<String> _loadingTexts = [
    "Şarkı hazırlanıyor...",
    "Bağlantı kuruluyor...",
    "Kalite ayarlanıyor...",
    "Oynatılıyor...",
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _timer = Timer.periodic(const Duration(milliseconds: 3000), (timer) {
      if (mounted) {
        if (_currentIndex < _loadingTexts.length - 1) {
          setState(() {
            _currentIndex++;
          });
        } else {
          timer.cancel(); // Son metne ulaştığında dur
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: primaryColor.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                ),
                const SizedBox(width: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.4),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                  child: Text(
                    _loadingTexts[_currentIndex],
                    key: ValueKey<String>(_loadingTexts[_currentIndex]),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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

void _showSleepTimerDialog(BuildContext context) {
  final langProvider = context.read<LanguageProvider>();

  CustomBottomSheet.showContent(
    context: context,
    child: Consumer<SongProvider>(
      builder: (context, provider, child) {
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
