import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:salatime/view/screens/compass/widget/qibla_dial_view.dart';
import 'package:salatime/view/screens/compass/widget/qiblah_compass.dart';

class _Locations extends GeolocatorPlatform {
  Completer<Position>? current;
  Position? cached;
  int cachedReads = 0;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    expect(locationSettings?.timeLimit, const Duration(seconds: 8));
    current = Completer<Position>();
    return current!.future;
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async {
    cachedReads++;
    return cached;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const compass = MethodChannel('hemanthraj/flutter_compass');
  const geomagnetic = MethodChannel('net.salatime.app/geomagnetic');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late GeolocatorPlatform original;
  late _Locations locations;
  late int compassSubscriptions;

  setUp(() {
    original = GeolocatorPlatform.instance;
    locations = _Locations();
    GeolocatorPlatform.instance = locations;
    compassSubscriptions = 0;
    messenger.setMockMethodCallHandler(compass, (call) async {
      if (call.method == 'listen') compassSubscriptions++;
      return null;
    });
    messenger.setMockMethodCallHandler(geomagnetic, (_) async => 0.0);
  });

  tearDown(() {
    GeolocatorPlatform.instance = original;
    messenger.setMockMethodCallHandler(compass, null);
    messenger.setMockMethodCallHandler(geomagnetic, null);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: QiblahCompassWidget())),
    );
    await tester.pump();
  }

  void expireGps() {
    expect(locations.current, isNotNull);
    locations.current!.completeError(
      TimeoutException('GPS unavailable', const Duration(seconds: 8)),
    );
  }

  Future<void> heading(WidgetTester tester, double value) async {
    await messenger.handlePlatformMessage(
      'hemanthraj/flutter_compass',
      const StandardMethodCodec().encodeSuccessEnvelope(<double>[value, 0, 0]),
      (_) {},
    );
    await tester.pump();
  }

  testWidgets(
    'GPS timeout without cache becomes a handled visible error',
    (tester) async {
      await open(tester);
      expireGps();
      await tester.pump();
      await tester.pump();

      expect(locations.cachedReads, 1);
      expect(compassSubscriptions, 0);
      expect(
        find.text(
          'location_service_permission_denied_for_getting_this_service_please_enable_location',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'GPS timeout uses the cached position and ignores invalid sensor headings',
    (tester) async {
      locations.cached = Position(
        latitude: 34.0181,
        longitude: -5.0078,
        timestamp: DateTime(2026, 10, 7),
        accuracy: 20,
        altitude: 100,
        altitudeAccuracy: 20,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      await open(tester);
      expireGps();
      await tester.pump();
      await tester.pump();

      expect(locations.cachedReads, 1);
      expect(compassSubscriptions, 1);
      await heading(tester, double.nan);
      await heading(tester, double.infinity);
      expect(find.byType(QiblaDialView), findsNothing);
      await heading(tester, 90);
      expect(find.byType(QiblaDialView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'leaving the compass before GPS expires does not leak an async error',
    (tester) async {
      await open(tester);
      await tester.pumpWidget(const SizedBox());
      expireGps();
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(compassSubscriptions, 0);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'a late GPS error from an old stream cannot affect a reopened compass',
    (tester) async {
      await open(tester);
      final oldRequest = locations.current!;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: QiblahCompassWidget(isActive: false)),
        ),
      );
      await open(tester);
      final newRequest = locations.current!;
      expect(identical(oldRequest, newRequest), isFalse);

      oldRequest.completeError(TimeoutException('Old GPS request expired'));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(QiblaDialView), findsNothing);

      newRequest.complete(
        Position(
          latitude: 34.0181,
          longitude: -5.0078,
          timestamp: DateTime(2026, 10, 7),
          accuracy: 20,
          altitude: 100,
          altitudeAccuracy: 20,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        ),
      );
      await tester.pump();
      await tester.pump();
      await heading(tester, 90);
      expect(find.byType(QiblaDialView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
