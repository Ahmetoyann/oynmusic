// lib/pages/search_page.dart
import 'package:flutter/material.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/pages/player_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Kaydırma dinleyicisi ekle
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<SongProvider>().loadMoreSearchResults().catchError((e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Sonuçlar yüklenirken hata: $e"),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    });

    // Sayfa açıldığında önerilen şarkıları yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SongProvider>().fetchSuggestedSongs();
    });
  }

  @override
  void dispose() {
    // Sayfa kapandığında controller'ı temizleyerek hafıza sızıntısını önle.
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
    // `watch` ile provider'daki tüm değişiklikleri dinliyoruz.
    final songProvider = context.watch<SongProvider>();
    final arananSarkilar = songProvider.searchedSongs;
    final aramaMetni = _searchController.text;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ara',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Arama Kutusu
            TextField(
              controller: _searchController,
              autofocus:
                  true, // Sayfa açıldığında klavyenin otomatik açılmasını sağlar.
              decoration: InputDecoration(
                hintText: 'Şarkı veya sanatçı ara...',
                prefixIcon: const Icon(Icons.search),
                // Arama kutusunun sonuna temizleme butonu ekle
                suffixIcon: aramaMetni.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          songProvider.updateSearchText('');
                        },
                      )
                    : null,
                // Stil özellikleri artık main.dart içerisindeki temadan otomatik alınıyor.
              ),
              // Kullanıcı her harf girdiğinde bu fonksiyon tetiklenir.
              onChanged: (value) {
                // Provider'daki arama metnini güncelle.
                songProvider.updateSearchText(value);
              },
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  songProvider.addToSearchHistory(value);
                }
                FocusScope.of(context).unfocus();
              },
            ),
            const SizedBox(height: 20),

            // Sonuçları veya başlangıç ekranını gösteren bölüm
            Expanded(
              child: _buildResultsBody(context, aramaMetni, arananSarkilar),
            ),
          ],
        ),
      ),
    );
  }

  /// Arama durumuna göre sonuç listesini veya başlangıç mesajını gösteren widget.
  Widget _buildResultsBody(
    BuildContext context,
    String aramaMetni,
    List<Song> sonuclar,
  ) {
    final songProvider = context.watch<SongProvider>();

    if (songProvider.isSearchLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Arama kutusu boşsa, bir "keşfet" mesajı göster.
    if (aramaMetni.isEmpty) {
      return ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          // 1. Arama Geçmişi Bölümü
          if (songProvider.searchHistory.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Son Aramalar',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => songProvider.clearSearchHistory(),
                    child: const Text(
                      'Temizle',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),
            ...songProvider.searchHistory.map((historyItem) {
              return ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(
                  historyItem,
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                  onPressed: () =>
                      songProvider.removeFromSearchHistory(historyItem),
                ),
                onTap: () {
                  _searchController.text = historyItem;
                  _searchController.selection = TextSelection.fromPosition(
                    TextPosition(offset: historyItem.length),
                  );
                  songProvider.updateSearchText(historyItem);
                  songProvider.addToSearchHistory(historyItem);
                },
              );
            }),
            const Divider(color: Colors.grey),
          ],

          // 2. Önerilen Şarkılar Bölümü
          if (songProvider.isSuggestionsLoading)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (songProvider.suggestedSongs.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Sizin İçin Önerilenler',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            ...songProvider.suggestedSongs.map((song) {
              return Card(
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(4.0),
                    child: Image.network(
                      song.coverUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey.shade800,
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    song.artist,
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                  onTap: () {
                    songProvider.playSong(song, songProvider.suggestedSongs);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PlayerPage(),
                      ),
                    );
                  },
                ),
              );
            }),
          ],
        ],
      );
    }
    // Arama yapıldı ama sonuç bulunamadıysa, bilgi ver.
    else if (sonuclar.isEmpty) {
      return Center(
        child: Text(
          '"$aramaMetni" için sonuç bulunamadı.',
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }
    // Arama sonuçları varsa, listele.
    else {
      return ListView.builder(
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        // Yükleniyor göstergesi için +1 ekliyoruz
        itemCount: sonuclar.length + (songProvider.isSearchLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Listenin sonundaysak ve yükleniyorsa loading göster
          if (index == sonuclar.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final song = sonuclar[index];
          final isCurrentSong = songProvider.currentSong?.id == song.id;

          return Card(
            child: ListTile(
              onTap: () {
                final isCurrentSong = songProvider.currentSong?.id == song.id;
                if (!isCurrentSong) {
                  songProvider.playSong(song, sonuclar);
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PlayerPage()),
                );
              },
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4.0),
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
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              subtitle: Text(
                song.artist,
                style: TextStyle(color: Colors.grey.shade400),
              ),
            ),
          );
        },
      );
    }
  }
}
