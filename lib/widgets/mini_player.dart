import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:provider/provider.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final songProvider = context.watch<SongProvider>();
    final song = songProvider.currentSong;

    if (song == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    Image.network(
                      song.coverUrl,
                      height: 65,
                      width: 65,
                      fit: BoxFit.cover,
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
                    IconButton(
                      icon: Icon(
                        song.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: song.isFavorite ? Colors.red : Colors.white,
                      ),
                      onPressed: () => songProvider.toggleFavorite(song),
                    ),
                    StreamBuilder<PlayerState>(
                      stream: songProvider.playerStateStream,
                      builder: (context, snapshot) {
                        final playerState = snapshot.data;
                        final playing = playerState?.playing ?? false;

                        return IconButton(
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
                        );
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
                          songProvider.audioPlayer.duration ?? Duration.zero;
                      double value = 0.0;
                      if (duration.inMilliseconds > 0) {
                        value =
                            (position.inMilliseconds / duration.inMilliseconds)
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
    );
  }
}
