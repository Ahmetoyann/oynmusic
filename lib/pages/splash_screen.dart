import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:muzik_app/main.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:url_launcher/url_launcher.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _textOpacityAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _sloganOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // 1. Logo Scale & Opacity (0.0 - 0.6)
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // 2. Text Slide & Fade (0.5 - 0.8)
    _textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.8, curve: Curves.easeIn),
      ),
    );

    _textSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.8, curve: Curves.easeOut),
      ),
    );

    // 3. Slogan Animasyonu (0.7 - 1.0)
    _sloganOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _checkUpdateAndNavigate();
      });
    });
  }

  Future<void> _checkUpdateAndNavigate() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(
            hours: 1,
          ), // Canlıda 1 saat idealdir. Test ederken 0 yapabilirsiniz.
        ),
      );

      // Firebase'e ulaşılamazsa kullanılacak varsayılan değerler
      await remoteConfig.setDefaults({
        "latest_version": "1.0.0",
        "force_update": false,
        "update_message":
            "Uygulamamızın yeni bir sürümü yayınlandı! Daha iyi bir deneyim için lütfen güncelleyin.",
        "store_url":
            "https://play.google.com/store/apps/details?id=com.ahmed.oyn_music",
      });

      await remoteConfig.fetchAndActivate();

      final requiredVersion = remoteConfig.getString('latest_version');
      final forceUpdate = remoteConfig.getBool('force_update');
      final updateMessage = remoteConfig.getString('update_message');
      final storeUrl = remoteConfig.getString('store_url');

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // Örn: "1.0.0"

      if (_isUpdateRequired(currentVersion, requiredVersion)) {
        if (mounted) {
          _showUpdateDialog(updateMessage, storeUrl, forceUpdate);
        }
        if (forceUpdate)
          return; // Zorunlu güncelleme ise ana ekrana (AuthWrapper) geçişi engelle!
      }
    } catch (e) {
      debugPrint("Güncelleme kontrolü başarısız: $e");
    }

    _navigateToHome(); // Güncelleme gerekmiyorsa veya hata olduysa normal akışa devam et
  }

  bool _isUpdateRequired(String current, String required) {
    final currentParts = current.split('.').map(int.parse).toList();
    final requiredParts = required.split('.').map(int.parse).toList();

    for (int i = 0; i < requiredParts.length; i++) {
      if (i >= currentParts.length) return true;
      if (requiredParts[i] > currentParts[i]) return true;
      if (requiredParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  void _showUpdateDialog(String message, String url, bool isForced) {
    showDialog(
      context: context,
      barrierDismissible: !isForced, // Zorunluysa dışarı tıklanarak kapatılamaz
      builder: (context) {
        return PopScope(
          canPop: !isForced, // Zorunluysa geri tuşuyla kapatılamaz
          child: AlertDialog(
            backgroundColor: Colors.grey.shade900,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.system_update_rounded,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Güncelleme Mevcut',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
            content: Text(
              message,
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
            actions: [
              if (!isForced)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToHome(); // Zorunlu değilse menüyü kapatıp uygulamaya devam et
                  },
                  child: const Text(
                    'Daha Sonra',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    ); // Cihazın varsayılan tarayıcısını/marketini açar
                  }
                },
                child: const Text('Güncelle'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AuthWrapper(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacityAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        decoration: BoxDecoration(shape: BoxShape.circle),
                        child: Image.asset(
                          'assets/icon/OYN_ana_logo_seffaf.png',
                          height: 160,
                          width: 160,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              SlideTransition(
                position: _textSlideAnimation,
                child: FadeTransition(
                  opacity: _textOpacityAnimation,
                  child: Text(
                    "OYN Music",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(
                          blurRadius: 10.0,
                          color: primaryColor.withOpacity(0.3),
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FadeTransition(
                opacity: _sloganOpacityAnimation,
                child: Text(
                  "Müziğin Ritmi",
                  style: TextStyle(
                    fontSize: 16,
                    color: primaryColor.withOpacity(0.7),
                    letterSpacing: 4,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
