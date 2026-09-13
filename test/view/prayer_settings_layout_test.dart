import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/package_prayer_time_controller.dart';
import 'package:salatime/data/api/api_client.dart';
import 'package:salatime/data/model/response/todays_prayer_time_model.dart';
import 'package:salatime/theme/modern_dark_theme.dart';
import 'package:salatime/theme/modern_light_theme.dart';
import 'package:salatime/view/screens/prayer_settings/calculation_method_screen.dart';
import 'package:salatime/view/screens/prayer_settings/prayer_calculation_settings.dart';
import 'package:salatime/view/screens/prayer_settings/widget/custom_prayer_dropdown.dart';

class _Strings extends Translations {
  _Strings(this.french);
  final Map<String, String> french;
  @override
  Map<String, Map<String, String>> get keys => {'fr': french};
}

class _PrayerController extends PrayerTimeController {
  _PrayerController(ApiClient apiClient) : super(apiClient: apiClient);

  int settingsLoads = 0;
  int locationLoads = 0;
  int timeLoads = 0;
  int configuredRefreshes = 0;
  @override
  String? get selectedCalculationMethod => '1';
  @override
  String? get selectedPrayerMadhab => 'STANDARD';
  @override
  Future<void> loadPrayerTimeSettings() async {
    settingsLoads++;
  }

  @override
  Future<void> getLocation() async {
    locationLoads++;
  }

  @override
  Future<void> cityCategoryListData() async {}
  @override
  Future<void> refreshConfiguredPrayerTime() async {
    configuredRefreshes++;
  }

  @override
  Future<PrayerTimeModel?> fetchPrayerTime({
    bool reload = true,
    bool isManualPrayerTme = false,
    String? manualCity,
    DateTime? date,
    bool applyResult = true,
  }) async {
    timeLoads++;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, String> french;
  setUpAll(() async {
    french = Map<String, String>.from(
      jsonDecode(await rootBundle.loadString('assets/language/fr.json')),
    );
    await (FontLoader(
      'Roboto',
    )..addFont(rootBundle.load('assets/font/Roboto-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  tearDown(Get.reset);

  for (final (width, scale) in [(320.0, 2.0), (360.0, 2.0), (360.0, 1.0)]) {
    for (final dark in [false, true]) {
      testWidgets(
        'French prayer settings fit ${width}px dark=$dark with ${scale}x text',
        (tester) async {
          SharedPreferences.setMockInitialValues({'is24HrFormat': true});
          final prefs = await SharedPreferences.getInstance();
          final controller =
              Get.put<PrayerTimeController>(
                    _PrayerController(
                        ApiClient(
                          appBaseUrl: 'https://example.invalid',
                          sharedPreferences: prefs,
                        ),
                      )
                      ..saveAddress.value =
                          'Saint-Étienne-du-Rouvray, Normandie',
                  )
                  as _PrayerController;
          Get.put<ApiClient>(controller.apiClient);
          tester.view.physicalSize = Size(width, 720);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final captureKey = GlobalKey();
          await tester.pumpWidget(
            GetMaterialApp(
              locale: const Locale('fr'),
              translations: _Strings(french),
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              supportedLocales: const [Locale('en'), Locale('fr')],
              theme: dark ? modernDark : modernLight,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: RepaintBoundary(
                key: captureKey,
                child: const Scaffold(
                  body: SingleChildScrollView(
                    padding: EdgeInsets.all(8),
                    child: PrayerTimeCalculationSettings(),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.text(french['prayer_time_settings']!));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          final formatLabel = find.text(
            french['show_prayer_time_formation_as_a_24_hr_clock']!,
          );
          final paragraph = tester.renderObject<RenderParagraph>(formatLabel);
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(tester.getRect(find.byType(Switch)).right, lessThan(width));
          await tester.scrollUntilVisible(find.byType(Switch), 100);
          await tester.tap(find.byType(Switch));
          await tester.pumpAndSettle();
          expect(prefs.getBool('is24HrFormat'), isFalse);
          expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
          expect(tester.takeException(), isNull);

          final directory = Platform.environment['SALATIME_QA_DIR'];
          if (directory != null) {
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .jumpTo(0);
            await tester.pumpAndSettle();
            await tester.runAsync(() async {
              final boundary =
                  captureKey.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final capture = await boundary.toImage(pixelRatio: 1);
              try {
                final bytes = await capture.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await Directory(directory).create(recursive: true);
                await File(
                  '$directory/prayer-settings-${width.toInt()}-${scale.toInt()}x-${dark ? 'dark' : 'light'}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
              } finally {
                capture.dispose();
              }
            });
          }

          expect(controller.settingsLoads, 1);
          final methods = find.byKey(
            const ValueKey('calculation-method-settings-entry'),
          );
          await tester.scrollUntilVisible(methods, 150);
          await tester.tap(methods);
          await tester.pumpAndSettle();
          expect(find.byType(CalculationMethodScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
          Navigator.of(
            tester.element(find.byType(CalculationMethodScreen)),
          ).pop();
          await tester.pumpAndSettle();

          // The remaining madhab menu uses the same accessible text scale.
          final dropdown = find.byType(CustomPrayerSettingDropDown);
          await tester.scrollUntilVisible(dropdown, 150);
          await tester.tap(dropdown);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          Navigator.of(tester.element(dropdown)).pop();
          await tester.pumpAndSettle();
          controller.update();
          await tester.pumpAndSettle();
          expect(controller.settingsLoads, 2);
          expect(controller.locationLoads, 0);
          expect(controller.timeLoads, 0);
          expect(controller.configuredRefreshes, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'long calculation names remain readable and selectable in the menu',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const first =
          'Autorité générale des affaires islamiques et des dotations';
      const second =
          'Comité de détermination des horaires et observation de la lune';
      String selected = 'first';
      await tester.pumpWidget(
        MaterialApp(
          theme: modernDark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: StatefulBuilder(
                builder: (context, setState) => CustomPrayerSettingDropDown(
                  dwItems: const [
                    {'id': 'first', 'value': first},
                    {'id': 'second', 'value': second},
                  ],
                  dwValue: selected,
                  onChange: (value) => setState(() => selected = value),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byTooltip(first), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final menuChoice = find.text(second).last;
      expect(
        tester.renderObject<RenderParagraph>(menuChoice).didExceedMaxLines,
        isFalse,
      );
      await tester.tap(menuChoice);
      await tester.pumpAndSettle();
      expect(selected, 'second');
      expect(tester.takeException(), isNull);
    },
  );
}
