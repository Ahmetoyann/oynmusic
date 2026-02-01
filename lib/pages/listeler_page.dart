// lib/pages/listeler_page.dart

import 'package:flutter/material.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/models/song_model.dart';

// 1. YENİ SAYFAYI IMPORT EDİYORUZ
import 'package:muzik_app/pages/folder_detail_page.dart';

class ListelerPage extends StatelessWidget {
  const ListelerPage({super.key});

  @override
  Widget build(BuildContext context) {
    // SongProvider'a bağlanarak oluşturulan klasörleri alıyoruz.
    final folders = context.watch<SongProvider>().folders;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Listelerim',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
      ),
      body: folders.isEmpty
          ? const Center(
              child: Text(
                'Henüz bir liste oluşturmadınız.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                return Card(
                  color: Colors.grey.shade800,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: _buildPlaylistCover(folder.songs),
                    title: Text(
                      folder.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${folder.songs.length} şarkı',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white70),
                          onPressed: () {
                            _showRenameDialog(context, folder);
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: Colors.grey.shade900,
                                title: const Text(
                                  'Listeyi Sil',
                                  style: TextStyle(color: Colors.white),
                                ),
                                content: Text(
                                  '${folder.name} listesi silinsin mi?',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text(
                                      'İptal',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      context.read<SongProvider>().deleteFolder(
                                        folder,
                                      );
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${folder.name} silindi.',
                                          ),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'Sil',
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    // 2. onTap İŞLEVİNİ GÜNCELLİYORUZ
                    onTap: () {
                      // Navigator.push ile yeni sayfayı açıyoruz.
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          // FolderDetailPage'i oluştururken,
                          // 'folder' parametresine o an tıklanan klasörü veriyoruz.
                          builder: (context) =>
                              FolderDetailPage(folder: folder),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildPlaylistCover(List<Song> songs) {
    const double size = 56;
    if (songs.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade800),
        ),
        child: const Icon(Icons.music_note, color: Colors.grey),
      );
    }

    if (songs.length < 4) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          songs.first.coverUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: size,
            height: size,
            color: Colors.grey.shade900,
            child: const Icon(Icons.music_note, color: Colors.grey),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildGridImage(songs[0].coverUrl)),
                  Expanded(child: _buildGridImage(songs[1].coverUrl)),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildGridImage(songs[2].coverUrl)),
                  Expanded(child: _buildGridImage(songs[3].coverUrl)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridImage(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey.shade900,
          child: const Icon(Icons.music_note, size: 16, color: Colors.grey),
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context, MusicFolder folder) {
    final TextEditingController controller = TextEditingController(
      text: folder.name,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Listeyi Yeniden Adlandır',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Yeni isim girin',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<SongProvider>().renameFolder(
                  folder,
                  controller.text,
                );
                Navigator.pop(context);
              }
            },
            child: Text(
              'Kaydet',
              style: TextStyle(color: Theme.of(context).primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}
