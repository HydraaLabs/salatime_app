import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:salatime/controller/quran_controller.dart';
import 'package:salatime/controller/quran_settings_controller.dart';
import 'package:salatime/data/api/api_client.dart';
import 'package:salatime/data/model/response/sura_list_model.dart' as sura;
import 'package:salatime/data/repository/quran_setting_repo.dart';
import 'package:salatime/data/repository/sifatname_list_repo.dart';
import 'package:salatime/helper/quran_chapter_catalog.dart';
import 'package:salatime/helper/route_helper.dart';
import 'package:salatime/view/screens/quran/widget/sura_list_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Settings extends SettingsController {
  _Settings(QuranSettingsRepo repo) : super(quranSettingRepo: repo);
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Quran extends QuranController {
  _Quran(QuranRepo repo) : super(quranRepo: repo);
  int loads = 0;
  String? opened;
  bool failing = false;

  @override
  Future<void> fetchSuraListData({String? translatorId}) async {
    loads++;
    suraListApiData = sura.SuraListModel(
      data: failing
          ? []
          : [
              sura.Data(
                id: 1,
                serialNumber: '1',
                arabicName: 'الفاتحة',
                translateName: 'Al-Fatihah',
                versesCount: '7',
              ),
              sura.Data(
                id: 2,
                serialNumber: '2',
                arabicName: 'البقرة',
                translateName: 'Al-Baqarah',
                versesCount: '286',
              ),
              sura.Data(
                id: 114,
                serialNumber: '114',
                arabicName: 'الناس',
                translateName: 'An-Nas',
                versesCount: '6',
              ),
            ],
    );
    update();
  }

  @override
  Future<void> fetchSuraDetaileData({
    String? suraId,
    String? translatorId,
  }) async {
    opened = suraId;
  }
}

class _Strings extends Translations {
  _Strings(this.keys);
  @override
  final Map<String, Map<String, String>> keys;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Quran quran;
  late _Strings strings;
  setUpAll(QuranChapterCatalog.load);
  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClient(
      appBaseUrl: 'https://example.invalid',
      sharedPreferences: prefs,
    );
    Get.put<SettingsController>(
      _Settings(QuranSettingsRepo(sharedPreferences: prefs, apiClient: api)),
    );
    quran = _Quran(QuranRepo(sharedPreferences: prefs, apiClient: api));
    Get.put<QuranController>(quran);
    final keys = <String, Map<String, String>>{};
    for (final language in ['fr', 'ar']) {
      keys[language] = Map<String, String>.from(
        jsonDecode(
              await rootBundle.loadString('assets/language/$language.json'),
            )
            as Map,
      );
    }
    strings = _Strings(keys);
  });
  tearDown(Get.reset);

  Future<void> show(
    WidgetTester tester, {
    String language = 'fr',
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      GetMaterialApp(
        locale: Locale(language),
        supportedLocales: const [Locale('fr'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        translations: strings,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: SuraListWidget()),
        getPages: [
          GetPage(
            name: RouteHelper.suraDetaile,
            page: () => const Scaffold(body: Text('reader')),
          ),
        ],
      ),
    );
    await tester.runAsync(QuranChapterCatalog.load);
    await tester.pumpAndSettle();
  }

  final search = find.byKey(const ValueKey('surah-catalog-search'));
  testWidgets(
    'matches localized, Arabic and transliterated aliases without refetching',
    (tester) async {
      await show(tester);
      expect(find.text('La vache'), findsOneWidget);
      for (final query in ['vâche', 'بَقَرَة', 'albaqarah', '٢']) {
        await tester.enterText(search, query);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('surah-result-2')), findsOneWidget);
        expect(find.byKey(const ValueKey('surah-result-1')), findsNothing);
      }
      await tester.enterText(search, 'introuvable');
      await tester.pumpAndSettle();
      expect(find.text('Aucune sourate trouvée.'), findsOneWidget);
      await tester.tap(find.byTooltip('Effacer la recherche'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('surah-result-1')), findsOneWidget);
      expect(quran.loads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'filtered item keeps its real chapter ID when opening the reader',
    (tester) async {
      await show(tester);
      await tester.enterText(search, 'الناس');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('surah-result-114')));
      await tester.pumpAndSettle();
      expect(quran.suraNumber, 114);
      expect(quran.opened, '114');
      expect(find.text('reader'), findsOneWidget);
      expect(quran.loads, 1);
    },
  );

  testWidgets('empty catalogue offers a working retry', (tester) async {
    quran.failing = true;
    await show(tester);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    quran.failing = false;
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.runAsync(QuranChapterCatalog.load);
    await tester.pumpAndSettle();
    expect(find.text('La vache'), findsOneWidget);
    expect(quran.loads, 2);
  });

  for (final language in ['fr', 'ar']) {
    testWidgets('$language stays usable at 320px with large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester, language: language, textScale: 2);
      expect(tester.takeException(), isNull);
      await tester.enterText(search, 'البقرة');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('surah-result-2')), findsOneWidget);
      expect(
        Directionality.of(tester.element(search)),
        language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
