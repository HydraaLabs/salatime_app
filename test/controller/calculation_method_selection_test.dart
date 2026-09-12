import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Instrument the existing plugin store without changing production dependencies.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zabi/controller/package_prayer_time_controller.dart';
import 'package:zabi/data/api/api_client.dart';
import 'package:zabi/data/model/response/todays_prayer_time_model.dart';
import 'package:zabi/helper/local_prayer_calculator.dart';
import 'package:zabi/helper/location_auto_update_service.dart';
import 'package:zabi/helper/prayer_alarm_health.dart';
import 'package:zabi/helper/prayer_calculation_methods.dart';
import 'package:zabi/helper/prayer_notification_preferences.dart';
import 'package:zabi/helper/salat_waqt_service.dart';
import 'package:zabi/service/cloud/preference_schema.dart';
import 'package:zabi/util/app_constants.dart';

class _OfflineApi extends ApiClient {
  _OfflineApi(SharedPreferences prefs)
    : super(appBaseUrl: 'https://unused.invalid', sharedPreferences: prefs);

  int requests = 0;

  @override
  Future<Response> postData(
    String uri,
    dynamic body, {
    Map<String, String>? headers,
  }) async {
    requests++;
    throw StateError('Calculation settings must not request the API');
  }
}

class _NoNetwork extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Calculation settings must work without HTTP');
  }
}

class _ControlledStore extends InMemorySharedPreferencesStore {
  _ControlledStore(SharedPreferences prefs)
    : super.withData({
        for (final key in prefs.getKeys()) 'flutter.$key': prefs.get(key)!,
      });

  final writes = <String>[];
  final writeStarted = Completer<void>();
  Completer<void>? firstWriteGate;
  bool rejectFrance = false;
  bool throwOnRejection = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.selectedCalculationMethod') {
      writes.add(value as String);
      if (!writeStarted.isCompleted) {
        writeStarted.complete();
        await firstWriteGate?.future;
      }
      if (value == '12' && rejectFrance) {
        if (throwOnRejection) throw PlatformException(code: 'write_failed');
        return false;
      }
    }
    return super.setValue(valueType, key, value);
  }
}

class _Harness {
  static const _notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  static const _timezone = MethodChannel('flutter_timezone');
  static const _location = MethodChannel('flutter.baseflow.com/geolocator');
  static const _geocoding = MethodChannel('flutter.baseflow.com/geocoding');
  static const _permissions = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  static const city = <String, Object>{
    AppConstants.isPrayerTme: true,
    AppConstants.IS_MANUAL_PRAYER_TIME: true,
    AppConstants.saveCityName: 'Paris',
    AppConstants.manualCityLat: 48.8566,
    AppConstants.manualCityLng: 2.3522,
    'selectedCalculationMethod': '3',
    'selectedPrayerMadhab': 'STANDARD',
  };

  late SharedPreferences prefs;
  late _OfflineApi api;
  late PrayerTimeController controller;
  final notificationCalls = <String>[];
  final locationCalls = <String>[];
  final permissionCalls = <String>[];
  Completer<void>? initializationGate;
  final initializationStarted = Completer<void>();

  Future<void> initialize([Map<String, Object> values = city]) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    Get.testMode = true;
    Get.locale = const Locale('en');
    SharedPreferences.setMockInitialValues(values);
    prefs = await SharedPreferences.getInstance();
    api = _OfflineApi(prefs);
    controller = PrayerTimeController(apiClient: api);
    Get.put<PrayerTimeController>(controller);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_timezone, (_) async => 'Europe/Paris');
    for (final channel in [_location, _geocoding]) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        locationCalls.add(call.method);
        throw StateError('Passive calculation must not access location');
      });
    }
    messenger.setMockMethodCallHandler(_permissions, (call) async {
      permissionCalls.add(call.method);
      throw StateError('Passive calculation must not request permission');
    });
    messenger.setMockMethodCallHandler(_notifications, (call) async {
      notificationCalls.add(call.method);
      switch (call.method) {
        case 'initialize':
          if (!initializationStarted.isCompleted) {
            initializationStarted.complete();
          }
          await initializationGate?.future;
          return true;
        case 'getNotificationChannels':
        case 'pendingNotificationRequests':
          return <Object>[];
        case 'canScheduleExactNotifications':
          return true;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
      PrayerAlarmHealth.channel,
      (_) async => {'failed': 0},
    );
    final previousHttp = HttpOverrides.current;
    final network = _NoNetwork();
    HttpOverrides.global = network;
    addTearDown(() async {
      if (initializationGate?.isCompleted == false) {
        initializationGate!.complete();
      }
      try {
        // Drain the shared coalescing timer before removing platform mocks.
        await drain();
        expect(api.requests, 0);
        expect(network.attempts, 0);
        expect(locationCalls, isEmpty);
        expect(permissionCalls, isEmpty);
      } finally {
        HttpOverrides.global = previousHttp;
        for (final channel in [
          _notifications,
          _timezone,
          _location,
          _geocoding,
          _permissions,
          PrayerAlarmHealth.channel,
        ]) {
          messenger.setMockMethodCallHandler(channel, null);
        }
        debugDefaultTargetPlatformOverride = null;
        Get.reset();
      }
    });
    for (final phase in PrayerNotificationPhase.values) {
      await PrayerNotificationPreferences.setPhaseEnabled(phase, false);
    }
  }

  Future<void> drain() =>
      SalatWaqtService.initializeSalatWaqt(requestPermissions: false);

  PrayerTimeModel expected(String method) => LocalPrayerCalculator.calculate({
    'type': 'automatic',
    'date': DateTime.now().toIso8601String().split('T').first,
    'lat': '48.8566',
    'lng': '2.3522',
    'prayer_method': method,
    'school': 'STANDARD',
    'timezone': 'Europe/Paris',
  })!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(LocalPrayerCalculator.initializeTimeZones);

  test('all 23 selectable methods are calculable and cloud-compatible', () {
    const expectedIds = {
      '0',
      '1',
      '2',
      '3',
      '4',
      '5',
      '7',
      '8',
      '9',
      '10',
      '11',
      '12',
      '13',
      '14',
      '15',
      '16',
      '17',
      '18',
      '19',
      '20',
      '21',
      '22',
      '23',
    };
    expect(PrayerCalculationMethods.all, hasLength(23));
    expect(PrayerCalculationMethods.ids, expectedIds);
    expect(PreferenceSchema.methods, expectedIds);
    for (final method in PrayerCalculationMethods.all) {
      expect(method.fallbackName.trim(), isNotEmpty);
      expect(PrayerCalculationMethods.byId(method.id), same(method));
      expect(PreferenceSchema.clean({'calculationMethod': method.id}), {
        'calculationMethod': method.id,
      });
      for (final school in ['STANDARD', 'HANAFI']) {
        expect(
          LocalPrayerCalculator.parameters(method.id, school),
          isNotNull,
          reason: '${method.id}/$school',
        );
      }
    }
    expect(PreferenceSchema.clean({'calculationMethod': '6'}), isEmpty);
    expect(PreferenceSchema.clean({'calculationMethod': '999'}), isEmpty);
    expect(PreferenceSchema.clean({'calculationMethod': 3}), isEmpty);
  });

  for (final saved in <String?>[null, '', '6', 'unknown']) {
    test(
      'missing or unsupported method ($saved) retains historical default',
      () async {
        final harness = _Harness();
        await harness.initialize({'selectedCalculationMethod': ?saved});
        await harness.controller.loadPrayerTimeSettings();
        expect(PrayerCalculationMethods.defaultId, '1');
        expect(harness.controller.selectedCalculationMethod, '1');
        expect(harness.prefs.getString('selectedCalculationMethod'), '1');
        expect(harness.controller.selectedPrayerMadhab, 'STANDARD');
        expect(harness.notificationCalls, isEmpty);
      },
    );
  }

  test(
    'every valid saved method survives controller settings reload',
    () async {
      final harness = _Harness();
      await harness.initialize({});
      for (final method in PrayerCalculationMethods.all) {
        await harness.prefs.setString('selectedCalculationMethod', method.id);
        await harness.controller.loadPrayerTimeSettings();
        expect(harness.controller.selectedCalculationMethod, method.id);
        expect(harness.prefs.getString('selectedCalculationMethod'), method.id);
      }
      expect(harness.notificationCalls, isEmpty);
    },
  );

  test('invalid selection changes neither saved value nor scheduler', () async {
    final harness = _Harness();
    await harness.initialize();
    await harness.controller.loadPrayerTimeSettings();
    await expectLater(
      harness.controller.selectCalculationMethod('6'),
      throwsArgumentError,
    );
    await expectLater(
      harness.controller.setSelectedCalculationMethod('invalid'),
      throwsArgumentError,
    );
    await harness.controller.setSelectedCalculationMethod(null);
    expect(harness.controller.selectedCalculationMethod, '3');
    expect(harness.prefs.getString('selectedCalculationMethod'), '3');
    expect(harness.notificationCalls, isEmpty);
  });

  for (final throws in [false, true]) {
    test(
      'failed preference write (throws=$throws) restores the previous choice',
      () async {
        final harness = _Harness();
        await harness.initialize();
        await harness.controller.loadPrayerTimeSettings();
        final previousStore = SharedPreferencesStorePlatform.instance;
        final store = _ControlledStore(harness.prefs)
          ..rejectFrance = true
          ..throwOnRejection = throws;
        SharedPreferencesStorePlatform.instance = store;
        addTearDown(
          () => SharedPreferencesStorePlatform.instance = previousStore,
        );

        await expectLater(
          harness.controller.selectCalculationMethod('12'),
          throws ? throwsA(isA<PlatformException>()) : throwsStateError,
        );
        expect(harness.controller.selectedCalculationMethod, '3');
        expect(harness.prefs.getString('selectedCalculationMethod'), '3');
        expect(harness.notificationCalls, isEmpty);
        expect(store.writes, ['12', '3']);

        // A rejected write must not poison the serialized queue for later edits.
        await harness.controller.selectCalculationMethod('21');
        expect(harness.controller.selectedCalculationMethod, '21');
        expect(harness.prefs.getString('selectedCalculationMethod'), '21');
        await harness.drain();
        expect(
          harness.controller.prayerTimeModel!.data!.toJson(),
          harness.expected('21').data!.toJson(),
        );
      },
    );
  }

  test(
    'selection persists and returns while notification initialization waits',
    () async {
      final harness = _Harness();
      await harness.initialize();
      await harness.controller.refreshConfiguredPrayerTime();
      final previous = harness.controller.prayerTimeModel!.data!.fajrStart;
      harness.initializationGate = Completer<void>();

      await harness.controller
          .selectCalculationMethod('12')
          .timeout(const Duration(seconds: 2));
      expect(harness.controller.selectedCalculationMethod, '12');
      expect(harness.prefs.getString('selectedCalculationMethod'), '12');
      await harness.initializationStarted.future.timeout(
        const Duration(seconds: 2),
      );
      expect(harness.initializationGate!.isCompleted, isFalse);
      expect(harness.controller.prayerTimeModel!.data!.fajrStart, previous);

      harness.initializationGate!.complete();
      await harness.drain();
      expect(harness.controller.prayerTimeModel!.calculatedLocally, isTrue);
      expect(
        harness.controller.prayerTimeModel!.data!.toJson(),
        harness.expected('12').data!.toJson(),
      );
      expect(
        harness.controller.prayerTimeModel!.data!.fajrStart,
        isNot(previous),
      );
    },
  );

  test(
    'rapid selections including returning to the initial value keep the last choice',
    () async {
      final harness = _Harness();
      await harness.initialize();
      await harness.controller.loadPrayerTimeSettings();
      final previousStore = SharedPreferencesStorePlatform.instance;
      final store = _ControlledStore(harness.prefs)
        ..firstWriteGate = Completer<void>();
      SharedPreferencesStorePlatform.instance = store;
      addTearDown(() {
        if (!store.firstWriteGate!.isCompleted) {
          store.firstWriteGate!.complete();
        }
        SharedPreferencesStorePlatform.instance = previousStore;
      });
      final selections = Future.wait([
        harness.controller.selectCalculationMethod('12'),
        harness.controller.selectCalculationMethod('21'),
        harness.controller.selectCalculationMethod('3'),
      ]);
      await store.writeStarted.future;
      expect(store.writes, ['12']);
      store.firstWriteGate!.complete();
      await selections;
      expect(store.writes, ['12', '21', '3']);
      expect(harness.controller.selectedCalculationMethod, '3');
      expect(harness.prefs.getString('selectedCalculationMethod'), '3');
      await harness.drain();
      expect(
        harness.controller.prayerTimeModel!.data!.toJson(),
        harness.expected('3').data!.toJson(),
      );
    },
  );

  test(
    'cold refresh calculates a saved city without fetching coordinates',
    () async {
      final harness = _Harness();
      await harness.initialize();
      expect(harness.controller.prayerTimeZone, isNull);
      await harness.controller.refreshConfiguredPrayerTime();
      expect(harness.controller.prayerTimeZone, 'Europe/Paris');
      expect(harness.controller.saveAddress.value, 'Paris');
      expect(harness.controller.usesManualPrayerTimetable, isFalse);
      expect(harness.controller.isManualPrayerTime.value, isTrue);
      expect(
        harness.controller.prayerTimeModel!.data!.toJson(),
        harness.expected('3').data!.toJson(),
      );
      expect(harness.notificationCalls, isEmpty);
    },
  );

  test(
    'cold automatic refresh uses saved coordinates over an old manual city',
    () async {
      final harness = _Harness();
      await harness.initialize({
        ..._Harness.city,
        AppConstants.saveCityName: 'Previous city',
        AppConstants.manualCityLat: 33.5731,
        AppConstants.manualCityLng: -7.5898,
        LocationAutoUpdateService.enabledKey: true,
        'prayer_time_automatic_latitude': 48.8566,
        'prayer_time_automatic_longitude': 2.3522,
        'prayer_time_automatic_city': 'Paris',
      });
      await harness.controller.refreshConfiguredPrayerTime();
      expect(harness.controller.currentAddress.value, 'Paris');
      expect(harness.controller.isManualPrayerTime.value, isFalse);
      expect(harness.controller.usesManualPrayerTimetable, isFalse);
      expect(
        harness.controller.prayerTimeModel!.data!.toJson(),
        harness.expected('3').data!.toJson(),
      );
    },
  );

  test(
    'cold refresh without a configured location leaves times unavailable',
    () async {
      final harness = _Harness();
      await harness.initialize({'selectedCalculationMethod': '21'});
      await harness.controller.selectCalculationMethod('12');
      await harness.drain();
      expect(harness.controller.selectedCalculationMethod, '12');
      expect(harness.controller.prayerTimeModel, isNull);
      expect(harness.controller.prayerTimeZone, isNull);
    },
  );

  test('method changes preserve the cached published timetable', () async {
    final harness = _Harness();
    final date = DateTime.now().toIso8601String().split('T').first;
    final published = PrayerTimeModel(
      status: true,
      data: Data(
        date: date,
        fajrStart: '06:10',
        sunrise: '07:35',
        zuhrStart: '13:25',
        asrStart: '16:45',
        maghribStart: '18:50',
        ishaStart: '20:20',
      ),
    );
    // Existing persisted format: manual date/city/coordinates/method/school/zone.
    final key = base64Url.encode(
      utf8.encode(
        jsonEncode([
          'manual',
          date,
          'paris',
          '',
          '',
          '3',
          'STANDARD',
          'Europe/Paris',
        ]),
      ),
    );
    await harness.initialize({
      AppConstants.isPrayerTme: true,
      AppConstants.IS_MANUAL_PRAYER_TIME: true,
      AppConstants.saveCityName: 'Paris',
      'selectedCalculationMethod': '3',
      'selectedPrayerMadhab': 'STANDARD',
      'prayer_time_response_cache_v1_$key': jsonEncode(published.toJson()),
    });
    await harness.controller.refreshConfiguredPrayerTime();
    expect(harness.controller.usesManualPrayerTimetable, isTrue);
    expect(harness.controller.prayerTimeModel!.toJson(), published.toJson());

    await harness.controller.selectCalculationMethod('12');
    await harness.drain();
    expect(harness.controller.selectedCalculationMethod, '12');
    expect(harness.prefs.getString('selectedCalculationMethod'), '12');
    expect(harness.controller.usesManualPrayerTimetable, isTrue);
    expect(harness.controller.prayerTimeModel!.toJson(), published.toJson());
    expect(harness.controller.prayerTimeModel!.calculatedLocally, isFalse);

    // A cold controller has no old request template to preserve. The saved
    // official timetable must remain usable under the newly selected method.
    await harness.controller.setSelectedPrayerMadhab('HANAFI');
    final restarted = PrayerTimeController(apiClient: harness.api);
    await restarted.refreshConfiguredPrayerTime();
    expect(restarted.selectedCalculationMethod, '12');
    expect(restarted.selectedPrayerMadhab, 'HANAFI');
    expect(restarted.usesManualPrayerTimetable, isTrue);
    expect(restarted.prayerTimeModel?.toJson(), published.toJson());
  });
}
