import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/pages/player_page.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/services/youtube_api_service.dart';
import 'package:muzik_app/pages/folder_detail_page.dart';

class ArtistDetailPage extends StatefulWidget {
  final String artistName;
  final List<Song> songs;

  const ArtistDetailPage({
    super.key,
    required this.artistName,
    required this.songs,
  });

  @override
  State<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends State<ArtistDetailPage> {
  late List<Song> _songs;
  List<YoutubePlaylist> _playlists = [];
  String? _nextPageToken;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Başlangıçta elimizdeki şarkıları gösteriyoruz
    _songs = List.from(widget.songs);
    _scrollController.addListener(_onScroll);
    // Arka planda sanatçının tüm şarkılarını çekiyoruz
    _fetchArtistSongs();
    _fetchPlaylists();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreSongs();
    }
  }

  Future<void> _fetchArtistSongs() async {
    try {
      final result = await YoutubeApiService.searchVideos(
        "${widget.artistName} music",
      );
      final artistSongs = result.songs;

      if (mounted && artistSongs.isNotEmpty) {
        setState(() {
          _songs = artistSongs;
          _nextPageToken = result.nextPageToken;
        });
      }
    } catch (e) {
      debugPrint("Sanatçı şarkıları yüklenirken hata: $e");
    }
  }

  Future<void> _fetchPlaylists() async {
    try {
      final playlists = await YoutubeApiService.searchPlaylists(
        "${widget.artistName} music",
      );
      if (mounted && playlists.isNotEmpty) {
        setState(() {
          _playlists = playlists;
        });
      }
    } catch (e) {
      debugPrint("Playlist yüklenirken hata: $e");
    }
  }

  Future<void> _loadMoreSongs() async {
    if (_isLoadingMore || _nextPageToken == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final result = await YoutubeApiService.searchVideos(
        "${widget.artistName} music",
        pageToken: _nextPageToken,
      );

      if (mounted) {
        setState(() {
          _songs.addAll(result.songs);
          _nextPageToken = result.nextPageToken;
        });
      }
    } catch (e) {
      debugPrint("Daha fazla şarkı yüklenirken hata: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _openPlaylist(YoutubePlaylist playlist) async {
    // Yükleniyor göstergesi
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final songs = await YoutubeApiService.fetchPlaylistSongs(playlist.id);
      if (!mounted) return;
      Navigator.pop(context); // Yükleniyor kapat

      // FolderDetailPage kullanarak playlist içeriğini göster
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FolderDetailPage(
            folder: MusicFolder(name: playlist.title, songs: songs),
          ),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Liste açılamadı: $e")));
    }
  }

  // Süreyi "01:23" formatında göstermek için yardımcı metot
  String _formatDuration(int? seconds) {
    if (seconds == null || seconds == 0) return '';
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  @override
  Widget build(BuildContext context) {
    // Favori durumlarını dinlemek için watch kullanıyoruz
    final songProvider = context.watch<SongProvider>();
    final coverUrl = _songs.isNotEmpty ? _songs.first.coverUrl : '';

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 300.0,
            pinned: true,
            stretch: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.artistName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                ),
              ),
              centerTitle: true,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverUrl.isNotEmpty)
                    Image.network(coverUrl, fit: BoxFit.cover),
                  if (coverUrl.isNotEmpty)
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                      child: Container(color: Colors.black.withOpacity(0.4)),
                    ),
                  if (coverUrl.isNotEmpty)
                    Center(
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(coverUrl, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_songs.isNotEmpty) {
                      songProvider.playSong(_songs.first, _songs);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PlayerPage(),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 28),
                  label: const Text(
                    "Tümünü Çal",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // OYNATMA LİSTELERİ (PLAYLISTS)
          if (_playlists.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Text(
                      "Oynatma Listeleri",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = _playlists[index];
                        return GestureDetector(
                          onTap: () => _openPlaylist(playlist),
                          child: Container(
                            width: 140,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      playlist.thumbnailUrl,
                                      width: 140,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  playlist.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final song = _songs[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  color: Colors.grey.shade900.withOpacity(0.5),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4.0),
                          child: Image.network(
                            song.coverUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.music_note,
                                  color: Colors.grey,
                                ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    title: Text(
                      song.title,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      song.artist,
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatDuration(song.duration),
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            song.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: song.isFavorite ? Colors.red : Colors.grey,
                          ),
                          onPressed: () {
                            songProvider.toggleFavorite(song);
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      songProvider.playSong(song, _songs);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PlayerPage(),
                        ),
                      );
                    },
                  ),
                ),
              );
            }, childCount: _songs.length),
          ),
          if (_isLoadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
        ],
      ),
    );
  }
}
