import 'dart:io';
import 'package:dio/dio.dart'; // Dio paketini ekleyin
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:just_audio/just_audio.dart';
import 'package:muzik_app/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/pages/recently_played_page.dart';
import 'package:muzik_app/pages/folder_detail_page.dart';
import 'package:muzik_app/widgets/google_logo_painter.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:muzik_app/widgets/custom_app_bar.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/pages/player_page.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:muzik_app/pages/artist_detail_page.dart';
import 'package:muzik_app/services/audius_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _controller;
  Color? _dominantColor;
  String? _currentSongId;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Şarkının kapak resminden baskın rengi çıkaran fonksiyon
  Future<void> _extractColor(Song song) async {
    try {
      ImageProvider imageProvider;
      if (song.localImagePath != null &&
          File(song.localImagePath!).existsSync()) {
        imageProvider = FileImage(File(song.localImagePath!));
      } else {
        imageProvider = NetworkImage(song.coverUrl);
      }

      final generator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(100, 100),
        maximumColorCount: 20,
      );
      if (mounted) {
        setState(() {
          _dominantColor =
              generator.dominantColor?.color ??
              generator.darkVibrantColor?.color ??
              generator.vibrantColor?.color;
        });
      }
    } catch (e) {
      debugPrint("Renk çekme hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final songProvider = context.watch<SongProvider>();
    final currentSong = songProvider.currentSong;

    if (currentSong != null && currentSong.id != _currentSongId) {
      _currentSongId = currentSong.id;
      _dominantColor = null; // Yeni şarkı yüklenirken varsayılana dön
      _extractColor(currentSong);
    }

    return Scaffold(
      appBar: const CustomAppBar(title: "Profil"),
      body: user == null
          ? Center(child: _buildLoginButton(context, authProvider))
          : _buildUserProfile(context, authProvider, user),
    );
  }

  // Giriş Yapılmamışsa Gösterilecek Kutu
  Widget _buildLoginButton(BuildContext context, AuthProvider provider) {
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
        const Text(
          "Devam etmek için giriş yapın",
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              elevation: 1,
            ),
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });
              try {
                final user = await provider.signInWithGoogle();
                if (mounted) {
                  setState(() => _isLoading = false);
                  if (user != null) {
                    Navigator.pop(context);
                    CustomSnackBar.showSuccess(
                      context: context,
                      message:
                          "Hoş Geldin, ${user.displayName ?? 'Kullanıcı'}!",
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  CustomSnackBar.showError(
                    context: context,
                    message: "Giriş başarısız: $e",
                  );
                }
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  size: const Size(20, 20),
                  painter: GoogleLogoPainter(),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Google ile Giriş Yap',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFolderLeading(MusicFolder folder) {
    Widget imageWidget;
    if (folder.customImagePath != null &&
        File(folder.customImagePath!).existsSync()) {
      imageWidget = Image.file(
        File(folder.customImagePath!),
        fit: BoxFit.cover,
      );
    } else if (folder.songs.isNotEmpty) {
      final song = folder.songs.first;
      if (song.localImagePath != null &&
          File(song.localImagePath!).existsSync()) {
        imageWidget = Image.file(File(song.localImagePath!), fit: BoxFit.cover);
      } else {
        imageWidget = Image.network(
          song.coverUrl,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey.shade800, Colors.grey.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        );
      }
    } else {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey.shade800, Colors.grey.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: 50, height: 50, child: imageWidget),
    );
  }

  Widget _buildModernStatCard(
    BuildContext context,
    String label,
    String value,
    String iconStr,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: CustomIcons.svgIcon(iconStr, color: color, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastPlayedCard(BuildContext context, Song song) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RecentlyPlayedPage()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child:
                  song.localImagePath != null &&
                      File(song.localImagePath!).existsSync()
                  ? Image.file(
                      File(song.localImagePath!),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      song.coverUrl,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        width: 64,
                        height: 64,
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
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CustomIcons.svgIcon(
                        CustomIcons.historyRounded,
                        size: 14,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "SON DİNLENEN",
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
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
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserStats(BuildContext context, SongProvider songProvider) {
    final favoriteCount = songProvider.favoriteSongs.length;

    // Gerçek toplam dinleme süresi (Saniye cinsinden)
    final totalSeconds = songProvider.totalListeningSeconds;

    String timeString;
    if (totalSeconds < 60) {
      timeString = "${totalSeconds}sn";
    } else if (totalSeconds < 3600) {
      timeString = "${(totalSeconds / 60).floor()}dk";
    } else {
      timeString = "${(totalSeconds / 3600).toStringAsFixed(1)}sa";
    }

    final lastPlayedSong = songProvider.recentlyPlayed.isNotEmpty
        ? songProvider.recentlyPlayed.first
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildModernStatCard(
                  context,
                  "Favoriler",
                  "$favoriteCount",
                  CustomIcons.favoriteRounded,
                  Colors.pinkAccent,
                  onTap: () => _showFavoritesBottomSheet(context, songProvider),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModernStatCard(
                  context,
                  "Takip",
                  "${songProvider.followedArtists.length}",
                  CustomIcons.person,
                  Colors.blueAccent,
                  onTap: () =>
                      _showFollowedArtistsBottomSheet(context, songProvider),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildModernStatCard(
                  context,
                  "Süre",
                  timeString,
                  CustomIcons.timerRounded,
                  Colors.orangeAccent,
                  onTap: () =>
                      _showListeningHistoryBottomSheet(context, songProvider),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModernStatCard(
                  context,
                  "En Çok",
                  "${songProvider.mostPlayed.length}",
                  CustomIcons.trending,
                  Colors.purpleAccent,
                  onTap: () =>
                      _showMostPlayedBottomSheet(context, songProvider),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (lastPlayedSong != null)
            _buildLastPlayedCard(context, lastPlayedSong),
        ],
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
    final folders = songProvider.folders;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Row(
            children: [
              StreamBuilder<PlayerState>(
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
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.35),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
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
                    child: CircleAvatar(
                      radius: 45,
                      backgroundImage: user.photoURL != null
                          ? (user.photoURL!.startsWith('http')
                                    ? NetworkImage(user.photoURL!)
                                    : FileImage(File(user.photoURL!)))
                                as ImageProvider
                          : null,
                      backgroundColor: Colors.grey.shade800,
                      child: user.photoURL == null
                          ? Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.white.withOpacity(0.9),
                            )
                          : null,
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        user.displayName ?? "Kullanıcı",
                        style: const TextStyle(
                          fontSize: 20,
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
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _showEditProfileBottomSheet(
                          context,
                          provider,
                          user.displayName,
                          user.photoURL,
                        ),
                        icon: CustomIcons.svgIcon(
                          CustomIcons.edit,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "Profili Düzenle",
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.3),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // İstatistikler Bölümü
          _buildUserStats(context, songProvider),
          const SizedBox(height: 12),

          // Çalma Listeleri Bölümü
          if (folders.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Çalma Listelerim (${folders.length})",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingsCard(
              child: Column(
                children: folders.asMap().entries.map((entry) {
                  final index = entry.key;
                  final folder = entry.value;
                  return Column(
                    children: [
                      ListTile(
                        leading: _buildFolderLeading(folder),
                        title: Text(
                          folder.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          '${folder.songs.length} şarkı',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                        trailing: CustomIcons.svgIcon(
                          CustomIcons.arrowForwardIos,
                          size: 16,
                          color: Colors.grey,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  FolderDetailPage(folder: folder),
                            ),
                          );
                        },
                      ),
                      if (index != folders.length - 1)
                        const Divider(height: 1, color: Colors.white10),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],

          _buildSettingsCard(
            child: ListTile(
              leading: _buildLeadingIcon(
                Colors.redAccent,
                CustomIcons.svgIcon(
                  CustomIcons.logout,
                  color: Colors.redAccent,
                  size: 24,
                ),
              ),
              title: const Text(
                'Çıkış Yap',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => _showSignOutBottomSheet(context, provider),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
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
    const String uploadPreset = "OYN Müzik"; // Unsigned Upload Preset

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
        return url;
      }
    } catch (e) {
      debugPrint("Cloudinary Upload Hatası: $e");
    }
    return null;
  }

  void _showEditProfileBottomSheet(
    BuildContext context,
    AuthProvider provider,
    String? currentName,
    String? currentPhotoUrl,
  ) {
    final TextEditingController controller = TextEditingController(
      text: currentName,
    );
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Text(
                'Profili Düzenle',
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
                      final croppedFile = await ImageCropper().cropImage(
                        sourcePath: image.path,
                        aspectRatio: const CropAspectRatio(
                          ratioX: 1,
                          ratioY: 1,
                        ),
                        uiSettings: [
                          AndroidUiSettings(
                            toolbarTitle: 'Fotoğrafı Kırp',
                            toolbarColor: Colors.grey.shade900,
                            toolbarWidgetColor: Colors.white,
                            initAspectRatio: CropAspectRatioPreset.square,
                            lockAspectRatio: true,
                            backgroundColor: Colors.black,
                            activeControlsWidgetColor: Theme.of(
                              context,
                            ).primaryColor,
                          ),
                          IOSUiSettings(
                            title: 'Fotoğrafı Kırp',
                            aspectRatioLockEnabled: true,
                            resetAspectRatioEnabled: false,
                          ),
                        ],
                      );

                      if (croppedFile != null && context.mounted) {
                        setModalState(() {
                          selectedImagePath = croppedFile.path;
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
                                        )
                                    ? (currentPhotoUrl.startsWith('http')
                                          ? Image.network(
                                              currentPhotoUrl,
                                              fit: BoxFit.cover,
                                              width: 100,
                                              height: 100,
                                              loadingBuilder:
                                                  (
                                                    context,
                                                    child,
                                                    loadingProgress,
                                                  ) {
                                                    if (loadingProgress == null)
                                                      return child;
                                                    return Icon(
                                                      Icons.person,
                                                      size: 60,
                                                      color: Colors.white
                                                          .withOpacity(0.9),
                                                    );
                                                  },
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => Icon(
                                                    Icons.person,
                                                    size: 60,
                                                    color: Colors.white
                                                        .withOpacity(0.9),
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
                                        color: Colors.white.withOpacity(0.9),
                                      )),
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
                  hintText: 'Yeni isim',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
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
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.2),
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
                            if (controller.text.trim().isEmpty) return;
                            try {
                              bool isSuccess = true;
                              await provider.updateDisplayName(
                                controller.text.trim(),
                              );
                              if (selectedImagePath != null) {
                                if (context.mounted) {
                                  CustomSnackBar.showInfo(
                                    context: context,
                                    message: "Profil resmi yükleniyor...",
                                  );
                                }
                                String? cloudUrl = await _uploadToCloudinary(
                                  selectedImagePath!,
                                );
                                if (cloudUrl != null) {
                                  await provider.user?.updatePhotoURL(cloudUrl);
                                  if (context.mounted) setState(() {});
                                } else {
                                  isSuccess = false;
                                  if (context.mounted) {
                                    CustomSnackBar.showError(
                                      context: context,
                                      message: "Resim yüklenirken hata oluştu.",
                                    );
                                  }
                                }
                              }
                              if (isSuccess && context.mounted) {
                                Navigator.pop(context);
                                CustomSnackBar.showSuccess(
                                  context: context,
                                  message: "Profil başarıyla güncellendi.",
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                CustomSnackBar.showError(
                                  context: context,
                                  message: "Güncelleme başarısız: $e",
                                );
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'Kaydet',
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
    );
  }

  void _showSignOutBottomSheet(BuildContext context, AuthProvider provider) {
    CustomBottomSheet.show(
      context: context,
      title: 'Çıkış Yap',
      message: 'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
      primaryButtonText: 'Çıkış Yap',
      primaryButtonColor: Colors.redAccent,
      secondaryButtonText: 'İptal',
      onPrimaryButtonTap: () {
        Navigator.pop(context);
        provider.signOut();
        CustomSnackBar.showInfo(context: context, message: 'Çıkış yapıldı.');
      },
    );
  }

  void _showListeningHistoryBottomSheet(
    BuildContext context,
    SongProvider provider,
  ) {
    CustomBottomSheet.showContent(
      context: context,
      child: Column(
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
          Text(
            'Dinleme Geçmişi',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (provider.recentlyPlayed.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                "Henüz bir şarkı dinlenmedi.",
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: provider.recentlyPlayed.length,
                itemBuilder: (context, index) {
                  final song = provider.recentlyPlayed[index];
                  final listenedSeconds = provider.getSongListeningSeconds(
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
                      child: Image.network(
                        song.coverUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          width: 40,
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
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    trailing: Text(
                      durationString,
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showMostPlayedBottomSheet(BuildContext context, SongProvider provider) {
    CustomBottomSheet.showContent(
      context: context,
      child: Column(
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
          Text(
            'En Çok Dinlenenler',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (provider.mostPlayed.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                "Henüz yeterli veri yok.",
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: provider.mostPlayed.length,
                itemBuilder: (context, index) {
                  final song = provider.mostPlayed[index];
                  final playCount =
                      provider.mostPlayedData[index]['count'] as int;

                  if (index == 0) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: () {
                            provider.playSong(song, provider.mostPlayed);
                            Navigator.pop(context);
                            PlayerPage.show(context);
                          },
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.15),
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
                                  ).primaryColor.withOpacity(0.1),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child:
                                      song.localImagePath != null &&
                                          File(
                                            song.localImagePath!,
                                          ).existsSync()
                                      ? Image.file(
                                          File(song.localImagePath!),
                                          width: 70,
                                          height: 70,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.network(
                                          song.coverUrl,
                                          width: 70,
                                          height: 70,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) => Container(
                                            width: 70,
                                            height: 70,
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
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "EN ÇOK DİNLENEN",
                                        style: TextStyle(
                                          color: Theme.of(context).primaryColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        song.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        song.artist,
                                        maxLines: 1,
                                        style: TextStyle(
                                          color: Colors.grey.shade300,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  "$playCount Kez",
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
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
                      child:
                          song.localImagePath != null &&
                              File(song.localImagePath!).existsSync()
                          ? Image.file(
                              File(song.localImagePath!),
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            )
                          : Image.network(
                              song.coverUrl,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(
                                width: 40,
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
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    trailing: Text(
                      "$playCount Kez",
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      provider.playSong(song, provider.mostPlayed);
                      Navigator.pop(context);
                      PlayerPage.show(context);
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showFavoritesBottomSheet(BuildContext context, SongProvider provider) {
    CustomBottomSheet.showContent(
      context: context,
      child: Consumer<SongProvider>(
        builder: (context, songProvider, child) {
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
              Text(
                'Favoriler',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (songProvider.favoriteSongs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    "Henüz favori şarkınız yok.",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: songProvider.favoriteSongs.length,
                    itemBuilder: (context, index) {
                      final song = songProvider.favoriteSongs[index];
                      final duration = Duration(seconds: song.duration ?? 0);
                      final durationString =
                          "${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}";

                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child:
                              song.localImagePath != null &&
                                  File(song.localImagePath!).existsSync()
                              ? Image.file(
                                  File(song.localImagePath!),
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  song.coverUrl,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                    width: 40,
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
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              durationString,
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontSize: 12,
                              ),
                            ),
                            IconButton(
                              icon: CustomIcons.svgIcon(
                                CustomIcons.favorite,
                                color: Theme.of(context).primaryColor,
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
                            context,
                          ); // Şarkıyı açtığında bottomsheet'i kapatır
                          PlayerPage.show(context);
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  void _showFollowedArtistsBottomSheet(
    BuildContext context,
    SongProvider provider,
  ) {
    CustomBottomSheet.showContent(
      context: context,
      child: Consumer<SongProvider>(
        builder: (context, songProvider, child) {
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
              Text(
                'Takip Edilen Sanatçılar',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (songProvider.followedArtists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    "Henüz takip ettiğiniz bir sanatçı yok.",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: songProvider.followedArtists.length,
                    itemBuilder: (context, index) {
                      final artistName = songProvider.followedArtists[index];

                      return _FollowedArtistTile(
                        artistName: artistName,
                        songProvider: songProvider,
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
            ],
          );
        },
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
  String? _imageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchArtistImage();
  }

  Future<void> _fetchArtistImage() async {
    try {
      final results = await YoutubeService.searchSongs(
        widget.artistName,
        limit: 1,
      );
      if (mounted) {
        setState(() {
          _imageUrl = results.isNotEmpty
              ? results.first.coverUrl
              : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(widget.artistName)}&background=random&color=fff&size=100';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _imageUrl =
              'https://ui-avatars.com/api/?name=${Uri.encodeComponent(widget.artistName)}&background=random&color=fff&size=100';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _isLoading || _imageUrl == null
          ? const _ProfileShimmer(width: 40, height: 40, borderRadius: 20)
          : CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey.shade800,
              backgroundImage: NetworkImage(_imageUrl!),
              onBackgroundImageError: (_, __) {},
            ),
      title: _isLoading || _imageUrl == null
          ? const _ProfileShimmer(width: 100, height: 14, borderRadius: 4)
          : Text(
              widget.artistName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
      trailing: OutlinedButton(
        onPressed: () {
          widget.songProvider.toggleFollowArtist(widget.artistName);
        },
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Theme.of(context).primaryColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          minimumSize: const Size(0, 30),
        ),
        child: Text(
          "Takipten Çık",
          style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12),
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtistDetailPage(
              artistName: widget.artistName,
              songs: const [], // Sayfa kendi içerisinde yükleyecektir
            ),
          ),
        );
      },
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
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: const Icon(
            Icons.star_rounded,
            color: Colors.amber,
            size: 36,
            shadows: [
              Shadow(
                color: Colors.orangeAccent,
                blurRadius: 15,
                offset: Offset(0, 0),
              ),
            ],
          ),
        );
      },
    );
  }
}
