import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zabi/helper/athkar_catalog.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.source, {this.failures = 0});
  final String source;
  int failures;
  final requested = <String>[];

  @override
  Future<ByteData> load(String key) async {
    requested.add(key);
    if (failures-- > 0) throw StateError('private_asset_details');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(source)));
  }
}

Map<String, dynamic> _document() => {
  'schemaVersion': 1,
  'categories': <Map<String, dynamic>>[
    for (final id in AthkarCatalog.primaryCategoryIds)
      {
        'id': id,
        'titleArabic': 'أذكار',
        'entries': <Map<String, dynamic>>[
          {
            'id': '$id:1',
            'sourceId': 1,
            'title': '',
            'body': 'الحمد لله',
            'repetition': '',
            'narrator': '',
            'reason': '',
            'type': 'أذكار',
            'isQuran': false,
          },
        ],
      },
  ],
};

Map<String, dynamic> _firstCategory(Map<String, dynamic> document) =>
    (document['categories'] as List).first as Map<String, dynamic>;
Map<String, dynamic> _firstEntry(Map<String, dynamic> document) =>
    (_firstCategory(document)['entries'] as List).first as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'packaged offline catalogue has 218 entries in the 14 source categories',
    () async {
      final catalog = await AthkarCatalog.load();
      expect(catalog.categories.map((category) => category.id), [
        'morning',
        'evening',
        'after_prayer',
        'sleep',
        'after_sleep',
        'salah',
        'taharah',
        'home',
        'eating',
        'fasting',
        'travel',
        'duaa',
        'distress',
        'ruqyah',
      ]);
      expect(catalog.categories.map((category) => category.entries.length), [
        21,
        20,
        15,
        31,
        4,
        40,
        7,
        7,
        13,
        5,
        9,
        26,
        9,
        11,
      ]);
      expect(catalog.entries, hasLength(218));
      expect(catalog.entries.map((entry) => entry.id).toSet(), hasLength(218));
      expect(
        catalog.entries.every((entry) => entry.body.trim().isNotEmpty),
        isTrue,
      );
      for (final category in catalog.categories) {
        expect(category.nameKey, 'athkar_category_${category.id}');
        expect(
          category.entries.every((entry) => entry.categoryId == category.id),
          isTrue,
        );
        expect(catalog.category(category.id), same(category));
      }
      expect(catalog.category('duaa_widget'), isNull);
      expect(catalog.entry('missing:1'), isNull);
    },
  );

  test(
    'loading preserves every Arabic text, reference and source order verbatim',
    () async {
      final raw =
          jsonDecode(await rootBundle.loadString(AthkarCatalog.assetPath))
              as Map;
      final catalog = await AthkarCatalog.load();
      final categories = raw['categories'] as List;
      for (var index = 0; index < categories.length; index++) {
        final category = catalog.categories[index];
        expect(category.titleArabic, categories[index]['titleArabic']);
        final entries = categories[index]['entries'] as List;
        for (var entryIndex = 0; entryIndex < entries.length; entryIndex++) {
          final source = entries[entryIndex] as Map;
          final entry = category.entries[entryIndex];
          expect({
            'id': entry.id,
            'sourceId': entry.sourceId,
            'title': entry.title,
            'body': entry.body,
            'repetition': entry.repetition,
            'narrator': entry.narrator,
            'reason': entry.reason,
            'type': entry.type,
            'isQuran': entry.isQuran,
          }, source);
          expect(entry.arabic, entry.body);
          expect(entry.reference, entry.narrator);
          expect(catalog.entry(entry.id), same(entry));
        }
      }
    },
  );

  test(
    'both original entries numbered 926 retain stable distinct identities',
    () async {
      final catalog = await AthkarCatalog.load();
      final repeated = catalog
          .category('duaa')!
          .entries
          .where((entry) => entry.sourceId == 926)
          .toList();
      expect(repeated.map((entry) => entry.id), [
        'duaa:926:ff2ec322be88',
        'duaa:926:58460cdc41ae',
      ]);
      expect(repeated[0].body, isNot(repeated[1].body));
    },
  );

  test(
    'counts are derived only from explicit source repetition instructions',
    () async {
      final catalog = await AthkarCatalog.load();
      for (final entry in catalog.entries) {
        if (entry.repetition.isEmpty) {
          expect(entry.repetitions, isNull);
        } else {
          expect(entry.repetitions, isNotNull, reason: entry.id);
        }
      }
      const instructions = {
        'مرة واحدة': 1,
        'ثلاث مرات': 3,
        'سبع مرات': 7,
        'عشر مرات': 10,
        'ثلاثا وثلاثين مرة': 33,
        'مائة مرة': 100,
      };
      for (final instruction in instructions.entries) {
        final document = _document();
        _firstEntry(document)['repetition'] = instruction.key;
        expect(
          AthkarCatalog.fromJson(document).entries.first.repetitions,
          instruction.value,
        );
      }
      final document = _document();
      _firstEntry(document)['repetition'] = 'عند الحاجة';
      expect(
        AthkarCatalog.fromJson(document).entries.first.repetitions,
        isNull,
      );
    },
  );

  test(
    'loading never trims body text or silently replaces optional reference text',
    () {
      final document = _document();
      final raw = _firstEntry(document)
        ..['body'] = '  الحمدُ لله\n  '
        ..['title'] = '  دعاء  '
        ..['narrator'] = '  المرجع  '
        ..['reason'] = '\nالسبب\n';
      final entry = AthkarCatalog.fromJson(document).entries.first;
      expect(entry.body, raw['body']);
      expect(entry.title, raw['title']);
      expect(entry.narrator, raw['narrator']);
      expect(entry.reason, raw['reason']);
    },
  );

  test('public catalogue and category collections are immutable snapshots', () {
    const entry = AthkarEntry(
      id: 'morning:1',
      sourceId: 1,
      categoryId: 'morning',
      body: 'الحمد لله',
    );
    final entries = [entry];
    final category = AthkarCategory(
      id: 'morning',
      titleArabic: 'الصباح',
      entries: entries,
    );
    final categories = [category];
    final catalog = AthkarCatalog(categories: categories);
    entries.clear();
    categories.clear();
    expect(catalog.entries, [entry]);
    expect(catalog.categories, [category]);
    expect(() => category.entries.clear(), throwsUnsupportedError);
    expect(() => catalog.entries.clear(), throwsUnsupportedError);
    expect(() => catalog.categories.clear(), throwsUnsupportedError);
  });

  test(
    'malformed JSON and unsupported top-level schemas produce controlled errors',
    () {
      for (final source in ['{', '', 'not-json']) {
        expect(
          () => AthkarCatalog.decode(source),
          throwsA(isA<AthkarCatalogException>()),
        );
      }
      for (final source in [
        null,
        [],
        7,
        {},
        {'schemaVersion': 2},
        {'schemaVersion': 1.0},
      ]) {
        expect(
          () => AthkarCatalog.fromJson(source),
          throwsA(isA<AthkarCatalogException>()),
        );
      }
    },
  );

  test('blank or non-string body text is rejected without a cast failure', () {
    for (final body in <Object?>[null, '', ' \n ', 7, false, []]) {
      final document = _document();
      _firstEntry(document)['body'] = body;
      expect(
        () => AthkarCatalog.fromJson(document),
        throwsA(isA<AthkarCatalogException>()),
      );
    }
  });

  test(
    'malformed reference, repetition and Quran fields produce controlled errors',
    () {
      for (final key in [
        'title',
        'repetition',
        'narrator',
        'reason',
        'type',
        'isQuran',
      ]) {
        final document = _document();
        _firstEntry(document)[key] = 7;
        expect(
          () => AthkarCatalog.fromJson(document),
          throwsA(isA<AthkarCatalogException>()),
          reason: key,
        );
      }
    },
  );

  test('duplicate or mismatched IDs cannot overwrite another invocation', () {
    final duplicate = _document();
    (_firstCategory(duplicate)['entries'] as List).add(
      Map.of(_firstEntry(duplicate)),
    );
    expect(
      () => AthkarCatalog.fromJson(duplicate),
      throwsA(isA<AthkarCatalogException>()),
    );
    for (final identity in <Object?>[
      null,
      7,
      'evening:1',
      'morning:2',
      'morning:1:invalid',
    ]) {
      final document = _document();
      _firstEntry(document)['id'] = identity;
      expect(
        () => AthkarCatalog.fromJson(document),
        throwsA(isA<AthkarCatalogException>()),
      );
    }
    for (final sourceId in <Object?>[null, -1, '1', 1.0]) {
      final document = _document();
      _firstEntry(document)['sourceId'] = sourceId;
      expect(
        () => AthkarCatalog.fromJson(document),
        throwsA(isA<AthkarCatalogException>()),
      );
    }
  });

  test('missing, duplicate, empty and unknown categories are rejected', () {
    final missing = _document();
    (missing['categories'] as List).removeAt(0);
    final duplicate = _document();
    (duplicate['categories'] as List).add(_firstCategory(duplicate));
    final empty = _document();
    _firstCategory(empty)['entries'] = [];
    final unknown = _document();
    _firstCategory(unknown)['id'] = 'unknown';
    for (final document in [missing, duplicate, empty, unknown]) {
      expect(
        () => AthkarCatalog.fromJson(document),
        throwsA(isA<AthkarCatalogException>()),
      );
    }
  });

  test(
    'asset load failures are sanitized and a later attempt can succeed',
    () async {
      final bundle = _Bundle(jsonEncode(_document()), failures: 1);
      await expectLater(
        AthkarCatalog.load(bundle: bundle),
        throwsA(
          isA<AthkarCatalogException>()
              .having((error) => error.code, 'code', 'asset_unavailable')
              .having(
                (error) => error.toString(),
                'description',
                isNot(contains('private_asset_details')),
              ),
        ),
      );
      final catalog = await AthkarCatalog.load(bundle: bundle);
      expect(catalog.categories, hasLength(4));
      expect(bundle.requested, everyElement(AthkarCatalog.assetPath));
    },
  );
}
