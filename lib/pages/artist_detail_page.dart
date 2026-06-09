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
import 'package:muzik_app/providers/language_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:muzik_app/widgets/custom_search_bar.dart';

class ArtistDetailPage extends StatefulWidget {
  final String artistName;
  final List<Song> songs;
  final bool isCollection;

  const ArtistDetailPage({
    super.key,
    required this.artistName,
    required this.songs,
    this.isCollection = false,
  });

  @override
  State<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends State<ArtistDetailPage>
    with SingleTickerProviderStateMixin {
  late List<Song> _songs;
  String? _nextPageToken;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _showSearchBar = false;
  bool _showStickyPlayButton = false;

  @override
  void initState() {
    super.initState();
    // Başlangıçta elimizdeki şarkıları gösteriyoruz
    _songs = List.from(widget.songs);
    _scrollController.addListener(_onScroll);

    // Arka planda sanatçının tüm şarkılarını çekiyoruz
    _fetchArtistSongs();

    if (!widget.isCollection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SongProvider>().fetchArtistAvatar(widget.artistName);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreSongs();
      }

      if (_scrollController.offset > 280 && !_showStickyPlayButton) {
        setState(() => _showStickyPlayButton = true);
      } else if (_scrollController.offset <= 280 && _showStickyPlayButton) {
        setState(() => _showStickyPlayButton = false);
      }

      // Yukarıdan aşağı (pull-down) çekildiğinde arama çubuğunu göster
      if (_scrollController.offset < -20 && !_showSearchBar) {
        setState(() => _showSearchBar = true);
      } else if (_scrollController.offset > 20 &&
          _showSearchBar &&
          _searchText.isEmpty) {
        setState(() => _showSearchBar = false);
      }
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
    final langProvider = context.watch<LanguageProvider>();
    // Favori durumlarını dinlemek için watch kullanıyoruz
    final songProvider = context.watch<SongProvider>();
    String coverUrl = _songs.isNotEmpty ? _songs.first.coverUrl : '';

    if (!widget.isCollection) {
      final artistAvatar = songProvider.getArtistAvatar(widget.artistName);
      if (artistAvatar != null && artistAvatar.isNotEmpty) {
        coverUrl = artistAvatar;
      }
    }

    final displayedSongs = _songs.where((song) {
      return song.title.toLowerCase().contains(_searchText.toLowerCase());
    }).toList();

    final bool isAnyLoaded = songProvider.currentSong != null &&
        displayedSongs.any((s) => s.id == songProvider.currentSong!.id);

    void handlePlayTap() {
      if (displayedSongs.isNotEmpty) {
        if (isAnyLoaded) {
          if (songProvider.audioPlayer.playing) {
            songProvider.audioPlayer.pause();
          } else {
            songProvider.audioPlayer.play();
          }
        } else {
          Song songToPlay = displayedSongs.first;
          if (songProvider.isShuffleEnabled) {
            songToPlay =
                displayedSongs[Random().nextInt(displayedSongs.length)];
          }
          songProvider.playSong(songToPlay, displayedSongs);
          CustomSnackBar.showInfo(
            context: context,
            message: "Liste oynatılıyor.",
            icon: CustomIcons.svgIcon(
              CustomIcons.playArrow,
              color: Colors.white,
              size: 24,
            ),
          );
        }
      }
    }

    return Stack(
      children: [
        Scaffold(
          extendBody: true,
          bottomNavigationBar: songProvider.currentSong != null
              ? Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        const Color(0xFF121212).withOpacity(
                          1,
                        ), // İçeriklerin arkadan flulaşarak görünmesi için şeffaflaştırıldı

                        const Color(0xFF121212).withOpacity(0.8),
                        const Color(0xFF121212).withOpacity(0.4),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.4, 0.8, 1.0],
                    ),
                  ),
                  child: SafeArea(
                    bottom: true,
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => PlayerPage.show(context),
                          child: const MiniPlayer(),
                        ),
                        const SizedBox(height: 2),
                      ],
                    ),
                  ),
                )
              : null,
          body: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverAppBar(
                expandedHeight: 440.0,
                pinned: true,
                stretch: true,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                scrolledUnderElevation: 0,
                title: Text(
                  _showStickyPlayButton ? widget.artistName : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                  ),
                ),
                centerTitle: true,
                leading: Center(
                  child: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const BackButtonIcon(),
                      color: Colors.white,
                      iconSize: 27,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (coverUrl.isNotEmpty)
                        Transform.scale(
                          scale: (coverUrl.contains('ytimg.com') ||
                                  coverUrl.contains('youtube.com'))
                              ? 1.35
                              : 1.0,
                          child: CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.grey.shade900, Colors.black],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (coverUrl.isNotEmpty)
                        BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                          child:
                              Container(color: Colors.black.withOpacity(0.4)),
                        ),
                      // Alt kısımdan yukarı doğru kararan (fade) degrade geçişi
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Theme.of(
                                context,
                              ).scaffoldBackgroundColor.withOpacity(0.6),
                              Theme.of(context).scaffoldBackgroundColor,
                            ],
                            stops: const [0.5, 0.85, 1.0],
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: kToolbarHeight),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              child: _showSearchBar
                                  ? Padding(
                                      padding: const EdgeInsets.only(
                                        left: 16,
                                        right: 16,
                                        bottom: 12,
                                      ),
                                      child: CustomSearchBar(
                                        controller: _searchController,
                                        hintText: widget.isCollection
                                            ? '${widget.artistName} içinde ara...'
                                            : langProvider
                                                .t('search_in_artist')
                                                .replaceAll(
                                                    '%s', widget.artistName),
                                        showClearButton: _searchText.isNotEmpty,
                                        fillColor:
                                            Colors.white.withOpacity(0.15),
                                        onClear: () {
                                          setState(() => _searchText = '');
                                          FocusScope.of(context).unfocus();
                                        },
                                        onChanged: (value) =>
                                            setState(() => _searchText = value),
                                        onSubmitted: (_) =>
                                            FocusScope.of(context).unfocus(),
                                      ),
                                    )
                                  : const SizedBox(
                                      width: double.infinity, height: 0),
                            ),
                            const Spacer(),
                            Center(
                              child: coverUrl.isNotEmpty
                                  ? AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeOutCubic,
                                      width: widget.isCollection
                                          ? (_showSearchBar
                                              ? 192
                                              : 288) // 16:9 genişlik
                                          : (_showSearchBar ? 160 : 220),
                                      height: widget.isCollection
                                          ? (_showSearchBar
                                              ? 108
                                              : 162) // 16:9 yükseklik
                                          : (_showSearchBar ? 160 : 220),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.rectangle,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.5),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Transform.scale(
                                          scale: (!widget.isCollection &&
                                                  (coverUrl.contains(
                                                          'ytimg.com') ||
                                                      coverUrl.contains(
                                                          'youtube.com')))
                                              ? 1.35
                                              : 1.0,
                                          child: CachedNetworkImage(
                                            imageUrl: coverUrl,
                                            fit: BoxFit.cover,
                                            errorWidget:
                                                (context, url, error) =>
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
                                    )
                                  : const SizedBox(),
                            ),
                            const Spacer(),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                widget.artistName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (displayedSongs.isNotEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  children: [
                                    // 1. Karışık Çal Butonu
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(30),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                            sigmaX: 10, sigmaY: 10),
                                        child: Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(30),
                                            border: Border.all(
                                              color:
                                                  Colors.white.withOpacity(0.2),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () {
                                                if (displayedSongs.isNotEmpty) {
                                                  songProvider.toggleShuffle();
                                                  CustomSnackBar.showInfo(
                                                    context: context,
                                                    message: songProvider
                                                            .isShuffleEnabled
                                                        ? "Karışık çalma açık."
                                                        : "Karışık çalma kapalı.",
                                                    icon: const Icon(
                                                      Icons.shuffle_rounded,
                                                      color: Colors.white,
                                                      size: 24,
                                                    ),
                                                  );
                                                }
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                              child: Center(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.shuffle_rounded,
                                                      color: Colors.white,
                                                      size: 24,
                                                    ),
                                                    if (songProvider
                                                        .isShuffleEnabled)
                                                      Container(
                                                        margin: const EdgeInsets
                                                            .only(
                                                          top: 2,
                                                        ),
                                                        width: 4,
                                                        height: 4,
                                                        decoration:
                                                            const BoxDecoration(
                                                          color: Colors.white,
                                                          shape:
                                                              BoxShape.circle,
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
                                    const SizedBox(width: 16),
                                    // 2. Oynat Butonu
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(30),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                            sigmaX: 10, sigmaY: 10),
                                        child: Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).primaryColor.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(30),
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
                                              onTap: handlePlayTap,
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                              child: Center(
                                                child: StreamBuilder<bool>(
                                                  stream: songProvider
                                                      .audioPlayer
                                                      .playingStream,
                                                  builder: (context, snapshot) {
                                                    final playing =
                                                        snapshot.data ?? false;
                                                    final isPlayingNow =
                                                        isAnyLoaded && playing;
                                                    return AnimatedSwitcher(
                                                      duration: const Duration(
                                                          milliseconds: 300),
                                                      child: Icon(
                                                        isPlayingNow
                                                            ? Icons
                                                                .pause_rounded
                                                            : Icons
                                                                .play_arrow_rounded,
                                                        key: ValueKey<bool>(
                                                            isPlayingNow),
                                                        color: isPlayingNow
                                                            ? Colors.greenAccent
                                                            : Colors.white,
                                                        size: 28,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (!widget.isCollection)
                                      Consumer<SongProvider>(
                                        builder: (context, provider, _) {
                                          final isFollowed =
                                              provider.isArtistFollowed(
                                            widget.artistName,
                                          );

                                          final primaryColor = Theme.of(
                                            context,
                                          ).primaryColor;
                                          Color borderColor;
                                          Color bgColor;
                                          Widget content;

                                          if (isFollowed) {
                                            borderColor =
                                                primaryColor.withOpacity(0.5);
                                            bgColor =
                                                primaryColor.withOpacity(0.1);
                                            content = Row(
                                              key: const ValueKey('followed'),
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.check_rounded,
                                                  color: primaryColor,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  langProvider.t('followed'),
                                                  style: TextStyle(
                                                    color: primaryColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            );
                                          } else {
                                            borderColor =
                                                Colors.white.withOpacity(0.2);
                                            bgColor =
                                                Colors.black.withOpacity(0.4);
                                            content = Row(
                                              key: const ValueKey('follow'),
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons
                                                      .person_add_alt_1_rounded,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  langProvider.t('follow'),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            );
                                          }

                                          return ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(30),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(
                                                sigmaX: 10,
                                                sigmaY: 10,
                                              ),
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 300,
                                                ),
                                                curve: Curves.easeInOut,
                                                decoration: BoxDecoration(
                                                  color: bgColor,
                                                  borderRadius:
                                                      BorderRadius.circular(30),
                                                  border: Border.all(
                                                    color: borderColor,
                                                    width: 1.5,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: borderColor
                                                          .withOpacity(0.2),
                                                      blurRadius: 15,
                                                      spreadRadius: 1,
                                                    ),
                                                  ],
                                                ),
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: () {
                                                      if (!provider
                                                          .isFirebaseLoggedIn) {
                                                        _showLoginBottomSheet(
                                                            context);
                                                        return;
                                                      }
                                                      provider
                                                          .toggleFollowArtist(
                                                        widget.artistName,
                                                      );
                                                      CustomSnackBar.showInfo(
                                                        context: context,
                                                        message: isFollowed
                                                            ? "${widget.artistName} takipten çıkarıldı."
                                                            : "${widget.artistName} takip ediliyor.",
                                                      );
                                                    },
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      30,
                                                    ),
                                                    child: Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 16,
                                                        vertical: 10,
                                                      ),
                                                      child: AnimatedSwitcher(
                                                        duration:
                                                            const Duration(
                                                          milliseconds: 300,
                                                        ),
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
                                    if (widget.isCollection)
                                      Consumer<SongProvider>(
                                        builder: (context, provider, _) {
                                          final existingFolderIndex =
                                              provider.folders.indexWhere(
                                            (f) => f.name == widget.artistName,
                                          );
                                          final isSaved =
                                              existingFolderIndex != -1;

                                          return ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(30),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(
                                                sigmaX: 10,
                                                sigmaY: 10,
                                              ),
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 300,
                                                ),
                                                width: 56,
                                                height: 56,
                                                decoration: BoxDecoration(
                                                  color: isSaved
                                                      ? Colors.greenAccent
                                                          .withOpacity(
                                                          0.2,
                                                        )
                                                      : Colors.white
                                                          .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(30),
                                                  border: Border.all(
                                                    color: isSaved
                                                        ? Colors.greenAccent
                                                            .withOpacity(
                                                            0.5,
                                                          )
                                                        : Colors.white
                                                            .withOpacity(0.2),
                                                    width: 1.5,
                                                  ),
                                                  boxShadow: isSaved
                                                      ? [
                                                          BoxShadow(
                                                            color: Colors
                                                                .greenAccent
                                                                .withOpacity(
                                                                    0.2),
                                                            blurRadius: 15,
                                                            spreadRadius: 1,
                                                          ),
                                                        ]
                                                      : [],
                                                ),
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: () {
                                                      if (!provider
                                                          .isFirebaseLoggedIn) {
                                                        _showLoginBottomSheet(
                                                            context);
                                                        return;
                                                      }
                                                      if (isSaved) {
                                                        final folderToDelete =
                                                            provider.folders[
                                                                existingFolderIndex];
                                                        provider.deleteFolder(
                                                          folderToDelete,
                                                        );
                                                        CustomSnackBar.showInfo(
                                                          context: context,
                                                          message:
                                                              "Mix kitaplıktan çıkarıldı.",
                                                        );
                                                      } else {
                                                        provider.createFolder(
                                                          name:
                                                              widget.artistName,
                                                          songs: displayedSongs,
                                                        );
                                                        CustomSnackBar
                                                            .showSuccess(
                                                          context: context,
                                                          message:
                                                              "Mix kitaplığınıza eklendi.",
                                                        );
                                                      }
                                                    },
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      30,
                                                    ),
                                                    child: Center(
                                                      child: AnimatedSwitcher(
                                                        duration:
                                                            const Duration(
                                                          milliseconds: 300,
                                                        ),
                                                        transitionBuilder:
                                                            (child, animation) =>
                                                                ScaleTransition(
                                                          scale: animation,
                                                          child: child,
                                                        ),
                                                        child: Icon(
                                                          isSaved
                                                              ? Icons
                                                                  .check_rounded
                                                              : Icons
                                                                  .add_rounded,
                                                          key: ValueKey<bool>(
                                                              isSaved),
                                                          color: isSaved
                                                              ? Colors
                                                                  .greenAccent
                                                              : Colors.white,
                                                          size: 28,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),
                          ],
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
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.025,
                    ),
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
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: songProvider.currentSong != null ? 160 : 40,
                ),
              ),
            ],
          ),
        ),
        if (displayedSongs.isNotEmpty)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            top: _showStickyPlayButton
                ? MediaQuery.of(context).padding.top + kToolbarHeight - 24
                : MediaQuery.of(context).padding.top + kToolbarHeight + 30,
            right: MediaQuery.of(context).size.width * 0.05,
            child: IgnorePointer(
              ignoring: !_showStickyPlayButton,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showStickyPlayButton ? 1.0 : 0.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.8),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: handlePlayTap,
                          borderRadius: BorderRadius.circular(28),
                          child: Center(
                            child: StreamBuilder<bool>(
                              stream: songProvider.audioPlayer.playingStream,
                              builder: (context, snapshot) {
                                final playing = snapshot.data ?? false;
                                final isPlayingNow = isAnyLoaded && playing;
                                return AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Icon(
                                    isPlayingNow
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    key: ValueKey<bool>(isPlayingNow),
                                    color: isPlayingNow
                                        ? Colors.greenAccent
                                        : Colors.white,
                                    size: 28,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
        ],
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
      primaryButtonText: langProvider.t(
        'login_to_continue',
      ), // Veya "Giriş Yap"
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
