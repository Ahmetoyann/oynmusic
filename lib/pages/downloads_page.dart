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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                const Text(
                  "Şu an çevrimdışı moddasınız",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            backgroundColor: Colors.grey.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Klavye açıldığında yukarı kayması için
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
              Center(
                child: GestureDetector(
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
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(12),
                      image: selectedImagePath != null
                          ? DecorationImage(
                              image: FileImage(File(selectedImagePath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: selectedImagePath == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                color: Colors.grey.shade400,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Kapak Seç",
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'İndirilenlerden Liste Oluştur',
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
                      context.read<SongProvider>().createFolder(
                        name: controller.text,
                        songs: _selectedSongs.toList(),
                        isFromDownloads: true,
                        customImagePath: selectedImagePath,
                      );
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
                    'Listeye Ekle',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).primaryColor, // Burada context innerContext değil, üstteki context olmalı veya Theme.of(innerContext)
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
                    _showCreateFolderBottomSheet(context);
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

  void _showStopPlaybackWarningBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orangeAccent,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Şarkı Çalınıyor',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Şu an çalan şarkıyı durdurup, silmeye öyle devam edin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Tamam',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${song.title} cihazınızdan silinecek.',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            const Text(
              'Bu şarkı çalma listesinden de kaldırılacak.',
              style: TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final provider = context.read<SongProvider>();
              if (provider.currentSong?.id == song.id &&
                  provider.audioPlayer.playing) {
                Navigator.pop(ctx);
                _showStopPlaybackWarningBottomSheet(context);
                return;
              }
              provider.deleteDownloadedSong(song);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      CustomIcons.svgIcon(
                        CustomIcons.delete,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${song.title} silindi.',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
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
                SnackBar(
                  content: Row(
                    children: [
                      CustomIcons.svgIcon(
                        CustomIcons.delete, // Using delete as sweep replacement
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Tüm şarkılar silindi.',
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
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSongOptions(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
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
              leading: const Icon(Icons.playlist_play, color: Colors.white),
              title: const Text(
                'Sıradaki Çal',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                context.read<SongProvider>().addSongToNext(song);
              },
            ),
            ListTile(
              leading: CustomIcons.svgIcon(
                CustomIcons.delete,
                color: Colors.redAccent,
                size: 24,
              ),
              title: const Text(
                'Şarkıyı Sil',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirmationDialog(context, song);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showFolderOptions(BuildContext context, MusicFolder folder) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
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
                Navigator.pop(ctx);
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
                Navigator.pop(ctx);
                _pickFolderImage(context, folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text(
                'Listeyi Sil',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteFolderDialog(context, folder);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kapak resmi güncellendi'),
            backgroundColor: Colors.green,
          ),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Listeyi Sil', style: TextStyle(color: Colors.white)),
        content: Text(
          '${folder.name} listesi silinsin mi?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              context.read<SongProvider>().deleteFolder(folder);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${folder.name} silindi.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            child: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
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
    // Seçim modu açıksa veya çevrimdışı moddaysak (ana sayfa gibi davranmalı) otomatik çıkışı engelle
    final bool popScopeCanPop =
        !_isSelectionMode && songProvider.hasConnection && canPopNavigator;

    return PopScope(
      canPop: popScopeCanPop,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        if (_isSelectionMode) {
          setState(() {
            _isSelectionMode = false;
            _selectedSongs.clear();
          });
          return;
        }

        SystemNavigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: songProvider.hasConnection,
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
                icon: const Icon(Icons.playlist_add),
                tooltip: "Listeye Ekle",
                onPressed: () => _showAddToPlaylistBottomSheet(context),
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
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: "Seçenekler",
                onSelected: (value) {
                  switch (value) {
                    case 'view_mode':
                      setState(() {
                        _isGridMode = !_isGridMode;
                      });
                      break;
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
                        songProvider.playSong(
                          filteredSongs.first,
                          filteredSongs,
                        );
                      }
                      break;
                    case 'select':
                      setState(() {
                        _isSelectionMode = true;
                      });
                      break;
                    case 'delete_all':
                      _showDeleteAllConfirmationDialog(context);
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'view_mode',
                    child: Row(
                      children: [
                        Icon(
                          _isGridMode ? Icons.list : Icons.grid_view,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _isGridMode ? 'Liste Görünümü' : 'Izgara Görünümü',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
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
                    value: 'delete_all',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_sweep_outlined,
                          color: Colors.redAccent,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Tümünü Sil',
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
        body: Column(
          children: [
            if (downloadedSongs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
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
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                          ),
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
                        onChanged: (value) =>
                            setState(() => _searchText = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: PopupMenuButton<SortOption>(
                        icon: const Icon(Icons.sort, color: Colors.white),
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
                          CustomIcons.svgIcon(
                            CustomIcons.download,
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
                              : IconButton(
                                  icon: const Icon(
                                    Icons.more_horiz,
                                    color: Colors.white,
                                  ),
                                  onPressed: () =>
                                      _showSongOptions(context, song),
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
