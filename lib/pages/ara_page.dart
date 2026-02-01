import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/pages/player_page.dart';
import 'package:muzik_app/models/song_model.dart';

/// Arama sayfası
/// - Üstte bir arama kutusu bulunur
/// - Arama metni girildiğinde `SongProvider.updateSearchText` çağrılır
/// - Eğer arama metni boş ise Trendler (tüm şarkılar) gösterilir
/// - Arama metni doluysa filtrelenmiş sonuçlar gösterilir
class AraPage extends StatelessWidget {
  const AraPage({super.key});

  @override
  Widget build(BuildContext context) {
    final songProvider = context.watch<SongProvider>();

    // Yükleniyor veya hata durumu kontrolü
    if (songProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ara'),
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (songProvider.errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ara'),
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Hata: ${songProvider.errorMessage}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
      );
    }

    // Kullanıcının arama yaptığı durumda provider.searchedSongs dolu olacaktır.
    // Eğer arama yapılmadıysa (arama metni boş) tüm şarkılar (trendler) gösterilir.
    final bool isSearching = songProvider.isSearching;
    final List<Song> results = isSearching
        ? songProvider.searchedSongs
        : songProvider.allSongs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ara'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Arama kutusu
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Şarkı veya sanatçı ara...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                filled: true,
                fillColor: Colors.grey.shade900,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => songProvider.updateSearchText(value),
            ),
            const SizedBox(height: 12),

            // Arama sonuçları veya Trendler listesi
            Expanded(
              child: Builder(
                builder: (context) {
                  // Arama yapıldıysa ve sonuç yoksa, kullanıcıya bilgi göster
                  if (isSearching && results.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 80,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Sonuç Bulunamadı',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Lütfen farklı bir anahtar kelime deneyin.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    );
                  }

                  // Eğer veri yoksa genel boş durum
                  if (results.isEmpty) {
                    return const Center(
                      child: Text(
                        'Gösterilecek şarkı yok',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  // Sonuçları grid olarak göster (TrendPage ile benzer görünüm)
                  return GridView.builder(
                    padding: const EdgeInsets.all(4.0),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final song = results[index];
                      return GestureDetector(
                        onTap: () {
                          final sp = Provider.of<SongProvider>(
                            context,
                            listen: false,
                          );
                          sp.playSong(song, results);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PlayerPage(),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.network(
                                  song.coverUrl,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, st) =>
                                      Container(
                                        color: Colors.grey.shade800,
                                        child: const Center(
                                          child: Icon(
                                            Icons.music_note_rounded,
                                            color: Colors.grey,
                                            size: 48,
                                          ),
                                        ),
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              song.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              song.artist,
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
