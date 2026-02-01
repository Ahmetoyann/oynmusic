import 'dart:io';
import 'package:flutter/material.dart';
import 'package:muzik_app/main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late AnimationController _bgController;
  late Animation<Alignment> _beginAlignment;
  late Animation<Alignment> _endAlignment;
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;
  late Animation<double> _textOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    // Yazı için fade-in (yavaşça görünme) animasyonu
    // Animasyonun yarısından sonra başlayıp sonuna kadar sürecek
    _textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // Nefes alma animasyonu (Büyüyüp küçülme)
    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _breathingAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    // Arka plan gradient animasyonu
    _bgController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _beginAlignment = Tween<Alignment>(
      begin: Alignment.topLeft,
      end: Alignment.bottomLeft,
    ).animate(_bgController);

    _endAlignment = Tween<Alignment>(
      begin: Alignment.bottomRight,
      end: Alignment.topRight,
    ).animate(_bgController);

    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    // 3 saniye bekle
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      _checkInternetAndNavigate();
    }
  }

  Future<void> _checkInternetAndNavigate() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        if (!mounted) return;
        // Ana ekrana yönlendir ve geri dönülmesini engelle (pushReplacement)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (_) {
      if (mounted) {
        _showNoInternetDialog();
      }
    }
  }

  void _showNoInternetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          "Bağlantı Hatası",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "İnternet bağlantısı bulunamadı. Lütfen bağlantınızı kontrol edip tekrar deneyin.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkInternetAndNavigate();
            },
            child: const Text(
              "Tekrar Dene",
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _bgController.dispose();
    _breathingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: _beginAlignment.value,
                end: _endAlignment.value,
                colors: [
                  Colors.black,
                  Theme.of(context).primaryColor.withOpacity(0.5),
                ],
              ),
            ),
            child: child,
          );
        },
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _animation,
                    child: ScaleTransition(
                      scale: _breathingAnimation,
                      child: Image.asset(
                        'assets/icon/oyn_music_asset.png',
                        width: 150,
                        height: 150,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _textOpacityAnimation,
                    child: const Text(
                      'OYN Music',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Text(
                'Versiyon 1.0.0',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
