import 'package:adhan/src/extensions/datetime.dart';
import '../rounding.dart';

import 'date_components.dart';

class CalendarUtil {
  /// Whether or not a year is a leap year (has 366 days)
  ///
  /// [year] the year
  /// return [bool] whether or not its a leap year
  static bool isLeapYear(int year) {
    return year % 4 == 0 && !(year % 100 == 0 && year % 400 != 0);
  }

  /// Date and time with a rounded minute
  ///
  /// This returns a date with the seconds rounded and added to the minute
  /// [when] the date and time
  /// return [DateTime] and time with 0 seconds and minutes including rounded seconds
  static DateTime roundedMinute(DateTime when,
      {Rounding rounding = Rounding.nearest}) {
    final minute = when.minute;
    final second = when.second;
    final increment = rounding == Rounding.up
        ? (second > 0 || when.millisecond > 0 || when.microsecond > 0 ? 1 : 0)
        : (second / 60).round();
    return when.copyWith(
        minute: minute + increment, second: 0, millisecond: 0, microsecond: 0);
  }

  /// Gets a UTC DateTime for the particular date
  ///
  /// [components] the date components
  /// return [DateTime] with a time set to 00:00:00 at utc
  static DateTime resolveTimeByDateComponents(DateComponents components) {
    return resolveTime(components.year, components.month, components.day);
  }

  /// Gets UTC DateTime for the particular date
  ///
  /// [year] the year
  /// [month] the month
  /// [day] the day
  /// return [DateTime] with a time set to 00:00:00 at utc
  static DateTime resolveTime(int year, int month, int day) {
    return DateTime.utc(year, month, day, 0, 0, 0);
  }
}
