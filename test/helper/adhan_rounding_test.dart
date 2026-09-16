import 'package:adhan/adhan.dart';
// Exercise the small upstream patch at its raw-instant boundary.
// ignore: implementation_imports
import 'package:adhan/src/data/calendar_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('upward rounding preserves exact minutes and never rounds twice', () {
    for (final second in [0, 1, 29, 30, 59]) {
      final raw = DateTime.utc(2026, 9, 16, 12, 30, second);
      expect(
        CalendarUtil.roundedMinute(raw, rounding: Rounding.up),
        DateTime.utc(2026, 9, 16, 12, second == 0 ? 30 : 31),
      );
      expect(
        CalendarUtil.roundedMinute(raw),
        DateTime.utc(2026, 9, 16, 12, second < 30 ? 30 : 31),
      );
    }
  });

  test('upward rounding clears subsecond precision and crosses midnight', () {
    expect(
      CalendarUtil.roundedMinute(
        DateTime.utc(2026, 9, 16, 23, 59, 0, 0, 1),
        rounding: Rounding.up,
      ),
      DateTime.utc(2026, 9, 17),
    );
    final rounded = CalendarUtil.roundedMinute(
      DateTime.utc(2026, 9, 16, 23, 59, 45),
      rounding: Rounding.up,
    );
    expect(rounded.isUtc, isTrue);
    expect(rounded, DateTime.utc(2026, 9, 17));
  });

  test('Singapore rounds each raw prayer once rather than adding a minute', () {
    final parameters = CalculationMethod.singapore.getParameters();
    final upward = PrayerTimes(
      Coordinates(1.3521, 103.8198),
      DateComponents(2026, 9, 16),
      parameters,
    );
    final nearestParameters = CalculationMethod.singapore.getParameters()
      ..rounding = Rounding.nearest;
    final nearest = PrayerTimes(
      Coordinates(1.3521, 103.8198),
      DateComponents(2026, 9, 16),
      nearestParameters,
    );
    final differences = [
      upward.fajr.difference(nearest.fajr).inMinutes,
      upward.sunrise.difference(nearest.sunrise).inMinutes,
      upward.dhuhr.difference(nearest.dhuhr).inMinutes,
      upward.asr.difference(nearest.asr).inMinutes,
      upward.maghrib.difference(nearest.maghrib).inMinutes,
      upward.isha.difference(nearest.isha).inMinutes,
    ];
    expect(differences, everyElement(isIn([0, 1])));
    expect(differences, containsAll([0, 1]));
  });
}
