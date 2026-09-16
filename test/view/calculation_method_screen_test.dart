import 'dart:async';
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
import 'package:salatime/helper/prayer_calculation_methods.dart';
import 'package:salatime/theme/modern_dark_theme.dart';
import 'package:salatime/theme/modern_light_theme.dart';
import 'package:salatime/view/screens/prayer_settings/calculation_method_screen.dart';
import 'package:salatime/view/screens/prayer_settings/prayer_calculation_settings.dart';

class _Strings extends Translations {
  _Strings(this.keys);
  @override
  final Map<String, Map<String, String>> keys;
}

class _Controller extends PrayerTimeController {
  _Controller(this.prefs)
    : super(
        apiClient: ApiClient(
          appBaseUrl: 'https://example.invalid',
          sharedPreferences: prefs,
        ),
      );
  final SharedPreferences prefs;
  String selected = '10';
  bool manual = false;
  bool automatic = false;
  String? country;
  @override
  bool get automaticCalculationMethod => automatic;
  @override
  String? get calculationCountry => country;
  Future<void> Function()? persist;
  final List<String> selections = [];

  @override
  String? get selectedCalculationMethod => selected;
  @override
  bool get usesManualPrayerTimetable => manual;
  @override
  String? get selectedPrayerMadhab => 'STANDARD';
  @override
  Future<void> loadPrayerTimeSettings() async {
    selected = prefs.getString('selectedCalculationMethod') ?? '10';
    update();
  }

  @override
  Future<void> selectCalculationMethod(String id) async {
    selections.add(id);
    automatic = false;
    await persist?.call();
    await prefs.setString('selectedCalculationMethod', id);
    selected = id;
    update();
  }

  @override
  Future<void> selectAutomaticCalculationMethod(bool enabled) async {
    await persist?.call();
    automatic = enabled;
    update();
  }

  @override
  Future<void> getLocation() async {}
  @override
  Future<void> cityCategoryListData() async {}
  @override
  Future<void> refreshConfiguredPrayerTime() async {}
  @override
  Future<PrayerTimeModel?> fetchPrayerTime({
    bool reload = true,
    bool isManualPrayerTme = false,
    String? manualCity,
    DateTime? date,
    bool applyResult = true,
  }) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final strings = <String, Map<String, String>>{};
  late _Controller controller;
  late SharedPreferences prefs;
  setUpAll(() async {
    for (final locale in ['en', 'fr', 'ar']) {
      strings[locale] = Map<String, String>.from(
        jsonDecode(await rootBundle.loadString('assets/language/$locale.json')),
      );
    }
    await (FontLoader(
      'Roboto',
    )..addFont(rootBundle.load('assets/font/Roboto-Regular.ttf'))).load();
    await (FontLoader('NotoSansArabic')
          ..addFont(rootBundle.load('assets/font/NotoSansArabic-Regular.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({'selectedCalculationMethod': '10'});
    prefs = await SharedPreferences.getInstance();
    controller = _Controller(prefs);
    Get.put<PrayerTimeController>(controller);
  });
  tearDown(Get.reset);

  Widget app({
    String locale = 'fr',
    bool dark = false,
    double scale = 1,
    Widget? home,
    GlobalKey? captureKey,
  }) => GetMaterialApp(
    locale: Locale(locale),
    translations: _Strings(strings),
    supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: (dark ? modernDark : modernLight).copyWith(
      textTheme: (dark ? modernDark : modernLight).textTheme.apply(
        fontFamilyFallback: ['NotoSansArabic'],
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: RepaintBoundary(key: captureKey, child: child!),
    ),
    home:
        home ??
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CalculationMethodScreen(),
                  ),
                ),
                child: const Text('Open methods'),
              ),
            ),
          ),
        ),
  );
  Finder tile(String id) => find.byKey(ValueKey('calculation-method-$id'));
  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Open methods'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'saved selection is checked and unchanged selection does not rewrite preferences',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(app());
      await open(tester);
      expect(
        find.byType(ListTile),
        findsNWidgets(PrayerCalculationMethods.all.length + 1),
      );
      expect(tester.widget<ListTile>(tile('10')).selected, isTrue);
      await tester.ensureVisible(tile('10'));
      expect(
        tester
            .getSemantics(tile('10'))
            .getSemanticsData()
            .flagsCollection
            .isChecked,
        ui.CheckedState.isTrue,
      );
      semantics.dispose();
      await tester.tap(tile('10'));
      await tester.pumpAndSettle();
      expect(find.byType(CalculationMethodScreen), findsNothing);
      expect(controller.selections, isEmpty);
      expect(prefs.getString('selectedCalculationMethod'), '10');
    },
  );

  testWidgets(
    'automatic option displays the resolved method and same method tap disables auto',
    (tester) async {
      controller.automatic = true;
      controller.country = 'QA';
      await tester.pumpWidget(app());
      await open(tester);
      expect(tester.widget<SwitchListTile>(tile('automatic')).value, isTrue);
      expect(find.textContaining('QA ·'), findsOneWidget);
      await tester.ensureVisible(tile('10'));
      await tester.tap(tile('10'));
      await tester.pumpAndSettle();
      expect(controller.selections, ['10']);
      expect(controller.automatic, isFalse);
    },
  );

  testWidgets('automatic toggle retains errors and allows retry', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await open(tester);
    controller.persist = () => Future.error(StateError('storage unavailable'));
    await tester.tap(tile('automatic'));
    await tester.pumpAndSettle();
    expect(find.text('calculation_method_save_error'.tr), findsOneWidget);
    expect(controller.automatic, isFalse);
    controller.persist = null;
    await tester.tap(tile('automatic'));
    await tester.pumpAndSettle();
    expect(controller.automatic, isTrue);
    expect(find.textContaining('Pays indisponible'), findsOneWidget);
  });

  testWidgets(
    'persists the selected method before returning and prevents overlapping writes',
    (tester) async {
      final persistence = Completer<void>();
      controller.persist = () => persistence.future;
      await tester.pumpWidget(app());
      await open(tester);
      await tester.ensureVisible(tile('3'));
      await tester.tap(tile('3'));
      await tester.pump();
      expect(controller.selections, ['3']);
      expect(find.byType(CalculationMethodScreen), findsOneWidget);
      expect(prefs.getString('selectedCalculationMethod'), '10');
      expect(tester.widget<ListTile>(tile('5')).onTap, isNull);
      persistence.complete();
      await tester.pumpAndSettle();
      expect(prefs.getString('selectedCalculationMethod'), '3');
      expect(find.byType(CalculationMethodScreen), findsNothing);
      await open(tester);
      expect(tester.widget<ListTile>(tile('3')).selected, isTrue);
    },
  );

  testWidgets('persistence errors retain the selection and allow retry', (
    tester,
  ) async {
    controller.persist = () => Future.error(StateError('storage unavailable'));
    await tester.pumpWidget(app());
    await open(tester);
    await tester.ensureVisible(tile('3'));
    await tester.tap(tile('3'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('calculation_method_save_error'.tr),
      -200,
    );
    expect(find.text('calculation_method_save_error'.tr), findsOneWidget);
    expect(prefs.getString('selectedCalculationMethod'), '10');
    expect(tester.widget<ListTile>(tile('10')).selected, isTrue);
    controller.persist = null;
    await tester.ensureVisible(tile('3'));
    await tester.tap(tile('3'));
    await tester.pumpAndSettle();
    expect(find.byType(CalculationMethodScreen), findsNothing);
    expect(prefs.getString('selectedCalculationMethod'), '3');
  });

  testWidgets('external preference updates refresh the visible checkmark', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await open(tester);
    controller.selected = '9';
    controller.update();
    await tester.pump();
    expect(tester.widget<ListTile>(tile('9')).selected, isTrue);
    expect(tester.widget<ListTile>(tile('10')).selected, isFalse);
    expect(controller.selections, isEmpty);
  });

  testWidgets(
    'manual timetable keeps the entry and lets the user save a method with an explanation',
    (tester) async {
      controller.manual = true;
      controller.isPrayerTimes.value = true;
      await tester.pumpWidget(
        app(
          home: const Scaffold(
            body: SingleChildScrollView(child: PrayerTimeCalculationSettings()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('prayer_time_settings'.tr));
      await tester.pumpAndSettle();
      final entry = find.byKey(
        const ValueKey('calculation-method-settings-entry'),
      );
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.text('calculation_method_manual_notice'.tr), findsOneWidget);
      await tester.ensureVisible(tile('3'));
      await tester.tap(tile('3'));
      await tester.pumpAndSettle();
      expect(prefs.getString('selectedCalculationMethod'), '3');
      expect(find.byType(CalculationMethodScreen), findsNothing);
      expect(
        find.descendant(
          of: entry,
          matching: find.text(
            calculationMethodLabel(PrayerCalculationMethods.byId('3')!),
          ),
        ),
        findsOneWidget,
      );
    },
  );

  for (final (locale, width, scale) in [
    ('fr', 320.0, 2.0),
    ('ar', 320.0, 2.0),
    ('fr', 360.0, 1.0),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'method names fit ${width.toInt()}px $locale dark=$dark with ${scale.toInt()}x text',
        (tester) async {
          tester.view.physicalSize = Size(width, scale == 1 ? 900 : 720);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final captureKey = GlobalKey();
          await tester.pumpWidget(
            app(
              locale: locale,
              dark: dark,
              scale: scale,
              captureKey: captureKey,
            ),
          );
          await open(tester);
          expect(tester.takeException(), isNull);
          final directory = Platform.environment['SALATIME_QA_DIR'];
          if (directory != null) {
            await tester.runAsync(() async {
              final boundary =
                  captureKey.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 1);
              try {
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await Directory(directory).create(recursive: true);
                await File(
                  '$directory/calculation-methods-$locale-${dark ? 'dark' : 'light'}${scale == 1 ? '-360-1x' : ''}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
              } finally {
                image.dispose();
              }
            });
          }
          await tester.scrollUntilVisible(tile('3'), 200);
          for (final method in PrayerCalculationMethods.all) {
            await tester.ensureVisible(tile(method.id));
            await tester.pump();
            final name = find.descendant(
              of: tile(method.id),
              matching: find.byType(Text),
            );
            expect(
              tester.renderObject<RenderParagraph>(name).didExceedMaxLines,
              isFalse,
            );
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
