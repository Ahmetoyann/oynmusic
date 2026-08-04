import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/song_provider.dart';
import '../providers/language_provider.dart';
import '../models/song_model.dart';
import '../pages/artist_detail_page.dart';
import '../widgets/device_cover_placeholder.dart';
import '../widgets/custom_snack_bar.dart';

class CurrentArtistBox extends StatefulWidget {
  final String artistName;
  final SongProvider songProvider;
  final LanguageProvider langProvider;
  final VoidCallback onRequireLogin;
  final Song currentSong;

  const CurrentArtistBox({
    Key? key,
    required this.artistName,
    required this.songProvider,
    required this.langProvider,
    required this.onRequireLogin,
    required this.currentSong,
  }) : super(key: key);

  @override
  State<CurrentArtistBox> createState() => _CurrentArtistBoxState();
}

class _CurrentArtistBoxState extends State<CurrentArtistBox> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  @override
  void didUpdateWidget(covariant CurrentArtistBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artistName != widget.artistName) {
      _loadAvatar();
    }
  }

  Future<void> _loadAvatar() async {
    setState(() => _isLoading = true);
    final currentAvatar =
        widget.songProvider.getArtistAvatar(widget.artistName);
    final subs = widget.songProvider.getArtistSubscribers(widget.artistName);

    if (currentAvatar != null &&
        !currentAvatar.contains('ui-avatars.com') &&
        subs != null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    await widget.songProvider.fetchArtistAvatar(widget.artistName);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl =
        widget.songProvider.getArtistAvatar(widget.artistName) ?? '';
    final songViewCount = widget.currentSong.viewCount;
    final isFollowed =
        widget.songProvider.followedArtists.contains(widget.artistName);
    final primaryColor = Theme.of(context).primaryColor;

    String followersText = '';
    if (songViewCount != null && songViewCount > 0) {
      final formatter = NumberFormat.compact(locale: 'tr_TR');
      followersText = 'Aylık ${formatter.format(songViewCount)} dinleyici';
    } else {
      followersText = '';
    }

    return SizedBox(
      height: 360,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Üst Kısım (5 oran)
            Expanded(
              flex: 5,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ArtistDetailPage(
                        artistName: widget.artistName,
                        songs: [widget.currentSong],
                      ),
                    ),
                  );
                },
                child: _isLoading && avatarUrl.isEmpty
                    ? DeviceCoverPlaceholder(
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: 0,
                        logoColor: primaryColor,
                      )
                    : CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            DeviceCoverPlaceholder(
                          width: double.infinity,
                          height: double.infinity,
                          borderRadius: 0,
                          logoColor: primaryColor,
                        ),
                      ),
              ),
            ),

            // Alt Kısım (2 oran)
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Sol Taraf (İsim ve Takipçi)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.artistName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (followersText.isNotEmpty)
                            Text(
                              followersText,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Sağ Taraf (Takip Et Butonu)
                    GestureDetector(
                      onTap: () {
                        if (!widget.songProvider.isFirebaseLoggedIn) {
                          widget.onRequireLogin();
                          return;
                        }
                        widget.songProvider
                            .toggleFollowArtist(widget.artistName);
                        CustomSnackBar.showInfo(
                          context: context,
                          message: isFollowed
                              ? widget.langProvider
                                  .t('artist_unfollowed')
                                  .replaceAll('%s', widget.artistName)
                              : widget.langProvider
                                  .t('artist_followed_snack')
                                  .replaceAll('%s', widget.artistName),
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isFollowed
                              ? primaryColor.withOpacity(0.15)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isFollowed
                                ? primaryColor.withOpacity(0.5)
                                : Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isFollowed
                              ? widget.langProvider.t('followed')
                              : widget.langProvider.t('follow'),
                          style: TextStyle(
                            color: isFollowed ? primaryColor : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
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
