import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/pages/player_page.dart';
import 'package:muzik_app/widgets/mini_player.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/widgets/song_card.dart';
import 'package:muzik_app/widgets/song_grid_card.dart';
import 'package:muzik_app/pages/folder_detail_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';
import 'package:muzik_app/main.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:muzik_app/widgets/custom_app_bar.dart';

enum SortOption { dateNewest, dateOldest, nameAZ, nameZA }

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  bool _isSelectionMode = false;
  final Set<Song> _selectedSongs = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  SortOption _sortOption = SortOption.dateNewest;
  bool _isGridMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hasConnection = context.read<SongProvider>().hasConnection;
      if (!hasConnection) {
        CustomSnackBar.showInfo(
          context: context,
          message: "Şu an çevrimdışı moddasınız",
          icon: const Icon(Icons.wifi_off, color: Colors.white, size: 24),
          duration: const Duration(seconds: 3),
        );
      }
    });
  }

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

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return "${date.day}.${date.month}.${date.year}";
  }

  String _getFileSizeString(String? path) {
    if (path == null) return '';
    try {
      final file = File(path);
      if (file.existsSync()) {
        final bytes = file.lengthSync();
        final mb = bytes / (1024 * 1024);
        return "${mb.toStringAsFixed(1)} MB";
      }
    } catch (e) {
      // Hata olursa boş dön
    }
    return '';
  }

  void _showCreateFolderBottomSheet(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    String? selectedImagePath;

    CustomBottomSheet.showContent(
      context: context,
      isScrollControlled: true, // Klavye açıldığında yukarı kayması için
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
                        context.read<SongProvider>().createFolder(
                          name: controller.text,
                          songs: _selectedSongs.toList(),
                          isFromDownloads: true,
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
                      Navigator.pop(innerContext);
                      _showCreateFolderBottomSheet(context);
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
                            Navigator.pop(innerContext);
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

  void _showStopPlaybackWarningBottomSheet(BuildContext context) {
    CustomBottomSheet.show(
      context: context,
      title: 'Şarkı Çalınıyor',
      message: 'Şu an çalan şarkıyı durdurup, silmeye öyle devam edin.',
      icon: const Icon(
        Icons.warning_amber_rounded,
        color: Colors.orangeAccent,
        size: 48,
      ),
      primaryButtonText: 'Tamam',
      primaryButtonColor: Colors.grey.shade800,
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, Song song) {
    CustomBottomSheet.show(
      context: context,
      title: 'Silmek istediğinize emin misiniz?',
      message:
          '${song.title} cihazınızdan silinecek.\nBu şarkı çalma listesinden de kaldırılacak.',
      primaryButtonText: 'Sil',
      primaryButtonColor: Colors.redAccent,
      secondaryButtonText: 'İptal',
      onPrimaryButtonTap: () {
        final provider = context.read<SongProvider>();
        if (provider.currentSong?.id == song.id &&
            provider.audioPlayer.playing) {
          Navigator.pop(context);
          _showStopPlaybackWarningBottomSheet(context);
          return;
        }
        provider.deleteDownloadedSong(song);
        Navigator.pop(context);
        CustomSnackBar.showError(
          context: context,
          message: '${song.title} silindi.',
        );
      },
    );
  }

  void _showDeleteSelectedDialog(BuildContext context) {
    final provider = context.read<SongProvider>();
    CustomBottomSheet.show(
      context: context,
      title: 'Seçilenleri Sil',
      message: '${_selectedSongs.length} şarkı cihazınızdan silinecek.',
      primaryButtonText: 'Sil',
      primaryButtonColor: Colors.redAccent,
      secondaryButtonText: 'İptal',
      onPrimaryButtonTap: () {
        // Çalan şarkı kontrolü
        if (provider.currentSong != null && provider.audioPlayer.playing) {
          if (_selectedSongs.any((s) => s.id == provider.currentSong!.id)) {
            Navigator.pop(context);
            _showStopPlaybackWarningBottomSheet(context);
            return;
          }
        }

        for (var song in _selectedSongs) {
          provider.deleteDownloadedSong(song);
        }
        Navigator.pop(context);
        setState(() {
          _isSelectionMode = false;
          _selectedSongs.clear();
        });
        CustomSnackBar.showError(
          context: context,
          message: 'Seçilen şarkılar silindi.',
        );
      },
    );
  }

  void _showDeleteAllConfirmationDialog(BuildContext context) {
    CustomBottomSheet.show(
      context: context,
      title: 'Tümünü Sil',
      message: 'İndirilen tüm şarkılar silinecek. Emin misiniz?',
      primaryButtonText: 'Sil',
      primaryButtonColor: Colors.redAccent,
      secondaryButtonText: 'İptal',
      onPrimaryButtonTap: () {
        context.read<SongProvider>().deleteAllDownloadedSongs();
        Navigator.pop(context);
        CustomSnackBar.showError(
          context: context,
          message: 'Tüm şarkılar silindi.',
        );
      },
    );
  }

  void _showSongOptions(BuildContext context, Song song) {
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
              context.read<SongProvider>().addSongToNext(song);
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
              'Şarkıyı Sil',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () {
              Navigator.pop(context);
              _showDeleteConfirmationDialog(context, song);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showFolderOptions(BuildContext context, MusicFolder folder) {
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
            leading: const Icon(Icons.edit, color: Colors.white),
            title: const Text(
              'Yeniden Adlandır',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              _showRenameFolderDialog(context, folder);
            },
          ),
          ListTile(
            leading: const Icon(Icons.image, color: Colors.white),
            title: const Text(
              'Kapak Resmini Değiştir',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              _pickFolderImage(context, folder);
            },
          ),
          ListTile(
            leading: CustomIcons.svgIcon(
              CustomIcons.delete,
              color: Colors.redAccent,
            ),
            title: const Text(
              'Listeyi Sil',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () {
              Navigator.pop(context);
              _showDeleteFolderDialog(context, folder);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _pickFolderImage(
    BuildContext context,
    MusicFolder folder,
  ) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      context.read<SongProvider>().updateFolderImage(folder, image.path);
      if (mounted) {
        CustomSnackBar.showSuccess(
          context: context,
          message: 'Kapak resmi güncellendi',
        );
      }
    }
  }

  void _showRenameFolderDialog(BuildContext context, MusicFolder folder) {
    final TextEditingController controller = TextEditingController(
      text: folder.name,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Yeniden Adlandır',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Yeni isim',
            hintStyle: TextStyle(color: Colors.grey.shade500),
            filled: true,
            fillColor: Colors.grey.shade800,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<SongProvider>().renameFolder(
                  folder,
                  controller.text,
                );
                Navigator.pop(ctx);
              }
            },
            child: Text(
              'Kaydet',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteFolderDialog(BuildContext context, MusicFolder folder) {
    CustomBottomSheet.show(
      context: context,
      title: 'Listeyi Sil',
      message: '${folder.name} listesi silinsin mi?',
      primaryButtonText: 'Sil',
      primaryButtonColor: Colors.redAccent,
      secondaryButtonText: 'İptal',
      onPrimaryButtonTap: () {
        context.read<SongProvider>().deleteFolder(folder);
        Navigator.pop(context);
        CustomSnackBar.showError(
          context: context,
          message: '${folder.name} silindi.',
        );
      },
    );
  }

  Widget _buildFolderCard(BuildContext context, MusicFolder folder) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FolderDetailPage(folder: folder),
          ),
        );
      },
      onLongPress: () => _showFolderOptions(context, folder),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildFolderCover(folder),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            folder.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${folder.songs.length} şarkı',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderCover(MusicFolder folder) {
    final songs = folder.songs;

    Widget buildDefaultCover() {
      if (songs.isEmpty) {
        return Container(
          color: Colors.grey.shade800,
          child: const Center(
            child: Icon(Icons.music_note, color: Colors.white54, size: 32),
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

    if (folder.customImagePath != null) {
      return Image.file(
        File(folder.customImagePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => buildDefaultCover(),
      );
    }
    return buildDefaultCover();
  }

  Widget _buildImage(Song song) {
    if (song.localImagePath != null) {
      return Image.file(
        File(song.localImagePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Image.network(
            song.coverUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (c, e, s) => Container(
              color: Colors.grey.shade800,
              child: const Icon(Icons.music_note, color: Colors.grey),
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
        child: const Icon(Icons.music_note, color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = context.watch<SongProvider>();
    final downloadedSongs = songProvider.downloadedSongs;
    final downloadFolders = songProvider.folders
        .where((f) => f.isFromDownloads)
        .toList();

    var filteredSongs = downloadedSongs.where((song) {
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

    final bool canPopNavigator = Navigator.of(context).canPop();

    return PopScope(
      // Seçim modunda değilsek her zaman geri gitmeye izin ver.
      // Seçim modundaysak, geri tuşu seçimi iptal etmeli.
      canPop: !_isSelectionMode,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        // Eğer buraya geldiyse, canPop false demektir, yani seçim modundayız.
        // Geri tuşuna basıldığında seçim modundan çık.
        if (_isSelectionMode) {
          setState(() {
            _isSelectionMode = false;
            _selectedSongs.clear();
          });
        }
      },
      child: Scaffold(
        appBar: CustomAppBar(
          showLeading: canPopNavigator, // Geri gidilebiliyorsa ikonu göster
          title: _isSelectionMode
              ? '${_selectedSongs.length} Seçildi'
              : 'İndirilenler',
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
              // Geri gidilebiliyorsa BackButton widget'ını göster
              : canPopNavigator
              ? BackButton(color: Theme.of(context).primaryColor)
              : null,
          actions: [
            if (_isSelectionMode) ...[
              IconButton(
                icon: const Icon(Icons.playlist_add),
                tooltip: "Listeye Ekle",
                onPressed: () => _showAddToPlaylistBottomSheet(context),
              ),
              IconButton(
                icon: CustomIcons.svgIcon(
                  CustomIcons.delete,
                  color: Colors.redAccent,
                ),
                tooltip: "Sil",
                onPressed: () => _showDeleteSelectedDialog(context),
              ),
            ] else if (downloadedSongs.isNotEmpty) ...[
              IconButton(
                icon: Icon(_isGridMode ? Icons.list : Icons.grid_view),
                tooltip: "Görünüm",
                onPressed: () {
                  setState(() {
                    _isGridMode = !_isGridMode;
                  });
                },
              ),
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
        body: Column(
          children: [
            if (downloadedSongs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'İndirilenlerde ara...',
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
            if (downloadedSongs.isNotEmpty)
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
                              message: "İndirilenler karışık çalınıyor.",
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
                              message: "İndirilenler oynatılıyor.",
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
            if (downloadFolders.isNotEmpty &&
                !_isSelectionMode &&
                _searchText.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Çevrimdışı Listeler",
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: downloadFolders.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 110,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: _buildFolderCard(context, downloadFolders[index]),
                    );
                  },
                ),
              ),
              const Divider(color: Colors.white10, height: 24),
            ],
            Expanded(
              child: downloadedSongs.isEmpty
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
                              Icons.downloading_rounded,
                              size: 80,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'Henüz İndirilen Yok',
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
                              'Çevrimdışı dinlemek istediğiniz şarkıları indirin.',
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
                              Navigator.of(
                                context,
                              ).popUntil((route) => route.isFirst);
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
                  : _isGridMode
                  ? GridView.builder(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        songProvider.currentSong != null ? 160 : 100,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: filteredSongs.length,
                      itemBuilder: (context, index) {
                        final song = filteredSongs[index];
                        final isSelected = _selectedSongs.contains(song);

                        return GestureDetector(
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
                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleSelection(song);
                            } else {
                              final isCurrentSong =
                                  songProvider.currentSong?.id == song.id;
                              if (!isCurrentSong) {
                                songProvider.playSong(song, downloadedSongs);
                              } else {
                                if (songProvider.audioPlayer.playing) {
                                  songProvider.audioPlayer.pause();
                                } else {
                                  songProvider.audioPlayer.play();
                                }
                              }
                            }
                          },
                          child: Stack(
                            children: [
                              SongGridCard(
                                song: song,
                                imageUrl: song.coverUrl,
                                title: song.title,
                                subtitle:
                                    "${song.artist}\n${_formatDate(song.dateAdded)}",
                                showFavorite: false,
                              ),
                              if (_isSelectionMode)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Theme.of(
                                              context,
                                            ).primaryColor.withOpacity(0.3)
                                          : Colors.transparent,
                                      border: isSelected
                                          ? Border.all(
                                              color: Theme.of(
                                                context,
                                              ).primaryColor,
                                              width: 3,
                                            )
                                          : null,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: isSelected
                                        ? Center(
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.check,
                                                color: Theme.of(
                                                  context,
                                                ).primaryColor,
                                                size: 20,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        songProvider.currentSong != null ? 160 : 100,
                      ),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: filteredSongs.length,
                      itemBuilder: (context, index) {
                        final song = filteredSongs[index];
                        final isSelected = _selectedSongs.contains(song);

                        // Dosya boyutunu hesapla
                        String sizeStr = _getFileSizeString(song.localPath);
                        String artistText =
                            "${song.artist} • ${_formatDate(song.dateAdded)}";
                        if (sizeStr.isNotEmpty) {
                          artistText += " • $sizeStr";
                        }

                        // Tarihi göstermek için geçici bir Song nesnesi oluşturuyoruz
                        final displaySong = Song(
                          id: song.id,
                          title: song.title,
                          artist: artistText,
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
                              : GestureDetector(
                                  onTap: () => _showSongOptions(context, song),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.1),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.more_horiz,
                                      size: 20,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleSelection(song);
                            } else {
                              final isCurrentSong =
                                  songProvider.currentSong?.id == song.id;
                              if (!isCurrentSong) {
                                songProvider.playSong(song, downloadedSongs);
                              } else {
                                if (songProvider.audioPlayer.playing) {
                                  songProvider.audioPlayer.pause();
                                } else {
                                  songProvider.audioPlayer.play();
                                }
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
      ),
    );
  }
}
