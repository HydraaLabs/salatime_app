import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/hadith_controller.dart';
import 'package:salatime/controller/localization_controller.dart';
import 'package:salatime/controller/nearby_mosque_controller.dart';
import 'package:salatime/controller/offline_quran_controller.dart';
import 'package:salatime/controller/package_prayer_time_controller.dart';
import 'package:salatime/controller/prayer_time_adjustment.dart';
import 'package:salatime/controller/quran_settings_controller.dart';
import 'package:salatime/controller/theme_controller.dart';
import 'package:salatime/helper/automatic_prayer_method.dart';
import 'package:salatime/helper/get_di.dart' as di;
import 'package:salatime/helper/route_helper.dart';
import 'package:salatime/main.dart' as app;
import 'package:salatime/service/reading/reading_progress_service.dart';
import 'package:salatime/util/app_constants.dart';
import 'package:salatime/view/base/bottom_navbar.dart';
import 'package:salatime/view/screens/dhikr/dhikr_screen.dart';
import 'package:salatime/view/screens/home/modern/modern_home_screen.dart';
import 'package:salatime/view/screens/home/modern/widget/modern_quran_reading_card.dart';
import 'package:salatime/view/screens/name_generator/islamic_name_generator_screen.dart';
import 'package:salatime/view/screens/nearby_mosque/nearby_mosque_screen.dart';
import 'package:salatime/view/screens/offline_quran/main_offline_quran_screen.dart';
import 'package:salatime/view/screens/offline_quran/offline_surah_detail_screen.dart';

import 'support/capture_frames.dart';

const _locales = <String, Locale>{
  'fr-FR': Locale('fr', 'FR'),
  'en-US': Locale('en', 'US'),
  'ar': Locale('ar', 'SA'),
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'capture the seven Play features using real iOS screens',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.clear();
      await preferences.setString(AppConstants.LANGUAGE_CODE, 'fr');
      await preferences.setString(AppConstants.COUNTRY_CODE, 'FR');
      await preferences.setString(AppConstants.THEME_MODE_KEY, 'light');
      await preferences.setString(
        AppConstants.HOME_LAYOUT_OVERRIDE_KEY,
        'modern',
      );
      await preferences.setBool(AppConstants.isPrayerTme, true);
      await preferences.setBool(AppConstants.IS_MANUAL_PRAYER_TIME, true);
      await preferences.setString(AppConstants.saveCityName, 'Fès');
      await preferences.setDouble(AppConstants.manualCityLat, 34.0331);
      await preferences.setDouble(AppConstants.manualCityLng, -5.0003);
      await AutomaticPrayerMethod.saveCountry(
        preferences,
        manual: true,
        code: 'MA',
        latitude: 34.0331,
        longitude: -5.0003,
      );
      final languages = await di.init();
      await ReadingProgressService.instance.initialize();
      final prayer = Get.find<PrayerTimeController>();
      await Get.find<PrayerTimeAdjustmentController>().init();
      await prayer.refreshConfiguredPrayerTime();
      expect(prayer.prayerTimeModel?.data, isNotNull);

      const route = '/play-style-capture';
      RouteHelper.routes.add(
        GetPage(
          name: route,
          page: () => BottomNavbarScreen(
            pageBuilder: (_, index, active, returnHome) => index == 0
                ? const ModernHomeScreen()
                : DhikrScreen(appBackButton: true, onBackPressed: returnHome),
          ),
        ),
      );
      runApp(app.MyApp(languages: languages, initialRoute: route));
      await _waitFor(
        tester,
        () => find.byType(ModernHomeScreen).evaluate().isNotEmpty,
      );

      if (const String.fromEnvironment('SALATIME_CAPTURE_SET') ==
          'light-home-reader') {
        for (final entry in _locales.entries) {
          await _language(tester, entry.value);
          await Get.find<ThemeController>().setMode(ThemeController.light);
          await _capture(tester, '${entry.key}/01-prayer-times');
        }
        if (const bool.fromEnvironment('SALATIME_CAPTURE_READER')) {
          await _language(tester, _locales['fr-FR']!);
          Get.to<void>(
            () => const OfflineSuraDetaileScreen(
              appBackButton: true,
              surahNumber: '1',
            ),
          );
          await _waitFor(
            tester,
            () =>
                find.byType(OfflineSuraDetaileScreen).evaluate().isNotEmpty &&
                Get.isRegistered<OfflineQuranController>() &&
                Get.find<OfflineQuranController>().suraDetailsApiData != null &&
                !Get.find<OfflineQuranController>().isSurahDetailsLoading.value,
          );
          await _capture(tester, 'fr-FR/04-quran-reading');
        }
        return;
      }

      // The host sets the simulator's real location service to public Fès
      // coordinates and grants while-in-use permission after this app is installed.
      // No method channel, controller dataset or network response is replaced.
      // ignore: avoid_print
      print('SALATIME_STORE_PREPARE_LOCATION');
      await tester.pump(const Duration(seconds: 5));

      // Preserve every locally available feature even if a remote map/CDN later
      // fails. The name generator remains in its initial state: no AI request or
      // consent is submitted, and reading progress remains the fresh local state.
      for (final entry in _locales.entries) {
        await _language(tester, entry.value);
        await Get.find<ThemeController>().setMode(ThemeController.light);
        await tester.pump(const Duration(seconds: 1));
        final homeScroll = find
            .descendant(
              of: find.byType(ModernHomeScreen),
              matching: find.byType(Scrollable),
            )
            .first;
        tester.state<ScrollableState>(homeScroll).position.jumpTo(0);
        await _capture(tester, '${entry.key}/01-prayer-times');

        await Get.find<ThemeController>().setMode(ThemeController.dark);
        await tester.pump(const Duration(seconds: 1));
        await tester.ensureVisible(find.byType(ModernQuranReadingCard));
        await _capture(tester, '${entry.key}/02-home-reading');

        Get.to<void>(() => const MainOfflineQuranScreen(appBackButton: true));
        final quranTabs = find.descendant(
          of: find.byType(MainOfflineQuranScreen),
          matching: find.byType(TabBar),
        );
        await _waitFor(tester, () => quranTabs.evaluate().isNotEmpty);
        await tester.pump(const Duration(milliseconds: 500));
        // Wait for the destination route to build before selecting its real
        // first tab. The label varies by locale and is not a stable identifier.
        final surahTab = tester.widget<TabBar>(quranTabs).tabs.first;
        await tester.tap(find.byWidget(surahTab));
        await _waitFor(
          tester,
          () =>
              Get.isRegistered<OfflineQuranController>() &&
              Get.find<OfflineQuranController>().surahList.length == 114 &&
              !Get.find<OfflineQuranController>().isLoading.value,
        );
        await _capture(tester, '${entry.key}/03-quran-list');
        await _back(tester);

        final settings = Get.find<SettingsController>();
        final originalFontSize = settings.arabicFontSize.value;
        final isTablet =
            MediaQuery.sizeOf(
              tester.element(find.byType(ModernHomeScreen)),
            ).shortestSide >=
            600;
        if (isTablet) {
          // The ordinary reader settings offer this exact 14–40 font-size range.
          settings.changeArabicFontSize(40);
        }
        Get.to<void>(
          () => const OfflineSuraDetaileScreen(
            appBackButton: true,
            surahNumber: '1',
          ),
        );
        await _waitFor(
          tester,
          () =>
              find.byType(OfflineSuraDetaileScreen).evaluate().isNotEmpty &&
              Get.isRegistered<OfflineQuranController>() &&
              Get.find<OfflineQuranController>().suraDetailsApiData != null &&
              !Get.find<OfflineQuranController>().isSurahDetailsLoading.value,
        );
        await _capture(tester, '${entry.key}/04-quran-reading');
        await _back(tester);
        if (isTablet) settings.changeArabicFontSize(originalFontSize);

        Get.to<void>(
          () => const IslamicNameGeneratorScreen(appBackButton: true),
        );
        await _waitFor(
          tester,
          () => find.byType(IslamicNameGeneratorScreen).evaluate().isNotEmpty,
        );
        await _capture(tester, '${entry.key}/07-name-generator');
        await _back(tester);
      }

      for (final entry in _locales.entries) {
        await _language(tester, entry.value);
        // A new controller represents opening this screen in a fresh language;
        // never reuse another language's in-memory CDN edition cache.
        if (Get.isRegistered<HadithController>()) {
          await Get.delete<HadithController>(force: true);
        }
        Get.toNamed<void>(
          RouteHelper.hadithChapters,
          arguments: ['bukhari', 'Sahih al Bukhari'],
        );
        await _waitFor(
          tester,
          () =>
              Get.isRegistered<HadithController>() &&
              !Get.find<HadithController>().isLoadingHadithChapter.value &&
              (Get.find<HadithController>()
                      .hadithChapterModel
                      ?.chapters
                      ?.isNotEmpty ??
                  false),
          seconds: 150,
        );
        await _capture(tester, '${entry.key}/06-hadith-chapters');
        await _back(tester);
      }

      for (final entry in _locales.entries) {
        await _language(tester, entry.value);
        Get.to<void>(() => const NearbyMosque(appBackButton: true));
        await _waitFor(
          tester,
          () =>
              Get.isRegistered<NearbyMosqueController>() &&
              !Get.find<NearbyMosqueController>().isLoading.value &&
              Get.find<NearbyMosqueController>().places.isNotEmpty,
          seconds: 180,
        );
        final coordinates = Get.find<NearbyMosqueController>()
            .userLocation
            .value
            .split(',')
            .map(double.parse)
            .toList();
        expect(coordinates[0], closeTo(34.0331, 0.001));
        expect(coordinates[1], closeTo(-5.0003, 0.001));
        // Give actual OSM tile requests time to finish; all maps receive visual QA.
        await tester.pump(const Duration(seconds: 10));
        await _capture(tester, '${entry.key}/05-nearby-mosques');
        await _back(tester);
      }
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

Future<void> _language(WidgetTester tester, Locale locale) async {
  final index = AppConstants.languages.indexWhere(
    (item) => item.languageCode == locale.languageCode,
  );
  await Get.find<LocalizationController>().setLanguage(locale, index);
  await tester.pump(const Duration(seconds: 1));
  expect(Get.locale, locale);
}

Future<void> _back(WidgetTester tester) async {
  Get.back<void>();
  await _waitFor(
    tester,
    () => find.byType(ModernHomeScreen).evaluate().isNotEmpty,
  );
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.byType(ModernHomeScreen), findsOneWidget);
}

Future<void> _waitFor(
  WidgetTester tester,
  bool Function() ready, {
  int seconds = 40,
}) async {
  for (var attempt = 0; attempt < seconds * 4; attempt++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (ready()) return;
  }
  fail('The real screen did not finish loading within $seconds seconds.');
}

Future<void> _capture(WidgetTester tester, String name) async {
  await renderCaptureFrames(tester);
  if (name.endsWith('/02-home-reading')) {
    final titleContext = tester.element(
      find.text('quran_reading_progress_title'.tr),
    );
    expect(
      DefaultTextStyle.of(titleContext).style.color,
      Theme.of(titleContext).textTheme.bodyMedium!.color,
      reason: 'The real dark theme text animation must finish before capture.',
    );
  }
  expect(tester.takeException(), isNull);
  expect(find.byType(AlertDialog), findsNothing);
  // ignore: avoid_print
  print('SALATIME_STORE_CAPTURE:$name');
  final port = int.parse(const String.fromEnvironment('SALATIME_CAPTURE_PORT'));
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  try {
    // iOS simulators share the Mac's loopback network. The collector responds
    // only after simctl has saved and verified the native PNG. Never navigate
    // away merely because a fixed capture delay elapsed on a busy Mac runner.
    final request = await client.postUrl(
      Uri.parse('http://127.0.0.1:$port/capture'),
    );
    request.headers.contentType = ContentType.json;
    final body = utf8.encode(jsonEncode({'name': name}));
    request.contentLength = body.length;
    request.add(body);
    final response = await request.close().timeout(
      const Duration(seconds: 120),
    );
    final payload = await response.transform(utf8.decoder).join();
    expect(response.statusCode, HttpStatus.ok);
    expect(jsonDecode(payload), {'ok': true, 'name': name});
  } finally {
    client.close(force: true);
  }
}
