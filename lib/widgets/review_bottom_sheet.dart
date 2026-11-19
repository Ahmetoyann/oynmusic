import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/language_provider.dart';
import 'package:muzik_app/utils/responsive.dart';

class ReviewBottomSheet {
  static Future<void> show(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    // Kullanıcı sheet açıkken kapatırsa hemen bir sonraki girişte tekrar açılmaması için sayacı sıfırla
    await prefs.setInt('app_launch_count', 0);

    if (!context.mounted) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return const _ReviewBottomSheetContent();
      },
    );

    if (result == true) {
      // Kullanıcı puan verdi / değerlendirme yaptı: bir daha asla gösterme
      await prefs.setBool('has_seen_review', true);
    } else {
      // "Daha sonra" butonuna tıkladı veya sheet'i kapattı: sonraki 2. girişte tekrar sorulsun
      await prefs.setBool('has_seen_review', false);
      await prefs.setInt('app_launch_count', 0);
    }
  }
}

class _ReviewBottomSheetContent extends StatefulWidget {
  const _ReviewBottomSheetContent();

  @override
  State<_ReviewBottomSheetContent> createState() =>
      _ReviewBottomSheetContentState();
}

class _ReviewBottomSheetContentState extends State<_ReviewBottomSheetContent> {
  int _selectedRating = 0;

  Future<void> _openGooglePlay() async {
    final uri = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.ahmed.oyn_music',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = context.watch<LanguageProvider>();
    final isWide = Responsive.isTabletOrLandscape(context);
    final borderRadius = isWide
        ? BorderRadius.circular(24)
        : const BorderRadius.vertical(top: Radius.circular(24));

    final content = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
        borderRadius: borderRadius,
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Icon / Illustration
                Icon(
                  Icons.favorite_rounded,
                  color: Theme.of(context).primaryColor,
                  size: 48,
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  langProvider.t(
                      'Uygulamamızı Sevdiniz mi?'), // Replace with proper translation key if needed later
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  langProvider.t('Bize 5 yıldız vererek destek olabilirsiniz!'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),

                // Stars
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedRating = index + 1;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          index < _selectedRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: index < _selectedRating
                              ? Colors.amber
                              : Colors.grey.shade600,
                          size: 40,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.2),
                            blurRadius: 15,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _selectedRating == 0
                              ? null
                              : () {
                                  Navigator.pop(context, true);
                                  _openGooglePlay();
                                },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                langProvider.t('rate_on_google_play'),
                                style: TextStyle(
                                  color: _selectedRating == 0
                                      ? Colors.grey.shade600
                                      : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Later Button
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    langProvider.t('later'),
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ),
      ),
    );

    if (isWide) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: content,
          ),
        ),
      );
    }
    return content;
  }
}
