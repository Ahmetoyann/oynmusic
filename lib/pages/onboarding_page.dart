import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/language_provider.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';
import 'dart:ui';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onCompleted;

  const OnboardingPage({super.key, required this.onCompleted});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _floatController;
  late Animation<Offset> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _floatAnimation =
        Tween<Offset>(
          begin: const Offset(0, -0.05),
          end: const Offset(0, 0.05),
        ).animate(
          CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
        );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _showLanguageBottomSheet(BuildContext context) {
    CustomBottomSheet.showContent(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade700,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.read<LanguageProvider>().t('language_selection'),
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...['en', 'tr', 'fr', 'de', 'es', 'ar'].map((langCode) {
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
            return ListTile(
              leading: Container(
                width: 36,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(flag, style: const TextStyle(fontSize: 16)),
              ),
              title: Text(
                langName,
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.white,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                  : null,
              onTap: () {
                provider.setLanguage(langCode);
                Navigator.pop(context);
              },
            );
          }).toList(),
          const SizedBox(height: 16),
        ],
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

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          // Animasyonlu Arka Plan Parlaması
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.2),
                radius: 0.8,
                colors: [
                  currentColor.withOpacity(0.25),
                  const Color(0xFF121212),
                ],
              ),
            ),
          ),
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
                      onTap: () => _showLanguageBottomSheet(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.language,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
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
                            SlideTransition(
                              position: _floatAnimation,
                              child: Container(
                                padding: const EdgeInsets.all(40),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: (data['color'] as Color).withOpacity(
                                      0.3,
                                    ),
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
                              margin: const EdgeInsets.symmetric(horizontal: 4),
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
                              TextButton(
                                onPressed: () {
                                  _pageController.animateToPage(
                                    onboardingData.length - 1,
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: Text(
                                  langProvider.t('skip'),
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            else
                              const SizedBox(width: 60), // Düzen için boşluk

                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: _currentPage == onboardingData.length - 1
                                  ? 140
                                  : 100,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () {
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
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: currentColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  elevation: 5,
                                  shadowColor: currentColor.withOpacity(0.5),
                                ),
                                child: FittedBox(
                                  child: Text(
                                    _currentPage == onboardingData.length - 1
                                        ? langProvider.t('start')
                                        : langProvider.t('next'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
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
    );
  }
}
