import 'dart:io';
import 'package:flutter/material.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/widgets/song_card.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SongGridCard extends StatelessWidget {
  final Song? song;
  final String imageUrl;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showFavorite;
  final String placeholderIcon;
  final int titleMaxLines;

  const SongGridCard({
    super.key,
    this.song,
    required this.imageUrl,
    required this.title,
    this.subtitle,
    this.onTap,
    this.showFavorite = true,
    this.placeholderIcon = CustomIcons.musicNote,
    this.titleMaxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isFav = song != null && showFavorite
        ? context.select<SongProvider, bool>(
            (p) => p.favoriteSongs.any((s) => s.id == song!.id),
          )
        : false;

    return GestureDetector(
      onTap: onTap,
      onLongPress: song != null
          ? () {
              SongCard.showModernMenu(context, song!);
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4), // Köşe yarıçapını azalt
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4), // Köşe yarıçapını azalt
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    (song?.localImagePath != null &&
                            File(song!.localImagePath!).existsSync())
                        ? Image.file(
                            File(song!.localImagePath!),
                            fit: BoxFit.cover,
                            cacheHeight: 300,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.grey.shade800, Colors.black],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            memCacheHeight: 300,
                            errorWidget: (context, url, error) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.grey.shade800, Colors.black],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                          ),
                    if (isFav)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.greenAccent,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: titleMaxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
