import 'package:salatime/helper/prayer_calculation_methods.dart';
import 'package:salatime/helper/notification_sound_catalog.dart';
import 'package:salatime/helper/additional_reminder_plan.dart';
import 'package:salatime/helper/prayer_notification_preferences.dart';

/// Explicit, versioned allow-list. Device permissions, tokens, locations and file
/// paths never enter this document, even if supplied by a restored backup.
class PreferenceSchema {
  static const languages = {
    'en',
    'fr',
    'ar',
    'tr',
    'ur',
    'id',
    'ms',
    'es',
    'bn',
    'fa',
  };
  static final methods = PrayerCalculationMethods.ids;
  static const fonts = {
    'Scheherazade New',
    'Amiri',
    'AmiriQuran',
    'Lateef',
    'NotoKufiArabic',
    'NotoNaskhArabic',
    'NotoNastaliqUrdu',
    'NotoSansArabic',
    'ReadexPro',
  };
  static Set<String> get bundled => NotificationSoundCatalog.keys;
  static const extraTypes = {
    'duha',
    'lastThird',
    'friday',
    'morning',
    'evening',
    'mondayThursday',
    'whiteDays',
    'fajrAlarm',
    'bedtime',
    'middleNight',
    'monday',
    'thursday',
  };
  static const extraAnchors = <String, Set<String>>{
    'fajrAlarm': {'beforeFajr', 'afterFajr'},
    'duha': {'beforeDhuhr', 'afterSunrise'},
    'morning': {'afterFajr'},
    'evening': {'afterAsr', 'beforeMaghrib'},
    'bedtime': {'afterIsha'},
    'monday': {'afterIsha', 'clock'},
    'thursday': {'afterIsha', 'clock'},
    'whiteDays': {'afterIsha', 'clock'},
    'mondayThursday': {'clock'},
    'middleNight': {'beforeMiddleNight'},
    'lastThird': {'beforeLastThird'},
    'friday': {'beforeMaghrib', 'beforeDhuhr'},
  };
  static int extraMinutesMax(String type, Map raw) =>
      raw['anchor'] == 'clock' && extraAnchors[type]!.contains('clock') ||
          !raw.containsKey('anchor') &&
              {'mondayThursday', 'whiteDays'}.contains(type)
      ? 1439
      : 120;
  static const prayerPhases = {'before', 'adhan', 'after'};
  static const notificationPrayers = {
    'fajr',
    'sunrise',
    'dhuhr',
    'jumaa',
    'asr',
    'maghrib',
    'isha',
  };
  static String prayerSound(String phase, String prayer) =>
      PrayerNotificationSetting.defaults(
        PrayerNotificationPrayer.values.byName(prayer),
        PrayerNotificationPhase.values.byName(phase),
      ).sound;
  static String extraSound(String type) => AdditionalReminderSetting.defaults(
    AdditionalReminderType.values.byName(type),
  ).sound;
  static String sound(Object? value, [String fallback = 'noti_beep']) =>
      bundled.contains(value) ? value as String : fallback;

  static Map<String, dynamic> clean(Object? value) {
    if (value is! Map) return {};
    final out = <String, dynamic>{};
    void choice(String key, Set<String> choices) {
      if (choices.contains(value[key])) out[key] = value[key];
    }

    void integer(String key, int min, int max) {
      final n = value[key];
      if (n is int && n >= min && n <= max) out[key] = n;
    }

    void boolean(String key) {
      if (value[key] is bool) out[key] = value[key];
    }

    if (value['schemaVersion'] == 1) out['schemaVersion'] = 1;
    choice('themeMode', {'light', 'dark', 'daylight'});
    choice('language', languages);
    if (value['country'] is String &&
        RegExp(r'^[A-Z]{2}$').hasMatch(value['country'])) {
      out['country'] = value['country'];
    }
    choice('homeLayout', {'modern', 'classic'});
    boolean('use24HourFormat');
    choice('calculationMethod', methods);
    choice('madhab', {'STANDARD', 'HANAFI'});
    integer('hijriOffset', -2, 2);
    Map<String, dynamic> group(
      String key,
      Map<String, bool Function(dynamic)> rules,
    ) {
      final raw = value[key];
      final result = <String, dynamic>{};
      if (raw is Map) {
        for (final entry in rules.entries) {
          if (raw.containsKey(entry.key) && entry.value(raw[entry.key])) {
            result[entry.key] = raw[entry.key];
          }
        }
      }
      if (result.isNotEmpty || raw is Map && raw.isEmpty) out[key] = result;
      return result;
    }

    bool b(dynamic x) => x is bool;
    bool i(dynamic x, int min, int max) => x is int && x >= min && x <= max;
    group('prayerAdjustments', {
      for (final k in [
        'fajr',
        'sunrise',
        'zuhr',
        'asr',
        'maghrib',
        'isha',
        'sehri',
        'iftar',
      ])
        k: (x) => i(x, -120, 120),
    });
    group('prayerNotifications', {
      for (final k in ['1', '2', '3', '4', '5']) k: b,
    });
    final prayerSettings = value['prayerNotificationSettings'];
    if (prayerSettings is Map) {
      final phases = <String, dynamic>{};
      for (final phase in prayerPhases) {
        final rows = prayerSettings[phase];
        if (rows is! Map) continue;
        final prayers = <String, dynamic>{};
        for (final prayer in notificationPrayers) {
          final raw = rows[prayer];
          if (raw is! Map) continue;
          prayers[prayer] = {
            if (raw['enabled'] is bool) 'enabled': raw['enabled'],
            if (raw.containsKey('sound'))
              'sound': sound(raw['sound'], prayerSound(phase, prayer)),
            if (i(raw['minutes'], 0, phase == 'adhan' ? 0 : 120))
              'minutes': raw['minutes'],
          };
        }
        phases[phase] = prayers;
      }
      out['prayerNotificationSettings'] = phases;
    }
    group('reminders', {
      'beforeEnabled': b,
      'afterEnabled': b,
      'beforeMinutes': (x) => i(x, 1, 60),
      'afterMinutes': (x) => i(x, 1, 60),
    });
    group('widgets', {
      for (final k in ['countdown', 'seconds', 'city', 'date', 'illustration'])
        k: b,
      'opacity': (x) => i(x, 0, 100),
    });
    final silence = group('silence', {
      'enabled': b,
      'delay': (x) => i(x, 0, 60),
      'duration': (x) => i(x, 5, 120),
      'fridayDuration': (x) => i(x, 5, 120),
      'fridayOverride': b,
      'prayers': (x) =>
          x is List && x.length <= 5 && x.every((n) => i(n, 1, 5)),
    });
    if (silence['prayers'] is List) {
      silence['prayers'] = (silence['prayers'] as List).toSet().toList()
        ..sort();
    }
    group('reader', {
      'arabicSize': (x) => x is num && x.isFinite && x >= 10 && x <= 64,
      'translationSize': (x) => x is num && x.isFinite && x >= 10 && x <= 64,
      'font': (x) => fonts.contains(x),
      'translator': (x) => x is String && RegExp(r'^\d{1,5}$').hasMatch(x),
      'translation': (x) =>
          x is String &&
          x.length <= 100 &&
          !x.contains('://') &&
          !x.contains('/'),
      'goal': (x) => i(x, 1, 1000),
    });
    final sounds = value['sounds'];
    if (sounds is Map) {
      out['sounds'] = {
        for (final k in ['adhan', 'before', 'after'])
          if (sounds.containsKey(k))
            k: sound(sounds[k], k == 'adhan' ? 'azan_2' : 'noti_beep'),
      };
    }
    final extras = value['additionalReminders'];
    if (extras is Map) {
      out['additionalReminders'] = <String, dynamic>{};
      for (final k in extraTypes) {
        final raw = extras[k];
        if (raw is! Map) continue;
        out['additionalReminders'][k] = {
          if (raw['enabled'] is bool) 'enabled': raw['enabled'],
          if (raw.containsKey('sound'))
            'sound': sound(raw['sound'], extraSound(k)),
          if (raw['useDefaultSound'] is bool)
            'useDefaultSound': raw['useDefaultSound'],
          if (extraAnchors[k]!.contains(raw['anchor'])) 'anchor': raw['anchor'],
          if (i(raw['minutes'], 0, extraMinutesMax(k, raw)))
            'minutes': raw['minutes'],
        };
      }
    }
    return out;
  }

  static Map<String, dynamic> flatten(
    Map<String, dynamic> source, [
    String prefix = '',
  ]) {
    final out = <String, dynamic>{};
    for (final e in source.entries) {
      final key = prefix.isEmpty ? e.key : '$prefix.${e.key}';
      if (e.value is Map) {
        if ((e.value as Map).isEmpty) {
          // Preserve explicit reset markers, including an empty override map.
          out[key] = <String, dynamic>{};
        } else {
          out.addAll(flatten(Map<String, dynamic>.from(e.value), key));
        }
      } else {
        out[key] = e.value;
      }
    }
    return out;
  }

  static Map<String, dynamic> expand(Map<String, dynamic> flat) {
    final out = <String, dynamic>{};
    for (final e in flat.entries) {
      final path = e.key.split('.');
      var target = out;
      for (final key in path.take(path.length - 1)) {
        target =
            target.putIfAbsent(key, () => <String, dynamic>{})
                as Map<String, dynamic>;
      }
      if (e.value is Map && (e.value as Map).isEmpty) {
        // A concurrent child edit can coexist with a parent reset marker.
        target.putIfAbsent(path.last, () => <String, dynamic>{});
      } else {
        target[path.last] = e.value;
      }
    }
    return out;
  }
}
