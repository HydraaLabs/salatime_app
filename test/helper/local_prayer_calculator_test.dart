import 'dart:convert';
import 'dart:io';

import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:salatime/helper/local_prayer_calculator.dart';

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
    '384 legacy reference days preserve 12 regional methods and both schools',
    () {
      final cases =
          jsonDecode(
                File(
                  'test/fixtures/prayer_times_reference.json',
                ).readAsStringSync(),
              )
              as List;
      expect(cases, hasLength(736));
      // These eleven methods now use the named Adhan presets and recommended
      // night bounds. Their independent Adhan reference has separate coverage;
      // the historical PHP fixtures remain authoritative for regional methods.
      const standardMethods = {
        '1',
        '2',
        '3',
        '4',
        '5',
        '9',
        '10',
        '11',
        '13',
        '15',
        '16',
      };
      final regionalCases = cases
          .where(
            (fixture) =>
                !standardMethods.contains(fixture['request']['prayer_method']),
          )
          .toList();
      expect(regionalCases, hasLength(384));
      for (final fixture in regionalCases) {
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
          expect(
            delta,
            lessThanOrEqualTo(2),
            reason: '${fixture['city']} $context ${time.key}',
          );
        }
      }
    },
  );

  test(
    'shared methods use stable named presets instead of ordinal positions',
    () {
      const expected = {
        '3': CalculationMethod.muslim_world_league,
        '5': CalculationMethod.egyptian,
        '1': CalculationMethod.karachi,
        '4': CalculationMethod.umm_al_qura,
        '16': CalculationMethod.dubai,
        '15': CalculationMethod.moon_sighting_committee,
        '2': CalculationMethod.north_america,
        '9': CalculationMethod.kuwait,
        '10': CalculationMethod.qatar,
        '11': CalculationMethod.singapore,
        '13': CalculationMethod.turkey,
      };
      for (final entry in expected.entries) {
        final standard = LocalPrayerCalculator.parameters(
          entry.key,
          'STANDARD',
        )!;
        final hanafi = LocalPrayerCalculator.parameters(entry.key, 'HANAFI')!;
        expect(standard.method, entry.value, reason: entry.key);
        expect(standard.madhab, Madhab.shafi);
        expect(hanafi.method, entry.value, reason: entry.key);
        expect(hanafi.madhab, Madhab.hanafi);
      }
    },
  );

  test('recommended night bounds apply only to the shared presets', () {
    for (final latitude in [-55.0, 0.0, 48.0, 48.0001, 55.0]) {
      expect(
        LocalPrayerCalculator.parameters(
          '3',
          'STANDARD',
          latitude: latitude,
        )!.highLatitudeRule,
        latitude > 48
            ? HighLatitudeRule.seventh_of_the_night
            : HighLatitudeRule.middle_of_the_night,
      );
      expect(
        LocalPrayerCalculator.parameters(
          '21',
          'STANDARD',
          latitude: latitude,
        )!.highLatitudeRule,
        HighLatitudeRule.twilight_angle,
      );
    }
    for (final method in ['4', '10']) {
      // Fixed-interval presets leave Isha's angle undefined. Their night rule
      // must still allow the Fajr bound and the 90-minute Isha to calculate.
      expect(
        LocalPrayerCalculator.calculate({...request, 'prayer_method': method}),
        isNotNull,
      );
    }
  });

  test('method corrections and Singapore upward rounding remain distinct', () {
    final dubai = LocalPrayerCalculator.parameters('16', 'STANDARD')!;
    expect(dubai.methodAdjustments.sunrise, -3);
    expect(dubai.methodAdjustments.dhuhr, 3);
    expect(dubai.methodAdjustments.asr, 3);
    expect(dubai.methodAdjustments.maghrib, 3);
    final turkey = LocalPrayerCalculator.parameters('13', 'STANDARD')!;
    expect(turkey.methodAdjustments.sunrise, -7);
    expect(turkey.methodAdjustments.dhuhr, 5);
    expect(turkey.methodAdjustments.asr, 4);
    expect(turkey.methodAdjustments.maghrib, 7);
    final singapore = LocalPrayerCalculator.parameters('11', 'STANDARD')!;
    expect(singapore.methodAdjustments.dhuhr, 1);
    expect(singapore.rounding, Rounding.up);
    expect(dubai.rounding, Rounding.nearest);
    expect(
      LocalPrayerCalculator.parameters('21', 'STANDARD')!.rounding,
      Rounding.nearest,
    );
  });

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
