import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zabi/helper/daily_verse.dart';
import 'package:zabi/service/quran/quran_translation_repository.dart';

class _MissingCommentaryBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key.contains('translations/ar/')) {
      throw StateError('Commentary unavailable');
    }
    return rootBundle.load(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'daily verse uses the selected published edition and keeps its notes and credit',
    () async {
      final repository = QuranTranslationRepository();
      final day = DateTime(2024, 1, 1);
      final french = await DailyVerse.load(day, 'fr', repository: repository);
      final official = await repository.verse(1, 1, languageCode: 'fr');
      expect(french.chapter, 1);
      expect(french.number, '1');
      expect(french.translation, official.translation);
      expect(french.footnotes, official.footnotes);
      expect(french.translationSource.editionKey, 'french_hameedullah');
      expect(french.source, contains('Muhammad Hamidullah'));
      expect(french.source, contains('QuranEnc.com'));
      expect(french.source, contains(french.translationSource.version));
      expect(french.tafsirSource!.editionKey, 'arabic_moyassar');
      expect(french.tafsir, isNotEmpty);
    },
  );

  test(
    'reader languages use one canonical verse with their own unmodified text',
    () async {
      final day = DateTime(2029, 7, 17);
      final french = await DailyVerse.load(day, 'fr');
      final english = await DailyVerse.load(day, 'en');
      final arabic = await DailyVerse.load(day, 'ar');
      expect(french.chapter, 87);
      expect(french.number, '18');
      expect(english.chapter, french.chapter);
      expect(english.number, french.number);
      expect(arabic.arabic, french.arabic);
      expect(english.arabic, french.arabic);
      expect(arabic.translation, french.tafsir);
      expect(arabic.translationSource.isTafsir, isTrue);
      expect(french.translation, isNot(english.translation));
      expect(english.translationSource.editionKey, 'english_rwwad');
    },
  );

  test(
    'missing commentary keeps the chosen translation without English fallback',
    () async {
      final value = await DailyVerse.load(
        DateTime(2024),
        'fr',
        bundle: _MissingCommentaryBundle(),
      );
      expect(value.translation, isNotEmpty);
      expect(value.translationSource.languageCode, 'fr');
      expect(value.tafsir, isEmpty);
      expect(value.tafsirSource, isNull);
    },
  );

  test('day choice is independent of time and increments across midnight', () {
    expect(
      DailyVerse.dayIndex(DateTime(2026, 9, 12, 23, 59)),
      DailyVerse.dayIndex(DateTime(2026, 9, 12)),
    );
    expect(
      DailyVerse.dayIndex(DateTime(2026, 9, 13)) -
          DailyVerse.dayIndex(DateTime(2026, 9, 12)),
      1,
    );
  });
}
