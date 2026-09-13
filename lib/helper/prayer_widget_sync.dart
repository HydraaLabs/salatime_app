import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:salatime/controller/package_prayer_time_controller.dart';
import 'package:salatime/controller/prayer_time_adjustment.dart';
import 'package:salatime/helper/local_prayer_calculator.dart';
import 'package:salatime/helper/prayer_alarm_health.dart';
import 'package:salatime/helper/prayer_alarm_plan.dart';
import 'package:salatime/helper/prayer_refresh_coordinator.dart';

/// Sends display data independently of notification permissions, sound setup,
/// alarm registration and cloud synchronization.
class PrayerWidgetSync {
  static final _coordinator = PrayerRefreshCoordinator(refresh: _refresh);

  static Future<void> refresh() => _coordinator.request(immediate: true);

  static Future<void> _refresh({
    required bool requestPermissions,
    required bool Function() isCurrent,
  }) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        !Get.isRegistered<PrayerTimeController>()) {
      return;
    }
    try {
      final controller = Get.find<PrayerTimeController>();
      // Uses saved coordinates/calendar only; never requests GPS or the network.
      await controller.refreshConfiguredPrayerTime();
      if (!isCurrent()) return;
      final zoneName = controller.prayerTimeZone;
      if (zoneName == null) return;
      LocalPrayerCalculator.initializeTimeZones();
      final zone = tz.getLocation(zoneName);
      final now = tz.TZDateTime.now(zone);
      final adjustments = <String, int>{};
      if (Get.isRegistered<PrayerTimeAdjustmentController>()) {
        final controller = Get.find<PrayerTimeAdjustmentController>();
        await controller.init();
        for (final key in [
          'fajr',
          'sunrise',
          'zuhr',
          'asr',
          'maghrib',
          'isha',
        ]) {
          adjustments[key] = controller.getAdjustmentMinutes(key) ?? 0;
        }
      }
      final prayers = <PrayerOccurrence>[];
      for (var offset = -1; offset < 30; offset++) {
        if (!isCurrent()) return;
        final day = await controller.getPrayerTimeForDate(
          tz.TZDateTime(zone, now.year, now.month, now.day + offset),
          allowNetwork: false,
        );
        if (day?.data == null) continue;
        final entries = PrayerOccurrence.fromDay(day!.data!, zone, adjustments);
        if (entries.length == 5) prayers.addAll(entries);
      }
      if (isCurrent()) await publish(controller, prayers, zoneName);
    } catch (error) {
      // Keep existing widget data; an optional display refresh must never block
      // onboarding or alarm scheduling.
      debugPrint('Prayer widget data unavailable: $error');
    }
  }

  static Future<void> publish(
    PrayerTimeController controller,
    List<PrayerOccurrence> prayers,
    String zoneName,
  ) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        prayers.isEmpty) {
      return;
    }
    try {
      await PrayerAlarmHealth.channel.invokeMethod<void>('updateWidget', {
        'prayers': jsonEncode(
          prayers
              .map(
                (p) => {
                  'at': p.time.millisecondsSinceEpoch,
                  'prayerId': p.prayerId,
                  'date': p.date,
                  'name': p.nameKey.tr,
                  'shortName': 'widget_prayer_${p.prayerId}'.tr,
                },
              )
              .toList(),
        ),
        'city': controller.isManualPrayerTime.value
            ? controller.saveAddress.value
            : controller.currentAddress.value,
        'nextLabel': 'next_prayer'.tr,
        'sinceLabel': 'time_since_prayer'.tr,
        'emptyLabel': 'widget_open_to_refresh'.tr,
        'locale': Get.locale?.toLanguageTag() ?? 'en',
        'timeZone': zoneName,
        'use24HourFormat': controller.is24HourFormat.value,
      });
    } on MissingPluginException {
      // Older binaries still receive the final full schedule update.
    } on PlatformException catch (error) {
      debugPrint('Prayer widget update failed: $error');
    }
  }
}
