import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/models/song_model.dart';

class CustomSnackBar {
  /// Genel kullanım için temel SnackBar gösterimi
  static void show({
    required BuildContext context,
    required String message,
    Color? backgroundColor,
    Widget? icon,
    Duration duration = const Duration(seconds: 2),
  }) {
    // Varsa önceki SnackBar'ı gizle, böylece üst üste binmezler
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final accentColor = backgroundColor ?? Theme.of(context).primaryColor;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: duration,
        content: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: accentColor.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: icon,
                      ),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Başarılı işlemler için yeşil SnackBar
  /// Örnek: CustomSnackBar.showSuccess(context: context, message: "İndirme tamamlandı");
  static void showSuccess({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      context: context,
      message: message,
      backgroundColor: Colors.greenAccent,
      icon: CustomIcons.svgIcon(
        CustomIcons.check,
        color: Colors.greenAccent,
        size: 20,
      ),
      duration: duration,
    );
  }

  /// Hata durumları için kırmızı SnackBar
  /// Örnek: CustomSnackBar.showError(context: context, message: "Bir hata oluştu");
  static void showError({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      context: context,
      message: message,
      backgroundColor: Colors.redAccent,
      icon: CustomIcons.svgIcon(
        CustomIcons.warningAmberRounded,
        color: Colors.redAccent,
        size: 20,
      ),
      duration: duration,
    );
  }

  /// Bilgilendirme için gri/varsayılan SnackBar
  static void showInfo({
    required BuildContext context,
    required String message,
    Widget? icon,
    Duration duration = const Duration(seconds: 2),
  }) {
    final primaryColor = Theme.of(context).primaryColor;

    show(
      context: context,
      message: message,
      backgroundColor: primaryColor,
      icon:
          icon ??
          CustomIcons.svgIcon(
            CustomIcons.musicNoteRounded,
            color: primaryColor,
            size: 20,
          ),
      duration: duration,
    );
  }

  /// İndirme ilerlemesini gösteren özel SnackBar (Buzlu cam ve dinamik renk efektli)
  static void showDownloadProgress({
    required BuildContext context,
    required Song song,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(days: 1), // Manuel olarak kapatılacak
        content: Consumer<SongProvider>(
          builder: (context, provider, child) {
            final progress = provider.downloadProgress[song.id] ?? 0.0;
            final isCanceling = provider.isCanceling(song.id);
            final isPaused = provider.isPaused(song.id);
            final details = provider.downloadDetails[song.id];
            final percentage = (progress * 100).toInt();
            final primaryColor = Theme.of(context).primaryColor;

            return Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.2),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: primaryColor.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 1. Kapak Resmi
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child:
                              (song.localImagePath != null &&
                                  File(song.localImagePath!).existsSync())
                              ? Image.file(
                                  File(song.localImagePath!),
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  song.coverUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                    width: 48,
                                    height: 48,
                                    color: Colors.grey.shade800,
                                    child: const Icon(
                                      Icons.music_note,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 14),

                        // 2. Metinler
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isCanceling
                                    ? 'İPTAL EDİLİYOR...'
                                    : isPaused
                                    ? 'DURAKLATILDI'
                                    : 'İNDİRİLİYOR...',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                song.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (details != null && !isCanceling) ...[
                                const SizedBox(height: 2),
                                Text(
                                  "%$percentage • $details",
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // 3. Aksiyon Butonları
                        if (!isCanceling) ...[
                          GestureDetector(
                            onTap: () {
                              if (isPaused) {
                                provider.downloadSong(song);
                              } else {
                                provider.pauseDownload(song);
                              }
                            },
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 38,
                                  height: 38,
                                  child: CircularProgressIndicator(
                                    value: progress == 0.0 ? null : progress,
                                    backgroundColor: Colors.white.withOpacity(
                                      0.1,
                                    ),
                                    color: primaryColor,
                                    strokeWidth: 3,
                                  ),
                                ),
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isPaused
                                        ? Icons.play_arrow_rounded
                                        : Icons.pause_rounded,
                                    color: primaryColor,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => provider.cancelDownload(song.id),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white70,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
