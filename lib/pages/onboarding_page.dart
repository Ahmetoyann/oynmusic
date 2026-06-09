import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/language_provider.dart';
import 'dart:ui';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onCompleted;

  const OnboardingPage({super.key, required this.onCompleted});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showLanguageFullScreen(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (pageContext, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Theme.of(pageContext).scaffoldBackgroundColor,
            body: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 32),
                        onPressed: () => Navigator.pop(pageContext),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.read<LanguageProvider>().t('language_selection'),
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children:
                          ['en', 'tr', 'fr', 'de', 'es', 'ar'].map((langCode) {
                        final provider = context.read<LanguageProvider>();
                        final isSelected = provider.currentLanguage == langCode;
                        String langName = '';
                        String flag = '';
                        switch (langCode) {
                          case 'en':
                            langName = 'English';
                            flag = '🇬🇧';
                            break;
                          case 'tr':
                            langName = 'Türkçe';
                            flag = '🇹🇷';
                            break;
                          case 'fr':
                            langName = 'Français';
                            flag = '🇫🇷';
                            break;
                          case 'de':
                            langName = 'Deutsch';
                            flag = '🇩🇪';
                            break;
                          case 'es':
                            langName = 'Español';
                            flag = '🇪🇸';
                            break;
                          case 'ar':
                            langName = 'العربية';
                            flag = '🇸🇦';
                            break;
                        }
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.2)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.5)
                                  : Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            leading: Container(
                              width: 40,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(flag,
                                  style: const TextStyle(fontSize: 18)),
                            ),
                            title: Text(
                              langName,
                              style: TextStyle(
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 16,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle_rounded,
                                    color: Theme.of(context).primaryColor)
                                : null,
                            onTap: () {
                              provider.setLanguage(langCode);
                              Navigator.pop(pageContext);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
              position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final langProvider = context.watch<LanguageProvider>();

    final List<Map<String, dynamic>> onboardingData = [
      {
        "title": langProvider.t('onboarding_1_title'),
        "desc": langProvider.t('onboarding_1_desc'),
        "icon": CustomIcons.trending,
        "color": const Color(0xFF6C63FF),
      },
      {
        "title": langProvider.t('onboarding_2_title'),
        "desc": langProvider.t('onboarding_2_desc'),
        "icon": CustomIcons.downloadingRounded,
        "color": const Color(0xFFFF6584),
      },
      {
        "title": langProvider.t('onboarding_3_title'),
        "desc": langProvider.t('onboarding_3_desc'),
        "icon": CustomIcons.library,
        "color": const Color(0xFF00BFA5),
      },
    ];

    final currentColor = onboardingData[_currentPage]['color'] as Color;

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
              child: Column(
                children: [
                  Align(
                    alignment: langProvider.isRTL
                        ? Alignment.topLeft
                        : Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: InkWell(
                        onTap: () => _showLanguageFullScreen(context),
                        borderRadius: BorderRadius.circular(20),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.15),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.language,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    langProvider.getCurrentLanguageName(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
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
                  Expanded(
                    flex: 3,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (value) =>
                          setState(() => _currentPage = value),
                      itemCount: onboardingData.length,
                      itemBuilder: (context, index) {
                        final data = onboardingData[index];
                        return Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(40),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: (data['color'] as Color)
                                        .withOpacity(0.3),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (data['color'] as Color)
                                          .withOpacity(0.2),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: data['icon'] is IconData
                                    ? Icon(
                                        data['icon'],
                                        size: 100,
                                        color: data['color'],
                                      )
                                    : CustomIcons.svgIcon(
                                        data['icon'],
                                        size: 100,
                                        color: data['color'],
                                      ),
                              ),
                              const SizedBox(height: 48),
                              Text(
                                data['title'],
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                data['desc'],
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade400,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        // Sayfa Göstergeleri (Dots)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            onboardingData.length,
                            (index) => GestureDetector(
                              onTap: () {
                                _pageController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                height: 8,
                                width: _currentPage == index ? 24 : 8,
                                decoration: BoxDecoration(
                                  color: _currentPage == index
                                      ? currentColor
                                      : Colors.grey.shade800,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Alt Butonlar
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 24,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (_currentPage != onboardingData.length - 1)
                                InkWell(
                                  onTap: () {
                                    _pageController.animateToPage(
                                      onboardingData.length - 1,
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(25),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      langProvider.t('skip'),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(width: 80),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: InkWell(
                                    onTap: () {
                                      if (_currentPage ==
                                          onboardingData.length - 1) {
                                        _completeOnboarding();
                                      } else {
                                        _pageController.nextPage(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeInOut,
                                        );
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(25),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      width: _currentPage ==
                                              onboardingData.length - 1
                                          ? 140
                                          : 100,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: currentColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(25),
                                        border: Border.all(
                                          color: currentColor.withOpacity(0.5),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Center(
                                        child: FittedBox(
                                          child: Text(
                                            _currentPage ==
                                                    onboardingData.length - 1
                                                ? langProvider.t('start')
                                                : langProvider.t('next'),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
