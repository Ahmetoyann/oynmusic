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
  String _selectedFilter = 'TÜMÜ';
  final List<String> _filters = ['TÜMÜ', 'ŞARKILAR', 'ALBÜMLER'];
  ScrollController? _primaryScrollController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentController = PrimaryScrollController.maybeOf(context);
    if (_primaryScrollController != currentController) {
      _primaryScrollController?.removeListener(_onScroll);
      _primaryScrollController = currentController;
      _primaryScrollController?.addListener(_onScroll);
    }
  }

  void _onScroll() {
    // Listenin sonuna 200 piksel kala yeni şarkıları yükle
    if (_primaryScrollController != null &&
        _primaryScrollController!.hasClients) {
      if (_primaryScrollController!.position.pixels >=
          _primaryScrollController!.position.maxScrollExtent - 200) {
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
  }

  @override
  void dispose() {
    _primaryScrollController?.removeListener(_onScroll);
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
        backgroundColor: const Color(0xFF121212),
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
      controller: _primaryScrollController,
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
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
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
                          margin: const EdgeInsets.only(right: 16),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SongGridCard(
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
      ),
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
    if (songs.isEmpty) return const SizedBox.shrink();
    // Listeden sadece ilk şarkıyı alıp "Günün Şarkısı" kartına gönderiyoruz.
    // İsteğe bağlı olarak Rastgele bir şarkı da seçilebilir (songs..shuffle()).
    return DailySongCard(song: songs.first, playlist: songs);
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
    final screenWidth = MediaQuery.of(context).size.width;
    final artistSongWidth = (screenWidth - 60) / 2.8;

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
                        fontSize: 12,
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
          height: artistSongWidth + 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _songs.length > 10 ? 11 : _songs.length,
            itemBuilder: (context, index) {
              if (_songs.length > 10 && index == 10) {
                return Container(
                  width: artistSongWidth,
                  margin: const EdgeInsets.only(right: 16),
                  child: _buildSeeMoreCard(context),
                );
              }
              return Container(
                width: artistSongWidth,
                margin: const EdgeInsets.only(right: 16),
                child: _buildSongCard(_songs[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSongCard(Song song) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SongGridCard(
        song: song,
        imageUrl: song.coverUrl,
        title: song.title,
        subtitle: song.artist,
        onTap: () {
          SongCard.showOptionsSheet(
            context,
            song,
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
        },
      ),
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
                        fontSize: 10,
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
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "Sanatçı",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

/// Günün Şarkısı için modern, buzlu arka planlı ve animasyonlu özel kart
class DailySongCard extends StatefulWidget {
  final Song song;
  final List<Song> playlist;

  const DailySongCard({super.key, required this.song, required this.playlist});

  @override
  State<DailySongCard> createState() => _DailySongCardState();
}

class _DailySongCardState extends State<DailySongCard> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SongProvider>();
    final isPlaying =
        provider.currentSong?.id == widget.song.id &&
        provider.audioPlayer.playing;
    final primaryColor = Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: GestureDetector(
        onTap: () {
          // Kartın geneline tıklandığında seçenekler menüsünü aç
          SongCard.showOptionsSheet(
            context,
            widget.song,
            onTap: () {
              // Menüden "Oynat" seçilirse çalma işlemini yap
              if (provider.currentSong?.id == widget.song.id) {
                if (isPlaying) {
                  provider.audioPlayer.pause();
                } else {
                  provider.audioPlayer.play();
                }
              } else {
                provider.playSong(widget.song, widget.playlist);
              }
            },
          );
        },
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    // Kapak Resmi
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Transform.scale(
                        scale:
                            (widget.song.coverUrl.contains('ytimg.com') ||
                                widget.song.coverUrl.contains('youtube.com'))
                            ? 1.35
                            : 1.0,
                        child: Image.network(
                          widget.song.coverUrl,
                          width: 76,
                          height: 76,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 76,
                                height: 76,
                                color: Colors.grey.shade800,
                                child: const Icon(
                                  Icons.music_note,
                                  color: Colors.white54,
                                ),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Şarkı Bilgileri
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.local_fire_department_rounded,
                                color: primaryColor,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Günün Şarkısı",
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Oynat/Duraklat Butonu
                    GestureDetector(
                      onTap: () {
                        // Sadece butona tıklandığında direkt çal/durdur
                        if (provider.currentSong?.id == widget.song.id) {
                          if (isPlaying) {
                            provider.audioPlayer.pause();
                          } else {
                            provider.audioPlayer.play();
                          }
                        } else {
                          provider.playSong(widget.song, widget.playlist);
                        }
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: primaryColor.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: CustomIcons.svgIcon(
                            isPlaying
                                ? CustomIcons.pauseRounded
                                : CustomIcons.playArrowRounded,
                            color: primaryColor,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
