import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:salatime/data/model/response/todays_prayer_time_model.dart';
import 'package:salatime/helper/local_prayer_calculator.dart';
import 'package:salatime/helper/prayer_alarm_plan.dart';

void main() {
  setUpAll(LocalPrayerCalculator.initializeTimeZones);
  Data day(String date, {String fajr = '05:30', String isha = '21:00'}) => Data(
    date: date,
    fajrStart: fajr,
    zuhrStart: '13:00',
    asrStart: '16:00',
    maghribStart: '19:00',
    ishaStart: isha,
  );
  test(
    'tomorrow uses its own clock, skips elapsed reminders and keeps stable IDs',
    () {
      final zone = tz.getLocation('UTC');
      final now = tz.TZDateTime(zone, 2026, 9, 11, 23);
      final prayers = [
        ...PrayerOccurrence.fromDay(day('2026-09-11'), zone, {}),
        ...PrayerOccurrence.fromDay(day('2026-09-12', fajr: '05:32'), zone, {
          'fajr': 2,
        }),
      ];
      final plan = buildPrayerAlarmPlan(
        prayers: prayers,
        now: now,
        enabledPrayerIds: {1, 2, 3, 4, 5},
        beforeMinutes: 10,
        afterMinutes: 15,
      );
      expect(plan, hasLength(15));
      expect(plan.first.time, tz.TZDateTime(zone, 2026, 9, 12, 5, 24));
      expect(plan.map((p) => p.id).toSet(), hasLength(15));
      expect(
        plan.where((p) => p.kind == PrayerAlarmKind.adhan).first.time.minute,
        34,
      );
    },
  );
  test(
    'skip one date removes all its reminders without disabling later prayers',
    () {
      final zone = tz.getLocation('UTC');
      final prayers = [
        for (var d = 11; d <= 12; d++)
          ...PrayerOccurrence.fromDay(day('2026-09-$d'), zone, {}),
      ];
      final plan = buildPrayerAlarmPlan(
        prayers: prayers,
        now: DateTime.utc(2026, 9, 11),
        enabledPrayerIds: {1, 3},
        skippedPrayers: {'2026-09-11:1'},
        beforeMinutes: 5,
        afterMinutes: 5,
      );
      expect(plan, hasLength(9));
      expect(plan.any((p) => p.prayer.key == '2026-09-11:1'), isFalse);
      expect(plan.any((p) => p.prayer.key == '2026-09-12:1'), isTrue);
    },
  );
  test(
    'iOS cap selects the earliest 60 and midnight offsets keep their actual date',
    () {
      final zone = tz.getLocation('Europe/Paris');
      final prayers = [
        for (var d = 28; d <= 35; d++)
          ...PrayerOccurrence.fromDay(
            day(
              DateTime(2026, 3, d).toIso8601String().split('T').first,
              fajr: '00:05',
            ),
            zone,
            {},
          ),
      ];
      final plan = buildPrayerAlarmPlan(
        prayers: prayers,
        now: DateTime.utc(2026, 3, 27),
        enabledPrayerIds: {1, 2, 3, 4, 5},
        beforeMinutes: 15,
        afterMinutes: 10,
        limit: 60,
      );
      expect(plan, hasLength(60));
      expect(plan.first.time.day, 27);
      expect(plan.first.time.hour, 23);
      for (var i = 1; i < plan.length; i++) {
        expect(plan[i].time.isBefore(plan[i - 1].time), isFalse);
      }
    },
  );
  test('Isha after midnight and DST are calendar days, not 24-hour shifts', () {
    final zone = tz.getLocation('Europe/Paris');
    final first = PrayerOccurrence.fromDay(
      day('2026-03-28', isha: '00:15'),
      zone,
      {},
    );
    final second = PrayerOccurrence.fromDay(day('2026-03-29'), zone, {});
    expect(first.last.time.day, 29);
    expect(
      second.first.time.difference(first.first.time),
      const Duration(hours: 23),
    );
    expect(
      PrayerOccurrence.fromDay(day('2026-03-29', fajr: '28:00'), zone, {}),
      isEmpty,
    );
  });
}
