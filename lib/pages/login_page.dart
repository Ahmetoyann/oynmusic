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
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.black, // veya ikonun baskın rengi
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Logo veya İkon
              Image.asset(
                'assets/icon/oyn_yenii_ikon.png',
                height: 130,
                width: 130,
                color: primaryColor,
              ),
              const SizedBox(height: 20),

              Text(
                "OYN Music",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: primaryColor,
                  letterSpacing: 1.5,
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: primaryColor.withValues(alpha: 0.3),
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Müziğin ritmini keşfet",
                style: TextStyle(
                  fontSize: 16,
                  color: primaryColor.withValues(alpha: 0.7),
                ),
              ),

              const Spacer(),

              // Google Giriş Butonu
              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  width: _isLoading
                      ? 55
                      : MediaQuery.of(context).size.width - 60,
                  height: 55,
                  decoration: BoxDecoration(
                    color: _isLoading ? Colors.grey.shade800 : Colors.white,
                    borderRadius: BorderRadius.circular(_isLoading ? 50 : 12),
                    boxShadow: _isLoading
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(_isLoading ? 50 : 12),
                      onTap: _isLoading
                          ? null
                          : () async {
                              setState(() => _isLoading = true);
                              try {
                                await context
                                    .read<AuthProvider>()
                                    .signInWithGoogle();
                                if (mounted) {
                                  context
                                      .read<SongProvider>()
                                      .fetchSongsFromApi();
                                }
                              } catch (e) {
                                debugPrint("Google Sign-In Error: $e");
                              } finally {
                                if (mounted) {
                                  setState(() => _isLoading = false);
                                }
                              }
                            },
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
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
                      ),
                    ),
                  ),
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
                  style: TextStyle(color: Colors.white),
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
