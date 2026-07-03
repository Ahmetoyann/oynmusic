import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/pages/player_page.dart';
import 'package:muzik_app/widgets/mini_player.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/widgets/song_card.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';
import 'package:muzik_app/widgets/custom_app_bar.dart';
import 'package:muzik_app/providers/language_provider.dart';
import 'package:muzik_app/widgets/custom_banner_ad.dart';
import 'package:muzik_app/widgets/custom_search_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:muzik_app/widgets/device_cover_placeholder.dart';
import 'package:muzik_app/pages/artist_detail_page.dart';

class RecentlyPlayedPage extends StatefulWidget {
  const RecentlyPlayedPage({super.key});

  @override
  State<RecentlyPlayedPage> createState() => _RecentlyPlayedPageState();
}

class _RecentlyPlayedPageState extends State<RecentlyPlayedPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  String _selectedFilterKey = 'all'; // Anahtar olarak saklayacağız

  // Filtreler için anahtar listesi
  final List<String> _filterKeys = [
    'all',
    'songs',
    'collections',
    'discoveries'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showClearHistoryDialog(BuildContext context) {
    final langProvider = context.read<LanguageProvider>();

    CustomBottomSheet.show(
      context: context,
      title: langProvider.t('clear_history'),
      message: langProvider.t('clear_history_desc'),
      primaryButtonText: langProvider.t('clear'),
      primaryButtonColor: Colors.redAccent,
      secondaryButtonText: langProvider.t('cancel'),
      onPrimaryButtonTap: () {
        context.read<SongProvider>().clearRecentlyPlayed();
        Navigator.pop(context);
        CustomSnackBar.showError(
          context: context,
          message: langProvider.t('history_cleared'),
        );
      },
    );
  }

  String _getDateHeader(BuildContext context, DateTime? date) {
    final langProvider = context.read<LanguageProvider>();
    if (date == null) return langProvider.t('older');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck.isAtSameMomentAs(today)) {
      return langProvider.t('today');
    } else if (dateToCheck.isAtSameMomentAs(yesterday)) {
      return langProvider.t('yesterday');
    } else {
      return langProvider.t('older');
    }
  }

  String _getExactTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0 && now.day == date.day) {
      // Bugün ise saat:dakika
      return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } else if (diff.inDays < 7) {
      // Son 1 hafta içindeyse gün sayısı
      final langProvider = context.read<LanguageProvider>();
      return langProvider
          .t('days_ago')
          .replaceAll('%d', diff.inDays.toString());
    } else {
      // Daha eskiyse tarih
      return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}";
    }
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = context.watch<SongProvider>();
    final langProvider = context.watch<LanguageProvider>();
    final allSongs = songProvider.recentlyPlayed;

    // Arama filtresi
    final displayedSongs = allSongs.where((song) {
      final query = _searchText.toLowerCase();
      final matchesSearch = song.title.toLowerCase().contains(query) ||
          song.artist.toLowerCase().contains(query);

      bool matchesFilter = true;
      if (_selectedFilterKey == 'songs') {
        matchesFilter = !song.title.toLowerCase().contains('mix') &&
            !song.title.toLowerCase().contains('albüm');
      } else if (_selectedFilterKey == 'collections') {
        matchesFilter = song.title.toLowerCase().contains('mix') ||
            song.title.toLowerCase().contains('albüm') ||
            song.title.toLowerCase().contains('set');
      } else if (_selectedFilterKey == 'discoveries') {
        // Basit bir keşif mantığı: Play count 1 ise (veya son 24 saatte eklendiyse)
        final count = songProvider.getSongListeningSeconds(song.id);
        matchesFilter =
            count < 120; // 2 dakikadan az dinlenenler yeni keşif sayılır
      }

      return matchesSearch && matchesFilter;
    }).toList();

    // En Sık Dinlenen Sanatçıları Hesapla
    final Map<String, int> artistPlayCounts = {};
    for (var song in allSongs) {
      artistPlayCounts[song.artist] = (artistPlayCounts[song.artist] ?? 0) + 1;
    }
    final topArtists = artistPlayCounts.keys.toList()
      ..sort((a, b) => artistPlayCounts[b]!.compareTo(artistPlayCounts[a]!));

    // Düzleştirilmiş (Flattened) Zaman Tüneli Listesi
    final List<dynamic> timelineItems = [];
    String? currentHeader;

    for (var song in displayedSongs) {
      final header = _getDateHeader(context, song.lastPlayed);
      if (header != currentHeader) {
        timelineItems.add(header); // Başlık (String)
        currentHeader = header;
      }
      timelineItems.add(song); // Şarkı Verisi (Song)
    }

    return Scaffold(
      backgroundColor:
          const Color(0xFF0F0F0F), // Çok hafif farklı modern bir siyah
      extendBody: true,
      appBar: CustomAppBar(title: langProvider.t('recently_played')),
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
      body: allSongs.isEmpty
          ? _buildEmptyState(context, true)
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // --- Arama Çubuğu ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: CustomSearchBar(
                      controller: _searchController,
                      hintText: langProvider.t('search_in_history'),
                      showClearButton: _searchText.isNotEmpty,
                      onClear: () {
                        setState(() => _searchText = '');
                      },
                      onChanged: (value) => setState(() => _searchText = value),
                    ),
                  ),
                ),

                // --- Akıllı Filtre Çipleri ---
                SliverToBoxAdapter(
                  child: _buildFilterChips(context),
                ),

                // --- En Sık Dinlediğin Sanatçılar (Yatay Scroll) ---
                if (_searchText.isEmpty &&
                    topArtists.isNotEmpty &&
                    _selectedFilterKey == 'all')
                  SliverToBoxAdapter(
                    child: _buildTopArtists(context, topArtists, songProvider),
                  ),

                // --- Bu Saatte En Çok Dinlediğin Akıllı Kart ---
                if (_searchText.isEmpty &&
                    allSongs.length > 5 &&
                    _selectedFilterKey == 'all')
                  SliverToBoxAdapter(
                    child: _buildSmartReminder(context, allSongs, songProvider),
                  ),

                // --- Zaman Tüneli Mimarisi (Flattened Lazy List) ---
                if (displayedSongs.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(context, false),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 24,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = timelineItems[index];

                          if (item is String) {
                            // Sticky Header Görünümü
                            return Padding(
                              padding:
                                  const EdgeInsets.only(top: 24, bottom: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Theme.of(context)
                                                .primaryColor
                                                .withOpacity(0.5),
                                            blurRadius: 8,
                                          )
                                        ]),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    item,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final song = item as Song;
                          final isCurrentSong =
                              songProvider.currentSong?.id == song.id;

                          // Oval ve Modern Swipe Destekli Şarkı Kartı
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: _buildSwipeableModernSongCard(context, song,
                                isCurrentSong, songProvider, displayedSongs),
                          );
                        },
                        childCount: timelineItems.length,
                      ),
                    ),
                  ),

                // --- Geçmişi Temizle Butonu (Sayfa Sonu) ---
                if (displayedSongs.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: songProvider.currentSong != null ? 160 : 40,
                        top: 16,
                      ),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () => _showClearHistoryDialog(context),
                          icon: CustomIcons.svgIcon(CustomIcons.delete,
                              size: 18, color: Colors.redAccent),
                          label: Text(langProvider.t('clear_history')),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  // --- YENİ EKLENEN MODERN VİDGET METOTLARI ---

  Widget _buildFilterChips(BuildContext context) {
    final langProvider = context.watch<LanguageProvider>();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _filterKeys.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filterKey = _filterKeys[index];
          final isSelected = _selectedFilterKey == filterKey;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilterKey = filterKey),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
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
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).primaryColor.withOpacity(0.5)
                          : Colors.white.withOpacity(0.1),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    langProvider.t(filterKey),
                    style: TextStyle(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.white70,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopArtists(
      BuildContext context, List<String> topArtists, SongProvider provider) {
    final langProvider = context.read<LanguageProvider>();
    final primaryColor = Theme.of(context).primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            langProvider.t('most_played_artists'),
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: topArtists.length > 10 ? 10 : topArtists.length,
            itemBuilder: (context, index) {
              final artist = topArtists[index];
              final isTop =
                  index == 0; // En çok dinlenen sanatçıya parlayan halka

              return _TopArtistTile(
                artistName: artist,
                songProvider: provider,
                isTop: isTop,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSmartReminder(
      BuildContext context, List<Song> allSongs, SongProvider provider) {
    final langProvider = context.watch<LanguageProvider>();
    final primaryColor = Theme.of(context).primaryColor;
    // Saate uygun rastgele bir favori seçimi
    final random = Random();
    final reminderSong = allSongs[random.nextInt(min(5, allSongs.length))];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.access_time_filled_rounded,
                  color: primaryColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    langProvider.t('smart_reminder_title'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reminderSong.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.play_circle_fill_rounded,
                  color: primaryColor, size: 36),
              onPressed: () {
                provider.playSong(reminderSong, allSongs);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeableModernSongCard(BuildContext context, Song song,
      bool isCurrentSong, SongProvider provider, List<Song> playlist) {
    final primaryColor = Theme.of(context).primaryColor;
    final timeStr = _getExactTime(song.lastPlayed);

    return Dismissible(
        key: ValueKey('${song.id}_${song.lastPlayed?.millisecondsSinceEpoch}'),
        direction: DismissDirection.horizontal,
        // Sağa Kaydırma: Favoriye Ekle/Çıkar
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          decoration: BoxDecoration(
            color: Colors.green.shade700,
            borderRadius: BorderRadius.circular(20),
          ),
          child:
              const Icon(Icons.favorite_rounded, color: Colors.white, size: 32),
        ),
        // Sola Kaydırma: Kuyruğa Ekle
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: Colors.blueAccent.shade700,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.queue_music_rounded,
              color: Colors.white, size: 32),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            provider.toggleFavorite(song);
            return false; // Listede kalmaya devam etsin
          } else if (direction == DismissDirection.endToStart) {
            provider.addSongToNext(song);
            return false; // Listede kalmaya devam etsin
          }
          return false;
        },
        child: GestureDetector(
          onTap: () {
            if (!isCurrentSong) {
              provider.playSong(song, playlist);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCurrentSong
                  ? primaryColor.withOpacity(0.15)
                  : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20), // Oval hatlı albüm kartı
              border: Border.all(
                color: isCurrentSong
                    ? primaryColor.withOpacity(0.5)
                    : Colors.white.withOpacity(0.05),
              ),
            ),
            child: Row(children: [
              // Oval Albüm Kapağı
              SizedBox(
                width: 71,
                height: 40,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: song.coverUrl.isEmpty
                      ? DeviceCoverPlaceholder(
                          logoColor: Theme.of(context).primaryColor,
                          borderRadius: 4,
                        )
                      : CachedNetworkImage(
                          imageUrl: song.coverUrl,
                          fit: BoxFit.cover,
                          errorWidget: (c, u, e) => DeviceCoverPlaceholder(
                            logoColor: Theme.of(context).primaryColor,
                            borderRadius: 4,
                          ),
                        ),
                ),
              ),

              const SizedBox(width: 16),
              // Şarkı Adı ve Sanatçı
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCurrentSong ? primaryColor : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Net Dinlenme Saati/Günü
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  timeStr,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ]),
          ),
        ));
  }
}

Widget _buildEmptyState(BuildContext context, bool isEmptyHistory) {
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
            isEmptyHistory ? CustomIcons.history : CustomIcons.searchOff,
            size: 64,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          isEmptyHistory
              ? langProvider.t('no_history')
              : langProvider.t('no_results'),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            isEmptyHistory
                ? langProvider.t('no_history_desc')
                : langProvider.t('try_different_search'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          ),
        ),
      ],
    ),
  );
}

/// Takip edilen sanatçıyı dinamik resmiyle yükleyen özel liste elemanı
class _TopArtistTile extends StatefulWidget {
  final String artistName;
  final SongProvider songProvider;
  final bool isTop;

  const _TopArtistTile({
    required this.artistName,
    required this.songProvider,
    required this.isTop,
  });

  @override
  State<_TopArtistTile> createState() => _TopArtistTileState();
}

class _TopArtistTileState extends State<_TopArtistTile> {
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

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final artistAvatar = widget.songProvider.getArtistAvatar(widget.artistName);

    // Eğer henüz çekilemediyse fallback olarak şarkı kapağını al
    String imageUrl = artistAvatar ?? '';
    if (imageUrl.isEmpty) {
      try {
        final fallbackSong = widget.songProvider.recentlyPlayed
            .firstWhere((s) => s.artist == widget.artistName);
        imageUrl = fallbackSong.coverUrl;
      } catch (e) {
        imageUrl =
            'https://ui-avatars.com/api/?name=${Uri.encodeComponent(widget.artistName)}&background=random&color=fff&size=100';
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtistDetailPage(
              artistName: widget.artistName,
              songs: const [],
            ),
          ),
        );
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: widget.isTop
                    ? [
                        BoxShadow(
                            color: primaryColor.withOpacity(0.0),
                            blurRadius: 15,
                            spreadRadius: 2)
                      ]
                    : null,
                border: widget.isTop
                    ? Border.all(color: primaryColor, width: 2)
                    : null,
              ),
              child: ClipOval(
                child: Container(
                  width: 64,
                  height: 64,
                  color: Colors.grey.shade800,
                  child: _isLoading && artistAvatar == null
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white54,
                            ),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => const Icon(
                            Icons.person,
                            color: Colors.white54,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.artistName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.isTop ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: widget.isTop ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
