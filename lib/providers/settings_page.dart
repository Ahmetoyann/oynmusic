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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey.shade600 : Colors.grey.shade600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        // AppBar rengi artık temadan geliyor
      ),
      // Arka plan rengi artık temadan geliyor
      body: ListView(
        children: [
          // Tema Modu Değiştirme
          SwitchListTile(
            title: Text('Karanlık Mod', style: TextStyle(color: textColor)),
            value: themeProvider.isDarkMode,
            onChanged: (val) {
              themeProvider.toggleTheme(val);
            },
            secondary: Icon(
              Icons.dark_mode,
              color: Theme.of(context).iconTheme.color,
            ),
          ),
          const Divider(),
          // Renk Seçimi
          ListTile(
            title: Text('Tema Rengi', style: TextStyle(color: textColor)),
            subtitle: SizedBox(
              height: 60,
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
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: Text(
              'Önbelleği Temizle',
              style: TextStyle(color: textColor),
            ),
            subtitle: Text(
              'İndirilen şarkıları ve favorileri siler.',
              style: TextStyle(color: subTextColor),
            ),
            onTap: () => _showClearCacheDialog(context),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.info_outline, color: textColor),
            title: Text(
              'Uygulama Hakkında',
              style: TextStyle(color: textColor),
            ),
            subtitle: Text(
              'Versiyon 1.0.0',
              style: TextStyle(color: subTextColor),
            ),
          ),
          if (authProvider.user != null) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: Text('Çıkış Yap', style: TextStyle(color: textColor)),
              subtitle: Text(
                '${authProvider.user?.email}',
                style: TextStyle(color: subTextColor),
              ),
              onTap: () => _showSignOutDialog(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildColorOption(BuildContext context, Color color) {
    final themeProvider = context.read<ThemeProvider>();
    final isSelected = themeProvider.primaryColor.value == color.value;

    return GestureDetector(
      onTap: () => themeProvider.setPrimaryColor(color),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 2,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
        title: Text(
          'Emin misiniz?',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Text(
          'Tüm indirilen şarkılar ve favoriler silinecek. Bu işlem geri alınamaz.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
        title: Text(
          'Çıkış Yap',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Text(
          'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
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
}
