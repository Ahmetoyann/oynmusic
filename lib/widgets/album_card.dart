import 'dart:ui';
import 'package:flutter/material.dart';

class BlurryAlbumCard extends StatefulWidget {
  final String title;
  final String artist;
  final String coverUrl;
  final VoidCallback onTap;

  const BlurryAlbumCard({
    super.key,
    required this.title,
    required this.artist,
    required this.coverUrl,
    required this.onTap,
  });

  @override
  State<BlurryAlbumCard> createState() => _BlurryAlbumCardState();
}

class _BlurryAlbumCardState extends State<BlurryAlbumCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 100),
      child: Container(
        width: 160, // Kart genişliği
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Arka Plan Resmi (Bulanık olacak)
              Image.network(
                widget.coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(color: Colors.grey.shade900),
              ),
              // 2. Blur Efekti
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                child: Container(
                  color: Colors.black.withOpacity(0.4), // Karartma
                ),
              ),
              // 3. İçerik (Resim + Metin)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Net Albüm Kapağı (Ortada küçük)
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              widget.coverUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Başlık
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (widget.artist.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      // Sanatçı
                      Text(
                        widget.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 4. Tıklama Efekti
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  onHighlightChanged: (value) {
                    setState(() {
                      _scale = value ? 0.95 : 1.0;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
