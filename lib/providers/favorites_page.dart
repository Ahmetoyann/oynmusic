import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/pages/player_page.dart';
import 'package:muzik_app/models/song_model.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
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

  void _showCreatePlaylistDialog(BuildContext context) {
    if (_selectedSongs.isEmpty) return;

    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Çalma Listesi Oluştur',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Liste Adı',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.green),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final provider = context.read<SongProvider>();
                provider.createFolder(
                  name: controller.text,
                  songs: _selectedSongs.toList(),
                );
                // Listeye eklenenleri favorilerden çıkar
                for (var song in _selectedSongs) {
                  provider.toggleFavorite(song);
                }
                Navigator.pop(context);
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
            child: Text(
              'Oluştur',
              style: TextStyle(color: Theme.of(context).primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistBottomSheet(BuildContext context) {
    if (_selectedSongs.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Consumer<SongProvider>(
          builder: (context, songProvider, child) {
            final folders = songProvider.folders;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Çalma Listesine Ekle',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                  title: const Text(
                    'Yeni Liste Oluştur',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showCreatePlaylistDialog(context);
                  },
                ),
                const Divider(color: Colors.grey),
                if (folders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Mevcut liste yok.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: folders.length,
                      itemBuilder: (context, index) {
                        final folder = folders[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.music_note,
                            color: Colors.grey,
                          ),
                          title: Text(
                            folder.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            '${folder.songs.length} şarkı',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                          onTap: () {
                            songProvider.addSongsToFolder(
                              folder,
                              _selectedSongs.toList(),
                            );
                            // Listeye eklenenleri favorilerden çıkar
                            for (var song in _selectedSongs) {
                              songProvider.toggleFavorite(song);
                            }
                            Navigator.pop(context);
                            setState(() {
                              _isSelectionMode = false;
                              _selectedSongs.clear();
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Şarkılar ${folder.name} listesine eklendi.',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = context.watch<SongProvider>();
    final favoriteSongs = songProvider.favoriteSongs;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode ? '${_selectedSongs.length} Seçildi' : 'Favorilerim',
        ),
        backgroundColor: Colors.black,
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
              icon: Icon(
                _selectedSongs.length == favoriteSongs.length
                    ? Icons.clear_all
                    : Icons.select_all,
              ),
              onPressed: () {
                setState(() {
                  if (_selectedSongs.length == favoriteSongs.length) {
                    _selectedSongs.clear();
                  } else {
                    _selectedSongs.addAll(favoriteSongs);
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.playlist_add),
              onPressed: () => _showAddToPlaylistBottomSheet(context),
            ),
          ] else if (favoriteSongs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: () {
                setState(() {
                  _isSelectionMode = true;
                });
              },
            ),
        ],
      ),
      backgroundColor: Colors.black,
      body: favoriteSongs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 80,
                    color: Colors.grey.shade800,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz favori şarkınız yok.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: favoriteSongs.length,
              itemBuilder: (context, index) {
                final song = favoriteSongs[index];
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
                      ),
                    ),
                    title: Text(
                      song.title,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                        : IconButton(
                            icon: const Icon(Icons.favorite, color: Colors.red),
                            onPressed: () {
                              songProvider.toggleFavorite(song);
                            },
                          ),
                    onTap: () {
                      if (_isSelectionMode) {
                        _toggleSelection(song);
                      } else {
                        final sp = Provider.of<SongProvider>(
                          context,
                          listen: false,
                        );
                        sp.playSong(song, favoriteSongs);
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
