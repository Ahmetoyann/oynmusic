import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/pages/login_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:muzik_app/pages/artist_detail_page.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:muzik_app/providers/language_provider.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SongCard extends StatelessWidget {
  final Song song;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final bool isSelected;
  final bool isPlaying;
  final bool showBorder;
  final bool showOptions;
  final VoidCallback? onDeleteTap;
  final String? deleteText;

  const SongCard({
    super.key,
    required this.song,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.isSelected = false,
    this.isPlaying = false,
    this.showBorder = false,
    this.showOptions = false,
    this.onDeleteTap,
    this.deleteText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Performans dostu dinleme: Sadece favori durumu değiştiğinde kart yenilenir
    final isFavorite = context.select<SongProvider, bool>(
      (p) => p.favoriteSongs.any((s) => s.id == song.id),
    );

    return Card(
      color: isSelected
          ? theme.primaryColor.withOpacity(0.2)
          : Colors.transparent,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        // Köşeleri keskinleştir
        borderRadius: BorderRadius.circular(12),
        side: showBorder && isSelected
            ? BorderSide(color: theme.primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: onTap, // Artık karta tıklandığında direkt şarkı çalacak
        onLongPress:
            onLongPress ??
            () => showModernMenu(
              context,
              song,
              onTap: onTap,
              onDeleteTap: onDeleteTap,
              deleteText: deleteText,
            ),
        leading: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildImage(),
              ),
              if (isFavorite)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: Colors.greenAccent,
                      size: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
        title: Tooltip(
          message: song.title,
          child: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isPlaying ? theme.primaryColor : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        subtitle: Text(
          song.duration != null && song.duration! > 0
              ? "${song.artist} • ${song.formattedDuration}"
              : song.artist,
          style: TextStyle(
            color: isPlaying
                ? theme.primaryColor.withOpacity(0.7)
                : Colors.grey.shade400,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: showOptions
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTrailingActions(context),
                  if (trailing != null) trailing!,
                ],
              )
            : trailing,
      ),
    );
  }

  Widget _buildImage() {
    const double size = 48;

    if (song.localImagePath != null &&
        File(song.localImagePath!).existsSync()) {
      return Transform.scale(
        scale:
            (song.coverUrl.contains('ytimg.com') ||
                song.coverUrl.contains('youtube.com'))
            ? 1.35
            : 1.0,
        child: Image.file(
          File(song.localImagePath!),
          width: size,
          height: size,
          cacheHeight: 200,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => _buildPlaceholder(size),
        ),
      );
    }

    return Transform.scale(
      scale:
          (song.coverUrl.contains('ytimg.com') ||
              song.coverUrl.contains('youtube.com'))
          ? 1.35
          : 1.0,
      child: CachedNetworkImage(
        imageUrl: song.coverUrl,
        width: size,
        height: size,
        memCacheHeight: 200,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => _buildPlaceholder(size),
      ),
    );
  }

  Widget _buildPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade800, Colors.grey.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _buildTrailingActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Consumer<SongProvider>(
          builder: (context, provider, child) {
            final isDownloaded = provider.isSongDownloaded(song.id);
            final isPaused = provider.isPaused(song.id);

            return ValueListenableBuilder<double?>(
              valueListenable: provider.getDownloadProgressNotifier(song.id),
              builder: (context, progress, child) {
                final bool isDownloading = provider.downloadProgress
                    .containsKey(song.id);
                Widget downloadIcon;
                if (isDownloading) {
                  downloadIcon = SizedBox(
                    width: 24,
                    height: 24,
                    child: isPaused
                        ? Icon(
                            Icons.pause,
                            color: Theme.of(context).primaryColor,
                            size: 24,
                          )
                        : CircularProgressIndicator(
                            value: progress == 0.0 && !isPaused
                                ? null
                                : progress,
                            strokeWidth: 2.0,
                            color: Colors.white,
                          ),
                  );
                } else if (isDownloaded) {
                  downloadIcon = CustomIcons.svgIcon(
                    CustomIcons.checkCircle,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  );
                } else {
                  downloadIcon = CustomIcons.svgIcon(
                    CustomIcons.downloadingRounded,
                    color: Colors.white,
                    size: 24,
                  );
                }

                return GestureDetector(
                  onTap: () {
                    if (isDownloading) {
                      if (isPaused) {
                        provider.downloadSong(song);
                      } else {
                        provider.pauseDownload(song);
                      }
                    } else if (!isDownloaded) {
                      if (!provider.isFirebaseLoggedIn) {
                        _showLoginBottomSheet(context);
                      } else {
                        provider.downloadSong(song).catchError((e) {
                          if (context.mounted) {
                            CustomSnackBar.showError(
                              context: context,
                              message: "İndirme başarısız: $e",
                            );
                          }
                        });
                      }
                    }
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: downloadIcon,
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(width: 8),
        _buildMenuButton(context),
      ],
    );
  }

  Widget _buildMenuButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
      onPressed: () => showModernMenu(
        context,
        song,
        onTap: onTap,
        onDeleteTap: onDeleteTap,
        deleteText: deleteText,
      ),
    );
  }

  static void _showAddToPlaylistBottomSheet(BuildContext context, Song song) {
    CustomBottomSheet.showContent(
      context: context,
      child: Consumer<SongProvider>(
        builder: (innerContext, provider, child) {
          final folders = provider.folders;
          final theme = Theme.of(innerContext);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
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
                            _showCreatePlaylistBottomSheet(context, song);
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
                                const Text(
                                  'Yeni Liste Oluştur',
                                  style: TextStyle(
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
                          trailing: CustomIcons.svgIcon(
                            CustomIcons.arrowForwardIosRounded,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          onTap: () {
                            if (folder.songs.any((s) => s.id == song.id)) {
                              Navigator.pop(context);
                              CustomSnackBar.showInfo(
                                context: context,
                                message:
                                    'Bu şarkı zaten ${folder.name} listesinde var.',
                              );
                            } else {
                              provider.addSongsToFolder(folder, [song]);
                              Navigator.pop(context);
                              CustomSnackBar.showSuccess(
                                context: context,
                                message:
                                    'Şarkı ${folder.name} listesine eklendi.',
                              );
                            }
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

  static void _showCreatePlaylistBottomSheet(BuildContext context, Song song) {
    final TextEditingController controller = TextEditingController();
    String? selectedImagePath;

    CustomBottomSheet.showContent(
      context: context,
      isScrollControlled: true,
      child: StatefulBuilder(
        builder: (modalContext, setModalState) => Padding(
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
                                Icons.add_a_photo_outlined,
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
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: controller,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Liste Adı',
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
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
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
                                context.read<SongProvider>().createFolder(
                                  name: controller.text,
                                  songs: [song],
                                  customImagePath: selectedImagePath,
                                );
                                Navigator.pop(context);
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
                            borderRadius: BorderRadius.circular(16),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  'Oluştur',
                                  style: TextStyle(
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
      ),
    );
  }

  static void _showLoginBottomSheet(BuildContext context) {
    CustomBottomSheet.show(
      context: context,
      title: "İndirmek için Giriş Yapın",
      message:
          "Şarkıları cihazınıza indirmek ve çevrimdışı dinlemek için lütfen giriş yapın.",
      icon: CustomIcons.svgIcon(
        CustomIcons.downloadingRounded,
        size: 60,
        color: Colors.white70,
      ),
      primaryButtonText: "Giriş Yap",
      primaryButtonColor: Colors.white,
      primaryButtonTextColor: Colors.black,
      secondaryButtonText: "İptal",
      onPrimaryButtonTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      },
    );
  }

  /// Ekranda ortalanmış şekilde açılan modern animasyonlu Seçenekler menüsü
  static void showModernMenu(
    BuildContext context,
    Song song, {
    VoidCallback? onTap,
    VoidCallback? onDeleteTap,
    String? deleteText,
  }) {
    // Menü açılırken cihaza modern bir titreşim (Haptic Feedback) gönderir
    HapticFeedback.mediumImpact();

    final provider = context.read<SongProvider>();
    final langProvider = context.read<LanguageProvider>();
    final primaryColor = Theme.of(context).primaryColor;

    CustomBottomSheet.showContent(
      context: context,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Şarkı Kapak Resmi (Boyutu küçültüldü)
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Transform.scale(
                  scale:
                      (song.coverUrl.contains('ytimg.com') ||
                          song.coverUrl.contains('youtube.com'))
                      ? 1.35
                      : 1.0,
                  child:
                      (song.localImagePath != null &&
                          File(song.localImagePath!).existsSync())
                      ? Image.file(
                          File(song.localImagePath!),
                          fit: BoxFit.cover,
                          cacheHeight: 400,
                        )
                      : CachedNetworkImage(
                          imageUrl: song.coverUrl,
                          fit: BoxFit.cover,
                          memCacheHeight: 400,
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade800,
                            child: const Icon(
                              Icons.music_note,
                              size: 40,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Şarkı İsmi ve Sanatçı
            SizedBox(
              width:
                  280, // Kayan yazının sınırlarını belirlemek için genişlik verildi
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    TextScroll(
                      song.title,
                      mode: TextScrollMode.bouncing,
                      velocity: const Velocity(pixelsPerSecond: Offset(30, 0)),
                      delayBefore: const Duration(seconds: 2),
                      pauseBetween: const Duration(seconds: 2),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Menü Butonları (Tüm Seçenekler ile Kompakt Tasarım)
            Flexible(
              child: Consumer<SongProvider>(
                builder: (consumerContext, currentProvider, child) {
                  final isFavorite = currentProvider.favoriteSongs.any(
                    (s) => s.id == song.id,
                  );
                  final isFollowed = currentProvider.isArtistFollowed(
                    song.artist,
                  );
                  final isDownloaded = currentProvider.isSongDownloaded(
                    song.id,
                  );
                  final progress = currentProvider.downloadProgress[song.id];
                  final isPaused = currentProvider.isPaused(song.id);

                  Widget buildOption({
                    required Widget iconWidget,
                    required String text,
                    required VoidCallback onMenuTap,
                    Color textColor = Colors.white,
                  }) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onMenuTap,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(
                                0.06,
                              ), // Butonların özel cam efekti arkaplanı
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                iconWidget,
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    text,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12.0, // Alt-üst estetik boşluk
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (onTap != null)
                            buildOption(
                              iconWidget: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              text: langProvider.t('play_song'),
                              onMenuTap: () {
                                Navigator.pop(context);
                                onTap();
                              },
                            ),
                          buildOption(
                            iconWidget: isDownloaded
                                ? const Icon(
                                    Icons.download_done_rounded,
                                    color: Colors.greenAccent,
                                    size: 22,
                                  )
                                : (progress != null
                                      ? (isPaused
                                            ? Icon(
                                                Icons.play_arrow_rounded,
                                                color: primaryColor,
                                                size: 22,
                                              )
                                            : SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                      value: progress.clamp(
                                                        0.0,
                                                        1.0,
                                                      ),
                                                      strokeWidth: 2.0,
                                                      color: primaryColor,
                                                    ),
                                              ))
                                      : const Icon(
                                          Icons.cloud_download_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        )),
                            text: isDownloaded
                                ? (langProvider.currentLanguage == 'tr'
                                      ? 'İndirildi'
                                      : 'Downloaded')
                                : (progress != null
                                      ? (isPaused
                                            ? (langProvider.currentLanguage ==
                                                      'tr'
                                                  ? 'Devam Et'
                                                  : 'Resume')
                                            : (langProvider.currentLanguage ==
                                                      'tr'
                                                  ? 'İndiriliyor...'
                                                  : 'Downloading...'))
                                      : langProvider.t('download')),
                            textColor: isDownloaded
                                ? Colors.greenAccent
                                : (progress != null
                                      ? primaryColor
                                      : Colors.white),
                            onMenuTap: () {
                              if (isDownloaded) {
                                Navigator.pop(context);
                                CustomSnackBar.showInfo(
                                  context: context,
                                  message: langProvider.t('already_downloaded'),
                                );
                              } else if (progress != null) {
                                if (isPaused) {
                                  currentProvider.downloadSong(song);
                                } else {
                                  currentProvider.pauseDownload(song);
                                }
                              } else {
                                Navigator.pop(context);
                                if (!currentProvider.isFirebaseLoggedIn) {
                                  _showLoginBottomSheet(context);
                                } else {
                                  currentProvider.downloadSong(song).catchError((
                                    e,
                                  ) {
                                    if (context.mounted) {
                                      CustomSnackBar.showError(
                                        context: context,
                                        message:
                                            "${langProvider.t('download_failed')} $e",
                                      );
                                    }
                                  });
                                }
                              }
                            },
                          ),
                          buildOption(
                            iconWidget: Icon(
                              isFavorite
                                  ? Icons.check_circle_rounded
                                  : Icons.add_circle_outline_rounded,
                              color: isFavorite
                                  ? Colors.greenAccent
                                  : Colors.white,
                              size: 22,
                            ),
                            text: isFavorite
                                ? (langProvider.currentLanguage == 'tr'
                                      ? 'Favorilerden Çıkar'
                                      : 'Remove Favorite')
                                : (langProvider.currentLanguage == 'tr'
                                      ? 'Favorilere Ekle'
                                      : 'Add to Favorites'),
                            textColor: isFavorite
                                ? Colors.greenAccent
                                : Colors.white,
                            onMenuTap: () {
                              currentProvider.toggleFavorite(song);
                              Navigator.pop(context);
                              CustomSnackBar.show(
                                context: context,
                                message: !isFavorite
                                    ? langProvider.t('added_to_favorites')
                                    : langProvider.t('removed_from_favorites'),
                                backgroundColor: !isFavorite
                                    ? Colors.green.shade700
                                    : Colors.redAccent,
                                icon: Icon(
                                  !isFavorite
                                      ? Icons.check_circle_rounded
                                      : Icons.remove_circle_outline_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              );
                            },
                          ),
                          buildOption(
                            iconWidget: Icon(
                              isFollowed
                                  ? Icons.check_rounded
                                  : Icons.person_add_alt_1_rounded,
                              color: isFollowed ? primaryColor : Colors.white,
                              size: 22,
                            ),
                            text: isFollowed
                                ? (langProvider.currentLanguage == 'tr'
                                      ? 'Takip Ediliyor'
                                      : 'Following')
                                : (langProvider.currentLanguage == 'tr'
                                      ? 'Sanatçıyı Takip Et'
                                      : 'Follow Artist'),
                            textColor: isFollowed ? primaryColor : Colors.white,
                            onMenuTap: () {
                              if (!currentProvider.isFirebaseLoggedIn) {
                                Navigator.pop(context);
                                _showLoginBottomSheet(context);
                                return;
                              }
                              currentProvider.toggleFollowArtist(song.artist);
                              Navigator.pop(context);
                              CustomSnackBar.showInfo(
                                context: context,
                                message: !isFollowed
                                    ? (langProvider.currentLanguage == 'tr'
                                          ? '${song.artist} takip ediliyor'
                                          : 'Following ${song.artist}')
                                    : (langProvider.currentLanguage == 'tr'
                                          ? '${song.artist} takipten çıkarıldı'
                                          : 'Unfollowed ${song.artist}'),
                              );
                            },
                          ),
                          buildOption(
                            iconWidget: CustomIcons.svgIcon(
                              CustomIcons.playlistPlay,
                              color: Colors.white,
                              size: 22,
                            ),
                            text: langProvider.t('play_next'),
                            onMenuTap: () {
                              Navigator.pop(context);
                              currentProvider.addSongToNext(song);
                            },
                          ),
                          buildOption(
                            iconWidget: Icon(
                              Icons.playlist_add,
                              color: Colors.white,
                              size: 22,
                            ),
                            text: langProvider.t('add_to_playlist'),
                            onMenuTap: () {
                              Navigator.pop(context);
                              _showAddToPlaylistBottomSheet(context, song);
                            },
                          ),
                          buildOption(
                            iconWidget: CustomIcons.svgIcon(
                              CustomIcons.person,
                              color: Colors.white,
                              size: 22,
                            ),
                            text: langProvider.t('go_to_artist'),
                            onMenuTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ArtistDetailPage(
                                    artistName: song.artist,
                                    songs: const [],
                                  ),
                                ),
                              );
                            },
                          ),
                          buildOption(
                            iconWidget: CustomIcons.svgIcon(
                              CustomIcons.iosShareOutlined,
                              color: Colors.white,
                              size: 22,
                            ),
                            text: langProvider.t('share'),
                            onMenuTap: () {
                              Navigator.pop(context);
                              Share.share(
                                'OYN Müzik\n\n🎵 ${song.title}\n👤 ${song.artist}\n\nDinlemek için uygulamamızı indirin: https://play.google.com/store/apps/details?id=com.ahmed.oyn_music',
                              );
                            },
                          ),
                          if (onDeleteTap != null)
                            buildOption(
                              iconWidget: CustomIcons.svgIcon(
                                CustomIcons.delete,
                                color: Colors.redAccent,
                                size: 22,
                              ),
                              text: deleteText ?? langProvider.t('cancel'),
                              textColor: Colors.redAccent,
                              onMenuTap: () {
                                Navigator.pop(context);
                                onDeleteTap();
                              },
                            ),
                        ],
                      ),
                    ),
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
