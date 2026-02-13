import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/widgets/song_card.dart';
import 'package:muzik_app/providers/auth_provider.dart';
import 'package:muzik_app/pages/profile_page.dart';

enum SortOption { dateNewest, dateOldest, nameAZ, nameZA }

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
  SortOption _sortOption = SortOption.dateNewest;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return "${date.day}.${date.month}.${date.year}";
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
            Text(
              'Çalma Listesi Oluştur',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
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
                        content: Row(
                          children: [
                            CustomIcons.svgIcon(
                              CustomIcons.check,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${controller.text} oluşturuldu.',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green.shade700,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.all(16),
                        duration: const Duration(seconds: 2),
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
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Çalma Listesine Ekle',
                    style: TextStyle(
                      color: Theme.of(innerContext).primaryColor,
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
                SnackBar(
                  content: Row(
                    children: [
                      CustomIcons.svgIcon(
                        CustomIcons
                            .delete, // Using delete as sweep replacement or standard
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Favoriler temizlendi.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 2),
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
    final authProvider = context.watch<AuthProvider>();
    final favoriteSongs = songProvider.favoriteSongs;

    var filteredSongs = favoriteSongs.where((song) {
      if (_searchText.isEmpty) return true;
      final query = _searchText.toLowerCase();
      return song.title.toLowerCase().contains(query) ||
          song.artist.toLowerCase().contains(query);
    }).toList();

    // Sıralama işlemi
    switch (_sortOption) {
      case SortOption.nameAZ:
        filteredSongs.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SortOption.nameZA:
        filteredSongs.sort((a, b) => b.title.compareTo(a.title));
        break;
      case SortOption.dateNewest:
        filteredSongs = filteredSongs.reversed.toList();
        break;
      case SortOption.dateOldest:
        // Varsayılan sıralama (eklenme sırası)
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode ? '${_selectedSongs.length} Seçildi' : 'Favoriler',
        ),
        centerTitle: false,
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
            : GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfilePage(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.grey.shade800,
                    backgroundImage: authProvider.user?.photoURL != null
                        ? NetworkImage(authProvider.user!.photoURL!)
                        : null,
                    child: authProvider.user?.photoURL == null
                        ? CustomIcons.svgIcon(
                            CustomIcons.person,
                            color: Colors.white,
                            size: 20,
                          )
                        : null,
                  ),
                ),
              ),
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
            PopupMenuButton<SortOption>(
              icon: const Icon(Icons.sort),
              tooltip: "Sırala",
              onSelected: (SortOption result) {
                setState(() {
                  _sortOption = result;
                });
              },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<SortOption>>[
                    const PopupMenuItem<SortOption>(
                      value: SortOption.dateNewest,
                      child: Text('Tarihe Göre (En Yeni)'),
                    ),
                    const PopupMenuItem<SortOption>(
                      value: SortOption.dateOldest,
                      child: Text('Tarihe Göre (En Eski)'),
                    ),
                    const PopupMenuItem<SortOption>(
                      value: SortOption.nameAZ,
                      child: Text('İsme Göre (A-Z)'),
                    ),
                    const PopupMenuItem<SortOption>(
                      value: SortOption.nameZA,
                      child: Text('İsme Göre (Z-A)'),
                    ),
                  ],
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: "Seçenekler",
              onSelected: (value) {
                switch (value) {
                  case 'shuffle_play':
                    if (filteredSongs.isNotEmpty) {
                      if (!songProvider.isShuffleEnabled) {
                        songProvider.toggleShuffle();
                      }
                      final random = Random();
                      final randomSong =
                          filteredSongs[random.nextInt(filteredSongs.length)];
                      songProvider.playSong(randomSong, filteredSongs);
                    }
                    break;
                  case 'play_all':
                    if (filteredSongs.isNotEmpty) {
                      if (songProvider.isShuffleEnabled) {
                        songProvider.toggleShuffle();
                      }
                      songProvider.playSong(filteredSongs.first, filteredSongs);
                    }
                    break;
                  case 'select':
                    setState(() {
                      _isSelectionMode = true;
                    });
                    break;
                  case 'clear_all':
                    _showClearFavoritesDialog(context);
                    break;
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'shuffle_play',
                  child: Row(
                    children: [
                      Icon(Icons.shuffle_rounded, color: Colors.white),
                      SizedBox(width: 12),
                      Text(
                        'Karışık Çal',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'play_all',
                  child: Row(
                    children: [
                      Icon(Icons.play_arrow_rounded, color: Colors.white),
                      SizedBox(width: 12),
                      Text(
                        'Tümünü Oynat',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'select',
                  child: Row(
                    children: [
                      Icon(Icons.checklist, color: Colors.white),
                      SizedBox(width: 12),
                      Text('Seç', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_sweep_outlined,
                        color: Colors.redAccent,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Tümünü Temizle',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              ],
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
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: CustomIcons.svgIcon(
                      CustomIcons.search,
                      color: Colors.grey,
                      size: 24,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade900,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  suffixIcon: _searchText.isNotEmpty
                      ? IconButton(
                          icon: CustomIcons.svgIcon(
                            CustomIcons.clear,
                            color: Colors.grey,
                            size: 24,
                          ),
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
                          size: 64,
                          color: Colors.grey.shade600,
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
                    padding: EdgeInsets.fromLTRB(
                      12,
                      12,
                      12,
                      songProvider.currentSong != null ? 160 : 100,
                    ),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: filteredSongs.length,
                    itemBuilder: (context, index) {
                      final song = filteredSongs[index];
                      final isSelected = _selectedSongs.contains(song);

                      // Tarihi göstermek için geçici bir Song nesnesi oluşturuyoruz
                      final displaySong = Song(
                        id: song.id,
                        title: song.title,
                        artist:
                            "${song.artist} • ${_formatDate(song.dateAdded)}",
                        coverUrl: song.coverUrl,
                        audioUrl: song.audioUrl,
                        duration: song.duration,
                        localPath: song.localPath,
                        localImagePath: song.localImagePath,
                        dateAdded: song.dateAdded,
                      );

                      return SongCard(
                        song: displaySong,
                        isSelected: isSelected,
                        showBorder: _isSelectionMode,
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
                                icon: Icon(
                                  Icons.favorite,
                                  color: Theme.of(context).primaryColor,
                                  size: 24,
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
