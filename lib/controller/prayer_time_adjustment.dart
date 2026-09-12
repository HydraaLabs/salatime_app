// controllers/prayer_time_adjustment_controller.dart
import 'dart:async';
import 'dart:convert';
import 'package:zabi/data/model/response/todays_prayer_time_model.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrayerTimeAdjustmentController extends GetxController {
  static const storageKey = 'prayerAdjustments';
  static const minimumMinutes = -120;
  static const maximumMinutes = 120;
  static const prayerKeys = {
    'fajr',
    'sunrise',
    'zuhr',
    'asr',
    'maghrib',
    'isha',
    'sehri',
    'iftar',
  };

  // A scheduler reload and a second controller must join the same write queue.
  static Future<void>? _operations;
  int _resetsInFlight = 0;

  // Store adjustments as Map<String, int> where key is prayer key and value is minutes
  final RxMap<String, int> _prayerAdjustments = <String, int>{}.obs;
  var isResetting = false.obs;
  var showCustomTimePicker = false.obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(
      initializeAdjustmentServices().catchError((Object _) {
        debugPrint('Prayer adjustments could not be loaded');
      }),
    );
  }

  Future<void> initializeAdjustmentServices() => init();

  Future<void> _enqueue(Future<void> Function(SharedPreferences prefs) action) {
    final previous = _operations;
    final completion = Completer<void>();
    _operations = completion.future;
    return (() async {
      try {
        if (previous != null) await previous;
        await action(await SharedPreferences.getInstance());
      } finally {
        // Release the barrier on failure too, and do not retain an idle zone.
        if (identical(_operations, completion.future)) _operations = null;
        completion.complete();
      }
    })();
  }

  Future<void> init() => _enqueue((prefs) async {
    _replaceAdjustments(_decode(prefs.get(storageKey)));
  });

  static Map<String, int> _decode(Object? saved) {
    if (saved is! String) return {};
    try {
      final decoded = jsonDecode(saved);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (prayerKeys.contains(entry.key) &&
              entry.value is int &&
              entry.value >= minimumMinutes &&
              entry.value <= maximumMinutes &&
              entry.value != 0)
            entry.key as String: entry.value as int,
      };
    } catch (_) {
      // A damaged field must not discard valid siblings or erase stored data.
      return {};
    }
  }

  void _replaceAdjustments(Map<String, int> values) {
    if (!mapEquals(_prayerAdjustments, values)) {
      _prayerAdjustments.value = Map<String, int>.from(values);
    }
    update();
  }

  static void _validatePrayerKey(String key) {
    if (!prayerKeys.contains(key)) {
      throw ArgumentError.value(key, 'prayerKey', 'Unknown prayer');
    }
  }

  static Future<void> _restorePreference(
    SharedPreferences prefs,
    Object? previous,
  ) async {
    // SharedPreferences changes its memory cache before the platform write.
    switch (previous) {
      case String value:
        await prefs.setString(storageKey, value);
      case bool value:
        await prefs.setBool(storageKey, value);
      case int value:
        await prefs.setInt(storageKey, value);
      case double value:
        await prefs.setDouble(storageKey, value);
      case List<String> value:
        await prefs.setStringList(storageKey, value);
      default:
        await prefs.remove(storageKey);
    }
  }

  Future<void> _mutate(void Function(Map<String, int>) change) =>
      _enqueue((prefs) async {
        final previous = prefs.get(storageKey);
        final next = _decode(previous);
        change(next);
        final saved = jsonEncode(next);
        _replaceAdjustments(next);
        try {
          if (!await prefs.setString(storageKey, saved)) {
            throw StateError('Prayer adjustments could not be saved');
          }
        } catch (_) {
          // Do not overwrite a different value restored while this write ran.
          if (prefs.get(storageKey) == saved) {
            try {
              await _restorePreference(prefs, previous);
            } catch (_) {
              // Keep the original storage error visible to the caller.
            }
          }
          _replaceAdjustments(_decode(prefs.get(storageKey)));
          rethrow;
        }
        update();
      });

  // Update adjustment for a specific prayer.
  Future<void> updateAdjustment(String prayerKey, int adjustmentMinutes) async {
    _validatePrayerKey(prayerKey);
    if (adjustmentMinutes < minimumMinutes ||
        adjustmentMinutes > maximumMinutes) {
      throw RangeError.range(
        adjustmentMinutes,
        minimumMinutes,
        maximumMinutes,
        'adjustmentMinutes',
      );
    }
    await _mutate((next) {
      if (adjustmentMinutes == 0) {
        next.remove(prayerKey);
      } else {
        next[prayerKey] = adjustmentMinutes;
      }
    });
  }

  // Reset specific prayer or all prayers
  Future<void> resetPrayerTime({String? prayerKey}) async {
    if (prayerKey != null) _validatePrayerKey(prayerKey);
    _resetsInFlight++;
    isResetting(true);
    try {
      await _mutate((next) {
        if (prayerKey != null) {
          next.remove(prayerKey);
        } else {
          next.clear();
        }
      });
    } finally {
      _resetsInFlight--;
      isResetting(_resetsInFlight > 0);
    }
  }

  // Get adjustment in minutes for a specific prayer
  int? getAdjustmentMinutes(String prayerKey) {
    return _prayerAdjustments[prayerKey];
  }

  // Get formatted adjustment string (e.g., "+5 min", "-10 min")
  String? getAdjustmentString(String prayerKey) {
    final minutes = _prayerAdjustments[prayerKey];
    if (minutes == null || minutes == 0) return null;
    return '${minutes > 0 ? '+' : ''}$minutes ${"min".tr}';
  }

  // Check if a prayer has been adjusted
  bool isAdjusted(String prayerKey) {
    return _prayerAdjustments.containsKey(prayerKey) &&
        _prayerAdjustments[prayerKey] != 0;
  }

  static Map<String, int> get displayOffsets =>
      Get.isRegistered<PrayerTimeAdjustmentController>()
      ? Map<String, int>.from(
          Get.find<PrayerTimeAdjustmentController>()._prayerAdjustments,
        )
      : const {};

  static Data? adjustedDay(Data? day) {
    if (day == null || !Get.isRegistered<PrayerTimeAdjustmentController>()) {
      return day;
    }
    final controller = Get.find<PrayerTimeAdjustmentController>();
    final copy = Data.fromJson(day.toJson());
    String? adjusted(String key, String? time) =>
        time == null ? null : controller.getAdjustedTimeString(key, time);
    copy.fajrStart = adjusted('fajr', day.fajrStart);
    copy.sunrise = adjusted('sunrise', day.sunrise);
    copy.zuhrStart = adjusted('zuhr', day.zuhrStart);
    copy.asrStart = adjusted('asr', day.asrStart);
    copy.maghribStart = adjusted('maghrib', day.maghribStart);
    copy.ishaStart = adjusted('isha', day.ishaStart);
    copy.sehriEnd = adjusted('sehri', day.sehriEnd);
    copy.iftarStart = adjusted('iftar', day.iftarStart);
    return copy;
  }

  // Get adjusted time for a prayer
  DateTime getAdjustedTime(String prayerKey, DateTime defaultTime) {
    final adjustment = _prayerAdjustments[prayerKey] ?? 0;
    return defaultTime.add(Duration(minutes: adjustment));
  }

  // Get adjusted time string
  String getAdjustedTimeString(String prayerKey, String defaultTime) {
    try {
      final parts = defaultTime.split(':');
      final baseTime = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );

      final adjustment = _prayerAdjustments[prayerKey] ?? 0;
      final adjustedTime = baseTime.add(Duration(minutes: adjustment));

      return '${adjustedTime.hour.toString().padLeft(2, '0')}:${adjustedTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return defaultTime;
    }
  }
}
