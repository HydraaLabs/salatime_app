import 'package:zabi/data/model/response/todays_prayer_time_model.dart';

class SharedPrayerTime {
  final String labelKey;
  final DateTime time;
  const SharedPrayerTime(this.labelKey, this.time);
  String get clock =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

/// Both export formats use the same snapshot, including manual corrections.
class PrayerShareData {
  final DateTime date;
  final String city;
  final List<SharedPrayerTime> prayers;
  const PrayerShareData(this.date, this.city, this.prayers);

  static PrayerShareData? fromDay(
    Data? day, {
    required String city,
    Map<String, int> adjustments = const {},
  }) {
    if (day == null) return null;
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})$',
    ).firstMatch(day.date ?? '');
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final number = int.parse(match[3]!);
    final date = DateTime(year, month, number);
    if (date.year != year || date.month != month || date.day != number) {
      return null;
    }
    final values = [
      ('fajr', 'fajr', day.fajrStart),
      ('sunrise', 'sunrise', day.sunrise),
      ('zuhr', day.isJumma == true ? 'jumuah' : 'dhuhr', day.zuhrStart),
      ('asr', 'asr', day.asrStart),
      ('maghrib', 'magrib', day.maghribStart),
      ('isha', 'isha', day.ishaStart),
    ];
    final prayers = <SharedPrayerTime>[];
    DateTime? previous;
    for (final (adjustmentKey, labelKey, value) in values) {
      final time = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value ?? '');
      if (time == null) return null;
      final hour = int.parse(time[1]!);
      final minute = int.parse(time[2]!);
      if (hour > 23 || minute > 59) return null;
      var base = DateTime(year, month, number, hour, minute);
      if (previous != null && base.isBefore(previous)) {
        if (adjustmentKey != 'isha') return null;
        base = DateTime(year, month, number + 1, hour, minute);
      }
      previous = base;
      prayers.add(
        SharedPrayerTime(
          labelKey,
          base.add(Duration(minutes: adjustments[adjustmentKey] ?? 0)),
        ),
      );
    }
    return PrayerShareData(date, city.trim(), List.unmodifiable(prayers));
  }

  String timeText(
    SharedPrayerTime prayer,
    String Function(DateTime) formatDate,
  ) {
    final t = prayer.time;
    if (t.year == date.year && t.month == date.month && t.day == date.day) {
      return prayer.clock;
    }
    return '${prayer.clock} (${formatDate(t)})';
  }

  String text({
    required String Function(String) translate,
    required String Function(DateTime) formatDate,
    required String hijriDate,
  }) => [
    'SalaTime · ${translate('prayer_share_title')}',
    if (city.isNotEmpty) city,
    formatDate(date),
    hijriDate,
    '',
    for (final prayer in prayers)
      '${translate(prayer.labelKey)} : ${timeText(prayer, formatDate)}',
    '',
    'salatime.net',
  ].join('\n');
}
