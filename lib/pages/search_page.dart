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
import 'package:muzik_app/pages/artist_detail_page.dart';
import 'package:muzik_app/widgets/song_grid_card.dart';
import 'package:muzik_app/providers/language_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';
import 'package:muzik_app/pages/login_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:muzik_app/widgets/custom_search_bar.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isHistoryExpanded = false; // Geçmişin açık/kapalı durumu

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
              message: "${context.read<LanguageProvider>().t('error')}: $e",
            );
          }
        });
      }
    });

    // Sayfa açıldığında önerilen şarkıları yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SongProvider>().fetchSuggestedSongs();
    });

    _initSpeech();
  }

  /// Mikrofon eklentisini başlatır
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  /// Dinlemeyi başlatır
  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {
      _isListening = true;
    });
  }

  /// Dinlemeyi durdurur
  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  /// Sesten metne çeviri yapıldıkça tetiklenir
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _searchController.text = result.recognizedWords;
      context.read<SongProvider>().updateSearchText(result.recognizedWords);
      if (result.finalResult) {
        _isListening = false;
        context.read<SongProvider>().addToSearchHistory(result.recognizedWords);
      }
    });
  }

  /// Akıllı Söz Arama Penceresini (Sözler aklında mı?) açar
  void _openLyricsSearch(BuildContext context) async {
    if (_isListening) {
      _stopListening();
    }

    final result = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'LyricsSearchDialog',
      barrierColor: Colors
          .transparent, // Arka plan karartmasını içeride BackdropFilter ile yapacağız
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: const _LyricsSearchDialog(),
        );
      },
    );

    if (result != null && result.trim().isNotEmpty && mounted) {
      _searchController.text = result.trim();
      context.read<SongProvider>().updateSearchText(result.trim());
      context.read<SongProvider>().addToSearchHistory(result.trim());
    }
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
    final langProvider = context.watch<LanguageProvider>();
    final arananSarkilar = songProvider.searchedSongs;
    final aramaMetni = _searchController.text;
    final selectedTab = songProvider.searchFilter;
    final tabKeys = ['songs', 'artists', 'collections'];

    return Scaffold(
      appBar: CustomAppBar(
        title: langProvider.t('search'),
        showLeading: false,
        wrapActionsInBox:
            false, // Otomatik kare kutu içine almayı devre dışı bırakır
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: TextButton(
                onPressed: () => _openLyricsSearch(context),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.05),
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.15),
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal:
                        8, // İkon eklendiği için kenar boşluklarını biraz kıstık
                    vertical: 0,
                  ),
                  minimumSize: const Size(
                    0,
                    32,
                  ), // Dikeyde minimum yüksekliği sabitledik
                  tapTargetSize: MaterialTapTargetSize
                      .shrinkWrap, // Gereksiz boşlukları kırpar
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(
                              0.2,
                            ), // İkon arkası saydam renk
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.graphic_eq_rounded,
                        color: Theme.of(context).primaryColor,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      langProvider.t('lyrics_in_mind'),
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.only(
          left: MediaQuery.of(context).size.width * 0.025,
          right: MediaQuery.of(context).size.width * 0.025,
          top: 16.0,
        ),
        child: Column(
          children: [
            // Arama Kutusu
            ClipRRect(
              borderRadius: BorderRadius.circular(CustomSearchBar.cornerRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  color: Colors.white,
                  child: CustomSearchBar(
                    controller: _searchController,
                    textStyle: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    hintStyle: const TextStyle(color: Colors.black),
                    hintText: langProvider.t('what_to_listen'),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: CustomIcons.svgIcon(
                        CustomIcons.search,
                        color: Colors.black.withOpacity(0.8),
                        size: 28,
                      ),
                    ),
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    showClearButton: aramaMetni.isNotEmpty,
                    onClear: () {
                      songProvider.updateSearchText('');
                      if (_isListening) _stopListening();
                    },
                    extraSuffix: _speechEnabled
                        ? _PulsingMic(
                            isListening: _isListening,
                            onTap:
                                _isListening ? _stopListening : _startListening,
                            color: Theme.of(context).primaryColor,
                          )
                        : null,
                    onChanged: (value) {
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

            // Tab (Segmented Control) Alanı - Sadece arama yapıldığında kayarak gösterilir
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: aramaMetni.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: ClipRRect(
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
                              children: tabKeys.map((tabKey) {
                                final isSelected = selectedTab == tabKey;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      songProvider.setSearchFilter(tabKey);
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
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
                                        langProvider.t(tabKey),
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
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
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
            const SizedBox(height: 16),

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
    final langProvider = context.watch<LanguageProvider>();
    final double bottomPadding = songProvider.currentSong != null ? 160 : 100;
    final selectedTab = songProvider.searchFilter;

    List<Song> suggestionsToDisplay = [];
    String suggestionTitle = '';
    if (selectedTab == 'artists') {
      suggestionsToDisplay = songProvider.suggestedArtists;
      suggestionTitle = langProvider.t('popular_artists_month');
    } else if (selectedTab == 'collections') {
      suggestionsToDisplay = songProvider.suggestedAlbums;
      suggestionTitle = langProvider.t('popular_mixes_month');
    } else {
      suggestionsToDisplay = songProvider.suggestedSongs;
      suggestionTitle = langProvider.t('recommended_for_you');
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
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.025,
                vertical: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    langProvider.t('recent_searches'),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => songProvider.clearSearchHistory(),
                    child: Text(
                      langProvider.t('clear'),
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),
            Builder(
              builder: (context) {
                final history = songProvider.searchHistory;
                // Kutucuklar yatayda daha az yer kapladığı için limiti 3'ten 5'e çıkardık
                final showAll = _isHistoryExpanded || history.length <= 5;
                final itemsToShow =
                    showAll ? history : history.take(5).toList();
                final remainingCount = history.length - 5;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width * 0.025,
                      ),
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 10.0,
                        children: itemsToShow.map((historyItem) {
                          return GestureDetector(
                            onTap: () {
                              _searchController.text = historyItem;
                              _searchController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(offset: historyItem.length),
                              );
                              songProvider.updateSearchText(historyItem);
                              songProvider.addToSearchHistory(historyItem);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade900,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    historyItem,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => songProvider
                                        .removeFromSearchHistory(historyItem),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    // +X Daha Fazla Göster Butonu
                    if (!showAll && remainingCount > 0)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isHistoryExpanded = true;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Center(
                            child: Text(
                              "+$remainingCount ${langProvider.t('see_more')}",
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Kapatma (Yukarı Ok) Butonu
                    if (showAll && history.length > 5)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isHistoryExpanded = false;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Center(
                            child: Icon(
                              Icons.keyboard_arrow_up_rounded,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
          ],

          // 2. Önerilen Şarkılar Bölümü
          if (songProvider.isSuggestionsLoading)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (suggestionsToDisplay.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  MediaQuery.of(context).size.width * 0.025,
                  16,
                  MediaQuery.of(context).size.width * 0.025,
                  8,
                ),
                child: Text(
                  suggestionTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            if (selectedTab == 'collections' && suggestionsToDisplay.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.025,
                ),
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
                  itemBuilder: (context, index) => _buildAlbumGridCard(
                    context,
                    suggestionsToDisplay[index],
                    suggestionsToDisplay,
                  ),
                ),
              )
            else if (selectedTab == 'artists' &&
                suggestionsToDisplay.isNotEmpty)
              ...suggestionsToDisplay.map(
                (song) => _buildArtistTile(context, song),
              )
            else if (selectedTab == 'songs' || selectedTab == 'all') ...[
              // SİZİN İÇİN ÖNERİLENLER (KOMPOZİT GÖRÜNÜM)
              // 1. Önerilen Şarkılar (Üstte 4 adet SongCard)
              if (suggestionsToDisplay.isNotEmpty)
                ...suggestionsToDisplay.take(4).map((song) {
                  final isCurrent = songProvider.currentSong?.id == song.id;
                  return SongCard(
                    song: song,
                    isPlaying: isCurrent,
                    showOptions: true,
                    onTap: () {
                      if (isCurrent) {
                        if (songProvider.audioPlayer.playing) {
                          songProvider.audioPlayer.pause();
                        } else {
                          songProvider.audioPlayer.play();
                        }
                      } else {
                        songProvider.playSong(song, suggestionsToDisplay);
                      }
                    },
                  );
                }),

              // 2. Önerilen Sanatçılar (Büyük Küreler)
              if (songProvider.suggestedArtists.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    MediaQuery.of(context).size.width * 0.025,
                    24,
                    MediaQuery.of(context).size.width * 0.025,
                    12,
                  ),
                  child: Text(
                    langProvider.t('popular_artists'),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.025,
                    ),
                    itemCount: songProvider.suggestedArtists.length,
                    itemBuilder: (context, index) {
                      final artistSong = songProvider.suggestedArtists[index];
                      return _buildLargeArtistAvatar(
                        context,
                        artistSong,
                        songProvider,
                      );
                    },
                  ),
                ),
              ],
            ],
          ],
          const SizedBox(height: 16),
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
          selectedTab == 'collections'
              ? SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.025,
                    vertical: 8.0,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.15,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildAlbumGridCard(
                        context,
                        sonuclar[index],
                        sonuclar,
                      ),
                      childCount: sonuclar.length,
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final song = sonuclar[index];
                    if (selectedTab == 'artists') {
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
                          songProvider.playSongWithSmartQueue(song);
                        } else {
                          if (songProvider.audioPlayer.playing) {
                            songProvider.audioPlayer.pause();
                          } else {
                            songProvider.audioPlayer.play();
                          }
                        }
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
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
        ],
      );
    }
  }

  Widget _buildArtistTile(BuildContext context, Song song) {
    final langProvider = context.watch<LanguageProvider>();
    final songProvider = context.watch<SongProvider>();
    final isFollowed = songProvider.isArtistFollowed(song.artist);
    final primaryColor = Theme.of(context).primaryColor;

    String coverUrl = song.coverUrl;
    final artistAvatar = songProvider.getArtistAvatar(song.artist);
    if (artistAvatar != null && artistAvatar.isNotEmpty) {
      coverUrl = artistAvatar;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SongProvider>().fetchArtistAvatar(song.artist);
      });
    }

    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.025,
        vertical: 8,
      ),
      leading: coverUrl.isEmpty
          ? const CustomShimmer(width: 56, height: 56, borderRadius: 28)
          : ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: CachedNetworkImage(
                imageUrl: coverUrl,
                memCacheHeight: 200,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  width: 56,
                  height: 56,
                  color: Colors.grey.shade800,
                  child: const Icon(Icons.person, color: Colors.white54),
                ),
              ),
            ),
      title: coverUrl.isEmpty
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
        child: coverUrl.isEmpty
            ? const CustomShimmer(width: 60, height: 12, borderRadius: 4)
            : Text(
                langProvider.t('artist'),
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
      ),
      onTap: coverUrl.isEmpty
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ArtistDetailPage(artistName: song.artist, songs: [song]),
                ),
              );
            },
      trailing: coverUrl.isEmpty
          ? null
          : GestureDetector(
              onTap: () {
                if (!songProvider.isFirebaseLoggedIn) {
                  _showLoginBottomSheet(context);
                  return;
                }
                songProvider.toggleFollowArtist(song.artist);
                CustomSnackBar.showInfo(
                  context: context,
                  message: isFollowed
                      ? "${song.artist} takipten çıkarıldı."
                      : "${song.artist} takip ediliyor.",
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isFollowed
                      ? primaryColor.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isFollowed
                        ? primaryColor.withOpacity(0.5)
                        : Colors.white.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isFollowed
                          ? Icons.check_rounded
                          : Icons.person_add_alt_1_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isFollowed
                          ? langProvider.t('followed')
                          : langProvider.t('follow'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAlbumGridCard(
    BuildContext context,
    Song song,
    List<Song> playlist,
  ) {
    if (song.coverUrl.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtistDetailPage(
              artistName: song.title, // Koleksiyon Adı
              songs: [song], // Listedeki ilk şarkı (Mix'in kendisi)
              isCollection: true,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLargeArtistAvatar(
    BuildContext context,
    Song song,
    SongProvider songProvider,
  ) {
    String coverUrl = song.coverUrl;
    final artistAvatar = songProvider.getArtistAvatar(song.artist);
    if (artistAvatar != null && artistAvatar.isNotEmpty) {
      coverUrl = artistAvatar;
    } else if (coverUrl.isEmpty) {
      coverUrl =
          'https://ui-avatars.com/api/?name=${Uri.encodeComponent(song.artist)}&background=random&color=fff&size=200';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtistDetailPage(
              artistName: song.artist,
              songs: const [], // Sanatçı detayı sayfasında zaten API'den güncel şarkılar çekilecek
            ),
          ),
        );
      },
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  memCacheHeight: 300,
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade800,
                    child: const Icon(
                      Icons.person,
                      color: Colors.white54,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String query) {
    final langProvider = context.watch<LanguageProvider>();
    final songProvider = context.watch<SongProvider>();
    final double bottomPadding = songProvider.currentSong != null ? 160 : 100;

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
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
                  langProvider
                      .t('search_no_results_query')
                      .replaceAll('%s', query),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                ),
              ),
              const Spacer(),
              SizedBox(height: bottomPadding),
            ],
          ),
        ),
      ],
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

// --- SÖZLER AKLINDA MI? (LYRICS SEARCH) DİYALOGU ---
class _LyricsSearchDialog extends StatefulWidget {
  const _LyricsSearchDialog();

  @override
  State<_LyricsSearchDialog> createState() => _LyricsSearchDialogState();
}

class _LyricsSearchDialogState extends State<_LyricsSearchDialog>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;
  bool _speechEnabled = false;
  String _words = '';
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _initSpeech();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted && _isListening) {
            setState(() => _isListening = false);
            _pulseController.stop();
            if (_words.isNotEmpty) {
              Navigator.pop(context, _words);
            }
          }
        }
      },
      onError: (errorNotification) {
        if (mounted) {
          setState(() => _isListening = false);
          _pulseController.stop();
        }
      },
    );
    if (mounted) setState(() {});
  }

  void _startListening() async {
    if (!_speechEnabled) return;
    setState(() {
      _words = '';
      _isListening = true;
    });
    _pulseController.repeat();
    await _speechToText.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _words = result.recognizedWords;
          });
          if (result.finalResult) {
            setState(() => _isListening = false);
            _pulseController.stop();
            Navigator.pop(context, _words);
          }
        }
      },
      pauseFor: const Duration(
        seconds: 4,
      ), // 4 saniye susulursa dinlemeyi bitirir
    );
  }

  void _stopListening() async {
    await _speechToText.stop();
    if (mounted) {
      setState(() => _isListening = false);
      _pulseController.stop();
      if (_words.isNotEmpty) {
        Navigator.pop(context, _words);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speechToText.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = context.read<LanguageProvider>();
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Arka Plan Bulanıklığı
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          ),
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade900.withOpacity(0.85),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Kapatma Tuşu
                  Align(
                    alignment: Alignment.topRight,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(Icons.mic_external_on, size: 60, color: primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    langProvider.t('remember_song'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isListening
                        ? langProvider.t('listening_to_you')
                        : langProvider.t('hum_lyrics_melody'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                  ),
                  const SizedBox(height: 32),

                  // Dinamik Metin (Kullanıcının Söyledikleri)
                  if (_words.isNotEmpty) ...[
                    Text(
                      '"$_words"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Başlat Butonu
                  GestureDetector(
                    onTap: _isListening ? _stopListening : _startListening,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_isListening)
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: 1.0 + (_pulseController.value * 0.4),
                                child: Opacity(
                                  opacity: 1.0 - _pulseController.value,
                                  child: Container(
                                    width: 84,
                                    height: 84,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: primaryColor.withOpacity(0.6),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isListening
                                ? primaryColor
                                : Colors.grey.shade800,
                            border: Border.all(
                              color: _isListening
                                  ? primaryColor
                                  : Colors.white.withOpacity(0.2),
                              width: 2,
                            ),
                            boxShadow: _isListening
                                ? [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.4),
                                      blurRadius: 20,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isListening
                                    ? Icons.graphic_eq_rounded
                                    : Icons.mic_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                              if (!_isListening) ...[
                                const SizedBox(height: 4),
                                Text(
                                  langProvider.t('start_listening'),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- MODERN MİKROFON ANİMASYONU ---
class _PulsingMic extends StatefulWidget {
  final bool isListening;
  final VoidCallback onTap;
  final Color color;

  const _PulsingMic({
    required this.isListening,
    required this.onTap,
    required this.color,
  });

  @override
  State<_PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<_PulsingMic>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isListening) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _PulsingMic oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !oldWidget.isListening) {
      _controller.repeat();
    } else if (!widget.isListening && oldWidget.isListening) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.isListening)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale:
                        1.0 + (_controller.value * 0.8), // 1.0'dan 1.8'e büyür
                    child: Opacity(
                      opacity: 1.0 - _controller.value, // Dışa doğru soluklaşır
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.color.withOpacity(0.8),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
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
