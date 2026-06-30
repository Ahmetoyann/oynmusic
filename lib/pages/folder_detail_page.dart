// lib/pages/folder_detail_page.dart

import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/widgets/mini_player.dart';
import 'package:muzik_app/pages/player_page.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/services/audius_service.dart';
import 'package:muzik_app/widgets/song_card.dart';
import 'package:image_picker/image_picker.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:muzik_app/widgets/custom_app_bar.dart';
import 'package:muzik_app/widgets/custom_drop_down.dart';
import 'package:muzik_app/providers/language_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:muzik_app/widgets/device_cover_placeholder.dart';
import 'package:muzik_app/widgets/custom_search_bar.dart';

enum FolderSortOption { titleAZ, titleZA, artistAZ, artistZA }

class FolderDetailPage extends StatefulWidget {
  // Bu sayfa, hangi klasörün gösterileceğini bilmek için bir MusicFolder nesnesi alır.
  final MusicFolder folder;

  // Constructor ile bu folder nesnesini almayı zorunlu kılıyoruz.
  const FolderDetailPage({super.key, required this.folder});

  @override
  State<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends State<FolderDetailPage>
    with SingleTickerProviderStateMixin {
  bool _isSelectionMode = false;
  bool _isReorderMode = false;
  final Set<String> _selectedSongIds = {};
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _showStickyPlayButton = false;
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
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
        // Liste aşağı kaydırıldığında ve arama kutusu boşsa gizle
        setState(() => _showSearchBar = false);
      }
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedSongIds.contains(id)) {
        _selectedSongIds.remove(id);
        if (_selectedSongIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedSongIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedSongIds.length == widget.folder.songs.length) {
        _selectedSongIds.clear();
      } else {
        _selectedSongIds.addAll(widget.folder.songs.map((s) => s.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Provider'ı izleyerek değişikliklerde sayfanın yenilenmesini sağlıyoruz.
    final songProvider = context.read<SongProvider>();
    final folders =
        context.select<SongProvider, List<MusicFolder>>((p) => p.folders);
    final currentSongId =
        context.select<SongProvider, String?>((p) => p.currentSong?.id);
    final langProvider = context.watch<LanguageProvider>();
    final folder = folders.firstWhere((f) => f.name == widget.folder.name,
        orElse: () => widget.folder);

    final displayedSongs = folder.songs.where((song) {
      if (_searchText.isEmpty) return true;
      final query = _searchText.toLowerCase();
      return song.title.toLowerCase().contains(query) ||
          song.artist.toLowerCase().contains(query);
    }).toList();

    // Listedeki tüm şarkıların toplam süresini hesapla
    int totalSeconds = folder.songs.fold(
      0,
      (sum, item) => sum + (item.duration ?? 0),
    );
    String durationText = '';
    if (totalSeconds > 0) {
      int h = totalSeconds ~/ 3600;
      int m = (totalSeconds % 3600) ~/ 60;
      int s = totalSeconds % 60;
      final isTr = langProvider.currentLanguage == 'tr';
      String hrStr = isTr ? 's' : 'h'; // TR için Saat
      String minStr = isTr ? 'd' : 'm'; // TR için Dakika
      String secStr = isTr ? 'sn' : 's'; // TR için Saniye

      if (h > 0) {
        durationText = '·$h$hrStr $m$minStr';
      } else {
        durationText = '·$m$minStr $s$secStr';
      }
    }

    final bool isAnyLoaded = currentSongId != null &&
        displayedSongs.any((s) => s.id == currentSongId);

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
                leading: (_isSelectionMode || _isReorderMode)
                    ? Center(
                        child: Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: CustomIcons.svgIcon(
                              CustomIcons.close,
                              size: 24,
                            ),
                            onPressed: () {
                              setState(() {
                                _isSelectionMode = false;
                                _isReorderMode = false;
                                _selectedSongIds.clear();
                              });
                            },
                          ),
                        ),
                      )
                    : Center(
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
                title: Text(
                  _isSelectionMode
                      ? '${_selectedSongIds.length} Seçildi'
                      : (_isReorderMode
                          ? langProvider.t('edit_order')
                          : (_showStickyPlayButton ? folder.name : '')),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                  ),
                ),
                centerTitle: true,
                actions: _isSelectionMode
                    ? [
                        Center(
                          child: Container(
                            width: 46,
                            height: 46,
                            margin: const EdgeInsets.only(right: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.2),
                              ),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: CustomIcons.svgIcon(
                                CustomIcons.selectAll,
                                size: 24,
                              ),
                              tooltip: langProvider.t('all'),
                              onPressed: _selectAll,
                            ),
                          ),
                        ),
                        Center(
                          child: Container(
                            width: 46,
                            height: 46,
                            margin: const EdgeInsets.only(right: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.2),
                              ),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: CustomIcons.svgIcon(
                                CustomIcons.playlistPlay,
                                size: 24,
                              ),
                              tooltip: langProvider.t('add_to_playlist'),
                              onPressed: _selectedSongIds.isEmpty
                                  ? null
                                  : () {
                                      final selectedSongs = folder.songs
                                          .where(
                                            (s) =>
                                                _selectedSongIds.contains(s.id),
                                          )
                                          .toList();
                                      songProvider.addSongsToNext(
                                        selectedSongs,
                                      );
                                      setState(() {
                                        _isSelectionMode = false;
                                        _selectedSongIds.clear();
                                      });
                                    },
                            ),
                          ),
                        ),
                        Center(
                          child: Container(
                            width: 46,
                            height: 46,
                            margin: const EdgeInsets.only(right: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.2),
                              ),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: CustomIcons.svgIcon(
                                CustomIcons.delete,
                                color: Colors.redAccent,
                              ),
                              tooltip: langProvider.t('delete_list'),
                              onPressed: _selectedSongIds.isEmpty
                                  ? null
                                  : () {
                                      _showBulkDeleteDialog(
                                        context,
                                        songProvider,
                                      );
                                    },
                            ),
                          ),
                        ),
                      ]
                    : [],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (folder.customImagePath != null &&
                          File(folder.customImagePath!).existsSync())
                        Image.file(
                          File(folder.customImagePath!),
                          fit: BoxFit.cover,
                        )
                      else if (folder.songs.isNotEmpty)
                        _buildImage(folder.songs.first)
                      else
                        Container(color: Colors.grey.shade900),

                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                        child: Container(color: Colors.black.withOpacity(0.4)),
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
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: CustomSearchBar(
                                              controller: _searchController,
                                              hintText: langProvider
                                                  .t('search_in_artist')
                                                  .replaceAll(
                                                      '%s', folder.name),
                                              showClearButton:
                                                  _searchText.isNotEmpty,
                                              fillColor: Colors.white
                                                  .withOpacity(0.15),
                                              onClear: () {
                                                setState(
                                                    () => _searchText = '');
                                                FocusScope.of(context)
                                                    .unfocus();
                                              },
                                              onChanged: (value) => setState(
                                                  () => _searchText = value),
                                              onSubmitted: (_) =>
                                                  FocusScope.of(context)
                                                      .unfocus(),
                                            ),
                                          ),
                                          if (folder.songs.isNotEmpty) ...[
                                            const SizedBox(width: 12),
                                            Container(
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: CustomDropDown<
                                                  FolderSortOption>(
                                                icon: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      langProvider.t('sort') ??
                                                          "Sırala",
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                  ],
                                                ),
                                                tooltip:
                                                    langProvider.t('sort') ??
                                                        "Sırala",
                                                onSelected: (option) {
                                                  final provider = context
                                                      .read<SongProvider>();
                                                  switch (option) {
                                                    case FolderSortOption
                                                          .titleAZ:
                                                      provider.sortFolderSongs(
                                                        folder,
                                                        (a, b) => a.title
                                                            .compareTo(b.title),
                                                      );
                                                      break;
                                                    case FolderSortOption
                                                          .titleZA:
                                                      provider.sortFolderSongs(
                                                        folder,
                                                        (a, b) => b.title
                                                            .compareTo(a.title),
                                                      );
                                                      break;
                                                    case FolderSortOption
                                                          .artistAZ:
                                                      provider.sortFolderSongs(
                                                        folder,
                                                        (a, b) => a.artist
                                                            .compareTo(
                                                                b.artist),
                                                      );
                                                      break;
                                                    case FolderSortOption
                                                          .artistZA:
                                                      provider.sortFolderSongs(
                                                        folder,
                                                        (a, b) => b.artist
                                                            .compareTo(
                                                                a.artist),
                                                      );
                                                      break;
                                                  }
                                                },
                                                items: [
                                                  CustomDropdownItem.build<
                                                      FolderSortOption>(
                                                    context: context,
                                                    value: FolderSortOption
                                                        .titleAZ,
                                                    icon: Icon(
                                                      Icons
                                                          .sort_by_alpha_rounded,
                                                      size: 20,
                                                      color: Theme.of(context)
                                                          .primaryColor,
                                                    ),
                                                    text: langProvider
                                                        .t('title_a_z'),
                                                  ),
                                                  CustomDropdownItem.build<
                                                      FolderSortOption>(
                                                    context: context,
                                                    value: FolderSortOption
                                                        .titleZA,
                                                    icon: Icon(
                                                      Icons
                                                          .sort_by_alpha_rounded,
                                                      size: 20,
                                                      color: Theme.of(context)
                                                          .primaryColor,
                                                    ),
                                                    text: langProvider
                                                        .t('title_z_a'),
                                                  ),
                                                  CustomDropdownItem.build<
                                                      FolderSortOption>(
                                                    context: context,
                                                    value: FolderSortOption
                                                        .artistAZ,
                                                    icon: Icon(
                                                      Icons
                                                          .person_outline_rounded,
                                                      size: 20,
                                                      color: Theme.of(context)
                                                          .primaryColor,
                                                    ),
                                                    text: langProvider
                                                        .t('artist_a_z'),
                                                  ),
                                                  CustomDropdownItem.build<
                                                      FolderSortOption>(
                                                    context: context,
                                                    value: FolderSortOption
                                                        .artistZA,
                                                    icon: Icon(
                                                      Icons
                                                          .person_outline_rounded,
                                                      size: 20,
                                                      color: Theme.of(context)
                                                          .primaryColor,
                                                    ),
                                                    text: langProvider
                                                        .t('artist_z_a'),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    )
                                  : const SizedBox(
                                      width: double.infinity, height: 0),
                            ),
                            const Spacer(),
                            Center(
                              child: GestureDetector(
                                onTap: () {
                                  _showFolderOptions(context, songProvider);
                                },
                                child: Stack(
                                  children: [
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeOutCubic,
                                      width: _showSearchBar ? 192 : 288,
                                      height: _showSearchBar ? 108 : 162,
                                      decoration: BoxDecoration(
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
                                        child: _buildFolderCover(folder),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          shape: BoxShape.circle,
                                        ),
                                        child: CustomIcons.svgIcon(
                                          CustomIcons.edit,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                folder.name,
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
                            if (folder.songs.isNotEmpty)
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
                                          sigmaX: 10,
                                          sigmaY: 10,
                                        ),
                                        child: Container(
                                          width: 44,
                                          height: 44,
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
                                                if (folder.songs.isNotEmpty) {
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
                                                      size: 20,
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
                                    const SizedBox(width: 12),
                                    // 2. Oynat Butonu
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(30),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: 10,
                                          sigmaY: 10,
                                        ),
                                        child: Container(
                                          width: 44,
                                          height: 44,
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
                                                        milliseconds: 300,
                                                      ),
                                                      child: Icon(
                                                        isPlayingNow
                                                            ? Icons
                                                                .pause_rounded
                                                            : Icons
                                                                .play_arrow_rounded,
                                                        key: ValueKey<bool>(
                                                          isPlayingNow,
                                                        ),
                                                        color: isPlayingNow
                                                            ? Colors.greenAccent
                                                            : Colors.white,
                                                        size: 26,
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
                                    Expanded(
                                      child: Text(
                                        '${folder.songs.length} ${langProvider.t('song')}$durationText',
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    // 3. Sıralama (Reorder) Modu Butonu
                                    IconButton(
                                      icon: Icon(
                                        Icons.drag_handle_rounded,
                                        color: _isReorderMode
                                            ? Theme.of(context).primaryColor
                                            : Colors.white.withOpacity(0.8),
                                      ),
                                      iconSize: 26,
                                      onPressed: () {
                                        setState(() {
                                          _isReorderMode = !_isReorderMode;
                                          if (_isReorderMode) {
                                            _isSelectionMode = false;
                                            _selectedSongIds.clear();
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 12),
                                    // 4. Ekle (+) Butonu
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(30),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: 10,
                                          sigmaY: 10,
                                        ),
                                        child: Container(
                                          width: 44,
                                          height: 44,
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
                                              onTap: () =>
                                                  _showAddSongsSheet(context),
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                              child: Center(
                                                child: CustomIcons.svgIcon(
                                                  CustomIcons.addRounded,
                                                  color: Colors.white,
                                                  size: 24,
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
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (folder.songs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(context),
                )
              else if (displayedSongs.isEmpty && _searchText.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 50.0),
                    child: _buildNoResultsState(context),
                  ),
                )
              else if (_searchText.isNotEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    MediaQuery.of(context).size.width * 0.025,
                    10,
                    MediaQuery.of(context).size.width * 0.025,
                    10,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final song = displayedSongs[index];
                      final isSelected = _selectedSongIds.contains(song.id);
                      return _buildSongItem(
                        context,
                        song,
                        isSelected,
                        index,
                        songProvider,
                      );
                    }, childCount: displayedSongs.length),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    MediaQuery.of(context).size.width * 0.025,
                    10,
                    MediaQuery.of(context).size.width * 0.025,
                    10,
                  ),
                  sliver: SliverReorderableList(
                    itemCount: folder.songs.length,
                    onReorder: (oldIndex, newIndex) {
                      if (!_isSelectionMode) {
                        songProvider.reorderSongsInFolder(
                          folder,
                          oldIndex,
                          newIndex,
                        );
                      }
                    },
                    itemBuilder: (context, index) {
                      final song = folder.songs[index];
                      final isSelected = _selectedSongIds.contains(song.id);
                      return _buildSongItem(
                        context,
                        song,
                        isSelected,
                        index,
                        songProvider,
                      );
                    },
                  ),
                ),
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: currentSongId != null ? 160 : 40,
                ),
              ),
            ],
          ),
          bottomNavigationBar: currentSongId != null
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
        ),
        if (!_isSelectionMode && !_isReorderMode && displayedSongs.isNotEmpty)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            top: _showStickyPlayButton
                ? MediaQuery.of(context).padding.top + kToolbarHeight - 24
                : MediaQuery.of(context).padding.top + 60,
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
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.8),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.3),
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
          )
      ],
    );
  }

  Future<void> _pickFolderImage(
    BuildContext context,
    SongProvider provider,
  ) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      provider.updateFolderImage(widget.folder, image.path);
      if (mounted) {
        CustomSnackBar.showSuccess(
          context: context,
          message: 'Kapak resmi güncellendi',
        );
      }
    }
  }

  void _showFolderOptions(BuildContext context, SongProvider provider) {
    final langProvider = context.read<LanguageProvider>();

    CustomBottomSheet.showContent(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          ListTile(
            leading: CustomIcons.svgIcon(
              CustomIcons.edit,
              color: Colors.white,
              size: 24,
            ),
            title: Text(
              langProvider.t('rename'),
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              _showRenameFolderDialog(context, provider);
            },
          ),
          ListTile(
            leading: CustomIcons.svgIcon(
              CustomIcons.image,
              color: Colors.white,
              size: 24,
            ),
            title: Text(
              langProvider.t('change_cover'),
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              _pickFolderImage(context, provider);
            },
          ),
          if (widget.folder.customImagePath != null)
            ListTile(
              leading: CustomIcons.svgIcon(
                CustomIcons.delete,
                color: Colors.redAccent,
              ),
              title: Text(
                langProvider.t('remove_cover'),
                style: const TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(context);
                provider.updateFolderImage(widget.folder, null);
                CustomSnackBar.showError(
                  context: context,
                  message: 'Kapak resmi kaldırıldı',
                );
              },
            ),
          ListTile(
            leading: CustomIcons.svgIcon(
              CustomIcons.delete,
              color: Colors.redAccent,
              size: 24,
            ),
            title: Text(
              langProvider.t('delete_list'),
              style: const TextStyle(color: Colors.redAccent),
            ),
            onTap: () {
              Navigator.pop(context);
              _showDeleteFolderDialog(context, provider);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showRenameFolderDialog(BuildContext context, SongProvider provider) {
    final langProvider = context.read<LanguageProvider>();
    final TextEditingController controller = TextEditingController(
      text: widget.folder.name,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text(
          langProvider.t('rename'),
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: langProvider.t('new_name_hint'),
            hintStyle: TextStyle(color: Colors.grey.shade500),
            filled: true,
            fillColor: Colors.grey.shade800,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              langProvider.t('cancel'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.renameFolder(widget.folder, controller.text);
                Navigator.pop(ctx);
              }
            },
            child: Text(
              langProvider.t('save'),
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteFolderDialog(BuildContext context, SongProvider provider) {
    final langProvider = context.read<LanguageProvider>();
    CustomBottomSheet.show(
      context: context,
      title: langProvider.t('delete_list'),
      message: '${widget.folder.name} ${langProvider.t('delete_list_desc')}',
      primaryButtonText: langProvider.t('delete'),
      primaryButtonColor: Colors.redAccent,
      secondaryButtonText: langProvider.t('cancel'),
      onPrimaryButtonTap: () {
        provider.deleteFolder(widget.folder);
        Navigator.pop(context); // Alt menüyü kapat
        Navigator.pop(context); // Detay sayfasından çık
        CustomSnackBar.showError(
          context: context,
          message: '${widget.folder.name} ${langProvider.t('deleted')}',
        );
      },
    );
  }

  Widget _buildFolderCover(MusicFolder folder) {
    final songs = folder.songs;
    if (folder.customImagePath != null &&
        File(folder.customImagePath!).existsSync()) {
      return Image.file(
        File(folder.customImagePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    if (songs.isEmpty) {
      return Container(
        color: Colors.grey.shade800,
        child: Center(
          child: CustomIcons.svgIcon(
            CustomIcons.musicNote,
            color: Colors.white54,
            size: 64,
          ),
        ),
      );
    }

    if (songs.length < 4) {
      return _buildImage(songs.first);
    }

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildImage(songs[0])),
              Expanded(child: _buildImage(songs[1])),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildImage(songs[2])),
              Expanded(child: _buildImage(songs[3])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImage(Song song) {
    if (song.localImagePath != null &&
        File(song.localImagePath!).existsSync()) {
      return ClipRect(
          child: Image.file(
        File(song.localImagePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return DeviceCoverPlaceholder(
            logoColor: Theme.of(context).primaryColor,
          );
        },
      ));
    }

    if (song.coverUrl.isEmpty) {
      return DeviceCoverPlaceholder(
        width: 108,
        height: 108,
        borderRadius: 8,
        logoColor: Theme.of(context).primaryColor,
      );
    }

    return ClipRect(
      child: CachedNetworkImage(
        imageUrl: song.coverUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorWidget: (context, url, error) => DeviceCoverPlaceholder(
          logoColor: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    SongProvider provider,
    Song song,
  ) {
    final langProvider = context.read<LanguageProvider>();
    CustomBottomSheet.show(
      context: context,
      title: langProvider.t('remove_from_list_title'),
      message: '${song.title} ${langProvider.t('remove_from_list_desc')}',
      primaryButtonText: langProvider.t('delete'),
      primaryButtonColor: Colors.redAccent,
      secondaryButtonText: langProvider.t('cancel'),
      onPrimaryButtonTap: () {
        provider.removeSongFromFolder(widget.folder, song);
        Navigator.pop(context);
        CustomSnackBar.showError(
          context: context,
          message: '${song.title} listeden silindi.',
        );
      },
    );
  }

  void _showBulkDeleteDialog(BuildContext context, SongProvider provider) {
    final langProvider = context.read<LanguageProvider>();
    CustomBottomSheet.show(
      context: context,
      title: langProvider.t('delete_selected'),
      message:
          '${_selectedSongIds.length} ${langProvider.t('delete_selected_songs_desc')}',
      primaryButtonText: langProvider.t('delete'),
      primaryButtonColor: Colors.redAccent,
      secondaryButtonText: langProvider.t('cancel'),
      onPrimaryButtonTap: () {
        provider.removeSongsFromFolder(
          widget.folder,
          _selectedSongIds.toList(),
        );
        Navigator.pop(context);
        setState(() {
          _isSelectionMode = false;
          _selectedSongIds.clear();
        });
        CustomSnackBar.showError(
          context: context,
          message: 'Seçilen şarkılar silindi.',
        );
      },
    );
  }

  Widget _buildSongItem(
    BuildContext context,
    Song song,
    bool isSelected,
    int index,
    SongProvider songProvider,
  ) {
    final langProvider = context.read<LanguageProvider>();
    final isCurrentSong = songProvider.currentSong?.id == song.id;

    return Material(
      key: ValueKey(song.id),
      color: isSelected
          ? Theme.of(context).primaryColor.withOpacity(0.1)
          : Colors.transparent,
      child: Row(
        children: [
          if (_isSelectionMode)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Checkbox(
                value: isSelected,
                activeColor: Theme.of(context).primaryColor,
                onChanged: (v) => _toggleSelection(song.id),
              ),
            ),
          Expanded(
            child: GestureDetector(
              onLongPress: () {
                if (!_isSelectionMode && !_isReorderMode) {
                  setState(() {
                    _isSelectionMode = true;
                    _selectedSongIds.add(song.id);
                  });
                }
              },
              child: SongCard(
                song: song,
                isPlaying: isCurrentSong,
                showOptions: !_isSelectionMode && !_isReorderMode,
                onDeleteTap: () =>
                    _showDeleteDialog(context, songProvider, song),
                deleteText: langProvider.t('remove_from_list'),
                trailing: _isSelectionMode ||
                        _searchText.isNotEmpty ||
                        !_isReorderMode
                    ? null
                    : ReorderableDragStartListener(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Icon(
                            Icons.drag_handle_rounded,
                            color: Theme.of(context).primaryColor,
                            size: 28,
                          ),
                        ),
                      ),
                onTap: () {
                  if (_isSelectionMode) {
                    _toggleSelection(song.id);
                  } else if (_isReorderMode) {
                    // Reorder modundayken normal şarkı tıklaması pasif olur.
                  } else {
                    final isCurrent = songProvider.currentSong?.id == song.id;

                    if (isCurrent) {
                      if (songProvider.audioPlayer.playing) {
                        songProvider.audioPlayer.pause();
                      } else {
                        songProvider.audioPlayer.play();
                      }
                    } else {
                      songProvider.playSong(song, widget.folder.songs);
                    }
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(BuildContext context) {
    final langProvider = context.watch<LanguageProvider>();
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
              CustomIcons.searchOff,
              size: 64,
              color: Theme.of(context).primaryColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            langProvider.t('no_results'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            langProvider.t('try_different_search'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
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
              color: Colors.grey.shade900,
              shape: BoxShape.circle,
            ),
            child: CustomIcons.svgIcon(
              CustomIcons.musicNote,
              size: 64,
              color: Theme.of(context).primaryColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            langProvider.t('list_empty'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            langProvider.t('no_song_in_list'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showAddSongsSheet(context),
            icon: CustomIcons.svgIcon(
              CustomIcons.addRounded,
              color: Colors.white,
              size: 24,
            ),
            label: Text(langProvider.t('add_song')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSongsSheet(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (pageContext, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Theme.of(pageContext).scaffoldBackgroundColor,
            body: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 32),
                        onPressed: () => Navigator.pop(pageContext),
                      ),
                    ),
                  ),
                  Expanded(child: AddSongsSheet(folder: widget.folder)),
                ],
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
              position: animation.drive(tween), child: child);
        },
      ),
    );
  }
}

class AddSongsSheet extends StatefulWidget {
  final MusicFolder folder;
  const AddSongsSheet({super.key, required this.folder});

  @override
  State<AddSongsSheet> createState() => _AddSongsSheetState();
}

class _AddSongsSheetState extends State<AddSongsSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Song> _songs = [];
  final Set<String> _selectedSongIds = {};
  bool _isLoading = false;
  Timer? _debounce;

  void _sortSongs() {
    final folderSongIds = widget.folder.songs.map((s) => s.id).toSet();
    _songs.sort((a, b) {
      final aExists = folderSongIds.contains(a.id);
      final bExists = folderSongIds.contains(b.id);
      if (aExists == bExists) return 0;
      return aExists ? 1 : -1;
    });
  }

  @override
  void initState() {
    super.initState();
    // Başlangıçta favorileri göster
    final provider = context.read<SongProvider>();
    if (widget.folder.isFromDownloads) {
      _songs = List.from(provider.downloadedSongs);
    } else {
      _songs = List.from(provider.favoriteSongs);
    }
    _sortSongs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        setState(() {
          final provider = context.read<SongProvider>();
          if (widget.folder.isFromDownloads) {
            _songs = List.from(provider.downloadedSongs);
          } else {
            _songs = List.from(provider.favoriteSongs);
          }
          _sortSongs();
        });
        return;
      }

      setState(() => _isLoading = true);
      try {
        if (widget.folder.isFromDownloads) {
          final provider = context.read<SongProvider>();
          final results = provider.downloadedSongs.where((s) {
            final q = query.toLowerCase();
            return s.title.toLowerCase().contains(q) ||
                s.artist.toLowerCase().contains(q);
          }).toList();
          if (mounted) {
            setState(() {
              _songs = results;
              _sortSongs();
            });
          }
        } else {
          final results = await YoutubeService.searchSongs(query);
          if (mounted) {
            setState(() {
              _songs = results;
              _sortSongs();
            });
          }
        }
      } catch (e) {
        debugPrint("Arama hatası: $e");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = context.watch<LanguageProvider>();

    return Column(
      children: [
        const SizedBox(height: 24),
        Text(
          langProvider.t('add_song'),
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: CustomSearchBar(
            controller: _searchController,
            hintText: widget.folder.isFromDownloads
                ? langProvider.t('search_in_downloads')
                : langProvider.t('search_or_select_favorites'),
            fillColor: Colors.grey.shade800,
            showClearButton: _searchController.text.isNotEmpty,
            onClear: () {
              _onSearchChanged('');
            },
            onChanged: _onSearchChanged,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _songs.length,
                  itemBuilder: (context, index) {
                    final song = _songs[index];
                    final isSelected = _selectedSongIds.contains(song.id);
                    final isAlreadyAdded = widget.folder.songs.any(
                      (s) => s.id == song.id,
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: isAlreadyAdded
                            ? null
                            : () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedSongIds.remove(song.id);
                                  } else {
                                    _selectedSongIds.add(song.id);
                                  }
                                });
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isSelected || isAlreadyAdded)
                                ? Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.15)
                                : Colors.grey.shade900.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (isSelected || isAlreadyAdded)
                                  ? Theme.of(context).primaryColor
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Opacity(
                                opacity: isAlreadyAdded ? 0.5 : 1.0,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: (song.localImagePath != null &&
                                          File(
                                            song.localImagePath!,
                                          ).existsSync())
                                      ? Image.file(
                                          File(song.localImagePath!),
                                          width: 71,
                                          height: 40,
                                          fit: BoxFit.cover,
                                        )
                                      : (song.coverUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: song.coverUrl,
                                              width: 71,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              errorWidget: (
                                                context,
                                                url,
                                                error,
                                              ) =>
                                                  DeviceCoverPlaceholder(
                                                width: 71,
                                                height: 40,
                                                borderRadius: 4,
                                                logoColor: Theme.of(context)
                                                    .primaryColor,
                                              ),
                                            )
                                          : DeviceCoverPlaceholder(
                                              width: 71,
                                              height: 40,
                                              borderRadius: 4,
                                              logoColor: Theme.of(context)
                                                  .primaryColor,
                                            )),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      song.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isAlreadyAdded
                                            ? Colors.grey
                                            : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isAlreadyAdded
                                          ? langProvider.t('already_in_list')
                                          : song.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isAlreadyAdded
                                            ? Theme.of(context).primaryColor
                                            : Colors.grey.shade400,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isAlreadyAdded)
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? Theme.of(context).primaryColor
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey.shade600,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? CustomIcons.svgIcon(
                                          CustomIcons.check,
                                          size: 16,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            16,
          ),
          child: Builder(
            builder: (context) {
              final bool isDisabled = _selectedSongIds.isEmpty;
              final primaryColor = Theme.of(context).primaryColor;

              return SizedBox(
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDisabled
                            ? Colors.white.withOpacity(0.05)
                            : primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDisabled
                              ? Colors.white.withOpacity(0.1)
                              : primaryColor.withOpacity(0.5),
                          width: 1.5,
                        ),
                        boxShadow: isDisabled
                            ? []
                            : [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.2),
                                  blurRadius: 15,
                                  spreadRadius: 1,
                                ),
                              ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: isDisabled
                              ? null
                              : () {
                                  final selectedSongs = _songs
                                      .where(
                                        (s) => _selectedSongIds.contains(s.id),
                                      )
                                      .toList();
                                  context.read<SongProvider>().addSongsToFolder(
                                        widget.folder,
                                        selectedSongs,
                                      );

                                  CustomSnackBar.showSuccess(
                                    context: context,
                                    message:
                                        '${selectedSongs.length} şarkı eklendi.',
                                  );
                                  Navigator.pop(context);
                                },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'Ekle (${_selectedSongIds.length})',
                                style: TextStyle(
                                  color: isDisabled
                                      ? Colors.grey.shade500
                                      : Colors.white,
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
              );
            },
          ),
        ),
      ],
    );
  }
}
