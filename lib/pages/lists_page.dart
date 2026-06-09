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
import 'package:muzik_app/pages/recently_played_page.dart';
import 'package:muzik_app/pages/favorites_page.dart';

// 1. YENİ SAYFAYI IMPORT EDİYORUZ
import 'package:muzik_app/pages/folder_detail_page.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:muzik_app/widgets/custom_app_bar.dart';
import 'package:muzik_app/pages/player_page.dart';
import 'package:muzik_app/widgets/custom_drop_down.dart';
import 'package:muzik_app/providers/language_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ListelerPage extends StatefulWidget {
  const ListelerPage({super.key});

  @override
  State<ListelerPage> createState() => _ListelerPageState();
}

class _ListelerPageState extends State<ListelerPage> {
  @override
  Widget build(BuildContext context) {
    // SongProvider'a bağlanarak oluşturulan klasörleri alıyoruz.
    final songProvider = context.watch<SongProvider>();
    final folders = songProvider.folders;
    final hasConnection = songProvider.hasConnection;
    final currentSongId = songProvider.currentSong?.id;
    final authProvider = context.watch<AuthProvider>();
    final langProvider = context.watch<LanguageProvider>();

    // Çevrimdışı ise sadece indirilenlerden oluşturulan listeleri göster
    final displayFolders = hasConnection
        ? folders
        : folders.where((f) => f.isFromDownloads).toList();

    // Varsayılan olarak en yeni eklenen klasörler üstte görünsün
    final sortedFolders = displayFolders.reversed.toList();
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: CustomAppBar(
        title: langProvider.t('library'),
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
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst İkili Kartlar (İndirilenler ve Son Dinlenenler)
          Padding(
            padding: EdgeInsets.fromLTRB(
              screenWidth * 0.025,
              16,
              screenWidth * 0.025,
              12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFavoritesSquareCard(context),
                _buildRecentlyPlayedSquareCard(context),
              ],
            ),
          ),

          if (sortedFolders.isNotEmpty || hasConnection)
            Padding(
              padding: EdgeInsets.fromLTRB(
                screenWidth * 0.025,
                8,
                screenWidth * 0.025,
                8,
              ),
              child: Text(
                langProvider.t(
                    'my_playlists'), // "Çalma Listelerim" metnini dil dosyasından çeker
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          Expanded(
            child: (sortedFolders.isEmpty && !hasConnection)
                ? _buildEmptyState(context, hasConnection)
                : GridView.builder(
                    padding: EdgeInsets.fromLTRB(
                      screenWidth * 0.025,
                      8,
                      screenWidth * 0.025,
                      currentSongId != null ? 160 : 100,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.15,
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
    final langProvider = context.watch<LanguageProvider>();
    return GestureDetector(
      onTap: () => _showCreateListSheet(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: CustomPaint(
              painter: _DashedBorderPainter(
                color: Colors.grey.shade700,
                strokeWidth: 1.5,
                radius: 8,
                gap: 6,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
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
            langProvider.t('new_list'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
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
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
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
                          child: CustomIcons.svgIcon(
                            CustomIcons.downloadingRounded,
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
              ? CustomIcons.svgIcon(
                  CustomIcons.downloadingRounded,
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
      return ClipRect(
          child: Image.file(
        File(song.localImagePath!),
        fit: BoxFit.cover,
        cacheHeight: 400,
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
      ));
    }
    return ClipRect(
      child: CachedNetworkImage(
        imageUrl: song.coverUrl,
        fit: BoxFit.cover,
        memCacheHeight: 400,
        width: double.infinity,
        height: double.infinity,
        errorWidget: (context, url, error) {
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
      ),
    );
  }

  Widget _buildFavoritesSquareCard(BuildContext context) {
    final langProvider = context.watch<LanguageProvider>();
    final songProvider = context.read<SongProvider>();
    final favorites =
        context.select<SongProvider, List<Song>>((p) => p.favoriteSongs);
    final screenWidth = MediaQuery.of(context).size.width;
    // Toplam boşluk = 2 * (screenWidth * 0.025) + ortadaki 12px boşluk
    final cardSize = (screenWidth - (screenWidth * 0.05) - 12) / 2;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FavoritesPage()),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: cardSize,
            height: cardSize,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Üst Kısım
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            langProvider.t('favorites'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            langProvider.t('songs'),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    ClipOval(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                // Alt Kısım
                if (favorites.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (favorites.isNotEmpty)
                        Expanded(child: _buildMiniSong(favorites[0])),
                      if (favorites.length > 1) ...[
                        const SizedBox(width: 8),
                        Expanded(child: _buildMiniSong(favorites[1])),
                      ] else ...[
                        const Spacer(),
                      ],
                      const SizedBox(width: 8),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.black.withOpacity(0.5),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.08),
                              offset: const Offset(0, 1),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            "+${favorites.length}",
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            langProvider.t('discover_songs'),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentlyPlayedSquareCard(BuildContext context) {
    final langProvider = context.watch<LanguageProvider>();
    final songProvider = context.read<SongProvider>();
    final history =
        context.select<SongProvider, List<Song>>((p) => p.recentlyPlayed);
    final screenWidth = MediaQuery.of(context).size.width;
    final cardSize = (screenWidth - (screenWidth * 0.05) - 12) / 2;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RecentlyPlayedPage()),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: cardSize,
            height: cardSize,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade400.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Üst Kısım
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            langProvider.t('recently_played'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            langProvider.t('songs'),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    ClipOval(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                // Alt Kısım
                if (history.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (history.isNotEmpty)
                        Expanded(child: _buildMiniSong(history[0])),
                      if (history.length > 1) ...[
                        const SizedBox(width: 8),
                        Expanded(child: _buildMiniSong(history[1])),
                      ] else ...[
                        const Spacer(),
                      ],
                      const SizedBox(width: 8),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.black.withOpacity(0.5),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.08),
                              offset: const Offset(0, 1),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            "+${history.length}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            langProvider.t('no_history') ?? 'Geçmiş Boş',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniSong(Song song) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: AspectRatio(aspectRatio: 16 / 9, child: _buildGridImage(song)),
        ),
        const SizedBox(height: 6),
        Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showFolderOptions(BuildContext context, MusicFolder folder) {
    final langProvider = context.read<LanguageProvider>();
    CustomBottomSheet.showContent(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          ListTile(
            leading: CustomIcons.svgIcon(
              CustomIcons.edit,
              color: Colors.white,
              size: 24,
            ),
            title: Text(
              langProvider.t('rename'),
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              _showRenameFolderDialog(context, folder);
            },
          ),
          ListTile(
            leading: CustomIcons.svgIcon(
              CustomIcons.image,
              color: Colors.white,
              size: 24,
            ),
            title: Text(
              langProvider.t('change_cover'),
              style: const TextStyle(color: Colors.white),
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
              size: 24,
            ),
            title: Text(
              langProvider.t('delete_list'),
              style: const TextStyle(color: Colors.redAccent),
            ),
            onTap: () {
              Navigator.pop(context);
              _showDeleteConfirmation(context, folder);
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
    final langProvider = context.read<LanguageProvider>();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      context.read<SongProvider>().updateFolderImage(folder, image.path);
      if (mounted) {
        CustomSnackBar.showSuccess(
          context: context,
          message: langProvider.t('cover_updated'),
        );
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, MusicFolder folder) {
    final langProvider = context.read<LanguageProvider>();
    CustomBottomSheet.show(
      context: context,
      title: langProvider.t('delete_list'),
      message: '${folder.name} ${langProvider.t('delete_list_desc')}',
      primaryButtonText: langProvider.t('delete'),
      primaryButtonColor: Colors.redAccent,
      secondaryButtonText: langProvider.t('cancel'),
      onPrimaryButtonTap: () {
        context.read<SongProvider>().deleteFolder(folder);
        Navigator.pop(context);
        CustomSnackBar.showError(
          context: context,
          message: '${folder.name} ${langProvider.t('deleted')}',
        );
      },
    );
  }

  void _showRenameFolderDialog(BuildContext context, MusicFolder folder) {
    final langProvider = context.read<LanguageProvider>();
    final TextEditingController controller = TextEditingController(
      text: folder.name,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text(
          langProvider.t('rename'),
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: langProvider.t('new_name_hint'),
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
            child: Text(
              langProvider.t('cancel'),
              style: const TextStyle(color: Colors.white),
            ),
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
              langProvider.t('save'),
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

  void _showCreateListSheet(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (pageContext, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Theme.of(pageContext).scaffoldBackgroundColor,
            body: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 32),
                        onPressed: () => Navigator.pop(pageContext),
                      ),
                    ),
                  ),
                  const Expanded(child: CreateListWithSongsSheet()),
                ],
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
              position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool hasConnection) {
    final langProvider = context.watch<LanguageProvider>();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: hasConnection
                ? CustomIcons.svgIcon(
                    CustomIcons.library,
                    size: 64,
                    color: Theme.of(context).primaryColor,
                  )
                : Icon(
                    Icons.wifi_off,
                    size: 64,
                    color: Theme.of(context).primaryColor,
                  ),
          ),
          const SizedBox(height: 24),
          Text(
            hasConnection
                ? langProvider.t('no_lists')
                : langProvider.t('offline_mode_msg'),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              hasConnection
                  ? langProvider.t('no_lists_desc')
                  : langProvider.t('no_offline_lists'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
            ),
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
    final langProvider = context.watch<LanguageProvider>();
    final songProvider = context.watch<SongProvider>();
    final favorites = songProvider.favoriteSongs;
    final downloads = songProvider.downloadedSongs;

    return Column(
      children: [
        // --- Modern Kapak Resmi Seçici ---
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: 256,
            height: 144,
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
                      Icon(
                        Icons.add_a_photo_outlined,
                        color: Theme.of(context).primaryColor,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        langProvider.t('choose_cover'),
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
              hintText: langProvider.t('list_name'),
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
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
              ),
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              overlayColor: MaterialStateProperty.all(Colors.transparent),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              tabs: [
                Tab(text: langProvider.t('favorites')),
                Tab(text: langProvider.t('downloads')),
              ],
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
            16,
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
                            message: langProvider.t(
                              'select_at_least_one_song',
                            ),
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
                        final bool isAllDownloaded = uniqueSelectedSongs.values
                            .every((s) => provider.isSongDownloaded(s.id));

                        provider.createFolder(
                          name: _nameController.text,
                          songs: uniqueSelectedSongs.values.toList(),
                          isFromDownloads: isAllDownloaded,
                          customImagePath: _selectedImagePath,
                        );
                        CustomSnackBar.showSuccess(
                          context: context,
                          message: '${_nameController.text} oluşturuldu.',
                        );
                        Navigator.pop(context); // Sheet'i kapat
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            '${langProvider.t('create')} (${_selectedSongIds.length})',
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
    );
  }

  Widget _buildSongList(List<Song> songs) {
    final langProvider = context.watch<LanguageProvider>();

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
            Text(
              langProvider.t('no_results'),
              style: const TextStyle(color: Colors.grey),
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
                borderRadius: BorderRadius.circular(8),
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
                    borderRadius: BorderRadius.circular(4),
                    child: (song.localImagePath != null &&
                            File(song.localImagePath!).existsSync())
                        ? Image.file(
                            File(song.localImagePath!),
                            width: 71,
                            height: 40,
                            fit: BoxFit.cover,
                          )
                        : CachedNetworkImage(
                            imageUrl: song.coverUrl,
                            width: 71,
                            height: 40,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(
                              width: 71,
                              height: 40,
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
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 10,
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
