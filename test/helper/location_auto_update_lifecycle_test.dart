import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:salatime/controller/package_prayer_time_controller.dart';
import 'package:salatime/data/api/api_client.dart';
import 'package:salatime/data/model/response/todays_prayer_time_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/helper/location_auto_update_service.dart';
import 'package:salatime/util/app_constants.dart';

class _Locations extends GeolocatorPlatform {
  final settings = <AppleSettings>[];
  int cancellations = 0;
  final streams = <StreamController<Position>>[];
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    settings.add(locationSettings! as AppleSettings);
    final controller = StreamController<Position>(
      onCancel: () {
        cancellations++;
      },
    );
    streams.add(controller);
    return controller.stream;
  }
}

class _Prayer extends PrayerTimeController {
  _Prayer(SharedPreferences prefs)
    : super(
        apiClient: ApiClient(
          appBaseUrl: 'https://unused.invalid',
          sharedPreferences: prefs,
        ),
      );
  int fetches = 0;
  Completer<PrayerTimeModel?>? pending;
  @override
  Future<PrayerTimeModel?> fetchPrayerTime({
    bool reload = true,
    bool isManualPrayerTme = false,
    String? manualCity,
    DateTime? date,
    bool applyResult = true,
  }) async {
    fetches++;
    expect(reload, isFalse);
    expect(isManualPrayerTme, isFalse);
    return pending?.future;
  }
}

Position position(double latitude) => Position(
  latitude: latitude,
  longitude: -5,
  timestamp: DateTime.now(),
  accuracy: 10,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late GeolocatorPlatform original;
  late _Locations locations;
  late bool always;
  late bool foreground;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({
      LocationAutoUpdateService.enabledKey: true,
    });
    original = GeolocatorPlatform.instance;
    locations = _Locations();
    GeolocatorPlatform.instance = locations;
    always = false;
    foreground = true;
    messenger.setMockMethodCallHandler(permissionChannel, (call) async {
      // Passive lifecycle changes must never trigger a permission request.
      expect(call.method, 'checkPermissionStatus');
      final granted = call.arguments == Permission.locationAlways.value
          ? always
          : foreground;
      return granted
          ? PermissionStatus.granted.index
          : PermissionStatus.denied.index;
    });
  });
  tearDown(() async {
    await LocationAutoUpdateService.stop();
    Get.reset();
    GeolocatorPlatform.instance = original;
    messenger.setMockMethodCallHandler(permissionChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'granting Always later restarts a single watcher with background enabled',
    () async {
      await LocationAutoUpdateService.start();
      expect(locations.settings.single.allowBackgroundLocationUpdates, isFalse);
      always = true;
      await LocationAutoUpdateService.start();
      expect(locations.cancellations, 1);
      expect(locations.settings.last.allowBackgroundLocationUpdates, isTrue);
      await Future.wait([
        LocationAutoUpdateService.start(),
        LocationAutoUpdateService.start(),
      ]);
      expect(locations.settings, hasLength(2));
    },
  );

  test(
    'revocation stops tracking and restoration reconnects without prompting',
    () async {
      always = true;
      await LocationAutoUpdateService.start();
      always = false;
      await LocationAutoUpdateService.start();
      expect(locations.settings.last.allowBackgroundLocationUpdates, isFalse);
      foreground = false;
      await LocationAutoUpdateService.start();
      expect(locations.cancellations, 2);
      foreground = true;
      await LocationAutoUpdateService.start();
      expect(locations.settings, hasLength(3));
    },
  );

  test('opting out stops tracking even after later resumes', () async {
    await LocationAutoUpdateService.start();
    await LocationAutoUpdateService.disable();
    await LocationAutoUpdateService.start();
    expect(locations.cancellations, 1);
    expect(locations.settings, hasLength(1));
  });

  test(
    'travel opt-in clears manual mode and refreshes its displacement baseline',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.isPrayerTme, true);
      await prefs.setBool(AppConstants.IS_MANUAL_PRAYER_TIME, true);
      await prefs.setDouble('auto_location_last_lat', 34);
      await prefs.setDouble('auto_location_last_lng', -5);
      await LocationAutoUpdateService.enable();
      expect(prefs.getBool(AppConstants.isPrayerTme), isFalse);
      expect(prefs.getBool(AppConstants.IS_MANUAL_PRAYER_TIME), isFalse);
      expect(prefs.containsKey('auto_location_last_lat'), isFalse);
      expect(locations.settings, hasLength(1));
    },
  );
  test(
    'movement below 3 km does not refresh; a failed refresh can retry',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('auto_location_last_lat', 34);
      await prefs.setDouble('auto_location_last_lng', -5);
      final prayer = Get.put<PrayerTimeController>(_Prayer(prefs)) as _Prayer;
      await LocationAutoUpdateService.start();
      locations.streams.single.add(position(34.01));
      await Future<void>.delayed(Duration.zero);
      expect(prayer.fetches, 0);
      locations.streams.single.add(position(34.05));
      await Future<void>.delayed(Duration.zero);
      expect(prayer.fetches, 1);
      expect(prefs.getDouble('auto_location_last_lat'), 34);
      locations.streams.single.add(position(34.05));
      await Future<void>.delayed(Duration.zero);
      expect(prayer.fetches, 2);
    },
  );

  test(
    'manual mode waits for the old in-flight location refresh to finish',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final prayer = Get.put<PrayerTimeController>(_Prayer(prefs)) as _Prayer;
      prayer.pending = Completer<PrayerTimeModel?>();
      await LocationAutoUpdateService.start();
      locations.streams.single.add(position(34));
      await Future<void>.delayed(Duration.zero);
      expect(prayer.fetches, 1);
      var stopped = false;
      final stopping = LocationAutoUpdateService.disable().then(
        (_) => stopped = true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(stopped, isFalse);
      prayer.pending!.complete(null);
      await stopping;
      expect(stopped, isTrue);
      expect(prefs.containsKey('auto_location_last_lat'), isFalse);
    },
  );

  test('stream errors allow reconnection on resume', () async {
    await LocationAutoUpdateService.start();
    locations.streams.single.addError(
      StateError('Location service unavailable'),
    );
    await Future<void>.delayed(Duration.zero);
    await LocationAutoUpdateService.start();
    expect(locations.cancellations, 1);
    expect(locations.settings, hasLength(2));
  });
}
