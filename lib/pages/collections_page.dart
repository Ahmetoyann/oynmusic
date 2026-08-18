import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/providers/language_provider.dart';
import 'package:muzik_app/widgets/song_grid_card.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/pages/artist_detail_page.dart';

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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          langProvider.t('featured_collections'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: displayedCollections.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: displayedCollections.length,
              itemBuilder: (context, index) {
                final collection = displayedCollections[index];
                return RepaintBoundary(
                    child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SongGridCard(
                    song: collection,
                    imageUrl: collection.coverUrl,
                    title: collection.title,
                    showFavorite: false,
                    titleMaxLines: 2,
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
                ));
              },
            ),
    );
  }
}
