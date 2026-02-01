import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/pages/player_page.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/services/music_api_service.dart';

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

  @override
  void initState() {
    super.initState();
    // Başlangıçta elimizdeki şarkıları gösteriyoruz
    _songs = List.from(widget.songs);
    // Arka planda sanatçının tüm şarkılarını çekiyoruz
    _fetchArtistSongs();
  }

  Future<void> _fetchArtistSongs() async {
    try {
      final artistSongs = await JamendoApiService.fetchSongs(
        artistName: widget.artistName,
        limit: 100, // Sanatçının daha fazla şarkısını çekmek için limit
      );

      if (mounted && artistSongs.isNotEmpty) {
        setState(() {
          _songs = artistSongs;
        });
      }
    } catch (e) {
      debugPrint("Sanatçı şarkıları yüklenirken hata: $e");
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
          const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
        ],
      ),
    );
  }
}
