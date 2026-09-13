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
import 'package:salatime/controller/package_prayer_time_controller.dart';
import 'package:salatime/controller/prayer_time_adjustment.dart';
import 'package:salatime/helper/location_auto_update_service.dart';
import 'package:salatime/helper/additional_reminder_plan.dart';
import 'package:salatime/data/model/response/todays_prayer_time_model.dart';
import 'package:salatime/helper/prayer_alarm_plan.dart';
import 'package:salatime/helper/prayer_notification_preferences.dart';
import 'package:salatime/helper/prayer_refresh_coordinator.dart';
import 'package:salatime/helper/prayer_alarm_health.dart';
import 'package:salatime/helper/prayer_widget_sync.dart';
import 'package:salatime/util/app_constants.dart';
import 'package:salatime/view/screens/notification/widgets/salat_waqt_repository.dart';

import 'adhan_notification_service_helper.dart';

class SalatWaqtService {
  static const scheduleKey = 'prayer_alarm_schedule_v2';
  static const skippedKey = 'prayer_alarm_skipped_v2';
  static const inexactKey = 'prayer_alarm_inexact_v2';
  static const failedKey = 'prayer_alarm_failed_v2';
  static const testAlarmId = 1999000001;
  static const _native = PrayerAlarmHealth.channel;
  static final _refreshCoordinator = PrayerRefreshCoordinator(
    refresh: _runRefresh,
  );
  static Future<void>? _notificationPermission;

  /// Replan from saved preferences without opening any system permission dialog.
  /// Rapid edits share one pass; the returned future includes edits made in flight.
  static Future<void> requestRefresh() {
    unawaited(PrayerWidgetSync.refresh());
    return _refreshCoordinator.request();
  }

  static Future<void> initializeSalatWaqt({bool requestPermissions = true}) {
    unawaited(PrayerWidgetSync.refresh());
    return _refreshCoordinator.request(
      immediate: true,
      requestPermissions: requestPermissions,
    );
  }

  static Future<void> _runRefresh({
    required bool requestPermissions,
    required bool Function() isCurrent,
  }) async {
    try {
      await _refresh(
        requestPermissions: requestPermissions,
        isCurrent: isCurrent,
      );
      final prefs = await SharedPreferences.getInstance();
      if (isCurrent() && (prefs.getBool(failedKey) ?? false)) {
        throw StateError('Prayer alarms could not all be scheduled');
      }
    } catch (error, stack) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(failedKey, true);
      } catch (_) {
        // Report the scheduling failure even if persistent storage also failed.
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  static Future<void> checkNotificationPermission() {
    final active = _notificationPermission;
    if (active != null) return active;
    final completion = Completer<void>();
    _notificationPermission = completion.future;
    unawaited(() async {
      Object? failure;
      StackTrace? failureStack;
      try {
        if (Platform.isAndroid || Platform.isIOS) {
          if (!await Permission.notification.isGranted) {
            await Permission.notification.request();
          }
        }
      } catch (error, stack) {
        failure = error;
        failureStack = stack;
      }
      _notificationPermission = null;
      if (failure != null) {
        completion.completeError(failure, failureStack);
      } else {
        completion.complete();
      }
    }());
    return completion.future;
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

  static Future<DateTime> scheduleTestAdhan() async {
    final service = AdhanNotificationServiceImpl();
    await service.initializeNotification();
    await service.cancelNotification(testAlarmId);
    final at = DateTime.now().add(const Duration(minutes: 1));
    final saved = await service.scheduleNotification(
      id: testAlarmId,
      title: 'alarm_test_title'.tr,
      body: 'alarm_test_body'.tr,
      dateTime: at,
      payload: jsonEncode({
        'id': testAlarmId,
        'prayerId': 1,
        'at': at.millisecondsSinceEpoch,
        'prayerAt': at.millisecondsSinceEpoch,
        'kind': 'adhan',
        'test': true,
        'stopLabel': 'stop_adhan'.tr,
      }),
    );
    if (!saved || service.schedulingFailed) {
      await service.cancelNotification(testAlarmId);
      throw StateError('Test alarm could not be scheduled');
    }
    return at;
  }

  static Future<void> _refresh({
    required bool requestPermissions,
    required bool Function() isCurrent,
  }) async {
    if (!Get.isRegistered<PrayerTimeController>()) return;
    final service = AdhanNotificationServiceImpl();
    await service.initializeNotification(
      requestPermissions: requestPermissions,
    );
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
    if (requestPermissions) {
      await controller.fetchPrayerTime(
        reload: false,
        isManualPrayerTme:
            !automatic && (prefs.getBool(AppConstants.isPrayerTme) ?? false),
        manualCity: prefs.getString(AppConstants.saveCityName),
      );
    } else {
      await controller.refreshConfiguredPrayerTime();
    }
    if (!isCurrent()) return;
    final zoneName = controller.prayerTimeZone;
    if (zoneName == null) return;
    final zone = tz.getLocation(zoneName);
    final now = tz.TZDateTime.now(zone);
    final adjustments = <String, int>{};
    if (Get.isRegistered<PrayerTimeAdjustmentController>()) {
      final adjustment = Get.find<PrayerTimeAdjustmentController>();
      await adjustment.init();
      for (final key in ['fajr', 'sunrise', 'zuhr', 'asr', 'maghrib', 'isha']) {
        adjustments[key] = adjustment.getAdjustmentMinutes(key) ?? 0;
      }
    }
    final prayers = <PrayerOccurrence>[];
    final notificationPrayers = <PrayerOccurrence>[];
    final notificationSettings = await PrayerNotificationPreferences.load(
      prefs,
    );
    final days = <Data>[];
    final extraSettings = await AdditionalReminderPreferences.load(prefs);
    final coveredDates = <String>{};
    // Native alarms survive process death; refresh this rolling window on launch,
    // resume, midnight and location/settings changes. iOS has a 64-request limit.
    for (var offset = -1; offset < 30; offset++) {
      if (!isCurrent()) return;
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
      notificationPrayers.addAll(
        PrayerOccurrence.fromDay(
          model.data!,
          zone,
          adjustments,
          includeSunrise: true,
        ),
      );
      days.add(model.data!);
      coveredDates.add(model.data!.date!);
    }
    // Publish the newly calculated window before any slow alarm registrations.
    if (!isCurrent()) return;
    await PrayerWidgetSync.publish(controller, prayers, zoneName);
    final enabledIds = notificationSettings
        .where(
          (s) =>
              s.phase == PrayerNotificationPhase.adhan &&
              s.enabled &&
              s.prayer.legacyId <= 5,
        )
        .map((s) => s.prayer.legacyId)
        .toSet();
    final skipped = (prefs.getStringList(skippedKey) ?? []).where((key) {
      final date = DateTime.tryParse(key.split(':').first);
      return date != null &&
          !date.isBefore(DateTime(now.year, now.month, now.day - 1));
    }).toSet();
    await prefs.setStringList(skippedKey, skipped.toList());
    final pending = await service.getPendingNotifications();
    final pendingById = {for (final request in pending) request.id: request};
    final old = await readSchedule();
    List<Map<String, dynamic>> oldExtra;
    try {
      oldExtra =
          (jsonDecode(
                    prefs.getString(
                          AdditionalReminderPreferences.scheduleKey,
                        ) ??
                        '[]',
                  )
                  as List)
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
    } catch (_) {
      oldExtra = [];
    }
    // A corrupt restored manifest must never cancel another feature's alarm.
    bool managedEntry(Map<String, dynamic> entry) {
      final id = entry['id'];
      if (id is! int) return false;
      if (entry['kind'] == 'extra_reminder') {
        return id >= 20000000 &&
            id < 30000000 &&
            AdditionalReminderType.values.any(
              (type) => type.name == entry['type'],
            );
      }
      return id >= 10000000 &&
          id < 20000000 &&
          ['adhan', 'before', 'after'].contains(entry['kind']);
    }

    final oldById = {
      for (final entry in [...old, ...oldExtra])
        if (managedEntry(entry)) entry['id'] as int: entry,
    };
    bool isEnabled(Map<String, dynamic> entry) {
      if (entry['kind'] == 'extra_reminder') {
        return extraSettings.any(
          (item) => item.type.name == entry['type'] && item.enabled,
        );
      }
      try {
        final prayer = PrayerNotificationPrayer.fromLegacyId(
          entry['prayerId'] as int,
          date: DateTime.parse(entry['date']),
        );
        return !skipped.contains(entry['key']) &&
            notificationSettings.any(
              (setting) =>
                  setting.prayer == prayer &&
                  setting.phase.name == entry['kind'] &&
                  setting.enabled,
            );
      } catch (_) {
        return false;
      }
    }

    // Offline manual calendars may not cover a previously scheduled date. Reuse
    // its known prayer instant and offset to apply changed settings, never the
    // old reminder instant. Legacy manifests without an offset retain their time.
    final cachedPrayers = restoreUncoveredPrayerOccurrences(
      alarms: oldById.values
          .where((entry) => entry['kind'] != 'extra_reminder')
          .toList(),
      coveredDates: coveredDates,
      zone: zone,
      adjustments: adjustments,
    );
    notificationPrayers.addAll(cachedPrayers);
    final reconciledDates = {
      ...coveredDates,
      ...cachedPrayers.map((p) => p.date),
    };
    final protectedIds = pending
        .where((request) {
          final entry = oldById[request.id];
          return entry != null &&
              isEnabled(entry) &&
              entry['at'] is int &&
              (entry['at'] as int) > now.millisecondsSinceEpoch &&
              !(entry['kind'] == 'extra_reminder'
                      ? coveredDates
                      : reconciledDates)
                  .contains(entry['date']);
        })
        .map((item) => item.id)
        .toSet();
    final otherCount = pending
        .where(
          (p) =>
              !oldById.containsKey(p.id) &&
              (Platform.isIOS || !_isLegacyId(p.id)),
        )
        .length;
    final limit =
        (Platform.isIOS
                ? 60 - otherCount - protectedIds.length
                : 450 - otherCount - protectedIds.length)
            .clamp(0, 450);
    final prayerPlan = buildPrayerAlarmPlan(
      prayers: notificationPrayers,
      now: now,
      settings: notificationSettings,
      skippedPrayers: skipped,
      limit: 450,
    );
    final extraPlan = buildAdditionalReminderPlan(
      days: days,
      zone: zone,
      now: now,
      settings: extraSettings,
      adjustments: adjustments,
      hijriAdjustment: prefs.getInt('hijri_date_adjustment_v1') ?? 0,
    );
    // Reserve one shared platform budget and keep the nearest occurrences,
    // so extra reminders cannot starve prayers or exceed Samsung/iOS limits.
    final desiredIds = selectReminderAlarmIds(
      candidates: [
        for (final alarm in prayerPlan) (id: alarm.id, time: alarm.time),
        for (final alarm in extraPlan) (id: alarm.id, time: alarm.time),
      ],
      limit: limit,
    );
    final plan = prayerPlan.where((item) => desiredIds.contains(item.id));
    if (!isCurrent()) return;
    // Start with every known registration so a superseded partial pass can
    // checkpoint its cancellations/additions without losing untouched alarms.
    final retained = <int, Map<String, dynamic>>{
      for (final request in pending)
        if (oldById[request.id] != null) request.id: oldById[request.id]!,
    };
    Future<void> checkpoint() async {
      for (final (key, extra) in [
        (scheduleKey, false),
        (AdditionalReminderPreferences.scheduleKey, true),
      ]) {
        final saved = await prefs.setString(
          key,
          jsonEncode(
            retained.values
                .where((entry) => (entry['kind'] == 'extra_reminder') == extra)
                .toList(),
          ),
        );
        if (!saved) {
          throw StateError('Prayer alarm schedule could not be saved');
        }
      }
    }

    Future<bool> superseded() async {
      if (isCurrent()) return false;
      await checkpoint();
      return true;
    }

    for (final request in pending) {
      if (await superseded()) return;
      final entry = oldById[request.id];
      if (entry == null) continue;
      final obsolete =
          !isEnabled(entry) ||
          entry['at'] is! int ||
          (entry['at'] as int) <= now.millisecondsSinceEpoch ||
          ((entry['kind'] == 'extra_reminder' ? coveredDates : reconciledDates)
                  .contains(entry['date']) &&
              !desiredIds.contains(request.id));
      if (obsolete) {
        await service.cancelNotification(request.id);
        retained.remove(request.id);
      }
    }
    for (final alarm in plan) {
      if (await superseded()) return;
      final name = alarm.prayer.nameKey.tr;
      final sound = alarm.setting!.sound;
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
          'minutes': '${alarm.setting!.minutes}',
        }),
        PrayerAlarmKind.after => 'iqama_reminder_body'.trParams({
          'prayer': name,
        }),
      };
      final previous = retained[alarm.id];
      final payload = jsonEncode({
        ...alarm.toJson(),
        'stopLabel': 'stop_adhan'.tr,
      });
      final registered = pendingById[alarm.id];
      // The plugin rewrites its entire alarm cache for every zonedSchedule.
      // Keep identical registrations; the final native routing pass still
      // repairs AlarmManager registrations after a permission/device change.
      if (previous != null &&
          registered?.title == title &&
          registered?.body == body &&
          registered?.payload == payload) {
        continue;
      }
      if (previous != null &&
          (previous['sound'] != sound ||
              previous['at'] != alarm.time.millisecondsSinceEpoch)) {
        await service.cancelNotification(alarm.id);
        retained.remove(alarm.id);
      }
      final saved = await service.scheduleNotification(
        id: alarm.id,
        title: title,
        body: body,
        dateTime: alarm.time,
        payload: payload,
        sound: sound,
        channel:
            '${alarm.kind == PrayerAlarmKind.adhan ? '' : '${alarm.kind.name}_'}adhan_$sound',
      );
      if (saved) {
        retained[alarm.id] = {...alarm.toJson(), 'title': title, 'body': body};
      }
    }
    for (final alarm in extraPlan.where(
      (item) => desiredIds.contains(item.id),
    )) {
      if (await superseded()) return;
      final title = alarm.setting.titleKey.tr;
      final body = '${alarm.setting.titleKey}_body'.tr;
      final data = {...alarm.toJson(), 'sound': alarm.setting.sound};
      final payload = jsonEncode(data);
      final registered = pendingById[alarm.id];
      if (retained.containsKey(alarm.id) &&
          registered?.title == title &&
          registered?.body == body &&
          registered?.payload == payload) {
        continue;
      }
      final saved = await service.scheduleNotification(
        id: alarm.id,
        title: title,
        body: body,
        dateTime: alarm.time,
        payload: payload,
        sound: alarm.setting.sound,
        channel: 'extra_${alarm.setting.type.name}_${alarm.setting.sound}',
      );
      if (saved) {
        retained[alarm.id] = {...data, 'title': title, 'body': body};
      }
    }
    if (await superseded()) return;
    // Old releases used three IDs per prayer. Retire only after replacements
    // succeed, or immediately when the user explicitly disables that prayer.
    for (var id = 1; id <= 5; id++) {
      if (!enabledIds.contains(id) ||
          (notificationPrayers.isNotEmpty && !service.schedulingFailed)) {
        for (final oldId in [
          id,
          beforeNotificationId(id),
          afterNotificationId(id),
        ]) {
          if (pendingById.containsKey(oldId)) {
            await service.cancelNotification(oldId);
          }
        }
      }
    }
    await checkpoint();
    if (!isCurrent()) return;
    await prefs.setBool(inexactKey, service.usedInexactAlarms);
    await prefs.setBool(
      failedKey,
      service.schedulingFailed ||
          ((notificationSettings.any((item) => item.enabled) ||
                  extraSettings.any((item) => item.enabled)) &&
              notificationPrayers.isEmpty),
    );
    if (Platform.isAndroid && prayers.isEmpty && retained.isNotEmpty) {
      // An offline calendar may only have the prior alarm manifest available.
      // Re-arm its retained registrations without replacing the widget's data.
      try {
        final routed = await _native.invokeMapMethod<String, dynamic>('route');
        if (routed?['inexact'] == true) await prefs.setBool(inexactKey, true);
        if ((routed?['failed'] as int? ?? 0) > 0) {
          await prefs.setBool(failedKey, true);
        }
      } on MissingPluginException {
        // Older binaries keep their plugin registrations.
      } on PlatformException catch (error) {
        await prefs.setBool(failedKey, true);
        debugPrint('Cached prayer alarm routing failed: $error');
      }
    }
    if (prayers.isNotEmpty) {
      await service.retireLegacyBadgeChannels();
      for (final setting in settings) {
        final today = prayers
            .where(
              (p) =>
                  p.prayerId == setting.id &&
                  p.date == DateFormat('yyyy-MM-dd').format(now),
            )
            .firstOrNull;
        if (today != null) {
          setting.time = today.time;
          await repository.saveSalatWaqt(setting);
        }
      }
      if (Platform.isAndroid) {
        try {
          final routed = await _native.invokeMapMethod<String, dynamic>(
            'update',
            {
              'alarms': jsonEncode(
                retained.values
                    .where((entry) => entry['kind'] != 'extra_reminder')
                    .toList(),
              ),
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
              'missedTitle': 'missed_prayer_title'.tr,
              'missedBody': 'missed_prayer_body'.tr,
            },
          );
          if (routed?['inexact'] == true) await prefs.setBool(inexactKey, true);
          if ((routed?['failed'] as int? ?? 0) > 0) {
            await prefs.setBool(failedKey, true);
          }
        } on MissingPluginException {
          // Older native binaries can still run the Dart improvements.
        } on PlatformException catch (error) {
          await prefs.setBool(failedKey, true);
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
