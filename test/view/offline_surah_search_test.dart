import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:salatime/controller/offline_quran_controller.dart';
import 'package:salatime/controller/quran_settings_controller.dart';
import 'package:salatime/data/api/api_client.dart';
import 'package:salatime/data/model/response/offline_sura_model.dart';
import 'package:salatime/data/repository/quran_setting_repo.dart';
import 'package:salatime/helper/quran_chapter_catalog.dart';
import 'package:salatime/view/screens/offline_quran/widgets/offline_sura_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Strings extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'fr': {
      'surah_search_hint': 'Rechercher une sourate',
      'surah_search_empty': 'Aucune sourate trouvée.',
      'catalog_search_clear': 'Effacer la recherche',
      'quran_verse_count': '@count versets',
    },
    'ar': {
      'surah_search_hint': 'ابحث عن سورة',
      'surah_search_empty': 'لم يتم العثور على سورة.',
      'catalog_search_clear': 'مسح البحث',
      'quran_verse_count': '@count آيات',
    },
  };
}

class _Settings extends SettingsController {
  _Settings(QuranSettingsRepo repo) : super(quranSettingRepo: repo);
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Offline extends OfflineQuranController {
  _Offline(this.fixture);
  final List<OfflineSurahListModel> fixture;
  var loads = 0;
  @override
  Future<void> loadSurahList() async {
    loads++;
    surahList.assignAll(fixture);
    isLoading.value = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<OfflineSurahListModel> fixture;
  late _Offline controller;

  setUpAll(() async {
    await QuranChapterCatalog.load();
    final data = jsonDecode(
      await rootBundle.loadString('assets/quran/surah_list.json'),
    );
    fixture = (data['data'] as List)
        .map((row) => OfflineSurahListModel.fromJson(row))
        .toList();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put<SettingsController>(
      _Settings(
        QuranSettingsRepo(
          sharedPreferences: prefs,
          apiClient: ApiClient(
            appBaseUrl: 'https://example.invalid',
            sharedPreferences: prefs,
          ),
        ),
      ),
    );
    controller = _Offline(fixture);
    Get.put<OfflineQuranController>(controller);
  });
  tearDown(Get.reset);

  Widget app({String language = 'fr', double scale = 1}) => GetMaterialApp(
    locale: Locale(language),
    supportedLocales: const [Locale('fr'), Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    translations: _Strings(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: const Scaffold(body: OfflineSuraList()),
  );

  final search = find.byKey(const ValueKey('offline-surah-search'));
  Finder row(int number) => find.byKey(ValueKey('offline-surah-$number'));

  testWidgets(
    'French search is local, empty state and clear keep the full list',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.runAsync(() async => QuranChapterCatalog.load());
      await tester.pumpAndSettle();
      expect(controller.loads, 1);
      expect(row(1), findsOneWidget);
      await tester.enterText(search, 'vache');
      await tester.pumpAndSettle();
      expect(row(2), findsOneWidget);
      expect(row(1), findsNothing);
      expect(find.text('La vache'), findsOneWidget);
      expect(find.text('البقرة'), findsOneWidget);
      await tester.enterText(search, 'introuvable');
      await tester.pump();
      expect(find.text('Aucune sourate trouvée.'), findsOneWidget);
      expect(row(2), findsNothing);
      await tester.tap(find.byTooltip('Effacer la recherche'));
      await tester.pump();
      expect(row(1), findsOneWidget);
      expect(controller.loads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Arabic input, RTL and large text stay usable on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(language: 'ar', scale: 2));
      await tester.runAsync(() async => QuranChapterCatalog.load());
      await tester.pumpAndSettle();
      await tester.enterText(search, 'الْبَقَرَه');
      await tester.pumpAndSettle();
      expect(row(2), findsOneWidget);
      expect(row(1), findsNothing);
      expect(Directionality.of(tester.element(search)), TextDirection.rtl);
      expect(find.text('البقرة'), findsOneWidget);
      expect(controller.loads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('selecting a filtered result retains the chapter identity', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.runAsync(() async => QuranChapterCatalog.load());
    await tester.pumpAndSettle();
    await tester.enterText(search, '112');
    await tester.pumpAndSettle();
    expect(row(112), findsOneWidget);
    expect(row(1), findsNothing);
    await tester.tap(row(112));
    expect(controller.lastSurahNumber, 112);
    // Dispose the navigator before building the reader: its separate audio and
    // reading-progress dependencies are not part of this catalogue test.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('search resets a scrolled list to the first matching chapter', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.runAsync(() async => QuranChapterCatalog.load());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(row(1), findsNothing);
    await tester.enterText(search, 'al');
    await tester.pumpAndSettle();
    expect(row(1).hitTestable(), findsOneWidget);
    expect(controller.loads, 1);
    expect(tester.takeException(), isNull);
  });
}
