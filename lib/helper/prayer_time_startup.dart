import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:salatime/controller/package_prayer_time_controller.dart';
import 'package:salatime/controller/prayer_time_adjustment.dart';

/// Prepare today's display before opening home, using saved configuration only.
/// Live location and network refreshes run afterwards, without hiding this data.
class PrayerTimeStartup {
  static Future<void> restore() async {
    try {
      final controller = Get.find<PrayerTimeController>();
      await Get.find<PrayerTimeAdjustmentController>().init();
      await controller.loadSwitchValue();
      // Recalculate for today and the current timezone; never reuse yesterday's
      // clock strings or ask for GPS, geocoding or a server response at startup.
      await controller.refreshConfiguredPrayerTime();
    } catch (_) {
      // Missing or invalid local data must not prevent opening the app. The
      // normal home refresh can still obtain a location or a manual timetable.
      debugPrint('Saved prayer times could not be restored at startup');
    }
  }
}
