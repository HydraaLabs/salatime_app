import 'dart:convert';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/helper/notification_sound_catalog.dart';
import 'package:salatime/util/app_constants.dart';

enum PrayerNotificationPrayer {
  fajr,
  sunrise,
  dhuhr,
  jumaa,
  asr,
  maghrib,
  isha;

  String get titleKey => switch (this) {
    jumaa => 'jumuah',
    maghrib => 'magrib',
    _ => name,
  };
  // Jumaa replaces Dhuhr's occurrence; sunrise owns a distinct notification ID.
  int get legacyId => switch (this) {
    fajr => 1,
    dhuhr || jumaa => 2,
    asr => 3,
    maghrib => 4,
    isha => 5,
    sunrise => 6,
  };
  static PrayerNotificationPrayer fromLegacyId(int id, {DateTime? date}) =>
      switch (id) {
        1 => fajr,
        2 => date?.weekday == DateTime.friday ? jumaa : dhuhr,
        3 => asr,
        4 => maghrib,
        5 => isha,
        6 => sunrise,
        _ => throw ArgumentError.value(id, 'id'),
      };
}

enum PrayerNotificationPhase {
  before,
  adhan,
  after;

  String get titleKey => switch (this) {
    before => 'before_adhan',
    adhan => 'adhan',
    after => 'after_adhan',
  };
}

class PrayerNotificationSetting {
  const PrayerNotificationSetting({
    required this.prayer,
    required this.phase,
    required this.enabled,
    required this.sound,
    required this.minutes,
  });
  final PrayerNotificationPrayer prayer;
  final PrayerNotificationPhase phase;
  final bool enabled;
  final String sound;
  final int minutes;

  factory PrayerNotificationSetting.defaults(
    PrayerNotificationPrayer prayer,
    PrayerNotificationPhase phase,
  ) => PrayerNotificationSetting(
    prayer: prayer,
    phase: phase,
    enabled: prayer != PrayerNotificationPrayer.sunrise,
    sound: defaultSound(prayer, phase),
    minutes: switch (phase) {
      PrayerNotificationPhase.before => switch (prayer) {
        PrayerNotificationPrayer.jumaa => 120,
        PrayerNotificationPrayer.maghrib => 10,
        _ => 5,
      },
      PrayerNotificationPhase.adhan => 0,
      PrayerNotificationPhase.after =>
        prayer == PrayerNotificationPrayer.maghrib ? 3 : 10,
    },
  );

  static String defaultSound(
    PrayerNotificationPrayer prayer,
    PrayerNotificationPhase phase,
  ) {
    if (prayer == PrayerNotificationPrayer.sunrise) {
      return switch (phase) {
        PrayerNotificationPhase.before => 'moatheni_water',
        PrayerNotificationPhase.adhan => 'moatheni_bird',
        PrayerNotificationPhase.after => 'moatheni_short_sound',
      };
    }
    if (prayer == PrayerNotificationPrayer.jumaa &&
        phase == PrayerNotificationPhase.after) {
      return 'moatheni_short_sound';
    }
    return 'moatheni_${phase == PrayerNotificationPhase.adhan ? 'on' : phase.name}_prayer_${prayer.name}';
  }

  PrayerNotificationSetting copyWith({
    bool? enabled,
    String? sound,
    int? minutes,
  }) => PrayerNotificationSetting(
    prayer: prayer,
    phase: phase,
    enabled: enabled ?? this.enabled,
    sound: sound ?? this.sound,
    minutes: minutes ?? this.minutes,
  );
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'sound': sound,
    'minutes': minutes,
  };

  factory PrayerNotificationSetting.fromJson(
    PrayerNotificationPrayer prayer,
    PrayerNotificationPhase phase,
    Object? value,
  ) {
    final defaults = PrayerNotificationSetting.defaults(prayer, phase);
    if (value is! Map) return defaults;
    final sound = value['sound'];
    final minutes = value['minutes'];
    return defaults.copyWith(
      enabled: value['enabled'] is bool ? value['enabled'] as bool : null,
      sound: sound is String && PrayerNotificationPreferences.validSound(sound)
          ? sound
          : null,
      minutes: phase == PrayerNotificationPhase.adhan
          ? 0
          : minutes is int
          ? minutes.clamp(0, 120)
          : null,
    );
  }
}

/// Once migrated, this document alone controls prayer notifications. Legacy
/// global controls must call the explicit setters below instead of writing old keys.
class PrayerNotificationPreferences {
  static const storageKey = 'prayer_notifications_v2';
  static final _changes = StreamController<void>.broadcast();
  static Stream<void> get changes => _changes.stream;
  static Future<void>? _queue;
  static const _genericSounds = {
    'azan_1',
    'azan_2',
    'azan_3',
    'noti_1',
    'noti_beep',
    'noti_beep_beep',
  };
  static bool validSound(String key) =>
      NotificationSoundCatalog.contains(key) ||
      RegExp(r'^custom_[a-f0-9]{64}$').hasMatch(key);

  static Future<T> _serial<T>(Future<T> Function() action) {
    final previous = _queue;
    final completion = Completer<void>();
    _queue = completion.future;
    return (() async {
      try {
        if (previous != null) await previous;
        return await action();
      } finally {
        // Release the active barrier before completing the caller's future.
        // Keeping an orphaned completed tail can retain a disposed event zone.
        if (identical(_queue, completion.future)) _queue = null;
        completion.complete();
      }
    })();
  }

  static Map<String, dynamic> _decode(String? value) {
    try {
      final json = jsonDecode(value ?? '{}');
      return json is Map ? Map<String, dynamic>.from(json) : {};
    } catch (_) {
      return {};
    }
  }

  static Map<String, dynamic> _clean(Map<String, dynamic> raw) => {
    for (final phase in PrayerNotificationPhase.values)
      if (raw[phase.name] is Map)
        phase.name: {
          for (final prayer in PrayerNotificationPrayer.values)
            if ((raw[phase.name] as Map)[prayer.name] is Map)
              prayer.name: PrayerNotificationSetting.fromJson(
                prayer,
                phase,
                raw[phase.name][prayer.name],
              ).toJson(),
        },
  };
  static Future<void> _write(
    SharedPreferences prefs,
    Map<String, dynamic> values,
  ) async {
    try {
      if (!await prefs.setString(storageKey, jsonEncode(values))) {
        throw StateError('Prayer notification settings could not be saved');
      }
    } catch (_) {
      // SharedPreferences updates its cache before the platform confirms the
      // write. Do not display a category as disabled if persistence failed.
      try {
        await prefs.reload();
      } catch (_) {
        // Preserve the original write failure for the caller's error state.
      }
      rethrow;
    }
    _changes.add(null);
  }

  static Future<Map<String, dynamic>> _migrated(SharedPreferences prefs) async {
    if (prefs.containsKey(storageKey)) {
      return _clean(_decode(prefs.getString(storageKey)));
    }
    final legacyEnabled = <int, bool>{};
    try {
      final rows = jsonDecode(prefs.getString('salat_waqt') ?? '[]');
      if (rows is List) {
        for (final row in rows) {
          final data = row is String ? jsonDecode(row) : row;
          if (data is Map &&
              data['id'] is int &&
              data['isNotificationEnabled'] is bool) {
            legacyEnabled[data['id']] = data['isNotificationEnabled'];
          }
        }
      }
    } catch (_) {
      /* Invalid legacy data falls back to the reference defaults. */
    }
    final result = <String, dynamic>{};
    for (final phase in PrayerNotificationPhase.values) {
      final enabledKey = phase == PrayerNotificationPhase.before
          ? AppConstants.BEFORE_ADHAN_REMINDER_ENABLED_KEY
          : AppConstants.AFTER_ADHAN_REMINDER_ENABLED_KEY;
      final minutesKey = phase == PrayerNotificationPhase.before
          ? AppConstants.BEFORE_ADHAN_REMINDER_MINUTES_KEY
          : AppConstants.AFTER_ADHAN_REMINDER_MINUTES_KEY;
      final soundKey = switch (phase) {
        PrayerNotificationPhase.before =>
          AppConstants.BEFORE_ADHAN_REMINDER_SOUND_KEY,
        PrayerNotificationPhase.adhan =>
          AppConstants.SELECTED_NOTIFICATION_SOUND_KEY,
        PrayerNotificationPhase.after =>
          AppConstants.AFTER_ADHAN_REMINDER_SOUND_KEY,
      };
      final oldSound = prefs.getString(soundKey);
      final hasPersonalChoice =
          oldSound != null &&
          validSound(oldSound) &&
          !_genericSounds.contains(oldSound);
      for (final prayer in PrayerNotificationPrayer.values) {
        final defaults = PrayerNotificationSetting.defaults(prayer, phase);
        final wasEnabled =
            prayer != PrayerNotificationPrayer.sunrise &&
            (legacyEnabled[prayer.legacyId] ?? true);
        final setting = defaults.copyWith(
          // The replacement notification setup adopts the reference's enabled
          // defaults. Keep intentional legacy sound customizations and their
          // activation choices; future v2 choices are never migrated again.
          enabled: !hasPersonalChoice
              ? defaults.enabled
              : phase == PrayerNotificationPhase.adhan
              ? wasEnabled
              : wasEnabled && (prefs.getBool(enabledKey) ?? false),
          sound:
              prayer != PrayerNotificationPrayer.sunrise &&
                  oldSound != null &&
                  validSound(oldSound) &&
                  !_genericSounds.contains(oldSound)
              ? oldSound
              : null,
          minutes: phase == PrayerNotificationPhase.adhan
              ? 0
              : prayer == PrayerNotificationPrayer.sunrise
              ? null
              : (oldSound == null || _genericSounds.contains(oldSound)) &&
                    prefs.getInt(minutesKey) ==
                        AppConstants.DEFAULT_PRAYER_REMINDER_MINUTES
              ? null
              : prefs.getInt(minutesKey)?.clamp(0, 120),
        );
        if (jsonEncode(setting.toJson()) != jsonEncode(defaults.toJson())) {
          (result[phase.name] ??= <String, dynamic>{})[prayer.name] = setting
              .toJson();
        }
      }
    }
    await _write(prefs, result);
    return result;
  }

  static Future<Map<String, dynamic>> loadOverrides([
    SharedPreferences? prefs,
  ]) => _serial(() async {
    final values = await _migrated(
      prefs ?? await SharedPreferences.getInstance(),
    );
    return _decode(jsonEncode(values));
  });
  static Future<List<PrayerNotificationSetting>> load([
    SharedPreferences? prefs,
  ]) async {
    final values = await loadOverrides(prefs);
    return [
      for (final phase in PrayerNotificationPhase.values)
        for (final prayer in PrayerNotificationPrayer.values)
          PrayerNotificationSetting.fromJson(
            prayer,
            phase,
            values[phase.name]?[prayer.name],
          ),
    ];
  }

  /// Only for restoring a pre-v2 cloud document after its legacy fields were applied.
  static Future<void> remigrateLegacy([SharedPreferences? preferences]) =>
      _serial(() async {
        final prefs = preferences ?? await SharedPreferences.getInstance();
        if (!await prefs.remove(storageKey)) {
          throw StateError('Could not migrate legacy prayer notifications');
        }
        await _migrated(prefs);
      });

  static Future<void> replaceOverrides(
    Map<String, dynamic> values, [
    SharedPreferences? prefs,
  ]) => _serial(() async {
    await _write(
      prefs ?? await SharedPreferences.getInstance(),
      _clean(values),
    );
  });
  static Future<void> save(PrayerNotificationSetting setting) =>
      _serial(() async {
        final prefs = await SharedPreferences.getInstance();
        final values = await _migrated(prefs);
        (values[setting.phase.name] ??= <String, dynamic>{})[setting
            .prayer
            .name] = PrayerNotificationSetting.fromJson(
          setting.prayer,
          setting.phase,
          setting.toJson(),
        ).toJson();
        await _write(prefs, values);
      });
  static Future<PrayerNotificationSetting> update(
    PrayerNotificationPrayer prayer,
    PrayerNotificationPhase phase, {
    bool? enabled,
    String? sound,
    int? minutes,
  }) => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    final values = await _migrated(prefs);
    final current = PrayerNotificationSetting.fromJson(
      prayer,
      phase,
      values[phase.name]?[prayer.name],
    );
    final setting = PrayerNotificationSetting.fromJson(
      prayer,
      phase,
      current
          .copyWith(enabled: enabled, sound: sound, minutes: minutes)
          .toJson(),
    );
    (values[phase.name] ??= <String, dynamic>{})[prayer.name] = setting
        .toJson();
    await _write(prefs, values);
    return setting;
  });

  static Future<void> setPrayerAdhanEnabled(
    PrayerNotificationPrayer prayer,
    bool enabled,
  ) => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    final values = await _migrated(prefs);
    const phase = PrayerNotificationPhase.adhan;
    final setting = PrayerNotificationSetting.fromJson(
      prayer,
      phase,
      values[phase.name]?[prayer.name],
    );
    (values[phase.name] ??= <String, dynamic>{})[prayer.name] = setting
        .copyWith(enabled: enabled)
        .toJson();
    await _write(prefs, values);
  });
  static Future<void> setPhaseEnabled(
    PrayerNotificationPhase phase,
    bool enabled,
  ) => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    final values = await _migrated(prefs);
    for (final prayer in PrayerNotificationPrayer.values) {
      if (enabled && prayer == PrayerNotificationPrayer.sunrise) continue;
      final setting = PrayerNotificationSetting.fromJson(
        prayer,
        phase,
        values[phase.name]?[prayer.name],
      );
      (values[phase.name] ??= <String, dynamic>{})[prayer.name] = setting
          .copyWith(enabled: enabled)
          .toJson();
    }
    await _write(prefs, values);
  });
}
