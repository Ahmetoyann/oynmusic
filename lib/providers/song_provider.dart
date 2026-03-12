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
import 'package:google_mobile_ads/google_mobile_ads.dart';

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
  // AudioHandler referansı (geç başlatılacak)
  late MyAudioHandler _audioHandler;
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
  bool _isLoadingMore = false; // Ekstra yükleme yapılıyor mu?
  List<Song> _recentlyPlayed = []; // Son dinlenenler listesi
  List<String> _searchHistory = [];
  String? _nextPageToken; // Sayfalama token'ı
  bool _isLowDataMode = false; // Düşük veri modu (Düşük kalite ses)
  bool _isSongLoading = false; // Şarkı hazırlanıyor mu?
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
  bool _isSuggestionsLoading = false; // Önerilerin yüklenme durumu

  // Reklam Değişkenleri
  InterstitialAd? _interstitialAd;
  int _songsPlayedCounter = 0;
  final int _adFrequency = 3; // Her 3 şarkıda bir reklam göster
  bool _isAdLoaded = false;

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
  bool _wasPlayingBeforeInterruption = false; // Kesintiden önce çalıyor muydu?
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
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get playbackError => _playbackError;
  bool get isSearchLoading => _isSearchLoading;
  bool get isSearchLoadingMore => _isSearchLoadingMore;
  bool get isLoadingMore => _isLoadingMore;
  List<String> get categories => _categories;
  List<String> get searchHistory => _searchHistory;
  List<Song> get recentlyPlayed => _recentlyPlayed;
  bool get isLowDataMode => _isLowDataMode;
  bool get isSongLoading => _isSongLoading;
  bool get hasConnection => _hasConnection;
  bool get isGuest => _isGuest;
  bool get isFirebaseLoggedIn => _currentUser != null;
  List<Song> get dailySongs => _dailySongs;
  bool get isShuffleEnabled => _isShuffleEnabled;
  LoopMode get loopMode => _loopMode;
  List<Song> get suggestedSongs => _suggestedSongs;
  bool get isSuggestionsLoading => _isSuggestionsLoading;
  List<Song> get playlist => _playlist;
  int? get currentSongIndex => _currentSongIndex;

  bool get isSleepTimerActive => _sleepTimer != null && _sleepTimer!.isActive;
  DateTime? get sleepTimerEndTime => _sleepTimerEndTime;

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
    _loadFolders();
    _loadSearchHistory();
    _loadRecentlyPlayed();
    fetchCategories();
    fetchSongsFromApi(); // Uygulama açılışında direkt çek
    _loadSettings();
    _initConnectivity();
    _initNotifications(); // Bildirim servisini başlat
    _loadInterstitialAd(); // İlk reklamı yükle
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
      _syncFavoritesWithFirestore();
      _syncFoldersWithFirestore();
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

    await _notificationsPlugin.initialize(initializationSettings);

    // Android 13+ için bildirim izni iste
    _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
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
            CustomSnackBar.showError(
              context: navigatorKey.currentContext!,
              message: "İnternet kesildiği için oynatma duraklatıldı.",
            );
          }
        }
      } else {
        // İnternet geldi: Kesintiden önce çalıyorsa devam et
        if (_isAudioServiceInitialized && _wasPlayingBeforeInterruption) {
          audioPlayer.play();
          _wasPlayingBeforeInterruption = false;
          if (navigatorKey.currentContext != null) {
            CustomSnackBar.showSuccess(
              context: navigatorKey.currentContext!,
              message: "Bağlantı sağlandı, oynatma devam ediyor.",
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

  Future<void> fetchSongsFromApi({String? genre, String? timeRange}) async {
    _currentGenre = genre;
    _currentTimeRange = timeRange;

    _isLoading = true;
    _nextPageToken = null; // Token'ı sıfırla
    _errorMessage = null;

    // Her yenilemede farklı içerik için rastgele ofset (0-50 arası)
    _initialOffset = Random().nextInt(50);

    // Yeni bir tür seçildiyse listeyi temizle ki kullanıcı yükleniyor görsün
    if (genre != null) _allSongs = [];
    notifyListeners();

    try {
      await _initAudioService();

      if (genre != null && genre != 'Hepsi') {
        // Audius API için tür eşleştirmesi (Mapping)
        String apiGenre = genre;
        if (genre == 'Hip Hop') apiGenre = 'Hip-Hop/Rap';

        final results = await AudiusService.getTrendingSongs(
          genre: apiGenre,
          timeRange: _currentTimeRange,
          offset: _initialOffset,
        );
        _allSongs = results;
      } else {
        // Hepsi seçiliyse Trendleri getir
        final results = await AudiusService.getTrendingSongs(
          timeRange: _currentTimeRange,
          offset: _initialOffset,
        );
        _allSongs = results;
      }
      _nextPageToken = null; // Audius basit endpoint'te sayfalama şimdilik yok

      // Günün şarkılarını belirle (Eğer liste boş değilse)
      if (_allSongs.isNotEmpty) {
        _dailySongs = List<Song>.from(_allSongs)..shuffle();
        _dailySongs = _dailySongs.take(10).toList();
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

        newSongs = await AudiusService.getTrendingSongs(
          genre: apiGenre,
          timeRange: _currentTimeRange,
          offset: currentOffset,
        );
      } else {
        newSongs = await AudiusService.getTrendingSongs(
          timeRange: _currentTimeRange,
          offset: currentOffset,
        );
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
      _audioHandler = await AudioService.init(
        builder: () => MyAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.ahmed.oyn_music.channel.audio',
          androidNotificationChannelName: 'Müzik Çalar',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidNotificationIcon: 'mipmap/ic_launcher',
        ),
      );

      // Şarkı bittiğinde otomatik geçiş
      _audioHandler.audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          playNext(userInitiated: false);
        }
      });

      // Bildirimden gelen Sonraki/Önceki komutlarını dinle
      _audioHandler.skipNextStream.listen((_) => playNext(userInitiated: true));
      _audioHandler.skipPrevStream.listen((_) => playPrevious());
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

  /// Şarkı araması yapar
  Future<void> searchSongs(String query) async {
    _isSearchLoading = true;
    _searchOffset = 0;
    _nextPageToken = null;
    notifyListeners();

    try {
      final results = await AudiusService.searchSongs(query);
      _searchResults = results;
    } catch (e) {
      debugPrint("Arama hatası: $e");
      _searchResults = [];
    } finally {
      _isSearchLoading = false;
      notifyListeners();
    }
  }

  /// Arama sayfası için rastgele önerilen şarkıları çeker
  Future<void> fetchSuggestedSongs() async {
    if (_suggestedSongs.isNotEmpty) return; // Zaten yüklendiyse tekrar çekme

    _isSuggestionsLoading = true;
    notifyListeners();
    try {
      final offset = Random().nextInt(100); // Rastgelelik için ofset
      final results = await AudiusService.getTrendingSongs(
        limit: 10,
        offset: offset,
      );
      _suggestedSongs = results;
    } catch (e) {
      debugPrint("Öneri şarkıları yüklenirken hata: $e");
    } finally {
      _isSuggestionsLoading = false;
      notifyListeners();
    }
  }

  /// Arama sonuçlarının devamını yükler (Sonsuz Kaydırma)
  Future<void> loadMoreSearchResults() async {
    if (_isSearchLoadingMore || _isSearchLoading || _searchText.isEmpty) return;

    _isSearchLoadingMore = true;
    notifyListeners();

    try {
      int currentOffset = _searchResults.length;
      final results = await AudiusService.searchSongs(
        _searchText,
        offset: currentOffset,
      );

      if (results.isNotEmpty) {
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

  /// Ayarları yükler
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isLowDataMode = prefs.getBool('low_data_mode') ?? false;
    notifyListeners();
  }

  /// Düşük veri modunu değiştirir
  Future<void> toggleLowDataMode(bool enable) async {
    _isLowDataMode = enable;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('low_data_mode', enable);
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
    if (_downloadProgress.containsKey(song.id)) return; // Zaten iniyorsa çık

    // Başlangıç durumu
    _downloadProgress[song.id] = null; // Belirsiz ilerleme için null ile başla
    _downloadDetails[song.id] = "Hazırlanıyor...";
    final cancelToken = CancelToken();
    _downloadCancelTokens[song.id] = cancelToken;
    notifyListeners();

    // İlerleme SnackBar'ını göster
    if (navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).hideCurrentSnackBar();
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: Consumer<SongProvider>(
            builder: (context, provider, child) {
              final progress = provider.downloadProgress[song.id];
              final details = provider.downloadDetails[song.id];
              final percentage = progress != null
                  ? (progress * 100).toInt()
                  : 0;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'İndiriliyor: ${song.title}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (progress != null)
                        Text(
                          "%$percentage",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  if (details != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      details,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress, // null ise belirsiz olur
                    backgroundColor: Colors.grey.shade600,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              );
            },
          ),
          backgroundColor: Colors.grey.shade800,
          duration: const Duration(days: 1), // Manuel olarak kapatılacak
        ),
      );
    }

    // Bildirim güncelleme kontrolü için değişken
    int lastProgressPercent = 0;
    // UI güncelleme kontrolü için değişken (Kasma sorununu çözmek için)
    int lastUiProgressPercent = 0;

    final dio = Dio();
    final dir = await getApplicationDocumentsDirectory();
    final savePath = '${dir.path}/${song.id}.m4a';
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
      while (!isDownloaded && !_cancelingDownloads.contains(song.id)) {
        // 1. İnternet kesikse bekle
        if (!_hasConnection) {
          _downloadDetails[song.id] = "Bağlantı bekleniyor...";
          notifyListeners();

          // Bağlantı gelene veya iptal edilene kadar bekle
          while (!_hasConnection && !_cancelingDownloads.contains(song.id)) {
            await Future.delayed(const Duration(milliseconds: 500));
          }

          if (_cancelingDownloads.contains(song.id)) break;

          _downloadDetails[song.id] = "İndirme devam ediyor...";
          notifyListeners();
        }

        try {
          // 2. Mevcut dosya boyutunu kontrol et (Kaldığı yeri bulmak için)
          int downloadedBytes = 0;
          if (await file.exists()) {
            downloadedBytes = await file.length();
          }

          // 3. İndirme isteği (Range header ile kaldığı yerden ister)
          final response = await dio.get<ResponseBody>(
            song.audioUrl,
            options: Options(
              responseType: ResponseType.stream,
              headers: downloadedBytes > 0
                  ? {'range': 'bytes=$downloadedBytes-'}
                  : null,
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
                _downloadProgress[song.id] = currentTotal / totalBytes;

                // MB Detay
                final double receivedMB = currentTotal / (1024 * 1024);
                final double totalMB = totalBytes / (1024 * 1024);
                _downloadDetails[song.id] =
                    "${receivedMB.toStringAsFixed(1)} MB / ${totalMB.toStringAsFixed(1)} MB";

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
            isDownloaded = true; // Başarıyla bitti, döngüden çık
          } finally {
            await sink.close();
          }
        } catch (e) {
          if (e is DioException && CancelToken.isCancel(e)) {
            rethrow; // İptal edildiyse dışarı fırlat
          }
          // Kullanıcı iptal etmediyse ve hata aldıysak (örneğin internet koptu)
          // Döngü başa dönecek ve internet kontrolü yapacak.
          if (_cancelingDownloads.contains(song.id)) {
            throw DioException(
              requestOptions: RequestOptions(),
              type: DioExceptionType.cancel,
            );
          }

          debugPrint(
            "İndirme kesildi, bağlantı bekleniyor veya tekrar deneniyor: $e",
          );
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      // Döngüden iptal ile çıkıldıysa hata fırlat
      if (_cancelingDownloads.contains(song.id)) {
        throw DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.cancel,
        );
      }

      // Resmi de indir
      try {
        await dio.download(song.coverUrl, imagePath);
        song.localImagePath = imagePath;
      } catch (e) {
        debugPrint("Resim indirme hatası: $e");
      }

      // Başarılı ise listeye ekle
      song.localPath = savePath;
      song.dateAdded = DateTime.now();
      _downloadedSongs.add(song);
      await _saveDownloadedSongs();

      // İlerleme snackbar'ını gizle ve başarı snackbar'ını göster
      if (navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(
          navigatorKey.currentContext!,
        ).hideCurrentSnackBar();
        CustomSnackBar.showSuccess(
          context: navigatorKey.currentContext!,
          message: "İndirme Tamamlandı: ${song.title}",
        );
      }

      try {
        _showDownloadNotification(song); // İndirme bitince bildirim göster
      } catch (e) {
        debugPrint("Bitiş bildirimi hatası: $e");
      }
    } catch (e) {
      // İlerleme snackbar'ını gizle
      if (navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(
          navigatorKey.currentContext!,
        ).hideCurrentSnackBar();
      }
      // Hata durumunda bildirimi iptal et
      _cancelNotification(song.id);

      // Hata türünü güvenli bir şekilde kontrol ediyoruz
      if (e is DioException && CancelToken.isCancel(e)) {
        debugPrint("İndirme iptal edildi: ${song.title}");

        // İptal edildiyse yarım kalan dosyayı sil
        if (await file.exists()) await file.delete();

        if (navigatorKey.currentContext != null) {
          CustomSnackBar.showError(
            context: navigatorKey.currentContext!,
            message: "İndirme iptal edildi",
          );
        }
      } else {
        debugPrint("İndirme hatası: $e");
        _playbackError = "İndirme başarısız oldu.";
        rethrow; // Hatayı fırlat ki UI (TrendPage vb.) yakalayabilsin
      }
    } finally {
      // Temizlik
      _downloadProgress.remove(song.id);
      _downloadDetails.remove(song.id);
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

    if (total > 0) {
      progress = ((received / total) * 100).toInt();
      final double receivedMB = received / (1024 * 1024);
      final double totalMB = total / (1024 * 1024);
      sizeInfo =
          "${receivedMB.toStringAsFixed(1)} MB / ${totalMB.toStringAsFixed(1)} MB";
    } else {
      indeterminate = true;
      sizeInfo = "Boyut hesaplanıyor...";
    }

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
        );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      song.id.hashCode,
      'İndiriliyor...',
      song.title,
      platformChannelSpecifics,
    );
  }

  Future<void> _cancelNotification(String songId) async {
    await _notificationsPlugin.cancel(songId.hashCode);
  }

  /// İndirmeyi iptal eder
  void cancelDownload(String songId) {
    if (_downloadCancelTokens.containsKey(songId)) {
      _cancelingDownloads.add(songId);
      notifyListeners(); // UI'ı güncelle ("İptal Ediliyor..." göstermek için)
      _downloadCancelTokens[songId]!.cancel();
      _cancelNotification(songId); // Bildirimi iptal et
      // State temizliği ve UI güncellemesi downloadSong metodunun finally bloğunda yapılacak
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
      CustomSnackBar.showInfo(
        context: navigatorKey.currentContext!,
        message: "${song.title} sıraya eklendi",
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
      CustomSnackBar.showInfo(
        context: navigatorKey.currentContext!,
        message: "${songs.length} şarkı sıraya eklendi",
      );
    }
  }

  /// Geçiş reklamını yükler
  void _loadInterstitialAd() {
    if (!Platform.isAndroid && !Platform.isIOS)
      return; // Sadece mobil için çalıştır
    InterstitialAd.load(
      adUnitId: Platform.isAndroid
          ? 'ca-app-pub-7993140773979821/5116160803' // Android Test ID
          : 'ca-app-pub-3940256099942544/4411468910', // iOS Test ID
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('InterstitialAd failed to load: $error');
          _isAdLoaded = false;
        },
      ),
    );
  }

  /// Sayaç kontrolü yapar ve gerekirse reklam gösterir
  Future<void> _checkAndShowAd() async {
    _songsPlayedCounter++;
    // Eğer sayaç frekansa ulaştıysa ve reklam yüklüyse
    if (_songsPlayedCounter % _adFrequency == 0 &&
        _isAdLoaded &&
        _interstitialAd != null) {
      final Completer<void> completer = Completer<void>();
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          ad.dispose();
          _isAdLoaded = false;
          _loadInterstitialAd(); // Bir sonraki için yenisini yükle
          completer.complete();
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          ad.dispose();
          _isAdLoaded = false;
          _loadInterstitialAd();
          completer.complete();
        },
      );
      await _interstitialAd!.show();
      await completer.future; // Reklam kapanana kadar bekle
    }
  }

  Future<void> playSong(Song song, List<Song> playlist) async {
    _addToRecentlyPlayed(song);

    // Servis başlatılmadıysa başlatmayı dene (Örn: İlk açılışta hata olduysa)
    if (!_isAudioServiceInitialized) {
      try {
        await _initAudioService();
      } catch (e) {
        debugPrint("AudioService başlatılamadı: $e");
        return;
      }
    }

    // Reklam kontrolü (Şarkı başlamadan önce)
    await _checkAndShowAd();

    _pendingSongId = song.id; // Hedef şarkıyı işaretle

    _isSongLoading = true;
    _playbackError = null; // Yeni şarkıya başlarken hatayı sıfırla

    bool isNewPlaylist = _playlist != playlist;
    _playlist = playlist;
    _currentSongIndex = _playlist.indexWhere((s) => s.id == song.id);

    // Şarkı listede bulunamadıysa işlemi durdur
    if (_currentSongIndex == -1) {
      _isSongLoading = false;
      notifyListeners();
      return;
    }

    notifyListeners(); // UI'ı hemen güncelle (Loading ve Yeni Şarkı İsmi)

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
            await _audioHandler.playSong(mediaItem, downloadedSong.localPath!);
            _isSongLoading = false;
            notifyListeners();
            return; // Yerelden çalındı, fonksiyondan çık
          }
        }

        // Normal URL
        if (_pendingSongId != song.id) return;

        await _audioHandler.playSong(mediaItem, song.audioUrl);

        // İşlem bittiğinde hala aynı şarkıdaysak loading'i kapat
        if (_pendingSongId == song.id) {
          notifyListeners();
        }
      } catch (e) {
        if (_pendingSongId != song.id)
          return; // Şarkı değiştiyse hatayı gösterme
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
        if (_loopMode == LoopMode.off && !userInitiated) return; // Dur
        nextIndex = _shuffledIndices[0]; // Başa dön
      } else {
        nextIndex = _shuffledIndices[currentShuffledIndex + 1];
      }
    } else {
      // Normal sıralama
      if (_currentSongIndex! + 1 >= _playlist.length) {
        // Listenin sonu
        if (_loopMode == LoopMode.off && !userInitiated) return; // Dur
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

  @override
  void dispose() {
    _audioHandler.stop();
    super.dispose();
  }
}
