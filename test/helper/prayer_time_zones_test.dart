import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:salatime/helper/device_clock_change.dart';
import 'package:salatime/helper/local_prayer_calculator.dart';
import 'package:salatime/helper/prayer_alarm_plan.dart';
import 'package:salatime/helper/prayer_time_zones.dart';

void main() {
  setUpAll(PrayerTimeZones.initialize);

  for (final name in ['Africa/Casablanca', 'Africa/El_Aaiun']) {
    test('$name follows the September 2026 transition and stays at GMT', () {
      final zone = PrayerTimeZones.location(name);
      final change = DateTime.utc(2026, 9, 20, 1);
      expect(
        tz.TZDateTime.from(
          change.subtract(const Duration(seconds: 1)),
          zone,
        ).timeZoneOffset,
        const Duration(hours: 1),
      );
      expect(tz.TZDateTime.from(change, zone).timeZoneOffset, Duration.zero);
      for (final date in [
        DateTime.utc(2026, 10, 25),
        DateTime.utc(2027, 3, 28),
        DateTime.utc(2030, 7, 1),
      ]) {
        expect(tz.TZDateTime.from(date, zone).timeZoneOffset, Duration.zero);
      }
      expect(tz.TZDateTime(zone, 2026, 3, 1, 12).timeZoneOffset, Duration.zero);
      expect(
        tz.TZDateTime(zone, 2026, 8, 1, 12).timeZoneOffset,
        const Duration(hours: 1),
      );
    });
  }

  test(
    'Azrou clocks and all reminder phases share the corrected UTC instant',
    () {
      final request = {
        'type': 'automatic',
        'date': '2026-09-20',
        'lat': '33.4344',
        'lng': '-5.2213',
        'prayer_method': '21',
        'school': 'STANDARD',
        'timezone': 'Africa/Casablanca',
      };
      final day = LocalPrayerCalculator.calculate(request)!.data!;
      final utcDay = LocalPrayerCalculator.calculate({
        ...request,
        'timezone': 'UTC',
      })!.data!;
      expect(day.zuhrStart, '12:14');
      expect(
        [
          day.fajrStart,
          day.sunrise,
          day.zuhrStart,
          day.asrStart,
          day.maghribStart,
          day.ishaStart,
        ],
        [
          utcDay.fajrStart,
          utcDay.sunrise,
          utcDay.zuhrStart,
          utcDay.asrStart,
          utcDay.maghribStart,
          utcDay.ishaStart,
        ],
      );
      final zone = PrayerTimeZones.location('Africa/Casablanca');
      final occurrences = PrayerOccurrence.fromDay(day, zone, {});
      final plan = buildPrayerAlarmPlan(
        prayers: occurrences,
        now: DateTime.utc(2026, 9, 20),
        enabledPrayerIds: {1, 2, 3, 4, 5},
        beforeMinutes: 5,
        afterMinutes: 10,
      );
      final dhuhr = plan.where((a) => a.prayer.prayerId == 2).toList();
      expect(dhuhr.map((a) => a.time.toUtc()).toSet(), {
        DateTime.utc(2026, 9, 20, 12, 9),
        DateTime.utc(2026, 9, 20, 12, 14),
        DateTime.utc(2026, 9, 20, 12, 24),
      });
    },
  );

  test('native rules handle a future change absent from the app database', () {
    final change = DateTime.utc(2029, 6, 1, 1);
    final nativeRules =
        tz.Location('Device/NewRule', [change.millisecondsSinceEpoch], [1], [
          const tz.TimeZone(
            3 * Duration.millisecondsPerHour,
            isDst: false,
            abbreviation: '+03',
          ),
          const tz.TimeZone(
            2 * Duration.millisecondsPerHour,
            isDst: false,
            abbreviation: '+02',
          ),
        ]);
    final device = PrayerTimeZones.deviceLocation(
      'Device/NewRule',
      2029,
      localTime: (instant) => tz.TZDateTime.from(instant, nativeRules),
    );
    expect(
      tz.TZDateTime(device, 2029, 5, 31, 12).toUtc(),
      DateTime.utc(2029, 5, 31, 9),
    );
    expect(
      tz.TZDateTime(device, 2029, 6, 1, 12).toUtc(),
      DateTime.utc(2029, 6, 1, 10),
    );
    expect(
      tz.TZDateTime.from(
        change.subtract(const Duration(seconds: 1)),
        device,
      ).hour,
      3,
    );
    expect(tz.TZDateTime.from(change, device).hour, 3);
  });

  test('native calendar preserves both spring and autumn DST transitions', () {
    final paris = tz.getLocation('Europe/Paris');
    final device = PrayerTimeZones.deviceLocation(
      'Europe/Paris',
      2026,
      localTime: (instant) => tz.TZDateTime.from(instant, paris),
    );
    for (final change in [
      DateTime.utc(2026, 3, 29, 1),
      DateTime.utc(2026, 10, 25, 1),
    ]) {
      for (final delta in [-1, 0, 1, 3600]) {
        final instant = change.add(Duration(seconds: delta));
        expect(
          tz.TZDateTime.from(instant, device).timeZoneOffset,
          tz.TZDateTime.from(instant, paris).timeZoneOffset,
        );
      }
    }
  });

  test(
    'a clock shift while foregrounded triggers once without timer false positives',
    () {
      final monitor = DeviceClockChange();
      final now = DateTime.utc(2026, 9, 20, 1);
      expect(monitor.observe(now, Duration.zero), isFalse);
      expect(
        monitor.observe(
          now.add(const Duration(seconds: 75)),
          const Duration(seconds: 75),
        ),
        isFalse,
      );
      expect(
        monitor.observe(
          now.subtract(const Duration(minutes: 58)),
          const Duration(minutes: 2),
        ),
        isTrue,
      );
      expect(
        monitor.observe(
          now.subtract(const Duration(minutes: 57)),
          const Duration(minutes: 3),
        ),
        isFalse,
      );
      final shifted = tz.TZDateTime.from(
        now.subtract(const Duration(minutes: 56)),
        tz.Location('Changed/Zone', [], [], [
          const tz.TimeZone(3600000, isDst: false, abbreviation: '+01'),
        ]),
      );
      expect(monitor.observe(shifted, const Duration(minutes: 4)), isTrue);
    },
  );
}
