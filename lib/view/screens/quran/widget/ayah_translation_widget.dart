// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'quran_reading_check.dart';
import 'quran_reading_keys.dart';
import 'quran_translation_source_card.dart';
import 'quran_translation_text.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zabi/controller/quran_controller.dart';
import 'package:zabi/controller/quran_settings_controller.dart';
import 'package:zabi/shimmer/all_shimmer_loder.dart';
import 'package:zabi/util/app_constants.dart';
import 'package:zabi/util/dimensions.dart';
import 'package:zabi/util/images.dart';
import 'package:zabi/util/styles.dart';

class AyanTranslationWidget extends StatelessWidget {
  const AyanTranslationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: GetBuilder<QuranController>(
        builder: (quranController) {
          if (quranController.translationError.value != null) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    quranController.translationError.value!.tr,
                    textAlign: TextAlign.center,
                  ),
                  TextButton.icon(
                    onPressed: () => quranController.refreshTranslation(),
                    icon: const Icon(Icons.refresh),
                    label: Text('quran_translation_retry'.tr),
                  ),
                ],
              ),
            );
          }
          if (quranController.isSuraDetaileLoading.value ||
              quranController.suraDetaileApiData == null) {
            return const Center(
              child: SingleChildScrollView(child: AyahTranslationShimmer()),
            );
          }

          final chapter = quranController.suraDetaileApiData!.data!.chapter!;
          final chapterInfo =
              quranController.suraDetaileApiData!.data!.chapterInfo!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (quranController.suraDetaileApiData!.translationSource != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: QuranTranslationSourceCard(
                    source:
                        quranController.suraDetaileApiData!.translationSource,
                  ),
                ),
              if (chapter.id != 1 && chapter.id != 9) _buildBismillah(context),
              ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.PADDING_SIZE_EXTRA_SMALL,
                ),
                itemCount: chapterInfo.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, chapterIndex) {
                  final chapterData = chapterInfo[chapterIndex];
                  return _buildChapterCardList(
                    context,
                    quranController,
                    chapterData,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBismillah(BuildContext context) {
    return Padding(
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
    );
  }

  Widget _buildChapterCardList(
    BuildContext context,
    QuranController controller,
    dynamic chapterData,
  ) {
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: chapterData.pageVerses!.length,
          itemBuilder: (context, verseIndex) {
            final verse = chapterData.pageVerses![verseIndex];
            return _buildVerseCard(context, controller, verse);
          },
        ),
        const SizedBox(height: Dimensions.PADDING_SIZE_EXTRA_SMALL),
        Text(
          chapterData.pageNumber.toString(),
          textAlign: TextAlign.center,
          style: robotoMedium.copyWith(
            fontSize: Dimensions.FONT_SIZE_LARGE,
            color: Theme.of(context).textTheme.bodyMedium!.color,
          ),
        ),
        const SizedBox(height: Dimensions.PADDING_SIZE_EXTRA_SMALL),
      ],
    );
  }

  Widget _buildVerseCard(
    BuildContext context,
    QuranController controller,
    dynamic verse,
  ) {
    final settings = Get.find<SettingsController>();

    return SizedBox(
      width: double.infinity,
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: Theme.of(context).cardColor,
        shadowColor: Get.isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Arabic Ayah
              Align(
                alignment: Alignment.centerRight,
                child: Obx(
                  () => SelectableText(
                    verse.arabicName.toString(),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: Get.find<SettingsController>().selectedArabicFont
                        .copyWith(
                          fontSize: settings.arabicFontSize.value,
                          color: Theme.of(context).textTheme.bodyMedium!.color,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: Dimensions.PADDING_SIZE_SMALL),

              // Transliteration, when it is supplied by the Arabic base text.
              if ((verse.transLiteration as String?)?.trim().isNotEmpty == true)
                Obx(
                  () => Container(
                    padding: const EdgeInsets.all(
                      Dimensions.PADDING_SIZE_EXTRA_SMALL,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).hintColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: SelectableText(
                      verse.transLiteration.toString(),
                      textAlign: TextAlign.justify,
                      style: robotoMedium.copyWith(
                        fontSize: settings.translateFontSize.value,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: Dimensions.PADDING_SIZE_SMALL),
              Divider(
                color: Theme.of(context).textTheme.bodyMedium!.color,
                height: 1,
              ),
              const SizedBox(height: Dimensions.PADDING_SIZE_SMALL),

              // Translation
              Obx(
                () => QuranTranslationText(
                  text: verse.translatedName ?? '',
                  footnotes: verse.translationFootnotes,
                  languageCode: controller
                      .suraDetaileApiData!
                      .translationSource
                      ?.languageCode,
                  style: robotoMedium.copyWith(
                    fontSize: settings.translateFontSize.value,
                  ),
                ),
              ),
              const SizedBox(height: Dimensions.PADDING_SIZE_SMALL),

              // Ayah number and Share button
              QuranReadingCheck(
                verseKeys: quranReadingKeys(
                  int.tryParse(
                        controller
                                .suraDetaileApiData!
                                .data!
                                .chapter!
                                .serialNumber ??
                            '',
                      ) ??
                      controller.suraDetaileApiData!.data!.chapter!.id,
                  [verse],
                ),
                label: 'reading_quran_verse_read'.tr,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildAyahNumber(context, verse.versesNumber),
                  Builder(
                    builder: (buttonContext) => IconButton(
                      onPressed: () {
                        final box =
                            buttonContext.findRenderObject() as RenderBox;
                        final chapter =
                            controller.suraDetaileApiData!.data!.chapter!;
                        Share.share(
                          quranTranslationShareText(
                            reference:
                                '${chapter.translatedName} ${chapter.serialNumber ?? chapter.id}:${verse.versesNumber}',
                            arabic: verse.arabicName ?? '',
                            translation: verse.translatedName ?? '',
                            footnotes: verse.translationFootnotes,
                            source: controller
                                .suraDetaileApiData!
                                .translationSource,
                            appName: AppConstants.APP_NAME,
                          ),
                          sharePositionOrigin:
                              box.localToGlobal(Offset.zero) & box.size,
                        );
                      },
                      icon: SvgPicture.asset(
                        Images.Icon_Share,
                        height: 28,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAyahNumber(BuildContext context, dynamic verseNumber) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SvgPicture.asset(
          Images.Icon_End_Ayah,
          height: 45,
          fit: BoxFit.fill,
          color: Theme.of(context).primaryColor,
        ),
        Text(
          verseNumber.toString(), // <- this line must be safe
          style: robotoMedium.copyWith(
            fontSize: Dimensions.FONT_SIZE_SMALL,
            color: Theme.of(context).textTheme.bodyMedium!.color,
          ),
        ),
      ],
    );
  }
}
