import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Exercise async persistence in the installed plugin without a new dependency.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:salatime/controller/localization_controller.dart';
import 'package:salatime/data/api/api_client.dart';
import 'package:salatime/service/cloud/preference_device.dart';
import 'package:salatime/service/cloud/preference_sync_engine.dart';
import 'package:salatime/util/app_constants.dart';

class _LocaleRemote implements PreferenceRemote {
  CloudDocument value = const CloudDocument(2, {
    'schemaVersion': 1,
    'language': 'en',
    'country': 'US',
    'themeMode': 'dark',
  });
  @override
  Future<CloudDocument> get(String account) async => value;
  @override
  Future<CloudDocument> put(
    String account,
    int version,
    Document preferences,
  ) async {
    expect(version, value.version);
    return value = CloudDocument(version + 1, preferences);
  }
}

class _GatedLanguageStore extends InMemorySharedPreferencesStore {
  _GatedLanguageStore()
    : super.withData({
        'flutter.language_code': 'en',
        'flutter.country_code': 'US',
      });
  final frenchStarted = Completer<void>();
  final englishStarted = Completer<void>();
  final frenchGate = Completer<void>();
  final englishGate = Completer<void>();
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    await super.setValue(type, key, value);
    if (key == 'flutter.language_code' &&
        value == 'fr' &&
        !frenchStarted.isCompleted) {
      frenchStarted.complete();
      await frenchGate.future;
    }
    if (key == 'flutter.language_code' &&
        value == 'en' &&
        !englishStarted.isCompleted) {
      englishStarted.complete();
      await englishGate.future;
    }
    return true;
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    Get.reset();
    Get.testMode = true;
    Get.locale = null;
    SharedPreferences.setMockInitialValues({});
    binding.platformDispatcher.localeTestValue = const Locale('en', 'US');
  });
  tearDown(() {
    binding.platformDispatcher.clearLocaleTestValue();
    debugDefaultTargetPlatformOverride = null;
    Get.reset();
  });
  Future<LocalizationController> controller() async {
    final prefs = await SharedPreferences.getInstance();
    return Get.put(
      LocalizationController(
        sharedPreferences: prefs,
        apiClient: ApiClient(
          appBaseUrl: 'https://example.test',
          sharedPreferences: prefs,
        ),
      ),
    );
  }

  test(
    'locale priorities are supported manual, supported system, then English',
    () {
      expect(
        LocalizationController.resolveLocale(
          systemLocale: const Locale('ar'),
          savedLanguageCode: 'fr-FR',
        ),
        const Locale('fr', 'FR'),
      );
      expect(
        LocalizationController.resolveLocale(
          systemLocale: const Locale('tr'),
          savedLanguageCode: 'unsupported',
        ),
        const Locale('tr', 'TR'),
      );
      expect(
        LocalizationController.resolveLocale(systemLocale: const Locale('ja')),
        const Locale('en', 'US'),
      );
      expect(
        LocalizationController.resolveLocale(
          systemLocale: const Locale('en'),
          savedLanguageCode: 'AR_sa',
          savedCountryCode: 'CA',
        ),
        const Locale('ar', 'CA'),
      );
      expect(
        LocalizationController.resolveLocale(
          systemLocale: const Locale('en'),
          savedLanguageCode: 'fr',
          savedCountryCode: 'invalid',
        ),
        const Locale('fr', 'FR'),
      );
    },
  );
  test(
    'automatic language loading does not persist a manual selection',
    () async {
      binding.platformDispatcher.localeTestValue = const Locale('tr', 'TR');
      final c = await controller();
      final prefs = await SharedPreferences.getInstance();
      expect(c.locale, const Locale('tr', 'TR'));
      expect(prefs.containsKey(AppConstants.LANGUAGE_CODE), false);
      expect(prefs.containsKey(AppConstants.COUNTRY_CODE), false);
      binding.platformDispatcher.localeTestValue = const Locale('ar', 'SA');
      c.loadCurrentLanguage();
      expect(c.locale, const Locale('ar', 'SA'));
      expect(prefs.containsKey(AppConstants.LANGUAGE_CODE), false);
    },
  );
  test(
    'cloud capture uses the effective system language before Get.locale exists',
    () async {
      binding.platformDispatcher.localeTestValue = const Locale('tr', 'TR');
      final prefs = await SharedPreferences.getInstance();
      expect(Get.locale, isNull);
      final snapshot = await AppPreferenceDevice(
        prefs,
        scope: 'test',
        reloadControllers: false,
      ).capture();
      expect(snapshot['language'], 'tr');
      expect(snapshot['country'], 'TR');
      expect(prefs.containsKey(AppConstants.LANGUAGE_CODE), false);
    },
  );
  testWidgets(
    'manual language emits before writes and cloud restoration emits nothing',
    (tester) async {
      final c = await controller();
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        GetMaterialApp(locale: c.locale, home: const SizedBox()),
      );
      final events = <Locale>[];
      final subscription = LocalizationController.languageChanges.listen((
        locale,
      ) {
        expect(c.locale, locale);
        expect(prefs.containsKey(AppConstants.LANGUAGE_CODE), false);
        events.add(locale);
      });
      addTearDown(subscription.cancel);
      final selecting = c.setLanguage(const Locale('fr'), 999);
      expect(events, [const Locale('fr', 'FR')]);
      await tester.pumpAndSettle();
      await selecting;
      expect(prefs.getString(AppConstants.LANGUAGE_CODE), 'fr');
      expect(prefs.getString(AppConstants.COUNTRY_CODE), 'FR');
      expect(AppConstants.languages[c.selectedIndex].languageCode, 'fr');
      await prefs.setString(AppConstants.LANGUAGE_CODE, 'ar');
      await prefs.setString(AppConstants.COUNTRY_CODE, 'SA');
      c.loadCurrentLanguage();
      expect(c.locale, const Locale('ar', 'SA'));
      expect(events.length, 1);
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'rapid selections persist the newest language and country together',
    (tester) async {
      final c = await controller();
      await tester.pumpWidget(
        GetMaterialApp(locale: c.locale, home: const SizedBox()),
      );
      final first = c.setLanguage(const Locale('fr'), 2);
      await tester.pumpAndSettle();
      final second = c.setLanguage(const Locale('ar'), 1);
      await tester.pumpAndSettle();
      await Future.wait([first, second]);
      final prefs = await SharedPreferences.getInstance();
      expect(c.locale, const Locale('ar', 'SA'));
      expect(prefs.getString(AppConstants.LANGUAGE_CODE), 'ar');
      expect(prefs.getString(AppConstants.COUNTRY_CODE), 'SA');
    },
  );
  testWidgets(
    'a connected selection reaches cloud without replacing other account settings',
    (tester) async {
      final c = await controller();
      await tester.pumpWidget(
        GetMaterialApp(locale: c.locale, home: const SizedBox()),
      );
      final prefs = await SharedPreferences.getInstance();
      final remote = _LocaleRemote();
      final engine = PreferenceSyncEngine(
        remote,
        AppPreferenceDevice(prefs, scope: 'test', reloadControllers: false),
      );
      final subscription = LocalizationController.languageChanges.listen((
        locale,
      ) {
        engine.noteLanguageChoice({
          'language': locale.languageCode,
          'country': locale.countryCode,
        });
      });
      addTearDown(subscription.cancel);
      await tester.runAsync(() => engine.selectAccount('a'));
      final selecting = c.setLanguage(const Locale('ar'), 1);
      await tester.pumpAndSettle();
      await selecting;
      await tester.runAsync(engine.sync);
      expect(remote.value.preferences['language'], 'ar');
      expect(remote.value.preferences['country'], 'SA');
      expect(remote.value.preferences['themeMode'], 'dark');
      expect(engine.status, 'cloud_synced');
    },
  );
  testWidgets(
    'queued manual language survives a stale cloud write and controller reload',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final store = _GatedLanguageStore();
      SharedPreferencesStorePlatform.instance = store;
      final c = await controller();
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        GetMaterialApp(locale: c.locale, home: const SizedBox()),
      );
      var revision = 0;
      final subscription = LocalizationController.languageChanges.listen(
        (_) => revision++,
      );
      addTearDown(subscription.cancel);
      final first = c.setLanguage(const Locale('fr', 'FR'), 2);
      await tester.pump();
      await store.frenchStarted.future;
      final cloudRevision = revision;
      final applying = AppPreferenceDevice(prefs, scope: 'test').applyIfCurrent(
        {'language': 'en', 'country': 'US'},
        () => revision == cloudRevision,
      );
      await tester.pump();
      await store.englishStarted.future;
      final second = c.setLanguage(const Locale('ar', 'SA'), 1);
      store.englishGate.complete();
      await tester.pump();
      expect(await applying, false);
      expect(c.locale, const Locale('ar', 'SA'));
      store.frenchGate.complete();
      await tester.pump();
      await Future.wait([first, second]);
      await tester.pumpAndSettle();
      expect(c.locale, const Locale('ar', 'SA'));
      expect(prefs.getString(AppConstants.LANGUAGE_CODE), 'ar');
      expect(prefs.getString(AppConstants.COUNTRY_CODE), 'SA');
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
