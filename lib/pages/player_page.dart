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

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

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

    return Scaffold(
      extendBodyBehindAppBar: true, // AppBar'ın arkasına içerik taşsın
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: Colors.white,
            size: 30,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              songProvider.isSleepTimerActive
                  ? Icons.timer
                  : Icons.timer_outlined,
              color: songProvider.isSleepTimerActive
                  ? Theme.of(context).primaryColor
                  : Colors.white,
            ),
            tooltip: "Uyku Zamanlayıcısı",
            onPressed: () => _showSleepTimerDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.queue_music_rounded, color: Colors.white),
            tooltip: "Sıradaki Şarkılar",
            onPressed: () {
              _showQueueBottomSheet(context, songProvider);
            },
          ),
          IconButton(
            icon: CustomIcons.svgIcon(
              CustomIcons.share,
              color: Colors.white,
              size: 24,
            ),
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
                                File(currentSong.localImagePath!).existsSync())
                            ? Image.file(
                                File(currentSong.localImagePath!),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.grey.shade800,
                                            Colors.black,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: Center(
                                        child: CustomIcons.svgIcon(
                                          CustomIcons.musicNote,
                                          color: Colors.white24,
                                          size: 120,
                                        ),
                                      ),
                                    ),
                              )
                            : Image.network(
                                currentSong.coverUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.grey.shade800,
                                          Colors.black,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: Center(
                                      child: CustomIcons.svgIcon(
                                        CustomIcons.musicNote,
                                        color: Colors.white24,
                                        size: 120,
                                      ),
                                    ),
                                  );
                                },
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
                      _buildDownloadButton(context, songProvider, currentSong),
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
                              inactiveTrackColor: Colors.white.withOpacity(0.3),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        child: StreamBuilder<PlayerState>(
                          stream: songProvider.playerStateStream,
                          builder: (context, snapshot) {
                            final playerState = snapshot.data;
                            final processingState =
                                playerState?.processingState;
                            final playing = playerState?.playing;

                            if (processingState == ProcessingState.loading ||
                                processingState == ProcessingState.buffering) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              );
                            } else if (playing != true) {
                              return IconButton(
                                icon: CustomIcons.svgIcon(
                                  CustomIcons.playerPlay,
                                  color: Colors.white,
                                  size: 45,
                                ),
                                onPressed: songProvider.audioPlayer.play,
                              );
                            } else {
                              return IconButton(
                                icon: const Icon(
                                  Icons.pause_rounded,
                                  color: Colors.white,
                                  size: 45,
                                ),
                                onPressed: songProvider.audioPlayer.pause,
                              );
                            }
                          },
                        ),
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
    );
  }

  void _showSleepTimerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Zamanlayıcı Ayarla',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildTimerOption(context, 15),
            _buildTimerOption(context, 30),
            _buildTimerOption(context, 45),
            _buildTimerOption(context, 60),
            if (context.read<SongProvider>().isSleepTimerActive)
              ListTile(
                leading: const Icon(Icons.timer_off, color: Colors.redAccent),
                title: const Text(
                  'Zamanlayıcıyı Kapat',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  context.read<SongProvider>().cancelSleepTimer();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Zamanlayıcı kapatıldı.')),
                  );
                },
              ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildTimerOption(BuildContext context, int minutes) {
    return ListTile(
      title: Text(
        '$minutes Dakika',
        style: const TextStyle(color: Colors.white),
      ),
      onTap: () {
        context.read<SongProvider>().setSleepTimer(minutes);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Müzik $minutes dakika sonra duracak.')),
        );
      },
    );
  }

  void _showQueueBottomSheet(BuildContext context, SongProvider songProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
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
                color: Colors.grey.shade900.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
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
                      color: Colors.grey.shade600,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "Sıradaki Şarkılar",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: songProvider.playlist.length,
                      itemBuilder: (context, index) {
                        final song = songProvider.playlist[index];
                        final isCurrent =
                            song.id == songProvider.currentSong?.id;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          leading: isCurrent
                              ? Icon(
                                  Icons.bar_chart_rounded,
                                  color: Theme.of(context).primaryColor,
                                )
                              : Text(
                                  "${index + 1}",
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                          title: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isCurrent
                                  ? Theme.of(context).primaryColor
                                  : Colors.white,
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
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
                            ),
                          ),
                          trailing: isCurrent
                              ? const SizedBox.shrink()
                              : null, // İleride buraya sürükleme ikonu eklenebilir
                          onTap: () {
                            if (!isCurrent) {
                              songProvider.playSong(
                                song,
                                songProvider.playlist,
                              );
                              Navigator.pop(context); // Listeyi kapat
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_download_rounded,
                size: 60,
                color: Colors.white70,
              ),
              const SizedBox(height: 16),
              const Text(
                "İndirmek için Giriş Yapın",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Şarkıları cihazınıza indirmek ve çevrimdışı dinlemek için lütfen giriş yapın.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx); // BottomSheet'i kapat
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Giriş Yap",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  "İptal",
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        Icons.cancel_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "İndirme işlemi iptal edildi",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 2),
                ),
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
        icon: CustomIcons.svgIcon(
          CustomIcons.download,
          color: Colors.white,
          size: 24,
        ),
        onPressed: () {
          if (!provider.isFirebaseLoggedIn) {
            _showLoginBottomSheet(context);
            return;
          }

          // İndirme başladığına dair belirgin bir bildirim (SnackBar)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.downloading_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "İndirme Başlatıldı",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );

          provider.downloadSong(song).catchError((e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("İndirme başarısız: $e"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          });
        },
      );
    }
  }
}
