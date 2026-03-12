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

class RecentlyPlayedPage extends StatefulWidget {
  const RecentlyPlayedPage({super.key});

  @override
  State<RecentlyPlayedPage> createState() => _RecentlyPlayedPageState();
}

class _RecentlyPlayedPageState extends State<RecentlyPlayedPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showClearHistoryDialog(BuildContext context) {
    CustomBottomSheet.show(
      context: context,
      title: 'Geçmişi Temizle',
      message: 'Tüm dinleme geçmişiniz silinsin mi? Bu işlem geri alınamaz.',
      primaryButtonText: 'Temizle',
      primaryButtonColor: Colors.redAccent,
      secondaryButtonText: 'İptal',
      onPrimaryButtonTap: () {
        context.read<SongProvider>().clearRecentlyPlayed();
        Navigator.pop(context);
        CustomSnackBar.showError(
          context: context,
          message: "Geçmiş temizlendi",
        );
      },
    );
  }

  String _getDateHeader(DateTime? date) {
    if (date == null) return 'Daha Önce';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final aWeekAgo = today.subtract(const Duration(days: 7));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck.isAtSameMomentAs(today)) {
      return 'Bugün';
    } else if (dateToCheck.isAtSameMomentAs(yesterday)) {
      return 'Dün';
    } else if (dateToCheck.isAfter(aWeekAgo)) {
      return 'Bu Hafta';
    } else {
      return 'Daha Önce';
    }
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = context.watch<SongProvider>();
    final allSongs = songProvider.recentlyPlayed;

    // Arama filtresi
    final displayedSongs = allSongs.where((song) {
      final query = _searchText.toLowerCase();
      return song.title.toLowerCase().contains(query) ||
          song.artist.toLowerCase().contains(query);
    }).toList();

    // Gruplama işlemi
    final Map<String, List<Song>> groupedSongs = {};
    for (var song in displayedSongs) {
      final header = _getDateHeader(song.lastPlayed);
      if (!groupedSongs.containsKey(header)) {
        groupedSongs[header] = [];
      }
      groupedSongs[header]!.add(song);
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'En Son Dinlediklerin'),
      bottomNavigationBar: songProvider.currentSong != null
          ? GestureDetector(
              onTap: () => PlayerPage.show(context),
              child: const MiniPlayer(),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Geçmişte ara...',
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
            ),
          ),
          if (allSongs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showClearHistoryDialog(context),
                  icon: CustomIcons.svgIcon(
                    CustomIcons.delete,
                    size: 18,
                    color: Colors.redAccent,
                  ),
                  label: const Text("Geçmişi Temizle"),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: displayedSongs.isEmpty
                ? _buildEmptyState(context, allSongs.isEmpty)
                : ListView.builder(
                    itemCount: groupedSongs.length,
                    padding: const EdgeInsets.only(bottom: 20),
                    itemBuilder: (context, index) {
                      final header = groupedSongs.keys.elementAt(index);
                      final songs = groupedSongs[header]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              header,
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...songs.map((song) {
                            final isCurrentSong =
                                songProvider.currentSong?.id == song.id;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: SongCard(
                                song: song,
                                isPlaying: isCurrentSong,
                                showOptions: true,
                                onTap: () {
                                  if (!isCurrentSong) {
                                    context.read<SongProvider>().playSong(
                                      song,
                                      displayedSongs,
                                    );
                                  }
                                  PlayerPage.show(context);
                                },
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isEmptyHistory) {
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
              isEmptyHistory ? CustomIcons.history : CustomIcons.searchOff,
              size: 64,
              color: Theme.of(context).primaryColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isEmptyHistory ? 'Henüz Geçmiş Yok' : 'Sonuç Bulunamadı',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isEmptyHistory
                ? 'Dinlediğiniz şarkılar burada görünecek.'
                : 'Aradığınız kriterlere uygun şarkı bulunamadı.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
