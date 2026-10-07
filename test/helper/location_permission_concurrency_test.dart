import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
// ignore: depend_on_referenced_packages
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/nearby_mosque_controller.dart';
import 'package:salatime/controller/package_prayer_time_controller.dart';
import 'package:salatime/data/api/api_client.dart';
import 'package:salatime/data/model/response/todays_prayer_time_model.dart';
import 'package:salatime/helper/location_helper.dart';
import 'package:salatime/helper/location_permission_coordinator.dart';

class _Geolocator extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.denied;
  Completer<LocationPermission>? permissionResult;
  Completer<LocationPermission>? checkResult;
  Completer<Position>? positionResult;
  final permissionStarted = Completer<void>();
  final positionStarted = Completer<void>();
  Object? permissionError;
  int permissionRequests = 0;
  int positions = 0;
  void Function()? onRequest;
  void Function()? onRequestFinished;

  final position = Position(
    latitude: 33.4,
    longitude: -5.2,
    timestamp: DateTime(2026, 10, 7),
    accuracy: 10,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      checkResult == null ? permission : await checkResult!.future;

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    onRequest?.call();
    if (!permissionStarted.isCompleted) permissionStarted.complete();
    try {
      if (permissionError != null) throw permissionError!;
      return permission = await permissionResult!.future;
    } finally {
      onRequestFinished?.call();
    }
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => null;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    positions++;
    if (!positionStarted.isCompleted) positionStarted.complete();
    return positionResult == null ? position : await positionResult!.future;
  }
}

class _Mosques extends NearbyMosqueController {
  int searches = 0;

  @override
  void searchNearbyPlaces() => searches++;
}

class _Prayer extends PrayerTimeController {
  _Prayer(ApiClient api) : super(apiClient: api);

  int refreshes = 0;

  @override
  Future<PrayerTimeModel?> fetchPrayerTime({
    bool reload = true,
    bool isManualPrayerTme = false,
    String? manualCity,
    DateTime? date,
    bool applyResult = true,
  }) async {
    refreshes++;
    return null;
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final coordinator = LocationPermissionCoordinator.instance;
  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late GeolocatorPlatform original;
  late _Geolocator geo;
  late List<int> handlerRequests;
  late PermissionStatus foregroundStatus;
  late PermissionStatus alwaysStatus;
  Completer<PermissionStatus>? handlerResult;
  late Completer<void> handlerStarted;
  late int activeDialogs;
  late int maxDialogs;

  setUp(() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    original = GeolocatorPlatform.instance;
    geo = _Geolocator();
    GeolocatorPlatform.instance = geo;
    handlerRequests = [];
    foregroundStatus = PermissionStatus.granted;
    alwaysStatus = PermissionStatus.denied;
    handlerResult = null;
    handlerStarted = Completer<void>();
    activeDialogs = 0;
    maxDialogs = 0;
    void started() {
      activeDialogs++;
      if (activeDialogs > maxDialogs) maxDialogs = activeDialogs;
      if (activeDialogs > 1) {
        throw const PermissionRequestInProgressException(
          'Concurrent native dialog',
        );
      }
    }

    geo.onRequest = started;
    geo.onRequestFinished = () => activeDialogs--;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'checkPermissionStatus') {
        return (call.arguments == Permission.locationAlways.value
                ? alwaysStatus
                : foregroundStatus)
            .index;
      }
      if (call.method == 'requestPermissions') {
        final permissions = (call.arguments as List).cast<int>();
        handlerRequests.addAll(permissions);
        started();
        if (!handlerStarted.isCompleted) handlerStarted.complete();
        try {
          final result = handlerResult == null
              ? PermissionStatus.granted
              : await handlerResult!.future;
          if (permissions.contains(Permission.location.value)) {
            foregroundStatus = result;
          }
          if (permissions.contains(Permission.locationAlways.value)) {
            alwaysStatus = result;
          }
          return {
            for (final permission in permissions) permission: result.index,
          };
        } finally {
          activeDialogs--;
        }
      }
      throw StateError('Unexpected permission method ${call.method}');
    });
  });

  tearDown(() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    GeolocatorPlatform.instance = original;
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
    Get.reset();
  });

  test('twelve concurrent foreground calls share one native dialog', () async {
    geo.permissionResult = Completer<LocationPermission>();
    final futures = List.generate(12, (_) => coordinator.ensureForeground());
    await geo.permissionStarted.future;
    expect(geo.permissionRequests, 1);
    expect(futures.every((future) => identical(future, futures.first)), isTrue);
    geo.permissionResult!.complete(LocationPermission.whileInUse);
    expect(
      await Future.wait(futures),
      everyElement(LocationPermission.whileInUse),
    );
    expect(maxDialogs, 1);
    await coordinator.ensureForeground();
    expect(geo.permissionRequests, 1);
  });

  test(
    'a shared refusal does not queue repeated prompts; explicit retry is possible',
    () async {
      geo.permissionResult = Completer<LocationPermission>();
      final futures = List.generate(8, (_) => coordinator.ensureForeground());
      await geo.permissionStarted.future;
      geo.permissionResult!.complete(LocationPermission.denied);
      expect(
        await Future.wait(futures),
        everyElement(LocationPermission.denied),
      );
      expect(geo.permissionRequests, 1);
      geo.permissionResult = Completer<LocationPermission>()
        ..complete(LocationPermission.whileInUse);
      expect(
        await coordinator.ensureForeground(),
        LocationPermission.whileInUse,
      );
      expect(geo.permissionRequests, 2);
    },
  );

  test('granted and permanently denied statuses never open a dialog', () async {
    geo.permission = LocationPermission.always;
    expect(await coordinator.ensureForeground(), LocationPermission.always);
    geo.permission = LocationPermission.deniedForever;
    expect(
      await coordinator.ensureForeground(),
      LocationPermission.deniedForever,
    );
    expect(geo.permissionRequests, 0);
  });

  test(
    'permission_handler joins a foreground dialog started by Geolocator',
    () async {
      geo.permissionResult = Completer<LocationPermission>();
      final location = coordinator.ensureForeground();
      await geo.permissionStarted.future;
      final travel = coordinator.ensureForegroundWithPermissionHandler();
      geo.permissionResult!.complete(LocationPermission.whileInUse);
      expect(await location, LocationPermission.whileInUse);
      expect(await travel, PermissionStatus.granted);
      expect(handlerRequests, isEmpty);
      expect(maxDialogs, 1);
    },
  );

  test(
    'Geolocator joins a foreground dialog started by permission_handler',
    () async {
      foregroundStatus = PermissionStatus.denied;
      handlerResult = Completer<PermissionStatus>();
      final travel = coordinator.ensureForegroundWithPermissionHandler();
      await handlerStarted.future;
      final location = coordinator.ensureForeground();
      handlerResult!.complete(PermissionStatus.granted);
      expect(await travel, PermissionStatus.granted);
      expect(await location, LocationPermission.whileInUse);
      expect(geo.permissionRequests, 0);
      expect(handlerRequests, [Permission.location.value]);
    },
  );

  test('Always requests wait for the foreground dialog and coalesce', () async {
    geo.permissionResult = Completer<LocationPermission>();
    final foreground = coordinator.ensureForeground();
    await geo.permissionStarted.future;
    final first = coordinator.ensureAlways();
    final second = coordinator.ensureAlways();
    expect(identical(first, second), isTrue);
    expect(handlerRequests, isEmpty);
    geo.permissionResult!.complete(LocationPermission.whileInUse);
    await foreground;
    expect(await first, PermissionStatus.granted);
    expect(await second, PermissionStatus.granted);
    expect(handlerRequests, [Permission.locationAlways.value]);
    expect(maxDialogs, 1);
  });

  test(
    'native failure releases the queue for the next explicit request',
    () async {
      geo.permissionError = PlatformException(code: 'LOCATION_NATIVE_ERROR');
      await expectLater(
        coordinator.ensureForeground(),
        throwsA(isA<PlatformException>()),
      );
      geo.permissionError = null;
      geo.permissionResult = Completer<LocationPermission>()
        ..complete(LocationPermission.whileInUse);
      expect(
        await coordinator.ensureForeground(),
        LocationPermission.whileInUse,
      );
      expect(geo.permissionRequests, 2);
    },
  );

  test(
    'a disposed caller cannot open a dialog after an async permission check',
    () async {
      geo.checkResult = Completer<LocationPermission>();
      var mounted = true;
      final future = coordinator.ensureForeground(canRequest: () => mounted);
      mounted = false;
      geo.checkResult!.complete(LocationPermission.denied);
      expect(await future, LocationPermission.denied);
      expect(geo.permissionRequests, 0);
    },
  );

  test(
    'a live joining caller can request after the first owner is disposed',
    () async {
      geo.checkResult = Completer<LocationPermission>();
      geo.permissionResult = Completer<LocationPermission>();
      var firstMounted = true;
      final first = coordinator.ensureForeground(
        canRequest: () => firstMounted,
      );
      final second = coordinator.ensureForegroundWithPermissionHandler(
        canRequest: () => true,
      );
      firstMounted = false;
      geo.checkResult!.complete(LocationPermission.denied);
      await geo.permissionStarted.future;
      expect(geo.permissionRequests, 1);
      geo.permissionResult!.complete(LocationPermission.whileInUse);
      expect(await first, LocationPermission.whileInUse);
      expect(await second, PermissionStatus.granted);
      expect(handlerRequests, isEmpty);
    },
  );

  test('no foreground dialog appears after all joining owners close', () async {
    geo.checkResult = Completer<LocationPermission>();
    var mounted = true;
    final first = coordinator.ensureForeground(canRequest: () => mounted);
    final second = coordinator.ensureForeground(canRequest: () => mounted);
    mounted = false;
    geo.checkResult!.complete(LocationPermission.denied);
    expect(
      await Future.wait([first, second]),
      everyElement(LocationPermission.denied),
    );
    expect(geo.permissionRequests, 0);
  });

  test(
    'queued Always upgrade survives the first owner closing when another remains',
    () async {
      geo.permissionResult = Completer<LocationPermission>();
      final foreground = coordinator.ensureForeground();
      await geo.permissionStarted.future;
      var firstMounted = true;
      final first = coordinator.ensureAlways(canRequest: () => firstMounted);
      final second = coordinator.ensureAlways(canRequest: () => true);
      firstMounted = false;
      geo.permissionResult!.complete(LocationPermission.whileInUse);
      await foreground;
      expect(await first, PermissionStatus.granted);
      expect(await second, PermissionStatus.granted);
      expect(handlerRequests, [Permission.locationAlways.value]);
      expect(maxDialogs, 1);
    },
  );

  test(
    'background callers open neither foreground nor Always dialogs',
    () async {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(await coordinator.ensureForeground(), LocationPermission.denied);
      expect(await coordinator.ensureAlways(), PermissionStatus.denied);
      expect(geo.permissionRequests, 0);
      expect(handlerRequests, isEmpty);
    },
  );

  test(
    'iOS completion waits for resumed before the next native dialog',
    () async {
      geo.permissionResult = Completer<LocationPermission>();
      final foreground = coordinator.ensureForeground();
      await geo.permissionStarted.future;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      geo.permissionResult!.complete(LocationPermission.whileInUse);
      final always = coordinator.ensureAlways();
      await Future<void>.delayed(Duration.zero);
      expect(handlerRequests, isEmpty);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(await foreground, LocationPermission.whileInUse);
      expect(await always, PermissionStatus.granted);
      expect(maxDialogs, 1);
    },
  );

  test('platform support retains the desktop fallback', () {
    expect(isGeolocatorSupported, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    expect(isGeolocatorSupported, isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(isGeolocatorSupported, isTrue);
  });

  test(
    'Nearby reentrant calls share permission, GPS and the initial search',
    () async {
      geo.permissionResult = Completer<LocationPermission>();
      final controller = _Mosques();
      final futures = List.generate(12, (_) => controller.getLocation());
      await geo.permissionStarted.future;
      expect(
        futures.every((future) => identical(future, futures.first)),
        isTrue,
      );
      geo.permissionResult!.complete(LocationPermission.whileInUse);
      await Future.wait(futures);
      expect(geo.permissionRequests, 1);
      expect(geo.positions, 1);
      expect(controller.searches, 1);
      expect(controller.userLocation.value, '33.4,-5.2');
    },
  );

  test(
    'Prayer and Nearby share a permission request but each receives GPS',
    () async {
      geo.permissionResult = Completer<LocationPermission>();
      final prefs = await SharedPreferences.getInstance();
      final prayer = _Prayer(
        ApiClient(
          appBaseUrl: 'https://example.invalid',
          sharedPreferences: prefs,
        ),
      );
      final nearby = _Mosques();
      final first = prayer.getLocation();
      final repeated = prayer.getLocation();
      final second = nearby.getLocation();
      await geo.permissionStarted.future;
      geo.permissionResult!.complete(LocationPermission.whileInUse);
      await Future.wait([first, repeated, second]);
      expect(geo.permissionRequests, 1);
      expect(prayer.refreshes, 1);
      expect(nearby.searches, 1);
      expect(geo.positions, 2);
    },
  );

  test(
    'closing Nearby while GPS is pending prevents stale UI/search updates',
    () async {
      geo.permission = LocationPermission.whileInUse;
      geo.positionResult = Completer<Position>();
      final controller =
          Get.put<NearbyMosqueController>(_Mosques()) as _Mosques;
      final future = controller.getLocation();
      await geo.positionStarted.future;
      await Get.delete<NearbyMosqueController>(force: true);
      geo.positionResult!.complete(geo.position);
      await future;
      expect(controller.isClosed, isTrue);
      expect(controller.userLocation.value, isEmpty);
      expect(controller.searches, 0);
    },
  );

  testWidgets(
    'Nearby handles native permission failure without an unhandled future',
    (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(home: const Scaffold(body: Text('GPS'))),
      );
      geo.permissionError = PlatformException(code: 'LOCATION_NATIVE_ERROR');
      final controller = _Mosques();
      final future = controller.getLocation();
      await tester.pump();
      await future;
      await tester.pump(const Duration(seconds: 4));
      expect(controller.isLocationDenied.value, isTrue);
      expect(geo.positions, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
