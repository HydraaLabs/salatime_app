import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/controller/package_prayer_time_controller.dart';
import 'package:zabi/helper/location_helper.dart';
import 'package:zabi/helper/salat_waqt_service.dart';

/// Watches the device position while the app is alive and, when the user has
/// enabled automatic location update (background location permission), re-
/// fetches the prayer times and reschedules the adhan notifications as soon
/// as the user has moved far enough for the times to change.
class LocationAutoUpdateService {
  LocationAutoUpdateService._();

  static const String enabledKey = 'auto_location_update';
  static const String _lastLatKey = 'auto_location_last_lat';
  static const String _lastLngKey = 'auto_location_last_lng';

  /// Minimum displacement (meters) before prayer times are recomputed.
  static const double _distanceFilterMeters = 3000;

  static StreamSubscription<Position>? _subscription;

  /// Starts the position watcher if the user opted in and the permission is
  /// granted. Safe to call multiple times — only one watcher ever runs.
  static Future<void> start() async {
    if (_subscription != null) return;
    if (!isGeolocatorSupported) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(enabledKey) != true) return;

    if (!await Permission.locationAlways.isGranted) {
      // Opt-in without the permission: fall back to "while in use", which is
      // still enough to adapt the adhan when the app is used.
      if (!await Permission.location.isGranted) return;
    }

    final lastLat = prefs.getDouble(_lastLatKey);
    final lastLng = prefs.getDouble(_lastLngKey);

    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        distanceFilter: _distanceFilterMeters ~/ 2,
      ),
    ).listen((position) async {
      final moved = lastLat == null ||
          lastLng == null ||
          Geolocator.distanceBetween(
                lastLat,
                lastLng,
                position.latitude,
                position.longitude,
              ) >=
              _distanceFilterMeters;
      if (!moved) return;

      await prefs.setDouble(_lastLatKey, position.latitude);
      await prefs.setDouble(_lastLngKey, position.longitude);
      await _refreshPrayerTimes();
    }, onError: (Object e) {
      if (kDebugMode) {
        print('LocationAutoUpdateService stream error: $e');
      }
    });

    if (kDebugMode) {
      print('LocationAutoUpdateService started');
    }
  }

  static Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Re-fetch prayer times for the current position and reschedule adhan.
  static Future<void> _refreshPrayerTimes() async {
    try {
      final prayerTimeController = Get.find<PrayerTimeController>();
      await prayerTimeController.fetchPrayerTime(
        reload: false,
        isManualPrayerTme: false,
      );
      await SalatWaqtService.initializeSalatWaqt();
      if (kDebugMode) {
        print('Prayer times refreshed after location change');
      }
    } catch (e) {
      if (kDebugMode) {
        print('LocationAutoUpdateService refresh failed: $e');
      }
    }
  }

  /// Disables the feature (e.g. when the user picks a manual city).
  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, false);
    await stop();
  }
}
