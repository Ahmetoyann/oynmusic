import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/providers/theme_provider.dart';
import 'package:muzik_app/providers/auth_provider.dart';

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
      appBar: AppBar(
        title: const Text(
          'Ayarlar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        // AppBar rengi artık temadan geliyor
      ),
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
                    backgroundImage: NetworkImage(user.photoURL ?? ''),
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
                leading: const Icon(Icons.timer, color: Colors.white),
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
                leading: const Icon(Icons.delete_outline, color: Colors.red),
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
                leading: Icon(Icons.info_outline, color: textColor),
                title: Text('Versiyon', style: TextStyle(color: textColor)),
                trailing: Text('1.0.0', style: TextStyle(color: subTextColor)),
              ),
              if (authProvider.user != null) ...[
                const Divider(height: 1, color: Colors.white10),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
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

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Emin misiniz?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Tüm indirilen şarkılar ve favoriler silinecek. Bu işlem geri alınamaz.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Dialogu kapat
              try {
                await context.read<SongProvider>().clearCache();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Önbellek başarıyla temizlendi.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bir hata oluştu.')),
                  );
                }
              }
            },
            child: const Text('Temizle', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Çıkış Yap', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().signOut();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Çıkış yapıldı.')));
            },
            child: const Text('Çıkış Yap', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSleepTimerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Zamanlayıcı Ayarla',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildTimerOption(context, 15),
            _buildTimerOption(context, 30),
            _buildTimerOption(context, 45),
            _buildTimerOption(context, 60),
            if (context.read<SongProvider>().isSleepTimerActive)
              ListTile(
                leading: const Icon(Icons.timer_off, color: Colors.redAccent),
                title: const Text(
                  'Zamanlayıcıyı Kapat',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  context.read<SongProvider>().cancelSleepTimer();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Zamanlayıcı kapatıldı.')),
                  );
                },
              ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildTimerOption(BuildContext context, int minutes) {
    return ListTile(
      title: Text(
        '$minutes Dakika',
        style: const TextStyle(color: Colors.white),
      ),
      onTap: () {
        context.read<SongProvider>().setSleepTimer(minutes);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Müzik $minutes dakika sonra duracak.')),
        );
      },
    );
  }
}
