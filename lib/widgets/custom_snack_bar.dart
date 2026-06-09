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
                borderRadius: BorderRadius.circular(8),
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
                borderRadius: BorderRadius.circular(8),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: accentColor.withOpacity(0.5),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (icon != null) ...[icon!, const SizedBox(width: 12)],
                        Expanded(
                          child: Text(
                            message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
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
      icon: const Icon(
        Icons.check_circle_rounded,
        color: Colors.greenAccent,
        size: 24,
      ),
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
      icon: const Icon(
        Icons.error_outline_rounded,
        color: Colors.redAccent,
        size: 24,
      ),
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
      icon: icon ??
          Icon(Icons.info_outline_rounded, color: primaryColor, size: 24),
      duration: duration,
    );
  }

  /// İndirme ilerlemesini gösteren özel Top Toast (Overlay)
  static void showDownloadProgress({
    required BuildContext context,
    required Song song,
    bool isMp4 = false,
  }) {
    hideCurrent();

    final overlay =
        Overlay.maybeOf(context) ?? navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    bool isClosing = false; // Kapanma zamanlayıcısı başladı mı

    _currentOverlay = OverlayEntry(
      builder: (context) {
        return Positioned(
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
              child: Consumer<SongProvider>(
                builder: (context, provider, child) {
                  final isCanceling =
                      isMp4 ? false : provider.isCanceling(song.id);
                  final isPaused = isMp4 ? false : provider.isPaused(song.id);
                  final primaryColor = Theme.of(context).primaryColor;
                  final langProvider = context.watch<LanguageProvider>();

                  return ValueListenableBuilder<double?>(
                    valueListenable: isMp4
                        ? provider.getVideoDownloadProgressNotifier(song.id)
                        : provider.getDownloadProgressNotifier(
                            song.id,
                          ),
                    builder: (context, progressValue, child) {
                      return ValueListenableBuilder<String>(
                        valueListenable: isMp4
                            ? provider.getVideoDownloadDetailsNotifier(song.id)
                            : provider.getDownloadDetailsNotifier(
                                song.id,
                              ),
                        builder: (context, detailsValue, child) {
                          final isDownloaded = isMp4
                              ? (progressValue != null && progressValue >= 1.0)
                              : provider.isSongDownloaded(song.id);

                          if (isDownloaded && !isClosing) {
                            isClosing = true;
                            Future.delayed(const Duration(seconds: 2), () {
                              hideCurrent();
                            });
                          }

                          final progress =
                              progressValue ?? (isDownloaded ? 1.0 : 0.0);
                          final percentage = (progress * 100).toInt();

                          return Container(
                            width: MediaQuery.of(context).size.width - 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: isDownloaded
                                      ? Colors.greenAccent.withOpacity(0.2)
                                      : primaryColor.withOpacity(0.2),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 20,
                                  sigmaY: 20,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDownloaded
                                        ? Colors.greenAccent.withOpacity(0.15)
                                        : primaryColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDownloaded
                                          ? Colors.greenAccent.withOpacity(0.5)
                                          : primaryColor.withOpacity(0.5),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            // Kapak Resmi
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: SizedBox(
                                                width: 78,
                                                height: 44,
                                                child: Stack(
                                                  children: [
                                                    Positioned.fill(
                                                      child: (song.localImagePath !=
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
                                                              imageUrl:
                                                                  song.coverUrl,
                                                              fit: BoxFit.cover,
                                                              memCacheHeight:
                                                                  200,
                                                              errorWidget: (c,
                                                                      url,
                                                                      error) =>
                                                                  Container(
                                                                color: Colors
                                                                    .grey
                                                                    .shade800,
                                                                child:
                                                                    const Icon(
                                                                  Icons
                                                                      .music_note,
                                                                  color: Colors
                                                                      .white54,
                                                                ),
                                                              ),
                                                            ),
                                                    ),
                                                    if (isDownloaded)
                                                      Positioned.fill(
                                                        child: Container(
                                                          color: Colors.black
                                                              .withOpacity(0.4),
                                                          child: const Icon(
                                                            Icons
                                                                .check_circle_rounded,
                                                            color: Colors
                                                                .greenAccent,
                                                            size: 24,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Şarkı Bilgileri
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    song.title +
                                                        (isMp4 ? " (MP4)" : ""),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  if (isDownloaded)
                                                    Text(
                                                      "%100 • Başarılı",
                                                      style: TextStyle(
                                                        color: Colors
                                                            .greenAccent
                                                            .shade100,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    )
                                                  else if (detailsValue
                                                          .isNotEmpty &&
                                                      !isCanceling)
                                                    _AnimatedDownloadDetails(
                                                      details: detailsValue,
                                                      percentage: percentage,
                                                    )
                                                  else if (isCanceling)
                                                    Text(
                                                      langProvider.t(
                                                        'canceling',
                                                      ),
                                                      style: TextStyle(
                                                        color: Colors
                                                            .grey.shade400,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Butonlar
                                            if (!isCanceling &&
                                                !isDownloaded &&
                                                !isMp4) ...[
                                              GestureDetector(
                                                onTap: () {
                                                  if (isPaused) {
                                                    provider.downloadSong(song);
                                                  } else {
                                                    provider.pauseDownload(
                                                      song,
                                                    );
                                                  }
                                                },
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                child: Container(
                                                  width: 40,
                                                  height: 40,
                                                  alignment: Alignment.center,
                                                  child: Icon(
                                                    isPaused
                                                        ? Icons
                                                            .play_arrow_rounded
                                                        : Icons.pause_rounded,
                                                    color: Colors.white,
                                                    size: 32,
                                                  ),
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () => provider
                                                    .cancelDownload(song.id),
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                child: Container(
                                                  width: 40,
                                                  height: 40,
                                                  alignment: Alignment.center,
                                                  child: const Icon(
                                                    Icons.close_rounded,
                                                    color: Colors.white70,
                                                    size: 24,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (!isDownloaded && !isCanceling)
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: LinearProgressIndicator(
                                            value: progress == 0.0 && !isPaused
                                                ? null
                                                : progress,
                                            minHeight: 2,
                                            backgroundColor: Colors.transparent,
                                            valueColor:
                                                const AlwaysStoppedAnimation<
                                                    Color>(Colors.white),
                                          ),
                                        ),
                                    ],
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
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
