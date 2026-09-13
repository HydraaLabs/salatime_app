import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/controller/localization_controller.dart';
import 'package:zabi/controller/offline_quran_controller.dart';
import 'package:zabi/controller/quran_controller.dart';
import 'package:zabi/data/api/api_client.dart';
import 'package:zabi/data/model/response/sura_detile_model.dart';
import 'package:zabi/data/repository/sifatname_list_repo.dart';
import 'package:zabi/service/quran/quran_translation_repository.dart';

SuraDetaileModel chapter(int number, String language) => SuraDetaileModel(
  data: Data(
    chapter: Chapter(id: number, serialNumber: '$number'),
    chapterInfo: [
      ChapterInfo(
        pageKey: 0,
        pageVerses: [
          PageVerses(
            id: 999,
            chapterId: number,
            versesNumber: 1,
            arabicName: 'بسم الله',
            translatedName: '$language official translation',
          ),
        ],
      ),
    ],
  ),
);

class Translations extends QuranTranslationRepository {
  final calls = <String>[];
  Future<SuraDetaileModel> Function(int, String)? onLoad;
  @override
  Future<SuraDetaileModel> loadSurah(
    int surah, {
    required String languageCode,
  }) async {
    calls.add('$languageCode:$surah');
    return onLoad == null
        ? chapter(surah, languageCode)
        : onLoad!(surah, languageCode);
  }
}

class NoTextApi extends QuranRepo {
  NoTextApi(SharedPreferences prefs)
    : super(
        sharedPreferences: prefs,
        apiClient: ApiClient(
          appBaseUrl: 'https://example.test',
          sharedPreferences: prefs,
        ),
      );
  int textCalls = 0;
  @override
  Future<Response> getSuraDetailsRepo(
    dynamic suraId,
    dynamic selectedTranslatorId,
  ) async {
    textCalls++;
    throw StateError('Text must stay local');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'selectedTranslatorId': '1'});
    prefs = await SharedPreferences.getInstance();
    Get.testMode = true;
  });
  tearDown(Get.reset);
  test(
    'online-labelled reader ignores historic translator and obtains French text locally',
    () async {
      final repository = Translations();
      final api = NoTextApi(prefs);
      final c = QuranController(
        quranRepo: api,
        translations: repository,
        languageCode: () => 'fr',
      );
      await c.fetchSuraDetaileData(suraId: '87', translatorId: '1');
      expect(repository.calls, ['fr:87']);
      expect(api.textCalls, 0);
      expect(c.suraNumber, 87);
      expect(
        c
            .suraDetaileApiData!
            .data!
            .chapterInfo!
            .single
            .pageVerses!
            .single
            .translatedName,
        'fr official translation',
      );
      expect(c.translationError.value, isNull);
    },
  );
  test(
    'offline reader tracks directly opened chapter and refreshes same chapter in new language',
    () async {
      var language = 'fr';
      final repository = Translations();
      final c = OfflineQuranController(
        translations: repository,
        languageCode: () => language,
      );
      await c.loadSurahDetails(surahNumber: 87, translatorId: '1');
      expect(c.lastSurahNumber, 87);
      language = 'ar';
      await c.refreshTranslation();
      expect(repository.calls, ['fr:87', 'ar:87']);
      expect(
        c
            .suraDetailsApiData!
            .data!
            .chapterInfo!
            .single
            .pageVerses!
            .single
            .translatedName,
        'ar official translation',
      );
    },
  );
  for (final offline in [false, true]) {
    test(
      'late previous-language result cannot replace current reader offline=$offline',
      () async {
        var language = 'en';
        final old = Completer<SuraDetaileModel>();
        final repository = Translations()
          ..onLoad = (number, lang) =>
              lang == 'en' ? old.future : Future.value(chapter(number, lang));
        if (offline) {
          final c = OfflineQuranController(
            translations: repository,
            languageCode: () => language,
          );
          final first = c.loadSurahDetails(surahNumber: 2);
          language = 'fr';
          await c.refreshTranslation();
          old.complete(chapter(2, 'en'));
          await first;
          expect(
            c
                .suraDetailsApiData!
                .data!
                .chapterInfo!
                .single
                .pageVerses!
                .single
                .translatedName,
            'fr official translation',
          );
          expect(c.isSurahDetailsLoading.value, isFalse);
        } else {
          final c = QuranController(
            quranRepo: NoTextApi(prefs),
            translations: repository,
            languageCode: () => language,
          );
          final first = c.fetchSuraDetaileData(suraId: '2');
          language = 'fr';
          await c.refreshTranslation();
          old.complete(chapter(2, 'en'));
          await first;
          expect(
            c
                .suraDetaileApiData!
                .data!
                .chapterInfo!
                .single
                .pageVerses!
                .single
                .translatedName,
            'fr official translation',
          );
          expect(c.isSuraDetaileLoading.value, isFalse);
        }
      },
    );
    test(
      'missing current edition exposes retry error and removes prior text offline=$offline',
      () async {
        final repository = Translations();
        if (offline) {
          final c = OfflineQuranController(
            translations: repository,
            languageCode: () => 'fr',
          );
          await c.loadSurahDetails(surahNumber: 1);
          repository.onLoad = (_, _) async =>
              throw const FormatException('Missing edition');
          await c.refreshTranslation(languageCode: 'tr');
          expect(c.suraDetailsApiData, isNull);
          expect(c.translationError.value, 'quran_translation_unavailable');
          expect(c.isSurahDetailsLoading.value, isFalse);
        } else {
          final c = QuranController(
            quranRepo: NoTextApi(prefs),
            translations: repository,
            languageCode: () => 'fr',
          );
          await c.fetchSuraDetaileData(suraId: '1');
          repository.onLoad = (_, _) async =>
              throw const FormatException('Missing edition');
          await c.refreshTranslation(languageCode: 'tr');
          expect(c.suraDetaileApiData, isNull);
          expect(c.translationError.value, 'quran_translation_unavailable');
          expect(c.isSuraDetaileLoading.value, isFalse);
        }
      },
    );
  }
  testWidgets(
    'app-language choice and restored cloud language reload both current chapters',
    (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          locale: const Locale('en', 'US'),
          home: const Scaffold(),
        ),
      );
      final repository = Translations();
      final api = NoTextApi(prefs);
      final online = Get.put(
        QuranController(quranRepo: api, translations: repository),
      );
      final offline = Get.put(OfflineQuranController(translations: repository));
      final locale = LocalizationController(
        sharedPreferences: prefs,
        apiClient: api.apiClient,
      );
      await online.fetchSuraDetaileData(suraId: '2');
      await offline.loadSurahDetails(surahNumber: 87);
      repository.calls.clear();
      final changing = locale.setLanguage(const Locale('fr', 'FR'), 2);
      await tester.pumpAndSettle();
      await changing;
      expect(repository.calls.toSet(), {'fr:2', 'fr:87'});
      repository.calls.clear();
      await prefs.setString('language_code', 'ar');
      await prefs.setString('country_code', 'SA');
      locale.loadCurrentLanguage();
      await tester.pumpAndSettle();
      expect(repository.calls.toSet(), {'ar:2', 'ar:87'});
      expect(online.suraNumber, 2);
      expect(offline.lastSurahNumber, 87);
      expect(api.textCalls, 0);
    },
  );
}
