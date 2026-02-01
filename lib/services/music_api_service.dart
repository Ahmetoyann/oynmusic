import 'package:muzik_app/models/song_model.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class JamendoApiService {
  static const String _baseUrl = 'https://api.jamendo.com/v3.0';
  static const String _clientId = 'fef06e78'; // Senin client_id

  // Tür (genre) parametresi eklendi. Örn: 'rock', 'jazz', 'pop'
  static Future<List<Song>> fetchSongs({
    String? genre,
    String? searchQuery,
    String? artistName,
    int limit = 50,
    int offset = 0,
  }) async {
    // URL parametrelerini bir Map olarak hazırlıyoruz.
    final Map<String, dynamic> queryParams = {
      'client_id': _clientId,
      'format': 'json',
      'limit': limit.toString(),
      'offset': offset.toString(),
      'order': 'popularity_total',
      'include': 'musicinfo',
      'audioformat': 'mp32',
    };

    if (genre != null && genre.isNotEmpty) {
      queryParams['fuzzytags'] = genre;
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      queryParams['namesearch'] = searchQuery;
    }

    if (artistName != null && artistName.isNotEmpty) {
      queryParams['artist_name'] = artistName;
    }

    // Uri.https kullanarak boşluk ve özel karakter sorunlarını (örn: Hip Hop) çözüyoruz.
    final uri = Uri.https('api.jamendo.com', '/v3.0/tracks/', queryParams);

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List results = decoded['results'] ?? [];
      return results.map((e) => Song.fromJamendoJson(e)).toList();
    } else {
      throw Exception('Jamendo API hata: ${response.statusCode}');
    }
  }

  /// Popüler müzik türlerini (etiketleri) çeker
  static Future<List<String>> fetchTags() async {
    final Map<String, dynamic> queryParams = {
      'client_id': _clientId,
      'format': 'json',
      'order': 'popularity_total',
      'limit': '15',
    };

    final uri = Uri.https('api.jamendo.com', '/v3.0/tags/', queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List results = decoded['results'] ?? [];
      return results.map((e) => e['name'].toString()).toList();
    } else {
      throw Exception('Jamendo API tags hata: ${response.statusCode}');
    }
  }
}
