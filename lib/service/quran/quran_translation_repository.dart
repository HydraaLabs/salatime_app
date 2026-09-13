import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:zabi/data/model/response/quran_translation_source.dart';
import 'package:zabi/data/model/response/sura_detile_model.dart';
import 'package:zabi/service/reading/reading_progress_models.dart';

export 'package:zabi/data/model/response/quran_translation_source.dart';

class QuranTranslationVerse {
  const QuranTranslationVerse({
    required this.translation,
    required this.footnotes,
  });
  final String translation;
  final String footnotes;
}

/// Published translations are read by chapter, without a runtime network call.
/// A missing or corrupt edition is an error, never an English substitution.
class QuranTranslationRepository {
  QuranTranslationRepository({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  static final instance = QuranTranslationRepository();
  static const supportedLanguages = {
    'ar',
    'bn',
    'en',
    'es',
    'fa',
    'fr',
    'id',
    'ms',
    'tr',
    'ur',
  };
  static const _base = 'assets/quran/translations';
  final AssetBundle _bundle;
  Future<Map<String, QuranTranslationSource>>? _manifest;
  final _chapters = <String, Map<int, QuranTranslationVerse>>{};
  final _loading = <String, Future<Map<int, QuranTranslationVerse>>>{};

  static String normalizeLanguage(String code) {
    var language = code.toLowerCase().split(RegExp('[-_]')).first;
    if (language == 'sp') language = 'es';
    if (!supportedLanguages.contains(language)) {
      throw ArgumentError.value(
        code,
        'languageCode',
        'Unsupported Quran language',
      );
    }
    return language;
  }

  Future<QuranTranslationSource> source(String languageCode) async {
    final language = normalizeLanguage(languageCode);
    final sources = await (_manifest ??= _loadManifest().catchError((
      Object error,
    ) {
      _manifest = null;
      throw error;
    }));
    final result = sources[language];
    if (result == null) {
      throw FormatException('Missing published edition: $language');
    }
    return result;
  }

  Future<Map<String, QuranTranslationSource>> _loadManifest() async {
    final raw = await _bundle.loadString('$_base/manifest.json', cache: false);
    final document = jsonDecode(raw);
    if (document is! Map ||
        document['schemaVersion'] != 1 ||
        document['sources'] is! Map) {
      throw const FormatException('Invalid published translation manifest');
    }
    final result = <String, QuranTranslationSource>{};
    for (final entry in (document['sources'] as Map).entries) {
      final source = QuranTranslationSource.fromJson(
        Map<String, dynamic>.from(entry.value),
      );
      if (entry.key != source.languageCode ||
          !supportedLanguages.contains(entry.key)) {
        throw const FormatException('Translation manifest language mismatch');
      }
      final uri = Uri.tryParse(source.sourceUrl);
      if (uri == null || uri.scheme != 'https' || uri.host != 'quranenc.com') {
        throw const FormatException('Invalid published source URL');
      }
      result[entry.key as String] = source;
    }
    if (result.length != supportedLanguages.length) {
      throw const FormatException('Incomplete published translation manifest');
    }
    return Map.unmodifiable(result);
  }

  Future<QuranTranslationVerse> verse(
    int surah,
    int verse, {
    required String languageCode,
  }) async {
    if (!QuranReadingKeys.valid(surah, verse)) {
      throw ArgumentError('Invalid canonical Quran verse');
    }
    return (await _chapter(surah, await source(languageCode)))[verse]!;
  }

  Future<Map<int, QuranTranslationVerse>> _chapter(
    int surah,
    QuranTranslationSource source,
  ) {
    final key = '${source.languageCode}:$surah';
    final cached = _chapters.remove(key);
    if (cached != null) {
      _chapters[key] = cached;
      return Future.value(cached);
    }
    return _loading[key] ??= _readChapter(surah, source)
        .then((chapter) {
          _chapters[key] = chapter;
          while (_chapters.length > 8) {
            _chapters.remove(_chapters.keys.first);
          }
          return chapter;
        })
        .whenComplete(() {
          _loading.remove(key);
        });
  }

  Future<Map<int, QuranTranslationVerse>> _readChapter(
    int surah,
    QuranTranslationSource source,
  ) async {
    final raw = await _bundle.loadString(
      '$_base/${source.languageCode}/$surah.json',
      cache: false,
    );
    return compute(_parseChapter, {
      'raw': raw,
      'source': source.toJson(),
      'surah': surah,
      'verseCount': QuranReadingKeys.verseCounts[surah - 1],
    });
  }

  Future<SuraDetaileModel> loadSurah(
    int surah, {
    required String languageCode,
  }) async {
    if (!QuranReadingKeys.valid(surah, 1)) {
      throw ArgumentError.value(surah, 'surah', 'Invalid Quran surah');
    }
    final edition = await source(languageCode);
    final translations = await _chapter(surah, edition);
    final raw = await _bundle.loadString(
      'assets/quran/en/s00$surah.json',
      cache: false,
    );
    final model = await compute(_parseCanonicalSurah, raw);
    final chapter = model.data?.chapter;
    if (chapter?.id != surah) {
      throw const FormatException('Canonical surah identity mismatch');
    }
    final seen = <int>{};
    for (final page in model.data?.chapterInfo ?? <ChapterInfo>[]) {
      for (final verse in page.pageVerses ?? <PageVerses>[]) {
        final number = verse.versesNumber;
        if (verse.chapterId != surah || number == null || !seen.add(number)) {
          throw const FormatException('Invalid canonical verse identity');
        }
        final official = translations[number];
        if (official == null) {
          throw const FormatException('Missing published verse');
        }
        verse.translatedName = official.translation;
        verse.translationFootnotes = official.footnotes;
      }
    }
    if (seen.length != translations.length) {
      throw const FormatException('Incomplete canonical surah');
    }
    model.translationSource = edition;
    return model;
  }
}

SuraDetaileModel _parseCanonicalSurah(String raw) {
  final decoded = jsonDecode(raw);
  return SuraDetaileModel.fromJson(
    Map<String, dynamic>.from(decoded is List ? decoded.first : decoded),
  );
}

Map<int, QuranTranslationVerse> _parseChapter(Map<String, dynamic> input) {
  final document = jsonDecode(input['raw'] as String);
  final source = input['source'] as Map;
  if (document is! Map ||
      document['schemaVersion'] != 1 ||
      document['languageCode'] != source['languageCode'] ||
      document['editionKey'] != source['editionKey'] ||
      document['version'] != source['version'] ||
      document['surah'] != input['surah'] ||
      document['verses'] is! Map) {
    throw const FormatException('Published chapter does not match its edition');
  }
  final rows = document['verses'] as Map;
  final count = input['verseCount'] as int;
  if (rows.length != count) {
    throw const FormatException('Incomplete published chapter');
  }
  final result = <int, QuranTranslationVerse>{};
  for (var number = 1; number <= count; number++) {
    final row = rows['$number'];
    if (row is! Map ||
        row['translation'] is! String ||
        (row['translation'] as String).trim().isEmpty ||
        row['footnotes'] is! String) {
      throw const FormatException('Invalid published verse text or notes');
    }
    result[number] = QuranTranslationVerse(
      translation: row['translation'],
      footnotes: row['footnotes'],
    );
  }
  return Map.unmodifiable(result);
}
