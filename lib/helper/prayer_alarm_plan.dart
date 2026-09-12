import 'package:timezone/timezone.dart' as tz;
import 'prayer_notification_preferences.dart';
import 'package:zabi/data/model/response/todays_prayer_time_model.dart';

class PrayerOccurrence {
  const PrayerOccurrence({
    required this.prayerId,
    required this.date,
    required this.time,
    this.adjustmentMinutes,
  });

  final int prayerId;
  final String date;
  final tz.TZDateTime time;

  /// Null for legacy manifests whose unadjusted prayer time is unknown.
  final int? adjustmentMinutes;
  String get key => '$date:$prayerId';
  PrayerNotificationPrayer get notificationPrayer =>
      PrayerNotificationPrayer.fromLegacyId(
        prayerId,
        date: DateTime.parse(date),
      );
  String get nameKey => notificationPrayer.titleKey;

  static List<PrayerOccurrence> fromDay(
    Data day,
    tz.Location zone,
    Map<String, int> adjustments, {
    bool includeSunrise = false,
  }) {
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
          adjustmentMinutes: adjustments[keys[i]] ?? 0,
        ),
      );
    }
    if (includeSunrise) {
      final sunrise = day.sunrise;
      if (sunrise != null &&
          RegExp(r'^(?:[01]?\d|2[0-3]):[0-5]\d$').hasMatch(sunrise)) {
        final parts = sunrise.split(':').map(int.parse).toList();
        result.add(
          PrayerOccurrence(
            prayerId: 6,
            date: day.date!,
            time: tz.TZDateTime(
              zone,
              date.year,
              date.month,
              date.day,
              parts[0],
              parts[1],
            ).add(Duration(minutes: adjustments['sunrise'] ?? 0)),
            adjustmentMinutes: adjustments['sunrise'] ?? 0,
          ),
        );
        result.sort((a, b) => a.time.compareTo(b.time));
      }
    }
    return result;
  }
}

enum PrayerAlarmKind { adhan, before, after }

class PlannedPrayerAlarm {
  const PlannedPrayerAlarm(this.prayer, this.kind, this.time, {this.setting});
  final PrayerNotificationSetting? setting;
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
    if (prayer.adjustmentMinutes != null)
      'adjustmentMinutes': prayer.adjustmentMinutes,
    'zone': time.location.name,
    'kind': kind.name,
    'key': prayer.key,
    'prayer': prayer.notificationPrayer.name,
    if (setting != null) 'sound': setting!.sound,
    if (setting != null) 'minutes': setting!.minutes,
  };
}

List<PlannedPrayerAlarm> buildPrayerAlarmPlan({
  required List<PrayerOccurrence> prayers,
  required DateTime now,
  Set<int> enabledPrayerIds = const {},
  List<PrayerNotificationSetting>? settings,
  Set<String> skippedPrayers = const {},
  int? beforeMinutes,
  int? afterMinutes,
  int limit = 450,
}) {
  final result = <PlannedPrayerAlarm>[];
  final bySetting = {
    for (final setting in settings ?? <PrayerNotificationSetting>[])
      '${setting.prayer.name}:${setting.phase.name}': setting,
  };
  final seen = <String>{};
  for (final prayer in prayers) {
    if (!seen.add(prayer.key) || skippedPrayers.contains(prayer.key)) continue;
    void add(
      PrayerAlarmKind kind,
      int minutes, [
      PrayerNotificationSetting? setting,
    ]) {
      final time = prayer.time.add(Duration(minutes: minutes));
      if (time.isAfter(now)) {
        result.add(PlannedPrayerAlarm(prayer, kind, time, setting: setting));
      }
    }

    if (settings != null) {
      for (final kind in PrayerAlarmKind.values) {
        final phase = PrayerNotificationPhase.values.byName(kind.name);
        final setting =
            bySetting['${prayer.notificationPrayer.name}:${phase.name}'] ??
            PrayerNotificationSetting.defaults(
              prayer.notificationPrayer,
              phase,
            );
        if (!setting.enabled) continue;
        add(kind, switch (kind) {
          PrayerAlarmKind.adhan => 0,
          PrayerAlarmKind.before => -setting.minutes.clamp(0, 120),
          PrayerAlarmKind.after => setting.minutes.clamp(0, 120),
        }, setting);
      }
    } else {
      // Compatibility for callers that still construct a legacy plan explicitly.
      if (!enabledPrayerIds.contains(prayer.prayerId)) continue;
      add(PrayerAlarmKind.adhan, 0);
      if (beforeMinutes != null) {
        add(PrayerAlarmKind.before, -beforeMinutes.clamp(1, 60));
      }
      if (afterMinutes != null) {
        add(PrayerAlarmKind.after, afterMinutes.clamp(1, 60));
      }
    }
  }
  result.sort((a, b) => a.time.compareTo(b.time));
  return result.take(limit).toList();
}

/// Recover only the prayer base time from our saved manifest when an offline
/// calendar has no fresh row. This lets sound/delay edits reconcile immediately.
List<PrayerOccurrence> restoreUncoveredPrayerOccurrences({
  required List<Map<String, dynamic>> alarms,
  required Set<String> coveredDates,
  required tz.Location zone,
  Map<String, int> adjustments = const {},
}) {
  final recovered = <String, PrayerOccurrence>{};
  for (final entry in alarms) {
    try {
      final id = entry['id'];
      final prayerId = entry['prayerId'];
      final at = entry['prayerAt'];
      final date = entry['date'];
      if (id is! int ||
          id < 10000000 ||
          id >= 20000000 ||
          prayerId is! int ||
          prayerId < 1 ||
          prayerId > 6 ||
          at is! int ||
          at <= 0 ||
          date is! String ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
          coveredDates.contains(date) ||
          entry['zone'] != zone.name ||
          !['adhan', 'before', 'after'].contains(entry['kind'])) {
        continue;
      }
      final parsed = DateTime.tryParse(date);
      if (parsed == null || parsed.toIso8601String().split('T').first != date) {
        continue;
      }
      final storedAdjustment = entry['adjustmentMinutes'];
      final hasKnownAdjustment =
          storedAdjustment is int &&
          storedAdjustment >= -120 &&
          storedAdjustment <= 120;
      const adjustmentKeys = [
        'fajr',
        'zuhr',
        'asr',
        'maghrib',
        'isha',
        'sunrise',
      ];
      final newAdjustment = adjustments[adjustmentKeys[prayerId - 1]] ?? 0;
      final delta = hasKnownAdjustment ? newAdjustment - storedAdjustment : 0;
      final prayer = PrayerOccurrence(
        prayerId: prayerId,
        date: date,
        time: tz.TZDateTime.fromMillisecondsSinceEpoch(
          zone,
          at,
        ).add(Duration(minutes: delta)),
        adjustmentMinutes: hasKnownAdjustment ? newAdjustment : null,
      );
      recovered[prayer.key] = prayer;
    } catch (_) {
      /* Invalid cached metadata is never used to create an alarm. */
    }
  }
  return recovered.values.toList();
}
