import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/services/audius_service.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/providers/language_provider.dart';
import 'package:muzik_app/providers/auth_provider.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:muzik_app/widgets/custom_search_bar.dart';

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
    final langProvider = context.read<LanguageProvider>();
    final authProvider = context.read<AuthProvider>();

    // Seçilen sanatçıları Firestore'a kaydet
    await provider.saveFollowedArtistsToFirestore();
    await provider.markInitialArtistsSeen();

    // Ana sayfaya geçmeden önce, trendleri seçilen sanatçılara göre yenilemek için tetikle
    // forceRefresh: true ile eski listeyi temizleyip yükleme ekranının görünmesini sağlıyoruz.
    provider.fetchSongsFromApi(forceRefresh: true);

    if (mounted) {
      final userName = authProvider.user?.displayName ?? langProvider.t('user');
      CustomSnackBar.showSuccess(
        context: context,
        message: langProvider.t('welcome_user').replaceAll('%s', userName),
      );
    }

    widget.onCompleted(); // Seçim bitti, AuthWrapper'ı tetikle
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SongProvider>();
    final artists = provider.suggestedArtists;
    final followedCount = provider.followedArtists.length;
    final canContinue = followedCount >= 3;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final langProvider = context.watch<LanguageProvider>();

    // Eğer arama yapılıyorsa arama sonuçlarını, yapılmıyorsa önerileri göster
    final displayArtists = _searchQuery.isEmpty ? artists : _searchResults;
    final showLoading = _searchQuery.isEmpty
        ? (provider.isSuggestionsLoading && artists.isEmpty)
        : _isSearching;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      langProvider
                          .t('who_do_you_listen')
                          .replaceAll('?', '?\n'),
                      style: const TextStyle(
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
                      "${langProvider.t('select_at_least_3')} ($followedCount/3)",
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Arama Çubuğu
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(CustomSearchBar.cornerRadius),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          color: Colors.grey.shade800.withOpacity(0.5),
                          child: CustomSearchBar(
                            controller: _searchController,
                            hintText: langProvider.t('search_artist'),
                            fillColor: Colors.transparent,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 15),
                            showClearButton: _searchQuery.isNotEmpty,
                            onClear: () {
                              _onSearchChanged('');
                            },
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
                            ? Center(
                                child: Text(
                                  langProvider.t('no_results'),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
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
                                  childAspectRatio:
                                      0.8, // Altında isim yazması için dikeyde yer açtık
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                                itemCount: displayArtists.length,
                                itemBuilder: (context, index) {
                                  final artist = displayArtists[index];
                                  final isSelected = provider.isArtistFollowed(
                                    artist.artist,
                                  );

                                  return GestureDetector(
                                    onTap: () {
                                      provider.toggleFollowArtist(
                                        artist.artist,
                                        syncToFirestore: false,
                                      );
                                      // Klavye açıksa kapat
                                      FocusScope.of(context).unfocus();
                                    },
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 300),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isSelected
                                                    ? Colors.greenAccent
                                                    : Colors.transparent,
                                                width: 3,
                                              ),
                                              boxShadow: isSelected
                                                  ? [
                                                      BoxShadow(
                                                        color: Colors
                                                            .greenAccent
                                                            .withOpacity(0.3),
                                                        blurRadius: 15,
                                                        spreadRadius: 2,
                                                      ),
                                                    ]
                                                  : [],
                                            ),
                                            child: ClipOval(
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  // Kapak Resmi
                                                  artist.coverUrl.isNotEmpty
                                                      ? Image.network(
                                                          artist.coverUrl,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (c, e,
                                                                  s) =>
                                                              Container(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade800),
                                                        )
                                                      : Container(
                                                          color: Colors.white
                                                              .withOpacity(
                                                                  0.05),
                                                          child: Center(
                                                            child: SizedBox(
                                                              width: 24,
                                                              height: 24,
                                                              child:
                                                                  CircularProgressIndicator(
                                                                color: Theme.of(
                                                                        context)
                                                                    .primaryColor,
                                                                strokeWidth:
                                                                    2.5,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                  // Sadece seçildiğinde hafif kararma efekti
                                                  if (isSelected)
                                                    Container(
                                                        color: Colors.black
                                                            .withOpacity(0.4)),
                                                  if (isSelected)
                                                    Center(
                                                      child: Icon(
                                                        Icons
                                                            .check_circle_rounded,
                                                        color:
                                                            Colors.greenAccent,
                                                        size: 54,
                                                        shadows: [
                                                          Shadow(
                                                            color: Colors
                                                                .greenAccent
                                                                .withOpacity(
                                                                    0.8),
                                                            blurRadius: 20,
                                                            offset:
                                                                const Offset(
                                                                    0, 0),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          artist.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
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
                        const Color(0xFF121212).withOpacity(0.85),
                        const Color(0xFF121212).withOpacity(0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: TextButton(
                          onPressed: _finishSelection,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            langProvider.t('skip'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: canContinue
                                    ? Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: canContinue
                                      ? Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.5)
                                      : Colors.white.withOpacity(0.1),
                                  width: 1.5,
                                ),
                                boxShadow: canContinue
                                    ? [
                                        BoxShadow(
                                          color: Theme.of(
                                            context,
                                          ).primaryColor.withOpacity(0.2),
                                          blurRadius: 15,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: canContinue ? _finishSelection : null,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: Center(
                                      child: Text(
                                        langProvider.t('continue'),
                                        style: TextStyle(
                                          color: canContinue
                                              ? Colors.white
                                              : Colors.grey.shade600,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
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
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
