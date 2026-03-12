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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[icon, const SizedBox(width: 12)],
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
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
      backgroundColor: Colors.green.shade700,
      icon: CustomIcons.svgIcon(
        CustomIcons.check,
        color: Colors.white,
        size: 24,
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
      icon: const Icon(Icons.error_outline, color: Colors.white),
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
    show(
      context: context,
      message: message,
      backgroundColor: Colors.grey.shade800,
      icon: icon ?? const Icon(Icons.info_outline, color: Colors.white),
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
        duration: const Duration(days: 1), // Manuel olarak kapatılacak
        content: Consumer<SongProvider>(
          builder: (context, provider, child) {
            final progress = provider.downloadProgress[song.id] ?? 0.0;
            final isCanceling = provider.isCanceling(song.id);
            final details = provider.downloadDetails[song.id];
            final percentage = (progress * 100).toInt();

            // Renk geçişi için başlangıç ve bitiş renkleri
            final startColor = Colors.grey.shade800.withOpacity(0.8);
            final endColor = Theme.of(context).primaryColor.withOpacity(0.8);

            // İlerlemeye göre anlık rengi hesapla
            final currentColor = Color.lerp(startColor, endColor, progress);

            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: currentColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isCanceling
                                            ? 'İptal Ediliyor...'
                                            : 'İndiriliyor: ${song.title}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (progress > 0 && !isCanceling)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 8.0,
                                        ),
                                        child: Text(
                                          "%$percentage",
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (details != null && !isCanceling) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    details,
                                    style: TextStyle(
                                      color: Colors.grey.shade300,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (!isCanceling)
                            GestureDetector(
                              onTap: () => provider.cancelDownload(song.id),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: progress == 0.0 ? null : progress,
                        backgroundColor: Colors.black.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ],
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
