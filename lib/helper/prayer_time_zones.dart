import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/timezone/iana.dart' as iana;

/// One clock source for calculation, prayer occurrences and widget epochs.
/// Device-local rules come from the OS, so an OS timezone update does not have
/// to wait for an app release. Other zones retain the bundled IANA rules.
class PrayerTimeZones {
  static bool _initialized = false;
  static String? _deviceZone;
  static final _deviceLocations = <int, tz.Location>{};

  static void initialize() {
    if (_initialized) return;
    iana.initializeTimeZones();
    _initialized = true;
  }

  static Future<String> refreshDeviceZone() async {
    initialize();
    final name = await FlutterTimezone.getLocalTimezone();
    // Unit tests running on a desktop can mock an IANA name without changing
    // their host clock. Only mobile devices use the native clock source.
    _deviceZone = !kIsWeb && (Platform.isAndroid || Platform.isIOS)
        ? name
        : null;
    _deviceLocations.clear();
    return name;
  }

  static tz.Location location(String name, {DateTime? date}) {
    initialize();
    if (name != _deviceZone) return tz.getLocation(name);
    final year = (date ?? DateTime.now()).year;
    return _deviceLocations.putIfAbsent(
      year,
      () =>
          deviceLocation(name, year, localTime: (instant) => instant.toLocal()),
    );
  }

  /// Read each date's native offset, including future DST transitions. Using
  /// today's offset for the whole notification window would recreate the bug.
  /// The caller caches this bounded calendar and rebuilds it on every refresh.
  static tz.Location deviceLocation(
    String name,
    int year, {
    required DateTime Function(DateTime instant) localTime,
  }) {
    final start = DateTime.utc(year - 1).millisecondsSinceEpoch;
    final end = DateTime.utc(year + 2).millisecondsSinceEpoch;
    final transitions = <int>[start];
    final indexes = <int>[0];
    final zones = <tz.TimeZone>[];
    tz.TimeZone at(int instant) {
      final local = localTime(
        DateTime.fromMillisecondsSinceEpoch(instant, isUtc: true),
      );
      return tz.TimeZone(
        local.timeZoneOffset.inMilliseconds,
        isDst: false,
        abbreviation: local.timeZoneName,
      );
    }

    var previous = at(start);
    zones.add(previous);
    const step = Duration.millisecondsPerHour * 6;
    for (var instant = start + step; instant <= end; instant += step) {
      final current = at(instant);
      if (current.offset == previous.offset &&
          current.abbreviation == previous.abbreviation) {
        continue;
      }
      var low = instant - step;
      var high = instant;
      while (high - low > 1000) {
        final middle = ((low + high) ~/ 2000) * 1000;
        final candidate = at(middle);
        if (candidate.offset == previous.offset &&
            candidate.abbreviation == previous.abbreviation) {
          low = middle;
        } else {
          high = middle;
        }
      }
      zones.add(current);
      transitions.add(high);
      indexes.add(zones.length - 1);
      previous = current;
    }
    return tz.Location(name, transitions, indexes, zones);
  }
}
