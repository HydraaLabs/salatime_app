import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:salatime/service/app_update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late SharedPreferences preferences;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    now = DateTime(2026, 10, 7, 12);
  });

  PackageInfo installed({
    String package = 'net.salatime.app',
    String version = '1.0.28',
    String build = '33',
  }) => PackageInfo(
    appName: 'SalaTime',
    packageName: package,
    version: version,
    buildNumber: build,
  );

  AppUpdateInfo android({
    int? code = 34,
    String package = 'net.salatime.app',
    UpdateAvailability availability = UpdateAvailability.updateAvailable,
  }) => AppUpdateInfo(
    updateAvailability: availability,
    immediateUpdateAllowed: false,
    immediateAllowedPreconditions: null,
    flexibleUpdateAllowed: false,
    flexibleAllowedPreconditions: null,
    availableVersionCode: code,
    installStatus: InstallStatus.unknown,
    packageName: package,
    clientVersionStalenessDays: null,
    updatePriority: 0,
  );

  String payload({
    String version = '1.0.29',
    String bundle = 'net.salatime.app',
    int id = 6812923710,
    String wrapper = 'software',
    String storeUrl = 'https://evil.example/',
    String? minimumOS = '15.0',
  }) => jsonEncode({
    'resultCount': 1,
    'results': [
      {
        'trackId': id,
        'bundleId': bundle,
        'wrapperType': wrapper,
        'version': version,
        'trackViewUrl': storeUrl,
        'minimumOsVersion': minimumOS,
      },
    ],
  });

  AppUpdateService service({
    TargetPlatform platform = TargetPlatform.android,
    Future<AppUpdateInfo> Function()? androidCheck,
    Future<String> Function(Uri)? lookup,
    PackageInfo? info,
    Future<bool> Function(Uri)? open,
    Future<IosStoreContext?> Function()? context,
    bool enabled = true,
    Duration timeout = const Duration(seconds: 5),
  }) => AppUpdateService(
    enabled: enabled,
    platform: () => platform,
    iosStoreContext:
        context ??
        (() async =>
            const IosStoreContext(storeCountry: 'ma', systemVersion: '26.0.1')),
    installedApp: () async => info ?? installed(),
    androidUpdate: androidCheck ?? (() async => android()),
    lookup: lookup ?? ((_) async => payload()),
    preferences: () async => preferences,
    now: () => now,
    openUrl: open,
    timeout: timeout,
  );

  test(
    'Android relies on actual Play availability and a higher version code',
    () async {
      for (final info in [
        android(code: 33),
        android(code: 32),
        android(code: null),
        android(availability: UpdateAvailability.updateNotAvailable),
        android(availability: UpdateAvailability.unknown),
        android(package: 'other.app'),
      ]) {
        final check = service(androidCheck: () async => info);
        expect(await check.checkForUpdate(), isNull);
      }
      final check = service();
      expect((await check.checkForUpdate())?.key, 'android:34');
      expect(check.availableUpdate.value?.version, isNull);
    },
  );

  test(
    'Play update in progress is still available through the store button',
    () async {
      final check = service(
        androidCheck: () async => android(
          availability: UpdateAvailability.developerTriggeredUpdateInProgress,
        ),
      );
      expect((await check.checkForUpdate())?.key, 'android:34');
    },
  );

  test(
    'preview, disabled and unsupported platforms do not query any store',
    () async {
      var calls = 0;
      Future<AppUpdateInfo> query() async {
        calls++;
        return android();
      }

      for (final check in [
        service(
          info: installed(package: 'net.salatime.app.preview'),
          androidCheck: query,
        ),
        service(enabled: false, androidCheck: query),
        service(platform: TargetPlatform.linux, androidCheck: query),
      ]) {
        expect(await check.checkForUpdate(), isNull);
      }
      expect(calls, 0);
    },
  );

  test(
    'iOS looks up the StoreKit storefront and verifies the app identity',
    () async {
      Uri? requested;
      final check = service(
        platform: TargetPlatform.iOS,
        lookup: (uri) async {
          requested = uri;
          return payload();
        },
      );
      expect((await check.checkForUpdate())?.version, '1.0.29');
      expect(requested?.host, 'itunes.apple.com');
      expect(requested?.queryParameters, {
        'id': '6812923710',
        'country': 'MA',
        'entity': 'software',
      });
      for (final response in [
        payload(bundle: 'other.app'),
        payload(id: 123),
        payload(wrapper: 'track'),
        payload(version: '1.0.27'),
        payload(version: '1.0.28'),
        payload(version: 'latest'),
        'invalid',
        '{"resultCount":0,"results":[]}',
        '{"resultCount":1,"results":[]}',
        '{"resultCount":2,"results":[{},{}]}',
      ]) {
        expect(
          AppUpdateService.updateFromAppStore(
            response,
            '1.0.28',
            systemVersion: '26.0.1',
          ),
          isNull,
        );
      }
    },
  );

  test(
    'versions compare numerically and ignore same-version build changes',
    () {
      expect(AppUpdateService.isNewerVersion('1.0.10', '1.0.9'), isTrue);
      expect(AppUpdateService.isNewerVersion('1.10', '1.9.9'), isTrue);
      expect(AppUpdateService.isNewerVersion('2', '1.99.99'), isTrue);
      expect(AppUpdateService.isNewerVersion('1.2.0', '1.2'), isFalse);
      expect(AppUpdateService.isNewerVersion('1.0.28', '1.0.28+33'), isFalse);
      expect(AppUpdateService.isNewerVersion('1.0.9', '1.0.10'), isFalse);
      expect(AppUpdateService.isNewerVersion('1.0.29-beta', '1.0.28'), isFalse);
      expect(AppUpdateService.isNewerVersion('1.0.29', 'bad'), isFalse);
    },
  );

  test(
    'unknown or malformed StoreKit context suppresses all lookup requests',
    () async {
      var calls = 0;
      for (final context in [
        null,
        const IosStoreContext(storeCountry: '', systemVersion: '18.0'),
        const IosStoreContext(storeCountry: 'MAR', systemVersion: '18.0'),
        const IosStoreContext(storeCountry: 'MA', systemVersion: ''),
        const IosStoreContext(storeCountry: 'MA', systemVersion: 'unknown'),
        const IosStoreContext(storeCountry: 'MA', systemVersion: '18.0+1'),
      ]) {
        final check = service(
          platform: TargetPlatform.iOS,
          context: () async => context,
          lookup: (_) async {
            calls++;
            return payload();
          },
        );
        expect(await check.checkForUpdate(), isNull);
      }
      expect(calls, 0);
    },
  );

  test(
    'native getContext loads the actual storefront and iOS system version',
    () async {
      const channel = MethodChannel('net.salatime.app/store_updates');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'getContext');
            return {'storeCountry': 'FR', 'systemVersion': '18.6.2'};
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      Uri? requested;
      final check = AppUpdateService(
        enabled: true,
        platform: () => TargetPlatform.iOS,
        installedApp: () async => installed(),
        preferences: () async => preferences,
        lookup: (uri) async {
          requested = uri;
          return payload(minimumOS: '18.6.2');
        },
        now: () => now,
      );
      expect((await check.checkForUpdate())?.version, '1.0.29');
      expect(requested?.queryParameters['country'], 'FR');
    },
  );

  test(
    'lookup versions must be installable on the known iOS system version',
    () async {
      for (final requiredOS in ['18.6.3', '19', 'invalid', '18.6-beta', null]) {
        final check = service(
          platform: TargetPlatform.iOS,
          context: () async => const IosStoreContext(
            storeCountry: 'MA',
            systemVersion: '18.6.2',
          ),
          lookup: (_) async => payload(minimumOS: requiredOS),
        );
        expect(await check.checkForUpdate(), isNull);
      }
      for (final requiredOS in ['15', '18.6', '18.6.2']) {
        final check = service(
          platform: TargetPlatform.iOS,
          context: () async => const IosStoreContext(
            storeCountry: 'MA',
            systemVersion: '18.6.2',
          ),
          lookup: (_) async => payload(minimumOS: requiredOS),
        );
        expect((await check.checkForUpdate())?.version, '1.0.29');
      }
    },
  );

  test(
    'missing minimum OS or malformed native payload never proves eligibility',
    () {
      final missingOS = jsonDecode(payload()) as Map;
      (missingOS['results'] as List).single.remove('minimumOsVersion');
      expect(
        AppUpdateService.updateFromAppStore(
          jsonEncode(missingOS),
          '1.0.28',
          systemVersion: '18.6.2',
        ),
        isNull,
      );
      expect(
        AppUpdateService.updateFromAppStore(
          payload(),
          '1.0.28',
          systemVersion: 'unknown',
        ),
        isNull,
      );
      expect(IosStoreContext.fromMap(null), isNull);
      expect(
        IosStoreContext.fromMap({'storeCountry': 'MA', 'systemVersion': 18}),
        isNull,
      );
      expect(
        IosStoreContext.fromMap({
          'storeCountry': 'MAR',
          'systemVersion': '18.0',
        }),
        isNull,
      );
      expect(
        IosStoreContext.fromMap({
          'storeCountry': 'ma',
          'systemVersion': '18.6.2',
        })?.storeCountry,
        'MA',
      );
    },
  );

  test(
    'an app missing from the country listing does not trigger a fallback',
    () async {
      var calls = 0;
      final check = service(
        platform: TargetPlatform.iOS,
        lookup: (_) async {
          calls++;
          return '{"resultCount":0,"results":[]}';
        },
      );
      expect(await check.checkForUpdate(), isNull);
      expect(calls, 1);
    },
  );

  test(
    'concurrent checks are coalesced and successful checks cool down six hours',
    () async {
      final completer = Completer<AppUpdateInfo>();
      var calls = 0;
      final check = service(
        androidCheck: () {
          calls++;
          return completer.future;
        },
      );
      final first = check.checkForUpdate();
      final second = check.checkForUpdate();
      expect(identical(first, second), isTrue);
      completer.complete(android());
      expect((await first)?.key, 'android:34');
      await check.checkForUpdate();
      expect(calls, 1);
      now = now.add(const Duration(hours: 6));
      await check.checkForUpdate();
      expect(calls, 2);
    },
  );

  test(
    'network or native API failures fail open and retry after thirty minutes',
    () async {
      var calls = 0;
      final check = service(
        androidCheck: () async {
          calls++;
          throw StateError('Play unavailable');
        },
      );
      expect(await check.checkForUpdate(), isNull);
      expect(await check.checkForUpdate(), isNull);
      expect(calls, 1);
      now = now.add(const Duration(minutes: 30));
      await check.checkForUpdate();
      expect(calls, 2);
      final offline = service(
        platform: TargetPlatform.iOS,
        lookup: (_) async => throw StateError('offline'),
      );
      expect(await offline.checkForUpdate(), isNull);
    },
  );

  test('slow native checks time out without a late notification', () async {
    final delayed = Completer<AppUpdateInfo>();
    final check = service(
      androidCheck: () => delayed.future,
      timeout: const Duration(milliseconds: 10),
    );
    expect(await check.checkForUpdate(), isNull);
    delayed.complete(android());
    await Future<void>.delayed(Duration.zero);
    expect(check.availableUpdate.value, isNull);
  });

  test(
    'dismissal survives restart, hides the same update for a day, then returns',
    () async {
      final check = service();
      final update = (await check.checkForUpdate())!;
      await check.dismiss(update);
      expect(check.availableUpdate.value, isNull);
      expect(
        preferences.getString(AppUpdateService.snoozeKey),
        contains('android:34'),
      );
      final restarted = service();
      expect(await restarted.checkForUpdate(), isNull);
      now = now.add(const Duration(hours: 23));
      expect(await restarted.checkForUpdate(), isNull);
      now = now.add(const Duration(hours: 1));
      expect((await restarted.checkForUpdate())?.key, 'android:34');
    },
  );

  test('a late store response cannot undo a dismissal', () async {
    final delayed = Completer<AppUpdateInfo>();
    final check = service(androidCheck: () => delayed.future);
    final request = check.checkForUpdate();
    await check.dismiss(const AvailableAppUpdate.android(34));
    delayed.complete(android());
    expect(await request, isNull);
    expect(check.availableUpdate.value, isNull);
  });

  test(
    'an entirely new update is not hidden by an older version snooze',
    () async {
      final check = service();
      await check.dismiss((await check.checkForUpdate())!);
      final newer = service(androidCheck: () async => android(code: 35));
      expect((await newer.checkForUpdate())?.key, 'android:35');
    },
  );

  test(
    'store buttons use fixed SalaTime URLs and launch failures return false',
    () async {
      Uri? opened;
      final check = service(
        platform: TargetPlatform.iOS,
        open: (uri) async {
          opened = uri;
          return true;
        },
      );
      expect(await check.openStore((await check.checkForUpdate())!), isTrue);
      expect(opened, Uri.parse('https://apps.apple.com/app/id6812923710'));
      final failure = service(
        open: (_) async => throw StateError('No handler'),
      );
      expect(
        await failure.openStore(const AvailableAppUpdate.android(34)),
        isFalse,
      );
    },
  );
}
