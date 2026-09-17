import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salatime/helper/local_prayer_calculator.dart';
import 'package:salatime/helper/additional_reminder_plan.dart';
import 'package:salatime/helper/prayer_notification_preferences.dart';
import 'helper/prayer_notification_scheduler_test.dart' show SchedulerHarness;

// The plugin binds its platform singleton once per test isolate.
// Keep this iOS migration separate from the Android scheduler suite.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(LocalPrayerCalculator.initializeTimeZones);
  late SchedulerHarness harness;
  setUp(() async {
    harness = SchedulerHarness();
    await harness.initialize();
  });
  test(
    'iOS grouping migrates existing schedules once without losing future IDs',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await PrayerNotificationPreferences.update(
        PrayerNotificationPrayer.asr,
        PrayerNotificationPhase.adhan,
        enabled: true,
      );
      await AdditionalReminderPreferences.save([
        AdditionalReminderSetting.defaults(
          AdditionalReminderType.morning,
        ).copyWith(enabled: true),
      ]);
      await harness.refresh();
      final ids = harness.pending.keys.toSet();
      expect(ids, hasLength(2));
      for (final id in ids) {
        expect(harness.payload(id)['iosThread'], 'salatime.prayer-reminders');
        final legacy = harness.payload(id)..remove('iosThread');
        harness.pending[id]!['payload'] = jsonEncode(legacy);
      }
      harness.clearCalls();
      await harness.refresh();
      expect(harness.scheduled.toSet(), ids);
      expect(harness.pending.keys.toSet(), ids);
      expect(harness.cancellations, isEmpty);
      harness.clearCalls();
      await harness.refresh();
      expect(harness.scheduled, isEmpty);
      expect(harness.pending.keys.toSet(), ids);
    },
  );
}
