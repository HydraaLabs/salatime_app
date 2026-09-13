// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:zabi/view/screens/quran/widget/quran_reading_check.dart';
import 'package:zabi/view/screens/quran/widget/quran_reading_keys.dart';
import 'package:zabi/view/screens/quran/widget/quran_translation_source_card.dart';
import 'package:zabi/view/screens/quran/widget/quran_translation_text.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zabi/controller/offline_quran_controller.dart';
import 'package:zabi/util/app_constants.dart';
import 'package:zabi/util/dimensions.dart';
import 'package:zabi/util/images.dart';
import 'package:zabi/util/styles.dart';
import 'package:zabi/view/base/loading_indicator.dart';

import '../../../../controller/quran_settings_controller.dart';

class OfflineAyanTranslationWidget extends StatefulWidget {
  const OfflineAyanTranslationWidget({super.key});

  @override
  State<OfflineAyanTranslationWidget> createState() =>
      _OfflineAyanTranslationWidgetState();
}

class _OfflineAyanTranslationWidgetState
    extends State<OfflineAyanTranslationWidget> {
  final Map<int, GlobalKey> _verseKeys = {};
  @override
  Widget build(BuildContext context) {
    return GetBuilder<OfflineQuranController>(
      builder: (suraDetaileController) {
        if (suraDetaileController.translationError.value != null) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  suraDetaileController.translationError.value!.tr,
                  textAlign: TextAlign.center,
                ),
                TextButton.icon(
                  onPressed: () => suraDetaileController.refreshTranslation(),
                  icon: const Icon(Icons.refresh),
                  label: Text('quran_translation_retry'.tr),
                ),
              ],
            ),
          );
        }
        if (suraDetaileController.isSurahDetailsLoading.value ||
            suraDetaileController.suraDetailsApiData == null) {
          return const Center(child: LoadingIndicator());
        }

        // Wrap in SizedBox + SingleChildScrollView + Column
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // allow scroll
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.PADDING_SIZE_EXTRA_SMALL,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (suraDetaileController.suraDetailsApiData!.translationSource !=
                  null)
                QuranTranslationSourceCard(
                  source: suraDetaileController
                      .suraDetailsApiData!
                      .translationSource,
                ),
              // your existing Bismillah card code...
              if (suraDetaileController.suraDetailsApiData!.data!.chapter!.id !=
                      1 &&
                  suraDetaileController.suraDetailsApiData!.data!.chapter!.id !=
                      9)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.PADDING_SIZE_EXTRA_SMALL,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      color: Theme.of(context).cardColor,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SvgPicture.asset(
                          Images.Bismillah,
                          height: 50,
                          fit: BoxFit.fitHeight,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ),
                ),

              // Replace outer ListView.builder with Column
              Column(
                children: List.generate(
                  suraDetaileController
                      .suraDetailsApiData!
                      .data!
                      .chapterInfo!
                      .length,
                  (index) {
                    var apiData = suraDetaileController
                        .suraDetailsApiData!
                        .data!
                        .chapterInfo![index];
                    return Column(
                      children: [
                        // inner ListView.builder remains unchanged
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const ClampingScrollPhysics(),
                          itemCount: apiData.pageVerses!.length,
                          itemBuilder: (context, verseIndex) {
                            final verse = apiData.pageVerses![verseIndex];
                            int verseNumber = verse.versesNumber!;
                            // Create key for each verse
                            _verseKeys[verseNumber] = GlobalKey();
                            return SizedBox(
                              key: _verseKeys[verseNumber],
                              width: double.infinity,
                              child: Card(
                                clipBehavior: Clip.antiAlias,
                                color: Theme.of(context).cardColor,
                                shadowColor: Get.isDarkMode
                                    ? Colors.grey[800]!
                                    : Colors.grey[200]!,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    children: [
                                      // Arabic Ayah
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Obx(
                                          () => SelectableText(
                                            apiData
                                                .pageVerses![verseIndex]
                                                .arabicName
                                                .toString(),
                                            textDirection: TextDirection.rtl,
                                            textAlign: TextAlign.right,
                                            style: Get.find<SettingsController>()
                                                .selectedArabicFont
                                                .copyWith(
                                                  fontSize:
                                                      Get.find<
                                                            SettingsController
                                                          >()
                                                          .arabicFontSize
                                                          .value,
                                                  color: Theme.of(
                                                    context,
                                                  ).textTheme.bodyMedium!.color,
                                                ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                        height: Dimensions.PADDING_SIZE_SMALL,
                                      ),
                                      // Translation
                                      Obx(
                                        () => QuranTranslationText(
                                          text: verse.translatedName ?? '',
                                          footnotes: verse.translationFootnotes,
                                          languageCode: suraDetaileController
                                              .suraDetailsApiData!
                                              .translationSource
                                              ?.languageCode,
                                          style: robotoMedium.copyWith(
                                            fontSize:
                                                Get.find<SettingsController>()
                                                    .translateFontSize
                                                    .value,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                        height: Dimensions.PADDING_SIZE_SMALL,
                                      ),
                                      // end ayah row
                                      QuranReadingCheck(
                                        verseKeys: quranReadingKeys(
                                          int.tryParse(
                                                suraDetaileController
                                                        .suraDetailsApiData!
                                                        .data!
                                                        .chapter!
                                                        .serialNumber ??
                                                    '',
                                              ) ??
                                              suraDetaileController
                                                  .suraDetailsApiData!
                                                  .data!
                                                  .chapter!
                                                  .id,
                                          [verse],
                                        ),
                                        label: 'reading_quran_verse_read'.tr,
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              SvgPicture.asset(
                                                Images.Icon_End_Ayah,
                                                height: 45,
                                                fit: BoxFit.fill,
                                                color: Theme.of(
                                                  context,
                                                ).primaryColor,
                                              ),
                                              Text(
                                                apiData
                                                    .pageVerses![verseIndex]
                                                    .versesNumber
                                                    .toString(),
                                                style: robotoMedium.copyWith(
                                                  fontSize: Dimensions
                                                      .FONT_SIZE_SMALL,
                                                  color: Theme.of(
                                                    context,
                                                  ).textTheme.bodyMedium!.color,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Builder(
                                                builder: (buttonContext) {
                                                  return IconButton(
                                                    onPressed: () {
                                                      final box =
                                                          buttonContext
                                                                  .findRenderObject()
                                                              as RenderBox;

                                                      Share.share(
                                                        quranTranslationShareText(
                                                          reference:
                                                              '${suraDetaileController.suraDetailsApiData!.data!.chapter!.translatedName} ${suraDetaileController.suraDetailsApiData!.data!.chapter!.serialNumber ?? suraDetaileController.suraDetailsApiData!.data!.chapter!.id}:${verse.versesNumber}',
                                                          arabic:
                                                              verse
                                                                  .arabicName ??
                                                              '',
                                                          translation:
                                                              verse
                                                                  .translatedName ??
                                                              '',
                                                          footnotes: verse
                                                              .translationFootnotes,
                                                          source: suraDetaileController
                                                              .suraDetailsApiData!
                                                              .translationSource,
                                                          appName: AppConstants
                                                              .APP_NAME,
                                                        ),
                                                        sharePositionOrigin:
                                                            box.localToGlobal(
                                                              Offset.zero,
                                                            ) &
                                                            box.size,
                                                      );
                                                    },
                                                    icon: SvgPicture.asset(
                                                      Images.Icon_Share,
                                                      height: 28,
                                                      color: Theme.of(
                                                        context,
                                                      ).primaryColor,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(
                          height: Dimensions.PADDING_SIZE_EXTRA_SMALL,
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            apiData.pageNumber.toString(),
                            textAlign: TextAlign.justify,
                            style: robotoMedium.copyWith(
                              fontSize: Dimensions.FONT_SIZE_LARGE,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium!.color,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: Dimensions.PADDING_SIZE_EXTRA_SMALL,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
