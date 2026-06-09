import 'dart:io';
import 'package:dio/dio.dart'; // Dio paketini ekleyin
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:muzik_app/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/pages/recently_played_page.dart';
import 'package:muzik_app/pages/folder_detail_page.dart';
import 'package:muzik_app/widgets/google_logo_painter.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:muzik_app/widgets/mini_player.dart';
import 'package:muzik_app/widgets/custom_app_bar.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/pages/player_page.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:muzik_app/pages/artist_detail_page.dart';
import 'package:muzik_app/services/audius_service.dart';
import 'package:muzik_app/providers/language_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:muzik_app/services/custom_winning_add.dart';
import 'package:muzik_app/pages/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isLoading = false;
  late AnimationController _controller;
  Color? _dominantColor;
  String? _currentSongId;

  // Şarkı ID'sine göre çıkarılan renkleri önbellekte (RAM) tutarız
  static final Map<String, Color> _colorCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentSong = context.watch<SongProvider>().currentSong;
    if (currentSong != null && currentSong.id != _currentSongId) {
      _currentSongId = currentSong.id;
      _dominantColor = null; // Yeni şarkı yüklenirken varsayılana dön
      _extractColor(currentSong);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AuthProvider>().reloadUser();
    }
  }

  // Şarkının kapak resminden baskın rengi çıkaran fonksiyon
  Future<void> _extractColor(Song song) async {
    // Eğer renk daha önce çıkarıldıysa tekrar hesaplama, cache'den al
    if (_colorCache.containsKey(song.id)) {
      if (mounted) {
        setState(() => _dominantColor = _colorCache[song.id]);
      }
      return;
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
        size: const Size(100, 100),
        maximumColorCount: 20,
      );
      if (mounted) {
        final color = generator.dominantColor?.color ??
            generator.darkVibrantColor?.color ??
            generator.vibrantColor?.color;

        if (color != null) _colorCache[song.id] = color; // Rengi kaydet

        setState(() {
          _dominantColor = color;
        });
      }
    } catch (e) {
      debugPrint("Renk çekme hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    // AuthProvider'ın önbelleğinden ziyade her zaman en güncel Firebase kullanıcısını alıyoruz
    final user = FirebaseAuth.instance.currentUser ?? authProvider.user;
    final songProvider = context.watch<SongProvider>();
    final langProvider = context.watch<LanguageProvider>();

    return Scaffold(
      extendBody: true,
      appBar: CustomAppBar(
        title: langProvider.t('profile'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: GestureDetector(
                onTap: () => CustomWinningAd.showCoinScreen(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.amber.withOpacity(0.5), width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on_rounded,
                          color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                            begin: songProvider.coins.toDouble(),
                            end: songProvider.coins.toDouble()),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeOutExpo,
                        builder: (context, value, child) {
                          return Text(
                            '${value.toInt()}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: user == null
                ? Center(child: _buildLoginButton(context, authProvider))
                : _buildUserProfile(context, authProvider, user),
          ),
        ],
      ),
      bottomNavigationBar: songProvider.currentSong != null
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
    );
  }

  // Giriş Yapılmamışsa Gösterilecek Kutu
  Widget _buildLoginButton(BuildContext context, AuthProvider provider) {
    final langProvider = context.watch<LanguageProvider>();

    if (_isLoading) {
      return const CircularProgressIndicator();
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CustomIcons.svgIcon(
          CustomIcons.lockOutline,
          size: 80,
          color: Colors.grey,
        ),
        const SizedBox(height: 24),
        Text(
          langProvider.t('login_to_continue'),
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
              foregroundColor:
                  Theme.of(context).primaryColor.computeLuminance() > 0.5
                      ? Colors.white
                      : Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 1,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.login_rounded),
                const SizedBox(width: 12),
                Text(
                  langProvider.t('login'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleImage(Song song) {
    if (song.localImagePath != null &&
        File(song.localImagePath!).existsSync()) {
      return ClipRect(
          child: Image.file(
        File(song.localImagePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheHeight: 200,
        cacheWidth: 200,
        errorBuilder: (c, e, s) => Container(color: Colors.grey.shade800),
      ));
    }
    return ClipRect(
      child: CachedNetworkImage(
        imageUrl: song.coverUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        memCacheHeight: 200,
        memCacheWidth: 200,
        errorWidget: (context, url, error) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.grey.shade800, Colors.grey.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFolderGridCover(MusicFolder folder) {
    final songs = folder.songs;

    Widget buildDefaultCover() {
      if (songs.isEmpty) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.grey.shade800, Colors.grey.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.music_note, color: Colors.white54, size: 32),
        );
      }

      if (songs.length < 4) {
        return _buildSingleImage(songs.first);
      }

      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildSingleImage(songs[0])),
                Expanded(child: _buildSingleImage(songs[1])),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildSingleImage(songs[2])),
                Expanded(child: _buildSingleImage(songs[3])),
              ],
            ),
          ),
        ],
      );
    }

    if (folder.customImagePath != null &&
        File(folder.customImagePath!).existsSync()) {
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

  Widget _buildStatCard(
    BuildContext context,
    String label,
    num targetValue,
    String Function(num) formatter,
    String iconStr,
    Color color,
    BorderRadius borderRadius,
    bool isLeftAlignment,
    VoidCallback onTap,
  ) {
    final isGrey = color == Colors.grey;
    final bgColor =
        isGrey ? Colors.grey.shade800.withOpacity(0.3) : color.withOpacity(0.2);
    final borderColor =
        isGrey ? Colors.grey.shade400.withOpacity(0.3) : color.withOpacity(0.5);
    final iconBgColor = Colors.grey.shade500.withOpacity(0.2);

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: borderRadius,
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: isLeftAlignment ? 0 : null,
                    right: isLeftAlignment ? null : 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: CustomIcons.svgIcon(
                        iconStr,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: isLeftAlignment ? 0 : null,
                    right: isLeftAlignment ? null : 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.08),
                            offset: const Offset(0, 1),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: TweenAnimationBuilder<num>(
                        tween: Tween<num>(begin: 0, end: targetValue),
                        duration: const Duration(seconds: 2),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Text(
                            formatter(value),
                            style: TextStyle(
                              color: isGrey ? Colors.white : color,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
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
    );
  }

  Widget _buildRecentlyPlayedListItem(BuildContext context, Song song) {
    final langProvider = context.watch<LanguageProvider>();
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RecentlyPlayedPage()),
        );
      },
      child: Container(
        color: Colors.transparent,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 71,
                height: 40,
                child: _buildSingleImage(song),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      CustomIcons.svgIcon(
                        CustomIcons.historyRounded,
                        size: 14,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          langProvider.t('recently_played'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  // Giriş Yapılmışsa Gösterilecek Profil
  Widget _buildUserProfile(
    BuildContext context,
    AuthProvider provider,
    dynamic user,
  ) {
    final songProvider = context.watch<SongProvider>();
    final langProvider = context.watch<LanguageProvider>();
    final folders = songProvider.folders;

    final favoriteCount = songProvider.favoriteSongs.length;
    final totalSeconds = songProvider.totalListeningSeconds;

    final lastPlayedSong = songProvider.recentlyPlayed.isNotEmpty
        ? songProvider.recentlyPlayed.first
        : null;

    // İstatistik kutularının boyutunu kare yapmak için hesaplamalar
    final screenWidth = MediaQuery.of(context).size.width;
    const gridSpacing = 16.0;
    const crossAxisCount = 2;

    final itemWidth =
        (screenWidth - 32 - (gridSpacing * (crossAxisCount - 1))) /
            crossAxisCount;
    final itemHeight = itemWidth; // Kare
    final totalWidth = screenWidth - 32;
    final totalHeight = (itemHeight * 2) + gridSpacing;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16.0,
        16.0,
        16.0,
        (songProvider.currentSong != null ? 160.0 : 40.0) +
            MediaQuery.of(
              context,
            ).padding.bottom, // MiniPlayer altındakilerin ezilmemesi için
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // --- Kullanıcı Bilgileri ve Düzenle Butonu ---
          Text(
            user.displayName ?? langProvider.t('user'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            user.email ?? "",
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          if (user.email != null && (user.emailVerified as bool)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.blueAccent.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: Colors.blueAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    langProvider.t('verified_account'),
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ] else if (user.email != null && !(user.emailVerified as bool)) ...[
            const SizedBox(height: 16),
            _buildVerificationBanner(context, provider),
            const SizedBox(height: 16),
          ] else ...[
            const SizedBox(height: 32),
          ],

          // --- Dairesel İstatistikler ve Merkez Avatar ---
          Center(
            child: SizedBox(
              width: totalWidth,
              height: totalHeight,
              child: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                context,
                                langProvider.t('favorites'),
                                favoriteCount,
                                (val) => val.toInt().toString(),
                                CustomIcons.favoriteRounded,
                                Colors.grey,
                                BorderRadius.circular(24),
                                true, // isLeftAlignment (Soldaki kutu için sol kenarlar)
                                () => _showFavoritesBottomSheet(
                                  context,
                                  songProvider,
                                ),
                              ),
                            ),
                            const SizedBox(width: gridSpacing),
                            Expanded(
                              child: _buildStatCard(
                                context,
                                langProvider.t('following'),
                                songProvider.followedArtists.length,
                                (val) => val.toInt().toString(),
                                CustomIcons.person,
                                Theme.of(context).primaryColor,
                                BorderRadius.circular(24),
                                false, // isLeftAlignment (Sağdaki kutu için sağ kenarlar)
                                () => _showFollowedArtistsBottomSheet(
                                  context,
                                  songProvider,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: gridSpacing),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                context,
                                langProvider.t('duration'),
                                totalSeconds,
                                (val) {
                                  final s = val.toInt();
                                  if (s < 60) return "${s}sn";
                                  if (s < 3600) return "${(s ~/ 60)}dk";
                                  return "${(s / 3600).toStringAsFixed(1)}sa";
                                },
                                CustomIcons.timerRounded,
                                Theme.of(context).primaryColor,
                                BorderRadius.circular(24),
                                true, // isLeftAlignment (Soldaki kutu)
                                () => _showListeningHistoryBottomSheet(
                                  context,
                                  songProvider,
                                ),
                              ),
                            ),
                            const SizedBox(width: gridSpacing),
                            Expanded(
                              child: _buildStatCard(
                                context,
                                langProvider.t('most_played'),
                                songProvider.mostPlayed.length,
                                (val) => val.toInt().toString(),
                                CustomIcons.trending,
                                Colors.grey,
                                BorderRadius.circular(24),
                                false, // isLeftAlignment (Sağdaki kutu)
                                () => _showMostPlayedBottomSheet(
                                  context,
                                  songProvider,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Merkez Profil Resmi
                  Center(
                    child: StreamBuilder<PlayerState>(
                      stream: songProvider.playerStateStream,
                      builder: (context, snapshot) {
                        final playerState = snapshot.data;
                        final playing = playerState?.playing ?? false;

                        if (playing && !_controller.isAnimating) {
                          _controller.repeat();
                        } else if (!playing && _controller.isAnimating) {
                          _controller.stop();
                        }

                        return AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            return Container(
                              padding: const EdgeInsets.all(
                                3,
                              ), // Siyah boşluk efekti (side) düşürüldü
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(
                                  context,
                                ).scaffoldBackgroundColor, // Arkaplanı kapatarak kartlarla avatar arasında boşluk hissi verir
                                gradient: playing
                                    ? SweepGradient(
                                        colors: [
                                          Colors.transparent,
                                          _dominantColor ??
                                              Theme.of(context).primaryColor,
                                          Colors.transparent,
                                        ],
                                        stops: const [0.0, 0.5, 1.0],
                                        transform: GradientRotation(
                                          _controller.value * 2 * math.pi,
                                        ),
                                      )
                                    : null,
                              ),
                              child: child,
                            );
                          },
                          child: GestureDetector(
                            onTap: () {
                              _showProfilePictureDialog(
                                context,
                                provider,
                                user,
                              );
                            },
                            child: Hero(
                              tag: 'profilePic',
                              child: CircleAvatar(
                                radius: 64,
                                backgroundImage: user.photoURL != null
                                    ? (user.photoURL!.startsWith('http')
                                            ? CachedNetworkImageProvider(
                                                user.photoURL!,
                                              )
                                            : FileImage(File(user.photoURL!)))
                                        as ImageProvider
                                    : null,
                                child: user.photoURL == null
                                    ? Icon(
                                        Icons.person,
                                        size: 70,
                                        color: Colors.white.withOpacity(0.9),
                                      )
                                    : null,
                              ),
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
          const SizedBox(height: 32),

          // Sadece Çalma Listeleri Bölümü
          if (folders.isNotEmpty) ...[
            ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: folders.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final folder = folders[index];

                int totalSeconds = folder.songs.fold(
                  0,
                  (sum, item) => sum + (item.duration ?? 0),
                );
                String durationText = '';
                if (totalSeconds > 0) {
                  int h = totalSeconds ~/ 3600;
                  int m = (totalSeconds % 3600) ~/ 60;
                  int s = totalSeconds % 60;
                  final isTr = langProvider.currentLanguage == 'tr';
                  String hrStr = isTr ? 's' : 'h'; // TR için Saat
                  String minStr = isTr ? 'd' : 'm'; // TR için Dakika
                  String secStr = isTr ? 'sn' : 's'; // TR için Saniye

                  if (h > 0) {
                    durationText = '·$h$hrStr $m$minStr';
                  } else {
                    durationText = '·$m$minStr $s$secStr';
                  }
                }

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FolderDetailPage(folder: folder),
                      ),
                    );
                  },
                  child: Container(
                    color: Colors.transparent,
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 71,
                            height: 40,
                            child: _buildFolderGridCover(folder),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                folder.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${folder.songs.length} ${langProvider.t('song')}$durationText',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],

          // Son Dinlenenler Bölümü
          if (lastPlayedSong != null) ...[
            _buildRecentlyPlayedListItem(context, lastPlayedSong),
            const SizedBox(height: 24),
          ],

          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.redAccent.withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showSignOutBottomSheet(context, provider),
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CustomIcons.svgIcon(
                            CustomIcons.logout,
                            color: Colors.redAccent,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            langProvider.t('sign_out'),
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
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showProfilePictureDialog(
    BuildContext outerContext,
    AuthProvider provider,
    dynamic user,
  ) {
    final photoUrl = user.photoURL;
    final langProvider = outerContext.read<LanguageProvider>();
    Offset offset = Offset.zero;
    bool isDragging = false;

    showDialog(
      context: outerContext,
      useSafeArea:
          false, // Arka plan bulanıklığının tüm ekranı (Durum çubuğu dahil) kaplamasını sağlar
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (statefulContext, setState) {
            return GestureDetector(
              onTap: () => Navigator.pop(
                  statefulContext), // Bulanık alana dokunulduğunda çıkış
              behavior: HitTestBehavior.opaque,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  color: Colors.transparent,
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onTap:
                        () {}, // Resme veya isme tıklandığında arka planın tetiklenmesini önler
                    onPanUpdate: (details) {
                      setState(() {
                        offset += details.delta;
                        isDragging = true;
                      });
                    },
                    onPanEnd: (details) {
                      // Eğer 100 pikselden fazla kaydırıldıysa veya hızlıca fırlatıldıysa pencereyi kapat
                      if (offset.distance > 100 ||
                          details.velocity.pixelsPerSecond.distance > 800) {
                        Navigator.pop(statefulContext);
                      } else {
                        // Yeterince kaydırılmadıysa yaylanarak (bounce) geri dönsün
                        setState(() {
                          offset = Offset.zero;
                          isDragging = false;
                        });
                      }
                    },
                    child: AnimatedContainer(
                      duration: isDragging
                          ? Duration.zero
                          : const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      transform: Matrix4.translationValues(
                        offset.dx,
                        offset.dy,
                        0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Hero(
                            tag: 'profilePic',
                            child: Container(
                              width:
                                  MediaQuery.of(outerContext).size.width * 0.85,
                              height:
                                  MediaQuery.of(outerContext).size.width * 0.85,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey.shade800,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.6),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: photoUrl != null
                                    ? (photoUrl.startsWith('http')
                                        ? CachedNetworkImage(
                                            imageUrl: photoUrl,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.file(
                                            File(photoUrl),
                                            fit: BoxFit.cover,
                                          ))
                                    : Icon(
                                        Icons.person,
                                        size: MediaQuery.of(outerContext)
                                                .size
                                                .width *
                                            0.4,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            user.displayName ?? langProvider.t('user'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 10,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(
                                outerContext,
                              ).primaryColor.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(
                                  outerContext,
                                ).primaryColor.withOpacity(0.5),
                                width: 1.5,
                              ),
                            ),
                            child: IconButton(
                              icon: CustomIcons.svgIcon(
                                CustomIcons.edit,
                                color: Colors.white,
                                size: 24,
                              ),
                              onPressed: () {
                                Navigator.pop(statefulContext);
                                _showEditProfileBottomSheet(
                                  outerContext, // Orijinal ve bozulmayan context'i aktarıyoruz
                                  provider,
                                  user.displayName,
                                  user.photoURL,
                                );
                              },
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
  }

  Widget _buildSettingsCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: child,
    );
  }

  Widget _buildLeadingIcon(Color color, Widget icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: icon,
    );
  }

  // Cloudinary Resim Yükleme Fonksiyonu
  Future<String?> _uploadToCloudinary(String imagePath) async {
    const String cloudName = "doe2nzhgx"; // Cloudinary Cloud Name

    // Cloudinary preset adında genellikle boşluk veya Türkçe karakter olmaz.
    const String uploadPreset = "oyn_music";

    try {
      String fileName = imagePath.split('/').last;
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(imagePath, filename: fileName),
        "upload_preset": uploadPreset,
        "folder": "user_profiles", // İsteğe bağlı klasör adı
      });

      Response response = await Dio().post(
        "https://api.cloudinary.com/v1_1/$cloudName/image/upload",
        data: formData,
      );

      if (response.statusCode == 200) {
        String url = response.data["secure_url"];
        // URL'ye otomatik boyutlandırma ve optimizasyon ekle (400x400)
        if (url.contains("/upload/")) {
          // w_400,h_400: Boyutlandırma, c_fill: Kırpma, q_auto: Kalite optimizasyonu
          url = url.replaceFirst(
            "/upload/",
            "/upload/w_400,h_400,c_fill,q_auto/",
          );
        }
        // Cache (Önbellek) sorununu önlemek için URL sonuna benzersiz bir zaman damgası ekliyoruz
        url = "$url?t=${DateTime.now().millisecondsSinceEpoch}";
        return url;
      }
    } catch (e) {
      if (e is DioException) {
        debugPrint(
            "Cloudinary Upload Hatası: ${e.response?.data ?? e.message}");
      } else {
        debugPrint("Cloudinary Upload Hatası: $e");
      }
    }
    return null;
  }

  void _showEditProfileBottomSheet(
    BuildContext context,
    AuthProvider provider,
    String? currentName,
    String? currentPhotoUrl,
  ) {
    final langProvider = context.read<LanguageProvider>();
    final TextEditingController controller = TextEditingController(
      text: currentName,
    );
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
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(pageContext).viewInsets.bottom,
                          left: 24,
                          right: 24,
                          top: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              langProvider.t('edit_profile'),
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: GestureDetector(
                                onTap: () async {
                                  final ImagePicker picker = ImagePicker();
                                  final XFile? image = await picker.pickImage(
                                    source: ImageSource.gallery,
                                  );
                                  if (image != null) {
                                    // Çentik ve saat engellemesini kaldırmak için telefonu geçici olarak tam ekran yapıyoruz
                                    SystemChrome.setEnabledSystemUIMode(
                                        SystemUiMode.immersiveSticky);

                                    CroppedFile? croppedFile;
                                    try {
                                      croppedFile =
                                          await ImageCropper().cropImage(
                                        sourcePath: image.path,
                                        aspectRatio: const CropAspectRatio(
                                          ratioX: 1,
                                          ratioY: 1,
                                        ),
                                        uiSettings: [
                                          AndroidUiSettings(
                                            toolbarTitle:
                                                langProvider.t('crop_photo'),
                                            toolbarColor: Colors.grey.shade900,
                                            statusBarColor:
                                                Colors.grey.shade900,
                                            toolbarWidgetColor: Colors.white,
                                            initAspectRatio:
                                                CropAspectRatioPreset.square,
                                            lockAspectRatio: true,
                                            hideBottomControls: false,
                                            backgroundColor: Colors.black,
                                            activeControlsWidgetColor: Theme.of(
                                              context,
                                            ).primaryColor,
                                          ),
                                          IOSUiSettings(
                                            title: langProvider.t('crop_photo'),
                                            aspectRatioLockEnabled: true,
                                            resetAspectRatioEnabled: false,
                                            doneButtonTitle: langProvider.t(
                                                'save'), // iOS cihazlar için buton yazısı
                                            cancelButtonTitle:
                                                langProvider.t('cancel'),
                                          ),
                                        ],
                                      );
                                    } finally {
                                      // Kırpma ekranı kapandıktan sonra (başarılı veya iptal) orijinal çubuğu geri getir
                                      SystemChrome.setEnabledSystemUIMode(
                                          SystemUiMode.edgeToEdge);
                                    }

                                    if (croppedFile != null &&
                                        context.mounted) {
                                      setModalState(() {
                                        selectedImagePath = croppedFile!.path;
                                      });
                                    }
                                  }
                                },
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.grey.shade800,
                                      ),
                                      child: ClipOval(
                                        child: selectedImagePath != null
                                            ? Image.file(
                                                File(selectedImagePath!),
                                                fit: BoxFit.cover,
                                                width: 100,
                                                height: 100,
                                              )
                                            : (currentPhotoUrl != null &&
                                                    !currentPhotoUrl.contains(
                                                      'googleusercontent.com',
                                                    ))
                                                ? (currentPhotoUrl
                                                        .startsWith('http')
                                                    ? CachedNetworkImage(
                                                        imageUrl:
                                                            currentPhotoUrl,
                                                        fit: BoxFit.cover,
                                                        width: 100,
                                                        height: 100,
                                                        placeholder:
                                                            (context, url) =>
                                                                const Icon(
                                                          Icons.person,
                                                          size: 60,
                                                          color: Colors.white,
                                                        ),
                                                        errorWidget: (context,
                                                                url, error) =>
                                                            const Icon(
                                                          Icons.person,
                                                          size: 60,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    : Image.file(
                                                        File(currentPhotoUrl),
                                                        fit: BoxFit.cover,
                                                        width: 100,
                                                        height: 100,
                                                      ))
                                                : Icon(
                                                    Icons.person,
                                                    size: 60,
                                                    color: Colors.white
                                                        .withOpacity(0.9),
                                                  ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.grey.shade900,
                                            width: 2,
                                          ),
                                        ),
                                        child: CustomIcons.svgIcon(
                                          CustomIcons.cameraAlt,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextField(
                              controller: controller,
                              autofocus: true,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: langProvider.t('new_name'),
                                hintStyle:
                                    TextStyle(color: Colors.grey.shade500),
                                filled: true,
                                fillColor: Colors.grey.shade800,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .primaryColor
                                          .withOpacity(0.2),
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
                                        onTap: () async {
                                          if (controller.text.trim().isEmpty)
                                            return;
                                          try {
                                            bool isSuccess = true;
                                            await provider.updateDisplayName(
                                              controller.text.trim(),
                                            );
                                            if (selectedImagePath != null) {
                                              if (context.mounted) {
                                                CustomSnackBar.showInfo(
                                                  context: context,
                                                  message: langProvider.t(
                                                    'uploading_profile_picture',
                                                  ),
                                                );
                                              }
                                              String? cloudUrl =
                                                  await _uploadToCloudinary(
                                                selectedImagePath!,
                                              );
                                              if (cloudUrl != null) {
                                                await FirebaseAuth
                                                    .instance.currentUser
                                                    ?.updatePhotoURL(cloudUrl);

                                                // AuthProvider'ın Firestore'dan eski veriyi çekmesini önlemek için veritabanını da güncelliyoruz
                                                try {
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('users')
                                                      .doc(FirebaseAuth.instance
                                                          .currentUser!.uid)
                                                      .set({
                                                    'photoURL': cloudUrl
                                                  }, SetOptions(merge: true));
                                                } catch (e) {}

                                                await provider
                                                    .reloadUser(); // AuthProvider'ı ve dinleyen her sayfayı (Trendler vb.) yenile
                                                if (context.mounted)
                                                  setState(() {});
                                              } else {
                                                isSuccess = false;
                                                if (context.mounted) {
                                                  CustomSnackBar.showError(
                                                    context: context,
                                                    message: langProvider.t(
                                                      'error_uploading_picture',
                                                    ),
                                                  );
                                                }
                                              }
                                            }
                                            if (isSuccess && context.mounted) {
                                              Navigator.pop(pageContext);
                                              setState(
                                                () {},
                                              ); // Tüm UI'ın yenilenmesini garantile
                                              CustomSnackBar.showSuccess(
                                                context: context,
                                                message: langProvider
                                                    .t('profile_updated'),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              CustomSnackBar.showError(
                                                context: context,
                                                message:
                                                    "${langProvider.t('error')}: $e",
                                              );
                                            }
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(16),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          child: Center(
                                            child: Text(
                                              langProvider.t('save'),
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

  void _showSignOutBottomSheet(BuildContext context, AuthProvider provider) {
    final langProvider = context.read<LanguageProvider>();
    CustomBottomSheet.show(
      context: context,
      title: langProvider.t('sign_out'),
      message: langProvider.t('sign_out_desc'),
      primaryButtonText: langProvider.t('sign_out'),
      primaryButtonColor: Colors.redAccent,
      secondaryButtonText: langProvider.t('cancel'),
      onPrimaryButtonTap: () async {
        Navigator.pop(context);
        await provider.signOut();
        if (context.mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          CustomSnackBar.showInfo(
            context: context,
            message: langProvider.t('signed_out'),
          );
        }
      },
    );
  }

  void _showListeningHistoryBottomSheet(
    BuildContext context,
    SongProvider provider,
  ) {
    final langProvider = context.read<LanguageProvider>();

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (pageContext, animation, secondaryAnimation) {
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
                  Expanded(
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          langProvider.t('recently_played'),
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (provider.recentlyPlayed.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              langProvider.t('no_recently_played'),
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: provider.recentlyPlayed.length,
                              itemBuilder: (context, index) {
                                final song = provider.recentlyPlayed[index];
                                final listenedSeconds =
                                    provider.getSongListeningSeconds(
                                  song.id,
                                );

                                String durationString = "$listenedSeconds sn";
                                if (listenedSeconds >= 60) {
                                  durationString =
                                      "${listenedSeconds ~/ 60} dk ${(listenedSeconds % 60).toString().padLeft(2, '0')} sn";
                                }

                                return ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: CachedNetworkImage(
                                      imageUrl: song.coverUrl,
                                      width: 71,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        width: 71,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.grey.shade800,
                                              Colors.grey.shade900,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    song.artist,
                                    maxLines: 1,
                                    style:
                                        TextStyle(color: Colors.grey.shade400),
                                  ),
                                  trailing: Text(
                                    durationString,
                                    style: TextStyle(
                                        color: Theme.of(context).primaryColor),
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],
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
              position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  void _showMostPlayedBottomSheet(BuildContext context, SongProvider provider) {
    final langProvider = context.read<LanguageProvider>();

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (pageContext, animation, secondaryAnimation) {
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
                  Expanded(
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          langProvider.t('most_played'),
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (provider.mostPlayed.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              langProvider.t('not_enough_data'),
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: provider.mostPlayed.length,
                              itemBuilder: (context, index) {
                                final song = provider.mostPlayed[index];
                                final playCount = provider.mostPlayedData[index]
                                    ['count'] as int;

                                if (index == 0) {
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          provider.playSong(
                                              song, provider.mostPlayed);
                                          Navigator.pop(pageContext);
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.fromLTRB(
                                              16, 8, 16, 16),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).primaryColor.withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(16),
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
                                                ).primaryColor.withOpacity(0.1),
                                                blurRadius: 15,
                                                offset: const Offset(0, 5),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: song.localImagePath !=
                                                            null &&
                                                        File(
                                                          song.localImagePath!,
                                                        ).existsSync()
                                                    ? Image.file(
                                                        File(song
                                                            .localImagePath!),
                                                        width: 128,
                                                        height: 72,
                                                        fit: BoxFit.cover,
                                                      )
                                                    : CachedNetworkImage(
                                                        imageUrl: song.coverUrl,
                                                        width: 128,
                                                        height: 72,
                                                        fit: BoxFit.cover,
                                                        errorWidget: (
                                                          context,
                                                          url,
                                                          error,
                                                        ) =>
                                                            Container(
                                                          width: 128,
                                                          height: 72,
                                                          decoration:
                                                              BoxDecoration(
                                                            gradient:
                                                                LinearGradient(
                                                              colors: [
                                                                Colors.grey
                                                                    .shade800,
                                                                Colors.grey
                                                                    .shade900,
                                                              ],
                                                              begin: Alignment
                                                                  .topLeft,
                                                              end: Alignment
                                                                  .bottomRight,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      langProvider
                                                          .t('most_played')
                                                          .toUpperCase(),
                                                      style: TextStyle(
                                                        color: Theme.of(context)
                                                            .primaryColor,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        letterSpacing: 1.2,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      song.title,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      song.artist,
                                                      maxLines: 1,
                                                      style: TextStyle(
                                                        color: Colors
                                                            .grey.shade300,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                "$playCount ${langProvider.t('times')}",
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
                                      const Positioned(
                                        top: -2,
                                        left: 4,
                                        child: _PulsingStar(),
                                      ),
                                    ],
                                  );
                                }

                                return ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: song.localImagePath != null &&
                                            File(song.localImagePath!)
                                                .existsSync()
                                        ? Image.file(
                                            File(song.localImagePath!),
                                            width: 71,
                                            height: 40,
                                            fit: BoxFit.cover,
                                          )
                                        : CachedNetworkImage(
                                            imageUrl: song.coverUrl,
                                            width: 71,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            errorWidget:
                                                (context, url, error) =>
                                                    Container(
                                              width: 71,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.grey.shade800,
                                                    Colors.grey.shade900,
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),
                                  title: Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    song.artist,
                                    maxLines: 1,
                                    style:
                                        TextStyle(color: Colors.grey.shade400),
                                  ),
                                  trailing: Text(
                                    "$playCount ${langProvider.t('times')}",
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onTap: () {
                                    provider.playSong(
                                        song, provider.mostPlayed);
                                    Navigator.pop(pageContext);
                                  },
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],
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
              position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  void _showFavoritesBottomSheet(BuildContext context, SongProvider provider) {
    final langProvider = context.read<LanguageProvider>();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (pageContext, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Theme.of(pageContext).scaffoldBackgroundColor,
            body: SafeArea(
              child: Consumer<SongProvider>(
                builder: (context, songProvider, child) {
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
                      Expanded(
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              langProvider.t('favorites'),
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (songProvider.favoriteSongs.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Text(
                                  langProvider.t('no_favorites_yet'),
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            else
                              Expanded(
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: songProvider.favoriteSongs.length,
                                  itemBuilder: (context, index) {
                                    final song =
                                        songProvider.favoriteSongs[index];
                                    final duration =
                                        Duration(seconds: song.duration ?? 0);
                                    final durationString =
                                        "${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}";

                                    return ListTile(
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: song.localImagePath != null &&
                                                File(song.localImagePath!)
                                                    .existsSync()
                                            ? Image.file(
                                                File(song.localImagePath!),
                                                width: 71,
                                                height: 40,
                                                fit: BoxFit.cover,
                                              )
                                            : CachedNetworkImage(
                                                imageUrl: song.coverUrl,
                                                width: 71,
                                                height: 40,
                                                fit: BoxFit.cover,
                                                errorWidget:
                                                    (context, url, error) =>
                                                        Container(
                                                  width: 71,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        Colors.grey.shade800,
                                                        Colors.grey.shade900,
                                                      ],
                                                      begin: Alignment.topLeft,
                                                      end:
                                                          Alignment.bottomRight,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                      ),
                                      title: Text(
                                        song.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                      subtitle: Text(
                                        song.artist,
                                        maxLines: 1,
                                        style: TextStyle(
                                            color: Colors.grey.shade400),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            durationString,
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .primaryColor,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.check_circle_rounded,
                                              color: Colors.greenAccent,
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              songProvider.toggleFavorite(song);
                                            },
                                          ),
                                        ],
                                      ),
                                      onTap: () {
                                        songProvider.playSong(
                                          song,
                                          songProvider.favoriteSongs,
                                        );
                                        Navigator.pop(
                                          pageContext,
                                        ); // Şarkıyı açtığında bottomsheet'i kapatır
                                      },
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 24),
                          ],
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

  void _showFollowedArtistsBottomSheet(
    BuildContext context,
    SongProvider provider,
  ) {
    final langProvider = context.read<LanguageProvider>();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (pageContext, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Theme.of(pageContext).scaffoldBackgroundColor,
            body: SafeArea(
              child: Consumer<SongProvider>(
                builder: (context, songProvider, child) {
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
                      Expanded(
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              langProvider.t('following'),
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (songProvider.followedArtists.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Text(
                                  langProvider.t('no_followed_artists'),
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            else
                              Expanded(
                                child: GridView.builder(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 0.8,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                                  itemCount:
                                      songProvider.followedArtists.length,
                                  itemBuilder: (context, index) {
                                    final artistName =
                                        songProvider.followedArtists[index];

                                    return _FollowedArtistTile(
                                      artistName: artistName,
                                      songProvider: songProvider,
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 24),
                          ],
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

  Widget _buildVerificationBanner(BuildContext context, AuthProvider provider) {
    final langProvider = context.read<LanguageProvider>();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.orangeAccent.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.orangeAccent.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mark_email_unread_rounded,
                color: Colors.orangeAccent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              langProvider.t('email_not_verified'),
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              try {
                await provider.sendEmailVerification();
                if (context.mounted) {
                  CustomSnackBar.showSuccess(
                    context: context,
                    message: langProvider.t('verification_sent'),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  CustomSnackBar.showError(
                    context: context,
                    message: e.toString().replaceAll('Exception: ', ''),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.withOpacity(0.3),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              minimumSize: const Size(0, 36),
              side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(langProvider.t('verify_email'),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// Takip edilen sanatçıyı dinamik resmiyle (Shimmer dahil) yükleyen özel liste elemanı
class _FollowedArtistTile extends StatefulWidget {
  final String artistName;
  final SongProvider songProvider;

  const _FollowedArtistTile({
    required this.artistName,
    required this.songProvider,
  });

  @override
  State<_FollowedArtistTile> createState() => _FollowedArtistTileState();
}

class _FollowedArtistTileState extends State<_FollowedArtistTile> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    // Eğer profil resmi bellekte varsa anında göster
    if (widget.songProvider.getArtistAvatar(widget.artistName) != null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Yoksa Youtube kanalındaki gerçek resmi çekilmesini bekle
    await widget.songProvider.fetchArtistAvatar(widget.artistName);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final artistAvatar = widget.songProvider.getArtistAvatar(widget.artistName);
    final imageUrl = artistAvatar != null && artistAvatar.isNotEmpty
        ? artistAvatar
        : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(widget.artistName)}&background=random&color=fff&size=100';

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtistDetailPage(
              artistName: widget.artistName,
              songs: const [],
            ),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipOval(
                child: _isLoading
                    ? const _ProfileShimmer(
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: 0,
                      )
                    : Container(
                        color: Colors.grey.shade800,
                        child: Transform.scale(
                          scale: 1.0,
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                const SizedBox(),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.artistName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Profil sayfası için özel Shimmer (İskelet Parlama) Efekti
class _ProfileShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _ProfileShimmer({
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  State<_ProfileShimmer> createState() => _ProfileShimmerState();
}

class _ProfileShimmerState extends State<_ProfileShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-2.0 + (_controller.value * 4), 0.0),
              end: Alignment(0.0 + (_controller.value * 4), 0.0),
              colors: [
                Colors.grey.shade900,
                Colors.grey.shade800,
                Colors.grey.shade900,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

class _PulsingStar extends StatefulWidget {
  const _PulsingStar();

  @override
  State<_PulsingStar> createState() => _PulsingStarState();
}

class _PulsingStarState extends State<_PulsingStar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true); // Durmadan tekrar eder (büyür ve küçülür)

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: Icon(
        Icons.star_rounded,
        color: Theme.of(context).primaryColor,
        size: 36,
        shadows: [
          Shadow(
            color: Theme.of(context).primaryColor.withOpacity(0.5),
            blurRadius: 15,
            offset: const Offset(0, 0),
          ),
        ],
      ),
    );
  }
}
