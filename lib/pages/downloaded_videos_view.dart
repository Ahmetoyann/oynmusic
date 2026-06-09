import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/providers/language_provider.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/pages/video_player_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:text_scroll/text_scroll.dart';

class DownloadedVideosView extends StatelessWidget {
  final bool isGridMode;
  const DownloadedVideosView({super.key, this.isGridMode = true});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SongProvider>();
    final videos = provider.downloadedVideos;

    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.videocam_off_rounded,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Video Bulunamadı',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'İndirdiğiniz MP4 formatındaki videolar burada listelenir.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final padding = EdgeInsets.only(
      top: 16,
      bottom: provider.currentSong != null ? 160 : 100,
      left: MediaQuery.of(context).size.width * 0.025,
      right: MediaQuery.of(context).size.width * 0.025,
    );

    if (isGridMode) {
      return GridView.builder(
        padding: padding,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.95,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final file = videos[index];
          final fileName = file.path.split('/').last.replaceAll('.mp4', '');

          // Dosya isminden Şarkı Adı ve Sanatçıyı ayrıştırıyoruz
          final parts = fileName.split(' - ');
          final title = parts.isNotEmpty ? parts[0].trim() : fileName;
          final artist = parts.length > 1
              ? parts.sublist(1).join(' - ').trim()
              : 'Bilinmeyen Sanatçı';

          final imagePath =
              file.path.substring(0, file.path.length - 4) + '.jpg';
          final imageFile = File(imagePath);

          return GestureDetector(
            onLongPress: () =>
                _showVideoOptions(context, file, title, artist, provider),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      VideoPlayerPage(videoFile: file, title: title),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        imageFile.existsSync()
                            ? Image.file(
                                imageFile,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  color: Colors.grey.shade900,
                                  child: const Icon(Icons.videocam_rounded,
                                      color: Colors.white54, size: 32),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.grey.shade800,
                                      Colors.grey.shade900
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.videocam_rounded,
                                    color: Colors.white54,
                                    size: 32,
                                  ),
                                ),
                              ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: GestureDetector(
                            onTap: () => _showVideoOptions(
                                context, file, title, artist, provider),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.more_horiz_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return ListView.builder(
      padding: padding,
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final file = videos[index];
        final fileName = file.path.split('/').last.replaceAll('.mp4', '');

        // Dosya isminden Şarkı Adı ve Sanatçıyı ayrıştırıyoruz
        final parts = fileName.split(' - ');
        final title = parts.isNotEmpty ? parts[0].trim() : fileName;
        final artist = parts.length > 1
            ? parts.sublist(1).join(' - ').trim()
            : 'Bilinmeyen Sanatçı';

        final imagePath = file.path.substring(0, file.path.length - 4) + '.jpg';
        final imageFile = File(imagePath);

        return Card(
          color: Colors.transparent,
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            onLongPress: () =>
                _showVideoOptions(context, file, title, artist, provider),
            leading: SizedBox(
              width: 85, // 16:9 Formatı
              height: 48,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: imageFile.existsSync()
                    ? Image.file(
                        imageFile,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade900,
                          child: const Icon(Icons.videocam_rounded,
                              color: Colors.white54, size: 24),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.grey.shade800,
                              Colors.grey.shade900
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.videocam_rounded,
                            color: Colors.white54,
                            size: 24,
                          ),
                        ),
                      ),
              ),
            ),
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: Colors.white,
              ),
              onPressed: () =>
                  _showVideoOptions(context, file, title, artist, provider),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      VideoPlayerPage(videoFile: file, title: title),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showVideoOptions(BuildContext context, File file, String title,
      String artist, SongProvider provider) {
    final langProvider = context.read<LanguageProvider>();
    final primaryColor = Theme.of(context).primaryColor;
    final imagePath = file.path.substring(0, file.path.length - 4) + '.jpg';
    final imageFile = File(imagePath);

    // Menü açılırken cihaza modern bir titreşim (Haptic Feedback) gönderir
    HapticFeedback.mediumImpact();

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (pageContext, animation, secondaryAnimation) {
          Widget buildOption({
            required Widget iconWidget,
            required String text,
            required VoidCallback onMenuTap,
            Color textColor = Colors.white,
          }) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onMenuTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
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
                              fontSize: 15,
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
                  const SizedBox(height: 8),
                  // Video Kapak Resmi (16:9 Formatında)
                  Container(
                    width: 240,
                    height: 135,
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
                      child: imageFile.existsSync()
                          ? Image.file(
                              imageFile,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey.shade800,
                              child: const Icon(
                                Icons.videocam_rounded,
                                size: 40,
                                color: Colors.white54,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Video İsmi ve Sanatçı
                  SizedBox(
                    width: 300,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          TextScroll(
                            title,
                            mode: TextScrollMode.bouncing,
                            velocity:
                                const Velocity(pixelsPerSecond: Offset(30, 0)),
                            delayBefore: const Duration(seconds: 2),
                            pauseBetween: const Duration(seconds: 2),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            artist,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Menü Butonları
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            buildOption(
                              iconWidget: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              text: langProvider.t('play'),
                              onMenuTap: () {
                                Navigator.pop(pageContext);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VideoPlayerPage(
                                        videoFile: file, title: title),
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
                                Navigator.pop(pageContext);
                                // Hem videoyu hem de resmi paylaşım dosyalarına ekliyoruz
                                List<XFile> shareFiles = [XFile(file.path)];
                                if (imageFile.existsSync()) {
                                  shareFiles.add(XFile(imageFile.path));
                                }
                                Share.shareXFiles(
                                  shareFiles,
                                  text:
                                      'OYN Müzik\'te bu videoyu izle: $title - $artist\n\nUygulamayı indir: https://play.google.com/store/apps/details?id=com.ahmed.oyn_music',
                                );
                              },
                            ),
                            buildOption(
                              iconWidget: const Icon(
                                Icons.save_alt_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              text: langProvider.currentLanguage == 'tr'
                                  ? 'Galeriye Kaydet'
                                  : 'Save to Gallery',
                              onMenuTap: () async {
                                Navigator.pop(pageContext);
                                try {
                                  if (Platform.isAndroid) {
                                    final directory = Directory(
                                        '/storage/emulated/0/Movies/OYN_Music');
                                    if (!await directory.exists()) {
                                      await directory.create(recursive: true);
                                    }
                                    final newPath =
                                        '${directory.path}/${file.path.split('/').last}';
                                    await file.copy(newPath);
                                    CustomSnackBar.showSuccess(
                                      context: context,
                                      message: langProvider.currentLanguage ==
                                              'tr'
                                          ? 'Video galeriye (Movies/OYN_Music) kaydedildi.'
                                          : 'Video saved to gallery (Movies/OYN_Music).',
                                    );
                                  } else {
                                    CustomSnackBar.showError(
                                      context: context,
                                      message: langProvider.currentLanguage ==
                                              'tr'
                                          ? "Sadece Android cihazlarda destekleniyor."
                                          : "Only supported on Android.",
                                    );
                                  }
                                } catch (e) {
                                  CustomSnackBar.showError(
                                    context: context,
                                    message:
                                        "${langProvider.currentLanguage == 'tr' ? 'Hata' : 'Error'}: $e",
                                  );
                                }
                              },
                            ),
                            buildOption(
                              iconWidget: CustomIcons.svgIcon(
                                CustomIcons.delete,
                                color: Colors.redAccent,
                                size: 22,
                              ),
                              text: langProvider.t('delete'),
                              textColor: Colors.redAccent,
                              onMenuTap: () {
                                Navigator.pop(pageContext);
                                CustomBottomSheet.show(
                                  context: context,
                                  title: "Videoyu Sil",
                                  message:
                                      "Bu videoyu cihazınızdan silmek istediğinize emin misiniz?",
                                  primaryButtonText: "Sil",
                                  primaryButtonColor: Colors.redAccent,
                                  secondaryButtonText: "İptal",
                                  onPrimaryButtonTap: () {
                                    provider.deleteDownloadedVideo(file);
                                    Navigator.pop(context);
                                    CustomSnackBar.showError(
                                      context: context,
                                      message: "Video silindi.",
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }
}
