import 'package:muzik_app/models/song_model.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YoutubeService {
  /// Trend şarkıları çeker (Kota gerektirmeyen YoutubeExplode yöntemi)
  static Future<List<Song>> getTrendingSongs({
    String? genre,
    String? timeRange,
    int limit = 20,
    int offset = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey =
        'yt_trending_${genre ?? "all"}_${timeRange ?? "all"}_${limit}_$offset';
    final cacheTimeKey = '${cacheKey}_time';

    // 1. Önbelleği Kontrol Et (12 Saat Geçerli)
    final cachedData = prefs.getString(cacheKey);
    final cacheTimeStr = prefs.getString(cacheTimeKey);
    if (cachedData != null && cacheTimeStr != null) {
      final cacheTime = DateTime.parse(cacheTimeStr);
      if (DateTime.now().difference(cacheTime).inHours < 12) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded
            .map((e) => Song.fromMap(e as Map<String, dynamic>))
            .toList();
      }
    }

    final yt = YoutubeExplode();
    try {
      // YouTube'da doğrudan trend endpoint'i olmadığı için popüler müzik terimleriyle dinamik arama yapıyoruz.
      String searchQuery = 'popüler türkçe müzik hit şarkılar';
      if (genre != null && genre != 'Hepsi') {
        searchQuery = 'en iyi $genre şarkılar popüler';
      }

      var searchResults = await yt.search.search(searchQuery);
      List<Video> videos = searchResults.whereType<Video>().toList();

      // Yükleme sırasında ofseti yakalamak için gerekirse sonraki sayfaları çek
      try {
        while (videos.length < offset + limit) {
          final nextPage = await searchResults.nextPage();
          if (nextPage == null || nextPage.isEmpty) break;
          videos.addAll(nextPage.whereType<Video>());
          searchResults = nextPage;
        }
      } catch (pageError) {
        // Sonraki sayfaları çekerken YouTube bot korumasına takılırsa,
        // işlemi tamamen çökertmek yerine başarıyla çektiğimiz kadarıyla devam edelim.
        print("Sayfalama hatası (Trend): $pageError");
      }

      final targetVideos = videos.skip(offset).take(limit).toList();
      final songs = targetVideos.map((video) {
        return Song(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          coverUrl: video.thumbnails.highResUrl,
          audioUrl:
              '', // Çalma sırasında SongProvider içinde yt.streamsClient ile çözülecek
          duration: video.duration?.inSeconds,
        );
      }).toList();

      // 2. Yeni veriyi önbelleğe al
      await prefs.setString(
        cacheKey,
        jsonEncode(songs.map((s) => s.toJson()).toList()),
      );
      await prefs.setString(cacheTimeKey, DateTime.now().toIso8601String());

      return songs;
    } catch (e) {
      throw Exception('Trend Şarkı Çekme Hatası: $e');
    } finally {
      yt.close();
    }
  }

  /// Şarkı araması yapar (Kota gerektirmeyen YoutubeExplode yöntemi)
  static Future<List<Song>> searchSongs(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'yt_search_${query.toLowerCase()}_${limit}_$offset';
    final cacheTimeKey = '${cacheKey}_time';

    // 1. Önbelleği Kontrol Et (24 saat geçerli)
    final cachedData = prefs.getString(cacheKey);
    final cacheTimeStr = prefs.getString(cacheTimeKey);
    if (cachedData != null && cacheTimeStr != null) {
      final cacheTime = DateTime.parse(cacheTimeStr);
      if (DateTime.now().difference(cacheTime).inHours < 24) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded
            .map((e) => Song.fromMap(e as Map<String, dynamic>))
            .toList();
      }
    }

    final yt = YoutubeExplode();
    try {
      var searchResults = await yt.search.search(query);
      List<Video> videos = searchResults.whereType<Video>().toList();

      // Yükleme sırasında ofseti yakalamak için gerekirse sonraki sayfaları çek
      try {
        while (videos.length < offset + limit) {
          final nextPage = await searchResults.nextPage();
          if (nextPage == null || nextPage.isEmpty) break;
          videos.addAll(nextPage.whereType<Video>());
          searchResults = nextPage;
        }
      } catch (pageError) {
        print("Sayfalama hatası (Arama): $pageError");
      }

      final targetVideos = videos.skip(offset).take(limit).toList();
      final songs = targetVideos.map((video) {
        return Song(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          coverUrl: video.thumbnails.highResUrl,
          audioUrl: '', // Çalma sırasında çözülecek
          duration: video.duration?.inSeconds,
        );
      }).toList();

      // 2. Yeni sonuçları önbelleğe kaydet
      await prefs.setString(
        cacheKey,
        jsonEncode(songs.map((s) => s.toJson()).toList()),
      );
      await prefs.setString(cacheTimeKey, DateTime.now().toIso8601String());

      return songs;
    } catch (e) {
      throw Exception('Arama Hatası: $e');
    } finally {
      yt.close();
    }
  }
}
