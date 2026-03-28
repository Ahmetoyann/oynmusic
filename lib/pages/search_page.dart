// lib/pages/search_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/widgets/song_card.dart';
import 'package:muzik_app/providers/auth_provider.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:muzik_app/widgets/custom_app_bar.dart';
import 'package:muzik_app/pages/player_page.dart';
import 'package:muzik_app/widgets/custom_banner_ad.dart';
import 'package:muzik_app/pages/artist_detail_page.dart';
import 'package:muzik_app/widgets/song_grid_card.dart';

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
            CustomSnackBar.showError(
              context: context,
              message: "Sonuçlar yüklenirken hata: $e",
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
    final selectedTab = songProvider.searchFilter;
    const tabs = ['Şarkılar', 'Sanatçılar', 'Albümler'];

    return Scaffold(
      appBar: CustomAppBar(title: 'Ara', showLeading: false),
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
            const SizedBox(height: 16),

            // Tab (Segmented Control) Alanı
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: tabs.map((tab) {
                      final isSelected = selectedTab == tab;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            songProvider.setSearchFilter(tab);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: isSelected
                                  ? Border.all(
                                      color: Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.5),
                                      width: 1,
                                    )
                                  : Border.all(
                                      color: Colors.transparent,
                                      width: 1,
                                    ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              tab,
                              style: TextStyle(
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey.shade400,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sonuçları veya başlangıç ekranını gösteren bölüm
            Expanded(
              child: _buildResultsBody(context, aramaMetni, arananSarkilar),
            ),

            // Banner Reklam Alanı
            const SizedBox(height: 10),
            const CustomBannerAd(),
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
    final selectedTab = songProvider.searchFilter;

    List<Song> suggestionsToDisplay = [];
    String suggestionTitle = '';
    if (selectedTab == 'Sanatçılar') {
      suggestionsToDisplay = songProvider.suggestedArtists;
      suggestionTitle = 'Ayın Popüler Sanatçıları';
    } else if (selectedTab == 'Albümler') {
      suggestionsToDisplay = songProvider.suggestedAlbums;
      suggestionTitle = 'Ayın Popüler Albümleri';
    } else {
      suggestionsToDisplay = songProvider.suggestedSongs;
      suggestionTitle = 'Sizin İçin Önerilenler';
    }

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
          else if (suggestionsToDisplay.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                suggestionTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            if (selectedTab == 'Albümler')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: suggestionsToDisplay.length,
                  itemBuilder: (context, index) =>
                      _buildAlbumGridCard(context, suggestionsToDisplay[index]),
                ),
              )
            else
              ...suggestionsToDisplay.map((song) {
                if (selectedTab == 'Sanatçılar') {
                  return _buildArtistTile(context, song);
                }
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
                      songProvider.playSong(song, suggestionsToDisplay);
                    }
                    PlayerPage.show(context);
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
      return CustomScrollView(
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          selectedTab == 'Albümler'
              ? SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildAlbumGridCard(context, sonuclar[index]),
                      childCount: sonuclar.length,
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final song = sonuclar[index];
                    if (selectedTab == 'Sanatçılar') {
                      return _buildArtistTile(context, song);
                    }

                    final isCurrentSong =
                        songProvider.currentSong?.id == song.id;

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
                        PlayerPage.show(context);
                      },
                    );
                  }, childCount: sonuclar.length),
                ),
          if (songProvider.isSearchLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
        ],
      );
    }
  }

  Widget _buildArtistTile(BuildContext context, Song song) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: song.coverUrl.isEmpty
          ? const CustomShimmer(width: 56, height: 56, borderRadius: 28)
          : CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey.shade800,
              backgroundImage: NetworkImage(song.coverUrl),
              onBackgroundImageError: (_, __) {},
            ),
      title: song.coverUrl.isEmpty
          ? const CustomShimmer(width: 120, height: 16, borderRadius: 4)
          : Text(
              song.artist,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: song.coverUrl.isEmpty
            ? const CustomShimmer(width: 60, height: 12, borderRadius: 4)
            : Text(
                'Sanatçı',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
      ),
      onTap: song.coverUrl.isEmpty
          ? null
          : () {
              context.read<SongProvider>().checkAndShowAdForArtist();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ArtistDetailPage(artistName: song.artist, songs: [song]),
                ),
              );
            },
    );
  }

  Widget _buildAlbumGridCard(BuildContext context, Song song) {
    if (song.coverUrl.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: CustomShimmer(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 12,
            ),
          ),
          SizedBox(height: 8),
          CustomShimmer(width: 100, height: 14, borderRadius: 4),
          SizedBox(height: 4),
          CustomShimmer(width: 60, height: 10, borderRadius: 4),
        ],
      );
    }

    return SongGridCard(
      imageUrl: song.coverUrl,
      title: song.title,
      subtitle: song.artist,
      showFavorite: false,
      placeholderIcon: CustomIcons.album,
      onTap: () {
        context.read<SongProvider>().checkAndShowAdForArtist();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ArtistDetailPage(artistName: song.artist, songs: [song]),
          ),
        );
      },
    );
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

// --- MODERN SHIMMER EFEKT WIDGET'I ---
class CustomShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const CustomShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  State<CustomShimmer> createState() => _CustomShimmerState();
}

class _CustomShimmerState extends State<CustomShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-2.0 + (_controller.value * 4), 0.0),
              end: Alignment(0.0 + (_controller.value * 4), 0.0),
              colors: [
                Colors.grey.shade900,
                Colors.grey.shade800,
                Colors.grey.shade900,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
