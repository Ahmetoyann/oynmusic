// lib/pages/listeler_page.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/pages/downloads_page.dart';
import 'package:muzik_app/pages/profile_page.dart';
import 'package:muzik_app/providers/auth_provider.dart';

// 1. YENİ SAYFAYI IMPORT EDİYORUZ
import 'package:muzik_app/pages/folder_detail_page.dart';

enum SortOption { dateNewest, dateOldest, nameAZ, nameZA }

class ListelerPage extends StatefulWidget {
  const ListelerPage({super.key});

  @override
  State<ListelerPage> createState() => _ListelerPageState();
}

class _ListelerPageState extends State<ListelerPage> {
  SortOption _sortOption = SortOption.dateNewest;

  @override
  Widget build(BuildContext context) {
    // SongProvider'a bağlanarak oluşturulan klasörleri alıyoruz.
    final songProvider = context.watch<SongProvider>();
    final authProvider = context.watch<AuthProvider>();
    final folders = songProvider.folders;
    final hasConnection = songProvider.hasConnection;

    // Çevrimdışı ise sadece indirilenlerden oluşturulan listeleri göster
    final displayFolders = hasConnection
        ? folders
        : folders.where((f) => f.isFromDownloads).toList();

    // Sıralama için kopyasını alıyoruz
    var sortedFolders = List<MusicFolder>.from(displayFolders);

    // Sıralama işlemi
    switch (_sortOption) {
      case SortOption.nameAZ:
        sortedFolders.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SortOption.nameZA:
        sortedFolders.sort((a, b) => b.name.compareTo(a.name));
        break;
      case SortOption.dateNewest:
        sortedFolders = sortedFolders.reversed.toList();
        break;
      case SortOption.dateOldest:
        // Varsayılan sıralama (eklenme sırası)
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitaplığım'),
        centerTitle: false,
        automaticallyImplyLeading: false,
        leading: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
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
          if (sortedFolders.isNotEmpty)
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
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // İndirilenler Kartı
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Container(
              width: double.infinity,
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.teal.shade900,
                    Colors.teal.shade800.withOpacity(0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    bottom: -40,
                    child: Transform.rotate(
                      angle: -0.2,
                      child: CustomIcons.svgIcon(
                        CustomIcons.download,
                        size: 140,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DownloadsPage(),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: CustomIcons.svgIcon(
                                CustomIcons.download,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 20),
                            const Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "İndirilenler",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Çevrimdışı dinle",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            CustomIcons.svgIcon(
                              CustomIcons.arrowRight,
                              color: Colors.white54,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: (sortedFolders.isEmpty && !hasConnection)
                ? _buildEmptyState(context, hasConnection)
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.7,
                        ),
                    itemCount: hasConnection
                        ? sortedFolders.length + 5
                        : sortedFolders.length,
                    itemBuilder: (context, index) {
                      if (hasConnection) {
                        if (index < sortedFolders.length) {
                          return _buildFolderGridCard(
                            context,
                            sortedFolders[index],
                          );
                        }
                        return _buildCreateListGridCard(context);
                      }
                      return _buildFolderGridCard(
                        context,
                        sortedFolders[index],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateListGridCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _showCreateListSheet(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: CustomPaint(
              painter: _DashedBorderPainter(
                color: Colors.grey.shade700,
                strokeWidth: 1.5,
                radius: 12,
                gap: 6,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.add_rounded,
                    color: Colors.grey.shade600,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Yeni Liste",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          const Text("", style: TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildFolderGridCard(BuildContext context, MusicFolder folder) {
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
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildPlaylistCover(folder, isGrid: true),
                    if (folder.isFromDownloads)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.download_done,
                            size: 10,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                  ],
                ),
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

  Widget _buildPlaylistCover(MusicFolder folder, {bool isGrid = false}) {
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
    // Klasör türüne göre ikon ve renk seçimi
    final String icon = folder.isFromDownloads
        ? CustomIcons.download
        : CustomIcons.star;
    final Color iconColor = folder.isFromDownloads
        ? Colors.white
        : Colors.orange;

    if (songs.isEmpty) {
      return Container(
        color: Colors.grey.shade800,
        child: Center(
          child: CustomIcons.svgIcon(
            icon,
            color: iconColor,
            size: isGrid ? 28 : 24,
          ),
        ),
      );
    }

    if (songs.length < 4) {
      final song = songs.first;
      return _buildGridImage(song);
    }

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildGridImage(songs[0])),
              Expanded(child: _buildGridImage(songs[1])),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildGridImage(songs[2])),
              Expanded(child: _buildGridImage(songs[3])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGridImage(Song song) {
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
              size: 16,
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
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey.shade900,
          child: CustomIcons.svgIcon(
            CustomIcons.musicNote,
            size: 16,
            color: Colors.grey,
          ),
        );
      },
    );
  }

  void _showFolderOptions(BuildContext context, MusicFolder folder) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
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
              _showRenameBottomSheet(context, folder);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.redAccent),
            title: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              Navigator.pop(ctx);
              _showDeleteConfirmation(context, folder);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, MusicFolder folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Listeyi Sil', style: TextStyle(color: Colors.white)),
        content: Text(
          '${folder.name} listesi silinsin mi?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              context.read<SongProvider>().deleteFolder(folder);
              Navigator.pop(context);
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

  void _showRenameBottomSheet(BuildContext context, MusicFolder folder) {
    final TextEditingController controller = TextEditingController(
      text: folder.name,
    );

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
              'Listeyi Yeniden Adlandır',
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
                hintText: 'Yeni isim girin',
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
                    context.read<SongProvider>().renameFolder(
                      folder,
                      controller.text,
                    );
                    Navigator.pop(ctx);
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
                  'Kaydet',
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

  void _showCreateListSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const CreateListWithSongsSheet(),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool hasConnection) {
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
            child: hasConnection
                ? CustomIcons.svgIcon(
                    CustomIcons.library,
                    size: 64,
                    color: Theme.of(context).primaryColor.withOpacity(0.5),
                  )
                : CustomIcons.svgIcon(
                    CustomIcons.wifiOff,
                    size: 64,
                    color: Theme.of(context).primaryColor.withOpacity(0.5),
                  ),
          ),
          const SizedBox(height: 24),
          Text(
            hasConnection ? 'Henüz Liste Yok' : 'Çevrimdışı Mod',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasConnection
                ? 'Oluşturduğunuz çalma listeleri burada görünecek.'
                : 'Çevrimdışı modda görüntülenecek liste yok.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double gap;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.radius = 12.0,
    this.gap = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );

    final Path dashPath = Path();
    final double dashWidth = 8.0;
    double distance = 0.0;
    for (final ui.PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth;
        distance += gap;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class CreateListWithSongsSheet extends StatefulWidget {
  const CreateListWithSongsSheet({super.key});

  @override
  State<CreateListWithSongsSheet> createState() =>
      _CreateListWithSongsSheetState();
}

class _CreateListWithSongsSheetState extends State<CreateListWithSongsSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  late TabController _tabController;
  final Set<String> _selectedSongIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = context.watch<SongProvider>();
    final favorites = songProvider.favoriteSongs;
    final downloads = songProvider.downloadedSongs;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
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
              Text(
                'Yeni Liste Oluştur',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Liste adı',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    filled: true,
                    fillColor: Colors.grey.shade800,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                indicatorColor: Theme.of(context).primaryColor,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: 'Favoriler'),
                  Tab(text: 'İndirilenler'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSongList(favorites),
                    _buildSongList(downloads),
                  ],
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
                    onPressed: () {
                      if (_nameController.text.isNotEmpty) {
                        final allSongs = [...favorites, ...downloads];
                        final uniqueSelectedSongs = <String, Song>{};
                        for (var s in allSongs) {
                          if (_selectedSongIds.contains(s.id)) {
                            uniqueSelectedSongs[s.id] = s;
                          }
                        }

                        final provider = context.read<SongProvider>();
                        // Seçilen tüm şarkıların indirilmiş olup olmadığını kontrol et
                        final bool isAllDownloaded = uniqueSelectedSongs.values
                            .every((s) => provider.isSongDownloaded(s.id));

                        provider.createFolder(
                          name: _nameController.text,
                          songs: uniqueSelectedSongs.values.toList(),
                          isFromDownloads: isAllDownloaded,
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${_nameController.text} oluşturuldu.',
                            ),
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
                    child: Text(
                      'Oluştur (${_selectedSongIds.length})',
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
      },
    );
  }

  Widget _buildSongList(List<Song> songs) {
    if (songs.isEmpty) {
      return const Center(
        child: Text("Şarkı bulunamadı", style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        final isSelected = _selectedSongIds.contains(song.id);
        return CheckboxListTile(
          value: isSelected,
          activeColor: Theme.of(context).primaryColor,
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            song.artist,
            maxLines: 1,
            style: TextStyle(color: Colors.grey.shade400),
          ),
          secondary: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child:
                (song.localImagePath != null &&
                    File(song.localImagePath!).existsSync())
                ? Image.file(
                    File(song.localImagePath!),
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      width: 40,
                      height: 40,
                      color: Colors.grey.shade800,
                      child: const Icon(Icons.music_note, size: 20),
                    ),
                  )
                : Image.network(
                    song.coverUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      width: 40,
                      height: 40,
                      color: Colors.grey.shade800,
                      child: const Icon(Icons.music_note, size: 20),
                    ),
                  ),
          ),
          onChanged: (bool? value) {
            setState(() {
              if (value == true) {
                _selectedSongIds.add(song.id);
              } else {
                _selectedSongIds.remove(song.id);
              }
            });
          },
        );
      },
    );
  }
}
