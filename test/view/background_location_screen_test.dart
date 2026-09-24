import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
// ignore: depend_on_referenced_packages
import 'package:geolocator_apple/geolocator_apple.dart';
// ignore: depend_on_referenced_packages
import 'package:geolocator_android/geolocator_android.dart';
// ignore: depend_on_referenced_packages
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/helper/location_auto_update_service.dart';
import 'package:salatime/view/screens/location/background_location_screen.dart';
import 'package:salatime/view/screens/prayer_settings/widget/automatic_location_tile.dart';

class _Strings extends Translations {
  _Strings(this.strings);
  final Map<String, String> strings;
  @override
  Map<String, Map<String, String>> get keys => {'fr': strings};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<int> requested;
  late int status;
  int? alwaysStatus;
  late GeolocatorPlatform original;
  late Map<String, String> french;

  setUpAll(() async {
    french = Map<String, String>.from(
      jsonDecode(await rootBundle.loadString('assets/language/fr.json')),
    );
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group(platform.name, () {
      final nativeChannel = MethodChannel(
        platform == TargetPlatform.iOS
            ? 'flutter.baseflow.com/geolocator_updates_apple'
            : 'flutter.baseflow.com/geolocator_updates_android',
      );
      setUp(() {
        debugDefaultTargetPlatformOverride = platform;
        SharedPreferences.setMockInitialValues({});
        original = GeolocatorPlatform.instance;
        GeolocatorPlatform.instance = platform == TargetPlatform.iOS
            ? GeolocatorApple()
            : GeolocatorAndroid();
        messenger.setMockMethodCallHandler(nativeChannel, (_) async => null);
        requested = [];
        alwaysStatus = null;
        status = PermissionStatus.denied.index;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'checkPermissionStatus') {
            return call.arguments == Permission.locationAlways.value
                ? alwaysStatus ?? status
                : status;
          }
          if (call.method == 'requestPermissions') {
            requested.addAll((call.arguments as List).cast<int>());
            return {
              for (final p in call.arguments as List)
                p: p == Permission.locationAlways.value
                    ? alwaysStatus ?? status
                    : status,
            };
          }
          throw StateError('Unexpected call: ${call.method}');
        });
      });
      tearDown(() async {
        await LocationAutoUpdateService.stop();
        GeolocatorPlatform.instance = original;
        messenger.setMockMethodCallHandler(nativeChannel, null);
        messenger.setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = null;
        Get.reset();
      });

      Future<void> openExplanation(WidgetTester tester) async {
        await tester.pumpWidget(
          GetMaterialApp(
            locale: const Locale('fr'),
            translations: _Strings(french),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const BackgroundLocationScreen(fromSettings: true),
                    ),
                  ),
                  child: const Text('Travel settings'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Travel settings'));
        await tester.pumpAndSettle();
      }

      test(
        'onboarding does not require optional background permission',
        () async {
          expect(await BackgroundLocationScreen.shouldShow(), isFalse);
          expect(requested, isEmpty);
        },
      );

      if (platform == TargetPlatform.android) {
        testWidgets(
          'Android explanation can be declined without any permission request',
          (tester) async {
            await openExplanation(tester);
            expect(
              find.text(french['travel_location_android_permission']!),
              findsOneWidget,
            );
            await tester.ensureVisible(find.text(french['no_thanks']!));
            await tester.tap(find.text(french['no_thanks']!));
            await tester.pumpAndSettle();
            expect(requested, isEmpty);
            expect(find.text('Travel settings'), findsOneWidget);
            final prefs = await SharedPreferences.getInstance();
            expect(
              prefs.getBool(LocationAutoUpdateService.enabledKey),
              isNot(true),
            );
            debugDefaultTargetPlatformOverride = null;
          },
        );
      }

      testWidgets(
        'neutral Continue action; refusal exits without Settings or retry',
        (tester) async {
          await openExplanation(tester);
          expect(find.text(french['activate']!), findsNothing);
          expect(
            find.text(french['no_thanks']!),
            platform == TargetPlatform.android ? findsOneWidget : findsNothing,
          );
          expect(find.byType(ElevatedButton), findsOneWidget);
          expect(requested, isEmpty);
          await tester.ensureVisible(find.text(french['onboarding_next']!));
          await tester.tap(find.text(french['onboarding_next']!));
          await tester.pumpAndSettle();
          expect(requested, [Permission.location.value]);
          expect(find.text('Travel settings'), findsOneWidget);
          final prefs = await SharedPreferences.getInstance();
          expect(
            prefs.getBool(LocationAutoUpdateService.enabledKey),
            isNot(true),
          );
          debugDefaultTargetPlatformOverride = null;
        },
      );

      testWidgets('permanently denied access exits without requesting again', (
        tester,
      ) async {
        status = PermissionStatus.permanentlyDenied.index;
        await openExplanation(tester);
        await tester.ensureVisible(find.text(french['onboarding_next']!));
        await tester.tap(find.text(french['onboarding_next']!));
        await tester.pumpAndSettle();
        expect(requested, isEmpty);
        expect(find.text('Travel settings'), findsOneWidget);
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('While Using remains usable when Always is declined', (
        tester,
      ) async {
        status = PermissionStatus.granted.index;
        alwaysStatus = PermissionStatus.denied.index;
        await openExplanation(tester);
        await tester.ensureVisible(find.text(french['onboarding_next']!));
        await tester.tap(find.text(french['onboarding_next']!));
        await tester.pumpAndSettle();
        expect(requested, [Permission.locationAlways.value]);
        expect(find.text('Travel settings'), findsOneWidget);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(LocationAutoUpdateService.enabledKey), isTrue);
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets(
        'travel settings show limited access, upgrade on resume and can be disabled',
        (tester) async {
          status = PermissionStatus.granted.index;
          alwaysStatus = PermissionStatus.denied.index;
          await tester.pumpWidget(
            GetMaterialApp(
              locale: const Locale('fr'),
              translations: _Strings(french),
              home: const Scaffold(
                body: SingleChildScrollView(child: AutomaticLocationTile()),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(requested, isEmpty);
          await tester.tap(find.byType(Switch));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(french['onboarding_next']!));
          await tester.tap(find.text(french['onboarding_next']!));
          await tester.pumpAndSettle();
          expect(
            find.textContaining(french['travel_location_foreground']!),
            findsOneWidget,
          );
          expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
          alwaysStatus = PermissionStatus.granted.index;
          // The real geolocator adapter closes its native EventChannel
          // asynchronously; do not trap that cancellation in the fake timer zone.
          await tester.runAsync(() async {
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.inactive,
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.paused,
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
            await LocationAutoUpdateService.start();
          });
          await tester.pumpAndSettle();
          expect(
            find.textContaining(french['travel_location_background']!),
            findsOneWidget,
          );
          expect(requested, [Permission.locationAlways.value]);
          // Manual city selection uses this same service action.
          await tester.runAsync(() async {
            await LocationAutoUpdateService.disable();
            // Allow the settings listener's native authorization reads to return.
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
          await tester.pumpAndSettle();
          expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
          expect(
            find.textContaining(french['travel_location_off']!),
            findsOneWidget,
          );
          await tester.pumpWidget(const SizedBox.shrink());
          debugDefaultTargetPlatformOverride = null;
        },
      );

      for (final size in [const Size(320, 568), const Size(1180, 820)]) {
        testWidgets('explanation fits $size with large text', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            GetMaterialApp(
              locale: const Locale('fr'),
              translations: _Strings(french),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const BackgroundLocationScreen(),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byType(ElevatedButton));
          expect(tester.takeException(), isNull);
          debugDefaultTargetPlatformOverride = null;
        });
      }
    });
  }
}
