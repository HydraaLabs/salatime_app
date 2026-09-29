// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:salatime/controller/quran_controller.dart';
import 'package:salatime/controller/quran_settings_controller.dart';
import 'package:salatime/data/model/response/sura_list_model.dart' as sura;
import 'package:salatime/helper/catalog_search.dart';
import 'package:salatime/helper/quran_chapter_catalog.dart';
import 'package:salatime/helper/route_helper.dart';
import 'package:salatime/shimmer/all_shimmer_loder.dart';
import 'package:salatime/util/dimensions.dart';
import 'package:salatime/util/images.dart';
import 'package:salatime/util/styles.dart';
import 'package:salatime/view/base/catalog_search_field.dart';

class SuraListWidget extends StatefulWidget {
  const SuraListWidget({super.key});

  @override
  State<SuraListWidget> createState() => _SuraListWidgetState();
}

class _SuraListWidgetState extends State<SuraListWidget> {
  final _search = TextEditingController();
  late final QuranController _controller = Get.find<QuranController>();
  QuranChapterCatalog? _catalog;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load() async {
    if (!_loading) setState(() => _loading = true);
    try {
      await Future.wait([
        _controller.fetchSuraListData(),
        QuranChapterCatalog.load().then((value) => _catalog = value),
      ]);
    } catch (_) {
      // Existing names remain searchable if the optional alias asset fails.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = Get.locale?.languageCode ?? 'en';
    return GetBuilder<QuranController>(
      autoRemove: false,
      builder: (controller) {
        final all = controller.suraListApiData?.data ?? <sura.Data>[];
        final matches = all
            .where(
              (item) => matchesCatalogSearch(_search.text, [
                item.translateName,
                item.arabicName,
                item.serialNumber,
                item.id?.toString(),
                ...?_catalog?.searchNames(item.id ?? 0, language),
              ]),
            )
            .toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(Dimensions.PADDING_SIZE_SMALL),
              child: CatalogSearchField(
                controller: _search,
                fieldKey: const ValueKey('surah-catalog-search'),
                hintText: 'surah_search_hint'.tr,
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: _loading || controller.isSuraListLoading.value
                  ? const Center(child: QuranListShimmer())
                  : all.isEmpty
                  ? Center(
                      child: TextButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: Text('athkar_retry'.tr),
                      ),
                    )
                  : matches.isEmpty
                  ? Center(child: Text('surah_search_empty'.tr))
                  : ListView.builder(
                      key: ValueKey('surah-results:${_search.text}'),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.PADDING_SIZE_SMALL,
                      ),
                      itemCount: matches.length,
                      itemBuilder: (context, index) =>
                          _tile(matches[index], language),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _tile(sura.Data data, String language) {
    final settings = Get.find<SettingsController>();
    final name =
        _catalog?.localizedName(data.id ?? 0, language) ??
        data.translateName ??
        data.arabicName ??
        '';
    final sameArabicName =
        normalizeCatalogSearch(name) ==
        normalizeCatalogSearch(data.arabicName ?? '');
    return Card(
      key: ValueKey('surah-result-${data.id}'),
      clipBehavior: Clip.antiAlias,
      color: Theme.of(context).cardColor,
      shadowColor: Get.isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
      child: ListTile(
        onTap: () {
          FocusScope.of(context).unfocus();
          _controller.suraNumber = data.id;
          unawaited(_controller.fetchSuraDetaileData(suraId: '${data.id}'));
          Get.toNamed(RouteHelper.suraDetaile, arguments: 0);
        },
        contentPadding: const EdgeInsetsDirectional.only(
          start: Dimensions.PADDING_SIZE_EXTRA_SMALL,
          end: Dimensions.PADDING_SIZE_SMALL,
        ),
        leading: Stack(
          alignment: Alignment.center,
          children: [
            SvgPicture.asset(
              Images.Icon_Star,
              height: 50,
              fit: BoxFit.fill,
              color: Theme.of(context).primaryColor,
            ),
            Text(
              data.serialNumber ?? '${data.id ?? ''}',
              style: robotoMedium.copyWith(
                fontSize: Dimensions.FONT_SIZE_SMALL,
                color: Theme.of(context).textTheme.bodyMedium!.color,
              ),
            ),
          ],
        ),
        title: Obx(
          () => Text(
            name,
            style: language == 'ar'
                ? settings.selectedArabicFont.copyWith(
                    fontSize: settings.arabicFontSize.value,
                  )
                : robotoMedium.copyWith(
                    fontSize: settings.translateFontSize.value,
                  ),
          ),
        ),
        subtitle: Obx(
          () => Text(
            'quran_verse_count'.trParams({'count': data.versesCount ?? ''}),
            style: robotoMedium.copyWith(
              fontSize: settings.translateFontSize.value - 3,
              color: Theme.of(context).textTheme.bodyLarge!.color,
            ),
          ),
        ),
        trailing: sameArabicName
            ? null
            : ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * .3,
                ),
                child: Obx(
                  () => Text(
                    data.arabicName ?? '',
                    textDirection: TextDirection.rtl,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: settings.selectedArabicFont.copyWith(
                      fontSize: settings.arabicFontSize.value,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
