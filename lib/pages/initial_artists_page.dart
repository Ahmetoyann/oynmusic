import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/services/audius_service.dart';
import 'package:muzik_app/custom_icons.dart';

class InitialArtistsPage extends StatefulWidget {
  final VoidCallback onCompleted;

  const InitialArtistsPage({super.key, required this.onCompleted});

  @override
  State<InitialArtistsPage> createState() => _InitialArtistsPageState();
}

class _InitialArtistsPageState extends State<InitialArtistsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  List<Song> _searchResults = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Sayfa açıldığında önerilen 10 sanatçıyı ve resimlerini çek
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SongProvider>().fetchSuggestedSongs();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    setState(() {
      _searchQuery = query;
    });

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isSearching = true);
      try {
        // Sanatçıları daha iyi bulmak için sorguya "sanatçı" kelimesini ekliyoruz
        final results = await YoutubeService.searchSongs(
          '${query.trim()} sanatçı',
          limit: 15,
        );

        // Aynı sanatçının birden fazla şarkısı gelmemesi için benzersiz sanatçıları filtreliyoruz
        final Map<String, Song> uniqueArtists = {};
        for (var song in results) {
          if (!uniqueArtists.containsKey(song.artist)) {
            uniqueArtists[song.artist] = song;
          }
        }
        if (mounted) {
          setState(() => _searchResults = uniqueArtists.values.toList());
        }
      } catch (e) {
        debugPrint("Sanatçı arama hatası: $e");
      } finally {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  Future<void> _finishSelection() async {
    final provider = context.read<SongProvider>();
    // Seçilen sanatçıları Firestore'a kaydet
    await provider.saveFollowedArtistsToFirestore();
    await provider.markInitialArtistsSeen();

    // Ana sayfaya geçmeden önce, trendleri seçilen sanatçılara göre yenilemek için tetikle
    // forceRefresh: true ile eski listeyi temizleyip yükleme ekranının görünmesini sağlıyoruz.
    provider.fetchSongsFromApi(forceRefresh: true);

    widget.onCompleted(); // Seçim bitti, AuthWrapper'ı tetikle
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SongProvider>();
    final artists = provider.suggestedArtists;
    final followedCount = provider.followedArtists.length;
    final canContinue = followedCount >= 3;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    // Eğer arama yapılıyorsa arama sonuçlarını, yapılmıyorsa önerileri göster
    final displayArtists = _searchQuery.isEmpty ? artists : _searchResults;
    final showLoading = _searchQuery.isEmpty
        ? (provider.isSuggestionsLoading && artists.isEmpty)
        : _isSearching;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          // Modern Arka Plan Parlaması (Glow Effect)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).primaryColor.withOpacity(0.2),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    "Kimi Dinlemeyi\nSeversin?",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    "Sana özel müzikler önerebilmemiz için en az 3 sanatçı seç. ($followedCount/3)",
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade400),
                  ),
                ),
                const SizedBox(height: 16),
                // Arama Çubuğu
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        color: Colors.grey.shade800.withOpacity(0.5),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Sanatçı ara...',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: CustomIcons.svgIcon(
                                CustomIcons.search,
                                color: Colors.grey.shade400,
                                size: 24,
                              ),
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: CustomIcons.svgIcon(
                                      CustomIcons.clear,
                                      size: 24,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 15,
                            ),
                          ),
                          onChanged: _onSearchChanged,
                        ),
                      ),
                    ),
                  ),
                ),
                // YENİ: Seçilen Sanatçılar Yatay Listesi
                if (provider.followedArtists.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 36,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: provider.followedArtists.length,
                      itemBuilder: (context, index) {
                        final artistName = provider.followedArtists[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: InkWell(
                            onTap: () => provider.toggleFollowArtist(
                              artistName,
                              syncToFirestore: false,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.5),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    artistName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Expanded(
                  child: showLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: Theme.of(context).primaryColor,
                          ),
                        )
                      : displayArtists.isEmpty && _searchQuery.isNotEmpty
                      ? const Center(
                          child: Text(
                            "Sonuç bulunamadı",
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            24,
                            8,
                            24,
                            120,
                          ), // Alt buton için kaydırma boşluğu
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 1.0, // Tam kare boyut
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          itemCount: displayArtists.length,
                          itemBuilder: (context, index) {
                            final artist = displayArtists[index];
                            final isSelected = provider.isArtistFollowed(
                              artist.artist,
                            );
                            // Seçiliyse listedeki sırasını bul (0'dan başladığı için +1 ekliyoruz)
                            final selectionIndex = isSelected
                                ? provider.followedArtists.indexOf(
                                        artist.artist,
                                      ) +
                                      1
                                : 0;

                            return GestureDetector(
                              onTap: () {
                                provider.toggleFollowArtist(
                                  artist.artist,
                                  syncToFirestore: false,
                                );
                                // Klavye açıksa kapat
                                FocusScope.of(context).unfocus();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(context).primaryColor
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: Theme.of(
                                              context,
                                            ).primaryColor.withOpacity(0.3),
                                            blurRadius: 15,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : [],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(17),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // Kapak Resmi
                                      artist.coverUrl.isNotEmpty
                                          ? Transform.scale(
                                              scale:
                                                  (artist.coverUrl.contains(
                                                        'ytimg.com',
                                                      ) ||
                                                      artist.coverUrl.contains(
                                                        'youtube.com',
                                                      ))
                                                  ? 1.35
                                                  : 1.0,
                                              child: Image.network(
                                                artist.coverUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (c, e, s) =>
                                                    Container(
                                                      color:
                                                          Colors.grey.shade800,
                                                    ),
                                              ),
                                            )
                                          : Container(
                                              color: Colors.grey.shade800,
                                            ),
                                      // Alt kısımdaki isim okunsun diye Gradient karartma
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.8),
                                            ],
                                            stops: const [0.5, 1.0],
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          color: Theme.of(
                                            context,
                                          ).primaryColor.withOpacity(0.2),
                                        ),
                                      if (isSelected)
                                        Positioned(
                                          top: 12,
                                          right: 12,
                                          child: Container(
                                            width: 26,
                                            height: 26,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).primaryColor,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                            child: Text(
                                              '$selectionIndex',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      Positioned(
                                        bottom: 12,
                                        left: 12,
                                        right: 12,
                                        child: Text(
                                          artist.artist,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          // Alt Buton Kısmı
          if (!isKeyboardOpen)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                // SafeArea'nın alt boşluğunu hesaplayarak daha uyumlu durmasını sağlar
                padding: EdgeInsets.fromLTRB(
                  24,
                  32,
                  24,
                  MediaQuery.of(context).padding.bottom + 24,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      const Color(0xFF121212),
                      const Color(0xFF121212).withOpacity(0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _finishSelection,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      child: const Text(
                        "Atla",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: canContinue ? _finishSelection : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade800,
                            disabledForegroundColor: Colors.grey.shade500,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: canContinue ? 8 : 0,
                            shadowColor: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.5),
                          ),
                          child: const Text(
                            "Devam Et",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
