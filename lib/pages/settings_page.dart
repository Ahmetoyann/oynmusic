import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/providers/theme_provider.dart';
import 'package:muzik_app/providers/auth_provider.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:muzik_app/widgets/custom_app_bar.dart';
import 'package:muzik_app/custom_icons.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    const textColor = Colors.white;
    final subTextColor = Colors.grey.shade600;
    final user = authProvider.user;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Ayarlar', centerTitle: true),
      // Arka plan rengi artık temadan geliyor
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Profil Bölümü (Giriş yapılmışsa)
          if (user != null) ...[
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: user.photoURL != null
                        ? (user.photoURL!.startsWith('http')
                                  ? NetworkImage(user.photoURL!)
                                  : FileImage(File(user.photoURL!)))
                              as ImageProvider
                        : null,
                    backgroundColor: Colors.grey.shade800,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.displayName ?? 'Kullanıcı',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    user.email ?? '',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 2. Görünüm Ayarları
          _buildSectionHeader(context, 'Görünüm'),
          _buildSettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tema Rengi', style: TextStyle(color: textColor)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildColorOption(
                            context,
                            const Color.fromARGB(255, 101, 144, 32),
                          ), // Yeşil (Varsayılan)
                          _buildColorOption(context, Colors.blue),
                          _buildColorOption(context, Colors.red),
                          _buildColorOption(context, Colors.purple),
                          _buildColorOption(context, Colors.orange),
                          _buildColorOption(context, Colors.teal),
                          _buildColorOption(context, Colors.pink),
                          _buildColorOption(context, Colors.indigo),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Müzik Ayarları (Zamanlayıcı vb.)
          _buildSectionHeader(context, 'Müzik'),
          _buildSettingsCard(
            children: [
              ListTile(
                leading: _buildLeadingIcon(
                  Colors.orange,
                  const Icon(Icons.timer_rounded, color: Colors.orange),
                ),
                title: const Text(
                  'Uyku Zamanlayıcısı',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  context.watch<SongProvider>().isSleepTimerActive
                      ? 'Bitiş: ${_formatTime(context.watch<SongProvider>().sleepTimerEndTime!)}'
                      : 'Kapalı',
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
                onTap: () => _showSleepTimerDialog(context),
              ),
            ],
          ),

          // 3. Veri ve Depolama
          _buildSectionHeader(context, 'Veri ve Depolama'),
          _buildSettingsCard(
            children: [
              ListTile(
                leading: _buildLeadingIcon(
                  Colors.red,
                  CustomIcons.svgIcon(CustomIcons.delete, color: Colors.red),
                ),
                title: Text(
                  'Önbelleği Temizle',
                  style: TextStyle(color: textColor),
                ),
                subtitle: Text(
                  'İndirilen şarkıları ve favorileri siler.',
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
                onTap: () => _showClearCacheDialog(context),
              ),
            ],
          ),

          // 4. Uygulama Hakkında ve Çıkış
          _buildSectionHeader(context, 'Uygulama'),
          _buildSettingsCard(
            children: [
              ListTile(
                leading: _buildLeadingIcon(
                  Colors.blue,
                  const Icon(Icons.info_outline, color: Colors.blue),
                ),
                title: Text('Versiyon', style: TextStyle(color: textColor)),
                trailing: Text('1.0.0', style: TextStyle(color: subTextColor)),
              ),
              if (authProvider.user != null) ...[
                const Divider(height: 1, color: Colors.white10),
                ListTile(
                  leading: _buildLeadingIcon(
                    Colors.redAccent,
                    const Icon(Icons.logout, color: Colors.redAccent),
                  ),
                  title: Text('Çıkış Yap', style: TextStyle(color: textColor)),
                  onTap: () => _showSignOutDialog(context),
                ),
              ],
            ],
          ),
          const SizedBox(height: 30),
        ],
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

  Widget _buildSettingsCard({required List<Widget> children}) {
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
    final themeProvider = context.read<ThemeProvider>();
    final isSelected = themeProvider.primaryColor.value == color.value;

    return GestureDetector(
      onTap: () => themeProvider.setPrimaryColor(color),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) async {
    final provider = context.read<SongProvider>();
    final cacheSize = await provider.getCacheSize();

    if (!context.mounted) return;

    CustomBottomSheet.show(
      context: context,
      title: 'Emin misiniz?',
      message:
          'Tüm indirilen şarkılar ve favoriler silinecek ($cacheSize). Bu işlem geri alınamaz.',
      primaryButtonText: 'Temizle',
      primaryButtonColor: Colors.red,
      secondaryButtonText: 'İptal',
      onPrimaryButtonTap: () async {
        Navigator.pop(context);
        try {
          await context.read<SongProvider>().clearCache();
          if (context.mounted) {
            CustomSnackBar.showSuccess(
              context: context,
              message: 'Önbellek başarıyla temizlendi.',
            );
          }
        } catch (e) {
          if (context.mounted) {
            CustomSnackBar.showError(
              context: context,
              message: 'Bir hata oluştu.',
            );
          }
        }
      },
    );
  }

  void _showSignOutDialog(BuildContext context) {
    CustomBottomSheet.show(
      context: context,
      title: 'Çıkış Yap',
      message: 'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
      primaryButtonText: 'Çıkış Yap',
      primaryButtonColor: Colors.red,
      secondaryButtonText: 'İptal',
      onPrimaryButtonTap: () {
        Navigator.pop(context);
        context.read<AuthProvider>().signOut();
        CustomSnackBar.showInfo(context: context, message: 'Çıkış yapıldı.');
      },
    );
  }

  void _showSleepTimerDialog(BuildContext context) {
    CustomBottomSheet.showContent(
      context: context,
      child: Consumer<SongProvider>(
        builder: (context, provider, child) {
          return Column(
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
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: Theme.of(context).primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Uyku Zamanlayıcısı',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (provider.isSleepTimerActive &&
                  provider.sleepTimerEndTime != null) ...[
                const SizedBox(height: 8),
                Text(
                  "Kapanış: ${provider.sleepTimerEndTime!.hour.toString().padLeft(2, '0')}:${provider.sleepTimerEndTime!.minute.toString().padLeft(2, '0')}",
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
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
              ),
              const SizedBox(height: 24),
              if (provider.isSleepTimerActive)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        provider.cancelSleepTimer();
                        Navigator.pop(context);
                        CustomSnackBar.showInfo(
                          context: context,
                          message: 'Zamanlayıcı kapatıldı.',
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Zamanlayıcıyı Kapat",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModernTimerOption(BuildContext context, int minutes) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.read<SongProvider>().setSleepTimer(minutes);
          Navigator.pop(context);
          CustomSnackBar.showInfo(
            context: context,
            message: 'Müzik $minutes dakika sonra duracak.',
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: (MediaQuery.of(context).size.width - 64) / 3,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
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
              const Text(
                "dk",
                style: TextStyle(
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
}
