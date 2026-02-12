// lib/pages/search_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/widgets/song_card.dart';
import 'package:muzik_app/providers/auth_provider.dart';
import 'package:muzik_app/pages/profile_page.dart';

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
    final authProvider = context.watch<AuthProvider>();
    final arananSarkilar = songProvider.searchedSongs;
    final aramaMetni = _searchController.text;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ara'),
        centerTitle: false,
        leading: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.grey.shade800,
              backgroundImage: authProvider.user?.photoURL != null
                  ? NetworkImage(authProvider.user!.photoURL!)
                  : null,
              child: authProvider.user?.photoURL == null
                  ? CustomIcons.svgIcon(
                      CustomIcons.person,
                      color: Colors.white,
                      size: 20,
                    )
                  : null,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Arama Kutusu
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  color: Colors.grey.shade800.withOpacity(0.5),
                  child: TextField(
                    controller: _searchController,
                    autofocus: false,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Ne dinlemek istiyorsun?',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: CustomIcons.svgIcon(
                          CustomIcons.search,
                          color: Colors.grey.shade400,
                          size: 24,
                        ),
                      ),
                      filled: false,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                      // Arama kutusunun sonuna temizleme butonu ekle
                      suffixIcon: aramaMetni.isNotEmpty
                          ? IconButton(
                              icon: CustomIcons.svgIcon(
                                CustomIcons.clear,
                                size: 24,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                songProvider.updateSearchText('');
                              },
                            )
                          : null,
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
                ),
              ),
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
    final double bottomPadding = songProvider.currentSong != null ? 160 : 100;

    if (songProvider.isSearchLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Arama kutusu boşsa, bir "keşfet" mesajı göster.
    if (aramaMetni.isEmpty) {
      return ListView(
        padding: EdgeInsets.only(bottom: bottomPadding),
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
                leading: CustomIcons.svgIcon(
                  CustomIcons.history,
                  color: Colors.grey,
                  size: 24,
                ),
                title: Text(
                  historyItem,
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: IconButton(
                  icon: CustomIcons.svgIcon(
                    CustomIcons.clear,
                    size: 18,
                    color: Colors.grey,
                  ),
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
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Sizin İçin Önerilenler',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            ...songProvider.suggestedSongs.map((song) {
              return SongCard(
                song: song,
                showOptions: true,
                onTap: () {
                  final isCurrent = songProvider.currentSong?.id == song.id;
                  if (isCurrent) {
                    if (songProvider.audioPlayer.playing) {
                      songProvider.audioPlayer.pause();
                    } else {
                      songProvider.audioPlayer.play();
                    }
                  } else {
                    songProvider.playSong(song, songProvider.suggestedSongs);
                  }
                },
              );
            }),
          ],
        ],
      );
    }
    // Arama yapıldı ama sonuç bulunamadıysa, bilgi ver.
    else if (sonuclar.isEmpty) {
      return _buildEmptyState(context, aramaMetni);
    }
    // Arama sonuçları varsa, listele.
    else {
      return ListView.builder(
        padding: EdgeInsets.only(bottom: bottomPadding),
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

          return SongCard(
            song: song,
            isPlaying: isCurrentSong,
            showOptions: true,
            onTap: () {
              if (!isCurrentSong) {
                songProvider.playSong(song, sonuclar);
              } else {
                if (songProvider.audioPlayer.playing) {
                  songProvider.audioPlayer.pause();
                } else {
                  songProvider.audioPlayer.play();
                }
              }
            },
          );
        },
      );
    }
  }

  Widget _buildEmptyState(BuildContext context, String query) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              shape: BoxShape.circle,
            ),
            child: CustomIcons.svgIcon(
              CustomIcons.searchOff,
              size: 64,
              color: Theme.of(context).primaryColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Sonuç Bulunamadı',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '"$query" için sonuç bulunamadı.\nLütfen farklı bir arama terimi deneyin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
