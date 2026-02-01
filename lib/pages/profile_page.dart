import 'package:flutter/material.dart';
import 'package:muzik_app/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/pages/folder_detail_page.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(title: const Text("Profil")),
      body: user == null
          ? Center(child: _buildLoginButton(context, authProvider))
          : _buildUserProfile(context, authProvider, user),
    );
  }

  // Giriş Yapılmamışsa Gösterilecek Kutu
  Widget _buildLoginButton(BuildContext context, AuthProvider provider) {
    if (_isLoading) {
      return const CircularProgressIndicator();
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
        const SizedBox(height: 24),
        const Text(
          "Devam etmek için giriş yapın",
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              elevation: 1,
            ),
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });
              try {
                final user = await provider.signInWithGoogle();
                if (mounted) {
                  setState(() => _isLoading = false);
                  if (user != null) {
                    Navigator.pop(context); // Başarılı olursa sayfayı kapat
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Hoş geldin, ${user.displayName}!"),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Giriş başarısız: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset('assets/icon/google_logo.svg', height: 20),
                const SizedBox(width: 12),
                const Text(
                  'Google ile Giriş Yap',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Giriş Yapılmışsa Gösterilecek Profil
  Widget _buildUserProfile(
    BuildContext context,
    AuthProvider provider,
    dynamic user,
  ) {
    final songProvider = context.watch<SongProvider>();
    final folders = songProvider.folders;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 50,
            backgroundImage: NetworkImage(user.photoURL ?? ''),
            backgroundColor: Colors.grey.shade800,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                user.displayName ?? "Kullanıcı",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                onPressed: () =>
                    _showEditNameDialog(context, provider, user.displayName),
              ),
            ],
          ),
          Text(user.email ?? "", style: TextStyle(color: Colors.grey.shade400)),
          const SizedBox(height: 32),

          // Çalma Listeleri Bölümü
          if (folders.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Çalma Listelerim (${folders.length})",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                return Card(
                  color: Colors.grey.shade900,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.music_note, color: Colors.grey),
                    title: Text(
                      folder.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '${folder.songs.length} şarkı',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              FolderDetailPage(folder: folder),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],

          ElevatedButton.icon(
            onPressed: () => provider.signOut(),
            icon: const Icon(Icons.logout),
            label: const Text("Çıkış Yap"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showEditNameDialog(
    BuildContext context,
    AuthProvider provider,
    String? currentName,
  ) {
    final TextEditingController controller = TextEditingController(
      text: currentName,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          "İsmi Düzenle",
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Yeni isim",
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await provider.updateDisplayName(controller.text.trim());
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text("Kaydet", style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }
}
