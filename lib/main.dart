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

// Global Navigator Key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
      title: 'Müzik Çalar',
      navigatorKey: navigatorKey, // Global key'i atıyoruz
      theme: ThemeData.dark().copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        primaryColor: themeProvider.primaryColor,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.dark(
          primary: themeProvider.primaryColor,
          secondary: themeProvider.primaryColor,
          surface: Colors.grey.shade900,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
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
          color: Colors.grey.shade900.withOpacity(0.5),
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          child: child!,
        );
        return ConnectionManager(child: wrappedChild);
      },
      home: const AuthWrapper(),
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
      return const MainScreen(initialIndex: 3);
    }

    // Oturum açılmışsa veya misafir ise Ana Ekrana git
    if (songProvider.isFirebaseLoggedIn || songProvider.isGuest) {
      return const MainScreen();
    }

    // Aksi halde Giriş Sayfasına git
    return const LoginPage();
  }
}

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
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
    DownloadsPage(), // İndirilenler sayfası eklendi
    ListelerPage(),
  ];

  void _onItemTapped(int index) {
    debugPrint('BottomNav tapped: $index');
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _selectedIndex, children: _pages),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  items: const <BottomNavigationBarItem>[
                    BottomNavigationBarItem(
                      icon: Icon(Icons.trending_up),
                      label: 'Trendler',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.search),
                      label: 'Ara',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.favorite),
                      label: 'Favoriler',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.download_done),
                      label: 'İndirilenler',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.list_alt_rounded),
                      label: 'Listeler',
                    ),
                  ],
                  currentIndex: _selectedIndex,
                  onTap: _onItemTapped,
                  backgroundColor: Colors.grey.shade900.withOpacity(0.6),
                  selectedItemColor: Theme.of(context).primaryColor,
                  unselectedItemColor: Colors.grey,
                  selectedIconTheme: const IconThemeData(size: 32),
                  unselectedIconTheme: const IconThemeData(size: 24),
                  showUnselectedLabels: false,
                  elevation: 0,
                ),
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
                  const Icon(Icons.wifi, color: Colors.white),
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
      backgroundColor: Colors.grey.shade900,
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
                const Icon(
                  Icons.wifi_off_rounded,
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
                  "Müzik dinlemeye devam etmek için lütfen internet bağlantınızı kontrol edin.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Manuel kontrol tetikle
                      context.read<SongProvider>().checkConnectionManually();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Bağlantıyı Yeniden Dene",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _userWantsOfflineMode = true;
                    });
                    Navigator.pop(ctx);
                    navigatorKey.currentState?.push(
                      MaterialPageRoute(
                        builder: (context) => const DownloadsPage(),
                      ),
                    );
                  },
                  child: Text(
                    "İndirilenleri Dinle (Çevrimdışı)",
                    style: TextStyle(color: Colors.grey.shade400),
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
