// ignore_for_file: deprecated_member_use, unnecessary_underscores

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:salatime/controller/audio_player_controller.dart';
import 'package:salatime/helper/catalog_search.dart';
import 'package:salatime/helper/quran_chapter_catalog.dart';
import 'package:salatime/shimmer/all_shimmer_loder.dart';
import 'package:salatime/util/images.dart';
import 'package:salatime/util/styles.dart';
import 'package:salatime/view/base/custom_app_bar.dart';
import 'package:salatime/view/base/catalog_search_field.dart';
import 'package:salatime/view/screens/audio/audio_player_sheet.dart';

import '../../../util/dimensions.dart';

class AudioPlayerView extends StatefulWidget {
  final bool? appBackButton;
  final reciterId = Get.arguments as int;

  AudioPlayerView({super.key, this.appBackButton});

  @override
  State<AudioPlayerView> createState() => _AudioPlayerViewState();
}

class _AudioPlayerViewState extends State<AudioPlayerView> {
  final AudioPlayerController _controller =
      Get.isRegistered<AudioPlayerController>()
      ? Get.find<AudioPlayerController>()
      : Get.put(AudioPlayerController(apiClient: Get.find()));
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  QuranChapterCatalog? _chapterCatalog;

  @override
  void initState() {
    super.initState();
    // AudioPlayerController already owns the initialized shared handler.
    _controller.isLoading.value = true;
    _controller.audioList.clear();
    _loadChapterCatalog();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _controller.loadAudioList(widget.reciterId.toString());
    });
  }

  Future<void> _loadChapterCatalog() async {
    try {
      final catalog = await QuranChapterCatalog.load();
      if (mounted) setState(() => _chapterCatalog = catalog);
    } catch (_) {
      // Existing media titles remain searchable if the bundled asset fails.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "audio_list_key".tr,
        isBackButtonExist: widget.appBackButton ?? false,
      ),
      body: Obx(
        () => _controller.isLoading.value
            ? const Center(child: DhuaShimmer())
            : _controller.audioData.isEmpty
            ? _buildEmptyAudioList()
            : _buildAudioListWithPlayer(),
      ),
    );
  }

  Widget _buildEmptyAudioList() {
    return Center(
      child: Text(
        "no_audio_found_key".tr,
        style: robotoMedium.copyWith(fontSize: Dimensions.FONT_SIZE_LARGE),
      ),
    );
  }

  Widget _buildAudioListWithPlayer() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(Dimensions.PADDING_SIZE_SMALL),
          child: CatalogSearchField(
            controller: _searchController,
            fieldKey: const ValueKey('audio_surah_search'),
            hintText: 'surah_search_hint'.tr,
            onChanged: (_) {
              if (_scrollController.hasClients) _scrollController.jumpTo(0);
              setState(() {});
            },
          ),
        ),
        Expanded(child: _buildAudioList()),
        _buildBottomPlayerSection(),
      ],
    );
  }

  Widget _buildAudioList() {
    final language = Localizations.localeOf(context).languageCode;
    // Keep the original MediaItems: selection/playback still uses the full
    // source queue, including when a search result is not its first item.
    final visible = _controller.audioList.where((item) {
      final chapter = item.extras?['chapterId'] as int?;
      return matchesCatalogSearch(_searchController.text, [
        item.title,
        if (chapter != null) ...[
          chapter.toString(),
          ...?_chapterCatalog?.searchNames(chapter, language),
        ],
      ]);
    }).toList();
    if (visible.isEmpty) {
      return Center(child: Text('surah_search_empty'.tr));
    }
    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: visible.length,
      itemBuilder: (context, index) => _buildAudioListItem(visible[index]),
    );
  }

  Widget _buildAudioListItem(MediaItem mediaItem) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.PADDING_SIZE_SMALL,
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: Theme.of(context).cardColor,
        child: ListTile(
          leading: CircleAvatar(
            backgroundImage: mediaItem.artUri != null
                ? NetworkImage(mediaItem.artUri.toString())
                : null,
          ),
          title: Text(
            _chapterCatalog?.localizedName(
                  mediaItem.extras?['chapterId'] as int? ?? 0,
                  Localizations.localeOf(context).languageCode,
                ) ??
                mediaItem.title,
            style: robotoMedium.copyWith(color: Theme.of(context).primaryColor),
          ),
          subtitle: Text(
            mediaItem.artist ?? 'unknown_artist_key'.tr,
            style: robotoMedium.copyWith(
              color: Theme.of(context).disabledColor,
            ),
          ),
          onTap: () => _controller.playMediaItem(mediaItem),
        ),
      ),
    );
  }

  Widget _buildBottomPlayerSection() {
    return Obx(() {
      final mediaItem = _controller.currentMediaItem.value;
      if (mediaItem == null) return const SizedBox.shrink();

      return GestureDetector(
        onTap: _showFullScreenBottomSheet,
        child: _buildBottomPlayer(mediaItem),
      );
    });
  }

  void _showFullScreenBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FullScreenBottomSheet(controller: _controller),
    );
  }

  Widget _buildBottomPlayer(MediaItem mediaItem) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.PADDING_SIZE_DEFAULT,
        vertical: Dimensions.PADDING_SIZE_SMALL,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.PADDING_SIZE_DEFAULT,
          vertical: Dimensions.PADDING_SIZE_SMALL,
        ),
        decoration: BoxDecoration(
          color: Get.isDarkMode
              ? Theme.of(context).cardColor.withOpacity(0.95)
              : Colors.white.withOpacity(0.97),
          borderRadius: BorderRadius.circular(
            Dimensions.RADIUS_EXTRA_LARGE + 10,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Album Art with Neumorphic Effect
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Get.isDarkMode
                        ? Colors.black.withOpacity(0.6)
                        : Colors.grey.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(4, 4),
                  ),
                  BoxShadow(
                    color: Get.isDarkMode
                        ? Colors.grey[800]!.withOpacity(0.4)
                        : Colors.white.withOpacity(0.8),
                    blurRadius: 10,
                    offset: const Offset(-4, -4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  width: 60,
                  height: 60,
                  color: Get.isDarkMode ? Colors.grey[850] : Colors.grey[100],
                  child: mediaItem.artUri != null
                      ? Image.network(
                          mediaItem.artUri.toString(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholderArt(),
                        )
                      : _buildPlaceholderArt(),
                ),
              ),
            ),

            const SizedBox(width: Dimensions.PADDING_SIZE_DEFAULT),

            // Media Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mediaItem.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: robotoMedium.copyWith(
                      fontSize: Dimensions.FONT_SIZE_LARGE,
                      fontWeight: FontWeight.w600,
                      color: Get.isDarkMode ? Colors.white : Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mediaItem.artist ?? 'unknown_artist_key'.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: robotoMedium.copyWith(
                      fontSize: Dimensions.FONT_SIZE_SMALL,
                      color: Get.isDarkMode
                          ? Colors.grey[400]
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Modern Controls
            _buildModernControlButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderArt() {
    return Center(
      child: Icon(
        Icons.music_note,
        size: 30,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildModernControlButtons() {
    return Obx(() {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Previous Button
            IconButton(
              icon: Icon(
                Icons.skip_previous_rounded,
                size: 28,
                color: Theme.of(context).primaryColor,
              ),
              onPressed: _controller.skipToPrevious,
            ),

            // Play/Pause Button
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: IconButton(
                icon: SvgPicture.asset(
                  _controller.isPlaying.value
                      ? Images.Pause_Icon
                      : Images.Play_Icon,
                  color: Colors.white,
                  width: 24,
                  height: 24,
                ),
                onPressed: _controller.togglePlayPause,
              ),
            ),

            // Next Button
            IconButton(
              icon: Icon(
                Icons.skip_next_rounded,
                size: 28,
                color: Theme.of(context).primaryColor,
              ),
              onPressed: _controller.skipToNext,
            ),
          ],
        ),
      );
    });
  }
}
