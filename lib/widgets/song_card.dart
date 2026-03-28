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

class SongCard extends StatelessWidget {
  final Song song;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final bool isSelected;
  final bool isPlaying;
  final bool showBorder;
  final bool showOptions;

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
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        onTap: onTap,
        onLongPress: onLongPress,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: _buildImage(),
        ),
        title: Tooltip(
          message: song.title,
          child: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isPlaying ? theme.primaryColor : Colors.white,
              fontSize: 12,
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
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: showOptions ? _buildTrailingActions(context) : trailing,
      ),
    );
  }

  Widget _buildImage() {
    const double size = 40;

    if (song.localImagePath != null &&
        File(song.localImagePath!).existsSync()) {
      return Image.file(
        File(song.localImagePath!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => _buildPlaceholder(size),
      );
    }

    return Image.network(
      song.coverUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (c, e, s) => _buildPlaceholder(size),
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
            final progress = provider.downloadProgress[song.id];
            final isPaused = provider.isPaused(song.id);

            Widget downloadIcon;
            if (progress != null) {
              downloadIcon = SizedBox(
                width: 20,
                height: 20,
                child: isPaused
                    ? Icon(
                        Icons.pause,
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      )
                    : CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 2.0,
                        color: Theme.of(context).primaryColor,
                      ),
              );
            } else if (isDownloaded) {
              downloadIcon = CustomIcons.svgIcon(
                CustomIcons.checkCircle,
                color: Theme.of(context).primaryColor,
                size: 22,
              );
            } else {
              downloadIcon = Icon(
                Icons.downloading,
                color: Colors.grey.shade400,
                size: 22,
              );
            }

            return GestureDetector(
              onTap: () {
                if (progress != null) {
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
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: downloadIcon,
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        _buildOptionsButton(context),
      ],
    );
  }

  Widget _buildOptionsButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showOptionsBottomSheet(context),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: CustomIcons.svgIcon(
          CustomIcons.moreHoriz,
          size: 20,
          color: Colors.grey,
        ),
      ),
    );
  }

  void _showOptionsBottomSheet(BuildContext context) {
    CustomBottomSheet.showContent(
      context: context,
      child: Consumer<SongProvider>(
        builder: (innerContext, provider, child) {
          final isFavorite = provider.favoriteSongs.any((s) => s.id == song.id);
          final isDownloaded = provider.isSongDownloaded(song.id);
          final theme = Theme.of(innerContext);

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
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

                  // Şarkı Bilgisi (Gelişmiş Görünüm)
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            song.coverUrl,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              width: 64,
                              height: 64,
                              color: Colors.grey.shade800,
                              child: CustomIcons.svgIcon(
                                CustomIcons.musicNote,
                                color: Colors.white54,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
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
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                            ),
                            if (isDownloaded) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: theme.primaryColor.withOpacity(0.5),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  "İndirildi",
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 8),

                  // Seçenekler
                  _buildOptionTile(
                    innerContext,
                    iconStr: isFavorite
                        ? CustomIcons.favorite
                        : CustomIcons.favoriteBorder,
                    iconColor: isFavorite ? theme.primaryColor : Colors.white,
                    text: isFavorite ? 'Favorilerden Çıkar' : 'Favoriye Ekle',
                    onTap: () {
                      provider.toggleFavorite(song);
                      Navigator.pop(context);
                      CustomSnackBar.show(
                        context: context,
                        message: !isFavorite
                            ? 'Favorilere eklendi'
                            : 'Favorilerden çıkarıldı',
                        backgroundColor: !isFavorite
                            ? Colors.green.shade700
                            : Colors.redAccent,
                        icon: CustomIcons.svgIcon(
                          !isFavorite
                              ? CustomIcons.favorite
                              : CustomIcons.favoriteBorder,
                          color: Colors.white,
                          size: 24,
                        ),
                      );
                    },
                  ),
                  _buildOptionTile(
                    innerContext,
                    iconStr: CustomIcons.playlistAddRounded,
                    text: 'Çalma Listesine Ekle',
                    onTap: () {
                      Navigator.pop(context);
                      _showAddToPlaylistBottomSheet(context);
                    },
                  ),
                  _buildOptionTile(
                    innerContext,
                    iconStr: CustomIcons.person,
                    text: 'Sanatçıya Git',
                    onTap: () {
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
                  _buildOptionTile(
                    innerContext,
                    iconStr: CustomIcons.iosShareOutlined,
                    text: 'Paylaş',
                    onTap: () {
                      Navigator.pop(context);
                      Share.share(
                        'OYN Müzik\n\n🎵 ${song.title}\n👤 ${song.artist}\n\nDinlemek için uygulamamızı indirin: https://play.google.com/store/apps/details?id=com.ahmed.oyn_music',
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required String iconStr,
    Color? iconColor,
    required String text,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: CustomIcons.svgIcon(
          iconStr,
          color: iconColor ?? theme.primaryColor,
          size: 22,
        ),
      ),
      title: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: CustomIcons.svgIcon(
        CustomIcons.arrowForwardIosRounded,
        color: theme.primaryColor.withOpacity(0.3),
        size: 14,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _showAddToPlaylistBottomSheet(BuildContext context) {
    CustomBottomSheet.showContent(
      context: context,
      child: Consumer<SongProvider>(
        builder: (innerContext, provider, child) {
          final folders = provider.folders;
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
                              ? const Icon(
                                  Icons.downloading,
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

  void _showCreatePlaylistBottomSheet(BuildContext context, Song song) {
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

  void _showLoginBottomSheet(BuildContext context) {
    CustomBottomSheet.show(
      context: context,
      title: "İndirmek için Giriş Yapın",
      message:
          "Şarkıları cihazınıza indirmek ve çevrimdışı dinlemek için lütfen giriş yapın.",
      icon: const Icon(Icons.downloading, size: 60, color: Colors.white70),
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
}
