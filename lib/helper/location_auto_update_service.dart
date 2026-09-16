import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/package_prayer_time_controller.dart';
import 'package:salatime/helper/location_helper.dart';
import 'package:salatime/helper/salat_waqt_service.dart';

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

  static StreamSubscription<void>? _subscription;
  static Future<void>? _starting;
  static int _generation = 0;

  /// Starts the position watcher if the user opted in and the permission is
  /// granted. Safe to call multiple times — only one watcher ever runs.
  static Future<void> start() {
    return _starting ??= _start(
      _generation,
    ).whenComplete(() => _starting = null);
  }

  static Future<void> _start(int generation) async {
    if (_subscription != null) return;
    if (!isGeolocatorSupported) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(enabledKey) != true) return;

    final backgroundPermissionGranted =
        await Permission.locationAlways.isGranted;
    if (!backgroundPermissionGranted) {
      // Opt-in without the permission: fall back to "while in use", which is
      // still enough to adapt the adhan when the app is used.
      if (!await Permission.location.isGranted) return;
    }

    if (generation != _generation) return;
    var lastLat = prefs.getDouble(_lastLatKey);
    var lastLng = prefs.getDouble(_lastLngKey);

    _subscription =
        Geolocator.getPositionStream(
              locationSettings: streamSettingsForPermission(
                backgroundPermissionGranted: backgroundPermissionGranted,
              ),
            )
            .asyncMap<void>((position) async {
              if (generation != _generation) return;
              final previousLat = lastLat;
              final previousLng = lastLng;
              final moved =
                  previousLat == null ||
                  previousLng == null ||
                  Geolocator.distanceBetween(
                        previousLat,
                        previousLng,
                        position.latitude,
                        position.longitude,
                      ) >=
                      _distanceFilterMeters;
              if (!moved) return;
              Get.find<PrayerTimeController>().useCurrentPosition(position);

              // asyncMap serializes updates while a network request is in flight.
              if (!await _refreshPrayerTimes() || generation != _generation) {
                return;
              }
              lastLat = position.latitude;
              lastLng = position.longitude;
              await prefs.setDouble(_lastLatKey, position.latitude);
              await prefs.setDouble(_lastLngKey, position.longitude);
            })
            .listen(
              (_) {},
              onError: (Object e) {
                if (kDebugMode) {
                  print('LocationAutoUpdateService stream error: $e');
                }
              },
            );

    if (kDebugMode) {
      print('LocationAutoUpdateService started');
    }
  }

  @visibleForTesting
  static LocationSettings streamSettingsForPermission({
    required bool backgroundPermissionGranted,
  }) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.low,
        distanceFilter: _distanceFilterMeters ~/ 2,
        allowBackgroundLocationUpdates: backgroundPermissionGranted,
        showBackgroundLocationIndicator: backgroundPermissionGranted,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.low,
      distanceFilter: _distanceFilterMeters ~/ 2,
    );
  }

  static Future<void> stop() async {
    _generation++;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    await _starting;
  }

  /// Re-fetch prayer times for the current position and reschedule adhan.
  static Future<bool> _refreshPrayerTimes() async {
    try {
      final prayerTimeController = Get.find<PrayerTimeController>();
      final prayerTimes = await prayerTimeController.fetchPrayerTime(
        reload: false,
        isManualPrayerTme: false,
      );
      if (prayerTimes == null) return false;
      await SalatWaqtService.initializeSalatWaqt();
      if (kDebugMode) {
        print('Prayer times refreshed after location change');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('LocationAutoUpdateService refresh failed: $e');
      }
      return false;
    }
  }

  /// Disables the feature (e.g. when the user picks a manual city).
  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, false);
    await stop();
  }
}
