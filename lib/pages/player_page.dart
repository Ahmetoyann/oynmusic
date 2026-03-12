import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:muzik_app/pages/login_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:muzik_app/widgets/custom_app_bar.dart';

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
            icon: Icon(Icons.keyboard_arrow_down, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(
                songProvider.isSleepTimerActive
                    ? Icons.more_time
                    : Icons.more_time_outlined,
                color: songProvider.isSleepTimerActive
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).primaryColor.withOpacity(0.3),
              ),
              tooltip: "Uyku Zamanlayıcısı",
              onPressed: () => _showSleepTimerDialog(context),
            ),
            IconButton(
              icon: Icon(Icons.table_rows),
              tooltip: "Sıradaki Şarkılar",
              onPressed: () {
                _showQueueBottomSheet(context, songProvider);
              },
            ),
            IconButton(
              icon: Icon(Icons.ios_share_outlined, size: 24),
              onPressed: () {
                Share.share(
                  'Bu şarkıyı OYN Music\'te keşfettim!\n\n🎵 ${currentSong.title}\n👤 ${currentSong.artist}\n\nDinlemek için: ${currentSong.audioUrl}',
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
                    errorBuilder: (ctx, err, stack) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.grey.shade800, Colors.black],
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
                          colors: [Colors.grey.shade800, Colors.black],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),

            // 2. KATMAN: Bulanıklık Efekti (Glassmorphism)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Container(
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
                          Colors.black.withOpacity(0.9),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // 3. KATMAN: İçerik
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),

                    // Büyük Kapak Resmi
                    Center(
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.85,
                        height: MediaQuery.of(context).size.width * 0.85,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                          color: Colors.grey.shade900,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child:
                              (currentSong.localImagePath != null &&
                                  File(
                                    currentSong.localImagePath!,
                                  ).existsSync())
                              ? Image.file(
                                  File(currentSong.localImagePath!),
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  currentSong.coverUrl,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Şarkı Başlığı ve Sanatçı
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentSong.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                currentSong.artist,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 18,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // İndirme Butonu
                        _buildDownloadButton(
                          context,
                          songProvider,
                          currentSong,
                        ),
                        IconButton(
                          icon: Icon(
                            currentSong.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: currentSong.isFavorite
                                ? Theme.of(context).primaryColor
                                : Colors.white,
                            size: 32,
                          ),
                          onPressed: () =>
                              songProvider.toggleFavorite(currentSong),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // İlerleme Çubuğu (Slider)
                    StreamBuilder<Duration>(
                      stream: songProvider.positionStream,
                      builder: (context, snapshot) {
                        final position = snapshot.data ?? Duration.zero;
                        final duration =
                            songProvider.audioPlayer.duration ?? Duration.zero;

                        return Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                trackHeight: 4,
                                activeTrackColor: primaryColor,
                                inactiveTrackColor: Colors.white.withOpacity(
                                  0.3,
                                ),
                                thumbColor: primaryColor,
                                overlayColor: primaryColor.withOpacity(0.2),
                              ),
                              child: Slider(
                                value: position.inSeconds.toDouble().clamp(
                                  0,
                                  duration.inSeconds.toDouble(),
                                ),
                                min: 0,
                                max: duration.inSeconds.toDouble() > 0
                                    ? duration.inSeconds.toDouble()
                                    : 1,
                                onChanged: (value) {
                                  songProvider.audioPlayer.seek(
                                    Duration(seconds: value.toInt()),
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(duration),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
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
                        IconButton(
                          icon: Icon(
                            Icons.shuffle,
                            color: songProvider.isShuffleEnabled
                                ? Theme.of(context).primaryColor
                                : Colors.white,
                          ),
                          onPressed: songProvider.toggleShuffle,
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
                        IconButton(
                          icon: Icon(
                            songProvider.loopMode == LoopMode.one
                                ? Icons.repeat_one
                                : Icons.repeat,
                            color: songProvider.loopMode == LoopMode.off
                                ? Colors.white
                                : Theme.of(context).primaryColor,
                          ),
                          onPressed: songProvider.cycleLoopMode,
                        ),
                      ],
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ],
        ),
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
          ? const Icon(Icons.pause_rounded, color: Colors.white, size: 45)
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

/// Oynatma durumuna göre ikonları ve eylemi yöneten genel bir widget.
Widget _buildPlayPauseIcon({
  required bool isPlaying,
  required VoidCallback onPressed,
}) {
  return IconButton(
    icon: isPlaying
        ? const Icon(Icons.pause_rounded, color: Colors.white, size: 45)
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
                Icon(
                  Icons.timer_outlined,
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
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
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
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: songProvider.playlist.length,
                  itemBuilder: (context, index) {
                    final song = songProvider.playlist[index];
                    final isCurrent = song.id == songProvider.currentSong?.id;

                    return Padding(
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
                                      ? Image.file(
                                          File(song.localImagePath!),
                                          fit: BoxFit.cover,
                                        )
                                      : Image.network(
                                          song.coverUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) => Container(
                                            color: Colors.grey.shade800,
                                            child: const Icon(
                                              Icons.music_note,
                                              color: Colors.white54,
                                            ),
                                          ),
                                        ),
                                  if (isCurrent)
                                    Container(
                                      color: Colors.black.withOpacity(0.6),
                                      child: Center(
                                        child: Icon(
                                          Icons.graphic_eq,
                                          color: Theme.of(context).primaryColor,
                                          size: 24,
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
    icon: const Icon(
      Icons.cloud_download_rounded,
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
  final isDownloaded = provider.isSongDownloaded(song.id);
  final progress = provider.downloadProgress[song.id];

  if (progress != null) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CircularProgressIndicator(
          value: progress,
          strokeWidth: 3,
          color: primaryColor,
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 20, color: Colors.white),
          onPressed: () {
            provider.cancelDownload(song.id);
            CustomSnackBar.showError(
              context: context,
              message: "İndirme işlemi iptal edildi",
            );
          },
        ),
      ],
    );
  } else if (isDownloaded) {
    return IconButton(
      icon: CustomIcons.svgIcon(
        CustomIcons.check,
        color: primaryColor,
        size: 24,
      ),
      onPressed: () {
        // İndirildi durumu
      },
    );
  } else {
    return IconButton(
      icon: Icon(Icons.downloading_rounded, color: Colors.white, size: 24),
      onPressed: () {
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
      },
    );
  }
}
