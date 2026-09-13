import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zabi/data/model/response/sura_detile_model.dart';
import 'package:zabi/helper/offline_quran_loader.dart';
import 'package:zabi/service/quran/quran_translation_repository.dart';

class _Translations extends QuranTranslationRepository {
  final calls = <String>[];
  bool fail = false;
  Completer<SuraDetaileModel>? englishGate;
  @override
  Future<SuraDetaileModel> loadSurah(
    int surah, {
    required String languageCode,
  }) async {
    calls.add('$languageCode:$surah');
    if (fail) throw StateError('Missing edition');
    if (languageCode == 'en' && englishGate != null) return englishGate!.future;
    return model(surah, languageCode);
  }

  SuraDetaileModel model(int surah, String language) => SuraDetaileModel(
    data: Data(
      chapter: Chapter(
        id: surah,
        arabicName: 'الفاتحة',
        translatedName: 'Chapter',
      ),
      chapterInfo: [
        ChapterInfo(
          pageKey: 0,
          pageVerses: [
            PageVerses(
              id: surah,
              chapterId: surah,
              versesNumber: 1,
              arabicName: 'بِسْمِ اللَّهِ',
              translatedName: language == 'fr' ? 'Miséricordieux' : 'Merciful',
              translationFootnotes: 'DO_NOT_INDEX_LARGE_FOOTNOTE',
            ),
          ],
        ),
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'same-language concurrent loads share one complete index and keep translation without notes',
    () async {
      final repository = _Translations();
      final loader = QuranLoader(translations: repository);
      await Future.wait([
        loader.loadAllVerses(totalSurah: 2, languageCode: 'fr'),
        loader.loadAllVerses(totalSurah: 2, languageCode: 'fr'),
      ]);
      expect(repository.calls, ['fr:1', 'fr:2']);
      expect(loader.allVerses.length, 2);
      final first = loader.allVerses.first;
      expect(first['translated_name'], 'Miséricordieux');
      expect(first['_searchText'], contains('miséricordieux'));
      expect(first['_searchText'], contains(normalizeQuranSearch('بسم الله')));
      expect(first.toString(), isNot(contains('DO_NOT_INDEX_LARGE_FOOTNOTE')));
      expect(first['page_key'], 0);
      await loader.loadAllVerses(totalSurah: 2, languageCode: 'fr');
      expect(repository.calls.length, 2);
    },
  );
  test(
    'changing language invalidates the index and never reuses English results',
    () async {
      final repository = _Translations();
      final loader = QuranLoader(translations: repository);
      await loader.loadAllVerses(totalSurah: 1, languageCode: 'en');
      expect(loader.allVerses.single['translated_name'], 'Merciful');
      await loader.loadAllVerses(totalSurah: 1, languageCode: 'fr');
      expect(loader.allVerses.single['translated_name'], 'Miséricordieux');
      expect(repository.calls, ['en:1', 'fr:1']);
    },
  );
  test(
    'a superseded language load cannot overwrite the current index',
    () async {
      final repository = _Translations()
        ..englishGate = Completer<SuraDetaileModel>();
      final loader = QuranLoader(translations: repository);
      final english = loader.loadAllVerses(totalSurah: 2, languageCode: 'en');
      await loader.loadAllVerses(totalSurah: 1, languageCode: 'fr');
      repository.englishGate!.complete(repository.model(1, 'en'));
      await english;
      expect(loader.allVerses.single['translated_name'], 'Miséricordieux');
      expect(repository.calls, containsAll(['en:1', 'fr:1']));
      expect(repository.calls, isNot(contains('en:2')));
    },
  );
  test(
    'failed edition load exposes no partial cache and can be retried',
    () async {
      final repository = _Translations()..fail = true;
      final loader = QuranLoader(translations: repository);
      await expectLater(
        loader.loadAllVerses(totalSurah: 1, languageCode: 'fr'),
        throwsStateError,
      );
      expect(loader.allVerses, isEmpty);
      repository.fail = false;
      await loader.loadAllVerses(totalSurah: 1, languageCode: 'fr');
      expect(loader.allVerses.length, 1);
    },
  );
  test(
    'all 114 published French chapters can be indexed with canonical identities',
    () async {
      final loader = QuranLoader();
      await loader.loadAllVerses(languageCode: 'fr');
      expect(loader.allVerses.length, 6236);
      expect(loader.allVerses.first['translated_name'], isNotEmpty);
      expect(loader.allVerses.last['chapter']['id'], 114);
    },
  );
}
