import 'package:flutter_test/flutter_test.dart';
import 'package:salatime/helper/prayer_display_phase.dart';
import 'package:salatime/data/model/response/todays_prayer_time_model.dart';

void main() {
  test(
    'approaching excludes the exact threshold, elapsed and missing times',
    () {
      expect(
        PrayerDisplayPhase.isApproaching(const Duration(hours: 1)),
        isFalse,
      );
      expect(
        PrayerDisplayPhase.isApproaching(
          const Duration(minutes: 59, seconds: 59),
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
  test('next prayer wins at one hour even during the elapsed window', () {
    final close = Data(
      date: '2026-09-16',
      maghribStart: '19:25',
      ishaStart: '20:51',
    );
    expect(
      PrayerDisplayPhase.resolve(
        DateTime(2026, 9, 16, 19, 50, 59),
        close,
      )!.prayerKey,
      'magrib',
    );
    expect(
      PrayerDisplayPhase.resolve(DateTime(2026, 9, 16, 19, 51), close),
      isNull,
    );
    final now = DateTime(2026, 9, 16, 20, 35);
    expect(PrayerDisplayPhase.resolve(now, close), isNull);
    final next = PrayerDisplayPhase.next(now, [close])!;
    expect(next.prayerKey, 'isha');
    expect(next.startedAt.difference(now), const Duration(minutes: 16));
    expect(
      PrayerDisplayPhase.isApproaching(next.startedAt.difference(now)),
      isTrue,
    );
    expect(
      PrayerDisplayPhase.resolve(
        DateTime(2026, 9, 16, 20, 51),
        close,
      )!.prayerKey,
      'isha',
    );
  });
  test('next priority uses tomorrow and adjusted prayer instants', () {
    final today = Data(date: '2026-09-16', ishaStart: '23:10');
    final tomorrow = Data(date: '2026-09-17', fajrStart: '00:20');
    final now = DateTime(2026, 9, 16, 23, 30);
    expect(
      PrayerDisplayPhase.resolve(
        now,
        today,
        nextDay: tomorrow,
        adjustments: {'fajr': 10},
      ),
      isNull,
    );
    expect(
      PrayerDisplayPhase.resolve(
        now.subtract(const Duration(seconds: 1)),
        today,
        nextDay: tomorrow,
        adjustments: {'fajr': 10},
      )!.prayerKey,
      'isha',
    );
  });
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
  test('elapsed starts at prayer time and ends exactly at one hour', () {
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
          DateTime(2026, 9, 12, 13, 59, 59),
          day,
        )!.elapsed,
      ),
      '00:59:59',
    );
    expect(PrayerDisplayPhase.resolve(DateTime(2026, 9, 12, 14), day), isNull);
    final next = PrayerDisplayPhase.next(DateTime(2026, 9, 12, 14), [day])!;
    expect(next.prayerKey, 'asr');
    expect(
      next.startedAt.difference(DateTime(2026, 9, 12, 14)),
      const Duration(hours: 2),
    );
  });
  test('a new prayer takes precedence and sunrise is not a prayer', () {
    expect(
      PrayerDisplayPhase.resolve(DateTime(2026, 9, 12, 17, 20), day)!.prayerKey,
      'magrib',
    );
    expect(
      PrayerDisplayPhase.resolve(
        DateTime(2026, 9, 12, 5, 59, 59),
        day,
      )!.prayerKey,
      'fajr',
    );
    expect(
      PrayerDisplayPhase.resolve(DateTime(2026, 9, 12, 6, 10), day),
      isNull,
    );
  });
  test('after midnight uses actual previous date and expires', () {
    final next = Data(date: '2026-09-13', ishaStart: '22:00');
    expect(
      PrayerDisplayPhase.resolve(
        DateTime(2026, 9, 13, 0, 39, 59),
        next,
        previousDay: day,
      )!.elapsed,
      const Duration(minutes: 59, seconds: 59),
    );
    expect(
      PrayerDisplayPhase.resolve(
        DateTime(2026, 9, 13, 0, 40),
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
