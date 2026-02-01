import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:muzik_app/services/audio_handler.dart';
import 'package:muzik_app/services/music_api_service.dart';
import 'package:muzik_app/models/song_model.dart';

class SongProvider with ChangeNotifier {
  List<Song> _allSongs = [];
  List<Song> _favoriteSongs = []; // Favori şarkı nesnelerini tutacak yeni liste
  User? _currentUser; // Giriş yapmış kullanıcı
  bool _isLocalFavoritesLoaded = false; // Yerel favorilerin yüklenme durumu
  bool _isLocalFoldersLoaded = false; // Yerel klasörlerin yüklenme durumu
  bool _isLoading = true;
  String? _errorMessage;
  final List<MusicFolder> _folders = [];
  // AudioHandler referansı (geç başlatılacak)
  late MyAudioHandler _audioHandler;
  bool _isAudioServiceInitialized = false;
  List<Song> _playlist = [];
  int? _currentSongIndex;
  String _searchText = '';
  int _currentOffset = 0; // Kaçıncı şarkıda kaldığımızı tutar
  String? _currentGenre; // Şu anki kategoriyi tutar
  List<Song> _searchResults = [];
  bool _isSearchLoading = false;
  int _searchOffset = 0; // Arama sonuçları için sayfa takibi
  bool _isSearchLoadingMore = false; // Arama sonuçlarını yükleme durumu
  Timer? _searchDebounce;
  bool _isLoadingMore = false; // Ekstra yükleme yapılıyor mu?
  List<String> _searchHistory = [];
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
  bool get isSearchLoading => _isSearchLoading;
  bool get isSearchLoadingMore => _isSearchLoadingMore;
  bool get isLoadingMore => _isLoadingMore;
  List<String> get categories => _categories;
  List<String> get searchHistory => _searchHistory;

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
    _currentOffset = 0; // Listeyi sıfırla
    _errorMessage = null;
    // Yeni bir tür seçildiyse listeyi temizle ki kullanıcı yükleniyor görsün
    if (genre != null) _allSongs = [];
    notifyListeners();

    try {
      await _initAudioService(); // Servisi başlat
      // İlk 50 şarkıyı çek
      _allSongs = await JamendoApiService.fetchSongs(
        genre: genre,
        limit: 50,
        offset: 0,
      );
      _currentOffset = 50; // Offset'i güncelle
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
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
      final newSongs = await JamendoApiService.fetchSongs(
        genre: _currentGenre,
        limit: 50,
        offset: _currentOffset,
      );

      if (newSongs.isNotEmpty) {
        _allSongs.addAll(newSongs); // Yeni şarkıları ekle
        _currentOffset += 50; // Sayfayı ilerlet
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
    try {
      final tags = await JamendoApiService.fetchTags();
      if (tags.isNotEmpty) {
        final formattedTags = tags.map((t) {
          if (t.isEmpty) return t;
          return t[0].toUpperCase() + t.substring(1);
        }).toList();
        _categories = ['Hepsi', ...formattedTags];
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Kategoriler yüklenirken hata: $e");
    }
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
      _performSearch(text);
    });
  }

  Future<void> _performSearch(String query) async {
    _isSearchLoading = true;
    _searchOffset = 0; // Yeni aramada offset'i sıfırla
    notifyListeners();

    try {
      _searchResults = await JamendoApiService.fetchSongs(
        searchQuery: query,
        limit: 20,
        offset: 0,
      );
      _searchOffset = 20; // İlk 20 yüklendi, sonraki 20 için hazırla
    } catch (e) {
      debugPrint("Arama hatası: $e");
    } finally {
      _isSearchLoading = false;
      notifyListeners();
    }
  }

  /// Arama sonuçlarının devamını yükler (Sonsuz Kaydırma)
  Future<void> loadMoreSearchResults() async {
    if (_isSearchLoadingMore || _isSearchLoading || _searchText.isEmpty) return;

    _isSearchLoadingMore = true;
    notifyListeners();

    try {
      final newSongs = await JamendoApiService.fetchSongs(
        searchQuery: _searchText,
        limit: 20,
        offset: _searchOffset,
      );

      if (newSongs.isNotEmpty) {
        _searchResults.addAll(newSongs);
        _searchOffset += 20;
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
    _playlist = playlist;
    _currentSongIndex = _playlist.indexWhere((s) => s.id == song.id);
    if (_currentSongIndex != -1) {
      try {
        String playUri = song.audioUrl;

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
        print("Ses çalınırken hata oluştu: $e");
      }
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
    _audioHandler.stop();
    super.dispose();
  }
}
