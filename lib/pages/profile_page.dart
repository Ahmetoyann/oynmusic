import 'dart:io';
import 'package:dio/dio.dart'; // Dio paketini ekleyin
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:just_audio/just_audio.dart';
import 'package:muzik_app/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/pages/folder_detail_page.dart';
import 'package:muzik_app/pages/favorites_page.dart';
import 'package:muzik_app/widgets/google_logo_painter.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:muzik_app/widgets/custom_app_bar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _controller;

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

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

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
        const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
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
    IconData icon,
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
              child: Icon(icon, color: color, size: 28),
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
    return Container(
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
                          colors: [Colors.grey.shade800, Colors.grey.shade900],
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
                    Icon(
                      Icons.history_rounded,
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
    );
  }

  Widget _buildUserStats(BuildContext context, SongProvider songProvider) {
    final favoriteCount = songProvider.favoriteSongs.length;

    // Toplam dinleme süresi (Recently Played üzerinden tahmini)
    final totalSeconds = songProvider.recentlyPlayed.fold<int>(
      0,
      (sum, song) => sum + (song.duration ?? 0),
    );

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
                  Icons.favorite_rounded,
                  Colors.pinkAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FavoritesPage(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModernStatCard(
                  context,
                  "Dinleme Süresi",
                  timeString,
                  Icons.timer_rounded,
                  Colors.orangeAccent,
                  onTap: () =>
                      _showListeningHistoryBottomSheet(context, songProvider),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                      gradient: playing
                          ? SweepGradient(
                              colors: [
                                Colors.transparent,
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
                  radius: 50,
                  backgroundImage: user.photoURL != null
                      ? (user.photoURL!.startsWith('http')
                                ? NetworkImage(user.photoURL!)
                                : FileImage(File(user.photoURL!)))
                            as ImageProvider
                      : null,
                  backgroundColor: Colors.grey.shade800,
                  child: user.photoURL == null
                      ? const Icon(Icons.person, size: 50, color: Colors.grey)
                      : null,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  user.displayName ?? "Kullanıcı",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  user.email ?? "",
                  style: TextStyle(color: Colors.grey.shade400),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _showEditProfileBottomSheet(
                    context,
                    provider,
                    user.displayName,
                    user.photoURL,
                  ),
                  icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                  label: const Text(
                    "Profili Düzenle",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
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
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
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
                const Icon(Icons.logout, color: Colors.redAccent),
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
                          image: selectedImagePath != null
                              ? DecorationImage(
                                  image: FileImage(File(selectedImagePath!)),
                                  fit: BoxFit.cover,
                                )
                              : (currentPhotoUrl != null
                                    ? DecorationImage(
                                        image:
                                            currentPhotoUrl.startsWith('http')
                                            ? NetworkImage(currentPhotoUrl)
                                            : FileImage(File(currentPhotoUrl))
                                                  as ImageProvider,
                                        fit: BoxFit.cover,
                                      )
                                    : null),
                        ),
                        child:
                            (selectedImagePath == null &&
                                currentPhotoUrl == null)
                            ? const Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.grey,
                              )
                            : null,
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
                          child: const Icon(
                            Icons.camera_alt,
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
                child: ElevatedButton(
                  onPressed: () async {
                    // İsim alanı boşsa işlem yapma
                    if (controller.text.trim().isEmpty) return;

                    await provider.updateDisplayName(controller.text.trim());

                    if (selectedImagePath != null) {
                      if (context.mounted) {
                        CustomSnackBar.showInfo(
                          context: context,
                          message: "Profil resmi yükleniyor...",
                        );
                      }

                      // Resmi Cloudinary'e yükle
                      String? cloudUrl = await _uploadToCloudinary(
                        selectedImagePath!,
                      );

                      if (cloudUrl != null) {
                        // Gelen URL'i (http...) kaydet
                        await provider.user?.updatePhotoURL(cloudUrl);
                        if (context.mounted) setState(() {});
                      } else if (context.mounted) {
                        CustomSnackBar.showError(
                          context: context,
                          message: "Resim yüklenirken hata oluştu.",
                        );
                      }
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Kaydet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  final duration = Duration(seconds: song.duration ?? 0);
                  final durationString =
                      "${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}";

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
}
