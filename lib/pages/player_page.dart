// lib/pages/player_page.dart
//
// Bu sayfa, tam ekran müzik çalar arayüzünü içerir.
// Şarkının kapak resmi, başlık, sanatçı bilgisi, ilerleme çubuğu ve
// kontrol butonlarını (önceki, oynat/durdur, sonraki) gösterir.

import 'package:flutter/material.dart';
import 'dart:ui'; // Blur efekti için gerekli
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:share_plus/share_plus.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

// Şarkının pozisyon, tampon ve toplam süresini birleştiren yardımcı bir sınıf
/// Şarkının çalma pozisyonu, tampon durumu ve toplam süresini tutan yardımcı sınıf
class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;

  PositionData(this.position, this.bufferedPosition, this.duration);
}

/// Tam ekran müzik çalar sayfası
/// Şarkı detaylarını ve kontrol arayüzünü gösterir
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  Song? _lastSong;
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  void dispose() {
    _disposeVideoControllers();
    super.dispose();
  }

  void _disposeVideoControllers() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _videoPlayerController = null;
    _chewieController = null;
  }

  Future<void> _initializeVideoPlayer(String url) async {
    _disposeVideoControllers();
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await _videoPlayerController!.initialize();
      // just_audio sesi çaldığı için video oynatıcının sesini kapatıyoruz (yankı olmaması için)
      await _videoPlayerController!.setVolume(0.0);

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: true,
        showControls:
            false, // Kendi kontrollerimizi kullandığımız için gizliyoruz
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        deviceOrientationsOnEnterFullScreen: [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp],
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Video yüklenirken hata: $e");
    }
  }

  // `just_audio`'dan gelen farklı stream'leri tek bir stream'de birleştiriyoruz.
  // Bu, arayüzdeki slider'ı ve süreleri tek bir yerden yönetmemizi sağlar.
  Stream<PositionData> get _positionDataStream {
    // `read` kullanıyoruz çünkü bu stream'in kendisi build içinde değişmeyecek.
    final songProvider = context.read<SongProvider>();
    return Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
      songProvider.positionStream, // Şarkının o anki saniyesi
      songProvider
          .audioPlayer
          .bufferedPositionStream, // Ne kadarının yüklendiği
      songProvider.durationStream, // Şarkının toplam süresi
      (position, bufferedPosition, duration) =>
          PositionData(position, bufferedPosition, duration ?? Duration.zero),
    );
  }

  @override
  Widget build(BuildContext context) {
    // `watch` kullanarak provider'daki değişiklikleri dinliyoruz.
    // Özellikle `currentSong` değiştiğinde bu sayfanın yeniden çizilmesi için gerekli.
    final songProvider = context.watch<SongProvider>();
    final song = songProvider.currentSong;

    // Şarkı değiştiğinde video kontrolünü yap
    if (song != _lastSong) {
      _lastSong = song;
      if (song != null && song.audioUrl.endsWith('.mp4')) {
        _initializeVideoPlayer(song.audioUrl);
      } else {
        _disposeVideoControllers();
      }
    }

    // Eğer bir şarkı seçilmemişse veya bir hata oluştuysa, sayfayı gösterme.
    if (song == null) {
      // Bu durum normalde yaşanmaz çünkü bu sayfaya şarkı seçilince geliyoruz.
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text("Çalınacak şarkı bulunamadı.")),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true, // İçeriğin AppBar arkasına taşmasını sağlar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Şimdi Oynatılıyor",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black, // Yüklenirken veya hata durumunda görünür
      body: Stack(
        children: [
          // 1. KATMAN: Arka Plan Resmi (Bulanık)
          Positioned.fill(
            child: Image.network(song.coverUrl, fit: BoxFit.cover),
          ),
          // 2. KATMAN: Bulanıklık ve Karartma Efekti
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
              child: Container(
                color: Colors.black.withOpacity(
                  0.5,
                ), // Okunabilirlik için karartma
              ),
            ),
          ),
          // 3. KATMAN: Asıl İçerik
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  // Albüm Kapağı
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: animation.drive(
                                Tween(begin: 0.9, end: 1.0),
                              ),
                              child: child,
                            ),
                          );
                        },
                    child: Container(
                      key: ValueKey(song.id),
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                        // Video hazırsa resmi gösterme, değilse kapak resmini göster
                        image:
                            (_chewieController != null &&
                                _chewieController!
                                    .videoPlayerController
                                    .value
                                    .isInitialized)
                            ? null
                            : DecorationImage(
                                image: NetworkImage(song.coverUrl),
                                fit: BoxFit.cover,
                              ),
                      ),
                      // Video hazırsa Chewie oynatıcıyı göster
                      child:
                          (_chewieController != null &&
                              _chewieController!
                                  .videoPlayerController
                                  .value
                                  .isInitialized)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Chewie(controller: _chewieController!),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Şarkı ve Sanatçı Adı
                  Text(
                    song.title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          songProvider.toggleFavorite(song);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                song.isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: song.isFavorite
                                    ? Colors.red
                                    : Colors.white,
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                song.isFavorite
                                    ? "Favorilerde"
                                    : "Favorilere Ekle",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share, color: Colors.white70),
                        onPressed: () {
                          Share.share(
                            'Dinle: ${song.title} - ${song.artist}\n${song.audioUrl}',
                          );
                        },
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Süre Çubuğu (Slider)
                  StreamBuilder<PositionData>(
                    stream: _positionDataStream,
                    builder: (context, snapshot) {
                      final positionData = snapshot.data;
                      // Eğer oynatıcıdan süre bilgisi henüz gelmediyse veya 0 ise,
                      // API'den gelen statik süreyi kullan.
                      final duration =
                          (positionData?.duration != null &&
                              positionData!.duration.inSeconds > 0)
                          ? positionData!.duration
                          : Duration(seconds: song.duration ?? 0);
                      final position = positionData?.position ?? Duration.zero;
                      final double maxDuration = duration.inMilliseconds
                          .toDouble();
                      final double sliderValue = _isDragging
                          ? _dragValue
                          : position.inMilliseconds.toDouble();

                      return Column(
                        children: [
                          Slider(
                            min: 0.0,
                            max: maxDuration + 1.0,
                            value: sliderValue.clamp(0.0, maxDuration),
                            onChangeStart: (value) {
                              setState(() {
                                _isDragging = true;
                                _dragValue = value;
                              });
                            },
                            onChanged: (value) {
                              setState(() => _dragValue = value);
                            },
                            onChangeEnd: (value) {
                              context.read<SongProvider>().audioPlayer.seek(
                                Duration(milliseconds: value.round()),
                              );
                              setState(() => _isDragging = false);
                            },
                            activeColor: Theme.of(context).primaryColor,
                            inactiveColor: Colors.grey.shade800,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(position),
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                Text(
                                  _formatDuration(duration),
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  // Çalma Kontrol Butonları
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Karışık Çal (Shuffle) Butonu
                      StreamBuilder<bool>(
                        stream:
                            songProvider.audioPlayer.shuffleModeEnabledStream,
                        builder: (context, snapshot) {
                          final shuffleModeEnabled = snapshot.data ?? false;
                          return IconButton(
                            icon: const Icon(Icons.shuffle),
                            color: shuffleModeEnabled
                                ? Theme.of(context).primaryColor
                                : Colors.white,
                            onPressed: () async {
                              final enable = !shuffleModeEnabled;
                              if (enable) {
                                await songProvider.audioPlayer.shuffle();
                              }
                              await songProvider.audioPlayer
                                  .setShuffleModeEnabled(enable);
                            },
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded, size: 40),
                        onPressed:
                            songProvider.playPrevious, // Önceki şarkıya geç
                        color: Colors.white,
                      ),
                      // Oynat/Durdur butonu
                      StreamBuilder<PlayerState>(
                        stream: songProvider.playerStateStream,
                        builder: (context, snapshot) {
                          final playerState = snapshot.data;
                          final processingState = playerState?.processingState;
                          final playing = playerState?.playing;

                          if (processingState == ProcessingState.loading ||
                              processingState == ProcessingState.buffering) {
                            return Container(
                              width: 64,
                              height: 64,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            );
                          } else if (playing != true) {
                            return IconButton(
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                                size: 64,
                              ),
                              onPressed: songProvider
                                  .audioPlayer
                                  .play, // Çalmaya başla/devam et
                              color: Colors.white,
                            );
                          } else if (processingState !=
                              ProcessingState.completed) {
                            return IconButton(
                              icon: const Icon(Icons.pause_rounded, size: 64),
                              onPressed:
                                  songProvider.audioPlayer.pause, // Duraklat
                              color: Colors.white,
                            );
                          } else {
                            // Şarkı tamamlandığında otomatik olarak sonraki şarkıya geç
                            songProvider.playNext();
                            return const SizedBox(
                              width: 64,
                              height: 64,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded, size: 40),
                        onPressed: songProvider.playNext, // Sonraki şarkıya geç
                        color: Colors.white,
                      ),
                      // Tekrarla (Repeat) Butonu
                      StreamBuilder<LoopMode>(
                        stream: songProvider.audioPlayer.loopModeStream,
                        builder: (context, snapshot) {
                          final loopMode = snapshot.data ?? LoopMode.off;
                          final icons = [
                            Icon(Icons.repeat, color: Colors.white),
                            Icon(
                              Icons.repeat,
                              color: Theme.of(context).primaryColor,
                            ),
                            Icon(
                              Icons.repeat_one,
                              color: Theme.of(context).primaryColor,
                            ),
                          ];
                          const cycleModes = [
                            LoopMode.off,
                            LoopMode.all,
                            LoopMode.one,
                          ];
                          final index = cycleModes.indexOf(loopMode);
                          return IconButton(
                            icon: icons[index],
                            onPressed: () {
                              songProvider.audioPlayer.setLoopMode(
                                cycleModes[(cycleModes.indexOf(loopMode) + 1) %
                                    cycleModes.length],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Süreyi "01:23" formatında göstermek için yardımcı metot
  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}
