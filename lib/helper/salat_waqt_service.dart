import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zabi/controller/package_prayer_time_controller.dart';
import 'package:zabi/controller/prayer_time_adjustment.dart';
import 'package:zabi/helper/location_auto_update_service.dart';
import 'package:zabi/helper/prayer_alarm_plan.dart';
import 'package:zabi/util/app_constants.dart';
import 'package:zabi/view/screens/notification/widgets/salat_waqt_repository.dart';

import 'adhan_notification_service_helper.dart';

class SalatWaqtService {
  static const scheduleKey = 'prayer_alarm_schedule_v2';
  static const skippedKey = 'prayer_alarm_skipped_v2';
  static const inexactKey = 'prayer_alarm_inexact_v2';
  static const failedKey = 'prayer_alarm_failed_v2';
  static const _native = MethodChannel('net.salatime.app/prayer_schedule');
  static Future<void> _queue = Future.value();

  // Serialize refreshes: changing a setting during GPS/scheduling work must not
  // leave the older request's alarms armed after the newer one finishes.
  static Future<void> initializeSalatWaqt() {
    final next = _queue.then((_) => _refresh());
    _queue = next.catchError((Object error) {
      debugPrint('Prayer scheduling failed: $error');
    });
    return next;
  }

  static Future<void> checkNotificationPermission() async {
    if (Platform.isAndroid || Platform.isIOS) {
      if (!await Permission.notification.isGranted) {
        await Permission.notification.request();
      }
    }
  }

  static Future<List<Map<String, dynamic>>> readSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      return (jsonDecode(prefs.getString(scheduleKey) ?? '[]') as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> skipPrayer(String key, bool skip) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = (prefs.getStringList(skippedKey) ?? []).toSet();
    if (skip) {
      keys.add(key);
    } else {
      keys.remove(key);
    }
    await prefs.setStringList(skippedKey, keys.toList());
    await initializeSalatWaqt();
  }

  static Future<void> _refresh() async {
    if (!Get.isRegistered<PrayerTimeController>()) return;
    final service = AdhanNotificationServiceImpl();
    await service.initializeNotification();
    final prefs = await SharedPreferences.getInstance();
    final repository = SalatWaqtRepository();
    var settings = await repository.getSalatWaqtList();
    if (settings.isEmpty) {
      await repository.seedSalatWaqt();
      settings = await repository.getSalatWaqtList();
    }
    final controller = Get.find<PrayerTimeController>();
    final automatic =
        prefs.getBool(LocationAutoUpdateService.enabledKey) ?? false;
    await controller.fetchPrayerTime(
      reload: false,
      isManualPrayerTme:
          !automatic && (prefs.getBool(AppConstants.isPrayerTme) ?? false),
      manualCity: prefs.getString(AppConstants.saveCityName),
    );
    final zoneName = controller.prayerTimeZone;
    if (zoneName == null) return;
    final zone = tz.getLocation(zoneName);
    final now = tz.TZDateTime.now(zone);
    final adjustments = <String, int>{};
    if (Get.isRegistered<PrayerTimeAdjustmentController>()) {
      final adjustment = Get.find<PrayerTimeAdjustmentController>();
      await adjustment.init();
      for (final key in ['fajr', 'zuhr', 'asr', 'maghrib', 'isha']) {
        adjustments[key] = adjustment.getAdjustmentMinutes(key) ?? 0;
      }
    }
    final prayers = <PrayerOccurrence>[];
    final coveredDates = <String>{};
    // Native alarms survive process death; refresh this rolling window on launch,
    // resume, midnight and location/settings changes. iOS has a 64-request limit.
    for (var offset = 0; offset < 30; offset++) {
      final date = tz.TZDateTime(zone, now.year, now.month, now.day + offset);
      final model = await controller.getPrayerTimeForDate(
        date,
        allowNetwork: false,
      );
      if (model?.data == null) continue;
      final occurrences = PrayerOccurrence.fromDay(
        model!.data!,
        zone,
        adjustments,
      );
      if (occurrences.length != 5) continue;
      prayers.addAll(occurrences);
      coveredDates.add(model.data!.date!);
    }
    final enabledIds = settings
        .where((p) => p.isNotificationEnabled)
        .map((p) => p.id)
        .toSet();
    final skipped = (prefs.getStringList(skippedKey) ?? []).where((key) {
      final date = DateTime.tryParse(key.split(':').first);
      return date != null &&
          !date.isBefore(DateTime(now.year, now.month, now.day - 1));
    }).toSet();
    await prefs.setStringList(skippedKey, skipped.toList());
    final before =
        (prefs.getBool(AppConstants.BEFORE_ADHAN_REMINDER_ENABLED_KEY) ?? false)
        ? (prefs.getInt(AppConstants.BEFORE_ADHAN_REMINDER_MINUTES_KEY) ??
                  AppConstants.DEFAULT_PRAYER_REMINDER_MINUTES)
              .clamp(1, 60)
        : null;
    final after =
        (prefs.getBool(AppConstants.AFTER_ADHAN_REMINDER_ENABLED_KEY) ?? false)
        ? (prefs.getInt(AppConstants.AFTER_ADHAN_REMINDER_MINUTES_KEY) ??
                  AppConstants.DEFAULT_PRAYER_REMINDER_MINUTES)
              .clamp(1, 60)
        : null;
    final pending = await service.getPendingNotifications();
    final old = await readSchedule();
    final oldById = {for (final entry in old) entry['id'] as int: entry};
    final otherCount = pending
        .where((p) => !oldById.containsKey(p.id) && !_isLegacyId(p.id))
        .length;
    final limit = (Platform.isIOS ? 60 - otherCount : 450 - otherCount).clamp(
      0,
      450,
    );
    final plan = buildPrayerAlarmPlan(
      prayers: prayers,
      now: now,
      enabledPrayerIds: enabledIds,
      skippedPrayers: skipped,
      beforeMinutes: before,
      afterMinutes: after,
      limit: limit,
    );
    final desiredIds = plan.map((p) => p.id).toSet();
    final retained = <int, Map<String, dynamic>>{};
    for (final request in pending) {
      final entry = oldById[request.id];
      if (entry == null) continue;
      final obsolete =
          !enabledIds.contains(entry['prayerId']) ||
          skipped.contains(entry['key']) ||
          (entry['at'] as int) <= now.millisecondsSinceEpoch ||
          (coveredDates.contains(entry['date']) &&
              !desiredIds.contains(request.id));
      if (obsolete) {
        await service.cancelNotification(request.id);
      } else {
        retained[request.id] = entry;
      }
    }
    for (final alarm in plan) {
      final name = alarm.prayer.nameKey.tr;
      final sound = switch (alarm.kind) {
        PrayerAlarmKind.adhan =>
          prefs.getString(AppConstants.SELECTED_NOTIFICATION_SOUND_KEY) ??
              AppConstants.DEFAULT_NOTIFICATION_SOUND,
        PrayerAlarmKind.before =>
          prefs.getString(AppConstants.BEFORE_ADHAN_REMINDER_SOUND_KEY) ??
              AppConstants.DEFAULT_PRAYER_REMINDER_SOUND,
        PrayerAlarmKind.after =>
          prefs.getString(AppConstants.AFTER_ADHAN_REMINDER_SOUND_KEY) ??
              AppConstants.DEFAULT_PRAYER_REMINDER_SOUND,
      };
      final title = switch (alarm.kind) {
        PrayerAlarmKind.adhan => name,
        PrayerAlarmKind.before => 'before_adhan'.tr,
        PrayerAlarmKind.after => 'iqama_reminder_title'.tr,
      };
      final body = switch (alarm.kind) {
        PrayerAlarmKind.adhan =>
          '${'time_for'.tr} $name ${'started_at'.tr} ${DateFormat.Hm().format(alarm.prayer.time)}',
        PrayerAlarmKind.before => 'prayer_in_minutes'.trParams({
          'prayer': name,
          'minutes': '$before',
        }),
        PrayerAlarmKind.after => 'iqama_reminder_body'.trParams({
          'prayer': name,
        }),
      };
      final saved = await service.scheduleNotification(
        id: alarm.id,
        title: title,
        body: body,
        dateTime: alarm.time,
        payload: jsonEncode(alarm.toJson()),
        sound: sound,
        channel:
            '${alarm.kind == PrayerAlarmKind.adhan ? '' : '${alarm.kind.name}_'}adhan_$sound',
      );
      if (saved) {
        retained[alarm.id] = {...alarm.toJson(), 'title': title, 'body': body};
      }
    }
    // Old releases used three IDs per prayer. Retire only after replacements
    // succeed, or immediately when the user explicitly disables that prayer.
    for (var id = 1; id <= 5; id++) {
      if (!enabledIds.contains(id) ||
          (prayers.isNotEmpty && !service.schedulingFailed)) {
        for (final oldId in [
          id,
          beforeNotificationId(id),
          afterNotificationId(id),
        ]) {
          await service.cancelNotification(oldId);
        }
      }
    }
    await prefs.setString(scheduleKey, jsonEncode(retained.values.toList()));
    await prefs.setBool(inexactKey, service.usedInexactAlarms);
    await prefs.setBool(
      failedKey,
      service.schedulingFailed || (enabledIds.isNotEmpty && prayers.isEmpty),
    );
    if (prayers.isNotEmpty) {
      await service.retireLegacyBadgeChannels();
      for (final setting in settings) {
        final today = prayers
            .where((p) => p.prayerId == setting.id)
            .firstOrNull;
        if (today != null) {
          setting.time = today.time;
          await repository.saveSalatWaqt(setting);
        }
      }
      if (Platform.isAndroid) {
        try {
          await _native.invokeMethod<void>('update', {
            'alarms': jsonEncode(retained.values.toList()),
            'prayers': jsonEncode(
              prayers
                  .map(
                    (p) => {
                      'at': p.time.millisecondsSinceEpoch,
                      'name': p.nameKey.tr,
                    },
                  )
                  .toList(),
            ),
            'city': controller.isManualPrayerTime.value
                ? controller.saveAddress.value
                : controller.currentAddress.value,
            'nextLabel': 'next_prayer'.tr,
            'emptyLabel': 'widget_open_to_refresh'.tr,
            'missedTitle': 'missed_prayer_title'.tr,
            'missedBody': 'missed_prayer_body'.tr,
          });
        } on MissingPluginException {
          // Older native binaries can still run the Dart improvements.
        } on PlatformException catch (error) {
          debugPrint('Prayer widget refresh failed: $error');
        }
      }
    }
  }

  static bool _isLegacyId(int id) =>
      (id >= 1 && id <= 5) ||
      (id >= 1001 && id <= 1005) ||
      (id >= 2001 && id <= 2005);

  static DateTime reminderDateTime(
    DateTime prayerTime,
    int minutes, {
    required bool before,
  }) => prayerTime.add(Duration(minutes: before ? -minutes : minutes));
  static int beforeNotificationId(int prayerId) => 1000 + prayerId;
  static int afterNotificationId(int prayerId) => 2000 + prayerId;
}
