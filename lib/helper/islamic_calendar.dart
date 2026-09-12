import 'package:flutter/foundation.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A local sighting correction, independent of prayer time adjustments.
class IslamicCalendarPreferences {
  static const storageKey = 'hijri_date_adjustment_v1';
  static final offset = ValueNotifier<int>(0);

  static Future<void> initialize([SharedPreferences? preferences]) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    offset.value = (prefs.getInt(storageKey) ?? 0).clamp(-2, 2);
  }

  static Future<void> setOffset(int value) async {
    if (value < -2 || value > 2) throw RangeError.range(value, -2, 2);
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setInt(storageKey, value)) {
      throw StateError('Could not save the Hijri date correction');
    }
    offset.value = value;
  }

  static HijriCalendar date(DateTime day) => HijriCalendar.fromDate(
    DateTime(day.year, day.month, day.day + offset.value),
  );

  static DateTime gregorian(int year, int month, int day) {
    final calendar = HijriCalendar();
    if (year < 1357 || year > 1499 || month < 1 || month > 12) {
      throw ArgumentError('Date is outside the supported calendar range');
    }
    if (day < 1 || day > calendar.getDaysInMonth(year, month)) {
      throw ArgumentError('Invalid Hijri day');
    }
    final base = calendar.hijriToGregorian(year, month, day);
    return DateTime(base.year, base.month, base.day - offset.value);
  }
}

class IslamicEvent {
  final String key;
  final int month;
  final int day;
  const IslamicEvent(this.key, this.month, this.day);

  DateTime dateInYear(int year) =>
      IslamicCalendarPreferences.gregorian(year, month, day);

  // These are calendar commemorations, not determinations of local moon sighting.
  static const all = [
    IslamicEvent('event_new_year', 1, 1),
    IslamicEvent('event_ashura', 1, 10),
    IslamicEvent('event_mawlid', 3, 12),
    IslamicEvent('event_isra', 7, 27),
    IslamicEvent('event_ramadan', 9, 1),
    IslamicEvent('event_eid_fitr', 10, 1),
    IslamicEvent('event_arafah', 12, 9),
    IslamicEvent('event_eid_adha', 12, 10),
  ];

  static int civilDaysBetween(DateTime first, DateTime second) => DateTime.utc(
    second.year,
    second.month,
    second.day,
  ).difference(DateTime.utc(first.year, first.month, first.day)).inDays;
}
