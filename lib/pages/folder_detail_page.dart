// lib/pages/folder_detail_page.dart

import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/widgets/mini_player.dart';
import 'package:muzik_app/pages/player_page.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/services/audius_service.dart';
import 'package:muzik_app/widgets/song_card.dart';
import 'package:image_picker/image_picker.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:muzik_app/widgets/custom_app_bar.dart';

enum FolderSortOption { titleAZ, titleZA, artistAZ, artistZA }

class FolderDetailPage extends StatefulWidget {
  // Bu sayfa, hangi klasörün gösterileceğini bilmek için bir MusicFolder nesnesi alır.
  final MusicFolder folder;

  // Constructor ile bu folder nesnesini almayı zorunlu kılıyoruz.
  const FolderDetailPage({super.key, required this.folder});

  @override
  State<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends State<FolderDetailPage> {
  bool _isSelectionMode = false;
  final Set<String> _selectedSongIds = {};

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedSongIds.contains(id)) {
        _selectedSongIds.remove(id);
        if (_selectedSongIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedSongIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedSongIds.length == widget.folder.songs.length) {
        _selectedSongIds.clear();
      } else {
        _selectedSongIds.addAll(widget.folder.songs.map((s) => s.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Provider'ı izleyerek değişikliklerde sayfanın yenilenmesini sağlıyoruz.
    final songProvider = context.watch<SongProvider>();
    final folder = widget.folder;

    return Scaffold(
      appBar: _isSelectionMode
          ? CustomAppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedSongIds.clear();
                  });
                },
              ),
              title: '${_selectedSongIds.length} Seçildi',
              actions: [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: "Tümünü Seç",
                  onPressed: _selectAll,
                ),
                IconButton(
                  icon: const Icon(Icons.playlist_play),
                  tooltip: "Sıraya Ekle",
                  onPressed: _selectedSongIds.isEmpty
                      ? null
                      : () {
                          final selectedSongs = folder.songs
                              .where((s) => _selectedSongIds.contains(s.id))
                              .toList();
                          songProvider.addSongsToNext(selectedSongs);
                          setState(() {
                            _isSelectionMode = false;
                            _selectedSongIds.clear();
                          });
                        },
                ),
                IconButton(
                  icon: CustomIcons.svgIcon(
                    CustomIcons.delete,
                    color: Colors.redAccent,
                  ),
                  tooltip: "Sil",
                  onPressed: _selectedSongIds.isEmpty
                      ? null
                      : () {
                          _showBulkDeleteDialog(context, songProvider);
                        },
                ),
              ],
            )
          : CustomAppBar(
              // Başlık olarak klasörün adını gösteriyoruz.
              title: folder.name,
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_rounded),
                  tooltip: "Şarkı Ekle",
                  onPressed: () => _showAddSongsSheet(context),
                ),
                if (folder.songs.isNotEmpty)
                  PopupMenuButton<FolderSortOption>(
                    icon: const Icon(Icons.sort_rounded),
                    tooltip: "Sırala",
                    onSelected: (option) {
                      final provider = context.read<SongProvider>();
                      switch (option) {
                        case FolderSortOption.titleAZ:
                          provider.sortFolderSongs(
                            folder,
                            (a, b) => a.title.compareTo(b.title),
                          );
                          break;
                        case FolderSortOption.titleZA:
                          provider.sortFolderSongs(
                            folder,
                            (a, b) => b.title.compareTo(a.title),
                          );
                          break;
                        case FolderSortOption.artistAZ:
                          provider.sortFolderSongs(
                            folder,
                            (a, b) => a.artist.compareTo(b.artist),
                          );
                          break;
                        case FolderSortOption.artistZA:
                          provider.sortFolderSongs(
                            folder,
                            (a, b) => b.artist.compareTo(a.artist),
                          );
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<FolderSortOption>>[
                          const PopupMenuItem(
                            value: FolderSortOption.titleAZ,
                            child: Text('Başlık (A-Z)'),
                          ),
                          const PopupMenuItem(
                            value: FolderSortOption.titleZA,
                            child: Text('Başlık (Z-A)'),
                          ),
                          const PopupMenuItem(
                            value: FolderSortOption.artistAZ,
                            child: Text('Sanatçı (A-Z)'),
                          ),
                          const PopupMenuItem(
                            value: FolderSortOption.artistZA,
                            child: Text('Sanatçı (Z-A)'),
                          ),
                        ],
                  ),
              ],
            ),
      body: folder.songs.isEmpty
          ? _buildEmptyState(context)
          : ReorderableListView.builder(
              header: _buildHeader(context, songProvider),
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: folder.songs.length,
              onReorder: (oldIndex, newIndex) {
                if (!_isSelectionMode) {
                  songProvider.reorderSongsInFolder(folder, oldIndex, newIndex);
                }
              },
              itemBuilder: (context, index) {
                final song = folder.songs[index];
                final isSelected = _selectedSongIds.contains(song.id);

                return Material(
                  key: ValueKey(song.id),
                  color: isSelected
                      ? Theme.of(context).primaryColor.withOpacity(0.1)
                      : Colors.transparent,
                  child: Row(
                    children: [
                      if (_isSelectionMode)
                        Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Checkbox(
                            value: isSelected,
                            activeColor: Theme.of(context).primaryColor,
                            onChanged: (v) => _toggleSelection(song.id),
                          ),
                        ),
                      Expanded(
                        child: GestureDetector(
                          onLongPress: () {
                            if (!_isSelectionMode) {
                              setState(() {
                                _isSelectionMode = true;
                                _selectedSongIds.add(song.id);
                              });
                            }
                          },
                          child: SongCard(
                            song: song,
                            trailing: _isSelectionMode
                                ? null
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () => _showSongOptions(
                                          context,
                                          songProvider,
                                          song,
                                        ),
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).primaryColor.withOpacity(0.4),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(
                                                0.1,
                                              ),
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.more_vert,
                                            size: 20,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      ReorderableDragStartListener(
                                        index: index,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0,
                                          ),
                                          child: CustomIcons.svgIcon(
                                            CustomIcons.dragHandle,
                                            color: Colors.grey,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleSelection(song.id);
                              } else {
                                final songProvider = context
                                    .read<SongProvider>();
                                final isCurrent =
                                    songProvider.currentSong?.id == song.id;

                                if (isCurrent) {
                                  if (songProvider.audioPlayer.playing) {
                                    songProvider.audioPlayer.pause();
                                  } else {
                                    songProvider.audioPlayer.play();
                                  }
                                } else {
                                  songProvider.playSong(song, folder.songs);
                                }
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: songProvider.currentSong != null
          ? GestureDetector(
              onTap: () => PlayerPage.show(context),
              child: const MiniPlayer(),
            )
          : null,
    );
  }

  void _showSongOptions(
    BuildContext context,
    SongProvider provider,
    Song song,
  ) {
    final theme = Theme.of(context);
    CustomBottomSheet.showContent(
      context: context,
      child: Column(
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
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.playlist_play, color: theme.primaryColor),
            ),
            title: const Text(
              'Sıradaki Çal',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              provider.addSongToNext(song);
            },
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CustomIcons.svgIcon(
                CustomIcons.delete,
                color: Colors.redAccent,
                size: 24,
              ),
            ),
            title: const Text(
              'Listeden Sil',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () {
              Navigator.pop(context);
              _showDeleteDialog(context, provider, song);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _pickFolderImage(
    BuildContext context,
    SongProvider provider,
  ) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      provider.updateFolderImage(widget.folder, image.path);
      if (mounted) {
        CustomSnackBar.showSuccess(
          context: context,
          message: 'Kapak resmi güncellendi',
        );
      }
    }
  }

  void _showImageOptions(BuildContext context, SongProvider provider) {
    CustomBottomSheet.showContent(
      context: context,
      child: Column(
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
          ListTile(
            leading: const Icon(Icons.image, color: Colors.white),
            title: const Text(
              'Resmi Değiştir',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              _pickFolderImage(context, provider);
            },
          ),
          ListTile(
            leading: CustomIcons.svgIcon(
              CustomIcons.delete,
              color: Colors.redAccent,
            ),
            title: const Text(
              'Resmi Kaldır',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () {
              Navigator.pop(context);
              provider.updateFolderImage(widget.folder, null);
              CustomSnackBar.showError(
                context: context,
                message: 'Kapak resmi kaldırıldı',
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, SongProvider provider) {
    return Column(
      children: [
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () {
            if (widget.folder.customImagePath != null) {
              _showImageOptions(context, provider);
            } else {
              _pickFolderImage(context, provider);
            }
          },
          child: Stack(
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildFolderCover(widget.folder),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "${widget.folder.songs.length} Şarkı",
          style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (widget.folder.songs.isNotEmpty) {
                      if (!provider.isShuffleEnabled) {
                        provider.toggleShuffle();
                      }

                      final random = Random();
                      final randomSong = widget
                          .folder
                          .songs[random.nextInt(widget.folder.songs.length)];

                      provider.playSong(randomSong, widget.folder.songs);
                      CustomSnackBar.showInfo(
                        context: context,
                        message: "Liste karışık çalınıyor.",
                        icon: const Icon(Icons.shuffle, color: Colors.white),
                      );
                    }
                  },
                  icon: const Icon(Icons.shuffle_rounded),
                  label: const Text(
                    "Karışık",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                    if (widget.folder.songs.isNotEmpty) {
                      if (provider.isShuffleEnabled) {
                        provider.toggleShuffle();
                      }

                      provider.playSong(
                        widget.folder.songs.first,
                        widget.folder.songs,
                      );
                      CustomSnackBar.showInfo(
                        context: context,
                        message: "Liste oynatılıyor.",
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                      );
                    }
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text(
                    "Oynat",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFolderCover(MusicFolder folder) {
    final songs = folder.songs;
    if (folder.customImagePath != null &&
        File(folder.customImagePath!).existsSync()) {
      return Image.file(
        File(folder.customImagePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    if (songs.isEmpty) {
      return Container(
        color: Colors.grey.shade800,
        child: const Center(
          child: Icon(Icons.music_note, color: Colors.white54, size: 64),
        ),
      );
    }

    if (songs.length < 4) {
      return _buildImage(songs.first);
    }

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildImage(songs[0])),
              Expanded(child: _buildImage(songs[1])),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildImage(songs[2])),
              Expanded(child: _buildImage(songs[3])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImage(Song song) {
    if (song.localImagePath != null &&
        File(song.localImagePath!).existsSync()) {
      return Image.file(
        File(song.localImagePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade900,
            child: CustomIcons.svgIcon(
              CustomIcons.musicNote,
              size: 32,
              color: Colors.grey,
            ),
          );
        },
      );
    }
    return Image.network(
      song.coverUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (c, e, s) => Container(
        color: Colors.grey.shade800,
        child: CustomIcons.svgIcon(
          CustomIcons.musicNote,
          size: 32,
          color: Colors.grey,
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    SongProvider provider,
    Song song,
  ) {
    CustomBottomSheet.show(
      context: context,
      title: 'Şarkıyı Listeden Sil',
      message: '${song.title} bu listeden silinsin mi?',
      primaryButtonText: 'Sil',
      primaryButtonColor: Colors.redAccent,
      secondaryButtonText: 'İptal',
      onPrimaryButtonTap: () {
        provider.removeSongFromFolder(widget.folder, song);
        Navigator.pop(context);
        CustomSnackBar.showError(
          context: context,
          message: '${song.title} listeden silindi.',
        );
      },
    );
  }

  void _showBulkDeleteDialog(BuildContext context, SongProvider provider) {
    CustomBottomSheet.show(
      context: context,
      title: 'Seçilenleri Sil',
      message: '${_selectedSongIds.length} şarkı bu listeden silinsin mi?',
      primaryButtonText: 'Sil',
      primaryButtonColor: Colors.redAccent,
      secondaryButtonText: 'İptal',
      onPrimaryButtonTap: () {
        provider.removeSongsFromFolder(
          widget.folder,
          _selectedSongIds.toList(),
        );
        Navigator.pop(context);
        setState(() {
          _isSelectionMode = false;
          _selectedSongIds.clear();
        });
        CustomSnackBar.showError(
          context: context,
          message: 'Seçilen şarkılar silindi.',
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              shape: BoxShape.circle,
            ),
            child: CustomIcons.svgIcon(
              CustomIcons.musicNote,
              size: 64,
              color: Theme.of(context).primaryColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Liste Boş',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Bu listede henüz hiç şarkı yok.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showAddSongsSheet(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text("Şarkı Ekle"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSongsSheet(BuildContext context) {
    CustomBottomSheet.showContent(
      context: context,
      isScrollControlled: true,
      child: AddSongsSheet(folder: widget.folder),
    );
  }
}

class AddSongsSheet extends StatefulWidget {
  final MusicFolder folder;
  const AddSongsSheet({super.key, required this.folder});

  @override
  State<AddSongsSheet> createState() => _AddSongsSheetState();
}

class _AddSongsSheetState extends State<AddSongsSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Song> _songs = [];
  final Set<String> _selectedSongIds = {};
  bool _isLoading = false;
  Timer? _debounce;

  void _sortSongs() {
    final folderSongIds = widget.folder.songs.map((s) => s.id).toSet();
    _songs.sort((a, b) {
      final aExists = folderSongIds.contains(a.id);
      final bExists = folderSongIds.contains(b.id);
      if (aExists == bExists) return 0;
      return aExists ? 1 : -1;
    });
  }

  @override
  void initState() {
    super.initState();
    // Başlangıçta favorileri göster
    final provider = context.read<SongProvider>();
    if (widget.folder.isFromDownloads) {
      _songs = List.from(provider.downloadedSongs);
    } else {
      _songs = List.from(provider.favoriteSongs);
    }
    _sortSongs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        setState(() {
          final provider = context.read<SongProvider>();
          if (widget.folder.isFromDownloads) {
            _songs = List.from(provider.downloadedSongs);
          } else {
            _songs = List.from(provider.favoriteSongs);
          }
          _sortSongs();
        });
        return;
      }

      setState(() => _isLoading = true);
      try {
        if (widget.folder.isFromDownloads) {
          final provider = context.read<SongProvider>();
          final results = provider.downloadedSongs.where((s) {
            final q = query.toLowerCase();
            return s.title.toLowerCase().contains(q) ||
                s.artist.toLowerCase().contains(q);
          }).toList();
          if (mounted) {
            setState(() {
              _songs = results;
              _sortSongs();
            });
          }
        } else {
          final results = await AudiusService.searchSongs(query);
          if (mounted) {
            setState(() {
              _songs = results;
              _sortSongs();
            });
          }
        }
      } catch (e) {
        debugPrint("Arama hatası: $e");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
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
            'Şarkı Ekle',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: widget.folder.isFromDownloads
                    ? 'İndirilenlerde ara...'
                    : 'Şarkı ara veya favorilerden seç...',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: CustomIcons.svgIcon(
                    CustomIcons.search,
                    color: Colors.grey,
                    size: 24,
                  ),
                ),
                filled: true,
                fillColor: Colors.grey.shade800,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _songs.length,
                    itemBuilder: (context, index) {
                      final song = _songs[index];
                      final isSelected = _selectedSongIds.contains(song.id);
                      final isAlreadyAdded = widget.folder.songs.any(
                        (s) => s.id == song.id,
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: isAlreadyAdded
                              ? null
                              : () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedSongIds.remove(song.id);
                                    } else {
                                      _selectedSongIds.add(song.id);
                                    }
                                  });
                                },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isSelected || isAlreadyAdded)
                                  ? Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.15)
                                  : Colors.grey.shade900.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (isSelected || isAlreadyAdded)
                                    ? Theme.of(context).primaryColor
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Opacity(
                                  opacity: isAlreadyAdded ? 0.5 : 1.0,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child:
                                        (song.localImagePath != null &&
                                            File(
                                              song.localImagePath!,
                                            ).existsSync())
                                        ? Image.file(
                                            File(song.localImagePath!),
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.network(
                                            song.coverUrl,
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) =>
                                                Container(
                                                  width: 50,
                                                  height: 50,
                                                  color: Colors.grey.shade800,
                                                  child: const Icon(
                                                    Icons.music_note,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isAlreadyAdded
                                              ? Colors.grey
                                              : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isAlreadyAdded
                                            ? "Zaten listede"
                                            : song.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isAlreadyAdded
                                              ? Theme.of(context).primaryColor
                                              : Colors.grey.shade400,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isAlreadyAdded)
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? Theme.of(context).primaryColor
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected
                                            ? Theme.of(context).primaryColor
                                            : Colors.grey.shade600,
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedSongIds.isEmpty
                    ? null
                    : () {
                        final selectedSongs = _songs
                            .where((s) => _selectedSongIds.contains(s.id))
                            .toList();
                        context.read<SongProvider>().addSongsToFolder(
                          widget.folder,
                          selectedSongs,
                        );
                        Navigator.pop(context);
                        CustomSnackBar.showSuccess(
                          context: context,
                          message: '${selectedSongs.length} şarkı eklendi.',
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey.shade800,
                  disabledForegroundColor: Colors.grey.shade500,
                ),
                child: Text(
                  'Ekle (${_selectedSongIds.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
