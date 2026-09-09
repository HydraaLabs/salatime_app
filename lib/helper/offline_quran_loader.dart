import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class QuranLoader {
  QuranLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;
  static final QuranLoader instance = QuranLoader();

  final AssetBundle _bundle;
  List<Map<String, dynamic>> _cachedVerses = [];
  Future<void>? _loading;

  Future<void> loadAllVerses({int totalSurah = 114}) {
    if (_cachedVerses.isNotEmpty) return Future.value();
    return _loading ??= _load(totalSurah);
  }

  Future<void> _load(int totalSurah) async {
    try {
      final verses = <Map<String, dynamic>>[];
      // Process one surah at a time so low-memory devices never hold all the
      // raw JSON at once. Parsing and normalization run off the UI isolate.
      for (var i = 1; i <= totalSurah; i++) {
        final raw = await _bundle.loadString(
          'assets/quran/en/s00$i.json',
          cache: false,
        );
        verses.addAll(await compute(_indexSurah, raw));
      }
      _cachedVerses = verses;
    } finally {
      // A failed load can be retried; never cache an incomplete Quran.
      _loading = null;
    }
  }

  List<Map<String, dynamic>> get allVerses => _cachedVerses;
}

List<Map<String, dynamic>> _indexSurah(String raw) {
  final decoded = json.decode(raw);
  final surah =
      (decoded is List ? decoded.first : decoded) as Map<String, dynamic>;
  final data = surah['data'] as Map<String, dynamic>;
  final chapter = data['chapter'] as Map<String, dynamic>;
  final verses = <Map<String, dynamic>>[];
  for (final page in data['chapter_info'] as List) {
    for (final verse in page['page_verses'] as List) {
      final arabic = (verse['arabic_name'] ?? '').toString();
      final translation = (verse['translated_name'] ?? '').toString();
      verses.add({
        'id': verse['id'],
        'chapter_id': verse['chapter_id'],
        'arabic_name': arabic,
        'translated_name': translation,
        'verse_number': verse['verses_number'] ?? verse['verse_number'],
        'page_number': page['page_number'],
        'page_key': page['page_key'],
        'chapter': chapter,
        '_searchText': normalizeQuranSearch(
          [
            arabic,
            verse['text_without_taskeel'] ?? '',
            translation,
            chapter['arabic_name'] ?? '',
            chapter['translated_name'] ?? '',
          ].join('\n'),
        ),
      });
    }
  }
  return verses;
}

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
