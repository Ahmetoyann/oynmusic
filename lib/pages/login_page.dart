import 'package:flutter/material.dart';
import 'package:muzik_app/providers/auth_provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/widgets/google_logo_painter.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SongProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Logo veya İkon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/icon/oyn_music_asset.png',
                  height: 130,
                  width: 130,
                ),
              ),
              const SizedBox(height: 20),

              Text(
                "OYN Music",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.white.withValues(alpha: 0.5),
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Müziğin ritmini keşfet",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),

              const Spacer(),

              // Google Giriş Butonu
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        setState(() {
                          _isLoading = true;
                        });
                        try {
                          await context.read<AuthProvider>().signInWithGoogle();
                          // Google girişi başarılı olduğunda, müzik verilerini çekmek için
                          // verileri yeniliyoruz
                          if (mounted) {
                            context.read<SongProvider>().fetchSongsFromApi();
                          }
                        } catch (e) {
                          debugPrint("Google Sign-In Error: $e");
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isLoading = false;
                            });
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(24, 24),
                            painter: GoogleLogoPainter(),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "Google ile Bağlan",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 16),

              // Giriş Yapmadan Devam Et (Opsiyonel)
              TextButton(
                onPressed: () {
                  provider.continueAsGuest();
                },
                child: Text(
                  "Giriş yapmadan devam et",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
