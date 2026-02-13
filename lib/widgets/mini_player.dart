import 'dart:ui';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/pages/player_page.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _startTimer();
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final provider = context.read<SongProvider>();
        if (provider.isSleepTimerActive) {
          setState(() {});
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = context.watch<SongProvider>();
    final song = songProvider.currentSong;

    if (song == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<PlayerState>(
      stream: songProvider.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final playing = playerState?.playing ?? false;
        final processingState = playerState?.processingState;

        if (playing && !_controller.isAnimating) {
          _controller.repeat();
        } else if (!playing && _controller.isAnimating) {
          _controller.stop();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              // Sağa/Sola kaydırma ile şarkı değiştirme
              // Hassasiyet için 100 eşik değeri kullanıldı
              if ((details.primaryVelocity ?? 0) < -100) {
                // Sola kaydırma -> Sonraki şarkı
                songProvider.playNext();
              } else if ((details.primaryVelocity ?? 0) > 100) {
                // Sağa kaydırma -> Önceki şarkı
                songProvider.playPrevious();
              }
            },
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) < -100) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PlayerPage()),
                );
              }
            },
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: playing
                        ? SweepGradient(
                            colors: [
                              Colors.transparent,
                              Theme.of(context).primaryColor,
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                            transform: GradientRotation(
                              _controller.value * 2 * math.pi,
                            ),
                          )
                        : null,
                    color: playing ? null : Colors.transparent,
                  ),
                  child: child,
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    height: 65,
                    color: Colors.grey.shade900.withOpacity(0.6),
                    child: Stack(
                      children: [
                        Row(
                          children: [
                            (song.localImagePath != null)
                                ? Image.file(
                                    File(song.localImagePath!),
                                    height: 65,
                                    width: 65,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (
                                          context,
                                          error,
                                          stackTrace,
                                        ) => Image.network(
                                          song.coverUrl,
                                          height: 65,
                                          width: 65,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (
                                                context,
                                                error,
                                                stackTrace,
                                              ) => Container(
                                                height: 65,
                                                width: 65,
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
                                                child: const Icon(
                                                  Icons.music_note_rounded,
                                                  color: Colors.white24,
                                                ),
                                              ),
                                        ),
                                  )
                                : Image.network(
                                    song.coverUrl,
                                    height: 65,
                                    width: 65,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              height: 65,
                                              width: 65,
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
                                              child: const Icon(
                                                Icons.music_note_rounded,
                                                color: Colors.white24,
                                              ),
                                            ),
                                  ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (songProvider.isSleepTimerActive &&
                                songProvider.sleepTimerEndTime != null)
                              _buildTimerDisplay(
                                context,
                                songProvider.sleepTimerEndTime!,
                              ),
                            IconButton(
                              icon: Icon(
                                song.isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: song.isFavorite
                                    ? Theme.of(context).primaryColor
                                    : Colors.white,
                              ),
                              onPressed: () =>
                                  songProvider.toggleFavorite(song),
                            ),
                            if (processingState == ProcessingState.loading ||
                                processingState == ProcessingState.buffering)
                              SizedBox(
                                width: 48,
                                height: 48,
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Theme.of(context).primaryColor,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                ),
                              )
                            else
                              IconButton(
                                icon: Icon(
                                  playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Theme.of(context).primaryColor,
                                  size: 32,
                                ),
                                onPressed: () {
                                  if (playing) {
                                    songProvider.audioPlayer.pause();
                                  } else {
                                    songProvider.audioPlayer.play();
                                  }
                                },
                              ),
                            IconButton(
                              icon: const Icon(
                                Icons.skip_next_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                              onPressed: songProvider.playNext,
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: StreamBuilder<Duration>(
                            stream: songProvider.audioPlayer.positionStream,
                            builder: (context, snapshot) {
                              final position = snapshot.data ?? Duration.zero;
                              final duration =
                                  songProvider.audioPlayer.duration ??
                                  Duration.zero;
                              double value = 0.0;
                              if (duration.inMilliseconds > 0) {
                                value =
                                    (position.inMilliseconds /
                                            duration.inMilliseconds)
                                        .clamp(0.0, 1.0);
                              }
                              return LinearProgressIndicator(
                                value: value,
                                minHeight: 2,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).primaryColor,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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

  Widget _buildTimerDisplay(BuildContext context, DateTime endTime) {
    final remaining = endTime.difference(DateTime.now());
    if (remaining.isNegative) return const SizedBox.shrink();
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, size: 10, color: primaryColor),
          const SizedBox(width: 4),
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: primaryColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
