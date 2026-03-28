import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/custom_icons.dart';

class FavoriteButton extends StatefulWidget {
  final Song song;
  final Color? activeColor;
  final Color? inactiveColor;

  const FavoriteButton({
    super.key,
    required this.song,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SongProvider>(
      builder: (context, provider, child) {
        return ScaleTransition(
          scale: _scaleAnimation,
          child: IconButton(
            icon: CustomIcons.svgIcon(
              widget.song.isFavorite
                  ? CustomIcons.favorite
                  : CustomIcons.favoriteBorder,
              color: widget.song.isFavorite
                  ? (widget.activeColor ?? Theme.of(context).primaryColor)
                  : (widget.inactiveColor ?? Colors.grey),
              size: 24,
            ),
            onPressed: () {
              // Titreşim efekti
              HapticFeedback.mediumImpact();
              // Animasyonu oynat (Büyü ve geri küçül)
              _controller.forward().then((_) => _controller.reverse());
              // Favori işlemini yap
              provider.toggleFavorite(widget.song);
            },
          ),
        );
      },
    );
  }
}
