import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/services/audius_service.dart';
import 'package:muzik_app/pages/player_page.dart';
import 'package:muzik_app/widgets/mini_player.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/widgets/song_card.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';
import 'package:muzik_app/pages/login_page.dart';

class ArtistDetailPage extends StatefulWidget {
  final String artistName;
  final List<Song> songs;

  const ArtistDetailPage({
    super.key,
    required this.artistName,
    required this.songs,
  });

  @override
  State<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends State<ArtistDetailPage> {
  late List<Song> _songs;
  String? _nextPageToken;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    // Başlangıçta elimizdeki şarkıları gösteriyoruz
    _songs = List.from(widget.songs);
    _scrollController.addListener(_onScroll);
    // Arka planda sanatçının tüm şarkılarını çekiyoruz
    _fetchArtistSongs();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreSongs();
    }
  }

  Future<void> _fetchArtistSongs() async {
    try {
      // Sanatçı adına göre Audius'ta arama yap
      final results = await YoutubeService.searchSongs(widget.artistName);
      if (mounted) {
        setState(() {
          _songs = results;
          _nextPageToken = null;
        });
      }
    } catch (e) {
      debugPrint("Sanatçı şarkıları yüklenirken hata: $e");
    }
  }

  Future<void> _loadMoreSongs() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final results = await YoutubeService.searchSongs(
        widget.artistName,
        offset: _songs.length,
      );

      if (mounted && results.isNotEmpty) {
        setState(() {
          _songs.addAll(results);
        });
      }
    } catch (e) {
      debugPrint("Daha fazla şarkı yüklenirken hata: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Favori durumlarını dinlemek için watch kullanıyoruz
    final songProvider = context.watch<SongProvider>();
    final coverUrl = _songs.isNotEmpty ? _songs.first.coverUrl : '';

    final displayedSongs = _songs.where((song) {
      return song.title.toLowerCase().contains(_searchText.toLowerCase());
    }).toList();

    return Scaffold(
      bottomNavigationBar: songProvider.currentSong != null
          ? GestureDetector(
              onTap: () => PlayerPage.show(context),
              child: const MiniPlayer(),
            )
          : null,
      body: CustomScrollView(
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverAppBar(
            expandedHeight: 300.0,
            pinned: true,
            stretch: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            leading: Center(
              child: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(
                    0.4,
                  ), // Kapak resmi üzerinde okunabilir olması için yarı saydam siyah
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const BackButtonIcon(),
                  color: Theme.of(context).primaryColor,
                  iconSize: 27,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.artistName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                ),
              ),
              centerTitle: true,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverUrl.isNotEmpty)
                    Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.grey.shade900, Colors.black],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                  if (coverUrl.isNotEmpty)
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                      child: Container(color: Colors.black.withOpacity(0.4)),
                    ),
                  if (coverUrl.isNotEmpty)
                    Center(
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.grey.shade800,
                                        Colors.black,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Center(
                                    child: CustomIcons.svgIcon(
                                      CustomIcons.person,
                                      size: 60,
                                      color: Colors.white24,
                                    ),
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 20.0, bottom: 8.0),
              child: Center(
                child: Consumer<SongProvider>(
                  builder: (context, provider, _) {
                    final isFollowed = provider.isArtistFollowed(
                      widget.artistName,
                    );

                    final primaryColor = Theme.of(context).primaryColor;
                    Color borderColor;
                    Color bgColor;
                    Widget content;

                    if (isFollowed) {
                      borderColor = primaryColor.withOpacity(0.5);
                      bgColor = primaryColor.withOpacity(0.1);
                      content = Row(
                        key: const ValueKey('followed'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            color: primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Takip Ediliyor",
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    } else {
                      borderColor = Colors.white.withOpacity(0.2);
                      bgColor = Colors.black.withOpacity(0.4);
                      content = Row(
                        key: const ValueKey('follow'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person_add_alt_1_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "Takip Et",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    }

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: borderColor, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: borderColor.withOpacity(0.2),
                                blurRadius: 15,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                if (!provider.isFirebaseLoggedIn) {
                                  _showLoginBottomSheet(context);
                                  return;
                                }
                                provider.toggleFollowArtist(widget.artistName);
                                CustomSnackBar.showInfo(
                                  context: context,
                                  message: isFollowed
                                      ? "${widget.artistName} takipten çıkarıldı."
                                      : "${widget.artistName} takip ediliyor.",
                                );
                              },
                              borderRadius: BorderRadius.circular(30),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: content,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '${widget.artistName} içinde ara...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: CustomIcons.svgIcon(
                      CustomIcons.search,
                      color: Colors.grey,
                      size: 24,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade900,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  suffixIcon: _searchText.isNotEmpty
                      ? IconButton(
                          icon: CustomIcons.svgIcon(
                            CustomIcons.clear,
                            color: Colors.grey,
                            size: 24,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchText = '');
                          },
                        )
                      : null,
                ),
                onChanged: (value) => setState(() => _searchText = value),
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 16.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                if (displayedSongs.isNotEmpty) {
                                  if (!songProvider.isShuffleEnabled) {
                                    songProvider.toggleShuffle();
                                  }
                                  final random = Random();
                                  final randomSong =
                                      displayedSongs[random.nextInt(
                                        displayedSongs.length,
                                      )];
                                  songProvider.playSong(
                                    randomSong,
                                    displayedSongs,
                                  );
                                  CustomSnackBar.showInfo(
                                    context: context,
                                    message: "Liste karışık çalınıyor.",
                                    icon: CustomIcons.svgIcon(
                                      CustomIcons.shuffle,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  );
                                  PlayerPage.show(context);
                                }
                              },
                              borderRadius: BorderRadius.circular(30),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CustomIcons.svgIcon(
                                      CustomIcons.shuffleRounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "Karışık",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.5),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.2),
                                blurRadius: 15,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                if (displayedSongs.isNotEmpty) {
                                  if (songProvider.isShuffleEnabled) {
                                    songProvider.toggleShuffle();
                                  }
                                  songProvider.playSong(
                                    displayedSongs.first,
                                    displayedSongs,
                                  );
                                  CustomSnackBar.showInfo(
                                    context: context,
                                    message: "Liste oynatılıyor.",
                                    icon: CustomIcons.svgIcon(
                                      CustomIcons.playArrow,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  );
                                  PlayerPage.show(context);
                                }
                              },
                              borderRadius: BorderRadius.circular(30),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CustomIcons.svgIcon(
                                      CustomIcons.playArrowRounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "Oynat",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
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
            ),
          ),
          if (displayedSongs.isEmpty && _searchText.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 50.0),
                child: _buildEmptyState(context),
              ),
            ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final song = displayedSongs[index];
              final isCurrentSong = songProvider.currentSong?.id == song.id;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SongCard(
                  song: song,
                  isPlaying: isCurrentSong,
                  showOptions: true,
                  onTap: () {
                    if (isCurrentSong) {
                      if (songProvider.audioPlayer.playing) {
                        songProvider.audioPlayer.pause();
                      } else {
                        songProvider.audioPlayer.play();
                      }
                    } else {
                      songProvider.playSong(song, displayedSongs);
                    }
                    PlayerPage.show(context);
                  },
                ),
              );
            }, childCount: displayedSongs.length),
          ),
          if (_isLoadingMore)
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
          const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
            'Aradığınız kriterlere uygun şarkı bulunamadı.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _showLoginBottomSheet(BuildContext context) {
    CustomBottomSheet.show(
      context: context,
      title: "Takip Etmek için Giriş Yapın",
      message:
          "Sanatçıları takip etmek ve güncellemelerinden haberdar olmak için lütfen giriş yapın.",
      icon: const Icon(
        Icons.person_add_disabled_rounded,
        size: 60,
        color: Colors.white70,
      ),
      primaryButtonText: "Giriş Yap",
      primaryButtonColor: Colors.white,
      primaryButtonTextColor: Colors.black,
      secondaryButtonText: "İptal",
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
