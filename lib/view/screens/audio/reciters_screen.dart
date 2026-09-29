import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:salatime/controller/audio_player_controller.dart';
import 'package:salatime/data/model/response/reciters_model.dart' as reciters;
import 'package:salatime/helper/catalog_search.dart';
import 'package:salatime/helper/route_helper.dart';
import 'package:salatime/shimmer/all_shimmer_loder.dart';
import 'package:salatime/util/dimensions.dart';
import 'package:salatime/util/images.dart';
import 'package:salatime/util/styles.dart';
import 'package:salatime/view/base/catalog_search_field.dart';
import 'package:salatime/view/base/custom_app_bar.dart';

class ReciterScreen extends StatefulWidget {
  final bool? appBackButton;
  const ReciterScreen({super.key, this.appBackButton});

  @override
  State<ReciterScreen> createState() => _ReciterScreenState();
}

class _ReciterScreenState extends State<ReciterScreen> {
  late final AudioPlayerController _controller;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String? _language;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<AudioPlayerController>()
        ? Get.find<AudioPlayerController>()
        : Get.put(AudioPlayerController(apiClient: Get.find()));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    if (_language == language) return;
    _language = language;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.fetchReciterData();
    });
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
        title: 'all_reciters_key'.tr,
        isBackButtonExist: widget.appBackButton ?? false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Dimensions.PADDING_SIZE_SMALL),
            child: CatalogSearchField(
              controller: _searchController,
              fieldKey: const ValueKey('reciter_search'),
              hintText: 'reciter_search_hint'.tr,
              onChanged: (_) {
                if (_scrollController.hasClients) _scrollController.jumpTo(0);
                setState(() {});
              },
            ),
          ),
          Expanded(
            child: GetBuilder<AudioPlayerController>(
              autoRemove: false,
              builder: (controller) {
                final allReciters = controller.recitersListApiData?.data;
                if (allReciters == null) {
                  if (controller.hasReciterLoadError) {
                    return Center(child: _retryMessage('reciter_load_error'));
                  }
                  return const Center(child: DhuaShimmer());
                }
                final visible = allReciters
                    .where(
                      (reciter) => matchesCatalogSearch(
                        _searchController.text,
                        [reciter.name, reciter.arabicName],
                      ),
                    )
                    .toList();
                return Column(
                  children: [
                    if (controller.isRecitersLoading.value)
                      const LinearProgressIndicator(),
                    if (controller.hasReciterLoadError)
                      _retryMessage('reciter_load_error')
                    else if (controller.arabicReciterNamesUnavailable)
                      _retryMessage('reciter_arabic_names_unavailable'),
                    Expanded(
                      child: visible.isEmpty
                          ? Center(child: Text('reciter_search_empty'.tr))
                          : ListView.builder(
                              controller: _scrollController,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.symmetric(
                                horizontal: Dimensions.PADDING_SIZE_SMALL,
                              ),
                              itemCount: visible.length,
                              itemBuilder: (context, index) =>
                                  _reciterTile(visible[index]),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _retryMessage(String messageKey) => Padding(
    padding: const EdgeInsets.all(Dimensions.PADDING_SIZE_SMALL),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(messageKey.tr, textAlign: TextAlign.center),
        TextButton(
          onPressed: _controller.isRecitersLoading.value
              ? null
              : () => _controller.fetchReciterData(forceRefresh: true),
          child: Text('auth_retry'.tr),
        ),
      ],
    ),
  );

  Widget _reciterTile(reciters.Data reciter) {
    final arabicName = reciter.arabicName;
    return Card(
      key: ValueKey('reciter_${reciter.id}'),
      clipBehavior: Clip.antiAlias,
      color: Theme.of(context).cardColor,
      shadowColor: Get.isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.only(
          start: Dimensions.PADDING_SIZE_EXTRA_SMALL,
          end: Dimensions.PADDING_SIZE_SMALL,
        ),
        leading: CircleAvatar(
          backgroundImage: reciter.profilePicture != null
              ? NetworkImage(reciter.profilePicture!)
              : AssetImage(Images.Reciter_Person),
        ),
        title: Text(
          reciter.name ?? 'no_name_found_key'.tr,
          style: robotoMedium,
        ),
        subtitle: arabicName != null && arabicName != reciter.name
            ? Text(arabicName, textDirection: TextDirection.rtl)
            : null,
        onTap: () => _selectReciter(reciter),
      ),
    );
  }

  void _selectReciter(reciters.Data reciter) {
    FocusScope.of(context).unfocus();
    final moshafs = _controller.moshafListFor(reciter.id!);
    if (moshafs.length > 1) {
      Get.bottomSheet(
        Container(
          color: Theme.of(context).cardColor,
          padding: const EdgeInsets.all(Dimensions.PADDING_SIZE_DEFAULT),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: moshafs.length,
            itemBuilder: (context, i) => ListTile(
              leading: const Icon(Icons.library_music),
              title: Text(moshafs[i].name ?? '', style: robotoMedium),
              onTap: () {
                _controller.selectedMoshaf = moshafs[i];
                Get.back();
                Get.toNamed(RouteHelper.audioList, arguments: reciter.id);
              },
            ),
          ),
        ),
      );
    } else {
      _controller.selectedMoshaf = moshafs.isNotEmpty ? moshafs.first : null;
      Get.toNamed(RouteHelper.audioList, arguments: reciter.id);
    }
  }
}
