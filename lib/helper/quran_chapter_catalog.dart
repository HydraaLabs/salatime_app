import 'dart:convert';

import 'package:flutter/services.dart';

/// Local titles for all 114 chapters. The bundled asset records the original
/// Quran.com / MP3Quran responses and their provenance; search never needs HTTP.
class QuranChapterCatalog {
  QuranChapterCatalog._(this._chapters);

  final Map<int, _ChapterNames> _chapters;
  static Future<QuranChapterCatalog>? _loading;

  static Future<QuranChapterCatalog> load() => _loading ??= _load();

  static Future<QuranChapterCatalog> _load() async {
    try {
      final json =
          jsonDecode(
                await rootBundle.loadString('assets/quran/chapter_names.json'),
              )
              as Map<String, dynamic>;
      final chapters = <int, _ChapterNames>{};
      for (final raw in json['chapters'] as List<dynamic>) {
        final row = raw as Map<String, dynamic>;
        chapters[row['id'] as int] = _ChapterNames(
          arabic: row['arabic'] as String,
          transliteration: row['transliteration'] as String,
          complexTransliteration: row['transliteration_diacritics'] as String,
          localized: Map<String, String>.unmodifiable(
            Map<String, String>.from(row['names'] as Map),
          ),
        );
      }
      return QuranChapterCatalog._(Map.unmodifiable(chapters));
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }

  String? localizedName(int number, String languageCode) {
    final code = languageCode.toLowerCase().split(RegExp('[-_]')).first;
    return _chapters[number]?.localized[code == 'sp' ? 'es' : code];
  }

  Iterable<String> searchNames(int number, String languageCode) sync* {
    final chapter = _chapters[number];
    if (chapter == null) return;
    yield '$number';
    yield chapter.arabic;
    yield chapter.transliteration;
    yield chapter.complexTransliteration;
    final localized = localizedName(number, languageCode);
    if (localized != null) yield localized;
  }
}

class _ChapterNames {
  const _ChapterNames({
    required this.arabic,
    required this.transliteration,
    required this.complexTransliteration,
    required this.localized,
  });

  final String arabic;
  final String transliteration;
  final String complexTransliteration;
  final Map<String, String> localized;
}
