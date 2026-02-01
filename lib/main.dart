import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:muzik_app/pages/listeler_page.dart';
import 'package:muzik_app/pages/search_page.dart';
import 'package:muzik_app/pages/trend_page.dart';
import 'package:muzik_app/pages/splash_screen.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/widgets/mini_player.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/favorites_page.dart'; // TrendPage'deki import yapısına göre
import 'package:muzik_app/providers/theme_provider.dart';
import 'package:muzik_app/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
      theme: themeProvider.isDarkMode
          ? ThemeData.dark().copyWith(
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
            )
          : ThemeData.light().copyWith(
              primaryColor: themeProvider.primaryColor,
              scaffoldBackgroundColor: Colors.grey.shade100,
              colorScheme: ColorScheme.light(
                primary: themeProvider.primaryColor,
                secondary: themeProvider.primaryColor,
                surface: Colors.white,
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: themeProvider.primaryColor,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
                titleTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                hintStyle: TextStyle(color: Colors.grey.shade600),
              ),
            ),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return CardTheme(
          color: themeProvider.isDarkMode
              ? Colors.grey.shade900.withOpacity(0.5)
              : Colors.white,
          elevation: themeProvider.isDarkMode ? 0 : 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = <Widget>[
    TrendPage(),
    SearchPage(),
    FavoritesPage(),
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
          const MiniPlayer(),
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
                      icon: Icon(Icons.list_alt_rounded),
                      label: 'Listeler',
                    ),
                  ],
                  currentIndex: _selectedIndex,
                  onTap: _onItemTapped,
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade900.withOpacity(0.6)
                      : Colors.white.withOpacity(0.9),
                  selectedItemColor: Theme.of(context).primaryColor,
                  unselectedItemColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey
                      : Colors.grey.shade600,
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
