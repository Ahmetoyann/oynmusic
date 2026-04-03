import 'dart:ui';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:muzik_app/pages/login_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:muzik_app/widgets/custom_app_bar.dart';
import 'package:muzik_app/widgets/custom_drop_down.dart';
import 'package:muzik_app/widgets/custom_banner_ad.dart';
import 'package:text_scroll/text_scroll.dart';

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

class _PlayerPageState extends State<PlayerPage>
    with SingleTickerProviderStateMixin {
  Color? _dominantColor;
  String? _currentSongId;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _extractColor(Song song) async {
    try {
      ImageProvider imageProvider;
      if (song.localImagePath != null &&
          File(song.localImagePath!).existsSync()) {
        imageProvider = FileImage(File(song.localImagePath!));
      } else {
        imageProvider = NetworkImage(song.coverUrl);
      }

      final generator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(100, 100), // Performans için küçük boyut
        maximumColorCount: 20,
      );
      if (mounted) {
        setState(() {
          _dominantColor =
              generator.dominantColor?.color ??
              generator.darkVibrantColor?.color ??
              generator.vibrantColor?.color;
        });
      }
    } catch (e) {
      debugPrint("Renk çekme hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = context.watch<SongProvider>();
    final currentSong = songProvider.currentSong;
    final primaryColor = Theme.of(context).primaryColor;
    final screenWidth = MediaQuery.of(context).size.width;

    // Eğer şarkı seçili değilse boş ekran dön
    if (currentSong == null) {
      return const Scaffold(body: Center(child: Text("Şarkı seçilmedi")));
    }

    // Şarkı değiştiyse rengi güncelle
    if (_currentSongId != currentSong.id) {
      _currentSongId = currentSong.id;
      _dominantColor = null; // Yüklenirken varsayılan rengi kullan (siyah)
      _extractColor(currentSong);
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
            icon: CustomIcons.svgIcon(CustomIcons.keyboardArrowDown, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: CustomIcons.svgIcon(
                currentSong.isFavorite
                    ? CustomIcons.favorite
                    : CustomIcons.favoriteBorder,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
              onPressed: () => songProvider.toggleFavorite(currentSong),
            ),
            CustomDropDown<int>(
              icon: const Icon(Icons.menu, size: 24),
              tooltip: "Seçenekler",
              onSelected: (value) {
                if (value == 0) {
                  _showSleepTimerDialog(context);
                } else if (value == 1) {
                  _showQueueBottomSheet(context, songProvider);
                } else if (value == 2) {
                  _shareSong(currentSong);
                }
              },
              items: [
                CustomDropdownItem.build<int>(
                  context: context,
                  value: 0,
                  icon: CustomIcons.svgIcon(
                    songProvider.isSleepTimerActive
                        ? CustomIcons.moreTime
                        : CustomIcons.moreTimeOutlined,
                    size: 20,
                    color: Theme.of(context).primaryColor,
                  ),
                  text: "Uyku Zamanlayıcısı",
                  textColor: songProvider.isSleepTimerActive
                      ? Theme.of(context).primaryColor
                      : Colors.white,
                ),
                CustomDropdownItem.build<int>(
                  context: context,
                  value: 1,
                  icon: CustomIcons.svgIcon(
                    CustomIcons.tableRows,
                    size: 20,
                    color: Theme.of(context).primaryColor,
                  ),
                  text: "Sıradaki Şarkılar",
                ),
                CustomDropdownItem.build<int>(
                  context: context,
                  value: 2,
                  icon: CustomIcons.svgIcon(
                    CustomIcons.iosShareOutlined,
                    size: 20,
                    color: Theme.of(context).primaryColor,
                  ),
                  text: "Paylaş",
                ),
              ],
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
                : Image.network(
                    currentSong.coverUrl,
                    fit: BoxFit.cover,
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
                  ),

            // 2. KATMAN: Bulanıklık Efekti (Glassmorphism) ve Su Dalgası Animasyonu
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                // Su dalgası (sıvı titreşimi) hissi vermek için X ve Y eksenindeki bulanıklık miktarını
                // animasyon süresince yavaşça ve sürekli olarak (asimetrik şekilde) değiştiriyoruz.
                final sigmaX =
                    25.0 +
                    10.0 * math.sin(_animationController.value * math.pi);
                final sigmaY =
                    25.0 +
                    10.0 * math.cos(_animationController.value * math.pi);

                return BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.lerp(
                          Alignment.topLeft,
                          Alignment.topRight,
                          _animationController.value,
                        )!,
                        end: Alignment.lerp(
                          Alignment.bottomRight,
                          Alignment.bottomLeft,
                          _animationController.value,
                        )!,
                        colors: [
                          (_dominantColor ?? primaryColor).withOpacity(0.6),
                          const Color(0xFF121212).withOpacity(0.9),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // 3. KATMAN: İçerik
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
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

                    // Büyük Kapak Resmi
                    Center(
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.85,
                        height:
                            MediaQuery.of(context).size.width *
                            0.85, // Kare görünüm için yüksekliği genişlikle aynı yapıyoruz
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                          color: Colors
                              .transparent, // Resim gelene kadar gri arka plan görünmesin
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Transform.scale(
                            // YouTube resimlerindeki gömülü siyah şeritleri kırpmak için %35 zoom yapıyoruz.
                            scale:
                                (currentSong.coverUrl.contains('ytimg.com') ||
                                    currentSong.coverUrl.contains(
                                      'youtube.com',
                                    ))
                                ? 1.35
                                : 1.0,
                            child:
                                (currentSong.localImagePath != null &&
                                    File(
                                      currentSong.localImagePath!,
                                    ).existsSync())
                                ? Image.file(
                                    File(currentSong.localImagePath!),
                                    width:
                                        MediaQuery.of(context).size.width *
                                        0.85,
                                    height:
                                        MediaQuery.of(context).size.width *
                                        0.85,
                                    fit: BoxFit.cover,
                                  )
                                : Image.network(
                                    currentSong.coverUrl,
                                    width:
                                        MediaQuery.of(context).size.width *
                                        0.85,
                                    height:
                                        MediaQuery.of(context).size.width *
                                        0.85,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // İndirme Butonu (Ortalanmış ve Kapak Resminin Altında)
                    Center(
                      child: _buildDownloadButton(
                        context,
                        songProvider,
                        currentSong,
                      ),
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
                              fontSize: (screenWidth * 0.06).clamp(20.0, 30.0),
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
                              fontSize: (screenWidth * 0.045).clamp(14.0, 22.0),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // İlerleme Çubuğu (Slider)
                    StreamBuilder<Duration>(
                      stream: songProvider.positionStream,
                      builder: (context, snapshot) {
                        // Şarkı yüklenirken ilerleme çubuğunu ve süreyi zorla 00:00'da tutuyoruz
                        final position = songProvider.isSongLoading
                            ? Duration.zero
                            : (snapshot.data ?? Duration.zero);
                        final duration = songProvider.isSongLoading
                            ? Duration.zero
                            : (songProvider.audioPlayer.duration ??
                                  Duration.zero);
                        final maxDuration = duration.inSeconds.toDouble() > 0
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
                                  thumbShape: SliderComponentShape.noThumb,
                                  overlayShape: SliderComponentShape.noOverlay,
                                  trackHeight: 4,
                                  activeTrackColor: primaryColor,
                                  inactiveTrackColor: Colors.white.withOpacity(
                                    0.3,
                                  ),
                                ),
                                child: Slider(
                                  value: position.inSeconds.toDouble().clamp(
                                    0.0,
                                    maxDuration,
                                  ),
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
                              CustomIcons.shuffle,
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
                            CustomIcons.playerPrev,
                            color: Colors.white,
                            size: 45,
                          ),
                          onPressed: () => songProvider.playPrevious(),
                        ),
                        Container(
                          width: 75,
                          height: 75,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: _buildAudioPlayPauseButton(songProvider),
                        ),
                        IconButton(
                          icon: CustomIcons.svgIcon(
                            CustomIcons.playerNext,
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
                                  ? CustomIcons.repeatOne
                                  : CustomIcons.repeat,
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
                    const SizedBox(height: 20),
                    const CustomBannerAd(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
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
              CustomIcons.playerPlay,
              color: Colors.white,
              size: 40,
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
      );
    },
  );
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
  }

  @override
  void dispose() {
    _controller.dispose();
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
                const Text(
                  "Şarkı Hazırlanıyor...",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
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
}) {
  return IconButton(
    icon: isPlaying
        ? CustomIcons.svgIcon(
            CustomIcons.pauseRounded,
            color: Colors.white,
            size: 45,
          )
        : CustomIcons.svgIcon(
            CustomIcons.playerPlay,
            color: Colors.white,
            size: 40,
          ),
    onPressed: onPressed,
  );
}

void _showSleepTimerDialog(BuildContext context) {
  CustomBottomSheet.showContent(
    context: context,
    child: Consumer<SongProvider>(
      builder: (context, provider, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomIcons.svgIcon(
                  CustomIcons.timerOutlined,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Uyku Zamanlayıcısı',
                  style: TextStyle(
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
                    child: const Text(
                      "Zamanlayıcıyı Kapat",
                      style: TextStyle(fontWeight: FontWeight.bold),
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

Widget _buildModernTimerOption(BuildContext context, int minutes) {
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
            const Text(
              "dk",
              style: TextStyle(
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

void _showQueueBottomSheet(BuildContext context, SongProvider songProvider) {
  CustomBottomSheet.showContent(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    child: DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        // Listeyi o anki şarkıya kaydırmak için
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients &&
              songProvider.currentSongIndex != null) {
            final offset = songProvider.currentSongIndex! * 72.0;
            // Çok uzun listelerde hata vermemesi için clamp
            if (offset < scrollController.position.maxScrollExtent) {
              scrollController.jumpTo(offset);
            }
          }
        });

        return Container(
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Tutamaç Çubuğu
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Sıradaki Şarkılar",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ReorderableListView.builder(
                  scrollController: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  buildDefaultDragHandles:
                      false, // Uzun basarak sürüklemeyi kapatıp ikonla sürükleteceğiz
                  onReorder: (oldIndex, newIndex) {
                    songProvider.reorderPlaylist(oldIndex, newIndex);
                  },
                  itemCount: songProvider.playlist.length,
                  itemBuilder: (context, index) {
                    final song = songProvider.playlist[index];
                    final isCurrent = song.id == songProvider.currentSong?.id;

                    return Padding(
                      key: ValueKey(song.id),
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? Theme.of(context).primaryColor.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isCurrent
                              ? Border.all(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.3),
                                )
                              : null,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
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
                                          child: Image.network(
                                            song.coverUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) =>
                                                Container(
                                                  color: Colors.grey.shade800,
                                                  child: CustomIcons.svgIcon(
                                                    CustomIcons.musicNote,
                                                    color: Colors.white54,
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
                                          color: Theme.of(context).primaryColor,
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
                              child: Icon(
                                Icons.drag_handle_rounded,
                                color: Colors.grey.shade600,
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
                              Navigator.pop(context); // Listeyi kapat
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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
    icon: const Icon(Icons.downloading, size: 60, color: Colors.white70),
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
  final isDownloaded = provider.isSongDownloaded(song.id);
  final progress = provider.downloadProgress[song.id];
  final isPaused = provider.isPaused(song.id);

  Widget content;
  VoidCallback? onTap;
  Color borderColor;
  Color bgColor;

  if (progress != null) {
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
              ? Icon(Icons.pause_rounded, color: primaryColor, size: 20)
              : CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.5,
                  color: primaryColor,
                ),
        ),
        const SizedBox(width: 12),
        Text(
          isPaused ? "Duraklatıldı" : "İndiriliyor...",
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
        const Text(
          "İndirildi",
          style: TextStyle(
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
        const Icon(Icons.downloading, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        const Text(
          "İndir",
          style: TextStyle(
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
}
