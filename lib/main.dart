import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:muzik_app/pages/lists_page.dart';
import 'package:muzik_app/pages/search_page.dart';
import 'package:muzik_app/pages/trend_page.dart';
import 'package:muzik_app/pages/downloads_page.dart';
import 'package:muzik_app/pages/offline_downloads_page.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/widgets/mini_player.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/pages/favorites_page.dart'; // TrendPage'deki import yapısına göre
import 'package:muzik_app/providers/theme_provider.dart';
import 'package:muzik_app/providers/language_provider.dart';
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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';

// Global Navigator Key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final GlobalKey<MainScreenState> mainScreenKey = GlobalKey<MainScreenState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Arkaplanda gelen bildirim işlemleri
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Zaman dilimini (Timezone) başlatıyoruz (Planlanmış bildirimler için)
  tz.initializeTimeZones();
  try {
    final dynamic localTz = await FlutterTimezone.getLocalTimezone();
    // Eğer paket doğrudan String dönmüyorsa (yeni sürüm), TimezoneInfo nesnesinin içindeki 'name' değerini alıyoruz.
    final String timeZoneName = localTz is String ? localTz : localTz.name;
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  } catch (e) {
    debugPrint("Zaman dilimi alınamadı: $e");
  }

  // Hem üst durum çubuğunu hem de alt navigasyon tuşlarını gösterir
  // NOT: Android'de şeffaf olabilmesi için edgeToEdge modunun setSystemUIOverlayStyle'dan ÖNCE çağrılması gerekir!
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Durum çubuğu (şarj, saat vb.) görünür olsun ve arkaplanla uyumlu olsun
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
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
    // Arkaplan bildirim dinleyicisini kaydet
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase başlatılamadı: $e");
  }
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider(prefs)),
        ChangeNotifierProvider(create: (context) => LanguageProvider(prefs)),
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final languageProvider = context.watch<LanguageProvider>();

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
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
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
      supportedLocales: const [
        Locale('en'),
        Locale('tr'),
        Locale('fr'),
        Locale('de'),
        Locale('es'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: Locale(languageProvider.currentLanguage),
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
        return Directionality(
          textDirection:
              languageProvider.isRTL ? TextDirection.rtl : TextDirection.ltr,
          child: ConnectionManager(child: wrappedChild),
        );
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
    if (!kIsWeb) {
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
    }

    if (permissions.isEmpty) return;

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    bool isPermanentlyDenied = false;
    statuses.forEach((permission, status) {
      // Android 13 ve üstü cihazlarda storage otomatik reddedilir. Eğer audio izni verildiyse bunu yoksayabiliriz.
      if (!kIsWeb &&
          Platform.isAndroid &&
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
          final langProvider = context.read<LanguageProvider>();

          return AlertDialog(
            backgroundColor: Colors.grey.shade900,
            title: Text(
              langProvider.t('permission_required'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              langProvider.t('permission_desc'),
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  langProvider.t('cancel'),
                  style: const TextStyle(color: Colors.grey),
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
                child: Text(langProvider.t('open_settings')),
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
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        permissions = [
          Permission.storage,
          Permission.audio,
          Permission.notification,
        ];
      } else if (Platform.isIOS) {
        permissions = [Permission.notification];
      }
    }

    bool hasDenied = false;
    for (var p in permissions) {
      var status = await p.status;
      if (!kIsWeb &&
          Platform.isAndroid &&
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
      return const AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(backgroundColor: Color(0xFF121212)),
      );

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
        return const AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: Color(0xFF121212),
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
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

class MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late List<ScrollController> _scrollControllers;
  late List<Widget> _pages;
  Timer? _reviewTimer;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;

    _scrollControllers = [
      ScrollController(),
      ScrollController(),
      ScrollController(),
      ScrollController(),
    ];

    _pages = [
      PrimaryScrollController(
        controller: _scrollControllers[0],
        child: const TrendPage(),
      ),
      PrimaryScrollController(
        controller: _scrollControllers[1],
        child: const SearchPage(),
      ),
      PrimaryScrollController(
        controller: _scrollControllers[2],
        child: const DownloadsPage(),
      ),
      PrimaryScrollController(
        controller: _scrollControllers[3],
        child: const ListelerPage(),
      ),
    ];

    // Çerçeve çizimi (render) bittikten sonra güncelleme kontrolünü güvenle yapıyoruz (1. Madde)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdate();
    });

    _initReviewTimer();
  }

  Future<void> _initReviewTimer() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenReview = prefs.getBool('has_seen_review') ?? false;

    if (!hasSeenReview) {
      _reviewTimer = Timer(const Duration(minutes: 3), () {
        if (mounted) {
          _showReviewBottomSheet();
          prefs.setBool('has_seen_review', true);
        }
      });
    }
  }

  @override
  void dispose() {
    _reviewTimer?.cancel();
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
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  /// Firebase üzerinden güncelleme kontrolü yapar
  Future<void> _checkForUpdate() async {
    final langProvider = context.read<LanguageProvider>();
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: const Duration(
            seconds: 0,
          ), // Anında test edebilmek için 0 (Sıfır) yapıldı
        ),
      );

      await remoteConfig.fetchAndActivate();

      final latestVersion = remoteConfig.getString('latest_version');
      final forceUpdate = remoteConfig.getBool('force_update');
      final updateMessage = remoteConfig.getString('update_message');
      final storeUrl = remoteConfig.getString('store_url');

      if (latestVersion.isNotEmpty) {
        final currentParts =
            currentVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
        final latestParts =
            latestVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

        bool hasUpdate = false;
        for (int i = 0; i < latestParts.length; i++) {
          final c = i < currentParts.length ? currentParts[i] : 0;
          final l = latestParts[i];
          if (l > c) {
            hasUpdate = true;
            break;
          }
          if (l < c) break;
        }

        if (hasUpdate && mounted) {
          showDialog(
            context: context,
            barrierDismissible:
                !forceUpdate, // Zorunluysa dışarı tıklayarak kapatılamaz
            barrierColor: Colors.black.withOpacity(
              0.8,
            ), // Arka planı şık bir şekilde karartır
            builder: (context) => PopScope(
              canPop: !forceUpdate, // Zorunluysa geri tuşuyla da kapatılamaz
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.2),
                        blurRadius: 40,
                        spreadRadius: -10,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Modern İkon Başlığı
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.rocket_launch_rounded,
                          color: Theme.of(context).primaryColor,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Başlık
                      Text(
                        langProvider.t('new_version_ready'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Açıklama Metni
                      Text(
                        updateMessage.isNotEmpty
                            ? updateMessage
                            : langProvider.t('update_message_default'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Tam Genişlikte Güncelle Butonu
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Theme.of(
                                      context,
                                    ).primaryColor.computeLuminance() >
                                    0.5
                                ? Colors.black
                                : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 8,
                            shadowColor: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () async {
                            final url = storeUrl.isNotEmpty
                                ? storeUrl
                                : 'https://play.google.com/store/apps/details?id=com.ahmed.oyn_music';
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          child: Text(
                            langProvider.t('update_now'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // Daha Sonra Butonu (Zorunlu değilse)
                      if (!forceUpdate) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              langProvider.t('later'),
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
      }
    } catch (e) {
      debugPrint("Güncelleme kontrol hatası: $e");
    }
  }

  void _showReviewBottomSheet() {
    final langProvider = context.read<LanguageProvider>();
    int selectedStar = 0;
    bool showFeedbackForm = false;
    final TextEditingController feedbackController = TextEditingController();

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (pageContext, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Theme.of(pageContext).scaffoldBackgroundColor,
            body: SafeArea(
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  final primaryColor = Theme.of(context).primaryColor;

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
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                            left: 24,
                            right: 24,
                            top: 24,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.star_rounded,
                                  color: primaryColor,
                                  size: 48,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                langProvider.t('do_you_like_app'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                showFeedbackForm
                                    ? langProvider.t('help_us_improve')
                                    : langProvider.t('how_do_you_rate'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Yıldızlar
                              if (!showFeedbackForm)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(5, (index) {
                                    return GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          selectedStar = index + 1;
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4.0),
                                        child: Icon(
                                          index < selectedStar
                                              ? Icons.star_rounded
                                              : Icons.star_border_rounded,
                                          color: index < selectedStar
                                              ? Colors.amber
                                              : Colors.grey.shade600,
                                          size: 40,
                                        ),
                                      ),
                                    );
                                  }),
                                ),

                              // Düşük Puanda Çıkan Geri Bildirim Formu
                              if (showFeedbackForm)
                                TextField(
                                  controller: feedbackController,
                                  maxLines: 3,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText:
                                        langProvider.t('write_your_thoughts'),
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

                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: selectedStar > 0
                                        ? primaryColor
                                        : Colors.grey.shade800,
                                    foregroundColor:
                                        primaryColor.computeLuminance() > 0.5
                                            ? Colors.black
                                            : Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: selectedStar == 0
                                      ? null
                                      : () async {
                                          if (selectedStar >= 4) {
                                            Navigator.pop(pageContext);
                                            final url =
                                                'https://play.google.com/store/apps/details?id=com.ahmed.oyn_music';
                                            final uri = Uri.parse(url);
                                            if (await canLaunchUrl(uri)) {
                                              await launchUrl(uri,
                                                  mode: LaunchMode
                                                      .externalApplication);
                                            }
                                          } else {
                                            if (!showFeedbackForm) {
                                              setModalState(() =>
                                                  showFeedbackForm = true);
                                            } else {
                                              Navigator.pop(pageContext);
                                              CustomSnackBar.showSuccess(
                                                context: context,
                                                message: langProvider
                                                    .t('thanks_for_feedback'),
                                              );
                                            }
                                          }
                                        },
                                  child: Text(
                                    showFeedbackForm
                                        ? langProvider.t('send')
                                        : (selectedStar >= 4
                                            ? langProvider
                                                .t('rate_on_google_play')
                                            : langProvider.t('next')),
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () => Navigator.pop(pageContext),
                                child: Text(
                                  langProvider.t('later'),
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
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
                    ? primaryColor.withOpacity(0.3)
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
    final langProvider = context.watch<LanguageProvider>();

    // Eğer bağlantı yoksa YALNIZCA bu ekranı göster
    if (!hasConnection) {
      return const OfflineDownloadsPage(isDirectOffline: true);
    }

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xFF121212).withOpacity(
                1,
              ), // İçeriklerin arkadan flulaşarak görünmesi için şeffaflaştırıldı

              const Color(0xFF121212).withOpacity(0.7),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  8, // Menüyü biraz daha aşağı hizalamak için alt boşluk sıfırlandı
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(
                      0,
                      langProvider.t('trends'),
                      CustomIcons.trending,
                      primaryColor,
                    ),
                    _buildNavItem(
                      1,
                      langProvider.t('search'),
                      _selectedIndex == 1
                          ? CustomIcons.searchActive
                          : CustomIcons.search,
                      primaryColor,
                    ),
                    _buildNavItem(
                      2,
                      langProvider.t('downloads'),
                      _selectedIndex == 2
                          ? CustomIcons.downloadingRounded
                          : CustomIcons.downloadingRounded,
                      primaryColor,
                    ),
                    _buildNavItem(
                      3,
                      langProvider.t('library'),
                      CustomIcons.library,
                      primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
    final langProvider = context.watch<LanguageProvider>();

    if (!hasConnection) {
      _wasDisconnected = true;
    } else if (hasConnection && _wasDisconnected) {
      _wasDisconnected = false;
      // Bağlantı geri geldiğinde modern snackbar göster
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigatorKey.currentContext != null) {
          CustomSnackBar.showSuccess(
            context: navigatorKey.currentContext!,
            message: langProvider.t('connection_restored'),
          );
        }
      });
    }

    return widget.child;
  }
}
