import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/providers/language_provider.dart';
import 'package:muzik_app/widgets/song_grid_card.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/pages/artist_detail_page.dart';
import 'package:muzik_app/widgets/custom_app_bar.dart';

class CollectionsPage extends StatelessWidget {
  const CollectionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final suggestedAlbums =
        context.select<SongProvider, List<Song>>((p) => p.suggestedAlbums);
    final langProvider = context.watch<LanguageProvider>();

    final List<Song> displayedCollections = suggestedAlbums;

    return Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: CustomAppBar(
          title: langProvider.t('featured_collections'),
        ),
        body: displayedCollections.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                color: Theme.of(context).primaryColor,
                backgroundColor: Colors.grey.shade900,
                onRefresh: () async {
                  await context
                      .read<SongProvider>()
                      .fetchSuggestedSongs(forceRefresh: true);
                },
                child: GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: displayedCollections.length,
                  itemBuilder: (context, index) {
                    final collection = displayedCollections[index];
                    return RepaintBoundary(
                      child: SongGridCard(
                        song: collection,
                        imageUrl: collection.coverUrl,
                        title: collection.title,
                        showFavorite: false,
                        titleMaxLines: 2,
                        showPlaceholderIcon: false,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ArtistDetailPage(
                                artistName: collection.title,
                                songs: [collection],
                                isCollection: true,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ));
  }
}
