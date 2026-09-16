import 'dart:convert';

import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'islamic_calendar.dart';

/// An explicit local-calendar option; the calculation method stays authoritative
/// unless the user chooses a fixed interval for Ramadan nights.
class RamadanIshaSettings {
  static const storageKey = 'ramadan_isha_interval_v1';
  static const intervalRequestKey = 'ramadan_isha_interval';
  static const hijriOffsetRequestKey = 'ramadan_isha_hijri_offset';
  static const maghribAdjustmentRequestKey = 'ramadan_isha_maghrib_adjustment';

  static int _interval(Object? value) =>
      value is int && (value == 90 || value == 120) ? value : 0;

  static int read(SharedPreferences prefs) => _interval(prefs.get(storageKey));

  static Future<void> setInterval(int value) async {
    if (value != 0 && value != 90 && value != 120) {
      throw ArgumentError.value(
        value,
        'value',
        'Expected 0, 90 or 120 minutes',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    final previous = read(prefs);
    final hadPrevious = prefs.containsKey(storageKey);
    try {
      if (!await prefs.setInt(storageKey, value)) {
        throw StateError('Could not save the Ramadan Isha interval');
      }
    } catch (_) {
      // SharedPreferences updates its memory cache before the platform write.
      if (prefs.get(storageKey) == value) {
        try {
          if (hadPrevious) {
            await prefs.setInt(storageKey, previous);
          } else {
            await prefs.remove(storageKey);
          }
        } catch (_) {
          // Report the original failure to the settings screen.
        }
      }
      rethrow;
    }
  }

  static int _maghribAdjustment(Object? saved) {
    if (saved is! String) return 0;
    try {
      final decoded = jsonDecode(saved);
      final value = decoded is Map ? decoded['maghrib'] : null;
      return value is int && value >= -120 && value <= 120 ? value : 0;
    } on FormatException {
      return 0;
    }
  }

  /// Call at calculation time so changes to either correction are reflected in
  /// the screen, widgets and the whole notification reserve on the same refresh.
  static Map<String, dynamic> enrichRequest(
    Map<String, dynamic> request,
    SharedPreferences prefs,
  ) {
    if (request['type'] != 'automatic') return Map.of(request);
    final offset = prefs.get(IslamicCalendarPreferences.storageKey);
    return {
      ...request,
      intervalRequestKey: read(prefs),
      hijriOffsetRequestKey: offset is int ? offset.clamp(-2, 2) : 0,
      maghribAdjustmentRequestKey: _maghribAdjustment(
        prefs.get('prayerAdjustments'),
      ),
    };
  }

  static DateTime ishaForNight({
    required Map<String, dynamic> request,
    required DateTime civilDate,
    required DateTime maghrib,
    required DateTime calculatedIsha,
  }) {
    if (request['type'] != 'automatic') return calculatedIsha;
    final interval = _interval(request[intervalRequestKey]);
    if (interval == 0) return calculatedIsha;
    final rawOffset = request[hijriOffsetRequestKey];
    final offset = rawOffset is int ? rawOffset.clamp(-2, 2) : 0;
    // The night begins at Maghrib: the evening before Ramadan 1 belongs to
    // Ramadan, while the evening before Shawwal 1 already belongs to Eid.
    final nextDay = DateTime(
      civilDate.year,
      civilDate.month,
      civilDate.day + 1 + offset,
    );
    try {
      if (HijriCalendar.fromDate(nextDay).hMonth != 9) return calculatedIsha;
    } on Exception {
      return calculatedIsha;
    } on ArgumentError {
      return calculatedIsha;
    }
    final correction = request[maghribAdjustmentRequestKey];
    final minutes = correction is int && correction >= -120 && correction <= 120
        ? correction
        : 0;
    // `maghrib` already contains the method's own correction. Personal Isha
    // correction is applied later by the existing display/alarm pipeline once.
    return maghrib.add(Duration(minutes: interval + minutes));
  }
}
