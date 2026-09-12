import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DailyVerse {
  const DailyVerse(
    this.chapter,
    this.number,
    this.arabic,
    this.translation,
    this.tafsir,
    this.source,
  );
  final int chapter;
  final String number, arabic, translation, tafsir, source;
  static int dayIndex(DateTime day) => DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).difference(DateTime.utc(2024)).inDays;
  static Future<DailyVerse> load(
    DateTime day,
    String translator, {
    AssetBundle? bundle,
  }) async {
    final index = dayIndex(day).abs();
    final chapter = index % 114 + 1;
    final folder = switch (translator) {
      '2' => 'bn',
      '3' => 'sp',
      '4' => 'ar',
      _ => 'en',
    };
    final assets = bundle ?? rootBundle;
    final translated = await assets.loadString(
      'assets/quran/$folder/s00$chapter.json',
    );
    final arabic = folder == 'ar'
        ? translated
        : await assets.loadString('assets/quran/ar/s00$chapter.json');
    return compute(_parseDailyVerse, {
      'chapter': chapter,
      'index': index ~/ 114,
      'translated': translated,
      'canonical': folder == 'en'
          ? translated
          : await assets.loadString('assets/quran/en/s00$chapter.json'),
      'arabic': arabic,
      'source': switch (folder) {
        'bn' => 'জহুরুল হক',
        'sp' => 'Bornez',
        'ar' => 'تفسير الجلالين',
        _ => 'Ahmed Ali',
      },
    });
  }
}

DailyVerse _parseDailyVerse(Map<String, dynamic> input) {
  List<Map<String, dynamic>> verses(String raw) {
    final json = jsonDecode(raw);
    final data = (json is List ? json.first : json)['data'];
    return [
      for (final page in data['chapter_info'])
        for (final verse in page['page_verses'])
          Map<String, dynamic>.from(verse),
    ];
  }

  final canonical = verses(input['canonical']);
  final verse = canonical[(input['index'] as int) % canonical.length];
  final translated = verses(input['translated'])
      .where((row) => '${row['verses_number']}' == '${verse['verses_number']}')
      .firstOrNull;
  final tafsir = verses(input['arabic'])
      .where((row) => '${row['verses_number']}' == '${verse['verses_number']}')
      .firstOrNull;
  return DailyVerse(
    input['chapter'],
    '${verse['verses_number']}',
    '${tafsir?['arabic_name'] ?? verse['arabic_name']}',
    translated?['translated_name']?.toString() ?? '',
    tafsir?['translated_name']?.toString() ?? '',
    input['source'],
  );
}
