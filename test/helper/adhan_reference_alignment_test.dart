import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salatime/helper/local_prayer_calculator.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(LocalPrayerCalculator.initializeTimeZones);

  test('shared methods agree with 1232 independent Adhan Kotlin cases', () {
    final lines = File(
      'test/fixtures/adhan_kotlin_0_0_5.csv',
    ).readAsLinesSync();
    expect(lines.length - 1, 1232);
    final failures = <String>[];
    for (final line in lines.skip(1)) {
      final row = line.split(',');
      final request = <String, dynamic>{
        'type': 'automatic',
        'lat': row[1],
        'lng': row[2],
        'timezone': row[3],
        'date': row[4],
        'prayer_method': row[5],
        'school': row[6],
      };
      final data = LocalPrayerCalculator.calculate(request)?.data;
      expect(data, isNotNull, reason: '$request');
      final actual = [
        data!.fajrStart,
        data.sunrise,
        data.zuhrStart,
        data.asrStart,
        data.maghribStart,
        data.ishaStart,
      ];
      final zone = tz.getLocation(row[3]);
      for (var i = 0; i < actual.length; i++) {
        final expected = tz.TZDateTime.from(DateTime.parse(row[i + 7]), zone);
        final clock =
            '${expected.hour.toString().padLeft(2, '0')}:'
            '${expected.minute.toString().padLeft(2, '0')}';
        if (actual[i] != clock) {
          failures.add(
            '${row[0]} ${row[4]} method=${row[5]} '
            '${row[6]} prayer=$i expected=$clock actual=${actual[i]}',
          );
        }
      }
    }
    expect(failures, isEmpty, reason: failures.take(25).join('\n'));
  });
}
