import 'package:timezone/timezone.dart' as tz;
import 'package:zabi/data/model/response/todays_prayer_time_model.dart';

class PrayerOccurrence {
  const PrayerOccurrence({
    required this.prayerId,
    required this.date,
    required this.time,
  });

  final int prayerId;
  final String date;
  final tz.TZDateTime time;
  String get key => '$date:$prayerId';
  String get nameKey =>
      const ['fajr', 'dhuhr', 'asr', 'magrib', 'isha'][prayerId - 1];

  static List<PrayerOccurrence> fromDay(
    Data day,
    tz.Location zone,
    Map<String, int> adjustments,
  ) {
    final date = DateTime.tryParse(day.date ?? '');
    if (date == null) return [];
    final clocks = [
      day.fajrStart,
      day.zuhrStart,
      day.asrStart,
      day.maghribStart,
      day.ishaStart,
    ];
    const keys = ['fajr', 'zuhr', 'asr', 'maghrib', 'isha'];
    final result = <PrayerOccurrence>[];
    tz.TZDateTime? previous;
    for (var i = 0; i < clocks.length; i++) {
      final clock = clocks[i];
      if (clock == null ||
          !RegExp(r'^(?:[01]?\d|2[0-3]):[0-5]\d$').hasMatch(clock)) {
        return [];
      }
      final parts = clock.split(':').map(int.parse).toList();
      var time = tz.TZDateTime(
        zone,
        date.year,
        date.month,
        date.day,
        parts[0],
        parts[1],
      );
      // At high latitudes Isha can fall after midnight on the next civil day.
      if (previous != null && time.isBefore(previous)) {
        if (i != 4) return [];
        time = tz.TZDateTime(
          zone,
          date.year,
          date.month,
          date.day + 1,
          parts[0],
          parts[1],
        );
      }
      previous = time;
      result.add(
        PrayerOccurrence(
          prayerId: i + 1,
          date: day.date!,
          time: time.add(Duration(minutes: adjustments[keys[i]] ?? 0)),
        ),
      );
    }
    return result;
  }
}

enum PrayerAlarmKind { adhan, before, after }

class PlannedPrayerAlarm {
  const PlannedPrayerAlarm(this.prayer, this.kind, this.time);
  final PrayerOccurrence prayer;
  final PrayerAlarmKind kind;
  final tz.TZDateTime time;

  int get id {
    final date = DateTime.parse(prayer.date);
    final day =
        DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    return 10000000 + day * 100 + kind.index * 10 + prayer.prayerId;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'prayerId': prayer.prayerId,
    'date': prayer.date,
    'at': time.millisecondsSinceEpoch,
    'prayerAt': prayer.time.millisecondsSinceEpoch,
    'zone': time.location.name,
    'kind': kind.name,
    'key': prayer.key,
  };
}

List<PlannedPrayerAlarm> buildPrayerAlarmPlan({
  required List<PrayerOccurrence> prayers,
  required DateTime now,
  required Set<int> enabledPrayerIds,
  Set<String> skippedPrayers = const {},
  int? beforeMinutes,
  int? afterMinutes,
  int limit = 450,
}) {
  final result = <PlannedPrayerAlarm>[];
  for (final prayer in prayers) {
    if (!enabledPrayerIds.contains(prayer.prayerId) ||
        skippedPrayers.contains(prayer.key)) {
      continue;
    }
    void add(PrayerAlarmKind kind, int minutes) {
      final time = prayer.time.add(Duration(minutes: minutes));
      if (time.isAfter(now)) result.add(PlannedPrayerAlarm(prayer, kind, time));
    }

    add(PrayerAlarmKind.adhan, 0);
    if (beforeMinutes != null) {
      add(PrayerAlarmKind.before, -beforeMinutes.clamp(1, 60));
    }
    if (afterMinutes != null) {
      add(PrayerAlarmKind.after, afterMinutes.clamp(1, 60));
    }
  }
  result.sort((a, b) => a.time.compareTo(b.time));
  return result.take(limit).toList();
}
