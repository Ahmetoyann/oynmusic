import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:muzik_app/pages/login_page.dart';
import 'package:share_plus/share_plus.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  Color? _dominantColor;
  String? _currentSongId;

  Future<void> _extractColor(String url) async {
    try {
      final generator = await PaletteGenerator.fromImageProvider(
        NetworkImage(url),
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

    // Eğer şarkı seçili değilse boş ekran dön
    if (currentSong == null) {
      return const Scaffold(body: Center(child: Text("Şarkı seçilmedi")));
    }

    // Şarkı değiştiyse rengi güncelle
    if (_currentSongId != currentSong.id) {
      _currentSongId = currentSong.id;
      _dominantColor = null; // Yüklenirken varsayılan rengi kullan (siyah)
      _extractColor(currentSong.coverUrl);
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
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              Share.share(
                'Bu şarkıyı OYN Music\'te keşfettim!\n\n🎵 ${currentSong.title}\n👤 ${currentSong.artist}\n\nDinlemek için: ${currentSong.audioUrl}',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // Ekstra seçenekler buraya eklenebilir
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. KATMAN: Arka Plan Resmi
          Image.network(
            currentSong.coverUrl,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => Container(color: Colors.black),
          ),

          // 2. KATMAN: Bulanıklık Efekti (Glassmorphism)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (_dominantColor ?? Colors.black).withOpacity(0.6),
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
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
                        child: Image.network(
                          currentSong.coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.music_note,
                                size: 120,
                                color: Colors.white12,
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
                              ? Colors.redAccent
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
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white.withOpacity(0.3),
                              thumbColor: Colors.white,
                              overlayColor: Colors.white.withOpacity(0.2),
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
                        icon: const Icon(
                          Icons.skip_previous_rounded,
                          color: Colors.white,
                          size: 45,
                        ),
                        onPressed: () => songProvider.playPrevious(),
                      ),
                      Container(
                        width: 75,
                        height: 75,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
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
                                  color: Colors.black,
                                ),
                              );
                            } else if (playing != true) {
                              return IconButton(
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.black,
                                  size: 45,
                                ),
                                onPressed: songProvider.audioPlayer.play,
                              );
                            } else {
                              return IconButton(
                                icon: const Icon(
                                  Icons.pause_rounded,
                                  color: Colors.black,
                                  size: 45,
                                ),
                                onPressed: songProvider.audioPlayer.pause,
                              );
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.skip_next_rounded,
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
    final isDownloaded = provider.isSongDownloaded(song.id);
    final progress = provider.downloadProgress[song.id];

    if (progress != null) {
      return Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 3,
            color: Colors.white,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Colors.white),
            onPressed: () => provider.cancelDownload(song.id),
          ),
        ],
      );
    } else if (isDownloaded) {
      return IconButton(
        icon: const Icon(Icons.check_circle, color: Colors.green),
        onPressed: () {
          // İndirildi durumu
        },
      );
    } else {
      return IconButton(
        icon: const Icon(Icons.download_rounded, color: Colors.white),
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
