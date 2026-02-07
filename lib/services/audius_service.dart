import 'package:dio/dio.dart';
import 'package:muzik_app/models/song_model.dart';

class AudiusService {
  // Audius Discovery Provider (Node)
  static const String _baseUrl = 'https://discoveryprovider.audius.co';
  static const String _appName = 'OYN Music';

  /// Trend şarkıları çeker
  static Future<List<Song>> getTrendingSongs({
    String? genre,
    int limit = 20,
    int offset = 0,
  }) async {
    final dio = Dio();
    try {
      final Map<String, dynamic> queryParams = {
        'limit': limit,
        'offset': offset,
        'app_name': _appName,
      };

      if (genre != null) {
        queryParams['genre'] = genre;
      }

      final response = await dio.get(
        '$_baseUrl/v1/tracks/trending',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        return data.map((e) => Song.fromAudiusJson(e)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Audius Trending Hatası: $e');
    }
  }

  /// Şarkı veya sanatçı araması yapar
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
        return data.map((e) => Song.fromAudiusJson(e)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Audius Arama Hatası: $e');
    }
  }
}
