// lib/pages/trend_page.dart
//
// Bu sayfa, trend olan şarkıları grid görünümünde listeler.
// Şarkıların kapak resimleri, başlıkları ve sanatçı bilgileri gösterilir.
// Her şarkı için indirme butonu ve çalma özelliği sunar.
import 'package:muzik_app/models/song_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/pages/player_page.dart';
import '../providers/favorites_page.dart';
import '../providers/settings_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:muzik_app/pages/artist_detail_page.dart';
import 'package:muzik_app/widgets/album_card.dart';
import 'package:muzik_app/providers/auth_provider.dart';
import 'package:muzik_app/pages/profile_page.dart';

/// Trend şarkıları gösteren ana sayfa widget'ı
class TrendPage extends StatefulWidget {
  const TrendPage({super.key});

  @override
  State<TrendPage> createState() => _TrendPageState();
}

class _TrendPageState extends State<TrendPage> {
  // Seçili olan kategoriyi tutan değişken
  String _selectedCategory = 'Hepsi';
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

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
    _searchController.dispose();
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
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FavoritesPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      // Kategorileri ve listeyi alt alta dizmek için Column kullanıyoruz
      body: Column(
        children: [
          // Arama Çubuğu
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Şarkı veya sanatçı ara...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          songProvider.updateSearchText('');
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
              ),
              onChanged: (val) => songProvider.updateSearchText(val),
            ),
          ),
          // 1. Kategori Listesi (Yatay)
          _buildCategoryList(context),

          // 2. İçerik Alanı (Yükleniyor, Hata veya Grid)
          Expanded(child: _buildBody(context, songProvider)),
        ],
      ),
    );
  }

  Widget _buildCategoryList(BuildContext context) {
    final categories = context.watch<SongProvider>().categories;

    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == _selectedCategory;

          return GestureDetector(
            onTap: () => _onCategorySelected(context, category),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context)
                          .primaryColor // Seçiliyse Yeşil
                    : Colors.grey.shade800, // Değilse Koyu Gri
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? Border.all(color: Colors.white.withOpacity(0.5))
                    : null,
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade400,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _onCategorySelected(BuildContext context, String category) {
    setState(() {
      _selectedCategory = category;
    });

    // Listeyi en başa kaydır
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    // Provider üzerinden API isteği at
    final provider = context.read<SongProvider>();
    if (category == 'Hepsi') {
      provider.fetchSongsFromApi(); // Filtresiz getir
    } else {
      provider.fetchSongsFromApi(genre: category.toLowerCase());
    }
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

    final songs = provider.isSearching
        ? provider.searchedSongs
        : provider.allSongs;

    if (songs.isEmpty) {
      return Center(
        child: Text(
          provider.isSearching
              ? 'Arama sonucu bulunamadı.'
              : 'Gösterilecek şarkı bulunamadı.',
        ),
      );
    }

    return _buildArtistList(context, songs, provider.isLoadingMore);
  }

  Widget _buildArtistList(
    BuildContext context,
    List<Song> songs,
    bool isLoadingMore,
  ) {
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

                      return BlurryAlbumCard(
                        title: artistName,
                        artist: '',
                        coverUrl: coverUrl,
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
              final artistName = artists[index];
              final artistSongs = groupedByArtist[artistName]!;
              // Albüm kapağı olarak sanatçının ilk şarkısının kapağını kullanıyoruz
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
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      // Albüm Kapağı
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              bottomLeft: Radius.circular(12),
                            ),
                            child: Image.network(
                              coverUrl,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                context.read<SongProvider>().playSong(
                                  artistSongs.first,
                                  artistSongs,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Sanatçı Bilgisi
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              artistName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(right: 16.0),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.grey,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }, childCount: artists.length),
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
}
