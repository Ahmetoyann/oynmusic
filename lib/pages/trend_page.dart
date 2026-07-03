// lib/pages/trend_page.dart
//
// Bu sayfa, trend olan şarkıları grid görünümünde listeler.
// Şarkıların kapak resimleri, başlıkları ve sanatçı bilgileri gösterilir.
// Her şarkı için indirme butonu ve çalma özelliği sunar.
import 'package:muzik_app/models/song_model.dart';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/services.dart';
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
import 'package:muzik_app/providers/language_provider.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';
import 'package:muzik_app/pages/login_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:muzik_app/widgets/device_cover_placeholder.dart';
import 'package:muzik_app/services/custom_winning_add.dart';

/// Trend şarkıları gösteren ana sayfa widget'ı
class TrendPage extends StatefulWidget {
  const TrendPage({super.key});

  @override
  State<TrendPage> createState() => _TrendPageState();
}

class _TrendPageState extends State<TrendPage> {
  String _selectedFilter = 'all';
  final List<String> _filterKeys = ['all', 'songs', 'collections'];
  ScrollController? _primaryScrollController;
  int _visibleArtistCount = 4;
  int _latestArtistCount = 0;
  bool _isIncrementingLocal = false;

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

  void _onScroll() {}

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
    final langProvider = context.watch<LanguageProvider>();

    // Kullanıcı ilk giriş yaptıysa ona 10 Jetonluk hoşgeldin paketini göster
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          authProvider.user != null &&
          !songProvider.receivedInitialCoins) {
        songProvider.markInitialCoinsReceived();
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) {
              return AlertDialog(
                backgroundColor: Colors.grey.shade900,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.card_giftcard_rounded,
                        color: Colors.amber, size: 64),
                    const SizedBox(height: 16),
                    Text(langProvider.t('welcome_bonus_title'),
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(langProvider.t('welcome_bonus_desc'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: InkWell(
                            onTap: () => Navigator.pop(ctx),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.amber.withOpacity(0.5),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  langProvider.t('thanks'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            });
      } else if (mounted && authProvider.user != null) {
        // İlk 10 jetonunu almış kullanıcılara günlük giriş +1 Jeton ödülünü kontrol et
        songProvider.checkAndGrantDailyReward();
      }
    });

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
                          ? CachedNetworkImageProvider(
                              authProvider.user!.photoURL!,
                              maxHeight: 150,
                            )
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
          height: 24, // Yüksekliği azaltıp daha minimal hale getirdik
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(right: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _filterKeys.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: 4), // Aralarındaki boşluğu daralttık
            itemBuilder: (context, index) {
              final filterKey = _filterKeys[index];
              final isSelected = _selectedFilter == filterKey;
              return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFilter = filterKey;
                    });
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      12,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6, // İç yan boşlukları daralttık
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).primaryColor.withOpacity(0.25)
                            : Colors.grey.shade800.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).primaryColor.withOpacity(0.5)
                              : Colors.transparent,
                          width: 1.0, // Çerçeveyi incelttik
                        ),
                      ),
                      child: Text(
                        langProvider.t(filterKey).toUpperCase(),
                        style: TextStyle(
                          color:
                              isSelected ? Colors.white : Colors.grey.shade400,
                          fontWeight: FontWeight.w600,
                          fontSize: 9, // Yazı boyutunu daha da küçülttük
                          letterSpacing: 0.0, // Harf aralığı kaldırıldı
                        ),
                      ),
                    ),
                  ));
            },
          ),
        ),
        titleSpacing: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: GestureDetector(
                onTap: () => CustomWinningAd.showCoinScreen(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.amber.withOpacity(0.5), width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on_rounded,
                          color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                            begin: songProvider.coins.toDouble(),
                            end: songProvider.coins.toDouble()),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeOutExpo,
                        builder: (context, value, child) {
                          return Text(
                            '${value.toInt()}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          );
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
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final langProvider = context.watch<LanguageProvider>();
    final isLoading = context.select<SongProvider, bool>((p) => p.isLoading);
    final errorMessage =
        context.select<SongProvider, String?>((p) => p.errorMessage);
    final provider = context.read<SongProvider>();

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return RefreshIndicator(
        color: Theme.of(context).primaryColor,
        backgroundColor: Colors.grey.shade900,
        onRefresh: () async {
          setState(() => _visibleArtistCount = 4);
          await provider.fetchSongsFromApi(forceRefresh: true);
        },
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.025,
                    vertical: 16.0,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${langProvider.t('error')}: $errorMessage',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red.shade300),
                      ),
                      const SizedBox(height: 24),
                      _buildRefreshButton(context, provider),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Normal Trend Listesi
    // Sadece kapak resmi olan şarkıları filtreleyerek UI'a gönderiyoruz
    final allSongs =
        context.select<SongProvider, List<Song>>((p) => p.allSongs);
    final songs = allSongs.where(_hasValidCover).toList();

    if (songs.isEmpty) {
      return RefreshIndicator(
        color: Theme.of(context).primaryColor,
        backgroundColor: Colors.grey.shade900,
        onRefresh: () async {
          setState(() => _visibleArtistCount = 4);
          await provider.fetchSongsFromApi(forceRefresh: true);
        },
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: _buildNoResultsFound(context),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: Theme.of(context).primaryColor,
      backgroundColor: Colors.grey.shade900,
      onRefresh: () async {
        setState(() => _visibleArtistCount = 4);
        await provider.fetchSongsFromApi(forceRefresh: true);
      },
      child: _buildArtistList(context, songs),
    );
  }

  Widget _buildNoResultsFound(BuildContext context) {
    final langProvider = context.watch<LanguageProvider>();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CustomIcons.svgIcon(
              CustomIcons.searchOff,
              size: 64,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            langProvider.t('no_results'),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              langProvider.t('try_different_search'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
            ),
          ),
          const SizedBox(height: 32),
          _buildRefreshButton(context, context.read<SongProvider>()),
        ],
      ),
    );
  }

  Widget _buildRefreshButton(BuildContext context, SongProvider provider) {
    final langProvider = context.read<LanguageProvider>();
    return OutlinedButton.icon(
      onPressed: () {
        setState(() => _visibleArtistCount = 4);
        provider.fetchSongsFromApi(forceRefresh: true);
      },
      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
      label: Text(
        langProvider.t('retry'),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: Theme.of(context).primaryColor.withOpacity(0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
      ),
    );
  }

  Widget _buildArtistList(
    BuildContext context,
    List<Song> songs, {
    bool isSearch = false,
  }) {
    final songProvider = context.read<SongProvider>();
    final currentSong =
        context.select<SongProvider, Song?>((p) => p.currentSong);
    final dailySongs =
        context.select<SongProvider, List<Song>>((p) => p.dailySongs);
    final mostPlayed =
        context.select<SongProvider, List<Song>>((p) => p.mostPlayed);
    final isLoadingMore =
        context.select<SongProvider, bool>((p) => p.isLoadingMore);
    final langProvider = context.watch<LanguageProvider>();
    final double bottomPadding = currentSong != null ? 160 : 100;
    // Şarkıları Sanatçı adına göre grupluyoruz
    final Map<String, List<Song>> groupedByArtist = {};
    for (var song in songs) {
      if (!groupedByArtist.containsKey(song.artist)) {
        groupedByArtist[song.artist] = [];
      }
      groupedByArtist[song.artist]!.add(song);
    }

    // Sağ tarafta her zaman en az 2 şarkı gösterilebilmesi için (Sol 1 + Sağ 2)
    // toplam şarkı sayısı 3'ten az olan sanatçıları listeden çıkarıyoruz.
    groupedByArtist.removeWhere((key, value) => value.length < 3);

    final sortedEntries = groupedByArtist.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    final sortedArtists = sortedEntries.map((e) => e.key).toList();
    _latestArtistCount = sortedArtists.length;

    // Eğer filtreleme sonrasında ekranda 4'ten az sanatçı kaldıysa otomatik daha fazla yükle
    if (sortedArtists.length < 4 &&
        !isLoadingMore &&
        songs.isNotEmpty &&
        songs.length < 150) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SongProvider>().loadMoreSongs();
      });
    }

    // Performans için gösterilecek sanatçı sayısını 4 ile sınırlıyoruz, kaydırdıkça artacak
    final displayedArtists = sortedArtists.take(_visibleArtistCount).toList();

    final bool showAll = isSearch || _selectedFilter == 'all';
    final bool showSongs = !isSearch && _selectedFilter == 'songs';
    final bool showAlbumsOnly = !isSearch && _selectedFilter == 'collections';

    final suggestedAlbums =
        context.select<SongProvider, List<Song>>((p) => p.suggestedAlbums);

    // Trend şarkıları arasından koleksiyonları (mix/albüm) filtrele
    List<Song> collectionSongs = songs.where((song) {
      final title = song.title.toLowerCase();
      return title.contains('mix') ||
          title.contains('albüm') ||
          title.contains('album') ||
          title.contains('playlist') ||
          title.contains('set');
    }).toList();

    // Eğer trendlerde yeterince koleksiyon yoksa, önerilen mix'lerle doldur
    if (collectionSongs.length < 4 && suggestedAlbums.isNotEmpty) {
      final existingIds = collectionSongs.map((s) => s.id).toSet();
      for (var mix in suggestedAlbums) {
        if (!existingIds.contains(mix.id)) {
          collectionSongs.add(mix);
        }
      }
    }

    final List<Song> displayedCollections;
    if (showAlbumsOnly) {
      displayedCollections = collectionSongs;
    } else if (showAll) {
      displayedCollections = collectionSongs.take(10).toList();
    } else {
      displayedCollections = [];
    }

    final bool useGrid = showAlbumsOnly;
    final primaryColor = Theme.of(context).primaryColor;

    // Günün şarkıları ve son dinlenenler için de sadece resmi olanları filtrele
    final validDailySongs = dailySongs
        .where(
          (s) =>
              s.coverUrl.isNotEmpty &&
              !s.coverUrl.contains('via.placeholder.com'),
        )
        .toList();

    return CustomScrollView(
      controller: _primaryScrollController,
      physics:
          const AlwaysScrollableScrollPhysics(), // Listenin her zaman kaydırılabilir olmasını (ve yenilenebilmesini) sağlar
      slivers: [
        // Günün Şarkıları Listesi
        if (!isSearch && (showAll || showSongs) && validDailySongs.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildDailySongsList(context, validDailySongs),
          ),

        // --- SENİN HAFTALIK MİX'İN (YOUR MIX) ---
        if (!isSearch && (showAll || showSongs) && mostPlayed.length > 5)
          SliverToBoxAdapter(
            child: _buildYourMixList(context, mostPlayed),
          ),

        // --- KOLEKSİYONLAR BÖLÜMÜ ---
        if (displayedCollections.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                MediaQuery.of(context).size.width * 0.025,
                16,
                MediaQuery.of(context).size.width * 0.025,
                12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    showAlbumsOnly
                        ? langProvider.t('all_collections')
                        : langProvider.t('featured_collections'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (displayedCollections.isNotEmpty)
          useGrid
              ? SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.025,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.15,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final collection = displayedCollections[index];
                      return _buildCollectionCard(
                        context,
                        collection,
                        isGrid: true,
                      );
                    }, childCount: displayedCollections.length),
                  ),
                )
              : SliverToBoxAdapter(
                  child: SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width * 0.025,
                      ),
                      itemCount: displayedCollections.length,
                      itemBuilder: (context, index) {
                        final collection = displayedCollections[index];
                        return Container(
                          width: 150,
                          margin: const EdgeInsets.only(right: 16),
                          child: _buildCollectionCard(
                            context,
                            collection,
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
              final artistName = displayedArtists[index];
              final initialSongs = groupedByArtist[artistName]!;
              return ArtistSectionWidget(
                artistName: artistName,
                initialSongs: initialSongs,
              );
            }, childCount: displayedArtists.length),
          ),

        // + Daha fazla sanatçı Butonu
        if ((showAll || showSongs) && !isLoadingMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    final provider = context.read<SongProvider>();
                    if (_visibleArtistCount < _latestArtistCount) {
                      setState(() {
                        _visibleArtistCount += 4;
                      });
                    } else if (!provider.isLoadingMore) {
                      provider.loadMoreSongs().then((_) {
                        if (mounted) {
                          setState(() {
                            _visibleArtistCount += 4;
                          });
                        }
                      }).catchError((e) {
                        if (mounted) {
                          CustomSnackBar.showError(
                            context: context,
                            message: langProvider.t('cannot_load_more'),
                          );
                        }
                      });
                    }
                  },
                  child: Text(
                    langProvider.t('more_artists'),
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
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
        SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
      ],
    );
  }

  Widget _buildCollectionCard(
    BuildContext context,
    Song collectionSong, {
    required bool isGrid,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SongGridCard(
          imageUrl: collectionSong.coverUrl,
          title: collectionSong.title,
          showFavorite: false, // Albüm kartında favori butonu göstermiyoruz
          placeholderIcon: CustomIcons.album,
          titleMaxLines: 2,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ArtistDetailPage(
                  artistName: collectionSong.title,
                  songs: [collectionSong],
                  isCollection: true,
                ),
              ),
            );
          },
        ),
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SongGridCard(
          song: song,
          imageUrl: song.coverUrl,
          title: song.title,
          subtitle: song.artist,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ArtistDetailPage(
                    artistName: song.artist, songs: artistSongs),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDailySongsList(BuildContext context, List<Song> songs) {
    if (songs.isEmpty) return const SizedBox.shrink();
    // Listeden sadece ilk şarkıyı alıp "Günün Şarkısı" kartına gönderiyoruz.
    // İsteğe bağlı olarak Rastgele bir şarkı da seçilebilir (songs..shuffle()).

    return DailySongCard(song: songs.first, playlist: songs);
  }

  Widget _buildYourMixList(BuildContext context, List<Song> mostPlayed) {
    final langProvider = context.read<LanguageProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final artistSongWidth = (screenWidth - 60) / 2.8;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.of(context).size.width * 0.025,
            12,
            MediaQuery.of(context).size.width * 0.025,
            12,
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                langProvider.t('your_weekly_mix'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: (artistSongWidth * 9 / 16) + 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width * 0.025,
            ),
            itemCount: mostPlayed.length > 20 ? 20 : mostPlayed.length,
            itemBuilder: (context, index) {
              final song = mostPlayed[index];

              Widget imageWidget;
              if (song.localImagePath != null &&
                  File(song.localImagePath!).existsSync()) {
                imageWidget = Image.file(
                  File(song.localImagePath!),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                );
              } else if (song.coverUrl.isEmpty) {
                imageWidget = DeviceCoverPlaceholder(
                  logoColor: Theme.of(context).primaryColor,
                  borderRadius: 4,
                );
              } else {
                imageWidget = CachedNetworkImage(
                  imageUrl: song.coverUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorWidget: (context, url, error) => DeviceCoverPlaceholder(
                    logoColor: Theme.of(context).primaryColor,
                    borderRadius: 4,
                  ),
                );
              }

              return Container(
                  width: artistSongWidth,
                  margin: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: () {
                      SongCard.showModernMenu(
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
                            provider.playSong(song, mostPlayed);
                          }
                        },
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: imageWidget,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 11)),
                      ],
                    ),
                  ));
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
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isFollowed = context.select<SongProvider, bool>(
        (p) => p.isArtistFollowed(widget.artistName));
    final isFirebaseLoggedIn =
        context.select<SongProvider, bool>((p) => p.isFirebaseLoggedIn);
    final langProvider = context.watch<LanguageProvider>();
    final primaryColor = Theme.of(context).primaryColor;

    return Padding(
        padding: EdgeInsets.fromLTRB(
          screenWidth * 0.025,
          16,
          screenWidth * 0.025,
          12, // Sanatçı blokları arası mesafe daraltıldı
        ),
        child: IntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Sanatçı Adı ve Takip Butonu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ArtistDetailPage(
                              artistName: widget.artistName,
                              songs: widget.initialSongs,
                            ),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          _SmallArtistAvatar(
                            artistName: widget.artistName,
                            songProvider: context.read<SongProvider>(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.artistName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      if (!isFirebaseLoggedIn) {
                        _showLoginBottomSheet(context);
                        return;
                      }
                      context
                          .read<SongProvider>()
                          .toggleFollowArtist(widget.artistName);
                      CustomSnackBar.showInfo(
                          context: context,
                          message: isFollowed
                              ? langProvider
                                  .t('artist_unfollowed')
                                  .replaceAll('%s', widget.artistName)
                              : langProvider
                                  .t('artist_followed_snack')
                                  .replaceAll('%s', widget.artistName));
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isFollowed
                            ? primaryColor.withOpacity(0.15)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isFollowed
                              ? primaryColor.withOpacity(0.5)
                              : Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFollowed
                                ? Icons.check_rounded
                                : Icons.person_add_alt_1_rounded,
                            color: isFollowed ? primaryColor : Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isFollowed
                                ? langProvider.t('followed')
                                : langProvider.t('follow'),
                            style: TextStyle(
                              color: isFollowed ? primaryColor : Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 2. Şarkılar Alanı (Kapak ve Liste)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sol: İlk Şarkı (16:9 Kapak ve Başlık)
                  if (widget.initialSongs.isNotEmpty)
                    SizedBox(
                      width: screenWidth * 0.38,
                      child: _buildSongCard(widget.initialSongs.first),
                    ),
                  const SizedBox(width: 12),
                  // Sağ: Şarkı Listesi ve +Sayı
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.initialSongs.length > 1)
                          _buildCompactListSong(widget.initialSongs[1]),
                        if (widget.initialSongs.length > 2)
                          _buildCompactListSong(widget.initialSongs[2]),
                        if (widget.initialSongs.length > 3)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ArtistDetailPage(
                                    artistName: widget.artistName,
                                    songs: widget.initialSongs,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(
                                langProvider.t('see_more'),
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ));
  }

  Widget _buildSongCard(Song song) {
    final isFav = context.select<SongProvider, bool>(
      (p) => p.favoriteSongs.any((s) => s.id == song.id),
    );

    return GestureDetector(
      onTap: () {
        SongCard.showModernMenu(
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
              provider.playSong(song, widget.initialSongs);
            }
          },
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: (song.localImagePath != null &&
                          File(song.localImagePath!).existsSync())
                      ? Image.file(
                          File(song.localImagePath!),
                          fit: BoxFit.cover,
                          cacheHeight: 300,
                        )
                      : CachedNetworkImage(
                          imageUrl: song.coverUrl,
                          fit: BoxFit.cover,
                          memCacheHeight: 300,
                          errorWidget: (context, url, error) =>
                              DeviceCoverPlaceholder(
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: 6,
                            logoColor: Theme.of(context).primaryColor,
                          ),
                        ),
                ),
                if (isFav)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.greenAccent,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactListSong(Song song) {
    final provider = context.read<SongProvider>();
    final isCurrentSong = provider.currentSong?.id == song.id;
    final primaryColor = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: () {
        SongCard.showModernMenu(
          context,
          song,
          onTap: () {
            if (provider.currentSong?.id == song.id) {
              if (provider.audioPlayer.playing) {
                provider.audioPlayer.pause();
              } else {
                provider.audioPlayer.play();
              }
            } else {
              provider.playSong(song, widget.initialSongs);
            }
          },
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        color: Colors.transparent,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 71,
                height: 40,
                child: (song.localImagePath != null &&
                        File(song.localImagePath!).existsSync())
                    ? Image.file(
                        File(song.localImagePath!),
                        fit: BoxFit.cover,
                        cacheHeight: 150,
                      )
                    : CachedNetworkImage(
                        imageUrl: song.coverUrl,
                        fit: BoxFit.cover,
                        memCacheHeight: 150,
                        errorWidget: (context, url, error) =>
                            DeviceCoverPlaceholder(
                          width: 71,
                          height: 40,
                          borderRadius: 4,
                          logoColor: Theme.of(context).primaryColor,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrentSong ? primaryColor : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrentSong
                          ? primaryColor.withOpacity(0.7)
                          : Colors.grey.shade400,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLoginBottomSheet(BuildContext context) {
    final langProvider = context.read<LanguageProvider>();

    CustomBottomSheet.show(
      context: context,
      title: langProvider.t('login_to_follow'),
      message: langProvider.t('login_to_follow_desc'),
      icon: const Icon(
        Icons.person_add_disabled_rounded,
        size: 60,
        color: Colors.white70,
      ),
      primaryButtonText: langProvider.t('login_to_continue'),
      primaryButtonColor: Colors.white,
      primaryButtonTextColor: Colors.black,
      secondaryButtonText: langProvider.t('cancel'),
      onPrimaryButtonTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      },
    );
  }
}

/// Sanatçıların isminin yanında duran, etrafı ışıltılı küçük profil avatarı
class _SmallArtistAvatar extends StatefulWidget {
  final String artistName;
  final SongProvider songProvider;

  const _SmallArtistAvatar({
    required this.artistName,
    required this.songProvider,
  });

  @override
  State<_SmallArtistAvatar> createState() => _SmallArtistAvatarState();
}

class _SmallArtistAvatarState extends State<_SmallArtistAvatar> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    if (widget.songProvider.getArtistAvatar(widget.artistName) != null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    await widget.songProvider.fetchArtistAvatar(widget.artistName);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final avatarUrl =
        widget.songProvider.getArtistAvatar(widget.artistName) ?? '';

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: primaryColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: _isLoading && avatarUrl.isEmpty
            ? DeviceCoverPlaceholder(
                width: 36,
                height: 36,
                borderRadius: 18,
                logoColor: Theme.of(context).primaryColor,
              )
            : CachedNetworkImage(
                imageUrl: avatarUrl.isNotEmpty
                    ? avatarUrl
                    : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(widget.artistName)}&background=random&color=fff&size=100',
                fit: BoxFit.cover,
                placeholder: (context, url) => DeviceCoverPlaceholder(
                  width: 36,
                  height: 36,
                  borderRadius: 18,
                  logoColor: Theme.of(context).primaryColor,
                ),
                errorWidget: (context, url, error) => DeviceCoverPlaceholder(
                  width: 36,
                  height: 36,
                  borderRadius: 18,
                  logoColor: Theme.of(context).primaryColor,
                ),
              ),
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
  String _getPersonalizedGreeting(BuildContext context, String? displayName) {
    final hour = DateTime.now().hour;
    final langProvider = context.read<LanguageProvider>();
    String greetingKey;

    if (hour >= 6 && hour < 12) {
      greetingKey = 'good_morning';
    } else if (hour >= 12 && hour < 18) {
      greetingKey = 'good_afternoon';
    } else if (hour >= 18 && hour < 22) {
      greetingKey = 'good_evening';
    } else {
      greetingKey = 'good_night';
    }
    final greeting = langProvider.t(greetingKey);

    final songOfTheDay = langProvider.t('song_of_the_day');

    if (displayName != null && displayName.trim().isNotEmpty) {
      final firstName = displayName.trim().split(' ').first;
      return '$greeting $firstName, $songOfTheDay';
    }
    return '$greeting, $songOfTheDay';
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentSong = context
        .select<SongProvider, bool>((p) => p.currentSong?.id == widget.song.id);
    final provider = context.read<SongProvider>();
    final primaryColor = Theme.of(context).primaryColor;
    final langProvider = context.watch<LanguageProvider>();
    final authProvider = context.watch<AuthProvider>();
    final personalizedTitle = _getPersonalizedGreeting(
      context,
      authProvider.user?.displayName,
    );
    final horizontalPadding = MediaQuery.of(context).size.width * 0.025;

    return Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          16,
          horizontalPadding,
          16,
        ),
        child: RepaintBoundary(
          child: GestureDetector(
            onTap: () {
              // Kartın geneline tıklandığında seçenekler menüsünü aç
              SongCard.showModernMenu(
                context,
                widget.song,
                onTap: () {
                  // Menüden "Oynat" seçilirse çalma işlemini yap
                  if (provider.currentSong?.id == widget.song.id) {
                    if (provider.audioPlayer.playing) {
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
              decoration:
                  BoxDecoration(borderRadius: BorderRadius.circular(24)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1.5,
                    ),
                  ),
                  child: Row(children: [
                    // Kapak Resmi
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: widget.song.coverUrl,
                        width: 112,
                        height: 63,
                        fit: BoxFit.cover,
                        memCacheHeight: 250,
                        errorWidget: (context, url, error) =>
                            DeviceCoverPlaceholder(
                          width: 112,
                          height: 63,
                          borderRadius: 10,
                          logoColor: Theme.of(context).primaryColor,
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.local_fire_department_rounded,
                                color: primaryColor,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  personalizedTitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    height: 1.2,
                                  ),
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
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
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
                          if (provider.audioPlayer.playing) {
                            provider.audioPlayer.pause();
                          } else {
                            provider.audioPlayer.play();
                          }
                        } else {
                          provider.playSong(widget.song, widget.playlist);
                        }
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: primaryColor.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: StreamBuilder<bool>(
                            stream: provider.audioPlayer.playingStream,
                            builder: (context, snapshot) {
                              final playing = snapshot.data ?? false;
                              final isPlayingNow = isCurrentSong && playing;
                              return CustomIcons.svgIcon(
                                isPlayingNow
                                    ? CustomIcons.pauseRounded
                                    : CustomIcons.playArrowRounded,
                                color: Colors.white,
                                size: 20,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ]),
                ),
              ),
            ),
          ),
        ));
  }
}
