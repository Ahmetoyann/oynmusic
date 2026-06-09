import 'dart:io';
import 'dart:math';
import 'dart:ui';
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
import 'package:muzik_app/pages/folder_detail_page.dart';
import 'package:muzik_app/pages/player_page.dart';
import 'package:muzik_app/widgets/custom_drop_down.dart';
import 'package:muzik_app/widgets/custom_banner_ad.dart';
import 'package:muzik_app/providers/language_provider.dart';
import 'package:muzik_app/widgets/mini_player.dart';
import 'package:muzik_app/widgets/custom_search_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  final ScrollController _scrollController = ScrollController();
  bool _showStickyPlayButton = false;

  List<Song> _cachedFilteredSongs = [];
  int _lastListLength = -1;
  String _lastSearchText = '';
  SortOption _lastSortOption = SortOption.dateNewest;
  String _cachedDurationText = '';
  String _lastLanguage = '';

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        if (_scrollController.offset > 120 && !_showStickyPlayButton) {
          setState(() => _showStickyPlayButton = true);
        } else if (_scrollController.offset <= 120 && _showStickyPlayButton) {
          setState(() => _showStickyPlayButton = false);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

    final langProvider = context.read<LanguageProvider>();
    final TextEditingController controller = TextEditingController();
    String? selectedImagePath;

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (pageContext, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Theme.of(pageContext).scaffoldBackgroundColor,
            body: SafeArea(
              child: StatefulBuilder(
                builder: (modalContext, setModalState) => Column(
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
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 8),
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
                                width: 256,
                                height: 144,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade900,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                  image: selectedImagePath != null
                                      ? DecorationImage(
                                          image: FileImage(
                                              File(selectedImagePath!)),
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_a_photo_outlined,
                                            color:
                                                Theme.of(context).primaryColor,
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
                            // Modern TextField
                            Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: TextField(
                                controller: controller,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
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
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.5),
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
                                          if (controller.text.isNotEmpty) {
                                            final provider =
                                                context.read<SongProvider>();
                                            provider.createFolder(
                                              name: controller.text,
                                              songs: _selectedSongs.toList(),
                                              customImagePath:
                                                  selectedImagePath,
                                            );
                                            Navigator.pop(pageContext);
                                            setState(() {
                                              _isSelectionMode = false;
                                              _selectedSongs.clear();
                                            });
                                            CustomSnackBar.showSuccess(
                                              context: context,
                                              message:
                                                  '${controller.text} ${langProvider.t('create')}d.',
                                            );
                                          } else {
                                            CustomSnackBar.showError(
                                              context: context,
                                              message:
                                                  'Lütfen bir liste adı girin.',
                                            );
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          child: Center(
                                            child: Text(
                                              langProvider.t('create'),
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
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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

  void _showAddToPlaylistBottomSheet(BuildContext context) {
    if (_selectedSongs.isEmpty) return;

    final langProvider = context.read<LanguageProvider>();
    CustomBottomSheet.showContent(
      context: context,
      child: Consumer<SongProvider>(
        builder: (innerContext, songProvider, child) {
          final folders = songProvider.folders;
          final theme = Theme.of(innerContext);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
              Text(
                langProvider.t('add_to_playlist'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Modern "Yeni Liste Oluştur" Butonu
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.primaryColor.withOpacity(0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryColor.withOpacity(0.2),
                            blurRadius: 15,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _showCreatePlaylistBottomSheet(context);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CustomIcons.svgIcon(
                                  CustomIcons.addRounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  langProvider.t('create_new_list'),
                                  style: const TextStyle(
                                    color: Colors.white,
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
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (folders.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      CustomIcons.svgIcon(
                        CustomIcons.folderOpenRounded,
                        size: 48,
                        color: Colors.grey.shade800,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        langProvider.t('no_lists'),
                        style: const TextStyle(color: Colors.grey),
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
                          coverWidget = CachedNetworkImage(
                            imageUrl: firstSong.coverUrl,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade800,
                              child: CustomIcons.svgIcon(
                                CustomIcons.musicNote,
                                color: Colors.white54,
                                size: 24,
                              ),
                            ),
                          );
                        }
                      } else {
                        coverWidget = Container(
                          color: Colors.grey.shade800,
                          child: folder.isFromDownloads
                              ? CustomIcons.svgIcon(
                                  CustomIcons.downloadingRounded,
                                  color: Colors.white70,
                                  size: 24,
                                )
                              : CustomIcons.svgIcon(
                                  CustomIcons.musicNoteRounded,
                                  color: Colors.white70,
                                  size: 24,
                                ),
                        );
                      }

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              width: 71,
                              height: 40,
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
                            '${folder.songs.length} ${langProvider.t('song')}',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                          trailing: CustomIcons.svgIcon(
                            CustomIcons.arrowForwardIosRounded,
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
    final langProvider = context.read<LanguageProvider>();

    CustomBottomSheet.show(
      context: context,
      title: langProvider.t('remove_from_list'),
      message:
          '${_selectedSongs.length} ${langProvider.t('delete_selected_desc')}',
      primaryButtonText: langProvider.t('delete'),
      primaryButtonColor: Colors.redAccent,
      secondaryButtonText: langProvider.t('cancel'),
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
          message: langProvider.t('deleted'),
        );
      },
    );
  }

  void _showClearFavoritesDialog(BuildContext context) {
    final langProvider = context.read<LanguageProvider>();

    CustomBottomSheet.show(
      context: context,
      title: langProvider.t('delete_all'),
      message: langProvider.t('delete_all_desc'),
      primaryButtonText: langProvider.t('clear'),
      primaryButtonColor: Colors.red,
      secondaryButtonText: langProvider.t('cancel'),
      onPrimaryButtonTap: () {
        context.read<SongProvider>().clearAllFavorites();
        Navigator.pop(context);
        CustomSnackBar.showError(
          context: context,
          message: langProvider.t('all_deleted'),
        );
      },
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
            ),
            title: Text(
              langProvider.t('delete_list'),
              style: const TextStyle(color: Colors.redAccent),
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
            hintText: langProvider.t('new_name'),
            hintStyle: TextStyle(color: Colors.grey.shade500),
            filled: true,
            fillColor: Colors.grey.shade800,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
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

  void _showDeleteFolderDialog(BuildContext context, MusicFolder folder) {
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
                  children: [_buildFolderCover(folder)],
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

  Widget _buildFolderCover(MusicFolder folder) {
    final songs = folder.songs;

    Widget buildDefaultCover() {
      if (songs.isEmpty) {
        return Container(
          color: Colors.grey.shade800,
          child: Center(
            child: CustomIcons.svgIcon(
              CustomIcons.musicNote,
              color: Colors.white54,
              size: 32,
            ),
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
    if (song.localImagePath != null &&
        File(song.localImagePath!).existsSync()) {
      return ClipRect(
          child: Image.file(
        File(song.localImagePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade800,
            child: CustomIcons.svgIcon(
              CustomIcons.musicNote,
              color: Colors.grey,
              size: 24,
            ),
          );
        },
      ));
    }
    return ClipRect(
      child: CachedNetworkImage(
        imageUrl: song.coverUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorWidget: (c, e, s) => Container(
          color: Colors.grey.shade800,
          child: CustomIcons.svgIcon(
            CustomIcons.musicNote,
            color: Colors.grey,
            size: 24,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = context.watch<SongProvider>();
    final authProvider = context.watch<AuthProvider>();
    final langProvider = context.watch<LanguageProvider>();

    final favoriteSongs = songProvider.favoriteSongs;
    final folders = songProvider.folders;
    final favoriteFolders = folders.where((f) => !f.isFromDownloads).toList();
    final currentSongId = songProvider.currentSong?.id;

    // Arama ve sıralama önbellekleme (Memoization)
    if (_lastListLength != favoriteSongs.length ||
        _lastSearchText != _searchText ||
        _lastSortOption != _sortOption ||
        _lastLanguage != langProvider.currentLanguage) {
      _lastListLength = favoriteSongs.length;
      _lastSearchText = _searchText;
      _lastSortOption = _sortOption;
      _lastLanguage = langProvider.currentLanguage;

      var temp = favoriteSongs.where((song) {
        if (_searchText.isEmpty) return true;
        final query = _searchText.toLowerCase();
        return song.title.toLowerCase().contains(query) ||
            song.artist.toLowerCase().contains(query);
      }).toList();

      int totalSeconds =
          temp.fold(0, (sum, item) => sum + (item.duration ?? 0));
      String durText = '';
      if (totalSeconds > 0) {
        int h = totalSeconds ~/ 3600;
        int m = (totalSeconds % 3600) ~/ 60;
        int s = totalSeconds % 60;
        final isTr = langProvider.currentLanguage == 'tr';
        String hrStr = isTr ? 's' : 'h';
        String minStr = isTr ? 'd' : 'm';
        String secStr = isTr ? 'sn' : 's';

        if (h > 0) {
          durText = '·$h$hrStr $m$minStr';
        } else {
          durText = '·$m$minStr $s$secStr';
        }
      }
      _cachedDurationText = durText;

      switch (_sortOption) {
        case SortOption.nameAZ:
          temp.sort((a, b) => a.title.compareTo(b.title));
          break;
        case SortOption.nameZA:
          temp.sort((a, b) => b.title.compareTo(a.title));
          break;
        case SortOption.dateNewest:
          temp = temp.reversed.toList();
          break;
        case SortOption.dateOldest:
          break;
      }
      _cachedFilteredSongs = temp;
    }

    final filteredSongs = _cachedFilteredSongs;
    final durationText = _cachedDurationText;

    final bool canPopNavigator = Navigator.of(context).canPop();

    final bool isAnyFavoriteLoaded = currentSongId != null &&
        filteredSongs.any((s) => s.id == currentSongId);

    void handlePlayTap() {
      if (filteredSongs.isNotEmpty) {
        if (isAnyFavoriteLoaded) {
          if (songProvider.audioPlayer.playing) {
            songProvider.audioPlayer.pause();
          } else {
            songProvider.audioPlayer.play();
          }
        } else {
          Song songToPlay = filteredSongs.first;
          if (songProvider.isShuffleEnabled) {
            songToPlay = filteredSongs[Random().nextInt(filteredSongs.length)];
          }
          songProvider.playSong(songToPlay, filteredSongs);
          CustomSnackBar.showInfo(
            context: context,
            message: "Favoriler oynatılıyor.",
            icon: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 24,
            ),
          );
        }
      }
    }

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (_isSelectionMode) {
          setState(() {
            _isSelectionMode = false;
            _selectedSongs.clear();
          });
        }
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: CustomAppBar(
              showLeading: canPopNavigator,
              title: _isSelectionMode
                  ? '${_selectedSongs.length} Seçildi'
                  : langProvider.t('favorites'),
              leading: _isSelectionMode
                  ? IconButton(
                      icon: CustomIcons.svgIcon(CustomIcons.close, size: 24),
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = false;
                          _selectedSongs.clear();
                        });
                      },
                    )
                  : canPopNavigator
                      ? const BackButton(color: Colors.white)
                      : null,
              actions: [
                if (_isSelectionMode) ...[
                  IconButton(
                    icon: Icon(Icons.playlist_add, size: 24),
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
                ],
              ],
            ),
            backgroundColor: const Color(0xFF121212),
            extendBody: true,
            bottomNavigationBar: currentSongId != null
                ? Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          const Color(0xFF121212).withOpacity(
                            1,
                          ), // İçeriklerin arkadan flulaşarak görünmesi için şeffaflaştırıldı

                          const Color(0xFF121212).withOpacity(0.8),
                          const Color(0xFF121212).withOpacity(0.4),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.4, 0.8, 1.0],
                      ),
                    ),
                    child: SafeArea(
                      bottom: true,
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => PlayerPage.show(context),
                            child: const MiniPlayer(),
                          ),
                          const SizedBox(height: 2),
                        ],
                      ),
                    ),
                  )
                : null,
            body: Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      if (favoriteSongs.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              MediaQuery.of(context).size.width * 0.025,
                              16,
                              MediaQuery.of(context).size.width * 0.025,
                              8,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: CustomSearchBar(
                                    controller: _searchController,
                                    hintText:
                                        langProvider.t('search_in_favorites'),
                                    showClearButton: _searchText.isNotEmpty,
                                    onClear: () {
                                      setState(() => _searchText = '');
                                      FocusScope.of(context).unfocus();
                                    },
                                    onChanged: (value) =>
                                        setState(() => _searchText = value),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade900,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: CustomDropDown<SortOption>(
                                    icon: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          langProvider.t('sort') ?? "Sırala",
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                    ),
                                    tooltip: langProvider.t('sort'),
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
                                ),
                              ],
                            ),
                          ),
                        ),
                      // --- PLAY / SHUFFLE BUTONLARI ---
                      if (favoriteSongs.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.025,
                              vertical: 8.0,
                            ),
                            child: Row(
                              children: [
                                // 1. Karışık Çal Butonu
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 10,
                                      sigmaY: 10,
                                    ),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.2),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            if (filteredSongs.isNotEmpty) {
                                              songProvider.toggleShuffle();
                                              CustomSnackBar.showInfo(
                                                context: context,
                                                message: songProvider
                                                        .isShuffleEnabled
                                                    ? "Karışık çalma açık."
                                                    : "Karışık çalma kapalı.",
                                                icon: const Icon(
                                                  Icons.shuffle_rounded,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              );
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.shuffle_rounded,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                                if (songProvider
                                                    .isShuffleEnabled)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                      top: 2,
                                                    ),
                                                    width: 4,
                                                    height: 4,
                                                    decoration:
                                                        const BoxDecoration(
                                                      color: Colors.white,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // 2. Oynat Butonu
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 10,
                                      sigmaY: 10,
                                    ),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                          color: Theme.of(
                                            context,
                                          ).primaryColor.withOpacity(0.5),
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
                                          onTap: handlePlayTap,
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                          child: Center(
                                            child: StreamBuilder<bool>(
                                              stream: songProvider
                                                  .audioPlayer.playingStream,
                                              builder: (context, snapshot) {
                                                final playing =
                                                    snapshot.data ?? false;
                                                final isPlayingNow =
                                                    isAnyFavoriteLoaded &&
                                                        playing;
                                                return AnimatedSwitcher(
                                                  duration: const Duration(
                                                    milliseconds: 300,
                                                  ),
                                                  child: Icon(
                                                    isPlayingNow
                                                        ? Icons.pause_rounded
                                                        : Icons
                                                            .play_arrow_rounded,
                                                    key: ValueKey<bool>(
                                                      isPlayingNow,
                                                    ),
                                                    color: isPlayingNow
                                                        ? Colors.greenAccent
                                                        : Colors.white,
                                                    size: 26,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${filteredSongs.length} ${langProvider.t('song')}$durationText',
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // 3. Ekle (+) Butonu
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 10,
                                      sigmaY: 10,
                                    ),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.2),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              _isSelectionMode = true;
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                          child: Center(
                                            child: CustomIcons.svgIcon(
                                              CustomIcons.addRounded,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (favoriteFolders.isNotEmpty &&
                          !_isSelectionMode &&
                          _searchText.isEmpty)
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  MediaQuery.of(context).size.width * 0.025,
                                  12,
                                  MediaQuery.of(context).size.width * 0.025,
                                  8,
                                ),
                                child: Row(
                                  children: [
                                    CustomIcons.svgIcon(
                                      CustomIcons.folderSpecialRounded,
                                      color: Theme.of(context).primaryColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      langProvider.t('favorite_lists'),
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
                                height: 125,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: EdgeInsets.symmetric(
                                    horizontal:
                                        MediaQuery.of(context).size.width *
                                            0.025,
                                  ),
                                  itemCount: favoriteFolders.length,
                                  itemBuilder: (context, index) {
                                    return Container(
                                      width: 170,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: _buildFolderCard(
                                        context,
                                        favoriteFolders[index],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const Divider(color: Colors.white10, height: 24),
                            ],
                          ),
                        ),
                      if (favoriteSongs.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .primaryColor
                                        .withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.favorite,
                                    size: 80,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  langProvider.t('no_favorites_yet'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 48),
                                  child: Text(
                                    langProvider.t('no_favorites_desc'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 15,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 40),
                                InkWell(
                                  onTap: () {
                                    mainScreenKey.currentState?.switchToTab(0);
                                  },
                                  borderRadius: BorderRadius.circular(30),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .primaryColor
                                                .withOpacity(0.15),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .primaryColor
                                                  .withOpacity(0.5),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.add_rounded,
                                            color:
                                                Theme.of(context).primaryColor,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          langProvider.t('discover_songs'),
                                          style: TextStyle(
                                            color:
                                                Theme.of(context).primaryColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (filteredSongs.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              langProvider.t('no_results'),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            MediaQuery.of(context).size.width * 0.025,
                            12,
                            MediaQuery.of(context).size.width * 0.025,
                            currentSongId != null ? 160 : 100,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
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
                                showOptions: !_isSelectionMode,
                                isPlaying: currentSongId == song.id,
                                trailing: _isSelectionMode
                                    ? CustomIcons.svgIcon(
                                        isSelected
                                            ? CustomIcons.checkCircle
                                            : CustomIcons.circleOutlined,
                                        color: isSelected
                                            ? Theme.of(context).primaryColor
                                            : Colors.grey,
                                        size: 24,
                                      )
                                    : null,
                                onTap: () {
                                  if (_isSelectionMode) {
                                    _toggleSelection(song);
                                  } else {
                                    final isCurrentSong =
                                        currentSongId == song.id;
                                    if (isCurrentSong &&
                                        songProvider.audioPlayer.playing) {
                                      songProvider.audioPlayer.pause();
                                    } else if (isCurrentSong) {
                                      songProvider.audioPlayer.play();
                                    } else {
                                      songProvider.playSong(
                                        song,
                                        favoriteSongs,
                                      );
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
                            }, childCount: filteredSongs.length),
                          ),
                        ),
                    ],
                  ),
                ),
                // Banner Reklam Alanı
                // Reklamlar geçici olarak kapatıldığı için gizlendi.
                // const CustomBannerAd(),
              ],
            ),
          ),
          if (!_isSelectionMode && filteredSongs.isNotEmpty)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              // Butonu appbar ile body arasına tam ortalayarak Spotify tarzı bir geçiş sağlar
              top: _showStickyPlayButton
                  ? MediaQuery.of(context).padding.top + kToolbarHeight - 24
                  : MediaQuery.of(context).padding.top + kToolbarHeight + 30,
              right: MediaQuery.of(context).size.width * 0.05,
              child: IgnorePointer(
                ignoring: !_showStickyPlayButton,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _showStickyPlayButton ? 1.0 : 0.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.8),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: handlePlayTap,
                            borderRadius: BorderRadius.circular(28),
                            child: Center(
                              child: StreamBuilder<bool>(
                                stream: songProvider.audioPlayer.playingStream,
                                builder: (context, snapshot) {
                                  final playing = snapshot.data ?? false;
                                  final isPlayingNow =
                                      isAnyFavoriteLoaded && playing;
                                  return AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: Icon(
                                      isPlayingNow
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      key: ValueKey<bool>(isPlayingNow),
                                      color: isPlayingNow
                                          ? Colors.greenAccent
                                          : Colors.white,
                                      size: 28,
                                    ),
                                  );
                                },
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
}
