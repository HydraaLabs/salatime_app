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
import 'package:zabi/controller/dhikr_controller.dart';
import 'package:zabi/controller/home_layout_controller.dart';
import 'package:zabi/controller/quran_settings_controller.dart';
import 'package:zabi/data/api/api_client.dart';
import 'package:zabi/data/repository/dikir_list_repo.dart';
import 'package:zabi/data/repository/quran_setting_repo.dart';
import 'package:zabi/helper/athkar_catalog.dart';
import 'package:zabi/helper/route_helper.dart';
import 'package:zabi/service/athkar_reader_preferences.dart';
import 'package:zabi/service/reading/reading_progress_service.dart';
import 'package:zabi/theme/modern_dark_theme.dart';
import 'package:zabi/theme/modern_light_theme.dart';
import 'package:zabi/view/screens/dhikr/dhikr_screen.dart';
import 'package:zabi/view/screens/dhikr/widgets/athkar_text_size_sheet.dart';
import 'package:zabi/view/screens/dhikr/widgets/personal_dhikr_screen.dart';
import 'package:zabi/view/screens/reading/reading_progress_screen.dart';

import '../support/fake_reading_progress.dart';

class _Strings extends Translations {
  _Strings(this.keys);
  @override
  final Map<String, Map<String, String>> keys;
}

class _ReaderPreferences extends AthkarReaderPreferences {
  bool failWrite = false;
  @override
  Future<void> save(double size) async {
    if (failWrite) throw StateError('Write unavailable');
    await super.save(size);
  }
}

class _PersonalSettings extends SettingsController {
  _PersonalSettings(QuranSettingsRepo repo) : super(quranSettingRepo: repo);
  @override
  // Existing personal cards only need the selected font, not remote settings.
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final strings = <String, Map<String, String>>{};
  late SharedPreferences prefs;
  late AthkarCatalog fixture;
  late AthkarCatalog realCatalog;
  late FakeReadingProgress reading;

  setUpAll(() async {
    for (final locale in ['en', 'fr', 'ar']) {
      strings[locale] = Map<String, String>.from(
        jsonDecode(await rootBundle.loadString('assets/language/$locale.json')),
      );
    }
    for (final (name, asset) in [
      ('Roboto', 'assets/font/Roboto-Regular.ttf'),
      ('NotoSansArabic', 'assets/font/NotoSansArabic-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(name)..addFont(rootBundle.load(asset))).load();
    }
    realCatalog = await AthkarCatalog.load();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    Get.put(HomeLayoutController(sharedPreferences: prefs));
    fixture = AthkarCatalog(
      categories: [
        for (final id in [
          'morning',
          'evening',
          'after_prayer',
          'sleep',
          'travel',
        ])
          AthkarCategory(
            id: id,
            titleArabic: 'أذكار',
            entries: [
              AthkarEntry(
                id: '$id:1',
                sourceId: 1,
                categoryId: id,
                title: 'ذِكْرُ اللَّهِ',
                body: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
                repetition: 'ثلاث مرات',
                narrator: 'مرجع النص',
              ),
              if (id == 'morning')
                const AthkarEntry(
                  id: 'morning:2',
                  sourceId: 2,
                  categoryId: 'morning',
                  body: 'نص بلا عدد محدد',
                ),
            ],
          ),
      ],
    );
    reading = FakeReadingProgress();
    reading.targets.addEntries(
      fixture.entries.map(
        (entry) => MapEntry(entry.id, entry.repetitions ?? 1),
      ),
    );
  });
  tearDown(Get.reset);

  Widget app({
    String locale = 'fr',
    bool dark = false,
    double scale = 1,
    Future<AthkarCatalog> Function()? load,
    AthkarReaderPreferences reader = const AthkarReaderPreferences(),
    GlobalKey? capture,
  }) => GetMaterialApp(
    locale: Locale(locale),
    translations: _Strings(strings),
    supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: (dark ? modernDark : modernLight).copyWith(
      textTheme: (dark ? modernDark : modernLight).textTheme.apply(
        fontFamilyFallback: ['NotoSansArabic'],
      ),
      primaryTextTheme: (dark ? modernDark : modernLight).primaryTextTheme
          .apply(fontFamilyFallback: ['NotoSansArabic']),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: RepaintBoundary(key: capture, child: child!),
    ),
    getPages: [
      GetPage(
        name: RouteHelper.addDhikr,
        page: () => const Scaffold(body: Text('Existing add form')),
      ),
    ],
    home: DhikrScreen(
      appBackButton: false,
      loadCatalog: load ?? () async => fixture,
      readerPreferences: reader,
      readingProgress: reading,
    ),
  );
  Finder key(String value) => find.byKey(ValueKey(value));
  Future<void> tab(WidgetTester tester, String id) async {
    await tester.ensureVisible(key('athkar-tab-$id'));
    await tester.tap(key('athkar-tab-$id'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'loads the offline catalogue once and keeps five scrollable categories without an API controller',
    (tester) async {
      var loads = 0;
      await tester.pumpWidget(
        app(
          load: () async {
            loads++;
            return fixture;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(Get.isRegistered<DhikrController>(), isFalse);
      expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isTrue);
      expect(find.byType(Tab), findsNWidgets(5));
      for (final id in ['evening', 'after_prayer', 'sleep', 'morning']) {
        await tab(tester, id);
        expect(key('athkar-card-$id:1'), findsOneWidget);
      }
      expect(loads, 1);
      final body = tester.widget<SelectableText>(
        key('athkar-arabic-morning:1'),
      );
      expect(body.textDirection, TextDirection.rtl);
      expect(body.data, fixture.entry('morning:1')!.arabic);
      expect(find.text('مرجع النص'), findsOneWidget);
      expect(find.text('ثلاث مرات'), findsOneWidget);
      expect(key('athkar-count-morning:2'), findsNothing);
      expect(reading.writes, 0);
    },
  );

  testWidgets(
    'per-card counters stop at the source count and reset without modifying personal counts',
    (tester) async {
      await prefs.setInt('personal-counter', 42);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.ensureVisible(key('athkar-count-morning:1'));
      for (var i = 0; i < 3; i++) {
        await tester.tap(key('athkar-count-morning:1'));
        await tester.pump();
      }
      expect(
        tester.widget<FilledButton>(key('athkar-count-morning:1')).onPressed,
        isNull,
      );
      expect(find.text(strings['fr']!['athkar_completed']!), findsOneWidget);
      await tab(tester, 'evening');
      expect(
        find.text(
          strings['fr']!['athkar_counter_progress']!
              .replaceAll('@current', '0')
              .replaceAll('@total', '3'),
        ),
        findsOneWidget,
      );
      await tab(tester, 'morning');
      expect(key('athkar-reset-morning:1'), findsOneWidget);
      await tester.tap(key('athkar-reset-morning:1'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(key('athkar-count-morning:1')).onPressed,
        isNotNull,
      );
      expect(prefs.getInt('personal-counter'), 42);
      expect(prefs.getKeys(), {'personal-counter'});
    },
  );

  testWidgets(
    'extra categories show the same reactive counters and AA controls',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tab(tester, 'more');
      await tester.tap(key('athkar-category-travel'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(key('athkar-count-travel:1'));
      await tester.tap(key('athkar-count-travel:1'));
      await tester.pump();
      expect(key('athkar-reset-travel:1'), findsOneWidget);
      await tester.tap(
        find.byTooltip(strings['fr']!['athkar_text_size']!).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(key('athkar-size-increase'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(AthkarTextSizeSheet))).pop();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SelectableText>(key('athkar-arabic-travel:1'))
            .style!
            .fontSize,
        28,
      );
    },
  );

  testWidgets(
    'checkboxes restore the day and cover entries without repetition instructions',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(reading.writes, 0);
      await tester.ensureVisible(key('athkar-read-morning:1'));
      await tester.tap(key('athkar-read-morning:1'));
      await tester.pumpAndSettle();
      expect(reading.todayCount(ReadingProgressKind.athkar, 'morning:1'), 3);
      expect(
        tester.widget<CheckboxListTile>(key('athkar-read-morning:1')).value,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(key('athkar-read-morning:1')).value,
        isTrue,
      );
      await tester.ensureVisible(key('athkar-read-morning:2'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(key('athkar-read-morning:2'));
      await tester.pumpAndSettle();
      await tester.tap(key('athkar-read-morning:2'));
      await tester.pumpAndSettle();
      expect(reading.todayCount(ReadingProgressKind.athkar, 'morning:2'), 1);
      expect(key('athkar-count-morning:2'), findsNothing);
      await tester.tap(key('athkar-read-morning:2'));
      await tester.pump();
      expect(reading.todayCount(ReadingProgressKind.athkar, 'morning:2'), 0);
      reading.today = '2026-09-14';
      reading.refresh();
      await tester.pumpAndSettle();
      await tester.ensureVisible(key('athkar-read-morning:1'));
      expect(
        tester.widget<CheckboxListTile>(key('athkar-read-morning:1')).value,
        isFalse,
      );
      expect(
        reading.count(
          ReadingProgressKind.athkar,
          'morning:1',
          day: '2026-09-13',
        ),
        3,
      );
    },
  );

  testWidgets(
    'rapid repetition taps are atomic and account refresh clears old checkmarks',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.ensureVisible(key('athkar-count-morning:1'));
      await tester.tap(key('athkar-count-morning:1'));
      await tester.tap(key('athkar-count-morning:1'));
      await tester.tap(key('athkar-count-morning:1'));
      await tester.pump();
      expect(reading.todayCount(ReadingProgressKind.athkar, 'morning:1'), 3);
      reading.initialized = false;
      reading.values.clear();
      reading.refresh();
      await tester.pump();
      expect(
        tester.widget<CheckboxListTile>(key('athkar-read-morning:1')).onChanged,
        isNull,
      );
      await reading.initialize();
      await tester.pump();
      expect(
        tester.widget<CheckboxListTile>(key('athkar-read-morning:1')).value,
        isFalse,
      );
      expect(
        tester.widget<CheckboxListTile>(key('athkar-read-morning:1')).onChanged,
        isNotNull,
      );
    },
  );

  testWidgets(
    'reading save failure is visible and statistics opens without marking anything',
    (tester) async {
      reading.failWrite = true;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.ensureVisible(key('athkar-read-morning:1'));
      await tester.tap(key('athkar-read-morning:1'));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        tester.widget<CheckboxListTile>(key('athkar-read-morning:1')).value,
        isFalse,
      );
      await tester.tap(key('athkar-reading-progress'));
      await tester.pumpAndSettle();
      expect(find.byType(ReadingProgressScreen), findsOneWidget);
      expect(reading.historyCalls, 1);
      expect(reading.writes, 0);
    },
  );

  testWidgets(
    'AA persists immediately, restores after reopening and stays within reading bounds',
    (tester) async {
      await prefs.setDouble(AthkarReaderPreferences.storageKey, 38);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(key('athkar-text-size'));
      await tester.pumpAndSettle();
      await tester.tap(key('athkar-size-increase'));
      await tester.pumpAndSettle();
      expect(prefs.getDouble(AthkarReaderPreferences.storageKey), 40);
      expect(
        tester.widget<IconButton>(key('athkar-size-increase')).onPressed,
        isNull,
      );
      Navigator.of(tester.element(find.byType(AthkarTextSizeSheet))).pop();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SelectableText>(key('athkar-arabic-morning:1'))
            .style!
            .fontSize,
        40,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SelectableText>(key('athkar-arabic-morning:1'))
            .style!
            .fontSize,
        40,
      );
    },
  );

  testWidgets(
    'failed reading-size save restores the displayed size and permits retry',
    (tester) async {
      final reader = _ReaderPreferences()..failWrite = true;
      await tester.pumpWidget(app(reader: reader));
      await tester.pumpAndSettle();
      await tester.tap(key('athkar-text-size'));
      await tester.pumpAndSettle();
      await tester.tap(key('athkar-size-increase'));
      await tester.pumpAndSettle();
      expect(find.text(strings['fr']!['athkar_save_error']!), findsOneWidget);
      expect(find.text('26'), findsOneWidget);
      expect(prefs.containsKey(AthkarReaderPreferences.storageKey), isFalse);
      reader.failWrite = false;
      await tester.tap(key('athkar-size-increase'));
      await tester.pumpAndSettle();
      expect(find.text('28'), findsOneWidget);
      expect(prefs.getDouble(AthkarReaderPreferences.storageKey), 28);
    },
  );

  testWidgets('a failed asset read can be retried without a network request', (
    tester,
  ) async {
    var loads = 0;
    await tester.pumpWidget(
      app(
        load: () async {
          if (loads++ == 0) throw const AthkarCatalogException('missing');
          return fixture;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(strings['fr']!['athkar_load_error']!), findsOneWidget);
    await tester.tap(find.text(strings['fr']!['athkar_retry']!));
    await tester.pumpAndSettle();
    expect(key('athkar-card-morning:1'), findsOneWidget);
    expect(loads, 2);
  });

  testWidgets(
    'Plus retains the existing personal list, its stored data and add route',
    (tester) async {
      final saved = jsonEncode([
        {
          'id': 'mine',
          'englishName': 'My saved dhikr',
          'arabicName': 'ذكر',
          'englishDescription': 'Saved text',
          'arabicDescription': 'النص',
        },
      ]);
      await prefs.setString(LocalDhikrStorage.dhikrListKey, saved);
      final api = ApiClient(
        appBaseUrl: 'https://example.invalid',
        sharedPreferences: prefs,
      );
      Get.put(DhikrRepo(sharedPreferences: prefs, apiClient: api));
      Get.put<SettingsController>(
        _PersonalSettings(
          QuranSettingsRepo(sharedPreferences: prefs, apiClient: api),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tab(tester, 'more');
      await tester.tap(key('athkar-personal-entry'));
      await tester.pumpAndSettle();
      expect(find.byType(PersonalDhikrScreen), findsOneWidget);
      expect(find.text('My saved dhikr'), findsOneWidget);
      await tester.tap(key('athkar-add-personal'));
      await tester.pumpAndSettle();
      expect(find.text('Existing add form'), findsOneWidget);
      expect(prefs.getString(LocalDhikrStorage.dhikrListKey), saved);
    },
  );

  for (final locale in ['fr', 'ar']) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '$locale ${dark ? 'dark' : 'light'} ${scale}x: real long Arabic text fits portrait and landscape',
          (tester) async {
            tester.view.physicalSize = Size(scale == 1 ? 360 : 320, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final capture = GlobalKey();
            await tester.pumpWidget(
              app(
                locale: locale,
                dark: dark,
                scale: scale,
                load: () async => realCatalog,
                capture: capture,
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1);
              final png = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final dir = Directory('/tmp/salatime-athkar-qa');
              await dir.create(recursive: true);
              await File(
                '${dir.path}/athkar-$locale-${dark ? 'dark' : 'light'}-${scale.toInt()}x.png',
              ).writeAsBytes(png!.buffer.asUint8List());
              image.dispose();
            });
            await tester.drag(
              find.byKey(const PageStorageKey('athkar-list-morning')),
              const Offset(0, -500),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.tap(key('athkar-text-size'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            tester.view.physicalSize = const Size(800, 320);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
