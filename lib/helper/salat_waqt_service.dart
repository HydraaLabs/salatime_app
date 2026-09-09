import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/controller/package_prayer_time_controller.dart';
import 'package:zabi/controller/prayer_time_adjustment.dart';
import 'package:zabi/helper/location_auto_update_service.dart';
import 'package:zabi/util/app_constants.dart';
import 'package:zabi/view/screens/notification/widgets/salat_waqt.dart';
import 'package:zabi/view/screens/notification/widgets/salat_waqt_repository.dart';

import 'adhan_notification_service_helper.dart';

class SalatWaqtService {
  static const int _beforeNotificationIdBase = 1000;
  static const int _afterNotificationIdBase = 2000;

  final SalatWaqtRepository _salatWaqtRepository;

  SalatWaqtService() : _salatWaqtRepository = SalatWaqtRepository();

  Future<DateTime?> getPrayerTimeByWaqt(SalatWaqt salatWaqt) async {
    return _getPrayerTime(salatWaqt);
  }

  Future<DateTime?> _getPrayerTime(SalatWaqt salatWaqt) async {
    final prefs = await SharedPreferences.getInstance();
    final isPrayerTme = prefs.getBool(AppConstants.isPrayerTme);
    final saveCityName = prefs.getString(AppConstants.saveCityName);

    // When automatic location update is enabled, always compute the adhan
    // from the current GPS position instead of a manually chosen city.
    final autoLocation =
        prefs.getBool(LocationAutoUpdateService.enabledKey) ?? false;

    await Get.find<PrayerTimeController>().fetchPrayerTime(
      reload: false,
      isManualPrayerTme: autoLocation ? false : (isPrayerTme ?? false),
      manualCity:
          saveCityName ??
          Get.find<PrayerTimeController>().currentAddress.toString(),
    );

    final autometicPrayerTime =
        Get.find<PrayerTimeController>().prayerTimeModel;

    if (autometicPrayerTime == null || autometicPrayerTime.data == null) {
      Get.log("Automatic prayer time data is null");
      return null;
    }

    // Get base prayer time from API
    DateTime baseTime;
    String prayerKey;
    Get.log(
      "Calculating time for ${salatWaqt.name} (ID: ${salatWaqt.id})\n ${autometicPrayerTime.data!.fajrStart}",
    );
    switch (salatWaqt.id) {
      case 1:
        baseTime = _parsePrayerTime(autometicPrayerTime.data!.fajrStart ?? "");
        prayerKey = 'fajr';
        break;
      case 2:
        baseTime = _parsePrayerTime(autometicPrayerTime.data!.zuhrStart ?? "");
        prayerKey = 'zuhr';
        break;
      case 3:
        baseTime = _parsePrayerTime(autometicPrayerTime.data!.asrStart ?? "");
        prayerKey = 'asr';
        break;
      case 4:
        baseTime = _parsePrayerTime(
          autometicPrayerTime.data!.maghribStart ?? "",
        );
        prayerKey = 'maghrib';
        break;
      case 5:
        baseTime = _parsePrayerTime(autometicPrayerTime.data!.ishaStart ?? "");
        prayerKey = 'isha';
        break;
      default:
        throw UnimplementedError("Invalid salatWaqt id: ${salatWaqt.id}");
    }

    // Apply user adjustments if any
    try {
      final adjustmentController = Get.find<PrayerTimeAdjustmentController>();
      final adjustedTime = adjustmentController.getAdjustedTime(
        prayerKey,
        baseTime,
      );
      Get.log(
        "Prayer: $prayerKey, Base: ${_formatTime(baseTime)}, Adjusted: ${_formatTime(adjustedTime)}",
      );
      return adjustedTime;
    } catch (e) {
      Get.log("Adjustment controller not found, using base time: $e");
      return baseTime;
    }
  }

  DateTime _parsePrayerTime(String time) {
    if (time.isEmpty) {
      throw const FormatException("Time string is empty");
    }

    final timeList = time.split(":");
    final hour = int.parse(timeList[0]);
    final min = int.parse(timeList[1]);
    return DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      hour,
      min,
    );
  }

  // Helper method to format time for logging
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> updateSalatWaqt() async {
    final salatWaqtList = await _salatWaqtRepository.getSalatWaqtList();

    for (final element in salatWaqtList) {
      try {
        element.time = (await getPrayerTimeByWaqt(element)) ?? element.time;
        await _salatWaqtRepository.saveSalatWaqt(element);
      } catch (e) {
        Get.log("Failed to update SalatWaqt ${element.id}: $e");
      }
    }
  }

  static Future<void> checkNotificationPermission() async {
    if (Platform.isAndroid || Platform.isIOS) {
      var status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    }
  }

  static Future<void> initializeSalatWaqt() async {
    await checkNotificationPermission();
    final adhanNotificationServices = AdhanNotificationServiceImpl();
    await adhanNotificationServices.initializeNotification();

    final salatWaqtRepository = SalatWaqtRepository();
    var salatWaqtList = await salatWaqtRepository.getSalatWaqtList();

    if (salatWaqtList.isEmpty) {
      await salatWaqtRepository.seedSalatWaqt();
    }

    // Initialize the adjustment controller BEFORE updating salat waqt
    try {
      Get.find<PrayerTimeAdjustmentController>();
    } catch (e) {
      Get.put(PrayerTimeAdjustmentController());
      await Get.find<PrayerTimeAdjustmentController>().init();
    }

    final salatWaqtService = SalatWaqtService();
    await salatWaqtService.updateSalatWaqt();

    final prefs = await SharedPreferences.getInstance();
    final beforeEnabled =
        prefs.getBool(AppConstants.BEFORE_ADHAN_REMINDER_ENABLED_KEY) ?? false;
    final afterEnabled =
        prefs.getBool(AppConstants.AFTER_ADHAN_REMINDER_ENABLED_KEY) ?? false;
    final beforeMinutes =
        (prefs.getInt(AppConstants.BEFORE_ADHAN_REMINDER_MINUTES_KEY) ??
                AppConstants.DEFAULT_PRAYER_REMINDER_MINUTES)
            .clamp(1, 60)
            .toInt();
    final afterMinutes =
        (prefs.getInt(AppConstants.AFTER_ADHAN_REMINDER_MINUTES_KEY) ??
                AppConstants.DEFAULT_PRAYER_REMINDER_MINUTES)
            .clamp(1, 60)
            .toInt();
    final beforeSound =
        prefs.getString(AppConstants.BEFORE_ADHAN_REMINDER_SOUND_KEY) ??
        AppConstants.DEFAULT_PRAYER_REMINDER_SOUND;
    final afterSound =
        prefs.getString(AppConstants.AFTER_ADHAN_REMINDER_SOUND_KEY) ??
        AppConstants.DEFAULT_PRAYER_REMINDER_SOUND;

    salatWaqtList = await salatWaqtRepository.getSalatWaqtList();
    for (final salatWaqt in salatWaqtList) {
      final beforeId = beforeNotificationId(salatWaqt.id);
      final afterId = afterNotificationId(salatWaqt.id);
      if (salatWaqt.isNotificationEnabled) {
        final time = salatWaqt.time.toLocal();
        final translatedPrayerName = salatWaqt.name.toLowerCase().tr;
        Get.log(
          'Notification for ${salatWaqt.name}: ${time.toIso8601String().split('T')[0]} => ${time.toIso8601String().split('T')[1]}',
        );

        await adhanNotificationServices.scheduleNotification(
          id: salatWaqt.id,
          title: translatedPrayerName,
          body:
              '${'time_for'.tr} ${salatWaqt.name} ${'started_at'.tr} ${DateFormat.jm().format(time)}',
          dateTime: time,
          payload: time.toIso8601String(),
        );

        if (beforeEnabled) {
          final reminderTime = reminderDateTime(
            time,
            beforeMinutes,
            before: true,
          );
          await adhanNotificationServices.scheduleNotification(
            id: beforeId,
            title: 'before_adhan'.tr,
            body: 'prayer_in_minutes'.trParams({
              'prayer': translatedPrayerName,
              'minutes': beforeMinutes.toString(),
            }),
            dateTime: reminderTime,
            payload: 'before:${salatWaqt.id}:${time.toIso8601String()}',
            sound: beforeSound,
            channel: 'before_adhan_$beforeSound',
          );
        } else {
          await adhanNotificationServices.cancelNotification(beforeId);
        }

        if (afterEnabled) {
          final reminderTime = reminderDateTime(
            time,
            afterMinutes,
            before: false,
          );
          await adhanNotificationServices.scheduleNotification(
            id: afterId,
            title: 'iqama_reminder_title'.tr,
            body: 'iqama_reminder_body'.trParams({
              'prayer': translatedPrayerName,
            }),
            dateTime: reminderTime,
            payload: 'after:${salatWaqt.id}:${time.toIso8601String()}',
            sound: afterSound,
            channel: 'after_adhan_$afterSound',
          );
        } else {
          await adhanNotificationServices.cancelNotification(afterId);
        }
      } else {
        await adhanNotificationServices.cancelNotification(salatWaqt.id);
        await adhanNotificationServices.cancelNotification(beforeId);
        await adhanNotificationServices.cancelNotification(afterId);
      }
    }
    await adhanNotificationServices.retireLegacyBadgeChannels();
  }

  static DateTime reminderDateTime(
    DateTime prayerTime,
    int minutes, {
    required bool before,
  }) {
    final offset = Duration(minutes: minutes);
    return before ? prayerTime.subtract(offset) : prayerTime.add(offset);
  }

  static int beforeNotificationId(int prayerId) =>
      _beforeNotificationIdBase + prayerId;

  static int afterNotificationId(int prayerId) =>
      _afterNotificationIdBase + prayerId;
}
