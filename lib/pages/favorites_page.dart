import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/models/song_model.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  bool _isSelectionMode = false;
  final Set<Song> _selectedSongs = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  void _showCreatePlaylistBottomSheet(BuildContext context) {
    if (_selectedSongs.isEmpty) return;

    final TextEditingController controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
              'Çalma Listesi Oluştur',
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
                    final provider = context.read<SongProvider>();
                    provider.createFolder(
                      name: controller.text,
                      songs: _selectedSongs.toList(),
                    );
                    // Listeye eklenenleri favorilerden çıkar
                    for (var song in _selectedSongs) {
                      provider.toggleFavorite(song);
                    }
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
          builder: (innerContext, songProvider, child) {
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
                    Navigator.pop(innerContext);
                    _showCreatePlaylistBottomSheet(context);
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
                            Navigator.pop(innerContext);
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

  void _showClearFavoritesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Tümünü Temizle',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Tüm favori şarkılarınız silinecek. Emin misiniz?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              context.read<SongProvider>().clearAllFavorites();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Favoriler temizlendi.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            child: const Text('Temizle', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = context.watch<SongProvider>();
    final favoriteSongs = songProvider.favoriteSongs;

    final filteredSongs = favoriteSongs.where((song) {
      if (_searchText.isEmpty) return true;
      final query = _searchText.toLowerCase();
      return song.title.toLowerCase().contains(query) ||
          song.artist.toLowerCase().contains(query);
    }).toList();

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
          ] else if (favoriteSongs.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: "Tümünü Temizle",
              onPressed: () => _showClearFavoritesDialog(context),
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
      backgroundColor: Colors.black,
      body: Column(
        children: [
          if (favoriteSongs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Favorilerde ara...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey.shade900,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  suffixIcon: _searchText.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchText = '');
                            FocusScope.of(context).unfocus();
                          },
                        )
                      : null,
                ),
                onChanged: (value) => setState(() => _searchText = value),
              ),
            ),
          Expanded(
            child: favoriteSongs.isEmpty
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
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : filteredSongs.isEmpty
                ? const Center(
                    child: Text(
                      'Sonuç bulunamadı.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: filteredSongs.length,
                    itemBuilder: (context, index) {
                      final song = filteredSongs[index];
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
                              : IconButton(
                                  icon: const Icon(
                                    Icons.favorite,
                                    color: Colors.red,
                                  ),
                                  onPressed: () =>
                                      songProvider.toggleFavorite(song),
                                ),
                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleSelection(song);
                            } else {
                              final isCurrentSong =
                                  songProvider.currentSong?.id == song.id;
                              if (isCurrentSong &&
                                  songProvider.audioPlayer.playing) {
                                songProvider.audioPlayer.pause();
                              } else if (isCurrentSong) {
                                songProvider.audioPlayer.play();
                              } else {
                                songProvider.playSong(song, favoriteSongs);
                              }
                            }
                          },
                          onLongPress: () {
                            if (!_isSelectionMode) {
                              setState(() {
                                _isSelectionMode = true;
                                _selectedSongs.add(song);
                              });
                            } else {
                              _toggleSelection(song);
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
