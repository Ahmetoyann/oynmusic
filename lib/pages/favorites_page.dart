import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/widgets/song_card.dart';
import 'package:muzik_app/providers/auth_provider.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';
import 'package:muzik_app/main.dart';
import 'package:muzik_app/widgets/custom_app_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:muzik_app/widgets/mini_player.dart';
import 'package:muzik_app/pages/player_page.dart';

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
    String? selectedImagePath;

    CustomBottomSheet.showContent(
      context: context,
      isScrollControlled: true,
      child: StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                // Modern Image Picker
                GestureDetector(
                  onTap: () async {
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null) {
                      setModalState(() {
                        selectedImagePath = image.path;
                      });
                    }
                  },
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      image: selectedImagePath != null
                          ? DecorationImage(
                              image: FileImage(File(selectedImagePath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: selectedImagePath == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_rounded,
                                color: Theme.of(context).primaryColor,
                                size: 48,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Kapak Seç",
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 24),
                // Modern TextField
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  child: TextField(
                    controller: controller,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Liste Adı',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 2,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(1),
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
                          customImagePath: selectedImagePath,
                        );
                        Navigator.pop(context);
                        setState(() {
                          _isSelectionMode = false;
                          _selectedSongs.clear();
                        });
                        CustomSnackBar.showSuccess(
                          context: context,
                          message: '${controller.text} oluşturuldu.',
                        );
                      } else {
                        CustomSnackBar.showError(
                          context: context,
                          message: 'Lütfen bir liste adı girin.',
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
                      elevation: 0,
                    ),
                    child: const Text(
                      'Oluştur',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddToPlaylistBottomSheet(BuildContext context) {
    if (_selectedSongs.isEmpty) return;

    CustomBottomSheet.showContent(
      context: context,
      child: Consumer<SongProvider>(
        builder: (innerContext, songProvider, child) {
          final folders = songProvider.folders;
          final theme = Theme.of(innerContext);

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
              const SizedBox(height: 16),
              const Text(
                'Listeye Ekle',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Modern "Yeni Liste Oluştur" Butonu
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _showCreatePlaylistBottomSheet(context);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.primaryColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, color: theme.primaryColor),
                          const SizedBox(width: 12),
                          Text(
                            'Yeni Liste Oluştur',
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (folders.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.folder_open_rounded,
                        size: 48,
                        color: Colors.grey.shade800,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Mevcut liste yok.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: folders.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final folder = folders[index];

                      Widget coverWidget;
                      if (folder.customImagePath != null &&
                          File(folder.customImagePath!).existsSync()) {
                        coverWidget = Image.file(
                          File(folder.customImagePath!),
                          fit: BoxFit.cover,
                        );
                      } else if (folder.songs.isNotEmpty) {
                        final firstSong = folder.songs.first;
                        if (firstSong.localImagePath != null &&
                            File(firstSong.localImagePath!).existsSync()) {
                          coverWidget = Image.file(
                            File(firstSong.localImagePath!),
                            fit: BoxFit.cover,
                          );
                        } else {
                          coverWidget = Image.network(
                            firstSong.coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              color: Colors.grey.shade800,
                              child: const Icon(
                                Icons.music_note,
                                color: Colors.white54,
                              ),
                            ),
                          );
                        }
                      } else {
                        coverWidget = Container(
                          color: Colors.grey.shade800,
                          child: Icon(
                            folder.isFromDownloads
                                ? Icons.download_rounded
                                : Icons.music_note_rounded,
                            color: Colors.white70,
                            size: 24,
                          ),
                        );
                      }

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: coverWidget,
                            ),
                          ),
                          title: Text(
                            folder.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${folder.songs.length} şarkı',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          onTap: () {
                            songProvider.addSongsToFolder(
                              folder,
                              _selectedSongs.toList(),
                            );
                            Navigator.pop(context);
                            setState(() {
                              _isSelectionMode = false;
                              _selectedSongs.clear();
                            });
                            CustomSnackBar.showSuccess(
                              context: context,
                              message:
                                  'Şarkılar ${folder.name} listesine eklendi.',
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteSelectedDialog(BuildContext context) {
    final songProvider = context.read<SongProvider>();
    CustomBottomSheet.show(
      context: context,
      title: 'Favorilerden Çıkar',
      message: '${_selectedSongs.length} şarkı favorilerden çıkarılsın mı?',
      primaryButtonText: 'Çıkar',
      primaryButtonColor: Colors.redAccent,
      secondaryButtonText: 'İptal',
      onPrimaryButtonTap: () {
        for (var song in _selectedSongs) {
          songProvider.toggleFavorite(song);
        }
        setState(() {
          _isSelectionMode = false;
          _selectedSongs.clear();
        });
        Navigator.pop(context);
        CustomSnackBar.showSuccess(
          context: context,
          message: 'Seçilenler favorilerden çıkarıldı.',
        );
      },
    );
  }

  void _showClearFavoritesDialog(BuildContext context) {
    CustomBottomSheet.show(
      context: context,
      title: 'Tümünü Temizle',
      message: 'Tüm favori şarkılarınız silinecek. Emin misiniz?',
      primaryButtonText: 'Temizle',
      primaryButtonColor: Colors.red,
      secondaryButtonText: 'İptal',
      onPrimaryButtonTap: () {
        context.read<SongProvider>().clearAllFavorites();
        Navigator.pop(context);
        CustomSnackBar.showError(
          context: context,
          message: 'Favoriler temizlendi.',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = context.watch<SongProvider>();
    final authProvider = context.watch<AuthProvider>();
    final favoriteSongs = songProvider.favoriteSongs;
    final canPop = Navigator.of(context).canPop();

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
      appBar: CustomAppBar(
        title: _isSelectionMode
            ? '${_selectedSongs.length} Seçildi'
            : 'Favoriler',
        showLeading: false,
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
            : canPop
            ? BackButton(color: Theme.of(context).primaryColor)
            : null,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.playlist_add),
              onPressed: () => _showAddToPlaylistBottomSheet(context),
            ),
            IconButton(
              icon: CustomIcons.svgIcon(
                CustomIcons.delete,
                color: Colors.redAccent,
              ),
              tooltip: "Favorilerden Çıkar",
              onPressed: () => _showDeleteSelectedDialog(context),
            ),
          ] else if (favoriteSongs.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: "Seç",
              onPressed: () {
                setState(() {
                  _isSelectionMode = true;
                });
              },
            ),
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
          ],
        ],
      ),
      bottomNavigationBar: songProvider.currentSong != null
          ? GestureDetector(
              onTap: () => PlayerPage.show(context),
              child: const MiniPlayer(),
            )
          : null,
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
          // --- PLAY / SHUFFLE BUTONLARI ---
          if (favoriteSongs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (filteredSongs.isNotEmpty) {
                          if (!songProvider.isShuffleEnabled) {
                            songProvider.toggleShuffle();
                          }
                          final random = Random();
                          final randomSong =
                              filteredSongs[random.nextInt(
                                filteredSongs.length,
                              )];
                          songProvider.playSong(randomSong, filteredSongs);
                          CustomSnackBar.showInfo(
                            context: context,
                            message: "Favoriler karışık çalınıyor.",
                            icon: const Icon(
                              Icons.shuffle,
                              color: Colors.white,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.shuffle_rounded),
                      label: const Text(
                        "Karışık",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (filteredSongs.isNotEmpty) {
                          if (songProvider.isShuffleEnabled) {
                            songProvider.toggleShuffle();
                          }
                          songProvider.playSong(
                            filteredSongs.first,
                            filteredSongs,
                          );
                          CustomSnackBar.showInfo(
                            context: context,
                            message: "Favoriler oynatılıyor.",
                            icon: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text(
                        "Oynat",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: favoriteSongs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade900,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.2),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 80,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Henüz Favori Yok',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 48),
                          child: Text(
                            'Sevdiğiniz şarkıları kalp ikonuna tıklayarak koleksiyonunuza ekleyin.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        ElevatedButton(
                          onPressed: () {
                            mainScreenKey.currentState?.switchToTab(0);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 10,
                            shadowColor: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.4),
                          ),
                          child: const Text(
                            'Şarkıları Keşfet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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
