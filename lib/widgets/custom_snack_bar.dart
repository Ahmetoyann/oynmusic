import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/providers/language_provider.dart';
import 'package:muzik_app/main.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CustomSnackBar {
  static OverlayEntry? _currentOverlay;

  static void hideCurrent() {
    if (_currentOverlay?.mounted == true) {
      _currentOverlay?.remove();
    }
    _currentOverlay = null;
  }

  /// Genel kullanım için temel Toast (Overlay) gösterimi
  static void show({
    required BuildContext context,
    required String message,
    Color? backgroundColor,
    Widget? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    hideCurrent();

    final overlay =
        Overlay.maybeOf(context) ?? navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    final accentColor = backgroundColor ?? Theme.of(context).primaryColor;

    _currentOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 20,
        left: 20,
        right: 20,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, -30 * (1 - value)),
              child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
            );
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: accentColor.withOpacity(0.5),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (icon != null) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.25),
                              shape: BoxShape.circle,
                            ),
                            child: icon,
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
        ),
      ),
    );

    overlay.insert(_currentOverlay!);

    if (duration.inDays < 1) {
      final entry = _currentOverlay;
      Future.delayed(duration, () {
        if (_currentOverlay == entry && entry?.mounted == true) {
          hideCurrent();
        }
      });
    }
  }

  /// Başarılı işlemler için yeşil Toast
  static void showSuccess({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context: context,
      message: message,
      backgroundColor: Colors.green.shade500, // Gölge için daha canlı yeşil
      icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
      duration: duration,
    );
  }

  /// Hata durumları için kırmızı Toast
  static void showError({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context: context,
      message: message,
      backgroundColor: Colors.redAccent,
      icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
      duration: duration,
    );
  }

  /// Bilgilendirme için varsayılan (primaryColor) Toast
  static void showInfo({
    required BuildContext context,
    required String message,
    Widget? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    show(
      context: context,
      message: message,
      backgroundColor: primaryColor,
      icon: icon ?? const Icon(Icons.info_outline_rounded, color: Colors.white),
      duration: duration,
    );
  }

  /// İndirme ilerlemesini gösteren özel Top Toast (Overlay)
  static void showDownloadProgress({
    required BuildContext context,
    required Song song,
  }) {
    hideCurrent();

    final overlay =
        Overlay.maybeOf(context) ?? navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    bool isMinimized = false; // Küçültülme durumu
    bool isClosing = false; // Kapanma zamanlayıcısı başladı mı

    _currentOverlay = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: MediaQuery.of(context).padding.top + 20,
          left: 20,
          right: 20,
          child: StatefulBuilder(
            builder: (context, setState) {
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, -30 * (1 - value)),
                    child: Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: Align(
                  alignment: Alignment.topRight, // Sağ üstte küçülecek
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragEnd: (details) {
                      // Sağa veya sola yeterli hızda kaydırılırsa küçült
                      if (details.primaryVelocity != null &&
                          details.primaryVelocity!.abs() > 100) {
                        if (!isMinimized) setState(() => isMinimized = true);
                      }
                    },
                    onTap: () {
                      // Üzerine tıklanınca geri büyüt
                      if (isMinimized) setState(() => isMinimized = false);
                    },
                    child: Material(
                      color: Colors.transparent,
                      child: Consumer<SongProvider>(
                        builder: (context, provider, child) {
                          final isDownloaded = provider.isSongDownloaded(
                            song.id,
                          );
                          if (isDownloaded && !isClosing) {
                            isClosing = true;
                            Future.delayed(const Duration(seconds: 2), () {
                              hideCurrent();
                            });
                          }

                          final isCanceling = provider.isCanceling(song.id);
                          final isPaused = provider.isPaused(song.id);
                          final primaryColor = Theme.of(context).primaryColor;
                          final langProvider = context
                              .watch<LanguageProvider>();

                          return ValueListenableBuilder<double?>(
                            valueListenable: provider
                                .getDownloadProgressNotifier(song.id),
                            builder: (context, progressValue, child) {
                              return ValueListenableBuilder<String>(
                                valueListenable: provider
                                    .getDownloadDetailsNotifier(song.id),
                                builder: (context, detailsValue, child) {
                                  final progress =
                                      progressValue ??
                                      (isDownloaded ? 1.0 : 0.0);
                                  final percentage = (progress * 100).toInt();
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    // Küçültüldüğünde tam yuvarlak, genişlediğinde ekranın tamamı eksi kenar payları
                                    width: isMinimized
                                        ? 68
                                        : MediaQuery.of(context).size.width -
                                              40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        isMinimized ? 34 : 16,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isDownloaded
                                              ? Colors.greenAccent.withOpacity(
                                                  0.2,
                                                )
                                              : primaryColor.withOpacity(0.2),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        isMinimized ? 34 : 16,
                                      ),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: 20,
                                          sigmaY: 20,
                                        ),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          padding: EdgeInsets
                                              .zero, // Padding'i içeri taşıyoruz ki tıklamalar bozulmasın
                                          decoration: BoxDecoration(
                                            color: isDownloaded
                                                ? Colors.greenAccent
                                                      .withOpacity(0.15)
                                                : primaryColor.withOpacity(
                                                    0.15,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              isMinimized ? 34 : 16,
                                            ),
                                            border: Border.all(
                                              color: isDownloaded
                                                  ? Colors.greenAccent
                                                        .withOpacity(0.5)
                                                  : primaryColor.withOpacity(
                                                      0.5,
                                                    ),
                                              width: 1.2,
                                            ),
                                          ),
                                          // İçeriğin değişmesini güzel bir solma animasyonu ile yapar
                                          child: AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            child: isMinimized
                                                ? Padding(
                                                    key: const ValueKey(
                                                      'minimized',
                                                    ),
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    child: SizedBox(
                                                      width: 56,
                                                      height: 56,
                                                      child: Stack(
                                                        alignment:
                                                            Alignment.center,
                                                        children: [
                                                          ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  28,
                                                                ),
                                                            child: SizedBox(
                                                              width: 56,
                                                              height: 56,
                                                              child: Stack(
                                                                children: [
                                                                  Positioned.fill(
                                                                    child: Transform.scale(
                                                                      scale:
                                                                          (song.coverUrl.contains(
                                                                                'ytimg.com',
                                                                              ) ||
                                                                              song.coverUrl.contains(
                                                                                'youtube.com',
                                                                              ))
                                                                          ? 1.35
                                                                          : 1.0,
                                                                      child:
                                                                          (song.localImagePath !=
                                                                                  null &&
                                                                              File(
                                                                                song.localImagePath!,
                                                                              ).existsSync())
                                                                          ? Image.file(
                                                                              File(
                                                                                song.localImagePath!,
                                                                              ),
                                                                              fit: BoxFit.cover,
                                                                              cacheHeight: 200,
                                                                            )
                                                                          : CachedNetworkImage(
                                                                              imageUrl: song.coverUrl,
                                                                              fit: BoxFit.cover,
                                                                              memCacheHeight: 200,
                                                                              errorWidget:
                                                                                  (
                                                                                    context,
                                                                                    url,
                                                                                    error,
                                                                                  ) => Container(
                                                                                    color: Colors.grey.shade800,
                                                                                    child: const Icon(
                                                                                      Icons.music_note,
                                                                                      color: Colors.white54,
                                                                                    ),
                                                                                  ),
                                                                            ),
                                                                    ),
                                                                  ),
                                                                  if (isDownloaded)
                                                                    Positioned.fill(
                                                                      child: TweenAnimationBuilder<double>(
                                                                        tween: Tween(
                                                                          begin:
                                                                              0.0,
                                                                          end:
                                                                              1.0,
                                                                        ),
                                                                        duration: const Duration(
                                                                          milliseconds:
                                                                              500,
                                                                        ),
                                                                        curve: Curves
                                                                            .elasticOut,
                                                                        builder:
                                                                            (
                                                                              context,
                                                                              val,
                                                                              child,
                                                                            ) {
                                                                              return Transform.scale(
                                                                                scale: val,
                                                                                child: Container(
                                                                                  color: Colors.black.withOpacity(
                                                                                    0.4,
                                                                                  ),
                                                                                  child: const Icon(
                                                                                    Icons.check_circle_rounded,
                                                                                    color: Colors.greenAccent,
                                                                                    size: 28,
                                                                                  ),
                                                                                ),
                                                                              );
                                                                            },
                                                                      ),
                                                                    ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          if (isPaused &&
                                                              !isDownloaded)
                                                            Container(
                                                              width: 48,
                                                              height: 48,
                                                              decoration: BoxDecoration(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                      0.4,
                                                                    ),
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                              child: Icon(
                                                                Icons
                                                                    .pause_rounded,
                                                                color:
                                                                    primaryColor,
                                                                size: 24,
                                                              ),
                                                            ),
                                                          if (!isDownloaded)
                                                            SizedBox(
                                                              width: 56,
                                                              height: 56,
                                                              child: CircularProgressIndicator(
                                                                value:
                                                                    (progress ==
                                                                            0.0 &&
                                                                        !isPaused)
                                                                    ? null
                                                                    : progress,
                                                                color:
                                                                    primaryColor,
                                                                strokeWidth: 3,
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                : Stack(
                                                    key: const ValueKey(
                                                      'expanded',
                                                    ),
                                                    clipBehavior: Clip.none,
                                                    children: [
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 14,
                                                              vertical: 18,
                                                            ),
                                                        child: SingleChildScrollView(
                                                          scrollDirection:
                                                              Axis.horizontal,
                                                          physics:
                                                              const NeverScrollableScrollPhysics(),
                                                          reverse: true,
                                                          child: SizedBox(
                                                            width:
                                                                MediaQuery.of(
                                                                  context,
                                                                ).size.width -
                                                                68,
                                                            child: Row(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .center,
                                                              children: [
                                                                ClipRRect(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        10,
                                                                      ),
                                                                  child: SizedBox(
                                                                    width: 48,
                                                                    height: 48,
                                                                    child: Stack(
                                                                      children: [
                                                                        Positioned.fill(
                                                                          child: Transform.scale(
                                                                            scale:
                                                                                (song.coverUrl.contains(
                                                                                      'ytimg.com',
                                                                                    ) ||
                                                                                    song.coverUrl.contains(
                                                                                      'youtube.com',
                                                                                    ))
                                                                                ? 1.35
                                                                                : 1.0,
                                                                            child:
                                                                                (song.localImagePath !=
                                                                                        null &&
                                                                                    File(
                                                                                      song.localImagePath!,
                                                                                    ).existsSync())
                                                                                ? Image.file(
                                                                                    File(
                                                                                      song.localImagePath!,
                                                                                    ),
                                                                                    fit: BoxFit.cover,
                                                                                    cacheHeight: 200,
                                                                                  )
                                                                                : CachedNetworkImage(
                                                                                    imageUrl: song.coverUrl,
                                                                                    fit: BoxFit.cover,
                                                                                    memCacheHeight: 200,
                                                                                    errorWidget:
                                                                                        (
                                                                                          c,
                                                                                          url,
                                                                                          error,
                                                                                        ) => Container(
                                                                                          color: Colors.grey.shade800,
                                                                                          child: const Icon(
                                                                                            Icons.music_note,
                                                                                            color: Colors.white54,
                                                                                          ),
                                                                                        ),
                                                                                  ),
                                                                          ),
                                                                        ),
                                                                        if (isDownloaded)
                                                                          Positioned.fill(
                                                                            child:
                                                                                TweenAnimationBuilder<
                                                                                  double
                                                                                >(
                                                                                  tween: Tween(
                                                                                    begin: 0.0,
                                                                                    end: 1.0,
                                                                                  ),
                                                                                  duration: const Duration(
                                                                                    milliseconds: 500,
                                                                                  ),
                                                                                  curve: Curves.elasticOut,
                                                                                  builder:
                                                                                      (
                                                                                        context,
                                                                                        val,
                                                                                        child,
                                                                                      ) {
                                                                                        return Transform.scale(
                                                                                          scale: val,
                                                                                          child: Container(
                                                                                            color: Colors.black.withOpacity(
                                                                                              0.4,
                                                                                            ),
                                                                                            child: const Icon(
                                                                                              Icons.check_circle_rounded,
                                                                                              color: Colors.greenAccent,
                                                                                              size: 28,
                                                                                            ),
                                                                                          ),
                                                                                        );
                                                                                      },
                                                                                ),
                                                                          ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 14,
                                                                ),
                                                                Expanded(
                                                                  child: Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      Text(
                                                                        isDownloaded
                                                                            ? langProvider
                                                                                  .t(
                                                                                    'downloaded',
                                                                                  )
                                                                                  .toUpperCase()
                                                                            : isCanceling
                                                                            ? langProvider
                                                                                  .t(
                                                                                    'canceling',
                                                                                  )
                                                                                  .toUpperCase()
                                                                            : isPaused
                                                                            ? langProvider
                                                                                  .t(
                                                                                    'paused',
                                                                                  )
                                                                                  .toUpperCase()
                                                                            : langProvider
                                                                                  .t(
                                                                                    'downloading',
                                                                                  )
                                                                                  .toUpperCase(),
                                                                        style: TextStyle(
                                                                          color:
                                                                              isDownloaded
                                                                              ? Colors.greenAccent
                                                                              : primaryColor,
                                                                          fontWeight:
                                                                              FontWeight.w900,
                                                                          fontSize:
                                                                              10,
                                                                          letterSpacing:
                                                                              0.8,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            2,
                                                                      ),
                                                                      Text(
                                                                        song.title,
                                                                        style: const TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          color:
                                                                              Colors.white,
                                                                          fontSize:
                                                                              14,
                                                                        ),
                                                                        maxLines:
                                                                            1,
                                                                        overflow:
                                                                            TextOverflow.ellipsis,
                                                                      ),
                                                                      if (isDownloaded) ...[
                                                                        const SizedBox(
                                                                          height:
                                                                              2,
                                                                        ),
                                                                        Text(
                                                                          "%100 • Başarılı",
                                                                          style: TextStyle(
                                                                            color:
                                                                                Colors.greenAccent.shade100,
                                                                            fontSize:
                                                                                11,
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                          ),
                                                                        ),
                                                                      ] else if (detailsValue
                                                                              .isNotEmpty &&
                                                                          !isCanceling) ...[
                                                                        const SizedBox(
                                                                          height:
                                                                              2,
                                                                        ),
                                                                        _AnimatedDownloadDetails(
                                                                          details:
                                                                              detailsValue,
                                                                          percentage:
                                                                              percentage,
                                                                        ),
                                                                      ],
                                                                    ],
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 8,
                                                                ),
                                                                if (!isCanceling &&
                                                                    !isDownloaded) ...[
                                                                  GestureDetector(
                                                                    onTap: () {
                                                                      if (isPaused) {
                                                                        provider
                                                                            .downloadSong(
                                                                              song,
                                                                            );
                                                                      } else {
                                                                        provider
                                                                            .pauseDownload(
                                                                              song,
                                                                            );
                                                                      }
                                                                    },
                                                                    child: Stack(
                                                                      alignment:
                                                                          Alignment
                                                                              .center,
                                                                      children: [
                                                                        SizedBox(
                                                                          width:
                                                                              38,
                                                                          height:
                                                                              38,
                                                                          child: CircularProgressIndicator(
                                                                            value:
                                                                                progress ==
                                                                                    0.0
                                                                                ? null
                                                                                : progress,
                                                                            backgroundColor: Colors.white.withOpacity(
                                                                              0.1,
                                                                            ),
                                                                            color:
                                                                                primaryColor,
                                                                            strokeWidth:
                                                                                3,
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          width:
                                                                              28,
                                                                          height:
                                                                              28,
                                                                          decoration: BoxDecoration(
                                                                            color: primaryColor.withOpacity(
                                                                              0.2,
                                                                            ),
                                                                            shape:
                                                                                BoxShape.circle,
                                                                          ),
                                                                          child: Icon(
                                                                            isPaused
                                                                                ? Icons.play_arrow_rounded
                                                                                : Icons.pause_rounded,
                                                                            color:
                                                                                primaryColor,
                                                                            size:
                                                                                18,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 12,
                                                                  ),
                                                                  GestureDetector(
                                                                    onTap: () =>
                                                                        provider.cancelDownload(
                                                                          song.id,
                                                                        ),
                                                                    child: Container(
                                                                      padding:
                                                                          const EdgeInsets.all(
                                                                            8,
                                                                          ),
                                                                      decoration: BoxDecoration(
                                                                        color: Colors
                                                                            .white
                                                                            .withOpacity(
                                                                              0.1,
                                                                            ),
                                                                        shape: BoxShape
                                                                            .circle,
                                                                      ),
                                                                      child: const Icon(
                                                                        Icons
                                                                            .close_rounded,
                                                                        color: Colors
                                                                            .white70,
                                                                        size:
                                                                            16,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),

                                                      Positioned(
                                                        top: 6,
                                                        right: 6,
                                                        child: GestureDetector(
                                                          onTap: () => setState(
                                                            () => isMinimized =
                                                                true,
                                                          ),
                                                          behavior:
                                                              HitTestBehavior
                                                                  .opaque,
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  5,
                                                                ),
                                                            decoration:
                                                                BoxDecoration(
                                                                  color: Colors
                                                                      .black
                                                                      .withOpacity(
                                                                        0.4,
                                                                      ),
                                                                  shape: BoxShape
                                                                      .circle,
                                                                ),
                                                            child: const Icon(
                                                              Icons
                                                                  .close_fullscreen_rounded,
                                                              color:
                                                                  Colors.white,
                                                              size: 14,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    overlay.insert(_currentOverlay!);
  }
}

/// İndirme başlamadan önce (Hazırlanıyor aşamasında) yazıları animasyonlu şekilde değiştiren widget
class _AnimatedDownloadDetails extends StatefulWidget {
  final String details;
  final int percentage;

  const _AnimatedDownloadDetails({
    required this.details,
    required this.percentage,
    Key? key,
  }) : super(key: key);

  @override
  State<_AnimatedDownloadDetails> createState() =>
      _AnimatedDownloadDetailsState();
}

class _AnimatedDownloadDetailsState extends State<_AnimatedDownloadDetails> {
  int _currentIndex = 0;
  Timer? _timer;
  final List<String> _loadingTexts = [
    "Hazırlanıyor...",
    "Bağlantı kuruluyor...",
    "Boyut hesaplanıyor...",
    "İndirme başlatılıyor...",
  ];

  @override
  void initState() {
    super.initState();
    // Metin geçiş süresini 1.2 saniyeden 2.5 saniyeye çıkardık
    _timer = Timer.periodic(const Duration(milliseconds: 4000), (timer) {
      if (mounted) {
        if (_currentIndex < _loadingTexts.length - 1) {
          setState(() {
            _currentIndex++;
          });
        } else {
          timer.cancel(); // Son metne ulaştığında döngüyü tamamen durdurur
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isLoadingPhase = widget.details == "Hazırlanıyor...";
    String displayText = isLoadingPhase
        ? _loadingTexts[_currentIndex]
        : "%${widget.percentage} • ${widget.details}";

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.4),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Text(
        displayText,
        key: ValueKey<String>(displayText),
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
