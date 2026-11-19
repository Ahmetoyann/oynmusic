import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:muzik_app/providers/auth_provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/widgets/google_logo_painter.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/language_provider.dart';
import 'package:muzik_app/pages/email_login_page.dart';
import 'package:muzik_app/pages/register_page.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:muzik_app/utils/responsive.dart';

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
    final langProvider = context.watch<LanguageProvider>();
    final isTablet = Responsive.isTabletOrLandscape(context);

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
        body: Stack(
          children: [
            SafeArea(
              child: isTablet
                  ? _buildTabletLayout(
                      context, primaryColor, langProvider, provider)
                  : _buildPhoneLayout(
                      context, primaryColor, langProvider, provider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoSection(Color primaryColor, LanguageProvider langProvider,
      {bool isTablet = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(isTablet ? 36 : 32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
            border: Border.all(
              color: primaryColor.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Image.asset(
            'assets/icon/OYN_ana_logo_seffaf.png',
            height: isTablet ? 110 : 90,
            width: isTablet ? 110 : 90,
            color: primaryColor,
          ),
        ),
        SizedBox(height: isTablet ? 24 : 28),
        Text(
          "OYN Music",
          style: TextStyle(
            fontSize: isTablet ? 36 : 32,
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
        const SizedBox(height: 10),
        Text(
          langProvider.t('slogan'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: primaryColor.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailButton(BuildContext context, LanguageProvider langProvider,
      {double? width}) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: InkWell(
            onTap: _isLoading
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const EmailLoginPage()),
                    );
                  },
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: width ?? (MediaQuery.of(context).size.width - 60),
              height: 55,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.email_outlined, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      langProvider.t('login_with_email'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton(
      BuildContext context, LanguageProvider langProvider,
      {double? width}) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _isLoading
                ? null
                : () async {
                    setState(() => _isLoading = true);
                    try {
                      final user = await context
                          .read<AuthProvider>()
                          .signInWithGoogle();
                      if (mounted && user != null) {
                        context
                            .read<SongProvider>()
                            .fetchSongsFromApi();
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      }
                    } catch (e) {
                      debugPrint("Google Sign-In Error: $e");
                    } finally {
                      if (mounted) {
                        setState(() => _isLoading = false);
                      }
                    }
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              width: width ?? (MediaQuery.of(context).size.width - 60),
              height: 55,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
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
                            Text(
                              langProvider.t('login_with_google'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
    );
  }

  Widget _buildGuestButton(BuildContext context, SongProvider provider,
      LanguageProvider langProvider) {
    return TextButton(
      onPressed: () {
        provider.continueAsGuest();
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
      child: Text(
        langProvider.t('continue_as_guest'),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildRegisterButton(BuildContext context, Color primaryColor,
      LanguageProvider langProvider) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RegisterPage()),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: primaryColor.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_add_rounded,
                  color: primaryColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  langProvider.t('register'),
                  style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneLayout(BuildContext context, Color primaryColor,
      LanguageProvider langProvider, SongProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          _buildLogoSection(primaryColor, langProvider, isTablet: false),
          const Spacer(),
          _buildEmailButton(context, langProvider),
          const SizedBox(height: 16),
          _buildGoogleButton(context, langProvider),
          const SizedBox(height: 16),
          _buildGuestButton(context, provider, langProvider),
          const SizedBox(height: 24),
          _buildRegisterButton(context, primaryColor, langProvider),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context, Color primaryColor,
      LanguageProvider langProvider, SongProvider provider) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 48.0, vertical: 40.0),
                  child: Row(
                    children: [
                      // Sol Bölüm: Marka ve Logo
                      Expanded(
                        flex: 5,
                        child: _buildLogoSection(primaryColor, langProvider,
                            isTablet: true),
                      ),
                      // İnce Dikey Ayırıcı
                      Container(
                        height: 320,
                        width: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        color: Colors.white.withOpacity(0.08),
                      ),
                      // Sağ Bölüm: Giriş İşlemleri
                      Expanded(
                        flex: 5,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildEmailButton(context, langProvider,
                                width: double.infinity),
                            const SizedBox(height: 16),
                            _buildGoogleButton(context, langProvider,
                                width: double.infinity),
                            const SizedBox(height: 16),
                            _buildGuestButton(context, provider, langProvider),
                            const SizedBox(height: 24),
                            _buildRegisterButton(
                                context, primaryColor, langProvider),
                          ],
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
    );
  }
}
