import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/helper/islamic_calendar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await IslamicCalendarPreferences.initialize();
  });

  test(
    'Gregorian and Hijri conversions agree before and after correction',
    () async {
      for (final offset in [-2, 0, 2]) {
        await IslamicCalendarPreferences.setOffset(offset);
        for (final date in [
          DateTime(2026, 3, 20),
          DateTime(2026, 6, 16),
          DateTime(2027, 1, 1),
        ]) {
          final hijri = IslamicCalendarPreferences.date(date);
          expect(
            IslamicCalendarPreferences.gregorian(
              hijri.hYear,
              hijri.hMonth,
              hijri.hDay,
            ),
            date,
          );
        }
      }
    },
  );

  test('positive sighting correction brings event date forward', () async {
    const event = IslamicEvent('eid', 10, 1);
    final uncorrected = event.dateInYear(1447);
    expect(uncorrected, DateTime(2026, 3, 20));
    await IslamicCalendarPreferences.setOffset(1);
    expect(event.dateInYear(1447), DateTime(2026, 3, 19));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(IslamicCalendarPreferences.storageKey), 1);
    IslamicCalendarPreferences.offset.value = 0;
    await IslamicCalendarPreferences.initialize();
    expect(IslamicCalendarPreferences.offset.value, 1);
  });

  test('rejects invalid dates rather than rolling into another month', () {
    expect(
      () => IslamicCalendarPreferences.gregorian(1447, 13, 1),
      throwsArgumentError,
    );
    expect(
      () => IslamicCalendarPreferences.gregorian(1447, 1, 31),
      throwsArgumentError,
    );
    expect(
      () => IslamicCalendarPreferences.gregorian(1300, 1, 1),
      throwsArgumentError,
    );
  });

  test('event distances count civil days and year lists stay ordered', () {
    expect(
      IslamicEvent.civilDaysBetween(
        DateTime(2026, 3, 28, 23, 59),
        DateTime(2026, 3, 29),
      ),
      1,
    );
    final dates = IslamicEvent.all
        .map((event) => event.dateInYear(1448))
        .toList();
    for (int index = 1; index < dates.length; index++) {
      expect(dates[index].isAfter(dates[index - 1]), isTrue);
    }
  });
}
