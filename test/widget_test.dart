import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/controller/localization_controller.dart';
import 'package:zabi/controller/noti_sound_controller.dart';
import 'package:zabi/controller/package_prayer_time_controller.dart';
import 'package:zabi/controller/prayer_reminder_controller.dart';
import 'package:zabi/controller/theme_controller.dart';
import 'package:zabi/data/api/api_client.dart';
import 'package:zabi/data/model/response/todays_prayer_time_model.dart';
import 'package:zabi/helper/route_helper.dart';
import 'package:zabi/helper/salat_waqt_service.dart';
import 'package:zabi/helper/translator_helper.dart';
import 'package:zabi/service/first_launch_setup_service.dart';
import 'package:zabi/util/app_constants.dart';
import 'package:zabi/view/screens/home/modern/widget/modern_daily_hadith_card.dart';
import 'package:zabi/view/screens/home/modern/widget/modern_next_prayer_card.dart';
import 'package:zabi/view/screens/home/modern/widget/modern_prayer_dashboard.dart';
import 'package:zabi/view/screens/onboarding/first_launch_setup_screen.dart';
import 'package:zabi/view/screens/notification/widgets/salat_waqt_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SalaTime application identity is configured', () {
    expect(AppConstants.APP_NAME, 'SalaTime');
    expect(Uri.parse(AppConstants.BASE_URL).host, 'salatime.net');
  });

  test('localized interface numerals are displayed with western digits', () {
    expect(translateText('0123456789'), '0123456789');
    expect(translateText('٠١٢٣٤٥٦٧٨٩'), '0123456789');
    expect(translateText('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
    expect(translateText('الساعة ٠٥:٣١'), 'الساعة 05:31');
  });

  test('every supported language has a bundled translation file', () async {
    for (final language in AppConstants.languages) {
      final languageCode = language.languageCode;
      expect(languageCode, isNotEmpty);

      final contents = await rootBundle.loadString(
        'assets/language/$languageCode.json',
      );
      final translations = json.decode(contents);

      expect(translations, isA<Map<String, dynamic>>());
      expect(translations, isNotEmpty);
      expect(translations['about'], isNotEmpty);
      expect(translations['version_number'], contains('@version'));
      for (var month = 1; month <= 12; month++) {
        expect(translations['hijri_month_$month'], isNotEmpty);
      }
      for (final key in const [
        'additional_prayer_reminders',
        'before_adhan',
        'after_adhan',
        'minutes_before',
        'minutes_after',
        'reminder_sound',
        'preview_sound',
        'enable_prayer_notifications',
        'disable_prayer_notifications',
        'prayer_in_minutes',
        'prayer_minutes_ago',
        'iqama_reminder_title',
        'iqama_reminder_body',
        'short_beep',
        'nav_today',
        'nav_qibla',
        'nav_mosques',
        'nav_more',
        'countdown_prefix',
        'previous_day',
        'next_day',
        'quran_reading_progress_title',
        'quran_progress_summary',
        'continue_reading',
        'theme_mode_title',
        'theme_mode_auto',
        'theme_mode_auto_desc',
        'theme_mode_light',
        'theme_mode_dark',
        'daily_hadith_1',
        'daily_hadith_2',
        'daily_hadith_3',
        'onboarding_welcome_title',
        'onboarding_welcome_body',
        'onboarding_language_label',
        'onboarding_settings_title',
        'onboarding_settings_body',
        'onboarding_enable_adhan',
        'onboarding_enable_adhan_description',
        'onboarding_battery_note',
        'onboarding_previous',
        'onboarding_next',
        'onboarding_finish',
        'allow_background_activity',
        'battery_optimization_granted',
        'battery_optimization_not_granted',
      ]) {
        expect(translations, contains(key), reason: '$languageCode: $key');
      }
    }
  });

  test('French reminder wording distinguishes Adhan and Iqama', () async {
    final contents = await rootBundle.loadString('assets/language/fr.json');
    final translations = json.decode(contents) as Map<String, dynamic>;

    expect(
      translations['before_adhan_description'],
      'Me prévenir avant chaque Adhan activé',
    );
    expect(translations['after_adhan_description'], 'Me prévenir pour l’Iqama');
    expect(translations['iqama_reminder_title'], 'Rappel d’Iqama');
  });

  test('French home uses the requested prayer names', () async {
    final contents = await rootBundle.loadString('assets/language/fr.json');
    final translations = json.decode(contents) as Map<String, dynamic>;

    expect(translations['fajr'], 'As-sobh');
    expect(translations['magrib'], 'Al-maghrib');
  });

  test(
    'manual timetables are cached by date and calculation context',
    () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.IS_MANUAL_PRAYER_TIME: true,
        AppConstants.isPrayerTme: true,
        AppConstants.saveCityName: 'Fes',
        'selectedCalculationMethod': '21',
        'selectedPrayerMadhab': 'STANDARD',
      });
      final preferences = await SharedPreferences.getInstance();
      const timezoneChannel = MethodChannel('flutter_timezone');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            timezoneChannel,
            (_) async => 'Africa/Casablanca',
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(timezoneChannel, null),
      );

      final firstApi = _CountingPrayerApiClient(preferences);
      final firstController = PrayerTimeController(apiClient: firstApi);
      final requestedDate = DateTime(2026, 9, 7);

      final first = await firstController.fetchPrayerTime(
        reload: false,
        isManualPrayerTme: true,
        manualCity: 'Fes',
        date: requestedDate,
        applyResult: false,
      );
      final second = await firstController.fetchPrayerTime(
        reload: false,
        isManualPrayerTme: true,
        manualCity: 'Fes',
        date: requestedDate,
        applyResult: false,
      );

      expect(first?.data?.date, '2026-09-07');
      expect(second?.data?.date, '2026-09-07');
      expect(firstApi.callCount, 1);

      final secondApi = _CountingPrayerApiClient(preferences);
      final secondController = PrayerTimeController(apiClient: secondApi);
      final restored = await secondController.fetchPrayerTime(
        reload: false,
        isManualPrayerTme: true,
        manualCity: 'Fes',
        date: requestedDate,
        applyResult: false,
      );
      expect(restored?.data?.date, '2026-09-07');
      expect(secondApi.callCount, 0);

      await secondController.fetchPrayerTime(
        reload: false,
        isManualPrayerTme: true,
        manualCity: 'Fes',
        date: DateTime(2026, 10, 23),
        applyResult: false,
      );
      expect(secondApi.callCount, 1);
      expect(secondApi.requestedDates, ['2026-10-23']);
    },
  );

  test('manual prayer calendar is filled ahead and reused offline', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.IS_MANUAL_PRAYER_TIME: true,
      AppConstants.isPrayerTme: true,
      AppConstants.saveCityName: 'Fes',
      'selectedCalculationMethod': '21',
      'selectedPrayerMadhab': 'STANDARD',
    });
    final preferences = await SharedPreferences.getInstance();
    const timezoneChannel = MethodChannel('flutter_timezone');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          timezoneChannel,
          (_) async => 'Africa/Casablanca',
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(timezoneChannel, null),
    );

    final api = _CountingPrayerApiClient(preferences);
    final controller = PrayerTimeController(apiClient: api);
    final today = DateTime(2026, 9, 8);
    await controller.fetchPrayerTime(
      reload: false,
      isManualPrayerTme: true,
      manualCity: 'Fes',
      date: today,
      applyResult: false,
    );
    expect(api.calendarCallCount, 1);
    expect(api.dailyCallCount, 0);

    expect(await controller.warmPrayerTimeCache(now: today), 0);
    expect(api.requestedDates, ['2026-09-08']);
    expect(api.calendarCallCount, 1);
    expect(api.dailyCallCount, 0);

    expect(await controller.warmPrayerTimeCache(now: today), 0);
    expect(api.callCount, 1);

    final offlineApi = _CountingPrayerApiClient(
      preferences,
      alwaysOffline: true,
    );
    final restoredController = PrayerTimeController(apiClient: offlineApi);
    final restored = await restoredController.fetchPrayerTime(
      reload: false,
      isManualPrayerTme: true,
      manualCity: 'Fes',
      date: DateTime(2026, 10, 23),
      applyResult: false,
    );
    expect(restored?.data?.date, '2026-10-23');
    expect(offlineApi.callCount, 0);
  });

  test('startup routes no longer include the logo splash screen', () {
    final routeNames = RouteHelper.routes.map((route) => route.name);

    expect(routeNames, isNot(contains('/')));
    expect(routeNames, contains(RouteHelper.firstLaunchSetup));
    expect(routeNames, contains(RouteHelper.bottomNavbar));
  });

  test('first-launch setup stores functional notification defaults', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final setup = FirstLaunchSetupService(preferences);

    expect(setup.shouldShow, isTrue);
    expect(AppConstants.DEFAULT_PRAYER_REMINDER_MINUTES, 5);

    await setup.complete(
      adhanEnabled: true,
      beforeEnabled: true,
      afterEnabled: true,
      beforeMinutes: AppConstants.DEFAULT_PRAYER_REMINDER_MINUTES,
      afterMinutes: AppConstants.DEFAULT_PRAYER_REMINDER_MINUTES,
      adhanSound: AppConstants.DEFAULT_NOTIFICATION_SOUND,
    );

    expect(setup.shouldShow, isFalse);
    expect(
      preferences.getInt(AppConstants.BEFORE_ADHAN_REMINDER_MINUTES_KEY),
      5,
    );
    expect(
      preferences.getInt(AppConstants.AFTER_ADHAN_REMINDER_MINUTES_KEY),
      5,
    );
    expect(
      preferences.getBool(AppConstants.BEFORE_ADHAN_REMINDER_ENABLED_KEY),
      isTrue,
    );
    expect(
      preferences.getBool(AppConstants.AFTER_ADHAN_REMINDER_ENABLED_KEY),
      isTrue,
    );
    final prayers = await SalatWaqtRepository().getSalatWaqtList();
    expect(prayers, hasLength(5));
    expect(prayers.every((prayer) => prayer.isNotificationEnabled), isTrue);
  });

  test(
    'onboarding saves three independent sounds and validates reminder sounds',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await FirstLaunchSetupService(prefs).complete(
        adhanEnabled: true,
        beforeEnabled: true,
        afterEnabled: true,
        beforeMinutes: 5,
        afterMinutes: 10,
        adhanSound: 'azan_3',
        beforeSound: 'noti_beep_beep',
        afterSound: 'noti_1',
      );
      expect(
        prefs.getString(AppConstants.SELECTED_NOTIFICATION_SOUND_KEY),
        'azan_3',
      );
      expect(
        prefs.getString(AppConstants.BEFORE_ADHAN_REMINDER_SOUND_KEY),
        'noti_beep_beep',
      );
      expect(
        prefs.getString(AppConstants.AFTER_ADHAN_REMINDER_SOUND_KEY),
        'noti_1',
      );
      await FirstLaunchSetupService(prefs).complete(
        adhanEnabled: false,
        beforeEnabled: true,
        afterEnabled: true,
        beforeMinutes: 5,
        afterMinutes: 10,
        adhanSound: 'missing',
        beforeSound: 'missing',
        afterSound: 'noti_1',
      );
      expect(
        prefs.getBool(AppConstants.BEFORE_ADHAN_REMINDER_ENABLED_KEY),
        isFalse,
      );
      expect(
        prefs.getBool(AppConstants.AFTER_ADHAN_REMINDER_ENABLED_KEY),
        isFalse,
      );
      expect(
        prefs.getString(AppConstants.BEFORE_ADHAN_REMINDER_SOUND_KEY),
        AppConstants.DEFAULT_PRAYER_REMINDER_SOUND,
      );
      expect(
        prefs.getString(AppConstants.AFTER_ADHAN_REMINDER_SOUND_KEY),
        'noti_1',
      );
    },
  );

  testWidgets(
    'first-launch setup hides disabled reminder sounds and allows independent choices',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      Get.put(
        LocalizationController(
          sharedPreferences: preferences,
          apiClient: ApiClient(
            appBaseUrl: AppConstants.BASE_URL,
            sharedPreferences: preferences,
          ),
        ),
      );
      addTearDown(Get.reset);

      String? previewedSound;
      await tester.pumpWidget(
        GetMaterialApp(
          translations: _OnboardingTestTranslations(),
          locale: const Locale('en', 'US'),
          home: FirstLaunchSetupScreen(
            soundPreview: (assetPath) async => previewedSound = assetPath,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Welcome to SalaTime'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Before Adhan'), findsOneWidget);
      expect(find.text('After Adhan'), findsOneWidget);
      expect(find.text('5 minutes'), findsNothing);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile).at(1)).value,
        isFalse,
      );
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile).at(2)).value,
        isFalse,
      );
      expect(
        find.byKey(const Key('onboarding_adhan_preview_button')),
        findsOneWidget,
      );

      final adhanToggle = find.byType(SwitchListTile).first;
      if (!tester.widget<SwitchListTile>(adhanToggle).value) {
        await tester.tap(adhanToggle);
        await tester.pump();
      }
      await tester.ensureVisible(
        find.byKey(const Key('onboarding_adhan_preview_button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('onboarding_adhan_preview_button')),
      );
      await tester.pump();
      expect(previewedSound, AppConstants.DEFAULT_NOTIFICATION_SOUND_ASSET);
      for (final kind in ['before', 'after']) {
        final toggle = find.byType(SwitchListTile).at(kind == 'before' ? 1 : 2);
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(
          find.byKey(Key('onboarding_${kind}_preview_button')),
          findsOneWidget,
        );
      }
      for (final choice in {
        'adhan': 'azan_3',
        'before': 'noti_beep_beep',
        'after': 'noti_1',
      }.entries) {
        final field = find.byWidgetPredicate(
          (w) =>
              w is DropdownButtonFormField<String> &&
              w.key.toString().contains('onboarding_${choice.key}_sound_'),
        );
        tester.widget<DropdownButtonFormField<String>>(field).onChanged!(
          choice.value,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(
            ValueKey('onboarding_${choice.key}_sound_${choice.value}'),
          ),
          findsOneWidget,
        );
        expect(previewedSound, 'assets/audio/${choice.value}.mp3');
      }
      await tester.ensureVisible(adhanToggle);
      await tester.tap(adhanToggle);
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  test('daylight theme follows local sunrise and sunset', () {
    expect(
      ThemeController.isDaylightAt(
        now: DateTime(2026, 9, 6, 7, 0),
        sunrise: '06:45',
        sunset: '19:52',
      ),
      isTrue,
    );
    expect(
      ThemeController.isDaylightAt(
        now: DateTime(2026, 9, 6, 20, 0),
        sunrise: '06:45',
        sunset: '19:52',
      ),
      isFalse,
    );
    expect(
      ThemeController.isDaylightAt(
        now: DateTime(2026, 9, 6, 6, 30),
        sunrise: '6:45 AM',
        sunset: '7:52 PM',
      ),
      isFalse,
    );
  });

  test('daily hadith selection is stable for a day and rotates', () {
    final morning = DateTime(2026, 9, 6, 8);
    final evening = DateTime(2026, 9, 6, 22);
    final tomorrow = DateTime(2026, 9, 7, 8);

    expect(
      ModernDailyHadithCard.indexForDate(morning),
      ModernDailyHadithCard.indexForDate(evening),
    );
    expect(
      ModernDailyHadithCard.indexForDate(tomorrow),
      isNot(ModernDailyHadithCard.indexForDate(morning)),
    );
  });

  test('system language is selected when it is supported', () {
    expect(
      LocalizationController.resolveLocale(
        systemLocale: const Locale('fr', 'CA'),
      ),
      const Locale('fr', 'FR'),
    );
  });

  test('English is used when the system language is unsupported', () {
    expect(
      LocalizationController.resolveLocale(
        systemLocale: const Locale('de', 'DE'),
      ),
      const Locale('en', 'US'),
    );
  });

  test('a saved language choice takes priority over the system language', () {
    expect(
      LocalizationController.resolveLocale(
        systemLocale: const Locale('fr', 'FR'),
        savedLanguageCode: 'ar',
        savedCountryCode: 'SA',
      ),
      const Locale('ar', 'SA'),
    );
  });

  test('Adhan 2 is selected when no notification sound was saved', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = NotiSoundController();

    await controller.loadSelectedSound();

    final preferences = await SharedPreferences.getInstance();
    expect(
      controller.selectedSound.value,
      AppConstants.DEFAULT_NOTIFICATION_SOUND_ASSET,
    );
    expect(
      preferences.getString(AppConstants.SELECTED_NOTIFICATION_SOUND_KEY),
      AppConstants.DEFAULT_NOTIFICATION_SOUND,
    );
  });

  test('an existing notification sound choice is preserved', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.SELECTED_NOTIFICATION_SOUND_KEY: 'azan_3',
    });
    final controller = NotiSoundController();

    await controller.loadSelectedSound();

    expect(controller.selectedSound.value, 'assets/audio/azan_3.mp3');
  });

  test('selecting an Adhan always starts an audible preview', () async {
    SharedPreferences.setMockInitialValues({});
    final previewedSounds = <String>[];
    final controller = NotiSoundController(
      soundPreview: (path) async => previewedSounds.add(path),
    );
    await controller.loadSelectedSound();

    await controller.selectSound(AppConstants.DEFAULT_NOTIFICATION_SOUND_ASSET);
    await controller.selectSound(AppConstants.DEFAULT_NOTIFICATION_SOUND_ASSET);

    expect(previewedSounds, [
      AppConstants.DEFAULT_NOTIFICATION_SOUND_ASSET,
      AppConstants.DEFAULT_NOTIFICATION_SOUND_ASSET,
    ]);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(AppConstants.SELECTED_NOTIFICATION_SOUND_KEY),
      AppConstants.DEFAULT_NOTIFICATION_SOUND,
    );
  });

  test('prayer reminders use safe defaults when not configured', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = PrayerReminderController();

    await controller.loadPreferences();

    expect(controller.beforeEnabled.value, isFalse);
    expect(controller.afterEnabled.value, isFalse);
    expect(
      controller.beforeMinutes.value,
      AppConstants.DEFAULT_PRAYER_REMINDER_MINUTES,
    );
    expect(
      controller.afterMinutes.value,
      AppConstants.DEFAULT_PRAYER_REMINDER_MINUTES,
    );
    expect(
      controller.beforeSound.value,
      AppConstants.DEFAULT_PRAYER_REMINDER_SOUND,
    );
    expect(controller.afterSound.value, 'noti_beep');
  });

  test('saved prayer reminder choices are restored', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.BEFORE_ADHAN_REMINDER_ENABLED_KEY: true,
      AppConstants.AFTER_ADHAN_REMINDER_ENABLED_KEY: true,
      AppConstants.BEFORE_ADHAN_REMINDER_MINUTES_KEY: 15,
      AppConstants.AFTER_ADHAN_REMINDER_MINUTES_KEY: 30,
      AppConstants.BEFORE_ADHAN_REMINDER_SOUND_KEY: 'noti_1',
      AppConstants.AFTER_ADHAN_REMINDER_SOUND_KEY: 'azan_1',
    });
    final controller = PrayerReminderController();

    await controller.loadPreferences();

    expect(controller.beforeEnabled.value, isTrue);
    expect(controller.afterEnabled.value, isTrue);
    expect(controller.beforeMinutes.value, 15);
    expect(controller.afterMinutes.value, 30);
    expect(controller.beforeSound.value, 'noti_1');
    expect(controller.afterSound.value, 'azan_1');
  });

  test(
    'selecting reminder sounds immediately plays each chosen sound',
    () async {
      SharedPreferences.setMockInitialValues({});
      final previewedSounds = <String>[];
      final controller = PrayerReminderController(
        soundPreview: (path) async => previewedSounds.add(path),
      );

      await controller.setSound(PrayerReminderType.before, 'noti_beep_beep');
      await controller.setSound(PrayerReminderType.after, 'noti_1');

      expect(previewedSounds, [
        'assets/audio/noti_beep_beep.mp3',
        'assets/audio/noti_1.mp3',
      ]);
    },
  );

  test('before and after reminders receive unique times and IDs', () {
    final prayerTime = DateTime(2026, 9, 4, 13, 30);

    expect(
      SalatWaqtService.reminderDateTime(prayerTime, 10, before: true),
      DateTime(2026, 9, 4, 13, 20),
    );
    expect(
      SalatWaqtService.reminderDateTime(prayerTime, 15, before: false),
      DateTime(2026, 9, 4, 13, 45),
    );
    expect(SalatWaqtService.beforeNotificationId(1), 1001);
    expect(SalatWaqtService.afterNotificationId(1), 2001);
    expect(
      SalatWaqtService.beforeNotificationId(1),
      isNot(SalatWaqtService.afterNotificationId(1)),
    );
  });

  testWidgets('a home bell toggles only its prayer notifications', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      AppConstants.BEFORE_ADHAN_REMINDER_ENABLED_KEY: true,
      AppConstants.AFTER_ADHAN_REMINDER_ENABLED_KEY: true,
    });
    final preferences = await SharedPreferences.getInstance();
    Get.put<SharedPreferences>(preferences);
    addTearDown(Get.reset);
    final repository = SalatWaqtRepository();
    await repository.seedSalatWaqt();
    final controller =
        PrayerTimeController(
            apiClient: ApiClient(
              appBaseUrl: AppConstants.BASE_URL,
              sharedPreferences: preferences,
            ),
          )
          ..currentWaqtName.value = 'Fajr'
          ..currentWaktTime.value = '05:31'
          ..saveAddress.value = 'Fes'
          ..prayerTimeModel = PrayerTimeModel(
            data: Data(
              fajrStart: '05:31',
              sunrise: '06:57',
              zuhrStart: '13:18',
              asrStart: '16:54',
              maghribStart: '19:39',
              ishaStart: '21:00',
            ),
          );
    var rescheduleCount = 0;

    await tester.pumpWidget(
      GetMaterialApp(
        translations: _PrayerDashboardTestTranslations(),
        locale: const Locale('en', 'US'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ModernPrayerDashboard(
              prayerTimeController: controller,
              notificationRepository: repository,
              rescheduleNotifications: () async => rescheduleCount++,
              now: () => DateTime(2026, 9, 6, 5, 20),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final hijriDate = tester.widget<Text>(
      find.byKey(const ValueKey('hijri_date_text')),
    );
    final gregorianDate = tester.widget<Text>(
      find.byKey(const ValueKey('gregorian_date_text')),
    );
    expect(hijriDate.data, "24 Rabi' al-Awwal 1448");
    expect(gregorianDate.data, 'Sunday, September 6, 2026');
    expect(
      hijriDate.style?.fontSize,
      greaterThan(gregorianDate.style!.fontSize!),
    );

    final fajrBell = find.byKey(const ValueKey('prayer_notification_1'));
    expect(fajrBell, findsOneWidget);
    expect(tester.widget<IconButton>(fajrBell).onPressed, isNotNull);
    expect(
      find.descendant(
        of: fajrBell,
        matching: find.byIcon(Icons.notifications_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(fajrBell);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final prayers = await repository.getSalatWaqtList();
    expect(
      prayers.singleWhere((prayer) => prayer.id == 1).isNotificationEnabled,
      isFalse,
    );
    expect(
      prayers
          .where((prayer) => prayer.id != 1)
          .every((prayer) => prayer.isNotificationEnabled),
      isTrue,
    );
    expect(rescheduleCount, 1);
    expect(
      find.descendant(
        of: fajrBell,
        matching: find.byIcon(Icons.notifications_none_rounded),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('date arrows update prayer times and reuse cached dates', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      AppConstants.IS_MANUAL_PRAYER_TIME: true,
      AppConstants.isPrayerTme: true,
      AppConstants.saveCityName: 'Fes',
      'selectedCalculationMethod': '21',
      'selectedPrayerMadhab': 'STANDARD',
    });
    final preferences = await SharedPreferences.getInstance();
    Get.put<SharedPreferences>(preferences);
    addTearDown(Get.reset);
    const timezoneChannel = MethodChannel('flutter_timezone');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          timezoneChannel,
          (_) async => 'Africa/Casablanca',
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(timezoneChannel, null),
    );

    final apiClient = _CountingPrayerApiClient(preferences);
    final controller = PrayerTimeController(apiClient: apiClient)
      ..currentWaqtName.value = 'Fajr'
      ..currentWaktTime.value = '05:31'
      ..saveAddress.value = 'Fes'
      ..prayerTimeModel = PrayerTimeModel(
        data: Data(
          date: '2026-09-06',
          fajrStart: '05:31',
          sunrise: '06:57',
          zuhrStart: '13:18',
          asrStart: '16:54',
          maghribStart: '19:39',
          ishaStart: '21:00',
        ),
      );
    final repository = SalatWaqtRepository();
    await repository.seedSalatWaqt();

    await tester.pumpWidget(
      GetMaterialApp(
        translations: _PrayerDashboardTestTranslations(),
        locale: const Locale('en', 'US'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ModernPrayerDashboard(
              prayerTimeController: controller,
              notificationRepository: repository,
              now: () => DateTime(2026, 9, 6, 5, 20),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const ValueKey('prayer_date_next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('gregorian_date_text')))
          .data,
      'Monday, September 7, 2026',
    );
    expect(find.text('05:30'), findsOneWidget);
    expect(apiClient.callCount, 1);
    expect(controller.prayerTimeModel?.data?.fajrStart, '05:31');

    await tester.tap(find.byKey(const ValueKey('prayer_date_previous')));
    await tester.pump();
    expect(apiClient.callCount, 1);

    await tester.tap(find.byKey(const ValueKey('prayer_date_next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(apiClient.callCount, 1);
    expect(find.text('05:30'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('active prayer is automatically brought into view', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    Get.put<SharedPreferences>(preferences);
    addTearDown(Get.reset);
    final controller =
        PrayerTimeController(
            apiClient: ApiClient(
              appBaseUrl: AppConstants.BASE_URL,
              sharedPreferences: preferences,
            ),
          )
          ..currentWaqtName.value = 'Maghrib'
          ..currentWaktTime.value = '19:51'
          ..prayerTimeModel = PrayerTimeModel(
            data: Data(
              fajrStart: '05:25',
              zuhrStart: '13:22',
              asrStart: '17:00',
              maghribStart: '19:51',
              ishaStart: '21:13',
            ),
          );

    await tester.pumpWidget(
      GetMaterialApp(
        translations: _TestTranslations(),
        locale: const Locale('en', 'US'),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: ModernNextPrayerCard(
                prayerTimeController: controller,
                now: () => DateTime(2026, 8, 30, 19, 49),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final prayerList = tester.widget<ListView>(find.byType(ListView));
    expect(prayerList.controller, isNotNull);
    expect(prayerList.controller!.offset, greaterThan(0));

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _TestTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en_US': {'adhan': 'A'},
  };
}

class _CountingPrayerApiClient extends ApiClient {
  int callCount = 0;
  int calendarCallCount = 0;
  int dailyCallCount = 0;
  final List<String> requestedDates = [];
  final bool alwaysOffline;

  _CountingPrayerApiClient(
    SharedPreferences preferences, {
    this.alwaysOffline = false,
  }) : super(appBaseUrl: AppConstants.BASE_URL, sharedPreferences: preferences);

  @override
  Future<Response> postData(
    String uri,
    dynamic body, {
    Map<String, String>? headers,
  }) async {
    callCount++;
    final request = body as Map<String, dynamic>;
    final date = request['date'] as String;
    requestedDates.add(date);
    if (alwaysOffline) {
      return const Response(
        statusCode: 1,
        statusText: ApiClient.noInternetMessage,
      );
    }
    if (uri == AppConstants.PRAYER_TIME_CALENDAR) {
      calendarCallCount++;
      final parsedAnchor = DateTime.parse(date);
      final anchor = DateTime.utc(
        parsedAnchor.year,
        parsedAnchor.month,
        parsedAnchor.day,
      );
      final firstDate = anchor.subtract(const Duration(days: 7));
      final days = List.generate(53, (index) {
        final day = firstDate.add(Duration(days: index));
        final dayString = DateFormat('yyyy-MM-dd').format(day);
        return _prayerTimeData(dayString);
      });
      return Response(
        statusCode: 200,
        body: {
          'status': true,
          'message': 'ok',
          'data': {
            'anchor_date': date,
            'start_date': DateFormat('yyyy-MM-dd').format(firstDate),
            'end_date': DateFormat(
              'yyyy-MM-dd',
            ).format(anchor.add(const Duration(days: 45))),
            'past_days': 7,
            'future_days': 45,
            'count': 53,
            'days': days,
            'missing_dates': <String>[],
          },
        },
      );
    }
    dailyCallCount++;
    return Response(
      statusCode: 200,
      body: {'status': true, 'message': 'ok', 'data': _prayerTimeData(date)},
    );
  }

  Map<String, dynamic> _prayerTimeData(String date) => {
    'date': date,
    'is_jumma': false,
    'imsak': '05:20',
    'fajr_start': '05:30',
    'sunrise': '06:55',
    'zuhr_start': '13:18',
    'asr_start': '16:54',
    'maghrib_start': '19:39',
    'isha_start': '21:00',
    'sehri': '05:20',
    'iftar': '19:39',
  };
}

class _PrayerDashboardTestTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en_US': {
      'next_prayer': 'Next prayer',
      'countdown_prefix': 'in',
      'previous_day': 'Previous day',
      'next_day': 'Next day',
      'hijri_month_3': "Rabi' al-Awwal",
      'fajr': 'Fajr',
      'sunrise': 'Sunrise',
      'dhuhr': 'Dhuhr',
      'asr': 'Asr',
      'magrib': 'Maghrib',
      'isha': 'Isha',
      'enable_prayer_notifications': 'Enable notifications for @prayer',
      'disable_prayer_notifications': 'Disable notifications for @prayer',
    },
  };
}

class _OnboardingTestTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en_US': {
      'onboarding_welcome_title': 'Welcome to SalaTime',
      'onboarding_welcome_body': 'Setup body',
      'onboarding_language_label': 'Application language',
      'onboarding_settings_title': 'Prayer notifications',
      'onboarding_settings_body': 'Settings body',
      'onboarding_enable_adhan': 'Enable the Adhan',
      'onboarding_enable_adhan_description': 'Enable prayer Adhan',
      'onboarding_battery_note': 'Battery note',
      'onboarding_previous': 'Previous',
      'onboarding_next': 'Next',
      'onboarding_finish': 'Finish',
      'before_adhan': 'Before Adhan',
      'before_adhan_description': 'Notify me before each enabled Adhan',
      'after_adhan': 'After Adhan',
      'after_adhan_description': 'Notify me for the Iqama',
      'minutes_before': 'Minutes before',
      'minutes_after': 'Minutes after',
      'minutes': 'minutes',
      'choose_sound_for_notification': 'Adhan sound',
      'preview_sound': 'Listen',
      'adhan_1': 'Adhan 1',
      'adhan_2': 'Adhan 2',
      'adhan_3': 'Adhan 3',
    },
  };
}
