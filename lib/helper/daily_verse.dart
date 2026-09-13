import 'package:flutter/services.dart';
import 'package:salatime/service/quran/quran_translation_repository.dart';

class DailyVerse {
  const DailyVerse({
    required this.chapter,
    required this.number,
    required this.arabic,
    required this.translation,
    required this.footnotes,
    required this.translationSource,
    required this.tafsir,
    this.tafsirSource,
  });

  final int chapter;
  final String number, arabic, translation, footnotes, tafsir;
  final QuranTranslationSource translationSource;
  final QuranTranslationSource? tafsirSource;
  String get source =>
      '${translationSource.publisher} · QuranEnc.com · ${translationSource.version}';

  static int dayIndex(DateTime day) => DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).difference(DateTime.utc(2024)).inDays;

  static Future<DailyVerse> load(
    DateTime day,
    String languageCode, {
    AssetBundle? bundle,
    QuranTranslationRepository? repository,
  }) async {
    final translations =
        repository ??
        (bundle == null
            ? QuranTranslationRepository.instance
            : QuranTranslationRepository(bundle: bundle));
    final index = dayIndex(day).abs();
    final chapter = index % 114 + 1;
    final model = await translations.loadSurah(
      chapter,
      languageCode: languageCode,
    );
    final verses = model.data!.chapterInfo!
        .expand((page) => page.pageVerses!)
        .toList(growable: false);
    final verse = verses[(index ~/ 114) % verses.length];
    String tafsir = '';
    QuranTranslationSource? tafsirSource;
    try {
      tafsir = (await translations.verse(
        chapter,
        verse.versesNumber!,
        languageCode: 'ar',
      )).translation;
      tafsirSource = await translations.source('ar');
    } catch (_) {
      // A missing commentary must not replace the selected published edition.
    }
    return DailyVerse(
      chapter: chapter,
      number: '${verse.versesNumber}',
      arabic: verse.arabicName!,
      translation: verse.translatedName!,
      footnotes: verse.translationFootnotes ?? '',
      translationSource: model.translationSource!,
      tafsir: tafsir,
      tafsirSource: tafsirSource,
    );
  }
}
