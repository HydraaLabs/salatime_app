// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:zabi/controller/quran_controller.dart';
import 'package:zabi/view/screens/reading/reading_progress_screen.dart';
import 'package:zabi/helper/route_helper.dart';
import 'package:zabi/util/dimensions.dart';
import 'package:zabi/util/images.dart';
import 'package:zabi/view/screens/quran/widget/quran_navigation_button.dart';
import 'package:zabi/view/screens/quran/widget/quran_translation_error.dart';
import 'package:zabi/view/base/custom_app_bar.dart';
import 'package:zabi/view/base/tabbar_button.dart';
import 'package:zabi/view/screens/quran/quran_settings_screen.dart';
import 'package:zabi/view/screens/quran/widget/arabic_quran_widget.dart';
import 'package:zabi/view/screens/quran/widget/ayah_translation_widget.dart';

class SuraDetaileScreen extends StatelessWidget {
  final bool appBackButton;
  final int? savedPage = int.tryParse(Get.arguments.toString());

  SuraDetaileScreen({super.key, required this.appBackButton});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<QuranController>(
      builder: (quranController) {
        final isLoading = quranController.isSuraDetaileLoading.value;
        final sura = quranController.suraDetaileApiData?.data?.chapter;

        return Scaffold(
          appBar: CustomAppBar(
            title: isLoading || sura == null
                ? "--"
                : "${sura.translatedName}\n${'quran_verse_count'.trParams({'count': sura.versesCount ?? ''})}",
            isBackButtonExist: appBackButton,
            actions: [
              IconButton(
                tooltip: 'reading_progress_title'.tr,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ReadingProgressScreen(),
                  ),
                ),
                icon: const Icon(Icons.insights_outlined),
              ),
              if (!isLoading)
                IconButton(
                  onPressed: () => openBottomSheet(context),
                  icon: SvgPicture.asset(
                    Images.Icon_Quran_Setting,
                    color: Get.isDarkMode
                        ? Theme.of(context).indicatorColor
                        : Theme.of(context).cardColor,
                    height: 28,
                  ),
                ),
            ],
          ),
          body: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                _buildTabBar(context),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : sura == null
                      ? QuranTranslationError(
                          onRetry: () => quranController.fetchSuraDetaileData(
                            suraId: quranController.suraNumber?.toString(),
                          ),
                        )
                      : TabBarView(
                          children: [
                            Center(
                              child: ArabicQuranWidget(pageNumber: savedPage),
                            ),
                            const Center(child: AyanTranslationWidget()),
                          ],
                        ),
                ),
                _buildNavigationButtons(context, quranController),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return TabBar(
      dividerColor: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.PADDING_SIZE_DEFAULT,
        vertical: Dimensions.PADDING_SIZE_EXTRA_SMALL,
      ),
      labelPadding: const EdgeInsets.symmetric(
        horizontal: Dimensions.PADDING_SIZE_EXTRA_SMALL,
      ),
      isScrollable: false,
      indicator: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(Dimensions.RADIUS_SMALL),
      ),
      tabs: [
        tabBarButton('arabic'.tr, context),
        tabBarButton('ayah_and_translation'.tr, context),
      ],
    );
  }

  Widget _buildNavigationButtons(
    BuildContext context,
    QuranController quranController,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 18),
      child: Row(
        children: [
          QuranNavigationButton(
            icon: Icons.chevron_left,
            label: 'previous_sura'.tr,
            isEnabled:
                !quranController.isSuraDetaileLoading.value &&
                (quranController.suraNumber ?? 1) > 1,
            onPressed: () {
              quranController.suraNumber =
                  (quranController.suraNumber ?? 1) - 1;
              quranController.fetchSuraDetaileData(
                suraId: quranController.suraNumber.toString(),
              );
              Get.toNamed(RouteHelper.suraDetaile, arguments: 0);
            },
          ),
          const SizedBox(width: 16),
          QuranNavigationButton(
            label: 'next_sura'.tr,
            icon: Icons.chevron_right,
            isLeftIcon: false,
            isEnabled:
                !quranController.isSuraDetaileLoading.value &&
                quranController.suraNumber != null &&
                quranController.suraNumber! < 114,
            onPressed: () {
              quranController.suraNumber =
                  (quranController.suraNumber ?? 1) + 1;
              quranController.fetchSuraDetaileData(
                suraId: quranController.suraNumber.toString(),
              );
              Get.toNamed(RouteHelper.suraDetaile, arguments: 0);
            },
          ),
        ],
      ),
    );
  }
}
