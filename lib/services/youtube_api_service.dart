import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:muzik_app/models/song_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class YoutubeSearchResult {
  final List<Song> songs;
  final String? nextPageToken;

  YoutubeSearchResult({required this.songs, this.nextPageToken});
}

class YoutubePlaylist {
  final String id;
  final String title;
  final String thumbnailUrl;

  YoutubePlaylist({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
  });

  factory YoutubePlaylist.fromJson(Map<String, dynamic> json) {
    final snippet = json['snippet'];
    return YoutubePlaylist(
      id: json['id']['playlistId'],
      title: snippet['title'] ?? 'Başlıksız Liste',
      thumbnailUrl:
          snippet['thumbnails']['medium']?['url'] ??
          snippet['thumbnails']['default']?['url'] ??
          '',
    );
  }
}

class YoutubeApiService {
  static const String _authority = 'www.googleapis.com';
  static const String _path = '/youtube/v3';

  /// YouTube'da video arar. Sayfalama için [pageToken] alabilir.
  static Future<YoutubeSearchResult> searchVideos(
    String query, {
    String? pageToken,
  }) async {
    final String apiKey = dotenv.env['YOUTUBE_API_KEY'] ?? '';

    // 1. Adım: Arama yapıp Video ID'lerini alıyoruz
    final Map<String, dynamic> searchParams = {
      'part': 'id',
      'q': query,
      'type': 'video',
      'maxResults': '20',
      'key': apiKey,
    };
    if (pageToken != null) {
      searchParams['pageToken'] = pageToken;
    }
    final Uri searchUri = Uri.https(_authority, '$_path/search', searchParams);

    final searchResponse = await http.get(searchUri);

    if (searchResponse.statusCode != 200) {
      throw Exception("YouTube Arama Hatası: ${searchResponse.statusCode}");
    }

    final searchData = jsonDecode(searchResponse.body);
    final String? nextPageToken = searchData['nextPageToken'];
    final List searchItems = searchData['items'];

    if (searchItems.isEmpty) {
      return YoutubeSearchResult(songs: [], nextPageToken: null);
    }

    // ID'leri virgülle ayrılmış string haline getir
    final String videoIds = searchItems
        .map((item) => item['id']['videoId'])
        .join(',');

    // 2. Adım: Bu ID'ler için detayları (snippet ve contentDetails) çekiyoruz
    final Uri detailsUri = Uri.https(_authority, '$_path/videos', {
      'part': 'snippet,contentDetails',
      'id': videoIds,
      'key': apiKey,
    });

    final detailsResponse = await http.get(detailsUri);

    if (detailsResponse.statusCode != 200) {
      throw Exception("YouTube Detay Hatası: ${detailsResponse.statusCode}");
    }

    final detailsData = jsonDecode(detailsResponse.body);
    final List videoItems = detailsData['items'];

    // contentDetails içeren factory metodunu kullanıyoruz
    return YoutubeSearchResult(
      songs: videoItems.map((e) => Song.fromYoutubeVideoJson(e)).toList(),
      nextPageToken: nextPageToken,
    );
  }

  /// YouTube'daki popüler müzikleri (Trendler) çeker.
  /// videoCategoryId=10 (Müzik kategorisi)
  static Future<YoutubeSearchResult> fetchPopularSongs({
    String? pageToken,
    String regionCode = 'TR', // Türkiye trendleri
  }) async {
    final String apiKey = dotenv.env['YOUTUBE_API_KEY'] ?? '';

    final Map<String, dynamic> queryParams = {
      'part': 'snippet,contentDetails',
      'chart': 'mostPopular',
      'videoCategoryId': '10', // Müzik kategorisi
      'maxResults': '20',
      'regionCode': regionCode,
      'key': apiKey,
    };
    if (pageToken != null) {
      queryParams['pageToken'] = pageToken;
    }
    final Uri uri = Uri.https(_authority, '$_path/videos', queryParams);
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception("YouTube Trendler Hatası: ${response.statusCode}");
    }

    final data = jsonDecode(response.body);
    final String? nextPageToken = data['nextPageToken'];
    final List items = data['items'];

    if (items.isEmpty) {
      return YoutubeSearchResult(songs: [], nextPageToken: null);
    }

    // videos endpoint'i zaten detayları içerdiği için ekstra isteğe gerek yok
    return YoutubeSearchResult(
      songs: items.map((e) => Song.fromYoutubeVideoJson(e)).toList(),
      nextPageToken: nextPageToken,
    );
  }

  /// YouTube'da playlist arar.
  static Future<List<YoutubePlaylist>> searchPlaylists(String query) async {
    final String apiKey = dotenv.env['YOUTUBE_API_KEY'] ?? '';
    final Uri uri = Uri.https(_authority, '$_path/search', {
      'part': 'snippet',
      'q': query,
      'type': 'playlist',
      'maxResults': '10',
      'key': apiKey,
    });

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception("YouTube Playlist Arama Hatası: ${response.statusCode}");
    }

    final data = jsonDecode(response.body);
    final List items = data['items'];

    return items.map((e) => YoutubePlaylist.fromJson(e)).toList();
  }

  /// Bir playlist'in içindeki şarkıları çeker.
  static Future<List<Song>> fetchPlaylistSongs(String playlistId) async {
    final String apiKey = dotenv.env['YOUTUBE_API_KEY'] ?? '';

    // 1. Playlist öğelerini (ID'lerini) al
    final Uri playlistUri = Uri.https(_authority, '$_path/playlistItems', {
      'part': 'snippet',
      'playlistId': playlistId,
      'maxResults': '50',
      'key': apiKey,
    });

    final playlistResponse = await http.get(playlistUri);
    if (playlistResponse.statusCode != 200)
      throw Exception("Playlist Items Hatası");

    final playlistData = jsonDecode(playlistResponse.body);
    final List items = playlistData['items'];
    if (items.isEmpty) return [];

    // 2. Video ID'lerini topla
    final videoIds = items
        .map((e) => e['snippet']['resourceId']['videoId'])
        .join(',');

    // 3. Video detaylarını (süre vb.) al
    final Uri videosUri = Uri.https(_authority, '$_path/videos', {
      'part': 'snippet,contentDetails',
      'id': videoIds,
      'key': apiKey,
    });

    final videosResponse = await http.get(videosUri);
    if (videosResponse.statusCode != 200)
      throw Exception("Videos Detail Hatası");

    final videosData = jsonDecode(videosResponse.body);
    final List videoItems = videosData['items'];

    return videoItems.map((e) => Song.fromYoutubeVideoJson(e)).toList();
  }
}
