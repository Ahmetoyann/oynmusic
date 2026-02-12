import 'dart:ui';
import 'package:flutter/material.dart';
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
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:muzik_app/pages/login_page.dart';
import 'package:muzik_app/pages/player_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muzik_app/pages/splash_screen.dart';
import 'package:muzik_app/custom_icons.dart';

// Global Navigator Key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final GlobalKey<MainScreenState> mainScreenKey = GlobalKey<MainScreenState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: "youtubeapi.env");
  } catch (e) {
    debugPrint("Env dosyası yüklenemedi: $e");
  }
  try {
    await Firebase.initializeApp();
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
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.dark(
          primary: themeProvider.primaryColor,
          secondary: themeProvider.primaryColor,
          surface: Colors.grey.shade900,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black,
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

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final songProvider = context.watch<SongProvider>();

    // İnternet yoksa direkt İndirilenler sayfasına yönlendir
    if (!songProvider.hasConnection) {
      return const DownloadsPage();
    }

    // Oturum açılmışsa veya misafir ise Ana Ekrana git
    if (songProvider.isFirebaseLoggedIn || songProvider.isGuest) {
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

class MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  final List<Widget> _pages = <Widget>[
    TrendPage(),
    SearchPage(),
    FavoritesPage(),
    ListelerPage(),
  ];

  void switchToTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onItemTapped(int index) {
    debugPrint('BottomNav tapped: $index');
    setState(() => _selectedIndex = index);
  }

  Widget _buildActiveIcon(String svgIcon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
      ),
      child: CustomIcons.svgIcon(
        svgIcon,
        color: color, // Active color
        size: 24,
      ),
    );
  }

  Widget _buildActiveMaterialIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
      ),
      child: Icon(icon, color: color, size: 24),
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
      body: (!hasConnection && _selectedIndex != 3)
          ? _buildNoConnectionView()
          : IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PlayerPage()),
              );
            },
            child: const MiniPlayer(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 8, 48, 7),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  items: <BottomNavigationBarItem>[
                    BottomNavigationBarItem(
                      icon: CustomIcons.svgIcon(
                        CustomIcons.trending,
                        size: 24,
                        color: Colors.grey,
                      ),
                      activeIcon: _buildActiveIcon(
                        CustomIcons.trending,
                        primaryColor,
                      ),
                      label: 'Trendler',
                    ),
                    BottomNavigationBarItem(
                      icon: CustomIcons.svgIcon(
                        CustomIcons.search,
                        size: 24,
                        color: Colors.grey,
                      ),
                      activeIcon: _buildActiveIcon(
                        CustomIcons.search,
                        primaryColor,
                      ),
                      label: 'Ara',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(
                        Icons.favorite_border,
                        color: Colors.grey,
                        size: 24,
                      ),
                      activeIcon: _buildActiveMaterialIcon(
                        Icons.favorite,
                        primaryColor,
                      ),
                      label: 'Favoriler',
                    ),
                    BottomNavigationBarItem(
                      icon: CustomIcons.svgIcon(
                        CustomIcons.library,
                        size: 24,
                        color: Colors.grey,
                      ),
                      activeIcon: _buildActiveIcon(
                        CustomIcons.library,
                        primaryColor,
                      ),
                      label: 'Kitaplığım',
                    ),
                  ],
                  currentIndex: _selectedIndex,
                  onTap: _onItemTapped,
                  backgroundColor: Colors.black.withValues(alpha: 0.3),
                  selectedItemColor: primaryColor,
                  unselectedItemColor: Colors.grey,
                  selectedIconTheme: const IconThemeData(size: 24),
                  unselectedIconTheme: const IconThemeData(size: 24),
                  selectedFontSize: 1,
                  unselectedFontSize: 1,
                  showUnselectedLabels: false,
                  showSelectedLabels: false,
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoConnectionView() {
    return Container(
      width: double.infinity,
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              shape: BoxShape.circle,
            ),
            child: CustomIcons.svgIcon(
              CustomIcons.wifiOff,
              size: 60,
              color: Colors.grey.shade600,
            ),
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
          ElevatedButton.icon(
            onPressed: () {
              // Kitaplığım sekmesine geçiş yap
              setState(() {
                _selectedIndex = 3;
              });
            },
            icon: CustomIcons.svgIcon(
              CustomIcons.offline,
              size: 24,
              color: Colors.white,
            ),
            label: const Text("Kitaplığıma Git"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
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
  bool _isBottomSheetOpen = false;
  bool _userWantsOfflineMode = false;

  @override
  Widget build(BuildContext context) {
    // Provider'dan bağlantı durumunu dinle
    final hasConnection = context.select<SongProvider, bool>(
      (p) => p.hasConnection,
    );

    // Bağlantı yoksa ve sheet açık değilse ve kullanıcı offline modu seçmediyse aç
    if (!hasConnection && !_isBottomSheetOpen && !_userWantsOfflineMode) {
      _isBottomSheetOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNoConnectionSheet();
      });
    }
    // Bağlantı geldiyse ve sheet açıksa kapat
    else if (hasConnection && _isBottomSheetOpen) {
      _userWantsOfflineMode = false;
      _isBottomSheetOpen = false;
      if (navigatorKey.currentState?.canPop() ?? false) {
        navigatorKey.currentState?.pop();
      }

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
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    } else if (hasConnection) {
      // Bağlantı varsa offline modu sıfırla
      _userWantsOfflineMode = false;
    }

    return widget.child;
  }

  void _showNoConnectionSheet() {
    showModalBottomSheet(
      context: navigatorKey.currentContext!,
      isDismissible: false, // Kullanıcı dışarı basarak kapatamasın
      enableDrag: false,
      backgroundColor: Colors.grey.shade900.withOpacity(0.6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        // Geri tuşunu engellemek için PopScope
        return PopScope(
          canPop: false,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomIcons.svgIcon(
                  CustomIcons.wifiOff,
                  size: 60,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  "İnternet Bağlantısı Yok",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Çevrimdışı modda kitaplığınızdaki şarkıları dinleyebilirsiniz.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _userWantsOfflineMode = true;
                      });
                      Navigator.pop(ctx);
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
                      "Çevrimdışı Dinle",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      // Sheet kapandığında (örneğin bağlantı gelip pop yapıldığında)
      _isBottomSheetOpen = false;
    });
  }
}
