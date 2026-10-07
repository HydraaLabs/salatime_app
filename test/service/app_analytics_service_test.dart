import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salatime/service/analytics/app_analytics_service.dart';
import 'package:salatime/service/analytics/firebase_analytics_sink.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late _FakeSink sink;

  AppAnalyticsService create({
    AppAnalyticsSink? overrideSink,
    AnalyticsSinkFactory? factory,
    bool enabledInBuild = true,
    Duration timeout = const Duration(milliseconds: 30),
  }) => AppAnalyticsService(
    preferences: prefs,
    sink: factory == null ? (overrideSink ?? sink) : null,
    sinkFactory: factory,
    enabledInBuild: enabledInBuild,
    sdkTimeout: timeout,
  );

  Future<void> settle() async {
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    sink = _FakeSink();
  });

  test(
    'first screens queue without waiting for Firebase and preserve order',
    () async {
      final configured = Completer<AppAnalyticsSink?>();
      final service = create(factory: () => configured.future);
      final initialization = service.initialize();

      await service.screenViewed('home');
      await service.screenViewed('settings');
      await service.appAction(AppAnalyticsAction.accountSignIn);
      expect(sink.events, isEmpty);

      configured.complete(sink);
      await initialization;
      await settle();
      expect(sink.events, [
        'screen:home',
        'screen:settings',
        'account_sign_in',
      ]);
      expect(sink.collectionChanges, [true]);
      expect(service.available, true);
    },
  );

  test('initialize only calls its factory once', () async {
    var calls = 0;
    final service = create(
      factory: () async {
        calls++;
        return sink;
      },
    );
    await Future.wait([service.initialize(), service.initialize()]);
    expect(calls, 1);
    expect(sink.collectionChanges, [true]);
  });

  test(
    'only known screens are accepted and no arbitrary event parameters exist',
    () async {
      final service = create();
      await service.initialize();
      for (final invalid in [
        'home?email=person@example.net',
        '/quran/2/255',
        'Surah Al-Baqarah',
        'audio_person_name',
        'HOME',
        '',
      ]) {
        await service.screenViewed(invalid);
      }
      await service.screenViewed('quran_reader');
      await settle();
      expect(sink.events, ['screen:quran_reader']);
    },
  );

  test(
    'duplicate rebuilds collapse but returning to a screen is recorded',
    () async {
      final service = create();
      await service.initialize();
      await service.screenViewed('home');
      await service.screenViewed('home');
      await service.screenViewed('settings');
      await service.screenViewed('settings');
      await service.screenViewed('home');
      await settle();
      expect(sink.events, ['screen:home', 'screen:settings', 'screen:home']);
    },
  );

  test('early memory queue stays bounded', () async {
    final configured = Completer<AppAnalyticsSink?>();
    final service = create(factory: () => configured.future);
    final initialization = service.initialize();
    await service.screenViewed('home');
    for (var i = 0; i < AppAnalyticsService.maxPendingEvents + 10; i++) {
      await service.appAction(AppAnalyticsAction.cloudSync);
    }
    configured.complete(sink);
    await initialization;
    await settle();
    expect(sink.events.length, AppAnalyticsService.maxPendingEvents);
    expect(sink.events.every((event) => event == 'cloud_sync'), true);
  });

  test(
    'saved opt-out persists across service restart and native consent is off',
    () async {
      final service = create();
      await service.initialize();
      await service.setCollectionEnabled(false);
      await service.screenViewed('home');
      await service.appAction(AppAnalyticsAction.accountSignUp);
      final restarted = create();
      await restarted.initialize();
      await restarted.screenViewed('home');
      await settle();
      expect(restarted.collectionPreference.value, false);
      expect(restarted.collectionEnabled, false);
      expect(prefs.getBool(AppAnalyticsService.preferenceKey), false);
      expect(sink.events, isEmpty);
      expect(sink.collectionChanges, [true, false, false]);
      expect(sink.resets, 1);
    },
  );

  test(
    'debug/profile suppression does not rewrite the user preference',
    () async {
      await prefs.setBool(AppAnalyticsService.preferenceKey, true);
      final service = create(enabledInBuild: false);
      await service.initialize();
      await service.screenViewed('home');
      await service.appAction(AppAnalyticsAction.accountSignIn);
      await settle();
      expect(service.collectionPreference.value, true);
      expect(service.collectionEnabled, false);
      expect(prefs.getBool(AppAnalyticsService.preferenceKey), true);
      expect(sink.collectionChanges, [false]);
      expect(sink.events, isEmpty);
    },
  );

  test(
    'opt-out during initialization drops queued screens and actions',
    () async {
      final configured = Completer<AppAnalyticsSink?>();
      final service = create(factory: () => configured.future);
      final initialization = service.initialize();
      await service.screenViewed('home');
      await service.appAction(AppAnalyticsAction.cloudSync);
      await service.setCollectionEnabled(false);
      configured.complete(sink);
      await initialization;
      await settle();
      expect(sink.collectionChanges, [false]);
      expect(sink.events, isEmpty);
    },
  );

  test('opting back in does not replay old queued events', () async {
    sink.blockFirstEvent = Completer<void>();
    final service = create();
    await service.initialize();
    await service.screenViewed('home');
    await service.screenViewed('settings');
    await service.appAction(AppAnalyticsAction.accountSignIn);
    await service.setCollectionEnabled(false);
    await service.setCollectionEnabled(true);
    await service.screenViewed('settings');
    sink.blockFirstEvent!.complete();
    await settle();
    expect(sink.events, ['screen:home', 'screen:settings']);
    expect(sink.resets, 1);
  });

  test(
    'missing Firebase configuration never prevents app navigation',
    () async {
      final service = create(factory: () async => null);
      await service.screenViewed('home');
      await service.initialize();
      await service.screenViewed('settings');
      await service.setCollectionEnabled(false);
      await settle();
      expect(service.available, false);
      expect(sink.events, isEmpty);
    },
  );

  test('factory and SDK initialization errors are swallowed', () async {
    final factoryFailure = create(
      factory: () async => throw StateError('missing config'),
    );
    await factoryFailure.screenViewed('home');
    await expectLater(factoryFailure.initialize(), completes);
    expect(factoryFailure.available, false);

    sink.failConfiguration = true;
    final sdkFailure = create();
    await sdkFailure.screenViewed('home');
    await expectLater(sdkFailure.initialize(), completes);
    expect(sdkFailure.available, false);
    expect(sink.events, isEmpty);
  });

  test('an SDK event failure does not prevent subsequent statistics', () async {
    final service = create();
    await service.initialize();
    sink.failNextEvent = true;
    await service.screenViewed('home');
    await service.screenViewed('settings');
    await settle();
    expect(sink.events, ['screen:settings']);
    expect(service.available, true);
  });

  test(
    'a stalled factory times out without retaining the memory queue',
    () async {
      final configured = Completer<AppAnalyticsSink?>();
      final service = create(factory: () => configured.future);
      await service.screenViewed('home');
      await expectLater(service.initialize(), completes);
      configured.complete(sink);
      await service.screenViewed('settings');
      await settle();
      expect(service.available, false);
      expect(sink.events, isEmpty);
      expect(sink.collectionChanges, isEmpty);
    },
  );

  test(
    'a stalled event times out and does not block the following screen',
    () async {
      sink.blockFirstEvent = Completer<void>();
      final service = create();
      await service.initialize();
      await service.screenViewed('home');
      await service.screenViewed('settings');
      await Future<void>.delayed(const Duration(milliseconds: 45));
      await settle();
      expect(sink.events, ['screen:home', 'screen:settings']);
      sink.blockFirstEvent!.complete();
    },
  );

  test('SDK failure when disabling still preserves user opt-out', () async {
    final service = create();
    await service.initialize();
    sink.failConfiguration = true;
    await expectLater(service.setCollectionEnabled(false), completes);
    await service.screenViewed('home');
    await settle();
    expect(service.collectionPreference.value, false);
    expect(service.collectionEnabled, false);
    expect(prefs.getBool(AppAnalyticsService.preferenceKey), false);
    expect(sink.events, isEmpty);
  });

  test(
    'Firebase advertising consent is denied before collecting any usage',
    () async {
      final firebase = _RecordingFirebaseAnalytics();
      final adapter = FirebaseAnalyticsSink(firebase);
      await adapter.setCollectionEnabled(true);
      expect(firebase.calls.map((call) => call.memberName), [
        #setAnalyticsCollectionEnabled,
        #setConsent,
        #setUserId,
        #setDefaultEventParameters,
        #setAnalyticsCollectionEnabled,
      ]);
      expect(firebase.calls.first.positionalArguments, [false]);
      expect(_nonNullArguments(firebase.calls[1]), {
        #adStorageConsentGranted: false,
        #adUserDataConsentGranted: false,
        #adPersonalizationSignalsConsentGranted: false,
        #analyticsStorageConsentGranted: true,
      });
      expect(firebase.calls[2].namedArguments[#id], null);
      expect(_nonNullArguments(firebase.calls[2]), isEmpty);
      expect(firebase.calls[3].positionalArguments, [null]);
      expect(firebase.calls.last.positionalArguments, [true]);
    },
  );

  test(
    'Firebase opt-out also denies analytics storage and clears local data',
    () async {
      final firebase = _RecordingFirebaseAnalytics();
      final adapter = FirebaseAnalyticsSink(firebase);
      await adapter.setCollectionEnabled(false);
      await adapter.resetData();
      expect(
        firebase.calls[1].namedArguments[#analyticsStorageConsentGranted],
        false,
      );
      expect(firebase.calls[4].positionalArguments, [false]);
      expect(firebase.calls.last.memberName, #resetAnalyticsData);
    },
  );

  test(
    'Firebase receives only fixed screen labels and parameter-free actions',
    () async {
      final firebase = _RecordingFirebaseAnalytics();
      final adapter = FirebaseAnalyticsSink(firebase);
      await adapter.screenViewed('home');
      await adapter.appAction(AppAnalyticsAction.accountSignIn.eventName);
      expect(firebase.calls[0].memberName, #logScreenView);
      expect(_nonNullArguments(firebase.calls[0]), {
        #screenName: 'home',
        #screenClass: 'SalaTime',
      });
      expect(firebase.calls[1].memberName, #logEvent);
      expect(_nonNullArguments(firebase.calls[1]), {#name: 'account_sign_in'});
    },
  );
  test(
    'opting out during delayed consent never sends a late activation',
    () async {
      final firebase = _DelayedFirebaseAnalytics()
        ..consentDelay = Completer<void>();
      final adapter = FirebaseAnalyticsSink(firebase);
      final optIn = adapter.setCollectionEnabled(true);
      await settle();
      expect(firebase.didDelayConsent, true);
      await adapter.setCollectionEnabled(false);
      firebase.consentDelay!.complete();
      await optIn;
      expect(firebase.collectionEnabled, false);
      expect(firebase.analyticsStorageGranted, false);
      expect(firebase.collectionRequests, everyElement(false));
    },
  );

  test(
    'late native activation completion is reconciled with the latest opt-out',
    () async {
      final firebase = _DelayedFirebaseAnalytics()
        ..activationDelay = Completer<void>();
      final adapter = FirebaseAnalyticsSink(firebase);
      final optIn = adapter.setCollectionEnabled(true);
      await settle();
      expect(firebase.didDelayActivation, true);
      await adapter.setCollectionEnabled(false);
      expect(firebase.collectionEnabled, false);
      firebase.activationDelay!.complete();
      await optIn;
      expect(firebase.collectionEnabled, false);
      expect(firebase.analyticsStorageGranted, false);
      expect(firebase.collectionRequests.where((value) => value).length, 1);
      expect(firebase.collectionRequests.last, false);
    },
  );

  test(
    'service forwards opt-out while native initialization is still pending',
    () async {
      final firebase = _DelayedFirebaseAnalytics()
        ..consentDelay = Completer<void>();
      final service = create(
        overrideSink: FirebaseAnalyticsSink(firebase),
        timeout: const Duration(seconds: 1),
      );
      final initialization = service.initialize();
      await service.screenViewed('home');
      await settle();
      expect(firebase.didDelayConsent, true);
      await service.setCollectionEnabled(false);
      expect(firebase.collectionEnabled, false);
      expect(service.collectionEnabled, false);
      firebase.consentDelay!.complete();
      await initialization;
      expect(firebase.collectionRequests, everyElement(false));
      expect(firebase.analyticsStorageGranted, false);
      expect(
        firebase.calls.where((call) => call.memberName == #logScreenView),
        isEmpty,
      );
    },
  );
}

Map<Symbol, dynamic> _nonNullArguments(Invocation invocation) => {
  for (final entry in invocation.namedArguments.entries)
    if (entry.value != null) entry.key: entry.value,
};

class _RecordingFirebaseAnalytics implements FirebaseAnalytics {
  final List<Invocation> calls = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    return Future<void>.value();
  }
}

class _DelayedFirebaseAnalytics extends _RecordingFirebaseAnalytics {
  Completer<void>? consentDelay;
  Completer<void>? activationDelay;
  bool didDelayConsent = false;
  bool didDelayActivation = false;
  bool collectionEnabled = false;
  bool analyticsStorageGranted = false;
  final List<bool> collectionRequests = [];

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    collectionRequests.add(enabled);
    if (enabled && activationDelay != null && !didDelayActivation) {
      didDelayActivation = true;
      await activationDelay!.future;
    }
    collectionEnabled = enabled;
  }

  @override
  Future<void> setConsent({
    bool? adStorageConsentGranted,
    bool? analyticsStorageConsentGranted,
    bool? adPersonalizationSignalsConsentGranted,
    bool? adUserDataConsentGranted,
    bool? functionalityStorageConsentGranted,
    bool? personalizationStorageConsentGranted,
    bool? securityStorageConsentGranted,
  }) async {
    if (analyticsStorageConsentGranted == true &&
        consentDelay != null &&
        !didDelayConsent) {
      didDelayConsent = true;
      await consentDelay!.future;
    }
    analyticsStorageGranted = analyticsStorageConsentGranted ?? false;
  }
}

class _FakeSink implements AppAnalyticsSink {
  final List<String> events = [];
  final List<bool> collectionChanges = [];
  int resets = 0;
  bool failConfiguration = false;
  bool failNextEvent = false;
  Completer<void>? blockFirstEvent;
  bool _didBlock = false;

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    collectionChanges.add(enabled);
    if (failConfiguration) throw StateError('SDK configuration failed');
  }

  @override
  Future<void> screenViewed(String screenName) => _record('screen:$screenName');

  @override
  Future<void> appAction(String eventName) => _record(eventName);

  Future<void> _record(String event) async {
    if (failNextEvent) {
      failNextEvent = false;
      throw StateError('SDK event failed');
    }
    events.add(event);
    if (!_didBlock && blockFirstEvent != null) {
      _didBlock = true;
      await blockFirstEvent!.future;
    }
  }

  @override
  Future<void> resetData() async => resets++;
}
