// lib/pages/trend_page.dart
//
// Bu sayfa, trend olan şarkıları grid görünümünde listeler.
// Şarkıların kapak resimleri, başlıkları ve sanatçı bilgileri gösterilir.
// Her şarkı için indirme butonu ve çalma özelliği sunar.
import 'package:muzik_app/models/song_model.dart';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/pages/artist_detail_page.dart';
import 'package:muzik_app/providers/auth_provider.dart';
import 'package:muzik_app/pages/profile_page.dart';
import 'package:muzik_app/services/audius_service.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/widgets/song_card.dart';
import 'package:muzik_app/widgets/song_grid_card.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:muzik_app/pages/player_page.dart';
import 'package:muzik_app/widgets/custom_banner_ad.dart';

/// Trend şarkıları gösteren ana sayfa widget'ı
class TrendPage extends StatefulWidget {
  const TrendPage({super.key});

  @override
  State<TrendPage> createState() => _TrendPageState();
}

class _TrendPageState extends State<TrendPage> {
  final ScrollController _scrollController = ScrollController();
  // bool _isSongGrid = false;
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
      provider.loadMoreSongs().catchError((e) {
        if (mounted) {
          // Varsa önceki uyarıyı gizle
          CustomSnackBar.showError(
            context: context,
            message: 'Daha fazla şarkı yüklenemedi.',
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

  // Geçerli bir kapak resmi olup olmadığını kontrol eden filtre mekanizması
  bool _hasValidCover(Song song) {
    final url = song.coverUrl;
    return url.isNotEmpty && !url.contains('via.placeholder.com');
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = context.watch<SongProvider>();
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
            child: CircleAvatar(
              backgroundColor: Colors.grey.shade800,
              backgroundImage: authProvider.user?.photoURL != null
                  ? (authProvider.user!.photoURL!.startsWith('http')
                            ? NetworkImage(authProvider.user!.photoURL!)
                            : FileImage(File(authProvider.user!.photoURL!)))
                        as ImageProvider
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
        title: SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = _filters[index];
              final isSelected = _selectedFilter == filter;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).primaryColor.withOpacity(0.2)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).primaryColor.withOpacity(0.5)
                              : Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade400,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        titleSpacing: 0,
      ),
      // İçerik Alanı (Yükleniyor, Hata veya Liste)
      body: Column(
        children: [
          Expanded(child: _buildBody(context, songProvider)),
          const CustomBannerAd(),
        ],
      ),
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

    // Normal Trend Listesi
    // Sadece kapak resmi olan şarkıları filtreleyerek UI'a gönderiyoruz
    final songs = provider.allSongs.where(_hasValidCover).toList();

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

    final bool useGrid = showAlbumsOnly;
    final primaryColor = Theme.of(context).primaryColor;

    // Günün şarkıları ve son dinlenenler için de sadece resmi olanları filtrele
    final validDailySongs = songProvider.dailySongs
        .where(
          (s) =>
              s.coverUrl.isNotEmpty &&
              !s.coverUrl.contains('via.placeholder.com'),
        )
        .toList();

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Günün Şarkıları Listesi
        if (!isSearch && (showAll || showSongs) && validDailySongs.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildDailySongsList(context, validDailySongs),
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
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
                    height: 190,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: displayedAlbums.length,
                      itemBuilder: (context, index) {
                        final entry = displayedAlbums[index];
                        return Container(
                          width: 150,
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
        context.read<SongProvider>().checkAndShowAdForArtist();
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

  Widget _buildSongListTile(
    BuildContext context,
    Song song,
    List<Song> artistSongs,
  ) {
    return SongCard(
      song: song,
      showOptions: true,
      onTap: () {
        context.read<SongProvider>().checkAndShowAdForArtist();
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
        context.read<SongProvider>().checkAndShowAdForArtist();
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
    final provider = context.read<SongProvider>();
    final currentSongId = provider.currentSong?.id;
    final isPlayingState = provider.audioPlayer.playing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            "Günün Şarkıları",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
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
              final isPlaying = currentSongId == song.id && isPlayingState;

              return GestureDetector(
                onTap: () {
                  if (provider.currentSong?.id == song.id) {
                    if (provider.audioPlayer.playing) {
                      provider.audioPlayer.pause();
                    } else {
                      provider.audioPlayer.play();
                    }
                  } else {
                    provider.playSong(song, songs);
                  }
                  PlayerPage.show(context);
                },
                child: Container(
                  width: 86,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).primaryColor,
                              Colors.purpleAccent.withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                            image: DecorationImage(
                              image: NetworkImage(song.coverUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: isPlaying
                              ? Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: CustomIcons.svgIcon(
                                    CustomIcons.graphicEq,
                                    color: Theme.of(context).primaryColor,
                                    size: 24,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isPlaying
                              ? Theme.of(context).primaryColor
                              : Colors.white.withOpacity(0.9),
                          fontSize: 10,
                          fontWeight: isPlaying
                              ? FontWeight.bold
                              : FontWeight.w500,
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

class _ArtistSectionWidgetState extends State<ArtistSectionWidget>
    with SingleTickerProviderStateMixin {
  late List<Song> _songs;
  late AnimationController _arrowController;
  late Animation<Offset> _arrowAnimation;

  @override
  void initState() {
    super.initState();
    _songs = List.from(widget.initialSongs);
    _fetchMoreSongs();
    // Ok ikonunun ileri-geri hareket etmesi için animasyon denetleyicisi
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _arrowAnimation =
        Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0.3, 0.0), // X ekseninde sağa doğru %30 kayma
        ).animate(
          CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
        );
  }

  @override
  void dispose() {
    _arrowController.dispose();
    super.dispose();
  }

  Future<void> _fetchMoreSongs() async {
    try {
      final results = await YoutubeService.searchSongs(
        widget.artistName,
        limit: 10,
      );
      if (mounted && results.isNotEmpty) {
        setState(() {
          // Kapak resmi olmayanları (placeholder vb.) burada da filtrele
          final validResults = results
              .where(
                (s) =>
                    s.coverUrl.isNotEmpty &&
                    !s.coverUrl.contains('via.placeholder.com'),
              )
              .toList();

          // Mevcut şarkıların üzerine API'den gelenleri ekle (ID kontrolü ile)
          final existingIds = _songs.map((s) => s.id).toSet();
          for (var song in validResults) {
            if (!existingIds.contains(song.id)) {
              _songs.add(song);
            }
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
              context.read<SongProvider>().checkAndShowAdForArtist();
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.2),
                    Colors.transparent,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomIcons.svgIcon(
                    CustomIcons.person,
                    color: Theme.of(context).primaryColor,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.artistName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SlideTransition(
                    position: _arrowAnimation,
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: Theme.of(context).primaryColor,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _songs.length > 10 ? 11 : _songs.length,
            itemBuilder: (context, index) {
              if (_songs.length > 10 && index == 10) {
                return Container(
                  width: 110,
                  margin: const EdgeInsets.only(right: 12),
                  child: _buildSeeMoreCard(context),
                );
              }
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
        PlayerPage.show(context);
      },
    );
  }

  Widget _buildSeeMoreCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.read<SongProvider>().checkAndShowAdForArtist();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ArtistDetailPage(artistName: widget.artistName, songs: _songs),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Theme.of(context).primaryColor,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Devamını\nGör",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Tümü",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "Sanatçı",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
