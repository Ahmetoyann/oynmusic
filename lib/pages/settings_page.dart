import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/providers/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:muzik_app/providers/theme_provider.dart';
import 'package:muzik_app/providers/language_provider.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:muzik_app/widgets/custom_app_bar.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/widgets/mini_player.dart';
import 'package:muzik_app/pages/player_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<PackageInfo> _packageInfoFuture;

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final languageProvider = context.watch<LanguageProvider>();
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    const textColor = Colors.white;
    final subTextColor = Colors.grey.shade600;

    return Scaffold(
      extendBody: true,
      appBar: CustomAppBar(
        title: languageProvider.t('settings'),
        centerTitle: true,
      ),
      bottomNavigationBar: context.watch<SongProvider>().currentSong != null
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF121212).withOpacity(
                      1,
                    ), // İçeriklerin arkadan flulaşarak görünmesi için şeffaflaştırıldı

                    const Color(0xFF121212).withOpacity(0.8),
                    const Color(0xFF121212).withOpacity(0.4),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 0.8, 1.0],
                ),
              ),
              child: SafeArea(
                bottom: true,
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => PlayerPage.show(context),
                      child: const MiniPlayer(),
                    ),
                    const SizedBox(height: 2),
                  ],
                ),
              ),
            )
          : null,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          (context.watch<SongProvider>().currentSong != null ? 160.0 : 40.0) +
              MediaQuery.of(context).padding.bottom,
        ),
        children: [
          // Dil Ayarları
          _buildSectionHeader(context, languageProvider.t('language')),
          _buildSettingsCard(
            context,
            children: [
              ListTile(
                leading: _buildLeadingIcon(
                  Colors.blueGrey,
                  const Icon(
                    Icons.language_rounded,
                    color: Colors.blueGrey,
                    size: 24,
                  ),
                ),
                title: Text(
                  languageProvider.t('language'),
                  style: const TextStyle(color: textColor),
                ),
                subtitle: Text(
                  languageProvider.getCurrentLanguageName(),
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.grey.shade600,
                  size: 14,
                ),
                onTap: () => _showLanguageFullScreen(context),
              ),
            ],
          ),

          // 1. Görünüm Ayarları
          _buildSectionHeader(
            context,
            languageProvider.t('appearance') ?? 'Görünüm',
          ),
          _buildSettingsCard(
            context,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildLeadingIcon(
                          Theme.of(context).primaryColor,
                          Icon(
                            Icons.color_lens_rounded,
                            color: Theme.of(context).primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                languageProvider.t('theme_color'),
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                languageProvider.t('theme_color_desc'),
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 60,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildColorOption(context, Colors.white),
                          _buildColorOption(context, Colors.amber),
                          _buildColorOption(context, Colors.green),
                          _buildColorOption(context, Colors.teal),
                          _buildColorOption(context, Colors.cyan),
                          _buildColorOption(context, Colors.lightBlue),
                          _buildColorOption(context, Colors.blue),
                          _buildColorOption(context, Colors.indigo),
                          _buildColorOption(context, Colors.deepPurple),
                          _buildColorOption(context, Colors.purple),
                          _buildColorOption(context, Colors.pink),
                          _buildColorOption(context, Colors.red),
                          _buildColorOption(context, const Color(0xFF8B0000)),
                          _buildColorOption(context, Colors.deepOrange),
                          _buildColorOption(context, Colors.orange),
                          _buildColorOption(
                            context,
                            const Color.fromARGB(255, 101, 144, 32),
                          ),
                          _buildColorOption(context, Colors.yellow),
                          _buildColorOption(context, Colors.brown),
                          _buildColorOption(context, Colors.blueGrey),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 2. Müzik Ayarları
          _buildSectionHeader(context, languageProvider.t('music')),
          _buildSettingsCard(
            context,
            children: [
              ListTile(
                leading: _buildLeadingIcon(
                  Colors.orange,
                  CustomIcons.svgIcon(
                    CustomIcons.timerRounded,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                title: Text(
                  languageProvider.t('sleep_timer'),
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  context.watch<SongProvider>().isSleepTimerActive
                      ? 'Bitiş: ${_formatTime(context.watch<SongProvider>().sleepTimerEndTime!)}'
                      : languageProvider.t('off'),
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.grey.shade600,
                  size: 14,
                ),
                onTap: () => _showSleepTimerFullScreen(context),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  height: 1,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
              Consumer<SongProvider>(
                builder: (context, provider, child) {
                  return SwitchListTile(
                    secondary: _buildLeadingIcon(
                      Colors.blueAccent,
                      const Icon(
                        Icons.data_usage_rounded,
                        color: Colors.blueAccent,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      languageProvider.t('data_saver'),
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      languageProvider.t('data_saver_desc'),
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                    value: provider.isLowDataMode,
                    activeColor: Theme.of(context).primaryColor,
                    onChanged: (bool value) {
                      provider.toggleLowDataMode(value);
                    },
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  height: 1,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
              ListTile(
                leading: _buildLeadingIcon(
                  Colors.purpleAccent,
                  const Icon(
                    Icons.equalizer_rounded,
                    color: Colors.purpleAccent,
                    size: 24,
                  ),
                ),
                title: Text(
                  languageProvider.t('equalizer'),
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  languageProvider.t('equalizer_desc'),
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.grey.shade600,
                  size: 14,
                ),
                onTap: () => _showEqualizerFullScreen(context),
              ),
            ],
          ),

          // 3. Veri ve Depolama
          _buildSectionHeader(context, languageProvider.t('data_storage')),
          _buildSettingsCard(
            context,
            children: [
              Consumer<SongProvider>(
                builder: (context, provider, child) {
                  return SwitchListTile(
                    secondary: _buildLeadingIcon(
                      Colors.teal,
                      const Icon(
                        Icons.wifi_rounded,
                        color: Colors.teal,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      languageProvider.t('download_wifi_only'),
                      style: const TextStyle(color: Colors.white),
                    ),
                    value: provider.downloadWifiOnly,
                    activeColor: Theme.of(context).primaryColor,
                    onChanged: (bool value) {
                      provider.setDownloadWifiOnly(value);
                    },
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  height: 1,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
              ListTile(
                leading: _buildLeadingIcon(
                  Colors.indigoAccent,
                  const Icon(
                    Icons.high_quality_rounded,
                    color: Colors.indigoAccent,
                    size: 24,
                  ),
                ),
                title: Text(
                  languageProvider.t('download_quality'),
                  style: TextStyle(color: textColor),
                ),
                subtitle: Text(
                  _getQualityText(context.watch<SongProvider>().downloadQuality,
                      languageProvider),
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.grey.shade600,
                  size: 14,
                ),
                onTap: () => _showDownloadQualityFullScreen(context),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  height: 1,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
              ListTile(
                leading: _buildLeadingIcon(
                  Colors.orange,
                  const Icon(
                    Icons.cleaning_services_rounded,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                title: Text(
                  languageProvider.t('clear_search_cache'),
                  style: TextStyle(color: textColor),
                ),
                subtitle: Text(
                  languageProvider.t('clear_search_cache_desc'),
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.grey.shade600,
                  size: 14,
                ),
                onTap: () => _showClearApiCacheDialog(context),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  height: 1,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
              ListTile(
                leading: _buildLeadingIcon(
                  Colors.red,
                  CustomIcons.svgIcon(CustomIcons.delete, color: Colors.red),
                ),
                title: Text(
                  languageProvider.t('clear_cache'),
                  style: TextStyle(color: textColor),
                ),
                subtitle: Text(
                  languageProvider.t('clear_cache_desc'),
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.grey.shade600,
                  size: 14,
                ),
                onTap: () => _showClearCacheDialog(context),
              ),
            ],
          ),

          // 4. Hesap Ayarları (Sadece giriş yapmış e-posta kullanıcıları için)
          if (user != null &&
              user.email != null &&
              user.providerData
                  .any((info) => info.providerId == 'password')) ...[
            _buildSectionHeader(
              context,
              languageProvider.currentLanguage == 'tr' ? 'Hesap' : 'Account',
            ),
            _buildSettingsCard(
              context,
              children: [
                ListTile(
                  leading: _buildLeadingIcon(
                    Colors.blueAccent,
                    const Icon(
                      Icons.lock_reset_rounded,
                      color: Colors.blueAccent,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    languageProvider.t('change_password'),
                    style: const TextStyle(color: textColor),
                  ),
                  subtitle: Text(
                    languageProvider.t('change_password_desc'),
                    style: TextStyle(color: subTextColor, fontSize: 12),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.grey.shade600,
                    size: 14,
                  ),
                  onTap: () {
                    CustomBottomSheet.show(
                      context: context,
                      title: languageProvider.t('change_password'),
                      message: languageProvider.currentLanguage == 'tr'
                          ? 'Şifre sıfırlama bağlantısı e-posta adresinize (${user.email}) gönderilecektir. Onaylıyor musunuz?'
                          : 'A password reset link will be sent to your email address (${user.email}). Do you confirm?',
                      primaryButtonText:
                          languageProvider.currentLanguage == 'tr'
                              ? 'Evet, Gönder'
                              : 'Yes, Send',
                      primaryButtonColor: Colors.blueAccent,
                      secondaryButtonText: languageProvider.t('cancel'),
                      onPrimaryButtonTap: () async {
                        Navigator.pop(context); // Önce onay penceresini kapat
                        try {
                          await authProvider.resetPassword(user.email!);
                          if (context.mounted) {
                            CustomSnackBar.showSuccess(
                              context: context,
                              message: languageProvider.t('reset_link_sent'),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            CustomSnackBar.showError(
                              context: context,
                              message:
                                  e.toString().replaceAll('Exception: ', ''),
                            );
                          }
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ],

          // 5. Uygulama Hakkında
          _buildSectionHeader(context, languageProvider.t('app')),
          _buildSettingsCard(
            context,
            children: [
              ListTile(
                leading: _buildLeadingIcon(
                  Colors.black,
                  Image.asset(
                    'assets/icon/OYN_ana_logo_seffaf.png',
                    width: 24,
                    height: 24,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                title: Text(
                  languageProvider.t('app_version'),
                  style: const TextStyle(color: textColor),
                ),
                trailing: FutureBuilder<PackageInfo>(
                  future: _packageInfoFuture,
                  builder: (context, snapshot) {
                    final version =
                        snapshot.hasData ? snapshot.data!.version : '...';
                    return Text(
                      version,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
              const _UpdateCheckButton(),
            ],
          ),
        ],
      ),
    );
  }

  void _showLanguageFullScreen(BuildContext context) {
    final provider = context.read<LanguageProvider>();
    String selectedLanguage = provider.currentLanguage;

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (pageContext, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Theme.of(pageContext).scaffoldBackgroundColor,
            body: SafeArea(
              child: StatefulBuilder(
                builder: (context, setState) {
                  final primaryColor = Theme.of(context).primaryColor;

                  Widget buildLangOption(
                      String code, String name, String flag) {
                    final isSelected = selectedLanguage == code;
                    return GestureDetector(
                      onTap: () {
                        setState(() => selectedLanguage = code);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor.withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? primaryColor.withOpacity(0.5)
                                : Colors.white.withOpacity(0.1),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryColor.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(flag,
                                  style: const TextStyle(fontSize: 20)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  color:
                                      isSelected ? primaryColor : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded,
                                  color: primaryColor, size: 24),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
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
                      const SizedBox(height: 8),
                      Icon(Icons.language_rounded,
                          size: 64, color: primaryColor),
                      const SizedBox(height: 16),
                      Text(
                        provider.t('language_selection'),
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          physics: const BouncingScrollPhysics(),
                          children: [
                            buildLangOption('en', 'English', '🇬🇧'),
                            buildLangOption('tr', 'Türkçe', '🇹🇷'),
                            buildLangOption('fr', 'Français', '🇫🇷'),
                            buildLangOption('de', 'Deutsch', '🇩🇪'),
                            buildLangOption('es', 'Español', '🇪🇸'),
                            buildLangOption('ar', 'العربية', '🇸🇦'),
                            const SizedBox(height: 40),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: InkWell(
                                    onTap: () async {
                                      provider.setLanguage(selectedLanguage);
                                      pageContext
                                          .read<SongProvider>()
                                          .rescheduleAllNotifications();
                                      Navigator.pop(pageContext);
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: primaryColor.withOpacity(0.5),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          provider.t('save'),
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
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  );
                },
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

  String _getQualityText(String quality, LanguageProvider langProvider) {
    switch (quality) {
      case 'low':
        return langProvider.t('quality_low');
      case 'medium':
        return langProvider.t('quality_medium');
      case 'high':
      default:
        return langProvider.t('quality_high');
    }
  }

  void _showDownloadQualityFullScreen(BuildContext context) {
    final provider = context.read<SongProvider>();
    final langProvider = context.read<LanguageProvider>();
    String selectedQuality = provider.downloadQuality;

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (pageContext, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Theme.of(pageContext).scaffoldBackgroundColor,
            body: SafeArea(
              child: StatefulBuilder(
                builder: (context, setState) {
                  final primaryColor = Theme.of(context).primaryColor;

                  Widget buildQualityOption(String code, String title,
                      String subtitle, IconData icon) {
                    final isSelected = selectedQuality == code;
                    return GestureDetector(
                      onTap: () => setState(() => selectedQuality = code),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor.withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? primaryColor.withOpacity(0.5)
                                : Colors.white.withOpacity(0.1),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(icon,
                                color:
                                    isSelected ? primaryColor : Colors.white70,
                                size: 32),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      color: isSelected
                                          ? primaryColor
                                          : Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded,
                                  color: primaryColor, size: 24),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
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
                      const SizedBox(height: 8),
                      Icon(Icons.high_quality_rounded,
                          size: 64, color: primaryColor),
                      const SizedBox(height: 16),
                      Text(
                        langProvider.t('download_quality'),
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          langProvider.currentLanguage == 'tr'
                              ? "Bu ayar MP3 indirmelerinde ses kalitesini (Bitrate), MP4 video indirmelerinde ise görüntü çözünürlüğünü (1080p, 720p, 480p) belirler."
                              : "This setting determines the audio quality (Bitrate) for MP3 downloads, and the video resolution (1080p, 720p, 480p) for MP4 downloads.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                              height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          physics: const BouncingScrollPhysics(),
                          children: [
                            buildQualityOption(
                              'high',
                              langProvider.currentLanguage == 'tr'
                                  ? 'Yüksek Kalite'
                                  : 'High Quality',
                              '1080p / 320kbps',
                              Icons.hd_rounded,
                            ),
                            buildQualityOption(
                              'medium',
                              langProvider.currentLanguage == 'tr'
                                  ? 'Orta Kalite'
                                  : 'Medium Quality',
                              '720p / 192kbps',
                              Icons.sd_rounded,
                            ),
                            buildQualityOption(
                              'low',
                              langProvider.currentLanguage == 'tr'
                                  ? 'Düşük Kalite'
                                  : 'Low Quality',
                              '480p / 128kbps',
                              Icons.data_saver_on_rounded,
                            ),
                            const SizedBox(height: 40),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: InkWell(
                                    onTap: () async {
                                      provider
                                          .setDownloadQuality(selectedQuality);
                                      Navigator.pop(pageContext);
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: primaryColor.withOpacity(0.5),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          langProvider.t('save') ??
                                              (langProvider.currentLanguage ==
                                                      'tr'
                                                  ? 'Kaydet'
                                                  : 'Save'),
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
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  );
                },
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

  Widget _buildLeadingIcon(Color color, Widget icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: icon,
    );
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 16),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildColorOption(BuildContext context, Color color) {
    final themeProvider = context.watch<ThemeProvider>();
    final isSelected = themeProvider.primaryColor.value == color.value;

    return GestureDetector(
      onTap: () => context.read<ThemeProvider>().setPrimaryColor(color),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        margin: const EdgeInsets.only(right: 16),
        width: isSelected ? 48 : 40,
        height: isSelected ? 48 : 40,
        padding: EdgeInsets.all(isSelected ? 3 : 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: isSelected
              ? Center(
                  child: Icon(
                    Icons.check_rounded,
                    color: color == Colors.white ? Colors.black : Colors.white,
                    size: 20,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) async {
    final provider = context.read<SongProvider>();
    final langProvider = context.read<LanguageProvider>();
    final cacheSize = await provider.getCacheSize();

    if (!context.mounted) return;

    CustomBottomSheet.show(
      context: context,
      title: langProvider.t('are_you_sure'),
      message: '${langProvider.t('clear_cache_warning')} ($cacheSize)',
      primaryButtonText: langProvider.t('clear'),
      primaryButtonColor: Colors.red,
      secondaryButtonText: langProvider.t('cancel'),
      onPrimaryButtonTap: () async {
        Navigator.pop(context);
        try {
          await context.read<SongProvider>().clearCache();
          if (context.mounted) {
            CustomSnackBar.showSuccess(
              context: context,
              message: langProvider.t('cache_cleared'),
            );
          }
        } catch (e) {
          if (context.mounted) {
            CustomSnackBar.showError(
              context: context,
              message: langProvider.t('an_error_occurred'),
            );
          }
        }
      },
    );
  }

  void _showClearApiCacheDialog(BuildContext context) {
    final langProvider = context.read<LanguageProvider>();
    CustomBottomSheet.show(
      context: context,
      title: langProvider.t('clear_api_cache_title'),
      message: langProvider.t('clear_api_cache_warning'),
      primaryButtonText: langProvider.t('clear'),
      primaryButtonColor: Colors.orange,
      secondaryButtonText: langProvider.t('cancel'),
      onPrimaryButtonTap: () async {
        Navigator.pop(context);
        try {
          await context.read<SongProvider>().clearApiCache();
          if (context.mounted) {
            CustomSnackBar.showSuccess(
              context: context,
              message: langProvider.t('api_cache_cleared'),
            );
          }
        } catch (e) {
          if (context.mounted) {
            CustomSnackBar.showError(
              context: context,
              message: langProvider.t('an_error_occurred'),
            );
          }
        }
      },
    );
  }

  void _showSleepTimerFullScreen(BuildContext context) {
    final langProvider = context.read<LanguageProvider>();

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (pageContext, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Theme.of(pageContext).scaffoldBackgroundColor,
            body: SafeArea(
              child: Consumer<SongProvider>(
                builder: (context, provider, child) {
                  final primaryColor = Theme.of(context).primaryColor;
                  return Column(
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
                      const SizedBox(height: 8),
                      Icon(Icons.timer_rounded, size: 64, color: primaryColor),
                      const SizedBox(height: 16),
                      Text(
                        langProvider.t('sleep_timer'),
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (provider.isSleepTimerActive &&
                          provider.sleepTimerEndTime != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          "Kapanış: ${provider.sleepTimerEndTime!.hour.toString().padLeft(2, '0')}:${provider.sleepTimerEndTime!.minute.toString().padLeft(2, '0')}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          physics: const BouncingScrollPhysics(),
                          children: [
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              alignment: WrapAlignment.center,
                              children: [
                                _buildModernTimerOption(context, 15),
                                _buildModernTimerOption(context, 30),
                                _buildModernTimerOption(context, 45),
                                _buildModernTimerOption(context, 60),
                                _buildModernTimerOption(context, 90),
                                _buildModernTimerOption(context, 120),
                              ],
                            ),
                            const SizedBox(height: 40),
                            if (provider.isSleepTimerActive)
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 10, sigmaY: 10),
                                    child: InkWell(
                                      onTap: () {
                                        provider.cancelSleepTimer();
                                        Navigator.pop(pageContext);
                                        CustomSnackBar.showInfo(
                                          context: context,
                                          message:
                                              langProvider.t('timer_canceled'),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color:
                                              Colors.redAccent.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.redAccent
                                                .withOpacity(0.5),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            langProvider.t('cancel'),
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
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  );
                },
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

  Widget _buildModernTimerOption(BuildContext context, int minutes) {
    final langProvider = context.read<LanguageProvider>();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.read<SongProvider>().setSleepTimer(minutes);
          Navigator.pop(context);
          CustomSnackBar.showInfo(
            context: context,
            message: langProvider
                .t('timer_set')
                .replaceAll('%s', minutes.toString()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: (MediaQuery.of(context).size.width - 80) / 3,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Text(
                "$minutes",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                langProvider.t('duration').substring(
                      0,
                      2,
                    ), // "Süre" kelimesinin ilk 2 harfi (Sü) veya çeviriye göre değişir
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEqualizerFullScreen(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (pageContext, animation, secondaryAnimation) {
          return const _EqualizerFullScreen();
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
}

class _UpdateCheckButton extends StatefulWidget {
  const _UpdateCheckButton();

  @override
  State<_UpdateCheckButton> createState() => _UpdateCheckButtonState();
}

class _UpdateCheckButtonState extends State<_UpdateCheckButton> {
  late Future<bool> _updateCheckFuture;

  @override
  void initState() {
    super.initState();
    // Gelecekteki işlem sadece bir kere başlatılır (Ayarlar sayfası kaydırıldığında tekrar Firestore okunmasını engeller)
    _updateCheckFuture = _checkIfUpdateAvailable();
  }

  Future<bool> _checkIfUpdateAvailable() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // Örn: 1.0.0

      final doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('config')
          .get(
            const GetOptions(source: Source.server),
          ); // Önbelleği yoksayıp zorunlu olarak taze veriyi sunucudan çeker
      if (doc.exists && doc.data() != null) {
        final latestVersion = doc.data()!['latest_version'] as String?;
        debugPrint(
          "👉 Cihazdaki Sürüm: $currentVersion | Firebase'deki Sürüm: $latestVersion",
        );

        if (latestVersion != null && latestVersion.isNotEmpty) {
          // Versiyonları '.' bazında ayır ve numara olarak kıyasla
          final currentParts = currentVersion
              .split('.')
              .map((e) => int.tryParse(e) ?? 0)
              .toList();
          final latestParts = latestVersion
              .split('.')
              .map((e) => int.tryParse(e) ?? 0)
              .toList();

          for (int i = 0; i < latestParts.length; i++) {
            final c = i < currentParts.length ? currentParts[i] : 0;
            final l = latestParts[i];
            if (l > c)
              return true; // Firestore'daki versiyon cihazdakinden daha büyük
            if (l < c) return false;
          }
        }
      }
    } catch (e) {
      debugPrint("Güncelleme kontrol hatası: $e");
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _updateCheckFuture,
      builder: (context, snapshot) {
        bool hasUpdate = snapshot.data ?? false;

        // Güncelleme yoksa hiçbir şey çizmeden widget'ı daralt
        if (!hasUpdate) return const SizedBox.shrink();

        final languageProvider = context.watch<LanguageProvider>();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, color: Colors.white.withOpacity(0.05)),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.greenAccent.withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.2),
                          blurRadius: 15,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          const storeUrl =
                              'https://play.google.com/store/apps/details?id=com.ahmed.oyn_music';
                          final uri = Uri.parse(storeUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            if (context.mounted) {
                              CustomSnackBar.showError(
                                context: context,
                                message: "Mağaza linki açılamadı.",
                              );
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.system_update_rounded,
                                color: Colors.greenAccent,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                languageProvider.currentLanguage == 'tr'
                                    ? 'Yeni Güncelleme Mevcut'
                                    : 'New Update Available',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
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
            ),
          ],
        );
      },
    );
  }
}

class _EqualizerFullScreen extends StatefulWidget {
  const _EqualizerFullScreen();

  @override
  State<_EqualizerFullScreen> createState() => _EqualizerFullScreenState();
}

class _EqualizerFullScreenState extends State<_EqualizerFullScreen> {
  late bool _isEnabled;
  late List<double> _values;
  final List<String> _freqs = ['60Hz', '230Hz', '910Hz', '3.6kHz', '14kHz'];

  @override
  void initState() {
    super.initState();
    final provider = context.read<SongProvider>();
    _isEnabled = provider.isEqualizerEnabled;
    _values = List.from(provider.equalizerValues);
  }

  void _saveToProvider() {
    context.read<SongProvider>().updateEqualizerSettings(_isEnabled, _values);
  }

  void _reset() {
    setState(() {
      _values = [0.0, 0.0, 0.0, 0.0, 0.0];
    });
    _saveToProvider();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final langProvider = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Icon(Icons.equalizer_rounded, size: 64, color: primaryColor),
            const SizedBox(height: 16),
            Text(
              langProvider.t('equalizer'),
              style: TextStyle(
                color: primaryColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                physics: const BouncingScrollPhysics(),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isEnabled
                            ? langProvider.t('custom_setting')
                            : langProvider.t('off'),
                        style: TextStyle(
                          color:
                              _isEnabled ? primaryColor : Colors.grey.shade500,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Switch(
                        value: _isEnabled,
                        activeColor: primaryColor,
                        onChanged: (val) {
                          setState(() => _isEnabled = val);
                          _saveToProvider();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 300,
                    padding:
                        const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (index) {
                        return Column(
                          children: [
                            Text(
                              _values[index] > 0
                                  ? "+${_values[index].toInt()}dB"
                                  : "${_values[index].toInt()}dB",
                              style: TextStyle(
                                color: _isEnabled
                                    ? Colors.white
                                    : Colors.grey.shade700,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 6,
                                    activeTrackColor: _isEnabled
                                        ? primaryColor
                                        : Colors.grey.shade800,
                                    inactiveTrackColor: _isEnabled
                                        ? Colors.white.withOpacity(0.08)
                                        : Colors.white.withOpacity(0.02),
                                    thumbColor: _isEnabled
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                    overlayColor: primaryColor.withOpacity(0.2),
                                    trackShape:
                                        const RoundedRectSliderTrackShape(),
                                  ),
                                  child: Slider(
                                    value: _values[index],
                                    min: -15,
                                    max: 15,
                                    divisions: 30,
                                    onChanged: _isEnabled
                                        ? (val) {
                                            setState(() {
                                              _values[index] = val;
                                            });
                                          }
                                        : null,
                                    onChangeEnd: _isEnabled
                                        ? (val) => _saveToProvider()
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _freqs[index],
                              style: TextStyle(
                                color: _isEnabled
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade700,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (_isEnabled)
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: InkWell(
                            onTap: _reset,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: primaryColor.withOpacity(0.5),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  langProvider.t('reset'),
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
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
