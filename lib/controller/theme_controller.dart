import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zabi/util/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends GetxController
    with WidgetsBindingObserver
    implements GetxService {
  final SharedPreferences sharedPreferences;
  final DateTime Function() _now;

  ThemeController({required this.sharedPreferences, DateTime Function()? now})
    : _now = now ?? DateTime.now {
    _mode =
        sharedPreferences.getString(AppConstants.THEME_MODE_KEY) ?? daylight;
    _sunrise = sharedPreferences.getString(AppConstants.DAYLIGHT_SUNRISE_KEY);
    _sunset = sharedPreferences.getString(AppConstants.DAYLIGHT_SUNSET_KEY);
    _darkTheme = _resolveIsDark(_now());
  }

  static const String daylight = 'daylight';
  static const String light = 'light';
  static const String dark = 'dark';

  late String _mode;
  bool _darkTheme = false;
  String? _sunrise;
  String? _sunset;
  Timer? _boundaryTimer;

  bool get darkTheme => _darkTheme;
  String get mode => _mode;
  bool get isDaylightMode => _mode == daylight;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _scheduleNextBoundary();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshForCurrentTime();
  }

  Future<void> setMode(String value) async {
    if (value != daylight && value != light && value != dark) return;
    _mode = value;
    await sharedPreferences.setString(AppConstants.THEME_MODE_KEY, value);
    _applyResolvedTheme();
    _scheduleNextBoundary();
  }

  void toggleTheme() {
    setMode(_darkTheme ? light : dark);
  }

  Future<void> updateDaylightTimes(String? sunrise, String? sunset) async {
    if (_parseClock(sunrise) == null || _parseClock(sunset) == null) return;

    _sunrise = sunrise!.trim();
    _sunset = sunset!.trim();
    await Future.wait([
      sharedPreferences.setString(AppConstants.DAYLIGHT_SUNRISE_KEY, _sunrise!),
      sharedPreferences.setString(AppConstants.DAYLIGHT_SUNSET_KEY, _sunset!),
    ]);

    if (isDaylightMode) {
      _applyResolvedTheme();
      _scheduleNextBoundary();
    }
  }

  void refreshForCurrentTime() {
    if (!isDaylightMode) return;
    _applyResolvedTheme();
    _scheduleNextBoundary();
  }

  void _applyResolvedTheme() {
    _darkTheme = _resolveIsDark(_now());
    sharedPreferences.setBool(AppConstants.THEME, _darkTheme);
    update();
  }

  bool _resolveIsDark(DateTime now) {
    if (_mode == light) return false;
    if (_mode == dark) return true;
    return !isDaylightAt(now: now, sunrise: _sunrise, sunset: _sunset);
  }

  static bool isDaylightAt({
    required DateTime now,
    String? sunrise,
    String? sunset,
  }) {
    final sunriseTime =
        _parseClock(sunrise) ?? const TimeOfDay(hour: 6, minute: 0);
    final sunsetTime =
        _parseClock(sunset) ?? const TimeOfDay(hour: 18, minute: 0);
    final sunriseDate = _onDate(now, sunriseTime);
    final sunsetDate = _onDate(now, sunsetTime);
    return !now.isBefore(sunriseDate) && now.isBefore(sunsetDate);
  }

  static TimeOfDay? _parseClock(String? value) {
    if (value == null) return null;
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*([AaPp][Mm])?$',
    ).firstMatch(value.trim());
    if (match == null) return null;

    var hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || minute > 59) return null;

    final suffix = match.group(3)?.toLowerCase();
    if (suffix != null) {
      if (hour < 1 || hour > 12) return null;
      if (suffix == 'pm' && hour != 12) hour += 12;
      if (suffix == 'am' && hour == 12) hour = 0;
    } else if (hour > 23) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  static DateTime _onDate(DateTime date, TimeOfDay time) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  void _scheduleNextBoundary() {
    _boundaryTimer?.cancel();
    if (!isDaylightMode) return;

    final now = _now();
    final sunriseTime =
        _parseClock(_sunrise) ?? const TimeOfDay(hour: 6, minute: 0);
    final sunsetTime =
        _parseClock(_sunset) ?? const TimeOfDay(hour: 18, minute: 0);
    final sunriseToday = _onDate(now, sunriseTime);
    final sunsetToday = _onDate(now, sunsetTime);

    final nextBoundary = now.isBefore(sunriseToday)
        ? sunriseToday
        : now.isBefore(sunsetToday)
        ? sunsetToday
        : _onDate(now.add(const Duration(days: 1)), sunriseTime);
    final delay = nextBoundary.difference(now) + const Duration(seconds: 1);
    _boundaryTimer = Timer(delay, refreshForCurrentTime);
  }

  @override
  void onClose() {
    _boundaryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
