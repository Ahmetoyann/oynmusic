// lib/models/song_model.dart

// Bu dosya, uygulama genelinde kullanılacak veri modellerini ve ilgili uzantıları içerir.

// =============================================================
// VERİ MODELLERİ
// =============================================================

/// Uygulama genelinde bir şarkıyı temsil eden sınıf.
class Song {
  final String id;
  final String title;
  final String artist;
  final String coverUrl;
  final String audioUrl;
  int? duration; // Şarkı süresi (saniye cinsinden)
  final String? lyrics;
  String? localPath; // İndirilen dosyanın yerel yolu
  String? localImagePath; // İndirilen kapak resminin yerel yolu
  DateTime? lastPlayed; // Son oynatılma zamanı
  DateTime? dateAdded; // Eklenme tarihi (Favori veya İndirme)

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.coverUrl,
    required this.audioUrl,
    this.duration,
    this.lyrics,
    this.localPath,
    this.localImagePath,
    this.lastPlayed,
    this.dateAdded,
  });

  /// Deezer API'den gelen JSON verisini bir Song nesnesine dönüştüren fabrika metodu.
  /// Çalma listesi (playlist) API'sinin formatına göre güncellendi.
  factory Song.fromJson(Map<String, dynamic> json) {
    // 'artist' ve 'album' bilgilerini JSON içindeki ayrı nesneler olarak alıyoruz.
    final artistInfo = json['artist'] as Map<String, dynamic>?;
    final albumInfo = json['album'] as Map<String, dynamic>?;

    return Song(
      id: json['id'].toString(),
      title: json['title_short'] ?? 'İsimsiz Şarkı',
      artist: artistInfo?['name'] ?? 'Bilinmeyen Sanatçı',

      // Kapak resmini 'album' nesnesinin içindeki 'cover_medium' alanından alıyoruz.
      // Eğer bu alanlar boş (null) gelirse, varsayılan bir yer tutucu resim kullanıyoruz.
      coverUrl: albumInfo?['cover_medium'] ?? 'https://via.placeholder.com/250',

      // Önizleme ses URL'sini alıyoruz.
      audioUrl: json['preview'] ?? '',
      duration: json['duration'] ?? 0,
      // API'den şarkı sözü gelmediği için şimdilik null bırakıyoruz.
      lyrics: null,
    );
  }

  /// Pixabay Video API'den gelen JSON verisini Song nesnesine dönüştüren fabrika metodu.
  factory Song.fromPixabayVideoJson(Map<String, dynamic> json) {
    final videos = json['videos'] as Map<String, dynamic>?;
    // Müzik çalar için 'tiny' veya 'small' boyutundaki video URL'sini alıyoruz (daha hızlı yükleme için).
    final String videoUrl =
        videos?['tiny']?['url'] ?? videos?['small']?['url'] ?? '';

    // Pixabay videoları için kapak resmi (picture_id kullanılarak oluşturulur)
    final String pictureId = json['picture_id']?.toString() ?? '';
    final String thumbnailUrl = pictureId.isNotEmpty
        ? 'https://i.vimeocdn.com/video/${pictureId}_640x360.jpg'
        : 'https://via.placeholder.com/250';

    return Song(
      id: json['id'].toString(),
      title: json['tags'] ?? 'İsimsiz Video',
      artist: json['user'] ?? 'Pixabay Sanatçısı',
      coverUrl: thumbnailUrl,
      audioUrl: videoUrl,
      duration: json['duration'] ?? 0,
      lyrics: null,
    );
  }

  /// Pixabay Audio API'den gelen JSON verisini Song nesnesine dönüştüren fabrika metodu.
  factory Song.fromPixabayAudioJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'].toString(),
      title: json['tags'] ?? 'İsimsiz Müzik',
      artist: json['user'] ?? 'Pixabay Sanatçısı',
      coverUrl: json['userImageURL'] ?? 'https://via.placeholder.com/250',
      audioUrl: json['preview'] ?? '',
      duration: json['duration'] ?? 0,
      lyrics: null,
    );
  }

  /// Jamendo API'den gelen JSON verisini Song nesnesine dönüştüren fabrika metodu.
  factory Song.fromJamendoJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'].toString(),
      title: json['name'] ?? 'İsimsiz Şarkı',
      artist: json['artist_name'] ?? 'Bilinmeyen Sanatçı',
      coverUrl: json['image'] ?? 'https://via.placeholder.com/250',
      audioUrl: json['audio'] ?? '',
      duration: json['duration'] ?? 0,
      lyrics: null,
    );
  }

  /// YouTube API'den gelen JSON verisini Song nesnesine dönüştüren fabrika metodu.
  factory Song.fromYoutubeJson(Map<String, dynamic> json) {
    final snippet = json['snippet'];
    final videoId = json['id']['videoId'];

    return Song(
      id: videoId,
      title: snippet['title'] ?? 'İsimsiz Video',
      artist: snippet['channelTitle'] ?? 'YouTube Kanalı',
      // Yüksek çözünürlüklü kapak resmi varsa al, yoksa varsayılanı kullan
      coverUrl:
          snippet['thumbnails']['high']?['url'] ??
          snippet['thumbnails']['default']?['url'] ??
          'https://via.placeholder.com/250',
      // Not: Bu URL doğrudan oynatılamaz. youtube_explode_dart gibi bir paket ile stream URL'ine çevrilmelidir.
      audioUrl: 'https://www.youtube.com/watch?v=$videoId',
      duration: 0, // Search endpoint süre bilgisi döndürmez
      lyrics: null,
    );
  }

  /// YouTube Video Details API'den gelen (contentDetails içeren) JSON verisini işler.
  factory Song.fromYoutubeVideoJson(Map<String, dynamic> json) {
    final snippet = json['snippet'];
    final contentDetails = json['contentDetails'];
    final videoId = json['id']; // 'videos' endpointinde ID string olarak gelir.

    return Song(
      id: videoId,
      title: snippet['title'] ?? 'İsimsiz Video',
      artist: snippet['channelTitle'] ?? 'YouTube Kanalı',
      coverUrl:
          snippet['thumbnails']['high']?['url'] ??
          snippet['thumbnails']['medium']?['url'] ??
          snippet['thumbnails']['default']?['url'] ??
          'https://via.placeholder.com/250',
      audioUrl: 'https://www.youtube.com/watch?v=$videoId',
      duration: _parseDuration(contentDetails['duration']),
      lyrics: null,
    );
  }

  /// Audius API'den gelen JSON verisini Song nesnesine dönüştüren fabrika metodu.
  factory Song.fromAudiusJson(Map<String, dynamic> json) {
    final user = json['user'] ?? {};
    final artwork = json['artwork'] ?? {};
    final trackId = json['id'];

    return Song(
      id: trackId.toString(),
      title: json['title'] ?? 'İsimsiz Şarkı',
      artist: user['name'] ?? 'Bilinmeyen Sanatçı',
      coverUrl:
          artwork['480x480'] ??
          artwork['150x150'] ??
          'https://via.placeholder.com/250',
      audioUrl: 'https://discoveryprovider.audius.co/v1/tracks/$trackId/stream',
      duration: json['duration'] ?? 0,
      lyrics: null,
    );
  }

  /// ISO 8601 formatındaki süreyi (örn: PT1H15M30S) saniyeye çevirir.
  static int _parseDuration(String? durationString) {
    if (durationString == null || durationString.isEmpty) return 0;

    final RegExp regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final Match? match = regex.firstMatch(durationString);

    if (match == null) return 0;

    final int hours = int.parse(match.group(1) ?? '0');
    final int minutes = int.parse(match.group(2) ?? '0');
    final int seconds = int.parse(match.group(3) ?? '0');

    return (hours * 3600) + (minutes * 60) + seconds;
  }

  /// Yerel depolama için JSON dönüşümü
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'coverUrl': coverUrl,
      'audioUrl': audioUrl,
      'duration': duration,
      'lyrics': lyrics,
      'localPath': localPath,
      'localImagePath': localImagePath,
      'lastPlayed': lastPlayed?.toIso8601String(),
      'dateAdded': dateAdded?.toIso8601String(),
    };
  }

  /// Yerel depolamadan geri dönüşüm
  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['id'],
      title: map['title'],
      artist: map['artist'],
      coverUrl: map['coverUrl'],
      audioUrl: map['audioUrl'],
      duration: map['duration'],
      lyrics: map['lyrics'],
      localPath: map['localPath'],
      localImagePath: map['localImagePath'],
      lastPlayed: map['lastPlayed'] != null
          ? DateTime.parse(map['lastPlayed'])
          : null,
      dateAdded: map['dateAdded'] != null
          ? DateTime.parse(map['dateAdded'])
          : null,
    );
  }
}

/// İndirilen şarkılardan oluşturulan klasörleri (listeleri) temsil eden sınıf.
class MusicFolder {
  String name;
  final List<Song> songs;
  bool isFromDownloads; // Klasörün indirilenlerden mi oluşturulduğunu belirtir
  String? customImagePath; // Klasör için özel kapak resmi yolu

  MusicFolder({
    required this.name,
    required this.songs,
    this.isFromDownloads = false,
    this.customImagePath,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'songs': songs.map((s) => s.toJson()).toList(),
    'isFromDownloads': isFromDownloads,
    'customImagePath': customImagePath,
  };

  factory MusicFolder.fromJson(Map<String, dynamic> json) {
    return MusicFolder(
      name: json['name'],
      songs: (json['songs'] as List)
          .map((s) => Song.fromMap(s as Map<String, dynamic>))
          .toList(),
      isFromDownloads: json['isFromDownloads'] ?? false,
      customImagePath: json['customImagePath'],
    );
  }
}

// =============================================================
// EXTENSION (Uzantı)
// =============================================================

/// Song sınıfına, uygulama hafızasında indirme durumunu yönetme yeteneği ekler.
extension SongDownloadStatus on Song {
  // `static` bir harita, uygulama çalıştığı sürece durumu korur.
  // Bu, uygulama kapatıldığında sıfırlanır. Kalıcı depolama için veritabanı gerekir.
  static final Map<String, bool> _downloadStatus = {};

  /// Bir şarkının indirilip indirilmediğini döndürür.
  bool get isDownloaded => _downloadStatus[id] ?? false;

  /// Bir şarkının indirme durumunu ayarlar.
  set isDownloaded(bool value) {
    _downloadStatus[id] = value;
  }

  /// İndirme durumu önbelleğini temizler.
  static void clear() {
    _downloadStatus.clear();
  }
}

/// Song sınıfına, favori durumunu yönetme yeteneği ekler.
extension SongFavoriteStatus on Song {
  static final Set<String> _favorites = {};

  /// Şarkının favori olup olmadığını döndürür.
  bool get isFavorite => _favorites.contains(id);

  /// Şarkının favori durumunu ayarlar.
  set isFavorite(bool value) {
    if (value) {
      _favorites.add(id);
    } else {
      _favorites.remove(id);
    }
  }

  /// Kaydedilmiş favori listesini hafızaya yükler.
  static void loadFavorites(List<String> ids) {
    _favorites.addAll(ids);
  }

  /// Kaydetmek üzere mevcut favori ID listesini döndürür.
  static List<String> getFavoriteIds() => _favorites.toList();

  /// Favori listesi önbelleğini temizler.
  static void clear() {
    _favorites.clear();
  }
}

/// Şarkı süresini biçimlendirmek için eklenti.
extension SongDurationFormatter on Song {
  /// Süreyi "DK:SN" (örn: 04:20) formatında döndürür.
  String get formattedDuration {
    final totalSeconds = duration ?? 0;
    if (totalSeconds <= 0) return "00:00";
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}
