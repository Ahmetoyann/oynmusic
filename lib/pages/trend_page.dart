// lib/pages/trend_page.dart
//
// Bu sayfa, trend olan şarkıları grid görünümünde listeler.
// Şarkıların kapak resimleri, başlıkları ve sanatçı bilgileri gösterilir.
// Her şarkı için indirme butonu ve çalma özelliği sunar.
import 'package:muzik_app/models/song_model.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/pages/artist_detail_page.dart';
import 'package:muzik_app/providers/auth_provider.dart';
import 'package:muzik_app/pages/profile_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:muzik_app/pages/player_page.dart';

/// Trend şarkıları gösteren ana sayfa widget'ı
class TrendPage extends StatefulWidget {
  const TrendPage({super.key});

  @override
  State<TrendPage> createState() => _TrendPageState();
}

class _TrendPageState extends State<TrendPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Kaydırma dinleyicisini ekle
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // Listenin sonuna 200 piksel kala yeni şarkıları yükle
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<SongProvider>().loadMoreSongs().catchError((e) {
        if (mounted) {
          // Varsa önceki uyarıyı gizle
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          // Yeni uyarıyı göster
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Daha fazla şarkı yüklenemedi.'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Tekrar Dene',
                textColor: Colors.white,
                onPressed: () => context.read<SongProvider>().loadMoreSongs(),
              ),
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    final songProvider = context.watch<SongProvider>();
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Trendler',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        actions: [
          // Profil / Giriş İkonu
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey.shade800,
                backgroundImage: authProvider.user != null
                    ? NetworkImage(authProvider.user!.photoURL!)
                    : null,
                child: authProvider.user == null
                    ? const Icon(Icons.person, color: Colors.white, size: 20)
                    : null,
              ),
            ),
          ),
        ],
      ),
      // İçerik Alanı (Yükleniyor, Hata veya Liste)
      body: _buildBody(context, songProvider),
    );
  }

  Widget _buildBody(BuildContext context, SongProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Hata: ${provider.errorMessage}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red.shade300),
          ),
        ),
      );
    }

    final songs = provider.allSongs;

    if (songs.isEmpty) {
      return const Center(child: Text('Gösterilecek şarkı bulunamadı.'));
    }

    return _buildArtistList(context, songs, provider.isLoadingMore);
  }

  Widget _buildArtistList(
    BuildContext context,
    List<Song> songs,
    bool isLoadingMore,
  ) {
    final songProvider = context.watch<SongProvider>();
    // Şarkıları Sanatçı adına göre grupluyoruz
    final Map<String, List<Song>> groupedByArtist = {};
    for (var song in songs) {
      if (!groupedByArtist.containsKey(song.artist)) {
        groupedByArtist[song.artist] = [];
      }
      groupedByArtist[song.artist]!.add(song);
    }

    final artists = groupedByArtist.keys.toList();

    // En çok şarkısı olan 5 sanatçıyı (albümü) bul
    final sortedEntries = groupedByArtist.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    final top5 = sortedEntries.take(5).toList();

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Günün Şarkısı Kartı
        if (songProvider.dailySong != null)
          SliverToBoxAdapter(
            child: _buildDailySongCard(context, songProvider.dailySong!),
          ),

        // Üst kısım: En çok şarkısı olan 5 albüm (Carousel)
        if (top5.isNotEmpty)
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Text(
                    "Öne Çıkan Albümler",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: top5.length,
                    itemBuilder: (context, index) {
                      final entry = top5[index];
                      final artistName = entry.key;
                      final artistSongs = entry.value;
                      final coverUrl = artistSongs.first.coverUrl;

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ArtistDetailPage(
                                artistName: artistName,
                                songs: artistSongs,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 160,
                          margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.network(
                                      coverUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey.shade800,
                                              child: const Center(
                                                child: Icon(
                                                  Icons.music_note,
                                                  size: 60,
                                                  color: Colors.white54,
                                                ),
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                artistName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    "Tüm Sanatçılar",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.all(12.0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final song = songs[index];
              final artistName = song.artist;
              final artistSongs = groupedByArtist[artistName]!;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ArtistDetailPage(
                        artistName: artistName,
                        songs: artistSongs,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        song.coverUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey.shade800,
                            child: const Icon(
                              Icons.music_note,
                              color: Colors.white70,
                            ),
                          );
                        },
                      ),
                    ),
                    title: Tooltip(
                      message: song.title,
                      child: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    subtitle: Text(
                      song.artist,
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  ),
                ),
              );
            }, childCount: songs.length), // artists.length yerine songs.length
          ),
        ),
        if (isLoadingMore)
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
      ],
    );
  }

  Widget _buildDailySongCard(BuildContext context, Song song) {
    return GestureDetector(
      onTap: () {
        final provider = context.read<SongProvider>();
        // Günün şarkısını çalma listesi olarak (tüm trendler) çalabiliriz.
        provider.playSong(song, provider.allSongs);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PlayerPage()),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Arka plan resmi
              Image.network(
                song.coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Theme.of(context).primaryColor.withOpacity(0.8),
                ),
              ),
              // Bulanıklık efekti
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.black.withOpacity(0.4)),
              ),
              // Arka plan dekoratif daireler
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Kapak Resmi
                    Hero(
                      tag: 'daily_song_${song.id}',
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            song.coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              color: Colors.grey.shade800,
                              child: const Icon(
                                Icons.music_note,
                                color: Colors.white54,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Bilgiler
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  "Günün Şarkısı",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.play_circle_fill,
                                color: Colors.white,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Hemen Dinle",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(
                                  Icons.share_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                onPressed: () {
                                  Share.share(
                                    'Bu şarkıyı OYN Music\'te keşfettim!\n\n🎵 ${song.title}\n👤 ${song.artist}\n\nDinlemek için: ${song.audioUrl}',
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
