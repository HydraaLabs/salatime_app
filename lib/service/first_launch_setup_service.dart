import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/controller/noti_sound_controller.dart';
import 'package:zabi/util/app_constants.dart';
import 'package:zabi/view/screens/notification/widgets/salat_waqt_repository.dart';

class FirstLaunchSetupService {
  FirstLaunchSetupService(this.preferences);

  final SharedPreferences preferences;

  bool get shouldShow =>
      !(preferences.getBool(AppConstants.FIRST_LAUNCH_SETUP_COMPLETE_KEY) ??
          false);

  Future<void> complete({
    required bool adhanEnabled,
    required bool beforeEnabled,
    required bool afterEnabled,
    required int beforeMinutes,
    required int afterMinutes,
    required String adhanSound,
    String beforeSound = AppConstants.DEFAULT_PRAYER_REMINDER_SOUND,
    String afterSound = AppConstants.DEFAULT_PRAYER_REMINDER_SOUND,
  }) async {
    final validBeforeMinutes = _validMinutes(beforeMinutes);
    final validAfterMinutes = _validMinutes(afterMinutes);
    final remindersCanRun = adhanEnabled;

    await preferences.setBool(
      AppConstants.BEFORE_ADHAN_REMINDER_ENABLED_KEY,
      remindersCanRun && beforeEnabled,
    );
    await preferences.setBool(
      AppConstants.AFTER_ADHAN_REMINDER_ENABLED_KEY,
      remindersCanRun && afterEnabled,
    );
    await preferences.setInt(
      AppConstants.BEFORE_ADHAN_REMINDER_MINUTES_KEY,
      validBeforeMinutes,
    );
    await preferences.setInt(
      AppConstants.AFTER_ADHAN_REMINDER_MINUTES_KEY,
      validAfterMinutes,
    );
    final validAdhanSound =
        NotiSoundController.availableSounds.any(
          (sound) =>
              sound['key'] == adhanSound && adhanSound.startsWith('azan_'),
        )
        ? adhanSound
        : AppConstants.DEFAULT_NOTIFICATION_SOUND;
    await preferences.setString(
      AppConstants.SELECTED_NOTIFICATION_SOUND_KEY,
      validAdhanSound,
    );

    for (final entry in {
      AppConstants.BEFORE_ADHAN_REMINDER_SOUND_KEY: beforeSound,
      AppConstants.AFTER_ADHAN_REMINDER_SOUND_KEY: afterSound,
    }.entries) {
      final validSound = NotiSoundController.availableSounds.any(
        (sound) => sound['key'] == entry.value,
      );
      await preferences.setString(
        entry.key,
        validSound ? entry.value : AppConstants.DEFAULT_PRAYER_REMINDER_SOUND,
      );
    }

    final repository = SalatWaqtRepository();
    var prayers = await repository.getSalatWaqtList();
    if (prayers.isEmpty) {
      await repository.seedSalatWaqt();
      prayers = await repository.getSalatWaqtList();
    }
    for (final prayer in prayers) {
      prayer.isNotificationEnabled = adhanEnabled;
      await repository.saveSalatWaqt(prayer);
    }

    await preferences.setBool(
      AppConstants.FIRST_LAUNCH_SETUP_COMPLETE_KEY,
      true,
    );
  }

  static Future<void> requestNotificationPermission() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  static Future<bool> requestBatteryOptimizationExemption() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    var status = await Permission.ignoreBatteryOptimizations.status;
    if (!status.isGranted) {
      status = await Permission.ignoreBatteryOptimizations.request();
    }
    return status.isGranted;
  }

  static int _validMinutes(int minutes) {
    return minutes.clamp(1, 60).toInt();
  }
}
