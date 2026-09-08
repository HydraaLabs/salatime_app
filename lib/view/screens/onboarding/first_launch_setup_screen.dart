import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/controller/localization_controller.dart';
import 'package:zabi/controller/noti_sound_controller.dart';
import 'package:zabi/controller/prayer_reminder_controller.dart';
import 'package:zabi/helper/route_helper.dart';
import 'package:zabi/service/first_launch_setup_service.dart';
import 'package:zabi/util/app_constants.dart';
import 'package:zabi/util/dimensions.dart';
import 'package:zabi/util/images.dart';
import 'package:zabi/util/styles.dart';
import 'package:zabi/view/screens/location/background_location_screen.dart';
import 'package:zabi/view/screens/notification/widgets/salat_waqt_repository.dart';

class FirstLaunchSetupScreen extends StatefulWidget {
  const FirstLaunchSetupScreen({super.key, this.soundPreview});

  final Future<void> Function(String assetPath)? soundPreview;

  @override
  State<FirstLaunchSetupScreen> createState() => _FirstLaunchSetupScreenState();
}

class _FirstLaunchSetupScreenState extends State<FirstLaunchSetupScreen> {
  final PageController _pageController = PageController();

  int _pageIndex = 0;
  bool _adhanEnabled = true;
  bool _beforeEnabled = true;
  bool _afterEnabled = true;
  int _beforeMinutes = AppConstants.DEFAULT_PRAYER_REMINDER_MINUTES;
  int _afterMinutes = AppConstants.DEFAULT_PRAYER_REMINDER_MINUTES;
  String _adhanSound = AppConstants.DEFAULT_NOTIFICATION_SOUND;
  bool _saving = false;
  AudioPlayer? _adhanPreviewPlayer;

  @override
  void initState() {
    super.initState();
    _loadSavedValues();
  }

  @override
  void dispose() {
    unawaited(_adhanPreviewPlayer?.dispose());
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _previewAdhanSound(String soundKey) async {
    final matches = NotiSoundController.availableSounds.where(
      (sound) => sound['key'] == soundKey && soundKey.startsWith('azan_'),
    );
    if (matches.isEmpty) return;

    final assetPath = matches.first['path']!;
    try {
      if (widget.soundPreview != null) {
        await widget.soundPreview!(assetPath);
        return;
      }
      final player = _adhanPreviewPlayer ??= AudioPlayer();
      await player.stop();
      await player.setAsset(assetPath);
      unawaited(player.play());
    } catch (_) {
      // Audio preview support must not block the first-launch setup.
    }
  }

  Future<void> _stopAdhanPreview() async {
    try {
      await _adhanPreviewPlayer?.stop();
    } catch (_) {
      // The audio backend may already have been released by the platform.
    }
  }

  Future<void> _loadSavedValues() async {
    final preferences = await SharedPreferences.getInstance();
    final prayers = await SalatWaqtRepository().getSalatWaqtList();
    if (!mounted) return;

    final savedSound = preferences.getString(
      AppConstants.SELECTED_NOTIFICATION_SOUND_KEY,
    );
    setState(() {
      if (prayers.isNotEmpty) {
        _adhanEnabled = prayers.any((prayer) => prayer.isNotificationEnabled);
      }
      _beforeEnabled =
          preferences.getBool(AppConstants.BEFORE_ADHAN_REMINDER_ENABLED_KEY) ??
          true;
      _afterEnabled =
          preferences.getBool(AppConstants.AFTER_ADHAN_REMINDER_ENABLED_KEY) ??
          true;
      _beforeMinutes = _validMinutes(
        preferences.getInt(AppConstants.BEFORE_ADHAN_REMINDER_MINUTES_KEY),
      );
      _afterMinutes = _validMinutes(
        preferences.getInt(AppConstants.AFTER_ADHAN_REMINDER_MINUTES_KEY),
      );
      if (NotiSoundController.availableSounds.any(
        (sound) => sound['key'] == savedSound,
      )) {
        _adhanSound = savedSound!;
      }
    });
  }

  int _validMinutes(int? minutes) {
    return PrayerReminderController.minuteOptions.contains(minutes)
        ? minutes!
        : AppConstants.DEFAULT_PRAYER_REMINDER_MINUTES;
  }

  Future<void> _goToSettings() async {
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _goBack() async {
    await _stopAdhanPreview();
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    if (_saving) return;
    await _stopAdhanPreview();
    setState(() => _saving = true);

    try {
      final preferences = await SharedPreferences.getInstance();
      await FirstLaunchSetupService(preferences).complete(
        adhanEnabled: _adhanEnabled,
        beforeEnabled: _beforeEnabled,
        afterEnabled: _afterEnabled,
        beforeMinutes: _beforeMinutes,
        afterMinutes: _afterMinutes,
        adhanSound: _adhanSound,
      );

      if (_adhanEnabled) {
        try {
          await FirstLaunchSetupService.requestNotificationPermission();
          await FirstLaunchSetupService.requestBatteryOptimizationExemption();
        } catch (_) {
          // A denied or unavailable system permission must not trap the user in
          // onboarding. It can be requested again from the app settings.
        }
      }

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
                children: const [_WelcomeStep(), _NotificationSettingsStep()],
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

class _NotificationSettingsStep extends StatefulWidget {
  const _NotificationSettingsStep();

  @override
  State<_NotificationSettingsStep> createState() =>
      _NotificationSettingsStepState();
}

class _NotificationSettingsStepState extends State<_NotificationSettingsStep> {
  _FirstLaunchSetupScreenState get parent =>
      context.findAncestorStateOfType<_FirstLaunchSetupScreenState>()!;

  @override
  Widget build(BuildContext context) {
    final settings = parent;
    final primary = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Dimensions.PADDING_SIZE_LARGE),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Dimensions.PADDING_SIZE_SMALL),
          Icon(Icons.notifications_active_outlined, size: 44, color: primary),
          const SizedBox(height: Dimensions.PADDING_SIZE_DEFAULT),
          Text(
            'onboarding_settings_title'.tr,
            style: robotoBold.copyWith(fontSize: 26, color: primary),
          ),
          const SizedBox(height: Dimensions.PADDING_SIZE_SMALL),
          Text(
            'onboarding_settings_body'.tr,
            style: robotoRegular.copyWith(
              fontSize: Dimensions.FONT_SIZE_LARGE,
              height: 1.45,
            ),
          ),
          const SizedBox(height: Dimensions.PADDING_SIZE_LARGE),
          Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile(
              value: settings._adhanEnabled,
              activeThumbColor: primary,
              title: Text('onboarding_enable_adhan'.tr, style: robotoMedium),
              subtitle: Text('onboarding_enable_adhan_description'.tr),
              secondary: Icon(Icons.mosque_outlined, color: primary),
              onChanged: (value) {
                settings.setState(() => settings._adhanEnabled = value);
                if (!value) unawaited(settings._stopAdhanPreview());
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: Dimensions.PADDING_SIZE_DEFAULT),
          _OnboardingReminderCard(
            title: 'before_adhan'.tr,
            description: 'before_adhan_description'.tr,
            dropdownLabel: 'minutes_before'.tr,
            enabled: settings._beforeEnabled,
            minutes: settings._beforeMinutes,
            adhanEnabled: settings._adhanEnabled,
            onEnabledChanged: (value) {
              settings.setState(() => settings._beforeEnabled = value);
              setState(() {});
            },
            onMinutesChanged: (value) {
              settings.setState(() => settings._beforeMinutes = value);
              setState(() {});
            },
          ),
          const SizedBox(height: Dimensions.PADDING_SIZE_DEFAULT),
          _OnboardingReminderCard(
            title: 'after_adhan'.tr,
            description: 'after_adhan_description'.tr,
            dropdownLabel: 'minutes_after'.tr,
            enabled: settings._afterEnabled,
            minutes: settings._afterMinutes,
            adhanEnabled: settings._adhanEnabled,
            onEnabledChanged: (value) {
              settings.setState(() => settings._afterEnabled = value);
              setState(() {});
            },
            onMinutesChanged: (value) {
              settings.setState(() => settings._afterMinutes = value);
              setState(() {});
            },
          ),
          const SizedBox(height: Dimensions.PADDING_SIZE_DEFAULT),
          DropdownButtonFormField<String>(
            key: ValueKey(settings._adhanSound),
            initialValue: settings._adhanSound,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'choose_sound_for_notification'.tr,
              prefixIcon: Icon(Icons.volume_up_outlined, color: primary),
              suffixIcon: IconButton(
                key: const Key('onboarding_adhan_preview_button'),
                tooltip: 'preview_sound'.tr,
                onPressed: settings._adhanEnabled
                    ? () => settings._previewAdhanSound(settings._adhanSound)
                    : null,
                icon: const Icon(Icons.play_circle_outline),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Dimensions.RADIUS_DEFAULT),
              ),
            ),
            items: NotiSoundController.availableSounds
                .where((sound) => sound['key']!.startsWith('azan_'))
                .map(
                  (sound) => DropdownMenuItem<String>(
                    value: sound['key'],
                    child: Text(sound['labelKey']!.tr),
                  ),
                )
                .toList(),
            onChanged: settings._adhanEnabled
                ? (value) {
                    if (value == null) return;
                    settings.setState(() => settings._adhanSound = value);
                    setState(() {});
                    unawaited(settings._previewAdhanSound(value));
                  }
                : null,
          ),
          const SizedBox(height: Dimensions.PADDING_SIZE_DEFAULT),
          Container(
            padding: const EdgeInsets.all(Dimensions.PADDING_SIZE_DEFAULT),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Dimensions.RADIUS_DEFAULT),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.battery_saver_outlined, color: primary),
                const SizedBox(width: Dimensions.PADDING_SIZE_SMALL),
                Expanded(
                  child: Text(
                    'onboarding_battery_note'.tr,
                    style: robotoRegular.copyWith(height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingReminderCard extends StatelessWidget {
  const _OnboardingReminderCard({
    required this.title,
    required this.description,
    required this.dropdownLabel,
    required this.enabled,
    required this.minutes,
    required this.adhanEnabled,
    required this.onEnabledChanged,
    required this.onMinutesChanged,
  });

  final String title;
  final String description;
  final String dropdownLabel;
  final bool enabled;
  final int minutes;
  final bool adhanEnabled;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onMinutesChanged;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          SwitchListTile(
            value: enabled && adhanEnabled,
            activeThumbColor: primary,
            title: Text(title, style: robotoMedium),
            subtitle: Text(description),
            onChanged: adhanEnabled ? onEnabledChanged : null,
          ),
          if (enabled && adhanEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimensions.PADDING_SIZE_DEFAULT,
                0,
                Dimensions.PADDING_SIZE_DEFAULT,
                Dimensions.PADDING_SIZE_DEFAULT,
              ),
              child: DropdownButtonFormField<int>(
                key: ValueKey(minutes),
                initialValue: minutes,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: dropdownLabel,
                  prefixIcon: Icon(Icons.schedule, color: primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      Dimensions.RADIUS_DEFAULT,
                    ),
                  ),
                ),
                items: PrayerReminderController.minuteOptions
                    .map(
                      (value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value ${'minutes'.tr}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) onMinutesChanged(value);
                },
              ),
            ),
        ],
      ),
    );
  }
}
