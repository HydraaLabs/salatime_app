import 'dart:convert';
import 'dart:async';

import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zabi/data/model/response/todays_prayer_time_model.dart';
import 'package:zabi/helper/prayer_alarm_plan.dart';

import 'notification_sound_catalog.dart';

enum AdditionalReminderType {
  duha,
  lastThird,
  friday,
  morning,
  evening,
  mondayThursday, // Legacy storage/IDs; the UI now has separate days.
  whiteDays,
  fajrAlarm,
  bedtime,
  middleNight,
  monday,
  thursday,
}

class AdditionalReminderSetting {
  const AdditionalReminderSetting({
    required this.type,
    this.enabled = false,
    this.sound = 'noti_beep',
    this.useDefaultSound = false,
    required this.minutes,
    this.anchor = '',
  });

  final AdditionalReminderType type;
  final bool enabled;
  final String sound;
  final bool useDefaultSound;
  final int minutes;
  final String anchor;
  String get effectiveAnchor => anchor.isEmpty ? legacyAnchor(type) : anchor;
  bool get usesClock => effectiveAnchor == 'clock';
  bool get hasOffset => !usesClock;
  bool get offsetBefore => effectiveAnchor.startsWith('before');
  int get minimumMinutes => 0;
  int get maximumMinutes => usesClock ? 1439 : 120;
  String get titleKey => 'extra_reminder_${type.name}';
  String get descriptionKey => '${titleKey}_description';
  String get timingLabelKey {
    if (effectiveAnchor == 'afterIsha') {
      if (type == AdditionalReminderType.monday) return 'extra_time_sundayIsha';
      if (type == AdditionalReminderType.thursday) {
        return 'extra_time_wednesdayIsha';
      }
      if (type == AdditionalReminderType.whiteDays) {
        return 'extra_time_hijri12Isha';
      }
    }
    return 'extra_time_$effectiveAnchor';
  }

  static String legacyAnchor(AdditionalReminderType type) => switch (type) {
    AdditionalReminderType.duha => 'afterSunrise',
    AdditionalReminderType.friday => 'beforeDhuhr',
    AdditionalReminderType.mondayThursday ||
    AdditionalReminderType.whiteDays => 'clock',
    _ => defaultAnchor(type),
  };
  static String defaultAnchor(AdditionalReminderType type) => switch (type) {
    AdditionalReminderType.duha => 'beforeDhuhr',
    AdditionalReminderType.lastThird => 'beforeLastThird',
    AdditionalReminderType.friday => 'beforeMaghrib',
    AdditionalReminderType.morning => 'afterFajr',
    AdditionalReminderType.evening => 'afterAsr',
    AdditionalReminderType.mondayThursday => 'clock',
    AdditionalReminderType.whiteDays ||
    AdditionalReminderType.bedtime ||
    AdditionalReminderType.monday ||
    AdditionalReminderType.thursday => 'afterIsha',
    AdditionalReminderType.fajrAlarm => 'beforeFajr',
    AdditionalReminderType.middleNight => 'beforeMiddleNight',
  };
  static List<String> allowedAnchors(AdditionalReminderType type) =>
      switch (type) {
        AdditionalReminderType.fajrAlarm => ['beforeFajr', 'afterFajr'],
        AdditionalReminderType.duha => ['beforeDhuhr', 'afterSunrise'],
        AdditionalReminderType.evening => ['afterAsr', 'beforeMaghrib'],
        AdditionalReminderType.friday => ['beforeMaghrib', 'beforeDhuhr'],
        AdditionalReminderType.monday ||
        AdditionalReminderType.thursday ||
        AdditionalReminderType.whiteDays => ['afterIsha', 'clock'],
        _ => [defaultAnchor(type)],
      };

  /// Confirmed against Moatheni Defaults.kt. SalaTime keeps every extra opt-in.
  factory AdditionalReminderSetting.defaults(
    AdditionalReminderType type,
  ) => AdditionalReminderSetting(
    type: type,
    sound:
        'moatheni_${switch (type) {
          AdditionalReminderType.duha => 'duha',
          AdditionalReminderType.lastThird => 'last_third',
          AdditionalReminderType.friday => 'jumaa_hour',
          AdditionalReminderType.morning => 'morning_azkar1',
          AdditionalReminderType.evening => 'evening_azkar1',
          AdditionalReminderType.mondayThursday || AdditionalReminderType.monday => 'monday_fasting',
          AdditionalReminderType.thursday => 'thursday_fasting',
          AdditionalReminderType.whiteDays => 'white_days',
          AdditionalReminderType.fajrAlarm => 'ring1',
          AdditionalReminderType.bedtime => 'sleep_azkar',
          AdditionalReminderType.middleNight => 'midnight',
        }}',
    useDefaultSound: true,
    anchor: defaultAnchor(type),
    minutes: switch (type) {
      AdditionalReminderType.fajrAlarm => 20,
      AdditionalReminderType.duha ||
      AdditionalReminderType.morning ||
      AdditionalReminderType.evening => 30,
      AdditionalReminderType.bedtime ||
      AdditionalReminderType.monday ||
      AdditionalReminderType.thursday ||
      AdditionalReminderType.whiteDays => 60,
      AdditionalReminderType.middleNight ||
      AdditionalReminderType.lastThird => 15,
      AdditionalReminderType.friday => 40,
      AdditionalReminderType.mondayThursday => 20 * 60,
    },
  );

  AdditionalReminderSetting copyWith({
    bool? enabled,
    String? sound,
    int? minutes,
    bool? useDefaultSound,
    String? anchor,
  }) => AdditionalReminderSetting(
    type: type,
    enabled: enabled ?? this.enabled,
    sound: sound ?? this.sound,
    useDefaultSound: useDefaultSound ?? (sound == null && this.useDefaultSound),
    minutes: minutes ?? this.minutes,
    anchor: anchor ?? this.anchor,
  );
  Map<String, Object> toJson() => {
    'enabled': enabled,
    'sound': sound,
    'useDefaultSound': useDefaultSound,
    'minutes': minutes,
    'anchor': effectiveAnchor,
  };
  factory AdditionalReminderSetting.fromJson(
    AdditionalReminderType type,
    Object? value,
  ) {
    final defaults = AdditionalReminderSetting.defaults(type);
    if (value is! Map) return defaults;
    final rawAnchor = value['anchor'];
    final legacyDefaultMinutes = switch (type) {
      AdditionalReminderType.duha => 20,
      AdditionalReminderType.lastThird => 0,
      AdditionalReminderType.friday => 60,
      AdditionalReminderType.morning || AdditionalReminderType.evening => 15,
      AdditionalReminderType.mondayThursday ||
      AdditionalReminderType.whiteDays => 1200,
      _ => null,
    };
    final replaceGenericDefault =
        rawAnchor == null &&
        value['sound'] == 'noti_beep' &&
        legacyDefaultMinutes != null &&
        value['minutes'] == legacyDefaultMinutes;
    final anchor = replaceGenericDefault
        ? defaults.anchor
        : rawAnchor == null
        ? legacyAnchor(type)
        : allowedAnchors(type).contains(rawAnchor)
        ? rawAnchor as String
        : defaults.anchor;
    final rawMinutes = value['minutes'];
    final rawSound = value['sound'];
    final stockSound =
        rawSound == 'noti_beep' &&
        (rawAnchor == null || !value.containsKey('useDefaultSound'));
    final validSound =
        rawSound is String &&
        (NotificationSoundCatalog.contains(rawSound) ||
            RegExp(r'^custom_[a-f0-9]{64}$').hasMatch(rawSound));
    return defaults.copyWith(
      enabled: value['enabled'] == true,
      anchor: anchor,
      minutes: replaceGenericDefault
          ? defaults.minutes
          : rawMinutes is int
          ? rawMinutes.clamp(0, anchor == 'clock' ? 1439 : 120)
          : defaults.minutes,
      sound: validSound && !stockSound ? rawSound : defaults.sound,
      useDefaultSound: stockSound
          ? true
          : value['useDefaultSound'] is bool
          ? value['useDefaultSound'] == true
          : !validSound,
    );
  }
}

class AdditionalReminderPreferences {
  static const storageKey = 'additional_reminders_v1';
  static const scheduleKey = 'additional_reminder_schedule_v1';
  static final _changes = StreamController<void>.broadcast();
  static Stream<void> get changes => _changes.stream;
  static Future<void>? _queue;

  static Future<T> _serial<T>(Future<T> Function() action) {
    final previous = _queue;
    final completion = Completer<void>();
    _queue = completion.future;
    return (() async {
      try {
        if (previous != null) await previous;
        return await action();
      } finally {
        // Drain the barrier even after a failed write. Releasing the finished
        // tail also avoids retaining a disposed widget-test event zone.
        if (identical(_queue, completion.future)) _queue = null;
        completion.complete();
      }
    })();
  }

  // Exact order of the reference application's Other notifications screen.
  static const visibleTypes = [
    AdditionalReminderType.fajrAlarm,
    AdditionalReminderType.duha,
    AdditionalReminderType.morning,
    AdditionalReminderType.evening,
    AdditionalReminderType.bedtime,
    AdditionalReminderType.monday,
    AdditionalReminderType.thursday,
    AdditionalReminderType.whiteDays,
    AdditionalReminderType.middleNight,
    AdditionalReminderType.lastThird,
    AdditionalReminderType.friday,
  ];

  static Future<List<AdditionalReminderSetting>> load([
    SharedPreferences? preferences,
  ]) => _serial(
    () async => _read(preferences ?? await SharedPreferences.getInstance()),
  );

  static List<AdditionalReminderSetting> _read(SharedPreferences prefs) {
    Map<dynamic, dynamic> json = {};
    try {
      final value = jsonDecode(prefs.getString(storageKey) ?? '{}');
      if (value is Map) json = value;
    } catch (_) {
      // A damaged preference does not unexpectedly enable a reminder.
    }
    return decode(json);
  }

  static List<AdditionalReminderSetting> decode(Map<dynamic, dynamic> raw) {
    final json = Map<dynamic, dynamic>.from(raw);
    final legacy = json['mondayThursday'];
    if (legacy is Map) {
      for (final type in [
        AdditionalReminderType.monday,
        AdditionalReminderType.thursday,
      ]) {
        if (!json.containsKey(type.name)) {
          final stock =
              legacy['sound'] == 'noti_beep' &&
              legacy['minutes'] == 1200 &&
              !legacy.containsKey('anchor');
          final useDefaults =
              stock ||
              (legacy['useDefaultSound'] == true &&
                  legacy['sound'] == 'moatheni_monday_fasting');
          json[type.name] = {
            ...legacy,
            'anchor': stock ? 'afterIsha' : 'clock',
            if (stock) 'minutes': 60,
            if (useDefaults)
              'sound': AdditionalReminderSetting.defaults(type).sound,
            if (useDefaults) 'useDefaultSound': true,
          };
        }
      }
      // Splitting keeps choices and event IDs without programming duplicates.
      json['mondayThursday'] = {...legacy, 'enabled': false};
    }
    return [
      for (final type in AdditionalReminderType.values)
        AdditionalReminderSetting.fromJson(type, json[type.name]),
    ];
  }

  static Future<void> save(
    List<AdditionalReminderSetting> settings, [
    SharedPreferences? preferences,
  ]) {
    // Capture the requested replacement before it waits behind other edits.
    final snapshot = List<AdditionalReminderSetting>.of(settings);
    return _serial(() async {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      await _write(prefs, snapshot);
    });
  }

  static Future<AdditionalReminderSetting> update(
    AdditionalReminderType type, {
    bool? enabled,
    String? sound,
    int? minutes,
    String? anchor,
    bool? useDefaultSound,
  }) => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    final current = _read(prefs);
    final previous = current.firstWhere((item) => item.type == type);
    final setting = AdditionalReminderSetting.fromJson(
      type,
      previous
          .copyWith(
            enabled: enabled,
            sound: sound,
            minutes: minutes,
            anchor: anchor,
            useDefaultSound: useDefaultSound,
          )
          .toJson(),
    );
    await _write(prefs, [
      for (final item in current) item.type == type ? setting : item,
    ]);
    return setting;
  });

  /// Toggle the whole series in one write against the latest saved settings.
  /// The retired combined fasting reminder must never be enabled alongside
  /// its separate Monday and Thursday replacements.
  static Future<void> setEnabled(bool enabled) => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    final current = _read(prefs);
    await _write(prefs, [
      for (final setting in current)
        setting.copyWith(
          enabled: enabled && visibleTypes.contains(setting.type),
        ),
    ]);
  });

  static Future<void> _write(
    SharedPreferences prefs,
    List<AdditionalReminderSetting> settings,
  ) async {
    try {
      if (!await prefs.setString(
        storageKey,
        jsonEncode({
          for (final setting in settings) setting.type.name: setting.toJson(),
        }),
      )) {
        throw StateError('Could not save reminder settings');
      }
    } catch (_) {
      // SharedPreferences updates its memory cache before the disk result.
      // Restore that cache so the UI can recover the persisted choices.
      try {
        await prefs.reload();
      } catch (_) {
        // Preserve the original write failure if the storage is unavailable.
      }
      rethrow;
    }
    _changes.add(null);
  }
}

class PlannedAdditionalReminder {
  const PlannedAdditionalReminder(this.setting, this.date, this.time);
  final AdditionalReminderSetting setting;
  final String date;
  final tz.TZDateTime time;
  int get id {
    final day = DateTime.parse(date);
    final dayNumber =
        DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    // Never change the legacy stride: eleven visible kinds exceed its ten slots.
    // Monday and Thursday reuse their old shared slot on distinct event dates.
    final (bank, slot) = switch (setting.type) {
      AdditionalReminderType.duha => (20000000, 0),
      AdditionalReminderType.lastThird => (20000000, 1),
      AdditionalReminderType.friday => (20000000, 2),
      AdditionalReminderType.morning => (20000000, 3),
      AdditionalReminderType.evening => (20000000, 4),
      AdditionalReminderType.mondayThursday ||
      AdditionalReminderType.monday ||
      AdditionalReminderType.thursday => (20000000, 5),
      AdditionalReminderType.whiteDays => (20000000, 6),
      AdditionalReminderType.fajrAlarm => (21000000, 0),
      AdditionalReminderType.bedtime => (21000000, 1),
      AdditionalReminderType.middleNight => (21000000, 2),
    };
    return bank + dayNumber * 10 + slot;
  }

  Map<String, Object> toJson() => {
    'id': id,
    'date': date,
    'at': time.millisecondsSinceEpoch,
    'zone': time.location.name,
    'kind': 'extra_reminder',
    'type': setting.type.name,
  };
}

List<PlannedAdditionalReminder> buildAdditionalReminderPlan({
  required List<Data> days,
  required tz.Location zone,
  required DateTime now,
  required List<AdditionalReminderSetting> settings,
  Map<String, int> adjustments = const {},
  int hijriAdjustment = 0,
}) {
  final result = <int, PlannedAdditionalReminder>{};
  final dates = <String, List<PrayerOccurrence>>{};
  String key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  for (final day in days) {
    final prayers = PrayerOccurrence.fromDay(day, zone, adjustments);
    if (prayers.length == 5) dates[day.date!] = prayers;
  }
  for (final day in days) {
    final date = DateTime.tryParse(day.date ?? '');
    if (date == null) continue;
    final prayers = dates[day.date];
    if (prayers == null) continue;
    final previous = dates[key(DateTime(date.year, date.month, date.day - 1))];
    for (final setting in settings.where((item) => item.enabled)) {
      tz.TZDateTime? at;
      final offset = Duration(minutes: setting.minutes);
      final anchor = setting.effectiveAnchor;
      switch (setting.type) {
        case AdditionalReminderType.duha:
          final sunrise = day.sunrise;
          if (sunrise != null &&
              RegExp(r'^(?:[01]?\d|2[0-3]):[0-5]\d$').hasMatch(sunrise)) {
            final clock = sunrise.split(':').map(int.parse).toList();
            final sunriseTime = tz.TZDateTime(
              zone,
              date.year,
              date.month,
              date.day,
              clock[0],
              clock[1],
            ).add(Duration(minutes: adjustments['sunrise'] ?? 0));
            at = anchor == 'beforeDhuhr'
                ? prayers[1].time.subtract(offset)
                : sunriseTime.add(offset);
            // The reference specifies the usable window: sunrise +20 to Dhuhr -15.
            if (at.isBefore(sunriseTime.add(const Duration(minutes: 20))) ||
                at.isAfter(
                  prayers[1].time.subtract(const Duration(minutes: 15)),
                )) {
              at = null;
            }
          }
        case AdditionalReminderType.lastThird:
        case AdditionalReminderType.middleNight:
          if (previous != null) {
            final sunset = previous[3].time;
            final night = calculatePrayerNight(
              previousMaghrib: sunset,
              fajr: prayers[0].time,
            );
            if (night != null) {
              at =
                  (setting.type == AdditionalReminderType.middleNight
                          ? night.middle
                          : night.lastThird)
                      .subtract(offset);
              if (at.isBefore(sunset)) at = null;
            }
          }
        case AdditionalReminderType.fajrAlarm:
          at = anchor == 'afterFajr'
              ? prayers[0].time.add(offset)
              : prayers[0].time.subtract(offset);
        case AdditionalReminderType.bedtime:
          at = prayers[4].time.add(offset);
        case AdditionalReminderType.friday:
          if (date.weekday == DateTime.friday) {
            at = (anchor == 'beforeDhuhr' ? prayers[1].time : prayers[3].time)
                .subtract(offset);
          }
        case AdditionalReminderType.morning:
          at = prayers[0].time.add(offset);
        case AdditionalReminderType.evening:
          at = anchor == 'beforeMaghrib'
              ? prayers[3].time.subtract(offset)
              : prayers[2].time.add(offset);
        case AdditionalReminderType.mondayThursday:
        case AdditionalReminderType.monday:
        case AdditionalReminderType.thursday:
        case AdditionalReminderType.whiteDays:
          final hijri = HijriCalendar.fromDate(
            DateTime(
              date.year,
              date.month,
              date.day + hijriAdjustment.clamp(-2, 2),
            ),
          );
          final eligible = switch (setting.type) {
            AdditionalReminderType.monday => date.weekday == DateTime.monday,
            AdditionalReminderType.thursday =>
              date.weekday == DateTime.thursday,
            AdditionalReminderType.mondayThursday =>
              date.weekday == DateTime.monday ||
                  date.weekday == DateTime.thursday,
            _ =>
              anchor == 'clock'
                  ? hijri.hDay >= 13 && hijri.hDay <= 15
                  : hijri.hDay == 13,
          };
          final excluded =
              (hijri.hMonth == 10 && hijri.hDay == 1) ||
              (hijri.hMonth == 12 && hijri.hDay >= 10 && hijri.hDay <= 13);
          if (eligible && !excluded) {
            at = anchor == 'clock'
                ? tz.TZDateTime(
                    zone,
                    date.year,
                    date.month,
                    date.day - 1,
                    setting.minutes ~/ 60,
                    setting.minutes % 60,
                  )
                : previous?[4].time.add(offset);
          }
      }
      if (at != null && at.isAfter(now)) {
        final event = PlannedAdditionalReminder(setting, day.date!, at);
        result[event.id] = event;
      }
    }
  }
  return result.values.toList()..sort((a, b) => a.time.compareTo(b.time));
}

/// A single chronological budget for prayers and optional reminders.
Set<int> selectReminderAlarmIds({
  required Iterable<({int id, DateTime time})> candidates,
  required int limit,
}) {
  final unique =
      <int, ({int id, DateTime time})>{
        for (final candidate in candidates) candidate.id: candidate,
      }.values.toList()..sort((a, b) {
        final timeOrder = a.time.compareTo(b.time);
        return timeOrder != 0 ? timeOrder : a.id.compareTo(b.id);
      });
  return unique.take(limit.clamp(0, 450)).map((item) => item.id).toSet();
}

({tz.TZDateTime middle, tz.TZDateTime lastThird})? calculatePrayerNight({
  required tz.TZDateTime previousMaghrib,
  required tz.TZDateTime fajr,
}) {
  final night = fajr.difference(previousMaghrib);
  if (night <= Duration.zero || night >= const Duration(hours: 24)) return null;
  return (
    middle: previousMaghrib.add(
      Duration(microseconds: night.inMicroseconds ~/ 2),
    ),
    lastThird: previousMaghrib.add(
      Duration(microseconds: night.inMicroseconds * 2 ~/ 3),
    ),
  );
}
