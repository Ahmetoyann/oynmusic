import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:muzik_app/pages/lists_page.dart';
import 'package:muzik_app/pages/search_page.dart';
import 'package:muzik_app/pages/trend_page.dart';
import 'package:muzik_app/pages/downloads_page.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/widgets/mini_player.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/pages/favorites_page.dart'; // TrendPage'deki import yapısına göre
import 'package:muzik_app/providers/theme_provider.dart';
import 'package:muzik_app/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:muzik_app/firebase_options.dart'; // Dosyayı import edin
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:muzik_app/pages/login_page.dart';
import 'package:muzik_app/pages/player_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muzik_app/pages/splash_screen.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/pages/onboarding_page.dart';
import 'package:muzik_app/pages/initial_artists_page.dart';
import 'package:permission_handler/permission_handler.dart';

// Global Navigator Key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final GlobalKey<MainScreenState> mainScreenKey = GlobalKey<MainScreenState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Durum çubuğu (şarj, saat vb.) görünür olsun ve arkaplanla uyumlu olsun
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF121212),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Hem üst durum çubuğunu hem de alt navigasyon tuşlarını gösterir
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  if (Platform.isAndroid || Platform.isIOS) {
    await MobileAds.instance.initialize();
  }
  try {
    await dotenv.load(fileName: "youtubeapi.env");
  } catch (e) {
    debugPrint("Env dosyası yüklenemedi: $e");
  }
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform, // Güncel ayarları kullan
    );
  } catch (e) {
    debugPrint("Firebase başlatılamadı: $e");
  }
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider(prefs)),
        ChangeNotifierProxyProvider<AuthProvider, SongProvider>(
          create: (context) => SongProvider(),
          update: (context, auth, songProvider) =>
              songProvider!..updateUser(auth.user),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'OYN',
      navigatorKey: navigatorKey, // Global key'i atıyoruz
      theme: ThemeData.dark().copyWith(
        textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme),
        primaryColor: themeProvider.primaryColor,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.dark(
          primary: themeProvider.primaryColor,
          secondary: themeProvider.primaryColor,
          surface: Colors.grey.shade900,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF121212),
          elevation: 0,
          titleTextStyle: GoogleFonts.montserrat(
            color: themeProvider.primaryColor,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
          iconTheme: IconThemeData(color: themeProvider.primaryColor),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade800,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          hintStyle: TextStyle(color: Colors.grey.shade400),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Colors.grey.shade900,
          contentTextStyle: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
          insetPadding: const EdgeInsets.all(16),
        ),
      ),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // ConnectionManager ile sarmalıyoruz
        final wrappedChild = CardTheme(
          color: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide.none,
          ),
          child: child!,
        );
        return ConnectionManager(child: wrappedChild);
      },
      home: const SplashScreen(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  bool? _seenOnboarding;
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkOnboarding();
    _requestPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama ayarlardan geri döndüğünde (Resumed) tetiklenir
    if (state == AppLifecycleState.resumed && _isDialogShowing) {
      _checkPermissionsStatus();
    }
  }

  Future<void> _requestPermissions() async {
    List<Permission> permissions = [];
    if (Platform.isAndroid) {
      permissions = [
        Permission.storage,
        Permission.audio,
        Permission.notification,
      ];
    } else if (Platform.isIOS) {
      // iOS için bildirim izni istenir (uygulamanızın özelliklerine göre eklenebilir)
      permissions = [Permission.notification];
    }

    if (permissions.isEmpty) return;

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    bool isPermanentlyDenied = false;
    statuses.forEach((permission, status) {
      // Android 13 ve üstü cihazlarda storage otomatik reddedilir. Eğer audio izni verildiyse bunu yoksayabiliriz.
      if (Platform.isAndroid &&
          permission == Permission.storage &&
          statuses[Permission.audio]?.isGranted == true) {
        return;
      }
      if (status.isPermanentlyDenied) {
        isPermanentlyDenied = true;
      }
    });

    if (isPermanentlyDenied && mounted && !_isDialogShowing) {
      _isDialogShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false, // Kullanıcı tıklayana kadar kapanmasın
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.grey.shade900,
            title: const Text(
              "İzin Gerekli",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              "Uygulamanın sorunsuz çalışabilmesi (şarkı indirme, arka planda çalma, bildirimler) için gerekli izinleri vermelisiniz. Lütfen uygulama ayarlarından izinleri etkinleştirin.",
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  "İptal",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor:
                      Theme.of(context).primaryColor.computeLuminance() > 0.5
                      ? Colors.black
                      : Colors.white,
                ),
                onPressed: () {
                  openAppSettings(); // Uygulama ayarlarına yönlendirir
                  // Dialog'u açık bırakıyoruz, ayarlardan dönünce lifecycle ile kapanacak
                },
                child: const Text("Ayarları Aç"),
              ),
            ],
          );
        },
      ).then((_) {
        _isDialogShowing = false;
      });
    }
  }

  Future<void> _checkPermissionsStatus() async {
    List<Permission> permissions = [];
    if (Platform.isAndroid) {
      permissions = [
        Permission.storage,
        Permission.audio,
        Permission.notification,
      ];
    } else if (Platform.isIOS) {
      permissions = [Permission.notification];
    }

    bool hasDenied = false;
    for (var p in permissions) {
      var status = await p.status;
      if (Platform.isAndroid &&
          p == Permission.storage &&
          await Permission.audio.status.isGranted) {
        continue;
      }
      // İzin kalıcı olarak reddedilmişse veya hala reddediliyorsa
      if (status.isPermanentlyDenied || status.isDenied) {
        hasDenied = true;
        break;
      }
    }

    // Eğer reddedilen bir izin kalmadıysa ve uyarı penceresi açıksa otomatik kapat
    if (!hasDenied && _isDialogShowing && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _seenOnboarding = prefs.getBool('seenOnboarding') ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_seenOnboarding == null)
      return const Scaffold(backgroundColor: Color(0xFF121212));

    if (!_seenOnboarding!) {
      return OnboardingPage(
        onCompleted: () {
          setState(() {
            _seenOnboarding = true;
          });
        },
      );
    }

    final songProvider = context.watch<SongProvider>();

    if (songProvider.isFirebaseLoggedIn) {
      if (songProvider.isSyncingUserData) {
        return const Scaffold(
          backgroundColor: Color(0xFF121212),
          body: Center(child: CircularProgressIndicator(color: Colors.white)),
        );
      }

      if (!songProvider.seenInitialArtists) {
        return InitialArtistsPage(onCompleted: () {});
      }
    }

    // Oturum açılmışsa (ve sanatçı seçimi görülmüşse/eşlenmişse) VEYA misafir ise Ana Ekrana git
    if ((songProvider.isFirebaseLoggedIn && songProvider.seenInitialArtists) ||
        songProvider.isGuest) {
      return MainScreen(key: mainScreenKey);
    }

    // Aksi halde Giriş Sayfasına git
    return const LoginPage();
  }
}

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isRetrying = false;
  bool _isBottomNavVisible = true;
  late AnimationController _navAnimController;
  late List<ScrollController> _scrollControllers;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _navAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );

    _scrollControllers = [
      ScrollController(),
      ScrollController(),
      ScrollController(),
      ScrollController(),
    ];

    _pages = [
      PrimaryScrollController(
        controller: _scrollControllers[0],
        child: TrendPage(),
      ),
      PrimaryScrollController(
        controller: _scrollControllers[1],
        child: SearchPage(),
      ),
      PrimaryScrollController(
        controller: _scrollControllers[2],
        child: FavoritesPage(),
      ),
      PrimaryScrollController(
        controller: _scrollControllers[3],
        child: ListelerPage(),
      ),
    ];
  }

  @override
  void dispose() {
    _navAnimController.dispose();
    for (var c in _scrollControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void switchToTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onItemTapped(int index) {
    debugPrint('BottomNav tapped: $index');
    if (_selectedIndex == index) {
      // Sayfa zaten aktifse pürüzsüz bir şekilde en tepeye kaydır
      if (_scrollControllers[index].hasClients) {
        _scrollControllers[index].animateTo(
          0.0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutQuart,
        );
      }
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  Widget _buildNavItem(
    int index,
    String label,
    String svgIcon,
    Color primaryColor,
  ) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? primaryColor : Colors.grey.withOpacity(0.6);

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuint,
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 16 : 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryColor.withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected
                    ? primaryColor.withOpacity(0.5)
                    : Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomIcons.svgIcon(svgIcon, color: color, size: 24),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final hasConnection = context.select<SongProvider, bool>(
      (p) => p.hasConnection,
    );

    return Scaffold(
      extendBody: true,
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          // Kullanıcı aşağı kaydırıyorsa gizle
          if (notification.direction == ScrollDirection.reverse) {
            if (_isBottomNavVisible) {
              setState(() => _isBottomNavVisible = false);
              _navAnimController.reverse();
            }
          }
          // Kullanıcı yukarı kaydırıyorsa göster
          else if (notification.direction == ScrollDirection.forward) {
            if (!_isBottomNavVisible) {
              setState(() => _isBottomNavVisible = true);
              _navAnimController.forward();
            }
          }
          return false;
        },
        child: (!hasConnection && _selectedIndex != 3)
            ? _buildNoConnectionView()
            : IndexedStack(index: _selectedIndex, children: _pages),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xFF121212),
              const Color(0xFF121212).withOpacity(0.9),
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
              SizeTransition(
                sizeFactor: CurvedAnimation(
                  parent: _navAnimController,
                  curve: Curves.easeInOut,
                ),
                axisAlignment: -1.0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    12, // SafeArea kullanıldığı için manuel bottom hesaplamasına gerek kalmadı
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(
                        0,
                        'Trendler',
                        CustomIcons.trending,
                        primaryColor,
                      ),
                      _buildNavItem(1, 'Ara', CustomIcons.search, primaryColor),
                      _buildNavItem(
                        2,
                        'Favoriler',
                        _selectedIndex == 2
                            ? CustomIcons.favorite
                            : CustomIcons.favoriteBorder,
                        primaryColor,
                      ),
                      _buildNavItem(
                        3,
                        'Kitaplığım',
                        CustomIcons.library,
                        primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoConnectionView() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF121212),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.wifi_off, size: 60, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          const Text(
            "İnternet Bağlantısı Yok",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Bu sayfaya erişmek için internet\nbağlantısı gereklidir.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
          const SizedBox(height: 32),
          if (_isRetrying)
            const CircularProgressIndicator()
          else
            Column(
              children: [
                OutlinedButton(
                  onPressed: () async {
                    setState(() {
                      _isRetrying = true;
                    });
                    await context
                        .read<SongProvider>()
                        .checkConnectionManually();
                    // Kullanıcıya işlem yapıldığını hissettirmek için kısa bir gecikme
                    await Future.delayed(const Duration(seconds: 1));
                    if (mounted) {
                      setState(() {
                        _isRetrying = false;
                      });
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey.shade600),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Tekrar Dene",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DownloadsPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor:
                        Theme.of(context).primaryColor.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Çevrimdışı Dinle",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// İnternet bağlantısını dinleyen ve BottomSheet gösteren widget
class ConnectionManager extends StatefulWidget {
  final Widget child;
  const ConnectionManager({super.key, required this.child});

  @override
  State<ConnectionManager> createState() => _ConnectionManagerState();
}

class _ConnectionManagerState extends State<ConnectionManager> {
  bool _wasDisconnected = false;

  @override
  Widget build(BuildContext context) {
    // Provider'dan bağlantı durumunu dinle
    final hasConnection = context.select<SongProvider, bool>(
      (p) => p.hasConnection,
    );

    if (!hasConnection) {
      _wasDisconnected = true;
    } else if (hasConnection && _wasDisconnected) {
      _wasDisconnected = false;
      // Bağlantı geri geldiğinde modern snackbar göster
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  CustomIcons.svgIcon(
                    CustomIcons.wifi,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Bağlantı sağlandı",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade700,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    }

    return widget.child;
  }
}
