import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:salatime/service/quran/quran_translation_repository.dart';

class QuranLoader {
  QuranLoader({AssetBundle? bundle, QuranTranslationRepository? translations})
    : _translations =
          translations ??
          (bundle == null
              ? QuranTranslationRepository.instance
              : QuranTranslationRepository(bundle: bundle));
  static final QuranLoader instance = QuranLoader();

  final QuranTranslationRepository _translations;
  List<Map<String, dynamic>> _cachedVerses = [];
  Future<void>? _loading;
  String? _key;
  int _generation = 0;

  Future<void> loadAllVerses({
    int totalSurah = 114,
    String languageCode = 'en',
  }) {
    if (totalSurah < 1 || totalSurah > 114) {
      return Future.error(RangeError.range(totalSurah, 1, 114));
    }
    final key = '$languageCode:$totalSurah';
    if (_key == key) {
      if (_cachedVerses.isNotEmpty) return Future.value();
      if (_loading != null) return _loading!;
    }
    final generation = ++_generation;
    _key = key;
    _cachedVerses = [];
    return _loading = _load(totalSurah, languageCode, generation);
  }

  Future<void> _load(
    int totalSurah,
    String languageCode,
    int generation,
  ) async {
    try {
      final verses = <Map<String, dynamic>>[];
      // One surah at a time; only official text, not large footnotes, is indexed.
      for (var i = 1; i <= totalSurah; i++) {
        final model = await _translations.loadSurah(
          i,
          languageCode: languageCode,
        );
        if (generation != _generation) return;
        final chapter = model.data!.chapter!.toJson();
        final rows = <Map<String, dynamic>>[];
        for (final page in model.data!.chapterInfo!) {
          for (final verse in page.pageVerses!) {
            rows.add({
              'id': verse.id,
              'chapter_id': verse.chapterId,
              'arabic_name': verse.arabicName ?? '',
              'translated_name': verse.translatedName ?? '',
              'verse_number': verse.versesNumber,
              'page_number': page.pageNumber,
              'page_key': page.pageKey,
              'chapter': chapter,
            });
          }
        }
        verses.addAll(await compute(_indexVerses, rows));
        if (generation != _generation) return;
      }
      _cachedVerses = List.unmodifiable(verses);
    } finally {
      if (generation == _generation) _loading = null;
    }
  }

  List<Map<String, dynamic>> get allVerses => _cachedVerses;
}

List<Map<String, dynamic>> _indexVerses(List<Map<String, dynamic>> rows) => [
  for (final row in rows)
    {
      ...row,
      '_searchText': normalizeQuranSearch(
        [
          row['arabic_name'],
          row['translated_name'],
          row['chapter']['arabic_name'] ?? '',
          row['chapter']['translated_name'] ?? '',
        ].join('\n'),
      ),
    },
];

final _diacritics = RegExp(r'[\u0610-\u061A\u064B-\u065F\u06D6-\u06ED]');

String normalizeQuranSearch(String input) {
  const replacements = {
    'أ': 'ا',
    'إ': 'ا',
    'آ': 'ا',
    'ٱ': 'ا',
    'ء': '',
    'ؤ': 'و',
    'ئ': 'ي',
    'ة': 'ه',
    'ى': 'ي',
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
  };
  var normalized = input;
  replacements.forEach(
    (from, to) => normalized = normalized.replaceAll(from, to),
  );
  return normalized.replaceAll(_diacritics, '').trim().toLowerCase();
}
