import 'package:zabi/helper/additional_reminder_plan.dart';
import 'package:zabi/helper/prayer_notification_preferences.dart';
import 'package:zabi/view/screens/notification/notification_settings_screen.dart';
import 'widget_prompt.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/controller/localization_controller.dart';
import 'package:zabi/helper/route_helper.dart';
import 'package:zabi/service/first_launch_setup_service.dart';
import 'package:zabi/util/app_constants.dart';
import 'package:zabi/util/dimensions.dart';
import 'package:zabi/util/images.dart';
import 'package:zabi/util/styles.dart';
import 'package:zabi/view/screens/location/background_location_screen.dart';

class FirstLaunchSetupScreen extends StatefulWidget {
  const FirstLaunchSetupScreen({super.key, this.soundPreview});

  final Future<void> Function(String assetPath)? soundPreview;

  @override
  State<FirstLaunchSetupScreen> createState() => _FirstLaunchSetupScreenState();
}

class _FirstLaunchSetupScreenState extends State<FirstLaunchSetupScreen> {
  final PageController _pageController = PageController();

  int _pageIndex = 0;
  bool _saving = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToSettings() async {
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _goBack() async {
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final preferences = await SharedPreferences.getInstance();
      await FirstLaunchSetupService(
        preferences,
      ).completeConfiguredNotifications();
      final notifications = await PrayerNotificationPreferences.load(
        preferences,
      );
      final extras = await AdditionalReminderPreferences.load(preferences);

      if (notifications.any((s) => s.enabled) || extras.any((s) => s.enabled)) {
        try {
          await FirstLaunchSetupService.requestNotificationPermission();
          await FirstLaunchSetupService.requestBatteryOptimizationExemption();
        } catch (_) {
          // A denied or unavailable system permission must not trap the user in
          // onboarding. It can be requested again from the app settings.
        }
      }

      if (mounted) await WidgetPrompt.showOnce(context, preferences);

      final nextRoute = await BackgroundLocationScreen.shouldShow()
          ? RouteHelper.backgroundLocation
          : RouteHelper.bottomNavbar;
      if (mounted) Get.offAllNamed(nextRoute);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimensions.PADDING_SIZE_LARGE,
                Dimensions.PADDING_SIZE_DEFAULT,
                Dimensions.PADDING_SIZE_LARGE,
                0,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: (_pageIndex + 1) / 2,
                  minHeight: 5,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
                  color: colorScheme.primary,
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _pageIndex = index),
                children: [
                  const _WelcomeStep(),
                  _NotificationSettingsStep(soundPreview: widget.soundPreview),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimensions.PADDING_SIZE_LARGE,
                Dimensions.PADDING_SIZE_SMALL,
                Dimensions.PADDING_SIZE_LARGE,
                Dimensions.PADDING_SIZE_LARGE,
              ),
              child: Row(
                children: [
                  if (_pageIndex > 0)
                    Expanded(
                      child: TextButton(
                        onPressed: _saving ? null : _goBack,
                        child: Text('onboarding_previous'.tr),
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: Dimensions.PADDING_SIZE_DEFAULT),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving
                          ? null
                          : (_pageIndex == 0 ? _goToSettings : _finish),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            Dimensions.RADIUS_DEFAULT,
                          ),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _pageIndex == 0
                                  ? 'onboarding_next'.tr
                                  : 'onboarding_finish'.tr,
                              style: robotoMedium,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LocalizationController>(
      builder: (controller) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(Dimensions.PADDING_SIZE_LARGE),
          child: Column(
            children: [
              const SizedBox(height: 36),
              Container(
                width: 132,
                height: 132,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                ),
                child: Image.asset(
                  Get.isDarkMode ? Images.Dark_APP_LOGO : Images.Light_APP_LOGO,
                ),
              ),
              const SizedBox(height: Dimensions.PADDING_SIZE_LARGE),
              Text(
                AppConstants.APP_NAME,
                style: robotoBold.copyWith(
                  fontSize: 30,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: Dimensions.PADDING_SIZE_LARGE),
              Text(
                'onboarding_welcome_title'.tr,
                textAlign: TextAlign.center,
                style: robotoBold.copyWith(fontSize: 24),
              ),
              const SizedBox(height: Dimensions.PADDING_SIZE_DEFAULT),
              Text(
                'onboarding_welcome_body'.tr,
                textAlign: TextAlign.center,
                style: robotoRegular.copyWith(
                  fontSize: Dimensions.FONT_SIZE_LARGE,
                  color: Theme.of(context).hintColor,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 36),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'onboarding_language_label'.tr,
                  style: robotoMedium.copyWith(
                    fontSize: Dimensions.FONT_SIZE_LARGE,
                  ),
                ),
              ),
              const SizedBox(height: Dimensions.PADDING_SIZE_SMALL),
              DropdownButtonFormField<int>(
                key: ValueKey(controller.selectedIndex),
                initialValue: controller.selectedIndex,
                isExpanded: true,
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.language,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      Dimensions.RADIUS_DEFAULT,
                    ),
                  ),
                ),
                items: List.generate(controller.languages.length, (index) {
                  final language = controller.languages[index];
                  return DropdownMenuItem<int>(
                    value: index,
                    child: Row(
                      children: [
                        Image.asset(language.imageUrl!, width: 24, height: 24),
                        const SizedBox(width: Dimensions.PADDING_SIZE_SMALL),
                        Flexible(child: Text(language.languageName!)),
                      ],
                    ),
                  );
                }),
                onChanged: (index) {
                  if (index == null) return;
                  final language = controller.languages[index];
                  controller.setLanguage(
                    Locale(language.languageCode!, language.countryCode),
                    index,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationSettingsStep extends StatelessWidget {
  const _NotificationSettingsStep({this.soundPreview});
  final Future<void> Function(String path)? soundPreview;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Dimensions.PADDING_SIZE_LARGE),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_active_outlined, size: 44, color: primary),
          const SizedBox(height: 16),
          Text(
            'onboarding_settings_title'.tr,
            style: robotoBold.copyWith(fontSize: 26, color: primary),
          ),
          const SizedBox(height: 12),
          Text(
            'onboarding_notification_categories_body'.tr,
            style: robotoRegular.copyWith(
              fontSize: Dimensions.FONT_SIZE_LARGE,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          NotificationSettingsMenu(soundPreview: soundPreview),
          const SizedBox(height: 24),
          Text(
            'onboarding_battery_note'.tr,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
