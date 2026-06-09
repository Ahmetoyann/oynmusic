import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/providers/language_provider.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/pages/artist_detail_page.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';

class SongMenuHelper {
  static void showModernMenu(BuildContext context, Song song) {
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    final bool isDeviceSong =
        song.localPath != null && song.audioUrl == song.localPath;

    CustomBottomSheet.showContent(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          ListTile(
            leading: CustomIcons.svgIcon(
              CustomIcons.playlistPlay,
              color: Colors.white,
              size: 24,
            ),
            title: Text(
              langProvider.t('add_to_playlist'),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            onTap: () {
              Navigator.pop(context);
              _showAddToPlaylistSheetStatic(
                context,
                song,
                songProvider,
                langProvider,
              );
            },
          ),
          if (!isDeviceSong)
            ListTile(
              leading: CustomIcons.svgIcon(
                CustomIcons.person,
                color: Colors.white,
                size: 24,
              ),
              title: Text(
                langProvider.t('go_to_artist'),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ArtistDetailPage(
                      artistName: song.artist,
                      songs: [song],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static void _showAddToPlaylistSheetStatic(
    BuildContext context,
    Song song,
    SongProvider songProvider,
    LanguageProvider langProvider,
  ) {
    // Add the playlist bottom sheet logic here from your PlayerPage
    // ...
  }
}
