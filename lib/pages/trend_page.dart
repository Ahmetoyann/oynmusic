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
import 'package:muzik_app/services/audius_service.dart';
import 'package:muzik_app/pages/recently_played_page.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/widgets/song_card.dart';
import 'package:muzik_app/widgets/song_grid_card.dart';

/// Trend şarkıları gösteren ana sayfa widget'ı
class TrendPage extends StatefulWidget {
  const TrendPage({super.key});

  @override
  State<TrendPage> createState() => _TrendPageState();
}

class _TrendPageState extends State<TrendPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isAlbumGrid = false;
  bool _isSongGrid = false;
  bool _isSearchActive = false;
  bool _showSearchContent = false;
  bool _isTitleVisible = true;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _selectedFilter = 'TÜMÜ';
  final List<String> _filters = ['TÜMÜ', 'ŞARKILAR', 'ALBÜMLER'];

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
      final provider = context.read<SongProvider>();
      final isSearching = _searchController.text.isNotEmpty;

      final future = isSearching
          ? provider.loadMoreSearchResults()
          : provider.loadMoreSongs();

      future.catchError((e) {
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
                onPressed: () {
                  if (_searchController.text.isNotEmpty) {
                    context.read<SongProvider>().loadMoreSearchResults();
                  } else {
                    context.read<SongProvider>().loadMoreSongs();
                  }
                },
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
    _searchController.dispose();
    _searchFocusNode.dispose();
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
        leading: !_isTitleVisible
            ? null
            : GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfilePage(),
                    ),
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
        title: _isTitleVisible
            ? SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final isSelected = _selectedFilter == filter;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade400,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )
            : null,
        centerTitle: false,
        titleSpacing: 0,
        actions: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            width: _isSearchActive
                ? MediaQuery.of(context).size.width - 16
                : 48,
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            onEnd: () {
              if (_isSearchActive) {
                setState(() {
                  _showSearchContent = true;
                });
                _searchFocusNode.requestFocus();
              } else {
                setState(() {
                  _isTitleVisible = true;
                });
              }
            },
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: _isSearchActive ? 15.0 : 0.0,
                  sigmaY: _isSearchActive ? 15.0 : 0.0,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  color: _isSearchActive
                      ? Colors.grey.shade800.withOpacity(0.5)
                      : Colors.transparent,
                  child: Row(
                    children: [
                      IconButton(
                        icon: CustomIcons.svgIcon(
                          CustomIcons.search,
                          color: _isSearchActive
                              ? Colors.white
                              : Theme.of(context).primaryColor,
                          size: 24,
                        ),
                        onPressed: () {
                          if (!_isSearchActive) {
                            setState(() {
                              _isSearchActive = true;
                              _isTitleVisible = false;
                            });
                          }
                        },
                      ),
                      Expanded(
                        child: _showSearchContent
                            ? TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                style: const TextStyle(color: Colors.white),
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => _searchFocusNode.unfocus(),
                                decoration: const InputDecoration(
                                  hintText: 'Ne dinlemek istiyorsun?',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  filled: false,
                                ),
                                onChanged: (value) {
                                  context.read<SongProvider>().updateSearchText(
                                    value,
                                  );
                                  setState(() {});
                                },
                              )
                            : const SizedBox(),
                      ),
                      if (_showSearchContent)
                        IconButton(
                          icon: CustomIcons.svgIcon(
                            CustomIcons.clear,
                            color: Colors.grey,
                            size: 24,
                          ),
                          onPressed: () {
                            setState(() {
                              _isSearchActive = false;
                              _showSearchContent = false;
                              _searchController.clear();
                            });
                            context.read<SongProvider>().updateSearchText('');
                          },
                        ),
                    ],
                  ),
                ),
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

    // Arama yapılıyorsa API sonuçlarını göster
    if (_searchController.text.isNotEmpty) {
      if (provider.isSearchLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      final songs = provider.searchedSongs;
      if (songs.isEmpty) {
        return _buildNoResultsFound(context);
      }

      return _buildArtistList(
        context,
        songs,
        provider.isSearchLoadingMore,
        isSearch: true,
      );
    }

    // Normal Trend Listesi
    final songs = provider.allSongs;

    if (songs.isEmpty) {
      return _buildNoResultsFound(context);
    }

    return _buildArtistList(context, songs, provider.isLoadingMore);
  }

  Widget _buildNoResultsFound(BuildContext context) {
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
            'Lütfen farklı bir arama terimi deneyin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistList(
    BuildContext context,
    List<Song> songs,
    bool isLoadingMore, {
    bool isSearch = false,
  }) {
    final songProvider = context.watch<SongProvider>();
    final double bottomPadding = songProvider.currentSong != null ? 160 : 100;
    // Şarkıları Sanatçı adına göre grupluyoruz
    final Map<String, List<Song>> groupedByArtist = {};
    for (var song in songs) {
      if (!groupedByArtist.containsKey(song.artist)) {
        groupedByArtist[song.artist] = [];
      }
      groupedByArtist[song.artist]!.add(song);
    }

    final artists = groupedByArtist.keys.toList();

    final sortedEntries = groupedByArtist.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    final bool showAll = isSearch || _selectedFilter == 'TÜMÜ';
    final bool showSongs = !isSearch && _selectedFilter == 'ŞARKILAR';
    final bool showAlbumsOnly = !isSearch && _selectedFilter == 'ALBÜMLER';

    final List<MapEntry<String, List<Song>>> displayedAlbums;
    if (showAlbumsOnly) {
      displayedAlbums = sortedEntries;
    } else if (showAll) {
      displayedAlbums = sortedEntries.take(10).toList();
    } else {
      displayedAlbums = [];
    }

    final bool useGrid = showAlbumsOnly ? true : _isAlbumGrid;
    final primaryColor = Theme.of(context).primaryColor;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Günün Şarkıları Listesi
        if (!isSearch &&
            (showAll || showSongs) &&
            songProvider.dailySongs.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildDailySongsList(context, songProvider.dailySongs),
          ),

        // --- ALBÜMLER BÖLÜMÜ ---
        if (displayedAlbums.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    showAlbumsOnly ? "Tüm Albümler" : "Öne Çıkan Albümler",
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!showAlbumsOnly)
                    IconButton(
                      icon: CustomIcons.svgIcon(
                        _isAlbumGrid ? CustomIcons.carousel : CustomIcons.grid,
                        color: primaryColor,
                        size: 24,
                      ),
                      onPressed: () {
                        setState(() {
                          _isAlbumGrid = !_isAlbumGrid;
                        });
                      },
                    ),
                ],
              ),
            ),
          ),

        if (displayedAlbums.isNotEmpty)
          useGrid
              ? SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final entry = displayedAlbums[index];
                      return _buildAlbumCard(
                        context,
                        entry.key,
                        entry.value,
                        isGrid: true,
                      );
                    }, childCount: displayedAlbums.length),
                  ),
                )
              : SliverToBoxAdapter(
                  child: SizedBox(
                    height: 150,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: displayedAlbums.length,
                      itemBuilder: (context, index) {
                        final entry = displayedAlbums[index];
                        return Container(
                          width: 110,
                          margin: const EdgeInsets.only(right: 12),
                          child: _buildAlbumCard(
                            context,
                            entry.key,
                            entry.value,
                            isGrid: false,
                          ),
                        );
                      },
                    ),
                  ),
                ),

        // --- EN SON DİNLEDİKLERİN BÖLÜMÜ ---
        if (!isSearch &&
            (showAll || showSongs) &&
            songProvider.recentlyPlayed.isNotEmpty)
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RecentlyPlayedPage(),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "En Son Dinlediklerin",
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        CustomIcons.svgIcon(
                          CustomIcons.arrowRight,
                          size: 18,
                          color: primaryColor.withOpacity(0.7),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 150,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: songProvider.recentlyPlayed.length,
                    itemBuilder: (context, index) {
                      final song = songProvider.recentlyPlayed[index];
                      return Container(
                        width: 110,
                        margin: const EdgeInsets.only(right: 12),
                        child: _buildRecentlyPlayedCard(context, song),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

        // --- SANATÇI BAZLI LİSTELEME ---
        if (showAll || showSongs)
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final artistName = artists[index];
              final initialSongs = groupedByArtist[artistName]!;
              return ArtistSectionWidget(
                artistName: artistName,
                initialSongs: initialSongs,
              );
            }, childCount: artists.length),
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
        SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
      ],
    );
  }

  Widget _buildAlbumCard(
    BuildContext context,
    String artistName,
    List<Song> artistSongs, {
    required bool isGrid,
  }) {
    final coverUrl = artistSongs.first.coverUrl;
    return SongGridCard(
      imageUrl: coverUrl,
      title: artistName,
      showFavorite: false, // Albüm kartında favori butonu göstermiyoruz
      placeholderIcon: CustomIcons.album,
      titleMaxLines: 2,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ArtistDetailPage(artistName: artistName, songs: artistSongs),
          ),
        );
      },
    );
  }

  Widget _buildRecentlyPlayedCard(BuildContext context, Song song) {
    return SongGridCard(
      song: song,
      imageUrl: song.coverUrl,
      title: song.title,
      subtitle: song.artist,
      onTap: () {
        final provider = context.read<SongProvider>();
        if (provider.currentSong?.id == song.id) {
          if (provider.audioPlayer.playing) {
            provider.audioPlayer.pause();
          } else {
            provider.audioPlayer.play();
          }
        } else {
          provider.playSong(song, provider.recentlyPlayed);
        }
      },
    );
  }

  Widget _buildSongListTile(
    BuildContext context,
    Song song,
    List<Song> artistSongs,
  ) {
    return SongCard(
      song: song,
      showOptions: true,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ArtistDetailPage(artistName: song.artist, songs: artistSongs),
          ),
        );
      },
    );
  }

  Widget _buildSongGridCard(
    BuildContext context,
    Song song,
    List<Song> artistSongs,
  ) {
    return SongGridCard(
      song: song,
      imageUrl: song.coverUrl,
      title: song.title,
      subtitle: song.artist,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ArtistDetailPage(artistName: song.artist, songs: artistSongs),
          ),
        );
      },
    );
  }

  Widget _buildDailySongsList(BuildContext context, List<Song> songs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text(
            "Günün Şarkıları",
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return GestureDetector(
                onTap: () {
                  final provider = context.read<SongProvider>();
                  if (provider.currentSong?.id == song.id) {
                    if (provider.audioPlayer.playing) {
                      provider.audioPlayer.pause();
                    } else {
                      provider.audioPlayer.play();
                    }
                  } else {
                    provider.playSong(song, songs);
                  }
                },
                child: Container(
                  width: 85,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      Container(
                        width: 75,
                        height: 75,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          image: DecorationImage(
                            image: NetworkImage(song.coverUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ArtistSectionWidget extends StatefulWidget {
  final String artistName;
  final List<Song> initialSongs;

  const ArtistSectionWidget({
    super.key,
    required this.artistName,
    required this.initialSongs,
  });

  @override
  State<ArtistSectionWidget> createState() => _ArtistSectionWidgetState();
}

class _ArtistSectionWidgetState extends State<ArtistSectionWidget> {
  late List<Song> _songs;

  @override
  void initState() {
    super.initState();
    _songs = List.from(widget.initialSongs);
    _fetchMoreSongs();
  }

  Future<void> _fetchMoreSongs() async {
    try {
      final results = await AudiusService.searchSongs(
        widget.artistName,
        limit: 10,
      );
      if (mounted && results.isNotEmpty) {
        setState(() {
          // Mevcut şarkıların üzerine API'den gelenleri ekle (ID kontrolü ile)
          final existingIds = _songs.map((s) => s.id).toSet();
          for (var song in results) {
            if (!existingIds.contains(song.id)) {
              _songs.add(song);
            }
          }
          // Maksimum 10 şarkı göster
          if (_songs.length > 10) {
            _songs = _songs.sublist(0, 10);
          }
        });
      }
    } catch (e) {
      debugPrint("Sanatçı şarkıları yüklenirken hata: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ArtistDetailPage(
                    artistName: widget.artistName,
                    songs: _songs,
                  ),
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    widget.artistName,
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CustomIcons.svgIcon(
                  CustomIcons.arrowRight,
                  size: 18,
                  color: Theme.of(context).primaryColor.withOpacity(0.7),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _songs.length,
            itemBuilder: (context, index) {
              return Container(
                width: 110,
                margin: const EdgeInsets.only(right: 12),
                child: _buildSongCard(_songs[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSongCard(Song song) {
    return SongGridCard(
      song: song,
      imageUrl: song.coverUrl,
      title: song.title,
      subtitle: song.artist,
      onTap: () {
        final provider = context.read<SongProvider>();
        if (provider.currentSong?.id == song.id) {
          if (provider.audioPlayer.playing) {
            provider.audioPlayer.pause();
          } else {
            provider.audioPlayer.play();
          }
        } else {
          provider.playSong(song, _songs);
        }
      },
    );
  }
}
