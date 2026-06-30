import 'dart:ui';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/pages/player_page.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/providers/language_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:muzik_app/widgets/device_cover_placeholder.dart';
import 'package:palette_generator/palette_generator.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  static final Map<String, Color> dominantColorCache = {};

  static Future<Color?> getDominantColor(Song song) async {
    if (dominantColorCache.containsKey(song.id)) {
      return dominantColorCache[song.id];
    }
    try {
      ImageProvider imageProvider;
      if (song.localImagePath != null &&
          File(song.localImagePath!).existsSync()) {
        imageProvider = FileImage(File(song.localImagePath!));
      } else {
        imageProvider = CachedNetworkImageProvider(song.coverUrl);
      }
      final generator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(50, 50),
      );

      // Canlı veya belirgin renkleri tercih et
      Color? color = generator.vibrantColor?.color ??
          generator.lightVibrantColor?.color ??
          generator.dominantColor?.color;

      // Eğer renk siyaha çok yakınsa (luminance < 0.05) daha açık/soluk alternatifleri dene
      if (color != null && color.computeLuminance() < 0.05) {
        color = generator.lightMutedColor?.color ??
            generator.mutedColor?.color ??
            color;
      }

      if (color != null) {
        dominantColorCache[song.id] = color;
        return color;
      }
    } catch (e) {
      debugPrint("MiniPlayer renk çekme hatası: $e");
    }
    return null;
  }

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  Timer? _timer;
  late SongProvider _songProvider;

  // Global state'ler: MiniPlayer'ın tüm sayfalarda aynı durumu (açık/kapalı) ve aynı konumu korumasını sağlar
  static final ValueNotifier<bool> isGloballyMinimized = ValueNotifier<bool>(
    false,
  );
  static Offset globalFloatingPosition = const Offset(
    -1,
    -1,
  ); // Dinamik hesaplama için varsayılan işaretçi
  static OverlayEntry? floatingEntry;

  Color? _dominantColor;
  String? _currentSongId;

  void _updateColor(Song song) async {
    if (_currentSongId == song.id) return;
    _currentSongId = song.id;
    _dominantColor = MiniPlayer.dominantColorCache[song.id];
    if (_dominantColor == null) {
      final color = await MiniPlayer.getDominantColor(song);
      if (mounted && _currentSongId == song.id) {
        setState(() {
          _dominantColor = color;
        });
      }
    }
  }

  static void showFloatingPlayer(BuildContext context) {
    if (floatingEntry != null) return;
    floatingEntry = OverlayEntry(
      builder: (context) => const _FloatingMiniPlayer(),
    );
    Overlay.of(context, rootOverlay: true).insert(floatingEntry!);
  }

  static void hideFloatingPlayer() {
    floatingEntry?.remove();
    floatingEntry = null;
  }

  @override
  void initState() {
    super.initState();
    _songProvider = context.read<SongProvider>();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_songProvider.isSleepTimerActive) {
          setState(() {});
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = context.watch<SongProvider>();
    final langProvider = context.watch<LanguageProvider>();
    final song = songProvider.currentSong;

    if (song == null) return const SizedBox.shrink();

    _updateColor(song);

    return ValueListenableBuilder<bool>(
      valueListenable: isGloballyMinimized,
      builder: (context, isMinimized, child) {
        if (isMinimized) {
          // Eğer küçültüldüyse, normal MiniPlayer'ı gizle ve yüzen player'ı başlat
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showFloatingPlayer(context);
          });
          return const SizedBox.shrink();
        } else {
          // Büyütüldüyse yüzen player'ı kapat ve alt menüdekini geri getir
          WidgetsBinding.instance.addPostFrameCallback((_) {
            hideFloatingPlayer();
          });

          return StreamBuilder<PlayerState>(
            stream: songProvider.playerStateStream,
            builder: (context, snapshot) {
              final playerState = snapshot.data;
              final playing = playerState?.playing ?? false;
              final processingState = playerState?.processingState;
              final isLoading = processingState == ProcessingState.loading ||
                  processingState == ProcessingState.buffering ||
                  songProvider.isSongLoading;

              final glowColor =
                  _dominantColor ?? Theme.of(context).primaryColor;

              return _buildExpandedPlayer(
                context,
                songProvider,
                langProvider,
                song,
                playing,
                processingState,
                isLoading,
                glowColor,
              );
            },
          );
        }
      },
    );
  }

  /// Alt navigasyon barındaki normal geniş görünümlü oynatıcı
  Widget _buildExpandedPlayer(
    BuildContext context,
    SongProvider songProvider,
    LanguageProvider langProvider,
    Song song,
    bool playing,
    ProcessingState? processingState,
    bool isLoading,
    Color glowColor,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          right: screenWidth * 0.025,
          left: screenWidth * 0.025,
          bottom: 8,
          top: 8,
        ),
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            // Sağa/sola kaydırma ile artık sadece şarkı değiştiriliyor
            if ((details.primaryVelocity ?? 0) < -100) {
              songProvider.playNext();
            } else if ((details.primaryVelocity ?? 0) > 100) {
              songProvider.playPrevious();
            }
          },
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < -100) {
              PlayerPage.show(context);
            }
          },
          onTap: () {
            PlayerPage.show(context);
          },
          child: RepaintBoundary(
            child: SizedBox(
              width: screenWidth * 0.95,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  color: Color.lerp(Colors.grey.shade900, glowColor, 0.25),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 6,
                          right: 12,
                          top: 8,
                          bottom: 8,
                        ),
                        child: Row(
                          children: [
                            // En Sol: Kapak Resmi
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: (song.localImagePath != null &&
                                      File(
                                        song.localImagePath!,
                                      ).existsSync())
                                  ? Image.file(
                                      File(song.localImagePath!),
                                      height: 44,
                                      width: 78,
                                      fit: BoxFit.cover,
                                      cacheHeight: 150,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) =>
                                          DeviceCoverPlaceholder(
                                        width: 78,
                                        height: 44,
                                        borderRadius: 4,
                                        logoColor:
                                            Theme.of(context).primaryColor,
                                      ),
                                    )
                                  : (song.coverUrl.isEmpty)
                                      ? DeviceCoverPlaceholder(
                                          width: 78,
                                          height: 44,
                                          borderRadius: 4,
                                          logoColor:
                                              Theme.of(context).primaryColor,
                                        )
                                      : CachedNetworkImage(
                                          imageUrl: song.coverUrl,
                                          height: 44,
                                          width: 78,
                                          fit: BoxFit.cover,
                                          memCacheHeight: 150,
                                          errorWidget: (context, url, error) =>
                                              DeviceCoverPlaceholder(
                                            width: 78,
                                            height: 44,
                                            borderRadius: 4,
                                            logoColor:
                                                Theme.of(context).primaryColor,
                                          ),
                                        ),
                            ),

                            const SizedBox(width: 12),
                            // Orta: Şarkı ve Sanatçı Adı
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13, // Küçük yazı
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 11, // Çok küçük yazı
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (songProvider.isSleepTimerActive &&
                                songProvider.sleepTimerEndTime != null)
                              _buildTimerDisplay(
                                context,
                                songProvider.sleepTimerEndTime!,
                              ),
                            const SizedBox(width: 8),
                            // En Sağ: Oynat / Durdur İkonu
                            if (isLoading)
                              const SizedBox(
                                width: 36,
                                height: 36,
                                child: Padding(
                                  padding: EdgeInsets.all(6.0),
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              )
                            else
                              GestureDetector(
                                onTap: () {
                                  if (playing) {
                                    songProvider.audioPlayer.pause();
                                  } else {
                                    songProvider.audioPlayer.play();
                                  }
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  child: CustomIcons.svgIcon(
                                    playing
                                        ? CustomIcons.pauseRounded
                                        : CustomIcons.playArrowRounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // En Alt: İlerleme Çizgisi
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: RepaintBoundary(
                          child: StreamBuilder<Duration>(
                            stream: songProvider.audioPlayer.positionStream,
                            builder: (context, snapshot) {
                              final position = snapshot.data ?? Duration.zero;
                              final duration =
                                  songProvider.audioPlayer.duration ??
                                      Duration.zero;
                              double value = 0.0;
                              if (duration.inMilliseconds > 0) {
                                value = (position.inMilliseconds /
                                        duration.inMilliseconds)
                                    .clamp(0.0, 1.0);
                              }
                              return LinearProgressIndicator(
                                value: value,
                                minHeight: 1,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              );
                            },
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
    );
  }

  Widget _buildTimerDisplay(BuildContext context, DateTime endTime) {
    final remaining = endTime.difference(DateTime.now());
    if (remaining.isNegative) return const SizedBox.shrink();
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomIcons.svgIcon(
            CustomIcons.timerOutlined,
            size: 10,
            color: primaryColor,
          ),
          const SizedBox(width: 4),
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: primaryColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sürüklenebilir Yüzen (PiP) Mini Oynatıcı Widget'ı
class _FloatingMiniPlayer extends StatefulWidget {
  const _FloatingMiniPlayer({Key? key}) : super(key: key);

  @override
  State<_FloatingMiniPlayer> createState() => _FloatingMiniPlayerState();
}

class _FloatingMiniPlayerState extends State<_FloatingMiniPlayer> {
  Offset position = _MiniPlayerState.globalFloatingPosition;

  Color? _dominantColor;
  String? _currentSongId;

  void _updateColor(Song song) async {
    if (_currentSongId == song.id) return;
    _currentSongId = song.id;
    _dominantColor = MiniPlayer.dominantColorCache[song.id];
    if (_dominantColor == null) {
      final color = await MiniPlayer.getDominantColor(song);
      if (mounted && _currentSongId == song.id) {
        setState(() {
          _dominantColor = color;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Eğer pozisyon henüz hesaplanmadıysa (ilk kez açılıyorsa)
    if (position == const Offset(-1, -1)) {
      final size = MediaQuery.of(context).size;
      final bottomPadding = MediaQuery.of(context).padding.bottom;
      // Sağ alt köşe, BottomNavigationBar'ın hemen üstüne konumlandırır
      position = Offset(
        size.width -
            140 -
            24, // Ekran genişliği - Kutu Genişliği - Sağ boşluk (24px)
        size.height -
            140 -
            bottomPadding -
            90, // Ekran yüksekliği - Kutu Yüksekliği - Alt Menü Yüksekliği
      );
      _MiniPlayerState.globalFloatingPosition = position;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SongProvider>();
    final song = provider.currentSong;
    if (song == null) return const SizedBox.shrink();

    _updateColor(song);
    final glowColor = _dominantColor ?? Theme.of(context).primaryColor;

    return StreamBuilder<PlayerState>(
      stream: provider.playerStateStream,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        final processingState = snapshot.data?.processingState;
        final isLoading = processingState == ProcessingState.loading ||
            processingState == ProcessingState.buffering ||
            provider.isSongLoading;

        return Positioned(
          left: position.dx,
          top: position.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                // Ekran sınırlarının dışına çıkmaması için pozisyonu kısıtla
                final size = MediaQuery.of(context).size;
                position = Offset(
                  (position.dx + details.delta.dx).clamp(
                    0.0,
                    size.width - 140.0,
                  ),
                  (position.dy + details.delta.dy).clamp(
                    0.0,
                    size.height - 140.0,
                  ),
                );
                // En son bırakıldığı konumu global state'e kaydet ki sayfa değiştiğinde unutmasın
                _MiniPlayerState.globalFloatingPosition = position;
              });
            },
            onTap: () {
              // Üstüne tıklanınca PiP arkada kapansın ve direkt tam ekran oynatıcı açılsın
              PlayerPage.show(context);
              _MiniPlayerState.isGloballyMinimized.value = false;
            },
            child: Material(
              type: MaterialType
                  .transparency, // Overlay içinde tap efektinin çalışması için
              child: SizedBox(
                width: 140,
                height: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    color: Color.lerp(Colors.grey.shade900, glowColor, 0.25),
                    padding: const EdgeInsets.all(12),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Üst Kısım: Küçük kapak ve bilgiler
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: (song.localImagePath != null &&
                                          File(
                                            song.localImagePath!,
                                          ).existsSync())
                                      ? Image.file(
                                          File(song.localImagePath!),
                                          width: 80,
                                          height: 45,
                                          fit: BoxFit.cover,
                                          cacheHeight: 200,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  DeviceCoverPlaceholder(
                                            width: 80,
                                            height: 45,
                                            borderRadius: 4,
                                            logoColor:
                                                Theme.of(context).primaryColor,
                                          ),
                                        )
                                      : (song.coverUrl.isEmpty)
                                          ? DeviceCoverPlaceholder(
                                              width: 80,
                                              height: 45,
                                              borderRadius: 4,
                                              logoColor: Theme.of(context)
                                                  .primaryColor,
                                            )
                                          : CachedNetworkImage(
                                              imageUrl: song.coverUrl,
                                              width: 80,
                                              height: 45,
                                              fit: BoxFit.cover,
                                              memCacheHeight: 200,
                                              errorWidget: (
                                                context,
                                                url,
                                                error,
                                              ) =>
                                                  DeviceCoverPlaceholder(
                                                width: 80,
                                                height: 45,
                                                borderRadius: 4,
                                                logoColor: Theme.of(context)
                                                    .primaryColor,
                                              ),
                                            ),
                                ),
                              ],
                            ),
                            // Alt Kısım: Yan yana Play/Pause ve Geçiş Butonları
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                if (isLoading)
                                  const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: SizedBox(
                                      width: 30,
                                      height: 30,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    ),
                                  )
                                else
                                  GestureDetector(
                                    onTap: () {
                                      if (playing)
                                        provider.audioPlayer.pause();
                                      else
                                        provider.audioPlayer.play();
                                    },
                                    behavior: HitTestBehavior.opaque,
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: CustomIcons.svgIcon(
                                        playing
                                            ? CustomIcons.pauseRounded
                                            : CustomIcons.playArrowRounded,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    ),
                                  ),
                                GestureDetector(
                                  onTap: () => provider.playNext(),
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: CustomIcons.svgIcon(
                                      CustomIcons.playerNext,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Mini player'da şarkı yüklenirken dönen animasyonlu metin
class _MiniPlayerLoadingText extends StatefulWidget {
  const _MiniPlayerLoadingText({Key? key}) : super(key: key);

  @override
  State<_MiniPlayerLoadingText> createState() => _MiniPlayerLoadingTextState();
}

class _MiniPlayerLoadingTextState extends State<_MiniPlayerLoadingText> {
  int _currentIndex = 0;
  Timer? _timer;
  final List<String> _loadingTexts = [
    "Hazırlanıyor...",
    "Bağlanıyor...",
    "Oynatılıyor...",
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 3000), (timer) {
      if (mounted) {
        if (_currentIndex < _loadingTexts.length - 1) {
          setState(() {
            _currentIndex++;
          });
        } else {
          timer.cancel();
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
        _loadingTexts[_currentIndex],
        key: ValueKey<String>(_loadingTexts[_currentIndex]),
        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
      ),
    );
  }
}
