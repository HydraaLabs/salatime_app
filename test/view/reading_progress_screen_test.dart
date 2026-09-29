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
import 'package:salatime/controller/home_layout_controller.dart';
import 'package:salatime/helper/athkar_catalog.dart';
import 'package:salatime/service/mobile_auth_service.dart';
import 'package:salatime/service/reading/reading_progress_service.dart';
import 'package:salatime/theme/modern_dark_theme.dart';
import 'package:salatime/theme/modern_light_theme.dart';
import 'package:salatime/view/screens/account/account_screen.dart';
import 'package:salatime/view/screens/reading/reading_progress_screen.dart';

import '../support/fake_reading_progress.dart';

class _Strings extends Translations {
  _Strings(this.keys);
  @override
  final Map<String, Map<String, String>> keys;
}

class _Auth extends MobileAuthService {
  _Auth() : super(apiBaseUrl: 'https://example.test');

  @override
  Future<void> initialize() async {}

  @override
  Future<void> loadConfiguration() async {
    configuration.value = const MobileAuthConfiguration(
      available: true,
      email: true,
    );
  }

  @override
  Future<String?> accessToken() async =>
      user.value == null ? null : 'test-token';

  @override
  Future<void> login({required String email, required String password}) async {
    user.value = MobileUser(
      id: 'reader',
      name: 'Reader',
      email: email,
      emailVerified: true,
      hasPassword: true,
    );
  }
}

class _ReadingStore implements ReadingProgressStore {
  final documents = <String, Map<String, dynamic>>{};

  @override
  Future<Map<String, dynamic>?> read(String key) async => documents[key];

  @override
  Future<void> write(String key, Map<String, dynamic> document) async {
    documents[key] = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(document)),
    );
  }
}

class _NoReadingNetwork implements ReadingProgressRemote {
  @override
  Future<ReadingProgressPage> pull(String token, int after) =>
      throw StateError('This test must not access the network');

  @override
  Future<ReadingProgressAcknowledgement> push(
    String token,
    List<ReadingProgressOperation> operations,
  ) => throw StateError('This test must not access the network');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final strings = <String, Map<String, String>>{};
  late FakeReadingProgress reading;
  late _Auth auth;

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
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.put(
      HomeLayoutController(
        sharedPreferences: await SharedPreferences.getInstance(),
      ),
    );
    reading = FakeReadingProgress();
    auth = _Auth();
    reading.targets.addAll({'morning:1': 3, 'evening:1': 3});
    await reading.setCount(
      ReadingProgressKind.athkar,
      'morning:1',
      3,
      day: '2026-09-12',
    );
    await reading.setCount(ReadingProgressKind.athkar, 'morning:1', 1);
    await reading.setCount(ReadingProgressKind.athkar, 'evening:1', 3);
    await reading.setCount(
      ReadingProgressKind.quran,
      '1:1',
      1,
      day: '2026-09-12',
    );
    await reading.setCount(ReadingProgressKind.quran, '1:1', 1);
    await reading.setMany(ReadingProgressKind.quran, {
      for (var verse = 1; verse <= 4; verse++) '112:$verse': 1,
    });
    reading.writes = 0;
  });
  tearDown(Get.reset);

  Widget app({
    String locale = 'fr',
    bool dark = false,
    double scale = 1,
    GlobalKey? capture,
    ReadingProgressService? progress,
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
      child: RepaintBoundary(key: capture, child: child!),
    ),
    home: ReadingProgressScreen(
      service: progress ?? reading,
      authService: auth,
    ),
  );

  Finder key(String name) => find.byKey(ValueKey(name));
  Future<void> reach(
    WidgetTester tester,
    String name, {
    bool up = false,
  }) async {
    await tester.scrollUntilVisible(
      key(name),
      up ? -250 : 250,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 40,
    );
    await tester.pumpAndSettle();
  }

  String metric(WidgetTester tester, String name) =>
      tester.widget<Text>(key('reading-progress-$name')).data!;

  testWidgets(
    'day, seven-day and unique totals reflect saved readings without marking new ones',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await reach(tester, 'reading-progress-selected-quran');
      expect(metric(tester, 'selected-athkar'), '1');
      expect(metric(tester, 'selected-quran'), '5');
      await reach(tester, 'reading-progress-selected-surahs');
      expect(metric(tester, 'selected-surahs'), '1');
      await reach(tester, 'reading-progress-week-quran');
      expect(metric(tester, 'week-athkar'), '2');
      expect(metric(tester, 'week-quran'), '6');
      await reach(tester, 'reading-progress-quran-coverage');
      expect(metric(tester, 'quran-coverage'), contains('5'));
      expect(metric(tester, 'quran-coverage'), contains('6236'));
      expect(reading.historyCalls, 1);
      expect(reading.writes, 0);
    },
  );

  testWidgets(
    'chart and history select a day, and today follows midnight until another day is selected',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await reach(tester, 'reading-week-2026-09-12');
      await tester.tap(key('reading-week-2026-09-12'));
      await tester.pump();
      await reach(tester, 'reading-progress-selected-quran', up: true);
      expect(metric(tester, 'selected-quran'), '1');
      reading.today = '2026-09-14';
      reading.refresh();
      await tester.pump();
      expect(metric(tester, 'selected-quran'), '1');
      await reach(tester, 'reading-progress-today', up: true);
      await tester.tap(key('reading-progress-today'));
      await tester.pump();
      await reach(tester, 'reading-progress-selected-quran');
      expect(metric(tester, 'selected-quran'), '0');
      await reach(tester, 'reading-history-2026-09-13');
      await tester.tap(key('reading-history-2026-09-13'));
      await tester.pump();
      await reach(tester, 'reading-progress-selected-quran', up: true);
      expect(metric(tester, 'selected-quran'), '5');
      expect(reading.writes, 0);
    },
  );

  testWidgets('statistics stay available while synchronization runs silently', (
    tester,
  ) async {
    await auth.login(email: 'reader@example.test', password: 'test-password');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    for (final status in [
      'cloud_signed_out',
      'cloud_pending',
      'cloud_syncing',
      'cloud_offline',
      'cloud_synced',
    ]) {
      reading.status = status;
      reading.refresh();
      await tester.pump();
      expect(key('reading-progress-cloud'), findsNothing);
      expect(key('reading-progress-sync'), findsNothing);
      expect(key('reading-progress-sign-in-prompt'), findsNothing);
      expect(key('reading-progress-today'), findsOneWidget);
      expect(metric(tester, 'selected-quran'), '5');
    }
    expect(reading.historyCalls, 1);
    expect(reading.syncCalls, 0);
    expect(reading.writes, 0);
  });

  testWidgets('guest invitation opens the existing account sign-in form', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(key('reading-progress-sign-in-prompt'), findsOneWidget);
    await tester.tap(key('reading-progress-sign-in'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountScreen), findsOneWidget);
    expect(key('auth_email'), findsOneWidget);
    expect(key('auth_password'), findsOneWidget);
    expect(reading.writes, 0);
  });

  testWidgets(
    'sign-in removes the invitation and adopts existing guest history offline',
    (tester) async {
      final progress = ReadingProgressService(
        auth: auth,
        store: _ReadingStore(),
        remote: _NoReadingNetwork(),
        catalog: AthkarCatalog(categories: []),
        now: () => DateTime(2026, 9, 13, 14),
        observeLifecycle: false,
        automaticSync: false,
      );
      addTearDown(progress.dispose);
      await progress.initialize();
      await progress.setCount(ReadingProgressKind.quran, '1:1', 1);
      await progress.setCount(
        ReadingProgressKind.quran,
        '1:2',
        1,
        day: '2026-09-12',
      );
      await tester.pumpWidget(app(progress: progress));
      await tester.pumpAndSettle();
      await tester.tap(key('reading-progress-sign-in'));
      await tester.pumpAndSettle();
      await tester.enterText(key('auth_email'), 'reader@example.test');
      await tester.enterText(key('auth_password'), 'test-password');
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(key('reading-progress-sign-in-prompt'), findsNothing);
      expect(progress.todayCount(ReadingProgressKind.quran, '1:1'), 1);
      expect(progress.statsForDay('2026-09-12').quranVerses, 1);
      expect(progress.pendingOperationCount, 2);
      expect(progress.status, 'cloud_pending');
      await reach(tester, 'reading-progress-selected-quran');
      expect(metric(tester, 'selected-quran'), '1');
      expect(find.text('cloud_synced'.tr), findsNothing);
    },
  );

  for (final locale in ['fr', 'ar']) {
    for (final dark in [false, true]) {
      testWidgets(
        '$locale ${dark ? 'dark' : 'light'} statistics fit 320px with double-size text',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final capture = GlobalKey();
          await tester.pumpWidget(
            app(locale: locale, dark: dark, scale: 2, capture: capture),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(key('reading-progress-sign-in-prompt'), findsOneWidget);
          final outputDirectory =
              Platform.environment['SALATIME_READING_PREVIEW_DIR'];
          if (outputDirectory != null) {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory(outputDirectory).create(recursive: true);
              await File(
                '$outputDirectory/reading-$locale-${dark ? 'dark' : 'light'}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await reach(tester, 'reading-week-2026-09-12');
          expect(tester.takeException(), isNull);
          await reach(tester, 'reading-history-2026-09-12');
          expect(tester.takeException(), isNull);
          tester.view.physicalSize = const Size(800, 320);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
