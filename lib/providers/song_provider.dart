import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:muzik_app/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:muzik_app/services/audio_handler.dart';
import 'package:muzik_app/services/audius_service.dart'; // Dosya adı aynı kaldı ama sınıf YoutubeService oldu
import 'package:muzik_app/models/song_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'dart:isolate';
import 'dart:ui';
import 'package:muzik_app/providers/language_provider.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:muzik_app/services/interstitial_ad_manager.dart';

@pragma('vm:entry-point')
void backgroundNotificationHandler(NotificationResponse response) {
  final SendPort? sendPort = IsolateNameServer.lookupPortByName(
    'download_send_port',
  );
  if (sendPort != null) {
    sendPort.send({'actionId': response.actionId, 'payload': response.payload});
  }
}

class SongProvider with ChangeNotifier {
  List<Song> _allSongs = [];
  List<Song> _favoriteSongs = []; // Favori şarkı nesnelerini tutacak yeni liste
  User? _currentUser; // Giriş yapmış kullanıcı
  bool _isLocalFavoritesLoaded = false; // Yerel favorilerin yüklenme durumu
  bool _isLocalFoldersLoaded = false; // Yerel klasörlerin yüklenme durumu
  bool _isLoading = true;
  String? _errorMessage;
  String? _playbackError; // Oynatma hataları için özel değişken
  final List<MusicFolder> _folders = [];
  // AudioHandler referansı (Anında başlatılıyor ki arayüz hemen erişebilsin)
  final MyAudioHandler _audioHandler = MyAudioHandler();
  bool _isAudioServiceInitialized = false;
  List<Song> _playlist = [];
  int? _currentSongIndex;
  String _searchText = '';
  String? _currentGenre; // Şu anki kategoriyi tutar
  String?
  _currentTimeRange; // Şu anki zaman aralığını tutar (week, month, year, allTime)
  List<Song> _searchResults = [];
  bool _isSearchLoading = false;
  int _searchOffset = 0; // Arama sonuçları için sayfa takibi
  bool _isSearchLoadingMore = false; // Arama sonuçlarını yükleme durumu
  Timer? _searchDebounce;
  String _searchFilter = 'songs';
  bool _isLoadingMore = false; // Ekstra yükleme yapılıyor mu?
  List<Song> _recentlyPlayed = []; // Son dinlenenler listesi
  List<String> _searchHistory = [];
  String? _nextPageToken; // Sayfalama token'ı
  bool _isLowDataMode = false; // Düşük veri modu (Düşük kalite ses)
  bool _isSongLoading = false; // Şarkı hazırlanıyor mu?
  bool _isEqualizerEnabled = false; // Ekolayzer açık mı?
  List<double> _equalizerValues = [4.0, 1.0, -2.0, 2.0, 5.0]; // EQ değerleri
  String?
  _pendingSongId; // Yüklenmekte olan şarkının ID'si (Hızlı geçiş kontrolü)
  bool _hasConnection = true; // İnternet bağlantısı var mı?
  bool _isGuest = false; // Misafir girişi yapıldı mı?
  int _initialOffset = 0; // Trendler için rastgele başlangıç noktası
  List<Song> _dailySongs = []; // Günün şarkıları
  bool _isShuffleEnabled = false; // Karışık çalma durumu
  LoopMode _loopMode = LoopMode.off; // Tekrar modu (Kapalı, Tümü, Tek)
  List<int> _shuffledIndices = []; // Karışık çalma sırası
  List<Song> _suggestedSongs = []; // Arama sayfası için önerilen şarkılar
  List<Song> _suggestedArtists = []; // Sanatçılar sekmesi için
  List<Song> _suggestedAlbums = []; // Koleksiyonlar sekmesi için
  bool _isSuggestionsLoading = false; // Önerilerin yüklenme durumu
  List<String> _followedArtists = []; // Takip edilen sanatçılar

  bool _isSyncingUserData = false;
  bool _seenInitialArtists = false;

  // Reklam Yöneticisi ve Sayaçlar
  final InterstitialAdManager _interstitialAdManager = InterstitialAdManager();
  int _downloadAdCounter = 0;
  int _songPlayAdCounter = 0;
  Timer? _adTimer;
  bool _isAdPending = false; // Şarkı bölünmesin diye reklamı bekletir
  final Map<String, String> _artistAvatars =
      {}; // Sanatçı avatarlarını önbellekte tutar

  // Uyku Zamanlayıcısı
  Timer? _sleepTimer;
  DateTime? _sleepTimerEndTime;

  // Bildirim Plugin'i
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // İndirme İşlemleri İçin Değişkenler
  List<Song> _downloadedSongs = [];
  final Map<String, double?> _downloadProgress =
      {}; // Şarkı ID -> İlerleme (0.0 - 1.0)
  final Map<String, String> _downloadDetails =
      {}; // Şarkı ID -> İndirme Detayı (MB bilgisi)
  final Map<String, CancelToken> _downloadCancelTokens = {}; // İptal tokenları
  final Set<String> _cancelingDownloads = {}; // İptal edilmekte olan indirmeler
  final Set<String> _pausedDownloads = {}; // Duraklatılan indirmeler

  // Sık güncellenen (her %1) indirme durumu için ValueNotifier kullanarak UI'ın gereksiz yere tamamen baştan çizilmesini önleriz
  final Map<String, ValueNotifier<double?>> _downloadProgressNotifiers = {};
  final Map<String, ValueNotifier<String>> _downloadDetailsNotifiers = {};
  ValueNotifier<double?> getDownloadProgressNotifier(String id) {
    return _downloadProgressNotifiers.putIfAbsent(
      id,
      () => ValueNotifier(_downloadProgress[id]),
    );
  }

  ValueNotifier<String> getDownloadDetailsNotifier(String id) {
    return _downloadDetailsNotifiers.putIfAbsent(
      id,
      () => ValueNotifier(_downloadDetails[id] ?? ""),
    );
  }

  int _totalListeningSeconds = 0; // Gerçek toplam dinleme süresi (saniye)
  Map<String, int> _songListeningSeconds = {}; // Şarkı bazlı dinleme süresi
  Timer? _listeningTimer; // Dinleme süresini takip eden zamanlayıcı
  bool _wasPlayingBeforeInterruption = false; // Kesintiden önce çalıyor muydu?
  // YouTube algoritmasını her seferinde baştan çözmemek (15 sn hız kazanmak) için
  // sınıf seviyesinde kalıcı (persistent ve önbellekli) tek bir nesne kullanıyoruz.
  final YoutubeExplode _yt = YoutubeExplode();
  bool _isFading =
      false; // Sesin kısılarak azalma/artma animasyon durumunu tutar
  bool _isFadingOutAtEnd =
      false; // Şarkı bitmek üzereyken tetiklenip tetiklenmediğini tutar
  // Çözümlenmiş YouTube müzik linklerini RAM'de tutarak sıfır gecikme sağlar
  final Map<String, String> _resolvedStreamUrlCache = {};
  final Map<String, Future<String>> _resolvingTasks = {};
  // Başlangıçta boş kalmaması için varsayılan popüler kategorileri ekliyoruz.
  List<String> _categories = [
    'Hepsi',
    'Pop',
    'Rock',
    'Electronic',
    'Hip Hop',
    'Jazz',
    'Indie',
    'Classical',
    'Metal',
    'Soundtrack',
  ];

  List<Song> get allSongs => _allSongs;
  List<Song> get favoriteSongs =>
      _favoriteSongs; // Artık doğrudan favori listesini döndürüyoruz
  List<MusicFolder> get folders => _folders;
  List<Song> get downloadedSongs => _downloadedSongs;
  Map<String, double?> get downloadProgress => _downloadProgress;
  Map<String, String> get downloadDetails => _downloadDetails;
  bool isCanceling(String id) => _cancelingDownloads.contains(id);
  bool isPaused(String id) => _pausedDownloads.contains(id);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get playbackError => _playbackError;
  bool get isSearchLoading => _isSearchLoading;
  bool get isSearchLoadingMore => _isSearchLoadingMore;
  String get searchFilter => _searchFilter;
  bool get isLoadingMore => _isLoadingMore;
  List<String> get categories => _categories;
  List<String> get searchHistory => _searchHistory;
  List<Song> get recentlyPlayed => _recentlyPlayed;
  bool get isLowDataMode => _isLowDataMode;
  bool get isEqualizerEnabled => _isEqualizerEnabled;
  List<double> get equalizerValues => _equalizerValues;
  bool get isSongLoading => _isSongLoading;
  bool get hasConnection => _hasConnection;
  bool get isGuest => _isGuest;
  bool get isFirebaseLoggedIn => _currentUser != null;
  List<Song> get dailySongs => _dailySongs;
  bool get isShuffleEnabled => _isShuffleEnabled;
  LoopMode get loopMode => _loopMode;
  List<Song> get suggestedSongs => _suggestedSongs;
  List<Song> get suggestedArtists => _suggestedArtists;
  List<Song> get suggestedAlbums => _suggestedAlbums;
  bool get isSuggestionsLoading => _isSuggestionsLoading;
  List<String> get followedArtists => _followedArtists;
  String? getArtistAvatar(String artistName) => _artistAvatars[artistName];
  bool get isSyncingUserData => _isSyncingUserData;
  bool get seenInitialArtists => _seenInitialArtists;
  List<Song> get playlist => _playlist;
  int? get currentSongIndex => _currentSongIndex;
  int get totalListeningSeconds => _totalListeningSeconds;
  int getSongListeningSeconds(String songId) =>
      _songListeningSeconds[songId] ?? 0;

  List<Map<String, dynamic>> _mostPlayedData =
      []; // En çok dinlenenler ham verisi
  List<Song> get mostPlayed => _mostPlayedData
      .map((e) => Song.fromMap(e['song'] as Map<String, dynamic>))
      .toList();
  List<Map<String, dynamic>> get mostPlayedData =>
      _mostPlayedData; // Çalma sayılarını göstermek için dışarı açıyoruz

  bool get isSleepTimerActive => _sleepTimer != null && _sleepTimer!.isActive;
  DateTime? get sleepTimerEndTime => _sleepTimerEndTime;

  /// Şarkı geçişlerinde sesi yumuşatarak azaltır (Fade Out)
  Future<void> _fadeOut() async {
    if (!_isAudioServiceInitialized) return;
    _isFading = true;
    double startVolume = audioPlayer.volume;
    int steps = 15;
    int durationMs = 600;
    int stepDuration = durationMs ~/ steps;

    for (int i = steps; i >= 0; i--) {
      if (!_isFading) break; // İptal edilirse çık
      await audioPlayer.setVolume((i / steps) * startVolume);
      await Future.delayed(Duration(milliseconds: stepDuration));
    }
  }

  /// Yeni şarkı başladığında sesi yumuşatarak artırır (Fade In)
  Future<void> _fadeIn() async {
    if (!_isAudioServiceInitialized) return;
    _isFading = true;
    _isFadingOutAtEnd = false;
    await audioPlayer.setVolume(0.0);

    int steps = 15;
    int durationMs = 800;
    int stepDuration = durationMs ~/ steps;

    for (int i = 0; i <= steps; i++) {
      if (!_isFading) break; // İptal edilirse çık
      await audioPlayer.setVolume(i / steps);
      await Future.delayed(Duration(milliseconds: stepDuration));
    }

    if (_isFading) {
      await audioPlayer.setVolume(1.0);
      _isFading = false;
    }
  }

  Song? get currentSong {
    if (_currentSongIndex != null &&
        _currentSongIndex! >= 0 &&
        _currentSongIndex! < _playlist.length) {
      return _playlist[_currentSongIndex!];
    }
    return null;
  }

  // PlayerPage'in bozulmaması için handler içindeki player'ı dışarı açıyoruz
  AudioPlayer get audioPlayer => _audioHandler.audioPlayer;

  // Stream'leri handler üzerinden veya player üzerinden alabiliriz
  Stream<PlayerState> get playerStateStream =>
      _audioHandler.audioPlayer.playerStateStream;
  Stream<Duration?> get durationStream =>
      _audioHandler.audioPlayer.durationStream;
  Stream<Duration> get positionStream =>
      _audioHandler.audioPlayer.positionStream;

  List<Song> get searchedSongs {
    if (_searchText.isEmpty) {
      return [];
    }
    return _searchResults;
  }

  bool get isSearching => _searchText.isNotEmpty;

  SongProvider() {
    _loadFavorites(); // Uygulama açılışında favorileri yükle
    _loadFollowedArtists();
    _loadFolders();
    _loadSearchHistory();
    _loadRecentlyPlayed();
    fetchCategories();
    _loadMostPlayed(); // En çok dinlenenleri yükle
    _loadDailySongs(); // Günün şarkılarını (varsa) yükle
    _loadSettings();
    _initConnectivity();
    checkConnectionManually().then((_) {
      fetchSongsFromApi(); // İnternet durumu belli olduktan sonra çek
    });
    _initNotifications(); // Bildirim servisini başlat
    _scheduleRetentionNotification(); // Haftalık hatırlatıcı (Retention) başlat
    _scheduleDailyNotification(); // Günlük (Günün Şarkısı) hatırlatıcı başlat
    _scheduleEveningNotifications(); // Akşam hatırlatıcılarını başlat
    _startListeningTimer(); // Dinleme süresi takibini başlat

    // Geçiş reklamlarını yükle ve 10 dakikalık zamanlayıcıyı başlat
    _interstitialAdManager.loadAd();
    _startAdTimer();
  }

  void _startAdTimer() {
    _adTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      // Eğer şu an bir şarkı çalıyorsa reklamı hemen gösterme, sıraya al
      if (_isAudioServiceInitialized && audioPlayer.playing) {
        _isAdPending = true;
      } else {
        // Çalmıyorsa hemen göster
        _interstitialAdManager.showAdIfAvailable();
      }
    });
  }

  /// AuthProvider'dan kullanıcı bilgisini günceller
  void updateUser(User? user) {
    final bool wasGuest = _currentUser == null;
    final bool isLoggingIn = user != null && wasGuest;

    // Giriş yapılıyorsa mevcut (misafir) indirmelerini geçici olarak sakla
    List<Song> guestDownloads = [];
    if (isLoggingIn) {
      guestDownloads = List.from(_downloadedSongs);
    }

    final bool wasLoggedIn = _currentUser != null;
    _currentUser = user;
    final bool isLoggedIn = _currentUser != null;

    // Yeni kullanıcı için indirmeleri yükle
    _loadDownloadedSongs().then((_) {
      // Eğer yeni giriş yapıldıysa ve misafir indirmeleri varsa bunları hesaba birleştir
      if (isLoggingIn && guestDownloads.isNotEmpty) {
        bool changed = false;
        for (var song in guestDownloads) {
          if (!_downloadedSongs.any((s) => s.id == song.id)) {
            _downloadedSongs.add(song);
            changed = true;
          }
        }
        if (changed) {
          _saveDownloadedSongs(); // Birleşmiş listeyi kullanıcının alanına kaydet
          notifyListeners();
        }
      }
    });

    // Oturum durumu değiştiyse (Giriş yapıldı veya uygulama açılışında oturum yüklendi)
    if (isLoggedIn && !wasLoggedIn) {
      // Eğer başka bir kaynaktan veri çekilmiyorsa şarkıları çek
      if (_allSongs.isEmpty) {
        // fetchSongsFromApi(); // Zaten constructor'da çağrılıyor, gerekirse tekrar çağırılabilir
      }
      notifyListeners(); // AuthWrapper'ı tetikle
    } else if (!isLoggedIn && wasLoggedIn) {
      notifyListeners(); // Çıkış yapıldı
    }

    if (_currentUser != null) {
      // Sadece yeni bir giriş yapıldığında yükleme ekranı göster
      if (!wasLoggedIn) {
        _isSyncingUserData = true;
        Future.wait([
          _syncFavoritesWithFirestore(),
          _syncFoldersWithFirestore(),
          _syncSettingsWithFirestore(),
          _syncFollowedArtistsWithFirestore(),
        ]).timeout(const Duration(seconds: 5)).whenComplete(() {
          // Eğer 5 saniye içinde yanıt gelmezse sonsuz döngüden çık
          _isSyncingUserData = false;
          notifyListeners();
        });
      } else {
        _syncFavoritesWithFirestore();
        _syncFoldersWithFirestore();
        _syncSettingsWithFirestore();
        _syncFollowedArtistsWithFirestore();
      }
    } else {
      _seenInitialArtists = false;
      _isSyncingUserData = false;
    }
  }

  /// Misafir olarak devam et
  void continueAsGuest() {
    _isGuest = true;
    notifyListeners();
  }

  /// İnternet bağlantısını dinler
  void _initConnectivity() {
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      _checkConnection(results);
    });
  }

  /// Manuel bağlantı kontrolü
  Future<void> checkConnectionManually() async {
    final results = await Connectivity().checkConnectivity();
    _checkConnection(results);
  }

  /// Bildirim servisini başlatır
  void _initNotifications() async {
    // Android için varsayılan ikon (uygulama ikonu genellikle @mipmap/ic_launcher'dır)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    // Ana isolate'de bildirim eylemlerini dinlemek için port ayarı
    final receivePort = ReceivePort();
    IsolateNameServer.removePortNameMapping('download_send_port');
    IsolateNameServer.registerPortWithName(
      receivePort.sendPort,
      'download_send_port',
    );

    receivePort.listen((message) {
      if (message is Map) {
        final actionId = message['actionId'];
        final payload = message['payload'];
        if (payload != null && actionId != null) {
          try {
            final Map<String, dynamic> songMap = jsonDecode(payload);
            final song = Song.fromMap(songMap);

            if (actionId == 'pause') {
              pauseDownload(song);
            } else if (actionId == 'resume') {
              downloadSong(song);
            } else if (actionId == 'cancel') {
              cancelDownload(song.id);
            }
          } catch (e) {
            debugPrint("Bildirim eylemi hatası (Port): $e");
          }
        }
      }
    });

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          final payload = response.payload!;

          // Özel Hatırlatıcı Bildirimlere (Akşam, Günlük, Haftalık) tıklandıysa
          if (payload == 'evening_notification' ||
              payload == 'retention_notification' ||
              payload == 'daily_notification') {
            // Uygulama kapalıyken açılıyorsa verilerin yüklenmesi için kısa bir gecikme
            Future.delayed(const Duration(milliseconds: 800), () {
              if (navigatorKey.currentContext != null) {
                // Şarkı çalmadan sadece Ana Sayfaya (Trendler) yönlendiriyoruz.
                // 0: Trendler, 1: Arama, 2: Favoriler, 3: Kitaplık
                mainScreenKey.currentState?.switchToTab(0);
              }
            });
            return; // İndirme işlemlerine girmemesi için çık
          }

          // İndirme bildirimleri buton eylemleri (Duraklat, Devam Et, İptal)
          if (response.actionId != null) {
            try {
              final Map<String, dynamic> songMap = jsonDecode(
                response.payload!,
              );
              final song = Song.fromMap(songMap);

              if (response.actionId == 'pause') {
                pauseDownload(song);
              } else if (response.actionId == 'resume') {
                downloadSong(song);
              } else if (response.actionId == 'cancel') {
                cancelDownload(song.id);
              }
            } catch (e) {
              debugPrint("Bildirim eylemi hatası: $e");
            }
          }
        }
      },
      onDidReceiveBackgroundNotificationResponse: backgroundNotificationHandler,
    );

    // Android 13+ için bildirim izni iste
    _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  /// Dil değiştiğinde tüm planlı bildirimleri iptal edip yeni dilde tekrar kurar
  Future<void> rescheduleAllNotifications() async {
    try {
      await _notificationsPlugin.cancel(999); // Haftalık
      await _notificationsPlugin.cancel(998); // Günlük
      for (int i = 0; i < 7; i++) {
        await _notificationsPlugin.cancel(2000 + i); // Akşam
      }

      // Yeni dile göre tekrar planla
      await _scheduleRetentionNotification();
      await _scheduleDailyNotification();
      await _scheduleEveningNotifications();
    } catch (e) {
      debugPrint("Bildirimleri yeniden planlama hatası: $e");
    }
  }

  /// Kullanıcıyı uygulamaya geri çağırmak için periyodik hatırlatıcı kurar (Retention)
  Future<void> _scheduleRetentionNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('language_code') ?? 'en';

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'retention_channel', // Kanal ID
          'Haftalık Hatırlatmalar', // Kanal Adı
          channelDescription:
              'Uygulamaya geri dönmeniz için haftalık hatırlatmalar',
          importance: Importance.high,
          priority: Priority.high,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    final Map<String, String> titles = {
      'tr': 'OYN Music Seni Bekliyor! 🚀🎧',
      'fr': 'OYN Music vous attend ! 🚀🎧',
      'de': 'OYN Music wartet auf dich! 🚀🎧',
      'es': '¡OYN Music te espera! 🚀🎧',
      'ar': 'OYN Music بانتظارك! 🚀🎧',
    };

    final Map<String, String> bodies = {
      'tr':
          'Haftalık en çok dinlediğin şarkılar ve sana özel yeni keşifler hazır. Hemen dinlemeye başla!',
      'fr':
          'Vos chansons les plus écoutées et de nouvelles découvertes sont prêtes. Écoutez maintenant !',
      'de':
          'Deine meistgespielten Songs und neue Entdeckungen sind bereit. Jetzt anhören!',
      'es':
          'Tus canciones más escuchadas y nuevos descubrimientos están listos. ¡Escucha ahora!',
      'ar': 'أغانيك الأكثر استماعاً واكتشافات جديدة جاهزة. استمع الآن!',
    };

    try {
      // Her hafta tekrarlayan bir bildirim planlar
      await _notificationsPlugin.periodicallyShow(
        999, // Sabit Bildirim ID'si
        titles[lang] ?? 'OYN Music is Waiting for You! 🚀🎧',
        bodies[lang] ??
            'Your weekly most played songs and new discoveries are ready. Start listening now!',
        RepeatInterval.weekly, // Haftalık tekrar (daily de yapılabilir)
        platformChannelSpecifics,
        payload: 'retention_notification',
      );
    } catch (e) {
      debugPrint("Hatırlatıcı bildirim kurulamadı: $e");
    }
  }

  /// Kullanıcıyı her gün "Günün Şarkısı" için uygulamaya davet eder
  Future<void> _scheduleDailyNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('language_code') ?? 'en';

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'daily_channel', // Kanal ID
          'Günlük Hatırlatmalar', // Kanal Adı
          channelDescription: 'Günün şarkısı için günlük hatırlatmalar',
          importance: Importance.high,
          priority: Priority.high,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    final Map<String, String> titles = {
      'tr': 'Günün Şarkısı Hazır! 💎',
      'fr': 'La chanson du jour est prête ! 💎',
      'de': 'Song des Tages ist bereit! 💎',
      'es': '¡La canción del día está lista! 💎',
      'ar': 'أغنية اليوم جاهزة! 💎',
    };

    final Map<String, String> bodies = {
      'tr':
          'Bugün senin için seçtiğimiz harika şarkıyı keşfetmek için hemen dinle!',
      'fr':
          'Écoutez maintenant pour découvrir la superbe chanson choisie pour vous !',
      'de':
          'Hör jetzt rein und entdecke den tollen Song, den wir für dich ausgewählt haben!',
      'es':
          '¡Escucha ahora para descubrir la gran canción que elegimos para ti hoy!',
      'ar': 'استمع الآن لاكتشاف الأغنية الرائعة التي اخترناها لك اليوم!',
    };

    try {
      // Her gün tekrarlayan bir bildirim planlar
      await _notificationsPlugin.periodicallyShow(
        998, // Sabit Bildirim ID'si
        titles[lang] ?? 'Song of the Day is Ready! 💎',
        bodies[lang] ??
            'Listen now to discover the great song we picked for you today!',
        RepeatInterval.daily,
        platformChannelSpecifics,
        payload: 'daily_notification',
      );
    } catch (e) {
      debugPrint("Günlük bildirim kurulamadı: $e");
    }
  }

  /// Gelecek 7 gün için 18:00 - 22:00 saatleri arasında rastgele bildirimler planlar
  Future<void> _scheduleEveningNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('language_code') ?? 'en';
    final random = Random();

    final Map<String, List<String>> allMessages = {
      'tr': [
        "Akşam keyfi OYN Music'te! Favori şarkıların seni bekliyor. 🛋️",
        "Günün yorgunluğunu müzikle at. Hemen dinlemeye başla! 🍃",
        "İyi akşamlar! Senin için hazırladığımız mix'lere göz at. 🔮",
        "Müzik ruhun gıdasıdır. Akşam moduna uygun şarkılar burada. 🌙",
      ],
      'fr': [
        "Ambiance du soir sur OYN Music ! Vos chansons préférées attendent. 🛋️",
        "Soulagez le stress de la journée avec la musique. Écoutez maintenant ! 🍃",
        "Bonsoir ! Découvrez les mix que nous avons préparés pour vous. 🔮",
        "La musique nourrit l'âme. Les chansons pour le soir sont ici. 🌙",
      ],
      'de': [
        "Abendstimmung auf OYN Music! Deine Lieblingssongs warten. 🛋️",
        "Bau den Stress des Tages mit Musik ab. Jetzt anhören! 🍃",
        "Guten Abend! Schau dir die Mixe an, die wir für dich vorbereitet haben. 🔮",
        "Musik ist Balsam für die Seele. Abendsongs sind hier. 🌙",
      ],
      'es': [
        "¡Ambiente nocturno en OYN Music! Tus canciones favoritas te esperan. 🛋️",
        "Alivia el estrés del día con música. ¡Escucha ahora! 🍃",
        "¡Buenas noches! Mira las mezclas que preparamos para ti. 🔮",
        "La música alimenta el alma. Las canciones para la noche están aquí. 🌙",
      ],
      'ar': [
        "أجواء المساء على OYN Music! أغانيك المفضلة بانتظارك. 🛋️",
        "تخلص من ضغوط اليوم مع الموسيقى. استمع الآن! 🍃",
        "مساء الخير! تفقد المقاطع التي أعددناها لك. 🔮",
        "الموسيقى غذاء الروح. أغاني المساء هنا. 🌙",
      ],
    };

    final Map<String, String> titles = {
      'tr': 'İyi Akşamlar! 🌆',
      'fr': 'Bonsoir ! 🌆',
      'de': 'Guten Abend! 🌆',
      'es': '¡Buenas tardes! 🌆',
      'ar': 'مساء الخير! 🌆',
    };

    final messages =
        allMessages[lang] ??
        allMessages['en'] ??
        [
          "Evening vibes on OYN Music! Your favorite songs are waiting. 🛋️",
          "Relieve the day's stress with music. Start listening now! 🍃",
          "Good evening! Check out the mixes we prepared for you. 🔮",
          "Music is food for the soul. Evening mood songs are here. 🌙",
        ];
    final title = titles[lang] ?? 'Good Evening! 🌆';

    // Uygulama her açıldığında bu döngü çalışır ve bugünden itibaren 7 günlük planı tazeler
    for (int i = 0; i < 7; i++) {
      final now = tz.TZDateTime.now(tz.local);

      // Rastgele Saat (18, 19, 20 veya 21) ve Rastgele Dakika (0-59)
      final int randomHour = 18 + random.nextInt(4);
      final int randomMinute = random.nextInt(60);

      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        randomHour,
        randomMinute,
      ).add(Duration(days: i));

      // Eğer belirlenen gün ve saat şu anki zamandan gerideyse (örneğin bugün saat 23:00 ise) o günü atla
      if (scheduledDate.isBefore(now)) continue;

      final randomMessage = messages[random.nextInt(messages.length)];

      try {
        await _notificationsPlugin.zonedSchedule(
          2000 +
              i, // 2000, 2001.. Her gün için farklı ID atanır, eski planlar ezilir
          title,
          randomMessage,
          scheduledDate,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'evening_channel',
              'Akşam Hatırlatmaları',
              channelDescription: 'Akşam saatlerinde rastgele hatırlatmalar',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          // PİL DOSTU YAKLAŞIM: Cihaz uyku modundayken bile kısıtlamaları esneterek tetikler ama kesin milisaniye hassasiyeti istemediğimiz için pili sömürmez.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'evening_notification',
        );
      } catch (e) {
        debugPrint("Akşam bildirimi planlanamadı: $e");
      }
    }
  }

  Future<void> _loadDailySongs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? date = prefs.getString('daily_songs_date');
    final String today = DateTime.now().toIso8601String().substring(0, 10);

    if (date == today) {
      final String? jsonString = prefs.getString('daily_songs');
      if (jsonString != null) {
        try {
          final List<dynamic> jsonList = jsonDecode(jsonString);
          _dailySongs = jsonList.map((e) => Song.fromMap(e)).toList();
          notifyListeners();
        } catch (e) {}
      }
    }
  }

  Future<void> _saveDailySongs() async {
    final prefs = await SharedPreferences.getInstance();
    final String today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString('daily_songs_date', today);
    await prefs.setString(
      'daily_songs',
      jsonEncode(_dailySongs.map((s) => s.toJson()).toList()),
    );
  }

  void _checkConnection(List<ConnectivityResult> results) {
    bool isConnected = !results.contains(ConnectivityResult.none);

    if (_hasConnection != isConnected) {
      _hasConnection = isConnected;

      if (!_hasConnection) {
        // İnternet gitti.
        // Çalan şarkı yerel mi (indirilenlerde var mı) kontrol et
        bool isLocal = false;
        if (currentSong != null) {
          final downloadedSong = _downloadedSongs.firstWhere(
            (s) => s.id == currentSong!.id,
            orElse: () =>
                Song(id: '', title: '', artist: '', coverUrl: '', audioUrl: ''),
          );

          if (downloadedSong.id.isNotEmpty &&
              downloadedSong.localPath != null) {
            if (File(downloadedSong.localPath!).existsSync()) {
              isLocal = true;
            }
          }
        }

        // Eğer yerel değilse ve çalıyorsa durdur
        if (!isLocal && _isAudioServiceInitialized && audioPlayer.playing) {
          _wasPlayingBeforeInterruption = true;
          audioPlayer.pause();

          if (navigatorKey.currentContext != null) {
            final langProvider = Provider.of<LanguageProvider>(
              navigatorKey.currentContext!,
              listen: false,
            );
            CustomSnackBar.showError(
              context: navigatorKey.currentContext!,
              message: langProvider.t('playback_paused_offline'),
            );
          }
        }
      } else {
        // İnternet geldi: Kesintiden önce çalıyorsa devam et
        if (_isAudioServiceInitialized && _wasPlayingBeforeInterruption) {
          audioPlayer.play();
          _wasPlayingBeforeInterruption = false;
          if (navigatorKey.currentContext != null) {
            final langProvider = Provider.of<LanguageProvider>(
              navigatorKey.currentContext!,
              listen: false,
            );
            CustomSnackBar.showSuccess(
              context: navigatorKey.currentContext!,
              message: langProvider.t('playback_resumed_online'),
            );
          }
        }

        // İnternet geldiğinde verileri yenile (Eğer liste boşsa veya hata varsa)
        if (_allSongs.isEmpty || _errorMessage != null) {
          fetchSongsFromApi(genre: _currentGenre);
        }
      }
      notifyListeners();
    }
  }

  /// Firestore ile favorileri senkronize eder (Merge işlemi)
  Future<void> _syncFavoritesWithFirestore() async {
    if (_currentUser == null) return;

    // Yerel favorilerin yüklenmesini bekle
    while (!_isLocalFavoritesLoaded) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid);
      final docSnapshot = await userDoc.get();

      List<Song> cloudFavorites = [];
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        if (data.containsKey('favorites')) {
          final List<dynamic> favs = data['favorites'];
          cloudFavorites = favs.map((e) => Song.fromMap(e)).toList();
        }
      }

      // Merge: Yerel + Bulut (ID'ye göre benzersizleştirme)
      final Map<String, Song> mergedMap = {};

      // Önce yerel favorileri ekle
      for (var song in _favoriteSongs) {
        mergedMap[song.id] = song;
      }

      // Buluttaki favorileri ekle (Eğer yerelde yoksa eklenir)
      for (var song in cloudFavorites) {
        if (!mergedMap.containsKey(song.id)) {
          mergedMap[song.id] = song;
        }
      }

      _favoriteSongs = mergedMap.values.toList();

      // UI ve Yerel Hafızayı Güncelle
      await _saveFavoritesToLocal();
      notifyListeners();

      // Birleşmiş listeyi Firestore'a geri yaz
      await _updateFirestoreFavorites();
    } catch (e) {
      debugPrint("Firestore sync hatası: $e");
    }
  }

  /// Firestore ile klasörleri senkronize eder (Merge işlemi)
  Future<void> _syncFoldersWithFirestore() async {
    if (_currentUser == null) return;

    // Yerel klasörlerin yüklenmesini bekle
    while (!_isLocalFoldersLoaded) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid);
      final docSnapshot = await userDoc.get();

      List<MusicFolder> cloudFolders = [];
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        if (data.containsKey('folders')) {
          final List<dynamic> flds = data['folders'];
          cloudFolders = flds.map((e) => MusicFolder.fromJson(e)).toList();
        }
      }

      // Merge: Yerel + Bulut (İsme göre)
      final Map<String, MusicFolder> mergedMap = {};

      for (var folder in _folders) {
        mergedMap[folder.name] = folder;
      }

      for (var cFolder in cloudFolders) {
        if (mergedMap.containsKey(cFolder.name)) {
          final existingFolder = mergedMap[cFolder.name]!;
          final existingIds = existingFolder.songs.map((s) => s.id).toSet();
          for (var song in cFolder.songs) {
            if (!existingIds.contains(song.id)) {
              existingFolder.songs.add(song);
            }
          }
        } else {
          mergedMap[cFolder.name] = cFolder;
        }
      }

      _folders.clear();
      _folders.addAll(mergedMap.values);

      await _saveFolders(); // Yerel ve Bulut (saveFolders içinde çağrılırsa)
      notifyListeners();
    } catch (e) {
      debugPrint("Firestore folders sync hatası: $e");
    }
  }

  /// Firestore ile kullanıcı ayarlarını (Ekolayzer vb.) senkronize eder
  Future<void> _syncSettingsWithFirestore() async {
    if (_currentUser == null) return;
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        if (data.containsKey('equalizer')) {
          final eq = data['equalizer'];
          _isEqualizerEnabled = eq['enabled'] ?? false;
          _equalizerValues = List<double>.from(
            eq['values']?.map((e) => (e as num).toDouble()) ??
                [4.0, 1.0, -2.0, 2.0, 5.0],
          );
          await _saveSettingsToLocal();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Firestore ayar senkronizasyon hatası: $e");
    }
  }

  /// Firestore ile takip edilen sanatçıları senkronize eder
  Future<void> _syncFollowedArtistsWithFirestore() async {
    if (_currentUser == null) return;
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;

        bool cloudSeen = data['seenInitialArtists'] ?? false;
        if (data.containsKey('followedArtists') &&
            (data['followedArtists'] as List).isNotEmpty) {
          cloudSeen = true; // Geriye dönük uyumluluk
        }
        if (cloudSeen) {
          _seenInitialArtists = true;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('seenInitialArtists', true);
        }

        if (data.containsKey('followedArtists')) {
          final List<dynamic> cloudFollowed = data['followedArtists'];
          final Set<String> merged = {
            ..._followedArtists,
            ...cloudFollowed.map((e) => e.toString()),
          };
          _followedArtists = merged.toList();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList('followed_artists', _followedArtists);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Firestore takip senkronizasyon hatası: $e");
    }
  }

  /// Seçilen sanatçıları Firestore'a kaydeder (Dışarıdan erişim için)
  Future<void> saveFollowedArtistsToFirestore() async {
    await _updateFirestoreFollowedArtists();
  }

  /// Sanatçı seçimi ekranının görüldüğünü yerelde ve veritabanında kaydeder
  Future<void> markInitialArtistsSeen() async {
    _seenInitialArtists = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenInitialArtists', true);
    if (_currentUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .set({
              'seenInitialArtists': true,
              'followedArtists': _followedArtists,
            }, SetOptions(merge: true));
      } catch (e) {
        debugPrint("seenInitialArtists kaydetme hatası: $e");
      }
    }
    notifyListeners();
  }

  Future<void> _updateFirestoreFollowedArtists() async {
    if (_currentUser == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .set({'followedArtists': _followedArtists}, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Firestore takip güncelleme hatası: $e");
    }
  }

  Future<void> fetchSongsFromApi({
    String? genre,
    String? timeRange,
    bool forceRefresh = false,
  }) async {
    _currentGenre = genre;
    _currentTimeRange = timeRange;

    if (!_hasConnection) {
      _isLoading = false;
      _errorMessage = "İnternet bağlantısı yok";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _nextPageToken = null; // Token'ı sıfırla
    _errorMessage = null;

    // Her yenilemede farklı içerik için rastgele ofset (0-50 arası)
    _initialOffset = Random().nextInt(50);

    // Yeni bir tür seçildiyse listeyi temizle ki kullanıcı yükleniyor görsün
    if (genre != null || forceRefresh) _allSongs = [];
    notifyListeners();

    try {
      await _initAudioService();

      if (genre != null && genre != 'Hepsi') {
        // Audius API için tür eşleştirmesi (Mapping)
        String apiGenre = genre;
        if (genre == 'Hip Hop') apiGenre = 'Hip-Hop/Rap';

        final results = await YoutubeService.getTrendingSongs(
          genre: apiGenre,
          timeRange: _currentTimeRange,
          offset: _initialOffset,
        );
        _allSongs = results;
      } else {
        // Hepsi seçiliyse ve takip edilen sanatçı varsa onlardan birine göre öneri getir
        if (_followedArtists.isNotEmpty) {
          final randomArtist =
              _followedArtists[Random().nextInt(_followedArtists.length)];
          final results = await YoutubeService.searchSongs(
            '$randomArtist popüler şarkılar',
            offset: _initialOffset,
          );
          _allSongs = results;
        } else {
          // Default Trendler
          final results = await YoutubeService.getTrendingSongs(
            timeRange: _currentTimeRange,
            offset: _initialOffset,
          );
          _allSongs = results;
        }
      }
      _nextPageToken = null; // Audius basit endpoint'te sayfalama şimdilik yok

      // Günün şarkılarını belirle (Eğer liste boş değilse)
      if (_allSongs.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final String? date = prefs.getString('daily_songs_date');
        final String today = DateTime.now().toIso8601String().substring(0, 10);

        if (date != today || _dailySongs.isEmpty) {
          _dailySongs = List<Song>.from(_allSongs)..shuffle();
          _dailySongs = _dailySongs.take(10).toList();
          _saveDailySongs();
        }
      }
    } catch (e) {
      debugPrint("Şarkı çekme hatası: $e");
      _errorMessage =
          "Şarkılar yüklenemedi: ${e.toString().replaceAll('Exception:', '').trim()}";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Listenin sonuna gelindiğinde daha fazla şarkı yükler
  Future<void> loadMoreSongs() async {
    // Zaten yükleniyorsa veya arama yapılıyorsa işlem yapma
    if (_isLoadingMore || _isLoading || isSearching) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      List<Song> newSongs = [];
      // Mevcut şarkı sayısı offset olarak kullanılır
      int currentOffset = _initialOffset + _allSongs.length;

      if (_currentGenre != null && _currentGenre != 'Hepsi') {
        String apiGenre = _currentGenre!;
        if (_currentGenre == 'Hip Hop') apiGenre = 'Hip-Hop/Rap';

        newSongs = await YoutubeService.getTrendingSongs(
          genre: apiGenre,
          timeRange: _currentTimeRange,
          offset: currentOffset,
        );
      } else {
        if (_followedArtists.isNotEmpty) {
          final randomArtist =
              _followedArtists[Random().nextInt(_followedArtists.length)];
          newSongs = await YoutubeService.searchSongs(
            '$randomArtist popüler şarkılar',
            offset: currentOffset,
          );
        } else {
          newSongs = await YoutubeService.getTrendingSongs(
            timeRange: _currentTimeRange,
            offset: currentOffset,
          );
        }
      }

      if (newSongs.isNotEmpty) {
        _allSongs.addAll(newSongs);
      }
    } catch (e) {
      debugPrint("Daha fazla şarkı yüklenirken hata: $e");
      rethrow;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// API'den popüler kategorileri (etiketleri) çeker
  Future<void> fetchCategories() async {
    // Jamendo API kaldırıldığı için statik listeyi kullanıyoruz.
    // _categories listesi zaten sınıfın başında tanımlı.
    notifyListeners();
  }

  /// AudioService ve Handler'ı başlatır
  Future<void> _initAudioService() async {
    if (_isAudioServiceInitialized) return;
    _isAudioServiceInitialized = true;

    try {
      await AudioService.init(
        builder: () =>
            _audioHandler, // Yeni bir tane üretmek yerine halihazırda anında oluşturduğumuz objeyi veriyoruz
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.ahmed.oyn_music.channel.audio',
          androidNotificationChannelName: 'OYN Music',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidNotificationIcon: 'mipmap/ic_launcher',
        ),
      );

      // Şarkı bittiğinde otomatik geçiş
      _audioHandler.audioPlayer.playerStateStream.listen((state) {
        // Bekleyen bir reklam varsa ve şarkı durduysa veya bittiyse reklamı göster
        if (_isAdPending &&
            (state.processingState == ProcessingState.completed ||
                !state.playing)) {
          _interstitialAdManager.showAdIfAvailable();
          _isAdPending = false;
        }

        if (state.processingState == ProcessingState.completed) {
          playNext(userInitiated: false);
        }
      });

      // Bildirimden gelen Sonraki/Önceki komutlarını dinle
      _audioHandler.skipNextStream.listen((_) => playNext(userInitiated: true));
      _audioHandler.skipPrevStream.listen((_) => playPrevious());

      // Şarkının son 1.5 saniyesinde fade out (Sesi kısarak bitirme) başlatır
      _audioHandler.audioPlayer.positionStream.listen((position) {
        final duration = _audioHandler.audioPlayer.duration;
        if (duration != null && duration.inMilliseconds > 5000) {
          final remainingMs = duration.inMilliseconds - position.inMilliseconds;
          if (remainingMs <= 1500 &&
              remainingMs > 0 &&
              !_isFadingOutAtEnd &&
              _audioHandler.audioPlayer.playing) {
            _isFadingOutAtEnd = true;
            _fadeOut();
          } else if (remainingMs > 1500 && _isFadingOutAtEnd) {
            // Eğer kullanıcı şarkıyı geri sararsa fade out'u iptal et ve sesi geri aç
            _isFadingOutAtEnd = false;
            _isFading = false;
            _audioHandler.audioPlayer.setVolume(1.0);
          }
        }
      });
    } catch (e) {
      _isAudioServiceInitialized = false;
      rethrow;
    }
  }

  /// Favorileri yerel hafızadan yükler
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Favori şarkı nesnelerini yükle (JSON formatında saklıyoruz)
    final String? favsJson = prefs.getString('favorite_songs_objects');
    if (favsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(favsJson);
        _favoriteSongs = decoded.map((e) => Song.fromMap(e)).toList();
      } catch (e) {
        debugPrint("Favoriler yüklenirken hata: $e");
      }
    }

    // 2. Modeldeki statik ID listesini güncelle (UI'daki kalp ikonları için)
    final List<String> ids = _favoriteSongs.map((s) => s.id).toList();
    SongFavoriteStatus.loadFavorites(ids);

    _isLocalFavoritesLoaded = true;
    notifyListeners();
  }

  void toggleFavorite(Song song) async {
    // UI durumunu güncelle
    song.isFavorite = !song.isFavorite;

    // Listeyi güncelle
    if (song.isFavorite) {
      // Eğer listede yoksa ekle
      if (!_favoriteSongs.any((s) => s.id == song.id)) {
        song.dateAdded = DateTime.now();
        _favoriteSongs.add(song);
      }
    } else {
      // Listeden çıkar
      _favoriteSongs.removeWhere((s) => s.id == song.id);
    }

    notifyListeners();

    // Değişikliği yerel hafızaya kaydet
    await _saveFavoritesToLocal();

    // Eğer giriş yapılmışsa Firestore'u da güncelle
    if (_currentUser != null) {
      _updateFirestoreFavorites();
    }
  }

  /// Tüm favorileri temizler
  Future<void> clearAllFavorites() async {
    SongFavoriteStatus.clear();
    _favoriteSongs.clear();
    notifyListeners();
    await _saveFavoritesToLocal();
    if (_currentUser != null) {
      _updateFirestoreFavorites();
    }
  }

  /// Favorileri yerel hafızaya (SharedPreferences) kaydeder
  Future<void> _saveFavoritesToLocal() async {
    final prefs = await SharedPreferences.getInstance();

    // Şarkı nesnelerini JSON olarak kaydet
    final String encoded = jsonEncode(
      _favoriteSongs.map((s) => s.toJson()).toList(),
    );
    await prefs.setString('favorite_songs_objects', encoded);

    // ID listesini de yedek olarak veya diğer kontroller için güncelleyelim
    await prefs.setStringList(
      'favorite_songs',
      SongFavoriteStatus.getFavoriteIds(),
    );
  }

  /// Favorileri Firestore'a kaydeder
  Future<void> _updateFirestoreFavorites() async {
    if (_currentUser == null) return;
    try {
      // Yerel dosya yollarını temizleyerek sadece gerekli veriyi buluta gönderiyoruz.
      // Böylece uygulama silinip yüklendiğinde geçersiz dosya yolları sorun yaratmaz.
      final cleanFavorites = _favoriteSongs.map((s) {
        final Map<String, dynamic> json = Map<String, dynamic>.from(s.toJson());
        json.remove('localPath');
        json.remove('localImagePath');
        return json;
      }).toList();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .set({'favorites': cleanFavorites}, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Firestore güncelleme hatası: $e");
    }
  }

  /// Klasörleri Firestore'a kaydeder
  Future<void> _updateFirestoreFolders() async {
    if (_currentUser == null) return;
    try {
      // Klasörleri ve içindeki şarkıları temizleyerek kaydet
      final cleanFolders = _folders.map((f) {
        final Map<String, dynamic> folderJson = Map<String, dynamic>.from(
          f.toJson(),
        );

        // Klasör içindeki şarkıların yerel yollarını temizle
        if (folderJson['songs'] != null) {
          final List<dynamic> songsList = folderJson['songs'];
          folderJson['songs'] = songsList.map((s) {
            final Map<String, dynamic> songJson = Map<String, dynamic>.from(
              s as Map,
            );
            songJson.remove('localPath');
            songJson.remove('localImagePath');
            return songJson;
          }).toList();
        }
        // Özel kapak resmi yerel bir dosya olduğu için bulutta saklamıyoruz
        folderJson.remove('customImagePath');
        return folderJson;
      }).toList();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .set({'folders': cleanFolders}, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Firestore folders güncelleme hatası: $e");
    }
  }

  /// Önbellek boyutunu hesaplar (İndirilen dosyalar)
  Future<String> getCacheSize() async {
    int totalBytes = 0;
    try {
      for (var song in _downloadedSongs) {
        if (song.localPath != null) {
          final file = File(song.localPath!);
          if (await file.exists()) {
            totalBytes += await file.length();
          }
        }
        if (song.localImagePath != null) {
          final imgFile = File(song.localImagePath!);
          if (await imgFile.exists()) {
            totalBytes += await imgFile.length();
          }
        }
      }
    } catch (e) {
      debugPrint("Cache boyutu hesaplanırken hata: $e");
    }

    if (totalBytes < 1024) return "${totalBytes} B";
    if (totalBytes < 1024 * 1024)
      return "${(totalBytes / 1024).toStringAsFixed(1)} KB";
    return "${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  /// Tüm önbelleği (indirilenler ve favoriler) temizler
  Future<void> clearCache() async {
    try {
      // 1. İndirilenleri sil
      await deleteAllDownloadedSongs();

      // 2. Favorileri temizle (SharedPreferences)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('favorite_songs');
      await prefs.remove('favorite_songs_objects');

      // 3. Hafızadaki durumları sıfırla
      // SongDownloadStatus.clear(); // Artık kullanılmıyor
      SongFavoriteStatus.clear();
      _favoriteSongs.clear();

      notifyListeners();
    } catch (e) {
      debugPrint("Önbellek temizlenirken hata: $e");
      rethrow;
    }
  }

  /// YouTube API önbelleğini temizler ve verileri günceller
  Future<void> clearApiCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (String key in keys) {
      if (key.startsWith('yt_trending_') || key.startsWith('yt_search_')) {
        await prefs.remove(key);
      }
    }

    // Önbellek temizlendikten sonra şarkıları API'den taze olarak çek
    fetchSongsFromApi(genre: _currentGenre, timeRange: _currentTimeRange);
  }

  void createFolder({
    required String name,
    required List<Song> songs,
    bool isFromDownloads = false,
    String? customImagePath,
  }) {
    if (name.isNotEmpty) {
      final newFolder = MusicFolder(
        name: name,
        songs: List.from(songs),
        isFromDownloads: isFromDownloads,
        customImagePath: customImagePath,
      );
      _folders.add(newFolder);
      _saveFolders();
      notifyListeners();
    }
  }

  void renameFolder(MusicFolder folder, String newName) {
    folder.name = newName;
    _saveFolders();
    notifyListeners();
  }

  void updateFolderImage(MusicFolder folder, String? imagePath) {
    folder.customImagePath = imagePath;
    _saveFolders();
    notifyListeners();
  }

  void deleteFolder(MusicFolder folder) {
    _folders.remove(folder);
    _saveFolders();
    notifyListeners();
  }

  void removeSongFromFolder(MusicFolder folder, Song song) {
    folder.songs.remove(song);
    _saveFolders();
    notifyListeners();
  }

  void removeSongsFromFolder(MusicFolder folder, List<String> songIds) {
    folder.songs.removeWhere((s) => songIds.contains(s.id));
    _saveFolders();
    notifyListeners();
  }

  void addSongsToFolder(MusicFolder folder, List<Song> newSongs) {
    // ID'ye göre kontrol ederek mükerrer eklemeyi önleyelim
    final existingIds = folder.songs.map((s) => s.id).toSet();
    final songsToAdd = newSongs
        .where((s) => !existingIds.contains(s.id))
        .toList();

    if (songsToAdd.isNotEmpty) {
      folder.songs.addAll(songsToAdd);
      _saveFolders();
      notifyListeners();
    }
  }

  void reorderSongsInFolder(MusicFolder folder, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final Song item = folder.songs.removeAt(oldIndex);
    folder.songs.insert(newIndex, item);
    _saveFolders();
    notifyListeners();
  }

  /// Klasördeki şarkıları belirli bir kurala göre sıralar
  void sortFolderSongs(
    MusicFolder folder,
    int Function(Song a, Song b) compare,
  ) {
    folder.songs.sort(compare);
    _saveFolders();
    notifyListeners();
  }

  /// Oynatma hatasını temizler
  void clearPlaybackError() {
    _playbackError = null;
    notifyListeners();
  }

  /// Son dinlenenleri yükler
  Future<void> _loadRecentlyPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('recently_played');
    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _recentlyPlayed = jsonList.map((e) => Song.fromMap(e)).toList();
        notifyListeners();
      } catch (e) {
        debugPrint("Geçmiş yüklenirken hata: $e");
      }
    }
  }

  /// Şarkıyı son dinlenenlere ekler
  Future<void> _addToRecentlyPlayed(Song song) async {
    // Listede varsa çıkarıp başa ekle
    _recentlyPlayed.removeWhere((s) => s.id == song.id);
    song.lastPlayed = DateTime.now();
    _recentlyPlayed.insert(0, song);

    // Maksimum 20 şarkı tut
    if (_recentlyPlayed.length > 20) {
      _recentlyPlayed = _recentlyPlayed.sublist(0, 20);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(
      _recentlyPlayed.map((s) => s.toJson()).toList(),
    );
    await prefs.setString('recently_played', jsonString);
  }

  /// Son dinlenenler geçmişini temizler
  Future<void> clearRecentlyPlayed() async {
    _recentlyPlayed.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recently_played');
  }

  void updateSearchText(String text) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchText = text;

    if (text.isEmpty) {
      _searchResults = [];
      _isSearchLoading = false;
      notifyListeners();
      return;
    }

    _isSearchLoading = true;
    notifyListeners();

    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      // Arama yap
      searchSongs(text);
    });
  }

  /// Arama filtresini günceller ve gerekirse aramayı tetikler
  void setSearchFilter(String filter) {
    if (_searchFilter == filter) return;
    _searchFilter = filter;
    notifyListeners();
    if (_searchText.isNotEmpty) {
      searchSongs(_searchText);
    }
  }

  /// Şarkı araması yapar
  Future<void> searchSongs(String query) async {
    _isSearchLoading = true;
    _searchOffset = 0;
    _nextPageToken = null;
    notifyListeners();

    try {
      String finalQuery = query.trim();
      if (_searchFilter == 'artists') {
        if (!finalQuery.toLowerCase().contains('sanatçı') &&
            !finalQuery.toLowerCase().contains('artist')) {
          finalQuery = '$finalQuery sanatçı';
        }
      } else if (_searchFilter == 'collections') {
        if (!finalQuery.toLowerCase().contains('mix') &&
            !finalQuery.toLowerCase().contains('albüm')) {
          finalQuery = '$finalQuery mix';
        }
      }

      final results = await YoutubeService.searchSongs(finalQuery);

      // Koleksiyonlar sekmesindeysek; başlığında mix/albüm/set geçenleri en üste taşı (Filtre Detaylandırması)
      if (_searchFilter == 'collections') {
        results.sort((a, b) {
          final aTitle = a.title.toLowerCase();
          final bTitle = b.title.toLowerCase();
          final aIsMix =
              aTitle.contains('mix') ||
              aTitle.contains('albüm') ||
              aTitle.contains('album') ||
              aTitle.contains('playlist') ||
              aTitle.contains('set');
          final bIsMix =
              bTitle.contains('mix') ||
              bTitle.contains('albüm') ||
              bTitle.contains('album') ||
              bTitle.contains('playlist') ||
              bTitle.contains('set');
          if (aIsMix && !bIsMix) return -1;
          if (!aIsMix && bIsMix) return 1;
          return 0;
        });
      }
      _searchResults = results;
    } catch (e) {
      debugPrint("Arama hatası: $e");
      _searchResults = [];
    } finally {
      _isSearchLoading = false;
      notifyListeners();
    }
  }

  /// Sanatçı avatarını çeker ve önbelleğe kaydeder
  Future<void> fetchArtistAvatar(String artistName) async {
    // Eğer sanatçının avatarı önbellekte varsa ve varsayılan UI-Avatar değilse (yani daha önce gerçek resmi çekilmişse) tekrar çekme
    if (_artistAvatars.containsKey(artistName) &&
        _artistAvatars[artistName] != null &&
        !_artistAvatars[artistName]!.contains('ui-avatars.com')) {
      return;
    }

    _artistAvatars[artistName] =
        ''; // Aynı anda mükerrer istekleri engellemek için geçici boşluk

    try {
      // Sanatçının şarkısı üzerinden kanalının gerçek profil fotoğrafını çekiyoruz
      final searchResults = await _yt.search.search(artistName);
      if (searchResults.isNotEmpty) {
        final firstVideo = searchResults.first;
        final channel = await _yt.channels.get(firstVideo.channelId);
        _artistAvatars[artistName] = channel.logoUrl;
      } else {
        _artistAvatars[artistName] =
            'https://ui-avatars.com/api/?name=${Uri.encodeComponent(artistName)}&background=random&color=fff&size=200';
      }
      notifyListeners();
    } catch (e) {
      _artistAvatars[artistName] =
          'https://ui-avatars.com/api/?name=${Uri.encodeComponent(artistName)}&background=random&color=fff&size=200';
      notifyListeners();
    }
  }

  /// Arama sayfası için rastgele önerilen şarkıları çeker
  Future<void> fetchSuggestedSongs() async {
    if (_suggestedSongs.isNotEmpty) return; // Zaten yüklendiyse tekrar çekme

    _isSuggestionsLoading = true;
    notifyListeners();

    // Statik Top 10 Sanatçı (netd müzik vb. kanallar olmadan sadece sanatçılar)
    final List<String> topArtists = [
      'Semicenk',
      'Mabel Matiz',
      'Motive',
      'Sezen Aksu',
      'Dedublüman',
      'Emir Can İğrek',
      'Blok3',
      'Melike Şahin',
      'Lvbel C5',
      'Duman',
    ];

    _suggestedArtists = topArtists.asMap().entries.map((entry) {
      final name = entry.value;
      return Song(
        id: 'artist_${entry.key}',
        title: name,
        artist: name,
        coverUrl: '', // Yüklenirken shimmer görünmesi için boş bırakıyoruz
        audioUrl: '',
      );
    }).toList();

    // Statik Popüler Mix İsimleri (Gerçek YouTube mix'leri aranacak)
    final List<String> topMixes = [
      'Türkçe Pop Mix',
      'Semicenk Mix',
      'Sezen Aksu Mix',
      'Yabancı Hit Mix',
      'Arabesk Mix',
      '90lar Pop Mix',
      'Rap Mix',
      'Akustik Mix',
      'Slow Müzik Mix',
      'Yaz Şarkıları Mix',
    ];

    _suggestedAlbums = topMixes.asMap().entries.map((entry) {
      final mixName = entry.value;
      return Song(
        id: 'mix_${entry.key}',
        title: mixName,
        artist: 'YouTube Mix',
        coverUrl: '', // Yüklenirken shimmer görünmesi için boş bırakıyoruz
        audioUrl: '',
      );
    }).toList();

    try {
      final offset = Random().nextInt(100); // Rastgelelik için ofset

      if (_followedArtists.isNotEmpty) {
        final randomArtist =
            _followedArtists[Random().nextInt(_followedArtists.length)];
        final results = await YoutubeService.searchSongs(
          randomArtist,
          limit: 10,
          offset: 0,
        );
        _suggestedSongs = results;
      } else {
        final results = await YoutubeService.getTrendingSongs(
          limit: 10,
          offset: offset,
        );
        _suggestedSongs = results;
      }
    } catch (e) {
      debugPrint("Öneri şarkıları yüklenirken hata: $e");
    } finally {
      _isSuggestionsLoading = false;
      notifyListeners();
    }

    // API'den arkaplanda gerçek resimleri çek
    _fetchRealCoversForSuggestions(topArtists, topMixes);
  }

  Future<void> _fetchRealCoversForSuggestions(
    List<String> artists,
    List<String> mixes,
  ) async {
    // Sanatçı resimlerini ağı tıkamamak için sırayla (sequential) çekiyoruz.
    // Böylece 20 istek aynı anda kilitlenmez, resimler bulundukça tek tek anında ekrana düşer.
    for (int i = 0; i < artists.length; i++) {
      final String artistName = artists[i];
      try {
        // Gerçek Youtube kanal resmini çekiyoruz
        final searchResults = await _yt.search.search(artistName);
        String realCover =
            'https://ui-avatars.com/api/?name=${Uri.encodeComponent(artistName)}&background=random&color=fff&size=200';
        if (searchResults.isNotEmpty) {
          final firstVideo = searchResults.first;
          final channel = await _yt.channels.get(firstVideo.channelId);
          realCover = channel.logoUrl;
          _artistAvatars[artistName] =
              realCover; // Önbelleğe de atalım ki diğer sayfalarda da anında dolsun
        }

        _suggestedArtists[i] = Song(
          id: _suggestedArtists[i].id,
          title: _suggestedArtists[i].title,
          artist: _suggestedArtists[i].artist,
          coverUrl: realCover,
          audioUrl: '',
        );
        notifyListeners();
      } catch (_) {
        _suggestedArtists[i] = Song(
          id: _suggestedArtists[i].id,
          title: _suggestedArtists[i].title,
          artist: _suggestedArtists[i].artist,
          coverUrl:
              'https://ui-avatars.com/api/?name=${Uri.encodeComponent(artistName)}&background=random&color=fff&size=200',
          audioUrl: '',
        );
        notifyListeners();
      }
    }

    // Mix resimlerini ve gerçek video verilerini sırayla çekiyoruz
    for (int i = 0; i < mixes.length; i++) {
      final String mixName = mixes[i];
      try {
        final results = await YoutubeService.searchSongs(mixName, limit: 1);
        if (results.isNotEmpty) {
          final realMix = results.first;
          _suggestedAlbums[i] = Song(
            id: realMix.id, // Gerçek YouTube ID'si
            title: mixName,
            artist: realMix.artist,
            coverUrl: realMix.coverUrl,
            audioUrl: realMix.audioUrl,
            duration: realMix.duration,
          );
        } else {
          _suggestedAlbums[i] = Song(
            id: _suggestedAlbums[i].id,
            title: mixName,
            artist: 'YouTube Mix',
            coverUrl:
                'https://ui-avatars.com/api/?name=${Uri.encodeComponent(mixName)}&background=random&color=fff&size=200',
            audioUrl: '',
          );
        }
        notifyListeners();
      } catch (_) {
        _suggestedAlbums[i] = Song(
          id: _suggestedAlbums[i].id,
          title: mixName,
          artist: 'YouTube Mix',
          coverUrl:
              'https://ui-avatars.com/api/?name=${Uri.encodeComponent(mixName)}&background=random&color=fff&size=200',
          audioUrl: '',
        );
        notifyListeners();
      }
    }
  }

  /// Arama sonuçlarının devamını yükler (Sonsuz Kaydırma)
  Future<void> loadMoreSearchResults() async {
    if (_isSearchLoadingMore || _isSearchLoading || _searchText.isEmpty) return;

    _isSearchLoadingMore = true;
    notifyListeners();

    try {
      int currentOffset = _searchResults.length;

      String finalQuery = _searchText.trim();
      if (_searchFilter == 'artists') {
        if (!finalQuery.toLowerCase().contains('sanatçı') &&
            !finalQuery.toLowerCase().contains('artist')) {
          finalQuery = '$finalQuery sanatçı';
        }
      } else if (_searchFilter == 'collections') {
        if (!finalQuery.toLowerCase().contains('mix') &&
            !finalQuery.toLowerCase().contains('albüm')) {
          finalQuery = '$finalQuery mix';
        }
      }

      final results = await YoutubeService.searchSongs(
        finalQuery,
        offset: currentOffset,
      );

      if (results.isNotEmpty) {
        if (_searchFilter == 'collections') {
          results.sort((a, b) {
            final aTitle = a.title.toLowerCase();
            final bTitle = b.title.toLowerCase();
            final aIsMix =
                aTitle.contains('mix') ||
                aTitle.contains('albüm') ||
                aTitle.contains('album') ||
                aTitle.contains('playlist') ||
                aTitle.contains('set');
            final bIsMix =
                bTitle.contains('mix') ||
                bTitle.contains('albüm') ||
                bTitle.contains('album') ||
                bTitle.contains('playlist') ||
                bTitle.contains('set');
            if (aIsMix && !bIsMix) return -1;
            if (!aIsMix && bIsMix) return 1;
            return 0;
          });
        }
        _searchResults.addAll(results);
      }
    } catch (e) {
      debugPrint("Daha fazla sonuç yüklenirken hata: $e");
      rethrow;
    } finally {
      _isSearchLoadingMore = false;
      notifyListeners();
    }
  }

  /// Arama geçmişini yükler
  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _searchHistory = prefs.getStringList('search_history') ?? [];
    notifyListeners();
  }

  /// Arama geçmişine ekler
  Future<void> addToSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    final cleanQuery = query.trim();

    // Varsa çıkarıp en başa ekleyelim (son aranan üstte olsun)
    if (_searchHistory.contains(cleanQuery)) {
      _searchHistory.remove(cleanQuery);
    }
    _searchHistory.insert(0, cleanQuery);

    // Maksimum 10 kayıt tutalım
    if (_searchHistory.length > 10) {
      _searchHistory = _searchHistory.sublist(0, 10);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search_history', _searchHistory);
  }

  Future<void> removeFromSearchHistory(String query) async {
    _searchHistory.remove(query);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search_history', _searchHistory);
  }

  Future<void> clearSearchHistory() async {
    _searchHistory.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_history');
  }

  /// En çok dinlenenleri yerel hafızadan yükler
  Future<void> _loadMostPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('most_played');
    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _mostPlayedData = jsonList
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        notifyListeners();
      } catch (e) {
        debugPrint("En çok dinlenenler yüklenirken hata: $e");
      }
    }
  }

  /// En çok dinlenenleri kaydeder
  Future<void> _saveMostPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(_mostPlayedData);
    await prefs.setString('most_played', jsonString);
  }

  /// Şarkıyı en çok dinlenenlere ekler ve dinleme sayacını günceller
  void _addToMostPlayed(Song song) {
    final index = _mostPlayedData.indexWhere((e) {
      final s = e['song'] as Map<String, dynamic>;
      return s['id'] == song.id;
    });

    if (index != -1) {
      _mostPlayedData[index]['count'] =
          (_mostPlayedData[index]['count'] as int) + 1;
      _mostPlayedData[index]['song'] = song
          .toJson(); // Şarkı verisini her ihtimale karşı güncelle
    } else {
      _mostPlayedData.add({'song': song.toJson(), 'count': 1});
    }

    // Dinlenme sayısına (count) göre büyükten küçüğe doğru sırala
    _mostPlayedData.sort(
      (a, b) => (b['count'] as int).compareTo(a['count'] as int),
    );

    // Sadece en çok dinlenen Top 50 şarkıyı tut (Hafızayı şişirmemek için)
    if (_mostPlayedData.length > 50) {
      _mostPlayedData = _mostPlayedData.sublist(0, 50);
    }
    notifyListeners();
    _saveMostPlayed();
  }

  /// Ayarları yükler
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isLowDataMode = prefs.getBool('low_data_mode') ?? false;
    _totalListeningSeconds = prefs.getInt('total_listening_seconds') ?? 0;
    _seenInitialArtists = prefs.getBool('seenInitialArtists') ?? false;

    final String? songSecondsJson = prefs.getString('song_listening_seconds');
    if (songSecondsJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(songSecondsJson);
        _songListeningSeconds = decoded.map(
          (key, value) => MapEntry(key, value as int),
        );
      } catch (e) {
        debugPrint("Şarkı süreleri yüklenirken hata: $e");
      }
    }

    _isEqualizerEnabled = prefs.getBool('eq_enabled') ?? false;
    final String? eqValuesJson = prefs.getString('eq_values');
    if (eqValuesJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(eqValuesJson);
        _equalizerValues = decoded.map((e) => (e as num).toDouble()).toList();
      } catch (e) {
        debugPrint("EQ ayarları yüklenirken hata: $e");
      }
    }

    notifyListeners();
  }

  /// Gerçek dinleme süresini takip etmek için sayacı başlatır
  void _startListeningTimer() {
    _listeningTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isAudioServiceInitialized && audioPlayer.playing) {
        _totalListeningSeconds++;

        if (currentSong != null) {
          _songListeningSeconds[currentSong!.id] =
              (_songListeningSeconds[currentSong!.id] ?? 0) + 1;
        }

        // Her 10 saniyede bir UI'ı güncelle ve kaydet (performans için arka planda yormaz)
        if (_totalListeningSeconds % 10 == 0) {
          SharedPreferences.getInstance().then((prefs) {
            prefs.setInt('total_listening_seconds', _totalListeningSeconds);
            prefs.setString(
              'song_listening_seconds',
              jsonEncode(_songListeningSeconds),
            );
          });
        }
      }
    });
  }

  /// Düşük veri modunu değiştirir
  Future<void> toggleLowDataMode(bool enable) async {
    _isLowDataMode = enable;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('low_data_mode', enable);
  }

  /// Ekolayzer ayarlarını günceller
  Future<void> updateEqualizerSettings(
    bool enabled,
    List<double> values,
  ) async {
    _isEqualizerEnabled = enabled;
    _equalizerValues = List.from(values);
    notifyListeners();

    await _saveSettingsToLocal();
    _updateFirestoreEqualizer();
  }

  Future<void> _saveSettingsToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('eq_enabled', _isEqualizerEnabled);
    await prefs.setString('eq_values', jsonEncode(_equalizerValues));
  }

  Future<void> _loadFollowedArtists() async {
    final prefs = await SharedPreferences.getInstance();
    _followedArtists = prefs.getStringList('followed_artists') ?? [];
    notifyListeners();
  }

  bool isArtistFollowed(String name) => _followedArtists.contains(name);

  Future<void> toggleFollowArtist(
    String artistName, {
    bool syncToFirestore = true,
  }) async {
    if (_followedArtists.contains(artistName)) {
      _followedArtists.remove(artistName);
    } else {
      _followedArtists.add(artistName);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('followed_artists', _followedArtists);

    if (_currentUser != null && syncToFirestore) {
      _updateFirestoreFollowedArtists();
    }
    _suggestedSongs.clear(); // Arama sayfası önerileri sıfırlansın
  }

  /// Ekolayzer ayarlarını Firestore'a kaydeder
  Future<void> _updateFirestoreEqualizer() async {
    if (_currentUser == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .set({
            'equalizer': {
              'enabled': _isEqualizerEnabled,
              'values': _equalizerValues,
            },
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Firestore EQ güncelleme hatası: $e");
    }
  }

  Future<void> _loadFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? foldersJson = prefs.getString('music_folders');
      if (foldersJson != null) {
        final List<dynamic> decoded = jsonDecode(foldersJson);
        _folders.clear();
        _folders.addAll(decoded.map((e) => MusicFolder.fromJson(e)).toList());
      }
    } catch (e) {
      debugPrint("Klasörler yüklenirken hata: $e");
    } finally {
      _isLocalFoldersLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _saveFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(
        _folders.map((f) => f.toJson()).toList(),
      );
      await prefs.setString('music_folders', encoded);

      // Eğer giriş yapılmışsa Firestore'u da güncelle
      if (_currentUser != null) {
        _updateFirestoreFolders();
      }
    } catch (e) {
      debugPrint("Klasörler kaydedilirken hata: $e");
    }
  }

  // Kullanıcıya özel depolama anahtarı oluşturur
  String _getDownloadsKey() {
    if (_currentUser != null) {
      return 'downloaded_songs_${_currentUser!.uid}';
    }
    return 'downloaded_songs'; // Misafir veya varsayılan anahtar
  }

  /// İndirilen şarkıları yükler
  Future<void> _loadDownloadedSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final String key = _getDownloadsKey();
    final String? jsonString = prefs.getString(key);
    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _downloadedSongs = jsonList.map((e) => Song.fromMap(e)).toList();
    } else {
      _downloadedSongs = []; // Kullanıcının verisi yoksa listeyi temizle
    }
    notifyListeners();
  }

  /// İndirilen şarkıları kaydeder
  Future<void> _saveDownloadedSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final String key = _getDownloadsKey();
    final String jsonString = jsonEncode(
      _downloadedSongs.map((s) => s.toJson()).toList(),
    );
    await prefs.setString(key, jsonString);
  }

  /// Şarkıyı indirmeyi başlatır
  Future<void> downloadSong(Song song) async {
    if (_downloadProgress.containsKey(song.id) &&
        !_pausedDownloads.contains(song.id))
      return; // Zaten iniyorsa çık

    bool isResuming = _pausedDownloads.contains(song.id);

    _pausedDownloads.remove(
      song.id,
    ); // Eğer duraklatılmışsa, artık devam ediyor

    // Başlangıç durumu
    if (!isResuming) {
      _downloadProgress[song.id] =
          null; // Belirsiz ilerleme için null ile başla
      if (_downloadProgressNotifiers.containsKey(song.id)) {
        _downloadProgressNotifiers[song.id]!.value = null;
      }
    }
    _downloadDetails[song.id] = isResuming
        ? "Devam ediliyor..."
        : "Hazırlanıyor...";
    if (_downloadDetailsNotifiers.containsKey(song.id)) {
      _downloadDetailsNotifiers[song.id]!.value = _downloadDetails[song.id]!;
    }
    final cancelToken = CancelToken();
    _downloadCancelTokens[song.id] = cancelToken;
    notifyListeners();

    // İlerleme SnackBar'ını göster
    if (navigatorKey.currentContext != null) {
      CustomSnackBar.showDownloadProgress(
        context: navigatorKey.currentContext!,
        song: song,
      );
    }

    // Bildirim güncelleme kontrolü için değişken
    int lastProgressPercent = 0;
    // UI güncelleme kontrolü için değişken (Kasma sorununu çözmek için)
    int lastUiProgressPercent = 0;

    final dio = Dio();
    final dir = await getApplicationDocumentsDirectory();
    final savePath = '${dir.path}/${song.id}.mp4';
    final imagePath = '${dir.path}/${song.id}.jpg';
    final file = File(savePath);

    try {
      // Başlangıç bildirimi
      try {
        await _showDownloadProgressNotification(song, 0, 0);
      } catch (e) {
        debugPrint("Başlangıç bildirimi hatası: $e");
      }

      bool isDownloaded = false;

      // AKILLI İNDİRME DÖNGÜSÜ (Otomatik Duraklat/Devam Et)
      int retryCount = 0; // Hata deneme sayacı
      while (!isDownloaded &&
          !_cancelingDownloads.contains(song.id) &&
          !_pausedDownloads.contains(song.id)) {
        // 1. İnternet kesikse bekle
        if (!_hasConnection) {
          _downloadDetails[song.id] = "Bağlantı bekleniyor...";
          if (_downloadDetailsNotifiers.containsKey(song.id)) {
            _downloadDetailsNotifiers[song.id]!.value =
                "Bağlantı bekleniyor...";
          }
          notifyListeners();

          // Bağlantı gelene veya iptal edilene kadar bekle
          while (!_hasConnection &&
              !_cancelingDownloads.contains(song.id) &&
              !_pausedDownloads.contains(song.id)) {
            await Future.delayed(const Duration(milliseconds: 500));
          }

          if (_cancelingDownloads.contains(song.id) ||
              _pausedDownloads.contains(song.id))
            break;

          _downloadDetails[song.id] = "İndirme devam ediyor...";
          if (_downloadDetailsNotifiers.containsKey(song.id)) {
            _downloadDetailsNotifiers[song.id]!.value =
                "İndirme devam ediyor...";
          }
          notifyListeners();
        }

        try {
          // 2. Mevcut dosya boyutunu kontrol et (Kaldığı yeri bulmak için)
          int downloadedBytes = 0;
          if (await file.exists()) {
            downloadedBytes = await file.length();
          }

          // Dinamik ses bağlantısını çöz
          String downloadUrl = song.audioUrl;
          // Eski Audius dışındaki tüm şarkıları YouTube üzerinden çöz
          if (!downloadUrl.contains('audius.co')) {
            try {
              downloadUrl = await _resolveYoutubeStreamUrl(song.id);
            } catch (e) {
              debugPrint("Youtube Explode İndirme Hatası: $e");
              throw Exception("İndirme için ses akışı alınamadı.");
            }
          }

          // 3. İndirme isteği (Range header ile kaldığı yerden ister)
          final response = await dio.get<ResponseBody>(
            downloadUrl,
            options: Options(
              responseType: ResponseType.stream,
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                'Referer': 'https://www.youtube.com/',
                'Origin': 'https://www.youtube.com',
                if (downloadedBytes > 0) 'range': 'bytes=$downloadedBytes-',
              },
            ),
            cancelToken: cancelToken,
          );

          // Toplam boyutu hesapla (Mevcut + Kalan)
          int totalBytes = downloadedBytes;
          final contentLengthHeader = response.headers.value(
            Headers.contentLengthHeader,
          );
          if (contentLengthHeader != null) {
            totalBytes += int.parse(contentLengthHeader);
          }

          // Eğer sunucu Range desteklemiyorsa (200 OK dönerse), dosyayı sıfırdan başlat
          if (response.statusCode == 200) {
            downloadedBytes = 0;
            if (contentLengthHeader != null) {
              totalBytes = int.parse(contentLengthHeader);
            }
          }

          final stream = response.data!.stream;
          // Dosyayı duruma göre ekleme (append) veya yazma (write) modunda aç
          final sink = file.openWrite(
            mode: (response.statusCode == 206)
                ? FileMode.append
                : FileMode.write,
          );

          int receivedChunk = 0;
          try {
            await stream.listen((chunk) {
              receivedChunk += chunk.length;
              sink.add(chunk);

              final currentTotal = downloadedBytes + receivedChunk;
              if (totalBytes > 0) {
                final progressVal = currentTotal / totalBytes;
                _downloadProgress[song.id] = progressVal;
                if (_downloadProgressNotifiers.containsKey(song.id)) {
                  _downloadProgressNotifiers[song.id]!.value = progressVal;
                }

                // MB Detay
                final double receivedMB = currentTotal / (1024 * 1024);
                final double totalMB = totalBytes / (1024 * 1024);
                final detailStr =
                    "${receivedMB.toStringAsFixed(1)} MB / ${totalMB.toStringAsFixed(1)} MB";
                _downloadDetails[song.id] = detailStr;
                if (_downloadDetailsNotifiers.containsKey(song.id)) {
                  _downloadDetailsNotifiers[song.id]!.value = detailStr;
                }

                // UI Güncelleme
                int currentPercent = ((currentTotal / totalBytes) * 100)
                    .toInt();
                if (currentPercent > lastUiProgressPercent) {
                  lastUiProgressPercent = currentPercent;
                  notifyListeners();
                }

                // Bildirim Güncelleme
                if (currentPercent > lastProgressPercent + 5) {
                  lastProgressPercent = currentPercent;
                  _showDownloadProgressNotification(
                    song,
                    currentTotal,
                    totalBytes,
                  ).ignore();
                }
              }
            }, cancelOnError: true).asFuture();

            await sink.flush();
            retryCount = 0; // İşlem başarılı olursa sayacı sıfırla
            isDownloaded = true; // Başarıyla bitti, döngüden çık
          } finally {
            await sink.close();
          }
        } catch (e) {
          if (e is DioException && CancelToken.isCancel(e)) {
            rethrow; // İptal edildiyse dışarı fırlat
          }
          if (e is DioException &&
              e.response != null &&
              (e.response!.statusCode == 403 ||
                  e.response!.statusCode == 404)) {
            _resolvedStreamUrlCache.remove(
              song.id,
            ); // Zaman aşımı olduysa linki RAM'den sil ki döngü taze link çeksin
          }
          // Kullanıcı iptal etmediyse ve hata aldıysak (örneğin internet koptu)
          // Döngü başa dönecek ve internet kontrolü yapacak.
          if (_cancelingDownloads.contains(song.id)) {
            throw DioException(
              requestOptions: RequestOptions(),
              type: DioExceptionType.cancel,
            );
          }

          // Eğer üst üste 3 kere hata verirse sonsuz döngüyü kır ve iptal et
          retryCount++;
          if (retryCount >= 3) {
            throw Exception(
              "Sunucu yanıt vermedi veya erişim reddedildi. Lütfen tekrar deneyin.",
            );
          }

          debugPrint(
            "İndirme kesildi, bağlantı bekleniyor veya tekrar deneniyor: $e",
          );
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      // Döngüden iptal ile çıkıldıysa hata fırlat
      if (_cancelingDownloads.contains(song.id) ||
          _pausedDownloads.contains(song.id)) {
        throw DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.cancel,
        );
      }

      // Resmi de indir
      try {
        await dio
            .download(song.coverUrl, imagePath)
            .timeout(const Duration(seconds: 10));
        song.localImagePath = imagePath;
      } catch (e) {
        debugPrint("Resim indirme hatası: $e");
      }

      // Şarkının bir kopyasını telefonun yerel (genel erişime açık) İndirilenler klasörüne kaydet
      if (Platform.isAndroid) {
        try {
          final publicDir = Directory('/storage/emulated/0/Download/OYN_Music');
          if (!await publicDir.exists()) {
            await publicDir.create(recursive: true);
          }
          // Dosya isminde sorun çıkarabilecek yasa dışı karakterleri temizle
          final cleanTitle = song.title
              .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
              .trim();
          final cleanArtist = song.artist
              .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
              .trim();
          final publicSavePath =
              '${publicDir.path}/$cleanTitle - $cleanArtist.m4a'; // Müzik olarak tanınması için uzantıyı m4a yapıyoruz

          await file.copy(publicSavePath);

          debugPrint("Şarkı genel klasöre kopyalandı: $publicSavePath");
        } catch (e) {
          debugPrint("Genel klasöre kopyalama hatası: $e");
        }
      }

      // Başarılı ise listeye ekle
      song.localPath = savePath;
      song.dateAdded = DateTime.now();
      _downloadedSongs.add(song);
      await _saveDownloadedSongs();

      notifyListeners(); // Arayüzün İndirildi animasyonunu anında başlatması için tetikle!

      // Not: İlerleme bildiriminin (SnackBar) başarılı olduğunda aniden yeşile dönmesi
      // ve kendi kendini kapatması CustomSnackBar içerisindeki isDownloaded kontrolüyle sağlanmaktadır.

      // İndirme bittiğinde reklam sayacını kontrol et
      _downloadAdCounter++;
      if (_downloadAdCounter % 2 == 0) {
        if (_isAudioServiceInitialized && audioPlayer.playing) {
          _isAdPending = true;
        } else {
          _interstitialAdManager.showAdIfAvailable();
        }
      }

      try {
        _showDownloadNotification(song); // İndirme bitince bildirim göster
      } catch (e) {
        debugPrint("Bitiş bildirimi hatası: $e");
      }
    } catch (e) {
      // Hata türünü güvenli bir şekilde kontrol ediyoruz
      if (e is DioException && CancelToken.isCancel(e)) {
        if (_pausedDownloads.contains(song.id)) {
          debugPrint("İndirme duraklatıldı: ${song.title}");
          _downloadDetails[song.id] = "Duraklatıldı";
          notifyListeners();
          // Duraklatıldı bildirimini ekranda tutmayı garantile
          _showDownloadProgressNotification(song, -1, -1);
        } else {
          CustomSnackBar.hideCurrent(); // İlerleme snackbar'ını gizle
          // İptal durumunda bildirimi temizle
          _cancelNotification(song.id);

          debugPrint("İndirme iptal edildi: ${song.title}");

          // İptal edildiyse yarım kalan dosyayı sil
          if (await file.exists()) await file.delete();

          if (navigatorKey.currentContext != null) {
            final langProvider = Provider.of<LanguageProvider>(
              navigatorKey.currentContext!,
              listen: false,
            );
            CustomSnackBar.showError(
              context: navigatorKey.currentContext!,
              message: langProvider.t('download_canceled'),
            );
          }
        }
      } else {
        CustomSnackBar.hideCurrent(); // İlerleme snackbar'ını gizle
        // Diğer hata durumlarında bildirimi iptal et
        _cancelNotification(song.id);

        debugPrint("İndirme hatası: $e");
        _playbackError = "İndirme başarısız oldu.";
        rethrow; // Hatayı fırlat ki UI (TrendPage vb.) yakalayabilsin
      }
    } finally {
      // Temizlik
      if (!_pausedDownloads.contains(song.id)) {
        _downloadProgress.remove(song.id);
        _downloadDetails.remove(song.id);
      }
      _downloadCancelTokens.remove(song.id);
      _cancelingDownloads.remove(song.id);
      notifyListeners();
    }
  }

  /// İndirme tamamlandı bildirimi gösterir
  Future<void> _showDownloadNotification(Song song) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'download_channel', // Kanal ID
          'İndirmeler', // Kanal Adı
          channelDescription: 'İndirme tamamlandı bildirimleri',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    // Şarkı ID'sinin hash kodunu bildirim ID'si olarak kullanıyoruz (benzersiz olması için)
    await _notificationsPlugin.show(
      song.id.hashCode,
      'İndirme Tamamlandı',
      '${song.title} başarıyla indirildi.',
      platformChannelSpecifics,
    );
  }

  /// İndirme ilerleme bildirimi gösterir
  Future<void> _showDownloadProgressNotification(
    Song song,
    int received,
    int total,
  ) async {
    int progress = 0;
    String sizeInfo = "";
    bool indeterminate = false;

    if (total == -1 && received == -1) {
      final double? pDouble = _downloadProgress[song.id];
      if (pDouble != null) {
        progress = (pDouble * 100).toInt();
      }
      sizeInfo = _downloadDetails[song.id] ?? "Duraklatıldı";
    } else if (total > 0) {
      progress = ((received / total) * 100).toInt();
      final double receivedMB = received / (1024 * 1024);
      final double totalMB = total / (1024 * 1024);
      sizeInfo =
          "${receivedMB.toStringAsFixed(1)} MB / ${totalMB.toStringAsFixed(1)} MB";
    } else {
      indeterminate = true;
      sizeInfo = "Boyut hesaplanıyor...";
    }

    final isPaused = _pausedDownloads.contains(song.id);
    final List<AndroidNotificationAction> actions = [
      AndroidNotificationAction(
        isPaused ? 'resume' : 'pause',
        isPaused ? 'Devam Et' : 'Durdur',
        cancelNotification: false,
        showsUserInterface: false,
      ),
      const AndroidNotificationAction(
        'cancel',
        'İptal Et',
        cancelNotification: true,
        showsUserInterface: false,
      ),
    ];

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'download_channel',
          'İndirmeler',
          channelDescription: 'İndirme durumu',
          importance: Importance.low, // Ses çıkarmaması için low
          priority: Priority.low,
          showProgress: true,
          maxProgress: 100,
          progress: progress,
          indeterminate: indeterminate,
          onlyAlertOnce: true,
          showWhen: false,
          subText: sizeInfo,
          actions: actions,
        );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    final String payload = jsonEncode(song.toJson());

    await _notificationsPlugin.show(
      song.id.hashCode,
      isPaused ? 'İndirme Duraklatıldı' : 'İndiriliyor...',
      song.title,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  Future<void> _cancelNotification(String songId) async {
    await _notificationsPlugin.cancel(songId.hashCode);
  }

  /// İndirmeyi duraklatır
  void pauseDownload(Song song) {
    final songId = song.id;
    if (_downloadProgress.containsKey(songId) &&
        !_pausedDownloads.contains(songId)) {
      _pausedDownloads.add(songId);
      _downloadDetails[songId] = "Duraklatıldı";
      getDownloadDetailsNotifier(songId).value = "Duraklatıldı";
      notifyListeners();

      if (_downloadCancelTokens.containsKey(songId)) {
        _downloadCancelTokens[songId]!.cancel();
      }

      // Bildirimi iptal etmek yerine durumu duraklatıldı olarak güncelle
      _showDownloadProgressNotification(song, -1, -1);
    }
  }

  /// İndirmeyi iptal eder
  void cancelDownload(String songId) async {
    _cancelingDownloads.add(songId);
    notifyListeners(); // UI'ı güncelle ("İptal Ediliyor..." göstermek için)
    _cancelNotification(songId); // Bildirimi iptal et

    if (_downloadCancelTokens.containsKey(songId)) {
      _downloadCancelTokens[songId]!.cancel();
    } else if (_pausedDownloads.contains(songId)) {
      // Duraklatılmışsa aktif döngü yoktur, elle temizle
      _pausedDownloads.remove(songId);
      _downloadProgress.remove(songId);
      _downloadDetails.remove(songId);
      _cancelingDownloads.remove(songId);
      notifyListeners();

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$songId.mp4');
      if (await file.exists()) await file.delete();

      if (navigatorKey.currentContext != null) {
        final langProvider = Provider.of<LanguageProvider>(
          navigatorKey.currentContext!,
          listen: false,
        );
        CustomSnackBar.hideCurrent();
        CustomSnackBar.showError(
          context: navigatorKey.currentContext!,
          message: langProvider.t('download_canceled'),
        );
      }
    }
  }

  /// İndirilen şarkıyı siler
  Future<void> deleteDownloadedSong(Song song) async {
    // Eğer silinen şarkı şu an çalıyorsa oynatmayı durdur
    if (currentSong?.id == song.id) {
      if (_isAudioServiceInitialized) {
        await _audioHandler.stop();
      }
      _currentSongIndex = null; // Çalan şarkı silindiği için index'i sıfırla
    } else if (identical(_playlist, _downloadedSongs)) {
      // Eğer indirilenler listesinden çalınıyorsa ve önceki bir şarkı siliniyorsa index'i güncelle
      final indexToRemove = _downloadedSongs.indexWhere((s) => s.id == song.id);
      if (_currentSongIndex != null &&
          indexToRemove != -1 &&
          indexToRemove < _currentSongIndex!) {
        _currentSongIndex = _currentSongIndex! - 1;
      }
    }

    if (song.localPath != null) {
      final file = File(song.localPath!);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (e) {
          debugPrint("Dosya silme hatası: $e");
        }
      }
    }
    if (song.localImagePath != null) {
      final imgFile = File(song.localImagePath!);
      if (await imgFile.exists()) {
        try {
          await imgFile.delete();
        } catch (e) {
          debugPrint("Resim silme hatası: $e");
        }
      }
    }
    _downloadedSongs.removeWhere((s) => s.id == song.id);
    await _saveDownloadedSongs();

    // Klasörlerden de kaldır
    bool folderUpdated = false;
    for (var folder in _folders) {
      final int initialCount = folder.songs.length;
      folder.songs.removeWhere((s) => s.id == song.id);
      if (folder.songs.length != initialCount) {
        folderUpdated = true;
      }
    }
    if (folderUpdated) {
      await _saveFolders();
    }
    notifyListeners();
  }

  /// Tüm indirilen şarkıları siler
  Future<void> deleteAllDownloadedSongs() async {
    // Oynatmayı durdur (Eğer indirilenlerden biri çalıyorsa)
    if (currentSong != null &&
        _downloadedSongs.any((s) => s.id == currentSong!.id) &&
        _isAudioServiceInitialized) {
      await _audioHandler.stop();
      _currentSongIndex = null; // Tüm liste silindiği için index'i sıfırla
    }

    // Silinecek ID'leri sakla (Klasörlerden silmek için)
    final idsToRemove = _downloadedSongs.map((s) => s.id).toSet();

    for (var song in _downloadedSongs) {
      if (song.localPath != null) {
        final file = File(song.localPath!);
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (e) {
            debugPrint("Dosya silme hatası: $e");
          }
        }
      }
      if (song.localImagePath != null) {
        final imgFile = File(song.localImagePath!);
        if (await imgFile.exists()) {
          try {
            await imgFile.delete();
          } catch (e) {
            debugPrint("Resim silme hatası: $e");
          }
        }
      }
    }
    _downloadedSongs.clear();
    await _saveDownloadedSongs();

    // Klasörlerden de kaldır
    bool folderUpdated = false;
    for (var folder in _folders) {
      final int initialCount = folder.songs.length;
      folder.songs.removeWhere((s) => idsToRemove.contains(s.id));
      if (folder.songs.length != initialCount) {
        folderUpdated = true;
      }
    }
    if (folderUpdated) {
      await _saveFolders();
    }
    notifyListeners();
  }

  bool isSongDownloaded(String id) {
    return _downloadedSongs.any((s) => s.id == id);
  }

  /// Şarkıyı sıradaki çalınacak olarak ekler
  void addSongToNext(Song song) {
    if (_playlist.isEmpty || _currentSongIndex == null) {
      playSong(song, [song]);
      return;
    }

    final int insertIndex = _currentSongIndex! + 1;
    _playlist.insert(insertIndex, song);

    if (_isShuffleEnabled) {
      for (int i = 0; i < _shuffledIndices.length; i++) {
        if (_shuffledIndices[i] >= insertIndex) {
          _shuffledIndices[i]++;
        }
      }
      int currentShuffledIndex = _shuffledIndices.indexOf(_currentSongIndex!);
      if (currentShuffledIndex != -1) {
        _shuffledIndices.insert(currentShuffledIndex + 1, insertIndex);
      } else {
        _shuffledIndices.add(insertIndex);
      }
    }

    notifyListeners();

    if (navigatorKey.currentContext != null) {
      final langProvider = Provider.of<LanguageProvider>(
        navigatorKey.currentContext!,
        listen: false,
      );
      CustomSnackBar.showInfo(
        context: navigatorKey.currentContext!,
        message: "${song.title} ${langProvider.t('added_to_queue')}",
      );
    }
  }

  /// Çoklu şarkıyı sıradaki çalınacaklar olarak ekler
  void addSongsToNext(List<Song> songs) {
    if (songs.isEmpty) return;

    if (_playlist.isEmpty || _currentSongIndex == null) {
      playSong(songs.first, songs);
      return;
    }

    final int insertIndex = _currentSongIndex! + 1;
    _playlist.insertAll(insertIndex, songs);

    if (_isShuffleEnabled) {
      // Mevcut indeksleri kaydır
      for (int i = 0; i < _shuffledIndices.length; i++) {
        if (_shuffledIndices[i] >= insertIndex) {
          _shuffledIndices[i] += songs.length;
        }
      }

      // Yeni şarkıların indekslerini shuffle listesine ekle
      int currentShuffledIndex = _shuffledIndices.indexOf(_currentSongIndex!);
      List<int> newIndices = List.generate(
        songs.length,
        (i) => insertIndex + i,
      );

      if (currentShuffledIndex != -1) {
        _shuffledIndices.insertAll(currentShuffledIndex + 1, newIndices);
      } else {
        _shuffledIndices.addAll(newIndices);
      }
    }

    notifyListeners();

    if (navigatorKey.currentContext != null) {
      final langProvider = Provider.of<LanguageProvider>(
        navigatorKey.currentContext!,
        listen: false,
      );
      CustomSnackBar.showInfo(
        context: navigatorKey.currentContext!,
        message: "${songs.length} ${langProvider.t('songs_added_to_queue')}",
      );
    }
  }

  /// YouTube bağlantısını çözer. Eğer zaten arka planda çözülüyorsa aynı işlemi bekleyerek (Future sharing) kopya istek atılmasını engeller.
  Future<String> _resolveYoutubeStreamUrl(String songId) {
    if (_resolvedStreamUrlCache.containsKey(songId)) {
      return Future.value(_resolvedStreamUrlCache[songId]!);
    }

    if (_resolvingTasks.containsKey(songId)) {
      return _resolvingTasks[songId]!;
    }

    final future = _yt.videos.streamsClient
        .getManifest(songId)
        .then((manifest) {
          // 1. Öncelik: Bot kısıtlamalarını aşmak için 'muxed' (ses+video) mp4 formatı
          Iterable<StreamInfo> muxedStreams = manifest.muxed.where(
            (s) => s.container.name.toString().toLowerCase() == 'mp4',
          );

          if (muxedStreams.isNotEmpty) {
            final url = muxedStreams.sortByBitrate().first.url.toString();
            _resolvedStreamUrlCache[songId] = url;
            _resolvingTasks.remove(songId);
            return url;
          }

          // 2. Yedek: Muxed bulunamazsa 'audioOnly' mp4 formatına geç
          Iterable<StreamInfo> audioStreams = manifest.audioOnly.where(
            (s) => s.container.name.toString().toLowerCase() == 'mp4',
          );

          if (audioStreams.isNotEmpty) {
            final url = audioStreams.sortByBitrate().last.url.toString();
            _resolvedStreamUrlCache[songId] = url;
            _resolvingTasks.remove(songId);
            return url;
          }

          // 3. Son çare
          if (manifest.audioOnly.isNotEmpty) {
            final url = manifest.audioOnly.sortByBitrate().last.url.toString();
            _resolvedStreamUrlCache[songId] = url;
            _resolvingTasks.remove(songId);
            return url;
          }

          throw Exception("Ses akışı bulunamadı");
        })
        .catchError((Object e) {
          _resolvingTasks.remove(songId);
          throw e;
        });

    _resolvingTasks[songId] = future;
    return future;
  }

  /// Sıradaki çalacak şarkının ses bağlantısını arka planda önceden hazırlar (Sıfır Gecikme)
  void _preResolveNextSong() {
    if (_playlist.isEmpty || _currentSongIndex == null) return;

    int nextIndex;
    if (_isShuffleEnabled) {
      if (_shuffledIndices.isEmpty ||
          _shuffledIndices.length != _playlist.length)
        return;
      int currentShuffledIndex = _shuffledIndices.indexOf(_currentSongIndex!);
      if (currentShuffledIndex == -1) return;
      if (currentShuffledIndex + 1 >= _shuffledIndices.length) {
        nextIndex = _shuffledIndices[0];
      } else {
        nextIndex = _shuffledIndices[currentShuffledIndex + 1];
      }
    } else {
      if (_currentSongIndex! + 1 >= _playlist.length) {
        nextIndex = 0;
      } else {
        nextIndex = _currentSongIndex! + 1;
      }
    }

    final nextSong = _playlist[nextIndex];

    // Eğer yerel dosya ise internetten çözmeye gerek yok
    final downloadedSong = _downloadedSongs.firstWhere(
      (s) => s.id == nextSong.id,
      orElse: () => nextSong,
    );
    if (downloadedSong.localPath != null &&
        File(downloadedSong.localPath!).existsSync()) {
      return;
    }

    // YouTube şarkısıysa arka planda sessizce çöz
    if (!nextSong.audioUrl.contains('audius.co')) {
      _resolveYoutubeStreamUrl(nextSong.id).catchError((_) {
        // Önceden yükleme sırasındaki hataları sessizce yutuyoruz, kullanıcı şarkıya tıkladığında zaten hatayı görür
      });
    }
  }

  Future<void> playSong(Song song, List<Song> playlist) async {
    _addToRecentlyPlayed(song);
    _addToMostPlayed(song); // En çok dinlenenler listesini güncelle

    // Şarkı oynatma tıklaması sayacını artır ve reklam kontrolü yap
    _songPlayAdCounter++;
    if (_songPlayAdCounter % 10 == 0) {
      if (_isAudioServiceInitialized && audioPlayer.playing) {
        _isAdPending = true;
      } else {
        _interstitialAdManager.showAdIfAvailable();
      }
    }

    // Servis başlatılmadıysa başlatmayı dene (Örn: İlk açılışta hata olduysa)
    if (!_isAudioServiceInitialized) {
      try {
        await _initAudioService();
      } catch (e) {
        debugPrint("AudioService başlatılamadı: $e");
        return;
      }
    }

    // YENİ ŞARKIYA GEÇİŞ: State'leri hemen güncelleyerek eski şarkının ekranda kalmasını önlüyoruz
    _pendingSongId = song.id; // Hedef şarkıyı işaretle

    _isSongLoading = true;
    _playbackError = null; // Yeni şarkıya başlarken hatayı sıfırla

    bool isNewPlaylist = _playlist != playlist;
    if (isNewPlaylist) {
      _playlist = List.from(
        playlist,
      ); // Listeyi kopyalayarak referans hatalarını ve çökmeleri engelliyoruz
    }
    _currentSongIndex = _playlist.indexWhere((s) => s.id == song.id);

    // Şarkı listede bulunamadıysa işlemi durdur
    if (_currentSongIndex == -1) {
      _isSongLoading = false;
      notifyListeners();
      return;
    }

    notifyListeners(); // UI'ı hemen güncelle (Kapak resmi ve isim anında değişsin)

    if (_isAudioServiceInitialized) {
      // Eski şarkı çalıyorsa ve henüz bitmemişse sesini yavaşça kısıp duraklat
      if (audioPlayer.playing &&
          audioPlayer.processingState != ProcessingState.completed) {
        _isFading = false;
        await _fadeOut();
        audioPlayer.pause();
      }
      audioPlayer.seek(
        Duration.zero,
      ); // Eski şarkının ilerleme çubuğunu arkaplanda sıfırla
      await audioPlayer.setVolume(0.0); // Yeni şarkıya fade-in hazırlığı
    }

    // Yeni bir liste geldiyse veya shuffle açık ama liste boşsa shuffle listesini oluştur
    if (_isShuffleEnabled && (isNewPlaylist || _shuffledIndices.isEmpty)) {
      _generateShuffledIndices();
    }

    if (_currentSongIndex != -1) {
      try {
        // 1. ÖNCE YEREL DOSYAYI KONTROL ET
        // Eğer şarkı indirilmişse ve dosya mevcutsa internete gitme
        final downloadedSong = _downloadedSongs.firstWhere(
          (s) => s.id == song.id,
          orElse: () => song,
        );

        // Resim URI'sini belirle (Çevrimdışı mod için yerel resim)
        Uri artUri = Uri.parse(song.coverUrl);
        if (downloadedSong.localImagePath != null &&
            File(downloadedSong.localImagePath!).existsSync()) {
          artUri = Uri.file(downloadedSong.localImagePath!);
        }

        // Bildirimde görünecek veriyi hazırla
        final mediaItem = MediaItem(
          id: song.id,
          album: "OYN Music",
          title: song.title,
          artist: song.artist,
          artUri: artUri,
          duration: Duration(seconds: song.duration ?? 0),
        );

        if (downloadedSong.localPath != null) {
          final file = File(downloadedSong.localPath!);
          if (await file.exists()) {
            if (_pendingSongId != song.id) return;
            await _audioHandler.playSong(mediaItem, downloadedSong.localPath!);
            _fadeIn(); // Yeni şarkının sesini yavaşça aç
            _isSongLoading = false;
            notifyListeners();
            return; // Yerelden çalındı, fonksiyondan çık
          }
        }

        // Normal URL
        if (_pendingSongId != song.id) return;

        // Dinamik ses bağlantısını çöz (Streaming)
        String streamUrl = song.audioUrl;
        // Audius dışındaki her şeyi (YouTube) id üzerinden YouTubeExplode ile çöz
        if (!streamUrl.contains('audius.co')) {
          try {
            streamUrl = await _resolveYoutubeStreamUrl(song.id);
          } catch (e) {
            debugPrint("Youtube Explode Akış Hatası: $e");
            throw Exception("Şarkı akışı alınamadı.");
          }
        }

        if (_pendingSongId != song.id) return;

        await _audioHandler.playSong(mediaItem, streamUrl);
        _fadeIn(); // Online şarkının sesini yavaşça aç

        // İşlem bittiğinde hala aynı şarkıdaysak loading'i kapat
        if (_pendingSongId == song.id) {
          notifyListeners();
        }

        // --- SIFIR GECİKME: Sonraki şarkıyı arka planda hazırla ---
        _preResolveNextSong();
      } catch (e) {
        if (_pendingSongId != song.id)
          return; // Şarkı değiştiyse hatayı gösterme

        _resolvedStreamUrlCache.remove(
          song.id,
        ); // Çalma hatası olduysa bozuk linki sil (süresi dolmuş olabilir)

        debugPrint("Ses çalınırken hata oluştu: $e");
        String errorStr = e.toString();
        if (errorStr.contains('PlayerException') ||
            errorStr.contains('Source error')) {
          if (errorStr.contains('403')) {
            _playbackError = "Erişim reddedildi (403). Lütfen tekrar deneyin.";
          } else if (errorStr.contains('Source error') &&
              errorStr.contains('0')) {
            _playbackError =
                "Kaynak hatası. Şarkı yüklenemedi, lütfen tekrar deneyin veya başka bir şarkı seçin.";
          } else {
            _playbackError =
                "Şarkı kaynağına erişilemedi. Format desteklenmiyor veya ağ hatası.\n($errorStr)";
          }
        } else {
          _playbackError =
              "Hata: ${errorStr.replaceAll('Exception:', '').trim()}";
        }
      } finally {
        // Sadece hedef şarkı bu ise loading'i kapat
        if (_pendingSongId == song.id) {
          _isSongLoading = false;
          notifyListeners();
        }
      }
    } else {
      _isSongLoading = false;
      notifyListeners();
    }
  }

  Future<void> playNext({bool userInitiated = true}) async {
    if (_playlist.isEmpty || _currentSongIndex == null) return;

    // Tekrar modu: Bir (Sadece otomatik geçişte geçerli, kullanıcı basarsa geçer)
    if (!userInitiated && _loopMode == LoopMode.one) {
      audioPlayer.seek(Duration.zero);
      audioPlayer.play();
      return;
    }

    int nextIndex;
    if (_isShuffleEnabled) {
      if (_shuffledIndices.isEmpty ||
          _shuffledIndices.length != _playlist.length) {
        _generateShuffledIndices();
      }

      int currentShuffledIndex = _shuffledIndices.indexOf(_currentSongIndex!);
      // Eğer bulunamazsa (olmaması lazım) listeyi yenile
      if (currentShuffledIndex == -1) {
        _generateShuffledIndices();
        currentShuffledIndex = _shuffledIndices.indexOf(_currentSongIndex!);
      }

      if (currentShuffledIndex + 1 >= _shuffledIndices.length) {
        // Listenin sonu
        nextIndex = _shuffledIndices[0]; // Başa dön
      } else {
        nextIndex = _shuffledIndices[currentShuffledIndex + 1];
      }
    } else {
      // Normal sıralama
      if (_currentSongIndex! + 1 >= _playlist.length) {
        // Listenin sonu
        nextIndex = 0; // Başa dön
      } else {
        nextIndex = _currentSongIndex! + 1;
      }
    }

    await playSong(_playlist[nextIndex], _playlist);
  }

  Future<void> playPrevious() async {
    if (_playlist.isEmpty || _currentSongIndex == null) return;

    // Eğer şarkı 3 saniyeden fazla çaldıysa başa sar
    if (audioPlayer.position.inSeconds > 3) {
      audioPlayer.seek(Duration.zero);
      return;
    }

    int prevIndex;
    if (_isShuffleEnabled) {
      if (_shuffledIndices.isEmpty) _generateShuffledIndices();
      int currentShuffledIndex = _shuffledIndices.indexOf(_currentSongIndex!);
      if (currentShuffledIndex <= 0) {
        prevIndex = _shuffledIndices[_shuffledIndices.length - 1];
      } else {
        prevIndex = _shuffledIndices[currentShuffledIndex - 1];
      }
    } else {
      if (_currentSongIndex! - 1 < 0) {
        prevIndex = _playlist.length - 1;
      } else {
        prevIndex = _currentSongIndex! - 1;
      }
    }
    await playSong(_playlist[prevIndex], _playlist);
  }

  void toggleShuffle() {
    _isShuffleEnabled = !_isShuffleEnabled;
    if (_isShuffleEnabled) {
      _generateShuffledIndices();
    }
    notifyListeners();
  }

  /// Uyku zamanlayıcısını ayarlar
  void setSleepTimer(int minutes) {
    cancelSleepTimer(notify: false); // Varsa öncekini sessizce iptal et

    if (minutes <= 0) return;

    _sleepTimerEndTime = DateTime.now().add(Duration(minutes: minutes));
    notifyListeners();

    _sleepTimer = Timer(Duration(minutes: minutes), () {
      if (_isAudioServiceInitialized && _audioHandler.audioPlayer.playing) {
        _audioHandler.pause();
      }
      cancelSleepTimer();
    });
  }

  /// Uyku zamanlayıcısını iptal eder
  void cancelSleepTimer({bool notify = true}) {
    if (_sleepTimer != null) {
      _sleepTimer!.cancel();
      _sleepTimer = null;
    }
    _sleepTimerEndTime = null;
    if (notify) {
      notifyListeners();
    }
  }

  void _generateShuffledIndices() {
    if (_playlist.isNotEmpty) {
      _shuffledIndices = List.generate(_playlist.length, (i) => i)..shuffle();
    }
  }

  void cycleLoopMode() {
    if (_loopMode == LoopMode.off) {
      _loopMode = LoopMode.all;
    } else if (_loopMode == LoopMode.all) {
      _loopMode = LoopMode.one;
    } else {
      _loopMode = LoopMode.off;
    }
    notifyListeners();
  }

  /// Çalma listesindeki şarkıların sırasını değiştirir
  void reorderPlaylist(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final Song item = _playlist.removeAt(oldIndex);
    _playlist.insert(newIndex, item);

    if (_currentSongIndex != null) {
      if (_currentSongIndex == oldIndex) {
        _currentSongIndex = newIndex;
      } else if (_currentSongIndex! > oldIndex &&
          _currentSongIndex! <= newIndex) {
        _currentSongIndex = _currentSongIndex! - 1;
      } else if (_currentSongIndex! < oldIndex &&
          _currentSongIndex! >= newIndex) {
        _currentSongIndex = _currentSongIndex! + 1;
      }
    }

    if (_isShuffleEnabled) {
      _generateShuffledIndices();
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _listeningTimer?.cancel();
    _adTimer?.cancel();
    _yt.close(); // Uygulama kapanırken persistent nesnemizi temizliyoruz
    if (_isAudioServiceInitialized) {
      _audioHandler.stop();
    }
    super.dispose();
  }
}
