import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// Exercise the installed iOS adapter's actual native-channel serialization.
// ignore: depend_on_referenced_packages
import 'package:geolocator_apple/geolocator_apple.dart';
// ignore: depend_on_referenced_packages
import 'package:geolocator_android/geolocator_android.dart';
import 'package:salatime/helper/location_auto_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(
    'flutter.baseflow.com/geolocator_updates_apple',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  for (final granted in [true, false]) {
    test(
      'iOS native background flags follow Always permission: $granted',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final nativeArguments = Completer<Map<dynamic, dynamic>>();
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'listen') {
            nativeArguments.complete(call.arguments as Map<dynamic, dynamic>);
          }
          return null;
        });
        final subscription = GeolocatorApple()
            .getPositionStream(
              locationSettings:
                  LocationAutoUpdateService.streamSettingsForPermission(
                    backgroundPermissionGranted: granted,
                  ),
            )
            .listen((_) {});
        try {
          final arguments = await nativeArguments.future.timeout(
            const Duration(seconds: 2),
          );
          expect(arguments['allowBackgroundLocationUpdates'], granted);
          expect(arguments['showBackgroundLocationIndicator'], granted);
          expect(arguments['accuracy'], LocationAccuracy.low.index);
          expect(arguments['distanceFilter'], 1500);
        } finally {
          await subscription.cancel();
        }
      },
    );
  }

  for (final granted in [true, false]) {
    test(
      'Android native foreground service follows background permission: $granted',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        const androidChannel = MethodChannel(
          'flutter.baseflow.com/geolocator_updates_android',
        );
        final nativeArguments = Completer<Map<dynamic, dynamic>>();
        messenger.setMockMethodCallHandler(androidChannel, (call) async {
          if (call.method == 'listen') {
            nativeArguments.complete(call.arguments as Map<dynamic, dynamic>);
          }
          return null;
        });
        final subscription = GeolocatorAndroid()
            .getPositionStream(
              locationSettings:
                  LocationAutoUpdateService.streamSettingsForPermission(
                    backgroundPermissionGranted: granted,
                  ),
            )
            .listen((_) {});
        try {
          final arguments = await nativeArguments.future.timeout(
            const Duration(seconds: 2),
          );
          expect(arguments['accuracy'], LocationAccuracy.low.index);
          expect(arguments['distanceFilter'], 1500);
          expect(arguments['timeInterval'], 60000);
          final notification = arguments['foregroundNotificationConfig'];
          if (granted) {
            expect(notification['notificationTitle'], 'SalaTime');
            expect(notification['notificationIcon'], {
              'name': 'launcher_icon',
              'defType': 'mipmap',
            });
            expect(notification['setOngoing'], isTrue);
            expect(notification['enableWakeLock'], isTrue);
            expect(notification['enableWifiLock'], isFalse);
          } else {
            expect(notification, isNull);
          }
        } finally {
          await subscription.cancel();
          messenger.setMockMethodCallHandler(androidChannel, null);
        }
      },
    );
  }
}
