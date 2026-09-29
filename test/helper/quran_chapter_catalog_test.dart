import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salatime/helper/catalog_search.dart';
import 'package:salatime/helper/quran_chapter_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranChapterCatalog catalog;

  setUpAll(() async => catalog = await QuranChapterCatalog.load());

  test('all 114 chapters have authentic titles for the ten app languages', () {
    for (final language in [
      'en',
      'ar',
      'fr',
      'tr',
      'ur',
      'id',
      'ms',
      'es',
      'bn',
      'fa',
    ]) {
      for (var number = 1; number <= 114; number++) {
        expect(
          catalog.localizedName(number, language),
          isNotEmpty,
          reason: '$language chapter $number',
        );
      }
    }
    expect(catalog.localizedName(2, 'fr'), 'La vache');
    expect(catalog.localizedName(2, 'ar'), 'البقرة');
    expect(catalog.localizedName(2, 'fa'), 'بقره');
    expect(catalog.localizedName(114, 'ar'), 'الناس');
    expect(catalog.localizedName(114, 'fa'), isNot('Mankind'));
  });

  test(
    'local title, Arabic variants, number and transliteration find chapter 2',
    () {
      for (final query in [
        'VACHE',
        'البقره',
        'الْبَقَرَة',
        'albaqarah',
        'Al-Baqarah',
        '٢',
      ]) {
        expect(
          matchesCatalogSearch(query, catalog.searchNames(2, 'fr')),
          isTrue,
          reason: query,
        );
        expect(
          matchesCatalogSearch(query, catalog.searchNames(1, 'fr')),
          isFalse,
          reason: query,
        );
      }
      expect(
        matchesCatalogSearch('cow', catalog.searchNames(2, 'fr')),
        isFalse,
      );
      expect(matchesCatalogSearch('cow', catalog.searchNames(2, 'en')), isTrue);
    },
  );

  test('locale variants normalize without adding an unrelated language', () {
    expect(catalog.localizedName(2, 'fr_FR'), 'La vache');
    expect(catalog.localizedName(2, 'fr-FR'), 'La vache');
    expect(catalog.localizedName(2, 'sp'), 'La Vaca');
    expect(catalog.localizedName(2, 'unknown'), isNull);
    expect(catalog.searchNames(0, 'fr'), isEmpty);
    expect(catalog.searchNames(115, 'fr'), isEmpty);
  });

  test(
    'loading reuses the same local catalogue without fetching a network list',
    () async {
      expect(await QuranChapterCatalog.load(), same(catalog));
    },
  );

  test(
    'bundled data preserves publisher provenance and full identity coverage',
    () async {
      final data = jsonDecode(
        await rootBundle.loadString('assets/quran/chapter_names.json'),
      );
      final rows = data['chapters'] as List<dynamic>;
      expect(rows.map((row) => row['id']).toSet(), {
        for (var n = 1; n <= 114; n++) n,
      });
      expect(
        (data['sources'] as List).every(
          (source) =>
              Uri.parse(source['url'] as String).scheme == 'https' &&
              RegExp(r'^[a-f0-9]{64}$').hasMatch(source['sha256'] as String),
        ),
        isTrue,
      );
    },
  );
}
