import 'package:flutter_test/flutter_test.dart';
import 'package:salatime/helper/prayer_display_phase.dart';
import 'package:salatime/data/model/response/todays_prayer_time_model.dart';

void main() {
  test(
    'approaching excludes the exact threshold, elapsed and missing times',
    () {
      expect(
        PrayerDisplayPhase.isApproaching(const Duration(minutes: 45)),
        isFalse,
      );
      expect(
        PrayerDisplayPhase.isApproaching(
          const Duration(minutes: 44, seconds: 59),
        ),
        isTrue,
      );
      expect(
        PrayerDisplayPhase.isApproaching(const Duration(milliseconds: 1)),
        isTrue,
      );
      expect(PrayerDisplayPhase.isApproaching(Duration.zero), isFalse);
      expect(
        PrayerDisplayPhase.isApproaching(const Duration(seconds: -1)),
        isFalse,
      );
      expect(PrayerDisplayPhase.isApproaching(null), isFalse);
      expect(
        PrayerDisplayPhase.isApproaching(
          const Duration(minutes: 10),
          elapsed: true,
        ),
        isFalse,
      );
    },
  );
  final day = Data(
    date: '2026-09-12',
    fajrStart: '05:00',
    sunrise: '06:10',
    zuhrStart: '13:00',
    asrStart: '16:00',
    maghribStart: '17:20',
    ishaStart: '23:40',
  );
  test('adjustments crossing midnight keep the original prayer date', () {
    final phase = PrayerDisplayPhase.resolve(
      DateTime(2026, 9, 13, 0, 20),
      Data(date: '2026-09-13'),
      previousDay: Data(date: '2026-09-12', ishaStart: '23:50'),
      adjustments: {'isha': 20},
    );
    expect(phase!.elapsed, const Duration(minutes: 10));
    expect(phase.startedAt, DateTime(2026, 9, 13, 0, 10));
  });
  test('elapsed starts at prayer time and ends exactly at 90 minutes', () {
    expect(
      PrayerDisplayPhase.resolve(DateTime(2026, 9, 12, 12, 59, 59), day),
      isNull,
    );
    expect(
      PrayerDisplayPhase.resolve(DateTime(2026, 9, 12, 13), day)!.elapsed,
      Duration.zero,
    );
    expect(
      PrayerDisplayPhase.format(
        PrayerDisplayPhase.resolve(
          DateTime(2026, 9, 12, 14, 29, 59),
          day,
        )!.elapsed,
      ),
      '01:29:59',
    );
    expect(
      PrayerDisplayPhase.resolve(DateTime(2026, 9, 12, 14, 30), day),
      isNull,
    );
  });
  test('a new prayer takes precedence and sunrise is not a prayer', () {
    expect(
      PrayerDisplayPhase.resolve(DateTime(2026, 9, 12, 17, 20), day)!.prayerKey,
      'magrib',
    );
    expect(
      PrayerDisplayPhase.resolve(DateTime(2026, 9, 12, 6, 15), day)!.prayerKey,
      'fajr',
    );
    expect(
      PrayerDisplayPhase.resolve(DateTime(2026, 9, 12, 6, 31), day),
      isNull,
    );
  });
  test('after midnight uses actual previous date and expires', () {
    final next = Data(date: '2026-09-13', ishaStart: '22:00');
    expect(
      PrayerDisplayPhase.resolve(
        DateTime(2026, 9, 13, 0, 20),
        next,
        previousDay: day,
      )!.elapsed,
      const Duration(minutes: 40),
    );
    expect(
      PrayerDisplayPhase.resolve(
        DateTime(2026, 9, 13, 1, 10),
        next,
        previousDay: day,
      ),
      isNull,
    );
  });
  test(
    'late Isha rolls into the following civil day and next uses tomorrow schedule',
    () {
      final late = Data(
        date: '2026-09-12',
        maghribStart: '23:00',
        ishaStart: '00:30',
      );
      final tomorrow = Data(date: '2026-09-13', fajrStart: '04:15');
      expect(
        PrayerDisplayPhase.resolve(
          DateTime(2026, 9, 13, 0, 45),
          tomorrow,
          previousDay: late,
        )!.elapsed,
        const Duration(minutes: 15),
      );
      final next = PrayerDisplayPhase.next(DateTime(2026, 9, 13, 2), [
        late,
        tomorrow,
      ]);
      expect(next!.prayerKey, 'fajr');
      expect(next.startedAt, DateTime(2026, 9, 13, 4, 15));
      expect(PrayerDisplayPhase.next(DateTime(2026, 9, 13, 2), [late]), isNull);
    },
  );
  test('sunrise is never shown as the next prayer after Fajr', () {
    expect(
      PrayerDisplayPhase.next(DateTime(2026, 9, 12, 5, 10), [day])!.prayerKey,
      'dhuhr',
    );
  });

  test('missing or invalid schedules and Friday', () {
    expect(PrayerDisplayPhase.resolve(DateTime(2026, 9, 12), null), isNull);
    expect(
      PrayerDisplayPhase.resolve(
        DateTime(2026, 9, 12),
        Data(fajrStart: '25:70'),
      ),
      isNull,
    );
    expect(
      PrayerDisplayPhase.resolve(
        DateTime(2026, 9, 11, 13, 10),
        Data(date: '2026-09-11', isJumma: true, zuhrStart: '13:00'),
      )!.prayerKey,
      'jumuah',
    );
  });
}
