import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:muzik_app/services/audio_handler.dart';
import 'package:muzik_app/services/youtube_api_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:muzik_app/models/song_model.dart';

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
  List<Song> _searchResults = [];
  bool _isSearchLoading = false;
  int _searchOffset = 0; // Arama sonuçları için sayfa takibi
  bool _isSearchLoadingMore = false; // Arama sonuçlarını yükleme durumu
  Timer? _searchDebounce;
  bool _isLoadingMore = false; // Ekstra yükleme yapılıyor mu?
  List<String> _searchHistory = [];
  final YoutubeExplode _yt = YoutubeExplode(); // YouTube veri çekme aracı
  String? _youtubeNextPageToken; // YouTube sayfalama token'ı
  String? _trendsNextPageToken; // Trendler sayfası için token
  bool _isLowDataMode = false; // Düşük veri modu (Düşük kalite ses)
  bool _isSongLoading = false; // Şarkı hazırlanıyor mu?
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
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get playbackError => _playbackError;
  bool get isSearchLoading => _isSearchLoading;
  bool get isSearchLoadingMore => _isSearchLoadingMore;
  bool get isLoadingMore => _isLoadingMore;
  List<String> get categories => _categories;
  List<String> get searchHistory => _searchHistory;
  bool get isLowDataMode => _isLowDataMode;
  bool get isSongLoading => _isSongLoading;

  Song? get currentSong =>
      _currentSongIndex != null ? _playlist[_currentSongIndex!] : null;

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
    fetchCategories();
    fetchSongsFromApi();
    _loadSettings();
  }

  /// AuthProvider'dan kullanıcı bilgisini günceller
  void updateUser(User? user) {
    _currentUser = user;
    if (_currentUser != null) {
      _syncFavoritesWithFirestore();
      _syncFoldersWithFirestore();
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

  Future<void> fetchSongsFromApi({String? genre}) async {
    _currentGenre = genre;

    _isLoading = true;
    _trendsNextPageToken = null; // Token'ı sıfırla
    _errorMessage = null;
    // Yeni bir tür seçildiyse listeyi temizle ki kullanıcı yükleniyor görsün
    if (genre != null) _allSongs = [];
    notifyListeners();

    try {
      await _initAudioService();

      YoutubeSearchResult result;

      // Eğer "Hepsi" seçiliyse veya tür yoksa Trendleri çek
      if (genre == null || genre == 'Hepsi') {
        result = await YoutubeApiService.fetchPopularSongs();
      } else {
        // Bir tür seçildiyse (örn: Rock), YouTube'da arama yap
        // "Rock music" şeklinde aratarak daha alakalı sonuçlar alabiliriz
        result = await YoutubeApiService.searchVideos("$genre music");
      }

      _allSongs = result.songs;
      _trendsNextPageToken = result.nextPageToken;
      _errorMessage = null;
    } catch (e) {
      debugPrint("Şarkı çekme hatası: $e");
      _errorMessage = "Şarkılar yüklenemedi. Lütfen tekrar deneyin.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Listenin sonuna gelindiğinde daha fazla şarkı yükler
  Future<void> loadMoreSongs() async {
    // Zaten yükleniyorsa veya arama yapılıyorsa (arama sonuçları sayfalı değilse) işlem yapma
    if (_isLoadingMore || _isLoading || isSearching) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      YoutubeSearchResult result;

      if (_currentGenre == null || _currentGenre == 'Hepsi') {
        // Trendlerin devamını yükle
        result = await YoutubeApiService.fetchPopularSongs(
          pageToken: _trendsNextPageToken,
        );
      } else {
        // Kategori aramasının devamını yükle
        result = await YoutubeApiService.searchVideos(
          "$_currentGenre music",
          pageToken: _trendsNextPageToken,
        );
      }

      if (result.songs.isNotEmpty) {
        _allSongs.addAll(result.songs);
        _trendsNextPageToken = result.nextPageToken;
      }
    } catch (e) {
      debugPrint("Daha fazla şarkı yüklenirken hata: $e");
      rethrow; // Hatayı fırlat ki TrendPage yakalayabilsin
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
          androidNotificationChannelId: 'com.muzikapp.channel.audio',
          androidNotificationChannelName: 'Müzik Çalar',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      );

      // Şarkı bittiğinde otomatik geçiş
      _audioHandler.audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          playNext();
        }
      });

      // Bildirimden gelen Sonraki/Önceki komutlarını dinle
      _audioHandler.skipNextStream.listen((_) => playNext());
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
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .set({
            'favorites': _favoriteSongs.map((s) => s.toJson()).toList(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Firestore güncelleme hatası: $e");
    }
  }

  /// Klasörleri Firestore'a kaydeder
  Future<void> _updateFirestoreFolders() async {
    if (_currentUser == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .set({
            'folders': _folders.map((f) => f.toJson()).toList(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Firestore folders güncelleme hatası: $e");
    }
  }

  /// Tüm önbelleği (indirilenler ve favoriler) temizler
  Future<void> clearCache() async {
    try {
      // 1. Favorileri temizle (SharedPreferences)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('favorite_songs');
      await prefs.remove('favorite_songs_objects');

      // 2. Hafızadaki durumları sıfırla
      // SongDownloadStatus.clear(); // Artık kullanılmıyor
      SongFavoriteStatus.clear();
      _favoriteSongs.clear();

      notifyListeners();
    } catch (e) {
      debugPrint("Önbellek temizlenirken hata: $e");
      rethrow;
    }
  }

  void createFolder({required String name, required List<Song> songs}) {
    if (name.isNotEmpty && songs.isNotEmpty) {
      final newFolder = MusicFolder(name: name, songs: List.from(songs));
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

  /// Oynatma hatasını temizler
  void clearPlaybackError() {
    _playbackError = null;
    notifyListeners();
  }

  void updateSearchText(String text) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchText = text;
    notifyListeners();

    if (text.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      // Jamendo yerine YouTube aramasını kullanıyoruz
      searchYoutube(text);
    });
  }

  /// YouTube üzerinden arama yapar (Jamendo yerine bunu kullanabilirsiniz)
  Future<void> searchYoutube(String query) async {
    _isSearchLoading = true;
    _searchOffset = 0;
    _youtubeNextPageToken = null; // Yeni aramada token'ı sıfırla
    notifyListeners();

    try {
      final result = await YoutubeApiService.searchVideos(query);
      _searchResults = result.songs;
      _youtubeNextPageToken = result.nextPageToken;
    } catch (e) {
      debugPrint("YouTube Arama hatası: $e");
      _searchResults = [];
      _youtubeNextPageToken = null;
    } finally {
      _isSearchLoading = false;
      notifyListeners();
    }
  }

  /// Arama sonuçlarının devamını yükler (Sonsuz Kaydırma)
  Future<void> loadMoreSearchResults() async {
    // Eğer yükleniyorsa, arama metni boşsa veya sonraki sayfa yoksa işlem yapma
    if (_isSearchLoadingMore ||
        _isSearchLoading ||
        _searchText.isEmpty ||
        _youtubeNextPageToken == null)
      return;

    _isSearchLoadingMore = true;
    notifyListeners();

    try {
      final result = await YoutubeApiService.searchVideos(
        _searchText,
        pageToken: _youtubeNextPageToken,
      );

      if (result.songs.isNotEmpty) {
        _searchResults.addAll(result.songs);
        _youtubeNextPageToken = result.nextPageToken;
      }
    } catch (e) {
      debugPrint("Daha fazla arama sonucu yüklenirken hata: $e");
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

  Future<void> playSong(Song song, List<Song> playlist) async {
    // Servis başlatılmadıysa başlatmayı dene (Örn: İlk açılışta hata olduysa)
    if (!_isAudioServiceInitialized) {
      try {
        await _initAudioService();
      } catch (e) {
        debugPrint("AudioService başlatılamadı: $e");
        return;
      }
    }

    _isSongLoading = true;
    _playbackError = null; // Yeni şarkıya başlarken hatayı sıfırla
    notifyListeners();

    _playlist = playlist;
    _currentSongIndex = _playlist.indexWhere((s) => s.id == song.id);
    if (_currentSongIndex != -1) {
      try {
        String playUri = song.audioUrl;

        // YouTube URL'si ise gerçek ses akışını (stream) çöz
        if (playUri.contains('youtube.com') || playUri.contains('youtu.be')) {
          try {
            // Video ID'sini kullanarak manifest dosyasını al
            var manifest = await _yt.videos.streamsClient
                .getManifest(song.id)
                .timeout(const Duration(seconds: 30)); // 30 saniye zaman aşımı

            // Sadece MP4 (m4a) formatını seçiyoruz, WebM/Opus kullanmıyoruz.
            var audioStreamInfo = manifest.audioOnly
                .where((e) => e.container.name == 'mp4')
                .withHighestBitrate();

            playUri = audioStreamInfo.url.toString();
            debugPrint("Oynatılacak URL: $playUri"); // Debug için URL'i yazdır
          } catch (e) {
            debugPrint("YouTube Stream Hatası: $e");
            if (e is TimeoutException) {
              _playbackError =
                  "Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.";
            } else {
              _playbackError =
                  "Bu şarkı oynatılamıyor: ${e.toString().replaceAll('Exception:', '').trim()}";
            }
            return; // finally bloğu çalışacak ve loading kapanacak
          }
        }

        // Bildirimde görünecek veriyi hazırla
        final mediaItem = MediaItem(
          id: song.id,
          album: "Müzik App",
          title: song.title,
          artist: song.artist,
          artUri: Uri.parse(song.coverUrl),
          duration: Duration(seconds: song.duration ?? 0),
        );

        // Handler üzerinden çal
        await _audioHandler.playSong(mediaItem, playUri);
        notifyListeners();
      } catch (e) {
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
        _isSongLoading = false;
        notifyListeners();
      }
    } else {
      _isSongLoading = false;
      notifyListeners();
    }
  }

  Future<void> playNext() async {
    if (_playlist.isNotEmpty && _currentSongIndex != null) {
      int nextIndex = (_currentSongIndex! + 1) % _playlist.length;
      await playSong(_playlist[nextIndex], _playlist);
    }
  }

  Future<void> playPrevious() async {
    if (_playlist.isNotEmpty && _currentSongIndex != null) {
      int prevIndex =
          (_currentSongIndex! - 1 + _playlist.length) % _playlist.length;
      await playSong(_playlist[prevIndex], _playlist);
    }
  }

  @override
  void dispose() {
    _yt.close();
    _audioHandler.stop();
    super.dispose();
  }
}
