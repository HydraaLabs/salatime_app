// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:salatime/controller/offline_quran_controller.dart';
import 'package:salatime/helper/catalog_search.dart';
import 'package:salatime/helper/quran_chapter_catalog.dart';
import 'package:salatime/util/dimensions.dart';
import 'package:salatime/util/images.dart';
import 'package:salatime/util/styles.dart';
import 'package:salatime/view/base/catalog_search_field.dart';
import 'package:salatime/view/screens/offline_quran/offline_surah_detail_screen.dart';
import '../../../../controller/quran_settings_controller.dart';
import '../../../base/loading_indicator.dart';

class OfflineSuraList extends StatefulWidget {
  const OfflineSuraList({super.key});

  @override
  State<OfflineSuraList> createState() => _OfflineSuraListState();
}

class _OfflineSuraListState extends State<OfflineSuraList> {
  final _searchController = TextEditingController();
  late final OfflineQuranController _controller;
  QuranChapterCatalog? _catalog;
  bool _catalogReady = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<OfflineQuranController>()
        ? Get.find<OfflineQuranController>()
        : Get.put(OfflineQuranController());
    if (_controller.surahList.isEmpty) _controller.loadSurahList();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    QuranChapterCatalog? catalog;
    try {
      catalog = await QuranChapterCatalog.load();
    } catch (_) {
      // The existing Arabic names and transliterations remain usable if a
      // local asset cannot be read; no network fallback is needed.
    }
    if (mounted) {
      setState(() {
        _catalog = catalog;
        _catalogReady = true;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = Get.locale?.languageCode ?? 'en';
    final settings = Get.find<SettingsController>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(Dimensions.PADDING_SIZE_SMALL),
          child: CatalogSearchField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            hintText: 'surah_search_hint'.tr,
            fieldKey: const ValueKey('offline-surah-search'),
          ),
        ),
        Expanded(
          child: Obx(() {
            if (_controller.isLoading.value || !_catalogReady) {
              return const Center(child: LoadingIndicator());
            }
            final surahs = _controller.surahList
                .where(
                  (sura) => matchesCatalogSearch(_query, [
                    '${sura.id}',
                    sura.arabicName,
                    sura.translateName,
                    ...?_catalog?.searchNames(sura.id, language),
                  ]),
                )
                .toList();
            if (surahs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(Dimensions.PADDING_SIZE_LARGE),
                  child: Text(
                    'surah_search_empty'.tr,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return ListView.builder(
              key: ValueKey('offline-surah-results:$_query'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.PADDING_SIZE_SMALL,
              ),
              itemCount: surahs.length,
              itemBuilder: (context, index) {
                final sura = surahs[index];
                final name =
                    _catalog?.localizedName(sura.id, language) ??
                    sura.translateName;

                return Card(
                  key: ValueKey('offline-surah-${sura.id}'),
                  clipBehavior: Clip.antiAlias,
                  color: Theme.of(context).cardColor,
                  shadowColor: Get.isDarkMode
                      ? Colors.grey[800]!
                      : Colors.grey[200]!,
                  child: InkWell(
                    onTap: () {
                      _controller.lastSurahNumber = sura.id;
                      Get.to(
                        () => OfflineSuraDetaileScreen(
                          appBackButton: true,
                          surahNumber: sura.id.toString(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        5,
                        12,
                        10,
                        12,
                      ),
                      child: Row(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SvgPicture.asset(
                                Images.Icon_Star,
                                height: 50,
                                fit: BoxFit.fill,
                                color: Theme.of(context).primaryColor,
                              ),
                              Text(
                                sura.id.toString(),
                                style: robotoMedium.copyWith(
                                  fontSize: Dimensions.FONT_SIZE_SMALL,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Obx(
                                  () => Text(
                                    name,
                                    style: language == 'ar'
                                        ? settings.selectedArabicFont.copyWith(
                                            fontSize:
                                                settings.arabicFontSize.value,
                                            color: Theme.of(
                                              context,
                                            ).textTheme.bodyLarge!.color,
                                          )
                                        : robotoMedium.copyWith(
                                            fontSize: settings
                                                .translateFontSize
                                                .value,
                                          ),
                                  ),
                                ),
                                if (name != sura.arabicName)
                                  Obx(
                                    () => Text(
                                      sura.arabicName,
                                      textDirection: TextDirection.rtl,
                                      style: settings.selectedArabicFont
                                          .copyWith(
                                            fontSize:
                                                settings.arabicFontSize.value,
                                            color: Theme.of(
                                              context,
                                            ).textTheme.bodyLarge!.color,
                                          ),
                                    ),
                                  ),
                                Obx(
                                  () => Text(
                                    [
                                      if (language != 'ar' &&
                                          name != sura.translateName)
                                        sura.translateName,
                                      'quran_verse_count'.trParams({
                                        'count': sura.versesCount,
                                      }),
                                    ].join(' · '),
                                    style: robotoMedium.copyWith(
                                      fontSize:
                                          settings.translateFontSize.value - 3,
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge!.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}
