import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salatime/service/quran/quran_translation_repository.dart';

class _Bundle extends CachingAssetBundle {
  final reads = <String, int>{};
  final replacements = <String, String>{};
  final missing = <String>{};
  @override
  Future<ByteData> load(String key) {
    reads.update(key, (count) => count + 1, ifAbsent: () => 1);
    if (missing.contains(key)) throw StateError('Missing published asset');
    final value = replacements[key];
    if (value != null) {
      return Future.value(
        ByteData.sublistView(Uint8List.fromList(utf8.encode(value))),
      );
    }
    return rootBundle.load(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const base = 'assets/quran/translations';

  test(
    'all ten editions map their original text and notes onto the same Arabic verses',
    () async {
      final repository = QuranTranslationRepository();
      final canonicalRaw =
          jsonDecode(await rootBundle.loadString('assets/quran/en/s001.json'))
              as Map;
      final canonical = (canonicalRaw['data']['chapter_info'] as List)
          .expand((page) => page['page_verses'] as List)
          .toList();
      for (final language in QuranTranslationRepository.supportedLanguages) {
        final raw =
            jsonDecode(await rootBundle.loadString('$base/$language/1.json'))
                as Map;
        final model = await repository.loadSurah(1, languageCode: language);
        expect(model.translationSource!.languageCode, language);
        expect(
          model.translationSource!.sourceUrl,
          startsWith('https://quranenc.com/'),
        );
        final verses = model.data!.chapterInfo!
            .expand((page) => page.pageVerses!)
            .toList();
        expect(verses.length, 7);
        for (var i = 0; i < 7; i++) {
          final verse = verses[i];
          final official = raw['verses']['${i + 1}'];
          expect(verse.arabicName, canonical[i]['arabic_name']);
          expect(verse.translatedName, official['translation']);
          expect(verse.translationFootnotes, official['footnotes']);
          expect(verse.chapterId, 1);
          expect(verse.versesNumber, i + 1);
        }
      }
    },
  );

  test(
    'French edition is Hamidullah and language aliases cannot silently become English',
    () async {
      final repository = QuranTranslationRepository();
      expect(
        (await repository.source('fr-FR')).editionKey,
        'french_hameedullah',
      );
      expect((await repository.source('sp')).languageCode, 'es');
      expect((await repository.source('AR_sa')).isTafsir, isTrue);
      await expectLater(repository.source('1'), throwsArgumentError);
      await expectLater(repository.source('xx'), throwsArgumentError);
      await expectLater(
        repository.loadSurah(115, languageCode: 'fr'),
        throwsArgumentError,
      );
      await expectLater(
        repository.verse(1, 8, languageCode: 'fr'),
        throwsArgumentError,
      );
    },
  );

  test(
    'parallel reads share a chapter load and separate languages and mutable reader models',
    () async {
      final bundle = _Bundle();
      final repository = QuranTranslationRepository(bundle: bundle);
      final loaded = await Future.wait([
        repository.loadSurah(1, languageCode: 'fr'),
        repository.loadSurah(1, languageCode: 'fr'),
        repository.loadSurah(1, languageCode: 'en'),
      ]);
      expect(bundle.reads['$base/manifest.json'], 1);
      expect(bundle.reads['$base/fr/1.json'], 1);
      expect(bundle.reads['$base/en/1.json'], 1);
      final original =
          loaded[1].data!.chapterInfo!.first.pageVerses!.first.translatedName;
      loaded[0].data!.chapterInfo!.first.pageVerses!.first.translatedName =
          'changed test display';
      expect(
        loaded[1].data!.chapterInfo!.first.pageVerses!.first.translatedName,
        original,
      );
      expect(loaded[2].translationSource!.languageCode, 'en');
    },
  );

  test(
    'missing edition fails without substitution and can be retried',
    () async {
      final bundle = _Bundle()..missing.add('$base/fr/1.json');
      final repository = QuranTranslationRepository(bundle: bundle);
      await expectLater(
        repository.loadSurah(1, languageCode: 'fr'),
        throwsStateError,
      );
      expect(bundle.reads['$base/en/1.json'], isNull);
      bundle.missing.clear();
      expect(
        (await repository.loadSurah(
          1,
          languageCode: 'fr',
        )).translationSource!.languageCode,
        'fr',
      );
    },
  );

  test(
    'mismatched editions and incomplete chapters never enter the cache',
    () async {
      final bundle = _Bundle();
      final repository = QuranTranslationRepository(bundle: bundle);
      final original = await rootBundle.loadString('$base/fr/1.json');
      final document = jsonDecode(original) as Map<String, dynamic>;
      document['languageCode'] = 'en';
      bundle.replacements['$base/fr/1.json'] = jsonEncode(document);
      await expectLater(
        repository.loadSurah(1, languageCode: 'fr'),
        throwsFormatException,
      );
      document['languageCode'] = 'fr';
      (document['verses'] as Map).remove('7');
      bundle.replacements['$base/fr/1.json'] = jsonEncode(document);
      await expectLater(
        repository.loadSurah(1, languageCode: 'fr'),
        throwsFormatException,
      );
      bundle.replacements.clear();
      expect(
        (await repository.loadSurah(1, languageCode: 'fr')).data!.chapter!.id,
        1,
      );
    },
  );
}
