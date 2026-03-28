// lib/pages/listeler_page.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/pages/downloads_page.dart';
import 'package:muzik_app/providers/auth_provider.dart';
import 'package:muzik_app/pages/settings_page.dart';

// 1. YENİ SAYFAYI IMPORT EDİYORUZ
import 'package:muzik_app/pages/folder_detail_page.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:muzik_app/widgets/custom_app_bar.dart';
import 'package:muzik_app/pages/recently_played_page.dart';
import 'package:muzik_app/widgets/song_grid_card.dart';
import 'package:muzik_app/pages/player_page.dart';
import 'package:muzik_app/widgets/custom_drop_down.dart';

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

    // En Son Dinlenenler için filtreleme
    final validRecentlyPlayed = songProvider.recentlyPlayed
        .where(
          (s) =>
              s.coverUrl.isNotEmpty &&
              !s.coverUrl.contains('via.placeholder.com'),
        )
        .toList();

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Kitaplığım',
        showLeading: false,
        actions: [
          IconButton(
            icon: CustomIcons.svgIcon(CustomIcons.settings, size: 24),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
          if (sortedFolders.isNotEmpty)
            CustomDropDown<SortOption>(
              icon: CustomIcons.svgIcon(CustomIcons.sort, size: 24),
              tooltip: "Sırala",
              onSelected: (SortOption result) {
                setState(() {
                  _sortOption = result;
                });
              },
              items: [
                CustomDropdownItem.build<SortOption>(
                  context: context,
                  value: SortOption.dateNewest,
                  icon: Icon(
                    Icons.arrow_downward_rounded,
                    size: 20,
                    color: Theme.of(context).primaryColor,
                  ),
                  text: 'Tarihe Göre (En Yeni)',
                ),
                CustomDropdownItem.build<SortOption>(
                  context: context,
                  value: SortOption.dateOldest,
                  icon: Icon(
                    Icons.arrow_upward_rounded,
                    size: 20,
                    color: Theme.of(context).primaryColor,
                  ),
                  text: 'Tarihe Göre (En Eski)',
                ),
                CustomDropdownItem.build<SortOption>(
                  context: context,
                  value: SortOption.nameAZ,
                  icon: Icon(
                    Icons.sort_by_alpha_rounded,
                    size: 20,
                    color: Theme.of(context).primaryColor,
                  ),
                  text: 'İsme Göre (A-Z)',
                ),
                CustomDropdownItem.build<SortOption>(
                  context: context,
                  value: SortOption.nameZA,
                  icon: Icon(
                    Icons.sort_by_alpha_rounded,
                    size: 20,
                    color: Theme.of(context).primaryColor,
                  ),
                  text: 'İsme Göre (Z-A)',
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
                    const Color(0xFF405DE6), // Royal Blue
                    const Color(0xFF833AB4), // Purple
                    const Color(0xFFE1306C), // Dark Pink
                    const Color(0xFFFD1D1D), // Red
                    const Color(0xFFF56040), // Orange
                    const Color(0xFFFCAF45), // Yellow
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
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
                      child: Icon(
                        Icons.downloading,
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
                              child: const Icon(
                                Icons.downloading,
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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

          if (validRecentlyPlayed.isNotEmpty) const SizedBox(height: 12),

          // --- EN SON DİNLEDİKLERİN BÖLÜMÜ ---
          if (validRecentlyPlayed.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                bottom: songProvider.currentSong != null ? 160 : 100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RecentlyPlayedPage(),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "En Son Dinlediklerin",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 150,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: validRecentlyPlayed.length > 10
                          ? 11
                          : validRecentlyPlayed.length,
                      itemBuilder: (context, index) {
                        if (validRecentlyPlayed.length > 10 && index == 10) {
                          return Container(
                            width: 110,
                            margin: const EdgeInsets.only(right: 12),
                            child: _buildSeeMoreCard(context),
                          );
                        }
                        final song = validRecentlyPlayed[index];
                        return Container(
                          width: 110,
                          margin: const EdgeInsets.only(right: 12),
                          child: _buildRecentlyPlayedCard(context, song),
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(height: songProvider.currentSong != null ? 160 : 100),
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
                  child: Text(
                    "+",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 40,
                      fontWeight: FontWeight.w300,
                    ),
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

  Widget _buildRecentlyPlayedCard(BuildContext context, Song song) {
    return SongGridCard(
      song: song,
      imageUrl: song.coverUrl,
      title: song.title,
      subtitle: song.artist,
      onTap: () {
        final provider = context.read<SongProvider>();
        if (provider.currentSong?.id == song.id) {
          if (provider.audioPlayer.playing) {
            provider.audioPlayer.pause();
          } else {
            provider.audioPlayer.play();
          }
        } else {
          provider.playSong(song, provider.recentlyPlayed);
        }
        PlayerPage.show(context);
      },
    );
  }

  Widget _buildSeeMoreCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RecentlyPlayedPage()),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Theme.of(context).primaryColor,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Devamını\nGör",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Tümü",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "Dinleme Geçmişi",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
          ),
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
                            Icons.downloading,
                            size: 16,
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

    if (songs.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey.shade800, Colors.grey.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: folder.isFromDownloads
              ? Icon(
                  Icons.downloading,
                  color: Colors.white,
                  size: isGrid ? 28 : 24,
                )
              : CustomIcons.svgIcon(
                  CustomIcons.star,
                  color: Colors.orange,
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
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey.shade800, Colors.grey.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.grey.shade800, Colors.grey.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        );
      },
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
            leading: CustomIcons.svgIcon(
              CustomIcons.edit,
              color: Colors.white,
              size: 24,
            ),
            title: const Text(
              'Yeniden Adlandır',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              _showRenameBottomSheet(context, folder);
            },
          ),
          ListTile(
            leading: CustomIcons.svgIcon(
              CustomIcons.delete,
              color: Colors.redAccent,
            ),
            title: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              Navigator.pop(context);
              _showDeleteConfirmation(context, folder);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, MusicFolder folder) {
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

  void _showRenameBottomSheet(BuildContext context, MusicFolder folder) {
    CustomBottomSheet.showContent(
      context: context,
      isScrollControlled: true,
      child: _RenameListSheet(folder: folder),
    );
  }

  void _showCreateListSheet(BuildContext context) {
    CustomBottomSheet.showContent(
      context: context,
      isScrollControlled: true,
      child: const CreateListWithSongsSheet(),
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

class _RenameListSheet extends StatefulWidget {
  final MusicFolder folder;
  const _RenameListSheet({required this.folder});

  @override
  State<_RenameListSheet> createState() => _RenameListSheetState();
}

class _RenameListSheetState extends State<_RenameListSheet> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.folder.name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
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
            controller: _controller,
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
                if (_controller.text.isNotEmpty) {
                  context.read<SongProvider>().renameFolder(
                    widget.folder,
                    _controller.text,
                  );
                  Navigator.pop(context);
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
    );
  }
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
  String? _selectedImagePath;

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

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImagePath = image.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = context.watch<SongProvider>();
    final favorites = songProvider.favoriteSongs;
    final downloads = songProvider.downloadedSongs;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
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
          // --- Modern Kapak Resmi Seçici ---
          GestureDetector(
            onTap: _pickImage,
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
                image: _selectedImagePath != null
                    ? DecorationImage(
                        image: FileImage(File(_selectedImagePath!)),
                        fit: BoxFit.cover,
                      )
                    : null,
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: _selectedImagePath == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CustomIcons.svgIcon(
                          CustomIcons.addPhotoAlternateRounded,
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
          // --- Modern İsim Girişi ---
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              controller: _nameController,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'Liste adı',
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                filled: true,
                fillColor: Colors.grey.shade800,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).primaryColor.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    labelColor: Theme.of(context).primaryColor,
                    unselectedLabelColor: Colors.grey.shade400,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    overlayColor: MaterialStateProperty.all(Colors.transparent),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    tabs: const [
                      Tab(text: 'Favoriler'),
                      Tab(text: 'İndirilenler'),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildSongList(favorites), _buildSongList(downloads)],
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).primaryColor.withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.2),
                          blurRadius: 15,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          // 1. İsim kontrolü
                          if (_nameController.text.isEmpty) {
                            CustomSnackBar.showError(
                              context: context,
                              message: 'Lütfen bir liste adı girin.',
                            );
                            return;
                          }

                          // 2. Şarkı seçimi kontrolü (YENİ)
                          if (_selectedSongIds.isEmpty) {
                            CustomSnackBar.showError(
                              context: context,
                              message: 'Lütfen en az bir şarkı seçin.',
                            );
                            return;
                          }

                          // 3. Liste oluşturma işlemleri
                          final allSongs = [...favorites, ...downloads];
                          final uniqueSelectedSongs = <String, Song>{};
                          for (var s in allSongs) {
                            if (_selectedSongIds.contains(s.id)) {
                              uniqueSelectedSongs[s.id] = s;
                            }
                          }

                          final provider = context.read<SongProvider>();
                          final bool isAllDownloaded = uniqueSelectedSongs
                              .values
                              .every((s) => provider.isSongDownloaded(s.id));

                          provider.createFolder(
                            name: _nameController.text,
                            songs: uniqueSelectedSongs.values.toList(),
                            isFromDownloads: isAllDownloaded,
                            customImagePath: _selectedImagePath,
                          );
                          Navigator.pop(context); // Sheet'i kapat
                          // Başarılı mesajı ana ekranda görünsün
                          CustomSnackBar.showSuccess(
                            context: context,
                            message: '${_nameController.text} oluşturuldu.',
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text(
                              'Oluştur (${_selectedSongIds.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongList(List<Song> songs) {
    if (songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIcons.svgIcon(
              CustomIcons.musicOffRounded,
              size: 64,
              color: Colors.grey.shade800,
            ),
            const SizedBox(height: 16),
            const Text(
              "Şarkı bulunamadı",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        final isSelected = _selectedSongIds.contains(song.id);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () {
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
                color: isSelected
                    ? Theme.of(context).primaryColor.withOpacity(0.15)
                    : Colors.grey.shade900.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child:
                        (song.localImagePath != null &&
                            File(song.localImagePath!).existsSync())
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
                            errorBuilder: (c, e, s) => Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey.shade800,
                              child: CustomIcons.svgIcon(
                                CustomIcons.musicNote,
                                color: Colors.grey,
                                size: 24,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                        ? CustomIcons.svgIcon(
                            CustomIcons.check,
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
    );
  }
}
