import 'package:flutter/material.dart';

class PlayingEqualizerIndicator extends StatefulWidget {
  final Color color;
  final double width;
  final double height;
  final bool isPlaying;

  const PlayingEqualizerIndicator({
    super.key,
    required this.color,
    this.width = 16.0,
    this.height = 16.0,
    this.isPlaying = true,
  });

  @override
  State<PlayingEqualizerIndicator> createState() => _PlayingEqualizerIndicatorState();
}

class _PlayingEqualizerIndicatorState extends State<PlayingEqualizerIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  final int _barCount = 3;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _barCount,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 300 + (index * 150)),
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.2, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    if (widget.isPlaying) {
      _startAnimations();
    } else {
      for (var controller in _controllers) {
        controller.value = 0.2;
      }
    }
  }

  @override
  void didUpdateWidget(covariant PlayingEqualizerIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _startAnimations();
      } else {
        _stopAnimations();
      }
    }
  }

  void _startAnimations() {
    for (var controller in _controllers) {
      controller.repeat(reverse: true);
    }
  }

  void _stopAnimations() {
    for (var controller in _controllers) {
      controller.stop();
      controller.animateTo(0.2, duration: const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(_barCount, (index) {
          return AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Container(
                width: widget.width / _barCount * 0.6,
                height: widget.height * _animations[index].value,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
