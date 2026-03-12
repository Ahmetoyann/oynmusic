import 'package:dio/dio.dart';
import 'package:muzik_app/models/song_model.dart';

class AudiusService {
  static const String _appName = 'OYN Music';
  static const String _baseUrl = 'https://discoveryprovider.audius.co';

  static const List<String> _bannedWords = [
    "sex",
    "porn",
    "xxx",
    "nude",
    "weed",
    "drug",
    "cocaine",
    "lean",
    "smoke",
    "beer",
    "alcohol",
    "vodka",
    "whiskey",
    "kill",
    "murder",
    "gun",
    "blood",
    "violence",
  ];

  static bool _isSafeContent(dynamic trackData) {
    if (trackData == null) return false;

    bool hasBannedWord(String? text) {
      if (text == null || text.isEmpty) return false;
      final lowerText = text.toLowerCase();
      for (final word in _bannedWords) {
        if (lowerText.contains(word)) return true;
      }
      return false;
    }

    final title = trackData['title']?.toString();
    final description = trackData['description']?.toString();
    final genre = trackData['genre']?.toString();
    String? artistName;
    if (trackData['user'] != null && trackData['user'] is Map) {
      artistName = trackData['user']['name']?.toString();
    }

    if (hasBannedWord(title)) return false;
    if (hasBannedWord(artistName)) return false;
    if (hasBannedWord(genre)) return false;
    if (hasBannedWord(description)) return false;

    // Resim kontrolü: Artwork alanı yoksa veya boşsa filtrele
    final artwork = trackData['artwork'];
    if (artwork == null) return false;

    // Song.fromAudiusJson Map bekliyor ve belirli keyleri arıyor
    if (artwork is! Map || artwork.isEmpty) return false;

    // Placeholder oluşmasını engellemek için geçerli boyut kontrolü
    if (artwork['150x150'] == null && artwork['480x480'] == null) return false;

    return true;
  }

  /// Trend şarkıları çeker
  static Future<List<Song>> getTrendingSongs({
    String? genre,
    String? timeRange,
    int limit = 20,
    int offset = 0,
  }) async {
    final dio = Dio();
    try {
      final Map<String, dynamic> queryParams = {
        'app_name': _appName,
        'limit': limit,
        'offset': offset,
      };

      if (genre != null && genre != 'Hepsi') {
        queryParams['genre'] = genre;
      }

      if (timeRange != null) {
        queryParams['time'] = timeRange;
      }

      final response = await dio.get(
        '$_baseUrl/v1/tracks/trending',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        return data
            .where((e) => _isSafeContent(e))
            .map((e) => Song.fromAudiusJson(e))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Audius Trending Hatası: $e');
    }
  }

  /// Şarkı araması yapar
  static Future<List<Song>> searchSongs(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    final dio = Dio();
    try {
      final response = await dio.get(
        '$_baseUrl/v1/tracks/search',
        queryParameters: {
          'query': query,
          'app_name': _appName,
          'limit': limit,
          'offset': offset,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        return data
            .where((e) => _isSafeContent(e))
            .map((e) => Song.fromAudiusJson(e))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Audius Arama Hatası: $e');
    }
  }
}
