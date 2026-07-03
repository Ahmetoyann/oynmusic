import 'dart:io';
import 'dart:math';
import 'dart:ui';
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
import 'package:muzik_app/widgets/custom_drop_down.dart';
import 'package:muzik_app/providers/language_provider.dart';
import 'package:muzik_app/widgets/custom_search_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:muzik_app/widgets/device_cover_placeholder.dart';
import 'package:muzik_app/pages/downloaded_videos_view.dart';
import 'package:on_audio_query/on_audio_query.dart';

enum SortOption { dateNewest, dateOldest, nameAZ, nameZA }

class OfflineDownloadsPage extends StatefulWidget {
  final bool isDirectOffline;
  const OfflineDownloadsPage({super.key, this.isDirectOffline = false});

  @override
  State<OfflineDownloadsPage> createState() => _OfflineDownloadsPageState();
}

class _OfflineDownloadsPageState extends State<OfflineDownloadsPage> {
  bool _isSelectionMode = false;
  final Set<Song> _selectedSongs = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  SortOption _sortOption = SortOption.dateNewest;
  bool _isGridMode = false;
  bool _isVideosGridMode = true;
  final ScrollController _scrollController = ScrollController();
  bool _showStickyPlayButton = false;
  late SongProvider _songProvider;
  bool _showVideos = false;
  int _selectedTabIndex = 0; // 0: Uygulama İndirmeleri, 1: Cihazımdaki Müzikler
  int _lastTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _songProvider = context.read<SongProvider>();
    _songProvider.addListener(_onConnectionChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _songProvider.loadDeviceSongs(); // Cihazdaki müzikleri otomatik tara
      final hasConnection = _songProvider.hasConnection;
      final langProvider = context.read<LanguageProvider>();
      if (!hasConnection) {
        CustomSnackBar.showInfo(
          context: context,
          message: langProvider.t('offline_mode_msg'),
          icon: const Icon(Icons.wifi_off, color: Colors.white, size: 24),
          duration: const Duration(seconds: 3),
        );
      }
    });
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

  void _onConnectionChanged() {
    if (!mounted) return;
    // İnternet geri geldiğinde bu sayfayı (ve üzerinde açılmış klasör sayfalarını) kapatarak Ana Ekrana dön
    if (_songProvider.hasConnection) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    _songProvider.removeListener(_onConnectionChanged);
    _scrollController.dispose();
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
                                            context
                                                .read<SongProvider>()
                                                .createFolder(
                                                  name: controller.text,
                                                  songs:
                                                      _selectedSongs.toList(),
                                                  isFromDownloads: true,
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
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (pageContext, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Theme.of(pageContext).scaffoldBackgroundColor,
            body: SafeArea(
              child: Consumer<SongProvider>(
                builder: (innerContext, songProvider, child) {
                  final folders = songProvider.folders;
                  final theme = Theme.of(innerContext);

                  return Column(
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
                      const SizedBox(height: 8),
                      Icon(Icons.playlist_add_check_circle_rounded,
                          size: 64, color: theme.primaryColor),
                      const SizedBox(height: 16),
                      Text(
                        langProvider.t('add_to_playlist'),
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Modern "Yeni Liste Oluştur" Butonu
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.primaryColor.withOpacity(0.5),
                                width: 1.5,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(pageContext);
                                  _showCreateFolderBottomSheet(context);
                                },
                                borderRadius: BorderRadius.circular(16),
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
                      const SizedBox(height: 24),

                      if (folders.isEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
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
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 8),
                            itemCount: folders.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
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
                                    File(firstSong.localImagePath!)
                                        .existsSync()) {
                                  coverWidget = Image.file(
                                    File(firstSong.localImagePath!),
                                    fit: BoxFit.cover,
                                  );
                                } else {
                                  coverWidget = CachedNetworkImage(
                                    imageUrl: firstSong.coverUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (c, e, s) =>
                                        DeviceCoverPlaceholder(
                                      width: 71,
                                      height: 40,
                                      borderRadius: 8,
                                      logoColor: Theme.of(context).primaryColor,
                                    ),
                                  );
                                }
                              } else {
                                coverWidget = DeviceCoverPlaceholder(
                                  width: 71,
                                  height: 40,
                                  borderRadius: 8,
                                  logoColor: Theme.of(context).primaryColor,
                                );
                              }

                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.1)),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(8),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
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
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${folder.songs.length} ${langProvider.t('song')}',
                                    style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 13),
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: CustomIcons.svgIcon(
                                      CustomIcons.arrowForwardIosRounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                  onTap: () {
                                    songProvider.addSongsToFolder(
                                      folder,
                                      _selectedSongs.toList(),
                                    );
                                    Navigator.pop(pageContext);
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
                    ],
                  );
                },
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

  void _showStopPlaybackWarningBottomSheet(BuildContext context) {
    final langProvider = context.read<LanguageProvider>();
    CustomBottomSheet.show(
      context: context,
      title: langProvider.t('song_playing_title'),
      message: langProvider.t('song_playing_warning'),
      icon: CustomIcons.svgIcon(
        CustomIcons.warningAmberRounded,
        color: Colors.orangeAccent,
        size: 48,
      ),
      primaryButtonText: langProvider.t('ok'),
      primaryButtonColor: Colors.grey.shade800,
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, Song song) {
    final langProvider = context.read<LanguageProvider>();
    CustomBottomSheet.show(
      context: context,
      title: langProvider.t('delete_confirmation'),
      message: '${song.title} ${langProvider.t('delete_device_desc')}',
      primaryButtonText: langProvider.t('delete'),
      primaryButtonColor: Colors.redAccent,
      secondaryButtonText: langProvider.t('cancel'),
      onPrimaryButtonTap: () async {
        final provider = context.read<SongProvider>();
        if (provider.currentSong?.id == song.id &&
            provider.audioPlayer.playing) {
          Navigator.pop(context);
          _showStopPlaybackWarningBottomSheet(context);
          return;
        }

        final isDeviceSong =
            song.localPath != null && song.audioUrl == song.localPath;
        try {
          if (isDeviceSong) {
            await provider.deleteDeviceSong(song);
          } else {
            await provider.deleteDownloadedSong(song);
          }
          if (context.mounted) {
            Navigator.pop(context);
            CustomSnackBar.showError(
              context: context,
              message: '${song.title} ${langProvider.t('deleted')}',
            );
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.pop(context);
            CustomSnackBar.showError(
              context: context,
              message: 'Silinemedi. Depolama izni gerekebilir.',
            );
          }
        }
      },
    );
  }

  void _showDeleteSelectedDialog(BuildContext context) {
    final provider = context.read<SongProvider>();
    final langProvider = context.read<LanguageProvider>();
    CustomBottomSheet.show(
      context: context,
      title: langProvider.t('delete_selected'),
      message:
          '${_selectedSongs.length} ${langProvider.t('delete_selected_desc')}',
      primaryButtonText: langProvider.t('delete'),
      primaryButtonColor: Colors.redAccent,
      secondaryButtonText: langProvider.t('cancel'),
      onPrimaryButtonTap: () async {
        final provider = context.read<SongProvider>();
        if (provider.currentSong != null && provider.audioPlayer.playing) {
          if (_selectedSongs.any((s) => s.id == provider.currentSong!.id)) {
            Navigator.pop(context);
            _showStopPlaybackWarningBottomSheet(context);
            return;
          }
        }

        Navigator.pop(context);

        int failedCount = 0;
        for (var song in _selectedSongs) {
          final isDeviceSong =
              song.localPath != null && song.audioUrl == song.localPath;
          try {
            if (isDeviceSong) {
              await provider.deleteDeviceSong(song);
            } else {
              await provider.deleteDownloadedSong(song);
            }
          } catch (e) {
            failedCount++;
          }
        }

        setState(() {
          _isSelectionMode = false;
          _selectedSongs.clear();
        });

        if (failedCount > 0) {
          CustomSnackBar.showError(
            context: context,
            message:
                '$failedCount dosya silinemedi (İzin kısıtlaması olabilir).',
          );
        } else {
          CustomSnackBar.showError(
            context: context,
            message: langProvider.t('deleted'),
          );
        }
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
                    _buildFolderCover(folder),
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

    if (song.coverUrl.isEmpty) {
      return DeviceCoverPlaceholder(
        logoColor: Theme.of(context).primaryColor,
      );
    }

    return ClipRect(
      child: CachedNetworkImage(
        imageUrl: song.coverUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorWidget: (context, url, error) => Container(
          color: Colors.grey.shade800,
          child: Center(
            child: CustomIcons.svgIcon(
              CustomIcons.musicNote,
              color: Colors.white54,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = context.watch<SongProvider>();
    final langProvider = context.watch<LanguageProvider>();
    final downloadedSongs = songProvider.downloadedSongs;
    final downloadFolders =
        songProvider.folders.where((f) => f.isFromDownloads).toList();
    final rawSongs =
        _selectedTabIndex == 0 ? downloadedSongs : songProvider.deviceSongs;

    var filteredSongs = rawSongs.where((song) {
      if (_searchText.isEmpty) return true;
      final query = _searchText.toLowerCase();
      return song.title.toLowerCase().contains(query) ||
          song.artist.toLowerCase().contains(query);
    }).toList();

    int totalSeconds = filteredSongs.fold(
      0,
      (sum, item) => sum + (item.duration ?? 0),
    );
    String durationText = '';
    if (totalSeconds > 0) {
      int h = totalSeconds ~/ 3600;
      int m = (totalSeconds % 3600) ~/ 60;
      int s = totalSeconds % 60;
      final isTr = langProvider.currentLanguage == 'tr';
      String hrStr = isTr ? 's' : 'h';
      String minStr = isTr ? 'd' : 'm';
      String secStr = isTr ? 'sn' : 's';
      if (h > 0) {
        durationText = '·$h$hrStr $m$minStr';
      } else {
        durationText = '·$m$minStr $s$secStr';
      }
    }

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
        break;
    }

    final bool isAnyLoaded = songProvider.currentSong != null &&
        filteredSongs.any((s) => s.id == songProvider.currentSong!.id);
    final bool isPlaying = isAnyLoaded && songProvider.audioPlayer.playing;

    void handlePlayTap() {
      if (filteredSongs.isNotEmpty) {
        if (isAnyLoaded) {
          if (songProvider.audioPlayer.playing) {
            songProvider.audioPlayer.pause();
          } else {
            songProvider.audioPlayer.play();
          }
        } else {
          if (songProvider.isShuffleEnabled) {
            songProvider.toggleShuffle();
          }
          songProvider.playSong(filteredSongs.first, filteredSongs);
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
      child: Scaffold(
        extendBody: true,
        backgroundColor: const Color(0xFF121212),
        appBar: CustomAppBar(
          showLeading: _isSelectionMode || !widget.isDirectOffline,
          title: null,
          titleWidget: _isSelectionMode
              ? Text(
                  '${_selectedSongs.length} Seçildi',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      langProvider.t('downloads'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Theme(
                      data: Theme.of(context).copyWith(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                      ),
                      child: PopupMenuButton<bool>(
                        onSelected: (bool isVideo) {
                          setState(() {
                            _showVideos = isVideo;
                            _isSelectionMode = false;
                            _selectedSongs.clear();
                          });
                        },
                        color: const Color(0xFF1E1E1E),
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        offset: const Offset(0, 40),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _showVideos
                                    ? Icons.videocam_rounded
                                    : Icons.music_note_rounded,
                                color: Theme.of(context).primaryColor,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _showVideos ? "MP4" : "MP3",
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Theme.of(context).primaryColor,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: false,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.music_note_rounded,
                                  color: !_showVideos
                                      ? Theme.of(context).primaryColor
                                      : Colors.white70,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text("MP3 Ses",
                                    style: TextStyle(
                                        color: !_showVideos
                                            ? Theme.of(context).primaryColor
                                            : Colors.white,
                                        fontWeight: !_showVideos
                                            ? FontWeight.bold
                                            : FontWeight.normal)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: true,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.videocam_rounded,
                                  color: _showVideos
                                      ? Theme.of(context).primaryColor
                                      : Colors.white70,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text("MP4 Video",
                                    style: TextStyle(
                                        color: _showVideos
                                            ? Theme.of(context).primaryColor
                                            : Colors.white,
                                        fontWeight: _showVideos
                                            ? FontWeight.bold
                                            : FontWeight.normal)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
              : (widget.isDirectOffline
                  ? null
                  : const BackButton(color: Colors.white)),
          actions: [
            if (_isSelectionMode) ...[
              IconButton(
                icon: const Icon(Icons.playlist_add, size: 24),
                tooltip: langProvider.t('add_to_playlist'),
                onPressed: () => _showAddToPlaylistBottomSheet(context),
              ),
              IconButton(
                icon: CustomIcons.svgIcon(
                  CustomIcons.delete,
                  color: Colors.redAccent,
                ),
                tooltip: langProvider.t('delete'),
                onPressed: () => _showDeleteSelectedDialog(context),
              ),
            ] else if (!_showVideos && downloadedSongs.isNotEmpty) ...[
              IconButton(
                icon: CustomIcons.svgIcon(
                  _isGridMode ? CustomIcons.list : CustomIcons.gridView,
                  size: 24,
                ),
                tooltip: langProvider.t('view'),
                onPressed: () {
                  setState(() {
                    _isGridMode = !_isGridMode;
                  });
                },
              ),
            ] else if (_showVideos &&
                _songProvider.downloadedVideos.isNotEmpty) ...[
              IconButton(
                icon: CustomIcons.svgIcon(
                  _isVideosGridMode ? CustomIcons.list : CustomIcons.gridView,
                  size: 24,
                ),
                tooltip: langProvider.t('view'),
                onPressed: () {
                  setState(() {
                    _isVideosGridMode = !_isVideosGridMode;
                  });
                },
              ),
            ],
          ],
        ),
        bottomNavigationBar: songProvider.currentSong != null
            ? Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      const Color(0xFF121212).withOpacity(1),
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
        body: _showVideos
            ? DownloadedVideosView(isGridMode: _isVideosGridMode)
            : Stack(
                children: [
                  CustomScrollView(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      if (downloadedSongs.isNotEmpty)
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
                                        langProvider.t('search_in_downloads'),
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
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: CustomDropDown<SortOption>(
                                    icon: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          langProvider.t('sort'),
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
                      if (!_showVideos)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal:
                                    MediaQuery.of(context).size.width * 0.025,
                                vertical: 8.0),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                      color: Colors.white.withOpacity(0.1),
                                      width: 1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _selectedTabIndex = 0),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: _selectedTabIndex == 0
                                                  ? Theme.of(context)
                                                      .primaryColor
                                                  : Colors.transparent,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            langProvider.t('app_downloads'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: _selectedTabIndex == 0
                                                  ? Theme.of(context)
                                                      .primaryColor
                                                  : Colors.grey,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() => _selectedTabIndex = 1);
                                        songProvider.loadDeviceSongs(
                                            forceRefresh: true);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: _selectedTabIndex == 1
                                                  ? Theme.of(context)
                                                      .primaryColor
                                                  : Colors.transparent,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            langProvider.t('device_music'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: _selectedTabIndex == 1
                                                  ? Theme.of(context)
                                                      .primaryColor
                                                  : Colors.grey,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
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
                        ),
                      if (rawSongs.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.025,
                              vertical: 8.0,
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 10, sigmaY: 10),
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
                                              if (!songProvider
                                                  .isShuffleEnabled) {
                                                songProvider.toggleShuffle();
                                              }
                                              final random = Random();
                                              final randomSong =
                                                  filteredSongs[random.nextInt(
                                                filteredSongs.length,
                                              )];
                                              songProvider.playSong(
                                                randomSong,
                                                filteredSongs,
                                              );
                                              CustomSnackBar.showInfo(
                                                context: context,
                                                message:
                                                    "İndirilenler karışık çalınıyor.",
                                                icon: const Icon(
                                                  Icons.shuffle_rounded,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              );
                                            }
                                          },
                                          borderRadius:
                                              BorderRadius.circular(30),
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
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 10, sigmaY: 10),
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
                                          onTap: () {
                                            if (filteredSongs.isNotEmpty) {
                                              if (songProvider
                                                  .isShuffleEnabled) {
                                                songProvider.toggleShuffle();
                                              }
                                              songProvider.playSong(
                                                filteredSongs.first,
                                                filteredSongs,
                                              );
                                              CustomSnackBar.showInfo(
                                                context: context,
                                                message:
                                                    "İndirilenler oynatılıyor.",
                                                icon: CustomIcons.svgIcon(
                                                  CustomIcons.playArrow,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              );
                                            }
                                          },
                                          borderRadius:
                                              BorderRadius.circular(30),
                                          child: Center(
                                            child: StreamBuilder<bool>(
                                              stream: songProvider
                                                  .audioPlayer.playingStream,
                                              builder: (context, snapshot) {
                                                final playing =
                                                    snapshot.data ?? false;
                                                final isPlayingNow =
                                                    isAnyLoaded && playing;
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
                                                        isPlayingNow),
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
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 10, sigmaY: 10),
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
                                          borderRadius:
                                              BorderRadius.circular(30),
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
                                if (_selectedTabIndex == 1) ...[
                                  const SizedBox(height: 40),
                                  InkWell(
                                    onTap: () {
                                      songProvider.loadDeviceSongs(
                                          forceRefresh: true);
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
                                              Icons.refresh_rounded,
                                              color: Theme.of(context)
                                                  .primaryColor,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Cihazı Tara',
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .primaryColor,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      if (_selectedTabIndex == 0 &&
                          downloadFolders.isNotEmpty &&
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
                                      CustomIcons.folderOpenRounded,
                                      color: Theme.of(context).primaryColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      langProvider.t('offline_lists'),
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
                                  itemCount: downloadFolders.length,
                                  itemBuilder: (context, index) {
                                    return Container(
                                      width: 170,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: _buildFolderCard(
                                        context,
                                        downloadFolders[index],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const Divider(color: Colors.white10, height: 24),
                            ],
                          ),
                        ),
                      if (rawSongs.isEmpty)
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
                                  child: CustomIcons.svgIcon(
                                    CustomIcons.downloadingRounded,
                                    size: 80,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  _selectedTabIndex == 0
                                      ? langProvider.t('no_downloads')
                                      : 'Cihazda Müzik Bulunamadı',
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
                                    _selectedTabIndex == 0
                                        ? langProvider.t('no_downloads_desc')
                                        : 'Cihazınızda oynatılabilir bir müzik dosyası bulunamadı.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 15,
                                      height: 1.4,
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
                      else if (_isGridMode)
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            MediaQuery.of(context).size.width * 0.025,
                            16,
                            MediaQuery.of(context).size.width * 0.025,
                            songProvider.currentSong != null ? 160 : 100,
                          ),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.85,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 12,
                            ),
                            delegate:
                                SliverChildBuilderDelegate((context, index) {
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
                                      songProvider.playSong(song, rawSongs);
                                    } else {
                                      if (songProvider.audioPlayer.playing) {
                                        songProvider.audioPlayer.pause();
                                      } else {
                                        songProvider.audioPlayer.play();
                                      }
                                    }
                                  }
                                },
                                child: _selectedTabIndex == 1
                                    ? Container(
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Theme.of(context)
                                                  .primaryColor
                                                  .withOpacity(0.2)
                                              : Colors.white.withOpacity(0.02),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: isSelected
                                              ? Border.all(
                                                  color: Theme.of(context)
                                                      .primaryColor,
                                                  width: 2)
                                              : Border.all(
                                                  color: Colors.white
                                                      .withOpacity(0.05),
                                                  width: 1),
                                        ),
                                        child: Stack(
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      const BorderRadius
                                                          .vertical(
                                                          top: Radius.circular(
                                                              7)),
                                                  child: AspectRatio(
                                                    aspectRatio: 16 / 9,
                                                    child:
                                                        DeviceCoverPlaceholder(
                                                      borderRadius: 7,
                                                      logoColor:
                                                          Theme.of(context)
                                                              .primaryColor,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            8.0),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Text(
                                                          song.title,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                              color: songProvider
                                                                          .currentSong
                                                                          ?.id ==
                                                                      song.id
                                                                  ? Theme.of(
                                                                          context)
                                                                      .primaryColor
                                                                  : Colors
                                                                      .white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 13),
                                                        ),
                                                        const SizedBox(
                                                            height: 4),
                                                        Text(
                                                          "${song.artist}\n${_formatDate(song.dateAdded)}",
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                              color: songProvider
                                                                          .currentSong
                                                                          ?.id ==
                                                                      song.id
                                                                  ? Theme.of(
                                                                          context)
                                                                      .primaryColor
                                                                      .withOpacity(
                                                                          0.7)
                                                                  : Colors.grey
                                                                      .shade400,
                                                              fontSize: 11),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (_isSelectionMode && isSelected)
                                              Positioned.fill(
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context)
                                                        .primaryColor
                                                        .withOpacity(0.3),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Center(
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              4),
                                                      decoration:
                                                          const BoxDecoration(
                                                        color: Colors.white,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child:
                                                          CustomIcons.svgIcon(
                                                        CustomIcons.check,
                                                        color: Theme.of(context)
                                                            .primaryColor,
                                                        size: 20,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      )
                                    : Stack(
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
                                                      ? Theme.of(context)
                                                          .primaryColor
                                                          .withOpacity(0.3)
                                                      : Colors.transparent,
                                                  border: isSelected
                                                      ? Border.all(
                                                          color:
                                                              Theme.of(context)
                                                                  .primaryColor,
                                                          width: 3,
                                                        )
                                                      : null,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: isSelected
                                                    ? Center(
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(4),
                                                          decoration:
                                                              const BoxDecoration(
                                                            color: Colors.white,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                          child: CustomIcons
                                                              .svgIcon(
                                                            CustomIcons.check,
                                                            color: Theme.of(
                                                                    context)
                                                                .primaryColor,
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
                            }, childCount: filteredSongs.length),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            MediaQuery.of(context).size.width * 0.025,
                            16,
                            MediaQuery.of(context).size.width * 0.025,
                            songProvider.currentSong != null ? 160 : 100,
                          ),
                          sliver: SliverList(
                            delegate:
                                SliverChildBuilderDelegate((context, index) {
                              final song = filteredSongs[index];
                              final isSelected = _selectedSongs.contains(song);

                              String sizeStr =
                                  _getFileSizeString(song.localPath);
                              String artistText =
                                  "${song.artist} • ${_formatDate(song.dateAdded)}";
                              if (sizeStr.isNotEmpty) {
                                artistText += " • $sizeStr";
                              }

                              final displaySong = Song(
                                id: song.id,
                                title: song.title,
                                artist: artistText,
                                coverUrl:
                                    _selectedTabIndex == 1 ? '' : song.coverUrl,
                                audioUrl: song.audioUrl,
                                duration: song.duration,
                                localPath: song.localPath,
                                localImagePath: _selectedTabIndex == 1
                                    ? null
                                    : song.localImagePath,
                                dateAdded: song.dateAdded,
                              );

                              if (_selectedTabIndex == 1) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context)
                                            .primaryColor
                                            .withOpacity(0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: isSelected
                                        ? Border.all(
                                            color:
                                                Theme.of(context).primaryColor,
                                            width: 1)
                                        : Border.all(
                                            color: Colors.transparent,
                                            width: 1),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: SizedBox(
                                        width: 71,
                                        height: 40,
                                        child: DeviceCoverPlaceholder(
                                          width: 71,
                                          height: 40,
                                          borderRadius: 6,
                                          logoColor:
                                              Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      song.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: songProvider.currentSong?.id ==
                                                  song.id
                                              ? Theme.of(context).primaryColor
                                              : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      artistText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: songProvider.currentSong?.id ==
                                                  song.id
                                              ? Theme.of(context)
                                                  .primaryColor
                                                  .withOpacity(0.7)
                                              : Colors.grey.shade400,
                                          fontSize: 12),
                                    ),
                                    trailing: _isSelectionMode
                                        ? CustomIcons.svgIcon(
                                            isSelected
                                                ? CustomIcons.checkCircle
                                                : CustomIcons.circleOutlined,
                                            color: isSelected
                                                ? Theme.of(context).primaryColor
                                                : Colors.grey,
                                            size: 24)
                                        : IconButton(
                                            icon: const Icon(
                                                Icons.more_horiz_rounded,
                                                color: Colors.white70),
                                            onPressed: () {
                                              SongCard.showModernMenu(
                                                context,
                                                song,
                                                onDeleteTap: () =>
                                                    _showDeleteConfirmationDialog(
                                                        context, song),
                                                deleteText: langProvider
                                                    .t('delete_from_device'),
                                                onTap: () {
                                                  if (songProvider
                                                          .currentSong?.id !=
                                                      song.id) {
                                                    songProvider.playSong(
                                                        song, rawSongs);
                                                  } else {
                                                    if (songProvider
                                                        .audioPlayer.playing) {
                                                      songProvider.audioPlayer
                                                          .pause();
                                                    } else {
                                                      songProvider.audioPlayer
                                                          .play();
                                                    }
                                                  }
                                                },
                                              );
                                            },
                                          ),
                                    onTap: () {
                                      if (_isSelectionMode) {
                                        _toggleSelection(song);
                                      } else {
                                        if (songProvider.currentSong?.id !=
                                            song.id) {
                                          songProvider.playSong(song, rawSongs);
                                        } else {
                                          if (songProvider
                                              .audioPlayer.playing) {
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
                                  ),
                                );
                              }

                              return SongCard(
                                song: displaySong,
                                isSelected: isSelected,
                                showBorder: _isSelectionMode,
                                showOptions: !_isSelectionMode,
                                showDownloadButton: true,
                                isPlaying:
                                    songProvider.currentSong?.id == song.id,
                                onDeleteTap: () =>
                                    _showDeleteConfirmationDialog(
                                        context, song),
                                deleteText:
                                    langProvider.t('delete_from_device'),
                                trailing: _isSelectionMode
                                    ? CustomIcons.svgIcon(
                                        isSelected
                                            ? CustomIcons.checkCircle
                                            : CustomIcons.circleOutlined,
                                        color: isSelected
                                            ? Theme.of(context).primaryColor
                                            : Colors.grey,
                                        size: 24)
                                    : null,
                                onTap: () {
                                  if (_isSelectionMode) {
                                    _toggleSelection(song);
                                  } else {
                                    if (songProvider.currentSong?.id !=
                                        song.id) {
                                      songProvider.playSong(song, rawSongs);
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
                            }, childCount: filteredSongs.length),
                          ),
                        ),
                    ],
                  ),
                  if (!_isSelectionMode && filteredSongs.isNotEmpty)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      top: _showStickyPlayButton
                          ? MediaQuery.of(context).padding.top +
                              kToolbarHeight -
                              24
                          : MediaQuery.of(context).padding.top +
                              kToolbarHeight +
                              30,
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
                                        stream: songProvider
                                            .audioPlayer.playingStream,
                                        builder: (context, snapshot) {
                                          final playing =
                                              snapshot.data ?? false;
                                          final isPlayingNow =
                                              isAnyLoaded && playing;
                                          return AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
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
      ),
    );
  }
}
