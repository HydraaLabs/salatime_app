import 'package:zabi/data/model/response/todays_prayer_time_model.dart';

/// Presentation only: never changes the prayer schedule or notification alarms.
class PrayerDisplayPhase {
  const PrayerDisplayPhase(this.prayerKey, this.startedAt, this.elapsed);
  final String prayerKey;
  final DateTime startedAt;
  final Duration elapsed;
  static const window = Duration(minutes: 90);

  static bool isApproaching(Duration? remaining, {bool elapsed = false}) =>
      !elapsed &&
      remaining != null &&
      remaining > Duration.zero &&
      remaining < const Duration(minutes: 45);

  static PrayerDisplayPhase? resolve(
    DateTime now,
    Data? today, {
    Data? previousDay,
    Map<String, int> adjustments = const {},
  }) {
    PrayerDisplayPhase? latest;
    for (final moment in moments([
      previousDay,
      today,
    ], adjustments: adjustments)) {
      final elapsed = now.difference(moment.startedAt);
      if (elapsed.isNegative || elapsed >= window) continue;
      if (latest == null || moment.startedAt.isAfter(latest.startedAt)) {
        latest = PrayerDisplayPhase(
          moment.prayerKey,
          moment.startedAt,
          elapsed,
        );
      }
    }
    return latest;
  }

  /// Keep civil dates when adjustments or a late Isha cross midnight.
  static List<PrayerDisplayPhase> moments(
    Iterable<Data?> days, {
    Map<String, int> adjustments = const {},
  }) {
    final result = <PrayerDisplayPhase>[];
    for (final day in days) {
      if (day == null) continue;
      final date = DateTime.tryParse(day.date ?? '');
      if (date == null) continue;
      DateTime? previous;
      final clocks = {
        'fajr': day.fajrStart,
        day.isJumma == true ? 'jumuah' : 'dhuhr': day.zuhrStart,
        'asr': day.asrStart,
        'magrib': day.maghribStart,
        'isha': day.ishaStart,
      };
      for (final entry in clocks.entries) {
        final match = RegExp(
          r'^(\d{1,2}):(\d{2})(?::\d{2})?$',
        ).firstMatch(entry.value?.trim() ?? '');
        if (match == null) continue;
        final hour = int.parse(match[1]!);
        final minute = int.parse(match[2]!);
        if (hour > 23 || minute > 59) continue;
        var at = DateTime(date.year, date.month, date.day, hour, minute);
        if (entry.key == 'isha' && previous != null && at.isBefore(previous)) {
          at = DateTime(date.year, date.month, date.day + 1, hour, minute);
        }
        previous = at;
        final adjustmentKey = switch (entry.key) {
          'dhuhr' || 'jumuah' => 'zuhr',
          'magrib' => 'maghrib',
          _ => entry.key,
        };
        result.add(
          PrayerDisplayPhase(
            entry.key,
            at.add(Duration(minutes: adjustments[adjustmentKey] ?? 0)),
            Duration.zero,
          ),
        );
      }
    }
    result.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return result;
  }

  static PrayerDisplayPhase? next(
    DateTime now,
    Iterable<Data?> days, {
    Map<String, int> adjustments = const {},
  }) {
    for (final moment in moments(days, adjustments: adjustments)) {
      if (moment.startedAt.isAfter(now)) return moment;
    }
    return null;
  }

  static String format(Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    return '${safe.inHours.toString().padLeft(2, '0')}:${(safe.inMinutes % 60).toString().padLeft(2, '0')}:${(safe.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}
