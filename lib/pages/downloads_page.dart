import 'package:flutter/material.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/pages/player_page.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  bool _isSelectionMode = false;
  final Set<Song> _selectedSongs = {};

  void _toggleSelection(Song song) {
    setState(() {
      if (_selectedSongs.contains(song)) {
        _selectedSongs.remove(song);
        if (_selectedSongs.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedSongs.add(song);
      }
    });
  }

  void _showCreateFolderBottomSheet(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Klavye açıldığında yukarı kayması için
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'İndirilenlerden Liste Oluştur',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Liste Adı',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                filled: true,
                fillColor: Colors.grey.shade800,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    context.read<SongProvider>().createFolder(
                      name: controller.text,
                      songs: _selectedSongs.toList(),
                      isFromDownloads: true,
                    );
                    Navigator.pop(ctx);
                    setState(() {
                      _isSelectionMode = false;
                      _selectedSongs.clear();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${controller.text} oluşturuldu.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Oluştur',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, Song song) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Silmek istediğinize emin misiniz?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '${song.title} cihazınızdan silinecek.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              context.read<SongProvider>().deleteDownloadedSong(song);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${song.title} silindi.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAllConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Tümünü Sil', style: TextStyle(color: Colors.white)),
        content: const Text(
          'İndirilen tüm şarkılar silinecek. Emin misiniz?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              context.read<SongProvider>().deleteAllDownloadedSongs();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tüm şarkılar silindi.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = context.watch<SongProvider>();
    final downloadedSongs = songProvider.downloadedSongs;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode
              ? '${_selectedSongs.length} Seçildi'
              : 'İndirilenler',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedSongs.clear();
                  });
                },
              )
            : null,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.create_new_folder_outlined),
              tooltip: "Klasör Oluştur",
              onPressed: () => _showCreateFolderBottomSheet(context),
            ),
            IconButton(
              icon: Icon(
                _selectedSongs.length == downloadedSongs.length
                    ? Icons.deselect
                    : Icons.select_all,
              ),
              onPressed: () {
                setState(() {
                  if (_selectedSongs.length == downloadedSongs.length) {
                    _selectedSongs.clear();
                  } else {
                    _selectedSongs.addAll(downloadedSongs);
                  }
                });
              },
            ),
          ] else if (downloadedSongs.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: "Tümünü Sil",
              onPressed: () => _showDeleteAllConfirmationDialog(context),
            ),
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: () {
                setState(() {
                  _isSelectionMode = true;
                });
              },
            ),
          ],
        ],
      ),
      body: downloadedSongs.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.download_done_rounded,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Henüz indirilmiş şarkı yok.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: downloadedSongs.length,
              itemBuilder: (context, index) {
                final song = downloadedSongs[index];
                final isPlaying =
                    songProvider.currentSong?.id == song.id &&
                    songProvider.audioPlayer.playing;
                final isSelected = _selectedSongs.contains(song);

                return Card(
                  color: _isSelectionMode && isSelected
                      ? Theme.of(context).primaryColor.withOpacity(0.2)
                      : Colors.grey.shade900,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: _isSelectionMode && isSelected
                        ? BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2,
                          )
                        : BorderSide.none,
                  ),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        song.coverUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(Icons.music_note),
                      ),
                    ),
                    title: Tooltip(
                      message: song.title,
                      child: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    subtitle: Text(
                      song.artist,
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    trailing: _isSelectionMode
                        ? Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.grey,
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _showDeleteConfirmationDialog(
                                  context,
                                  song,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  isPlaying
                                      ? Icons.pause_circle
                                      : Icons.play_circle_fill,
                                  size: 32,
                                  color: Theme.of(context).primaryColor,
                                ),
                                onPressed: () {
                                  songProvider.playSong(song, downloadedSongs);
                                },
                              ),
                            ],
                          ),
                    onTap: () {
                      if (_isSelectionMode) {
                        _toggleSelection(song);
                      } else {
                        final isCurrentSong =
                            songProvider.currentSong?.id == song.id;
                        if (!isCurrentSong) {
                          songProvider.playSong(song, downloadedSongs);
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PlayerPage(),
                          ),
                        );
                      }
                    },
                    onLongPress: () {
                      if (!_isSelectionMode) {
                        setState(() {
                          _isSelectionMode = true;
                          _selectedSongs.add(song);
                        });
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
