import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zabi/helper/local_prayer_calculator.dart';

void main() {
  setUpAll(LocalPrayerCalculator.initializeTimeZones);
  final request = <String, dynamic>{
    'type': 'automatic',
    'date': '2026-09-11',
    'lat': '33.5731',
    'lng': '-7.5898',
    'prayer_method': '21',
    'school': 'STANDARD',
    'timezone': 'Africa/Casablanca',
  };
  int minutes(String value) {
    final parts = value.split(':').map(int.parse).toList();
    return parts[0] * 60 + parts[1];
  }

  test(
    '736 reference days cover all 23 methods, both schools and four cities',
    () {
      final cases =
          jsonDecode(
                File(
                  'test/fixtures/prayer_times_reference.json',
                ).readAsStringSync(),
              )
              as List;
      expect(cases, hasLength(736));
      for (final fixture in cases) {
        final context = Map<String, dynamic>.from(fixture['request'] as Map);
        final model = LocalPrayerCalculator.calculate(context);
        expect(model, isNotNull, reason: '$context');
        final day = model!.data!;
        final actual = {
          'Fajr': day.fajrStart,
          'Sunrise': day.sunrise,
          'Dhuhr': day.zuhrStart,
          'Asr': day.asrStart,
          'Maghrib': day.maghribStart,
          'Isha': day.ishaStart,
        };
        final date = DateTime.parse(context['date'] as String);
        final zone = tz.getLocation(context['timezone'] as String);
        final offset = tz.TZDateTime(
          zone,
          date.year,
          date.month,
          date.day,
          12,
        ).timeZoneOffset.inMinutes;
        for (final time in actual.entries) {
          var delta =
              ((minutes(time.value!) - offset) % 1440 -
                      minutes(fixture['expected'][time.key] as String))
                  .abs();
          if (delta > 720) delta = 1440 - delta;
          // Adhan's Moonsighting implementation uses different seasonal bounds
          // and +5/+3 minute Dhuhr/Maghrib corrections from the legacy backend.
          final tolerance = context['prayer_method'] == '15' ? 8 : 2;
          expect(
            delta,
            lessThanOrEqualTo(tolerance),
            reason: '${fixture['city']} $context ${time.key}',
          );
        }
      }
    },
  );

  test('method and school choices materially affect the requested times', () {
    final morocco = LocalPrayerCalculator.calculate(request)!.data!;
    final france = LocalPrayerCalculator.calculate({
      ...request,
      'prayer_method': '12',
    })!.data!;
    final hanafi = LocalPrayerCalculator.calculate({
      ...request,
      'school': 'HANAFI',
    })!.data!;
    expect(
      minutes(france.fajrStart!),
      greaterThan(minutes(morocco.fajrStart!)),
    );
    expect(minutes(hanafi.asrStart!), greaterThan(minutes(morocco.asrStart!)));
    expect(morocco.sehriEnd, morocco.fajrStart);
    expect(morocco.iftarStart, morocco.maghribStart);
  });

  test(
    'uses each prayer instant timezone including DST and Morocco Ramadan',
    () {
      final paris = {
        ...request,
        'lat': '48.8566',
        'lng': '2.3522',
        'timezone': 'Europe/Paris',
        'prayer_method': '3',
      };
      final before = LocalPrayerCalculator.calculate({
        ...paris,
        'date': '2026-03-28',
      })!.data!;
      final after = LocalPrayerCalculator.calculate({
        ...paris,
        'date': '2026-03-29',
      })!.data!;
      expect(
        minutes(after.zuhrStart!) - minutes(before.zuhrStart!),
        inInclusiveRange(59, 61),
      );
      expect(
        tz.TZDateTime(
          tz.getLocation('Africa/Casablanca'),
          2026,
          3,
          1,
          12,
        ).timeZoneOffset,
        Duration.zero,
      );
      expect(
        tz.TZDateTime(
          tz.getLocation('Africa/Casablanca'),
          2026,
          10,
          25,
          12,
        ).timeZoneOffset,
        const Duration(hours: 1),
      );
    },
  );

  test('invalid input and manual timetables never invent fallback times', () {
    for (final overrides in [
      {'type': 'manual'},
      {'lat': 'NaN'},
      {'lat': '91'},
      {'lng': '181'},
      {'timezone': 'Unknown/Place'},
      {'prayer_method': '99'},
      {'school': 'unknown'},
      {'date': 'invalid'},
    ]) {
      expect(
        LocalPrayerCalculator.calculate({...request, ...overrides}),
        isNull,
      );
    }
  });
}
