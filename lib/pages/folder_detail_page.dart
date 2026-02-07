// lib/pages/folder_detail_page.dart

import 'package:flutter/material.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/widgets/mini_player.dart';
import 'package:muzik_app/pages/player_page.dart';

class FolderDetailPage extends StatelessWidget {
  // Bu sayfa, hangi klasörün gösterileceğini bilmek için bir MusicFolder nesnesi alır.
  final MusicFolder folder;

  // Constructor ile bu folder nesnesini almayı zorunlu kılıyoruz.
  const FolderDetailPage({super.key, required this.folder});

  @override
  Widget build(BuildContext context) {
    // Provider'ı izleyerek değişikliklerde sayfanın yenilenmesini sağlıyoruz.
    final songProvider = context.watch<SongProvider>();

    return Scaffold(
      appBar: AppBar(
        // Başlık olarak klasörün adını gösteriyoruz.
        title: Text(
          folder.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: folder.songs.isEmpty
          ? const Center(
              child: Text(
                'Bu listede hiç şarkı yok.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: folder.songs.length,
              onReorder: (oldIndex, newIndex) {
                songProvider.reorderSongsInFolder(folder, oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final song = folder.songs[index];

                return Card(
                  key: ValueKey(song.id), // Sıralama için benzersiz key gerekli
                  color: Colors.grey.shade900.withOpacity(0.5),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4.0),
                      child: Image.network(
                        song.coverUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.music_note,
                            size: 50,
                            color: Colors.grey,
                          );
                        },
                      ),
                    ),
                    title: Tooltip(
                      message: song.title,
                      child: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    subtitle: Text(
                      song.artist,
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () {
                            _showDeleteDialog(context, songProvider, song);
                          },
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.only(left: 8.0, right: 8.0),
                            child: Icon(Icons.drag_handle, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    // Bu sayfadaki bir şarkıya tıklandığında ne olacağı:
                    onTap: () {
                      final songProvider = context.read<SongProvider>();
                      final isCurrent = songProvider.currentSong?.id == song.id;

                      if (isCurrent) {
                        if (songProvider.audioPlayer.playing) {
                          songProvider.audioPlayer.pause();
                        } else {
                          songProvider.audioPlayer.play();
                        }
                      } else {
                        // Çalma listesi olarak bu KLASÖRÜN ŞARKI LİSTESİNİ kullanıyoruz.
                        songProvider.playSong(song, folder.songs);
                      }
                    },
                  ),
                );
              },
            ),
      bottomNavigationBar: songProvider.currentSong != null
          ? GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PlayerPage()),
                );
              },
              child: const MiniPlayer(),
            )
          : null,
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    SongProvider provider,
    Song song,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Şarkıyı Listeden Sil',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '${song.title} bu listeden silinsin mi?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              provider.removeSongFromFolder(folder, song);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${song.title} listeden silindi.'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
