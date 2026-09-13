import 'package:zabi/view/screens/account/account_screen.dart';
import 'package:zabi/view/screens/reminders/daily_prayer_markers_screen.dart';
import 'package:zabi/view/screens/islamic_calendar/islamic_calendar_screen.dart';
import 'package:zabi/view/screens/prayer_share/prayer_share_screen.dart';
// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'widgets/prayer_widget_settings.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zabi/controller/quran_settings_controller.dart';
import 'package:zabi/util/dimensions.dart';
import 'package:zabi/util/images.dart';
import 'package:zabi/view/base/custom_app_bar.dart';
import 'package:zabi/view/base/custom_snackbar.dart';
import 'package:zabi/service/play_store_review_service.dart';
import 'package:zabi/view/screens/language/language_dw_widget.dart';
import 'package:zabi/view/screens/notification/notification_dw_widget.dart';
import 'package:zabi/view/screens/prayer_settings/prayer_calculation_settings.dart';
import 'package:zabi/view/screens/settings/widgets/home_layout_dw_widget.dart';
import 'package:zabi/view/screens/settings/widgets/item_widgets.dart';
import 'package:zabi/view/screens/settings/widgets/theme_mode_dw_widget.dart';

class SettingsScreen extends StatefulWidget {
  final bool appBackButton;
  const SettingsScreen({super.key, required this.appBackButton});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final Future<PackageInfo> _packageInfo;

  @override
  void initState() {
    super.initState();
    _packageInfo = PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Appbar start ===>
      appBar: CustomAppBar(
        title: 'settings'.tr,
        isBackButtonExist: widget.appBackButton == true ? true : false,
      ),

      body: GetBuilder<SettingsController>(
        builder: (settingsController) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.PADDING_SIZE_EXTRA_SMALL,
              ),
              child: Column(
                children: [
                  const SizedBox(height: Dimensions.PADDING_SIZE_EXTRA_SMALL),
                  const AccountSettingsCard(),
                  // Prayer Time Calculation Settings Section
                  const PrayerTimeCalculationSettings(),

                  // Notification section
                  const NofificationDWWidget(),
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.wb_twilight_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text('daily_markers_title'.tr),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Get.to(() => const DailyPrayerMarkersScreen()),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.calendar_month_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text('islamic_calendar_title'.tr),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Get.to(() => const IslamicCalendarScreen()),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.ios_share_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text('prayer_share_title'.tr),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Get.to(() => const PrayerShareScreen()),
                    ),
                  ),

                  // select language section
                  const LanguageDWWidget(),

                  // home screen layout (appearance) section
                  const ThemeModeDWWidget(),
                  const HomeLayoutDWWidget(),
                  if (Platform.isAndroid) const PrayerWidgetSettings(),

                  // share and rate app section  for android.
                  Platform.isAndroid
                      ? Column(
                          children: [
                            if (settingsController.mosqueSettingsApiData !=
                                    null &&
                                settingsController
                                        .mosqueSettingsApiData!
                                        .data !=
                                    null &&
                                settingsController
                                        .mosqueSettingsApiData!
                                        .data!
                                        .playStoreUrl !=
                                    null)
                              SettingsItem(
                                leadingIcon: Icons.share,
                                imagePath: Images.Icon_share_app,
                                title: 'share'.tr,
                                onTap: () async {
                                  final playStoreUrl = settingsController
                                      .mosqueSettingsApiData!
                                      .data!
                                      .playStoreUrl
                                      .toString();
                                  if (Uri.tryParse(playStoreUrl) != null) {
                                    await Share.share(playStoreUrl);
                                  } else {
                                    showCustomSnackBar(
                                      "invalid_URL".tr,
                                      isError: true,
                                    );
                                  }
                                },
                              ),
                            SettingsItem(
                              imagePath: Images.Icon_rate_app,
                              leadingIcon: Icons.rate_review,
                              title: 'rate_us'.tr,
                              onTap: () async {
                                final opened = await PlayStoreReviewService
                                    .instance
                                    .openStore();
                                if (!opened && mounted) {
                                  showCustomSnackBar(
                                    'review_store_unavailable'.tr,
                                    isError: true,
                                  );
                                }
                              },
                            ),
                          ],
                        )
                      : const SizedBox(),

                  // share and rate app section  for ios
                  Platform.isIOS
                      ? Column(
                          children: [
                            if (settingsController.mosqueSettingsApiData !=
                                    null &&
                                settingsController
                                        .mosqueSettingsApiData!
                                        .data !=
                                    null &&
                                settingsController
                                        .mosqueSettingsApiData!
                                        .data!
                                        .appStoreUrl !=
                                    null)
                              SettingsItem(
                                imagePath: Images.Icon_share_app,
                                leadingIcon: Icons.share,
                                title: 'share'.tr,
                                onTap: () async {
                                  final appStoreUrl = settingsController
                                      .mosqueSettingsApiData!
                                      .data!
                                      .appStoreUrl
                                      .toString();
                                  if (Uri.tryParse(appStoreUrl) != null) {
                                    await Share.share(appStoreUrl);
                                  } else {
                                    showCustomSnackBar(
                                      "invalid_URL".tr,
                                      isError: true,
                                    );
                                  }
                                },
                              ),
                            if (settingsController.mosqueSettingsApiData !=
                                    null &&
                                settingsController
                                        .mosqueSettingsApiData!
                                        .data !=
                                    null &&
                                settingsController
                                        .mosqueSettingsApiData!
                                        .data!
                                        .appStoreUrl !=
                                    null)
                              SettingsItem(
                                imagePath: Images.Icon_rate_app,
                                leadingIcon: Icons.rate_review,
                                title: 'rate_us'.tr,
                                onTap: () async {
                                  final appStoreUrl = settingsController
                                      .mosqueSettingsApiData!
                                      .data!
                                      .appStoreUrl
                                      .toString();
                                  if (Uri.tryParse(appStoreUrl) != null) {
                                    final url = Uri.parse(appStoreUrl);
                                    launchUrl(
                                      url,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  } else {
                                    showCustomSnackBar(
                                      "invalid_URL".tr,
                                      isError: true,
                                    );
                                  }
                                },
                              ),
                          ],
                        )
                      : const SizedBox(),

                  FutureBuilder<PackageInfo>(
                    future: _packageInfo,
                    builder: (context, snapshot) {
                      final packageInfo = snapshot.data;
                      final version = packageInfo == null
                          ? '…'
                          : 'version_number'.trParams({
                              'version': packageInfo.version,
                              'build': packageInfo.buildNumber,
                            });

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        color: Theme.of(context).cardColor,
                        shadowColor: Get.isDarkMode
                            ? Colors.grey[800]
                            : Colors.grey[200],
                        child: ListTile(
                          contentPadding: const EdgeInsetsDirectional.symmetric(
                            horizontal: Dimensions.PADDING_SIZE_DEFAULT,
                          ),
                          leading: Icon(
                            Icons.info_outline,
                            color: Theme.of(context).primaryColor,
                            size: 25,
                          ),
                          title: Text(
                            'about'.tr,
                            style: const TextStyle(
                              fontSize: Dimensions.FONT_SIZE_LARGE,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(version),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
