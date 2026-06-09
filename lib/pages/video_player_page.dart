import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerPage extends StatefulWidget {
  final File videoFile;
  final String title;

  const VideoPlayerPage({
    super.key,
    required this.videoFile,
    required this.title,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _controller;
  bool _showControls = true;
  bool _isLandscape = false;

  void _toggleLandscape() {
    setState(() {
      _isLandscape = !_isLandscape;
    });
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
    _hideControlsTimer();
  }

  void _skipBackward() {
    final currentPosition = _controller.value.position;
    final newPosition = currentPosition - const Duration(seconds: 10);
    _controller
        .seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
    _hideControlsTimer();
  }

  void _skipForward() {
    final currentPosition = _controller.value.position;
    final duration = _controller.value.duration;
    final newPosition = currentPosition + const Duration(seconds: 10);
    _controller.seekTo(newPosition > duration ? duration : newPosition);
    _hideControlsTimer();
  }

  @override
  void initState() {
    super.initState();
    // Tam ekran (Sinematik) deneyim için durum çubuğunu gizler
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
        _hideControlsTimer();
      });
  }

  void _hideControlsTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    // Cihazı tekrar dikey forma (portrait) zorla
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    // Sayfadan çıkınca cihazın bildirim ve menü çubuklarını geri getir
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inHours > 0 ? '${duration.inHours}:' : ''}$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          setState(() {
            _showControls = !_showControls;
          });
          if (_showControls) _hideControlsTimer();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video Oynatıcı Alanı
            Center(
              child: _controller.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : const CircularProgressIndicator(color: Colors.white),
            ),
            // Üzerine Gelen Kontroller (Play/Pause, Süre, Geri Dön)
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Üst Bar
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 28),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              widget.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 48), // Dengeleyici boşluk
                        ],
                      ),
                      const Spacer(),
                      // Orta Kontroller (Geri, Oynat/Duraklat, İleri)
                      if (_controller.value.isInitialized)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: _skipBackward,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(12),
                                child: const Icon(
                                  Icons.replay_10_rounded,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                            ),
                            const SizedBox(width: 32),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _controller.value.isPlaying
                                      ? _controller.pause()
                                      : _controller.play();
                                });
                                _hideControlsTimer();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Icon(
                                  _controller.value.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 56,
                                ),
                              ),
                            ),
                            const SizedBox(width: 32),
                            GestureDetector(
                              onTap: _skipForward,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(12),
                                child: const Icon(
                                  Icons.forward_10_rounded,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                            ),
                          ],
                        ),
                      const Spacer(),
                      // Alt İlerleme Çubuğu (Slider)
                      if (_controller.value.isInitialized)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 24),
                          child: Row(
                            children: [
                              ValueListenableBuilder(
                                valueListenable: _controller,
                                builder:
                                    (context, VideoPlayerValue value, child) {
                                  return Text(
                                    _formatDuration(value.position),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13),
                                  );
                                },
                              ),
                              Expanded(
                                child: ValueListenableBuilder(
                                  valueListenable: _controller,
                                  builder:
                                      (context, VideoPlayerValue value, child) {
                                    return SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        thumbShape: const RoundSliderThumbShape(
                                            enabledThumbRadius: 6),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                                overlayRadius: 14),
                                        activeTrackColor:
                                            Theme.of(context).primaryColor,
                                        inactiveTrackColor:
                                            Colors.white.withOpacity(0.3),
                                        thumbColor:
                                            Theme.of(context).primaryColor,
                                      ),
                                      child: Slider(
                                        value: value.position.inSeconds
                                            .toDouble()
                                            .clamp(
                                                0.0,
                                                value.duration.inSeconds
                                                    .toDouble()),
                                        max: value.duration.inSeconds
                                                    .toDouble() >
                                                0
                                            ? value.duration.inSeconds
                                                .toDouble()
                                            : 1.0,
                                        onChanged: (pos) {
                                          _controller.seekTo(
                                              Duration(seconds: pos.toInt()));
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Text(
                                _formatDuration(_controller.value.duration),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                              ),
                              const SizedBox(width: 16),
                              GestureDetector(
                                onTap: _toggleLandscape,
                                child: Icon(
                                  _isLandscape
                                      ? Icons.fullscreen_exit_rounded
                                      : Icons.fullscreen_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
