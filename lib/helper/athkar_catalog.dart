import 'dart:convert';

import 'package:flutter/services.dart';

/// Texts and source references are kept verbatim; only app labels are localized.
class AthkarEntry {
  const AthkarEntry({
    required this.id,
    required this.sourceId,
    required this.categoryId,
    required this.body,
    this.title = '',
    this.repetition = '',
    this.narrator = '',
    this.reason = '',
    this.type = '',
    this.isQuran = false,
  });

  final String id;
  final int sourceId;
  final String categoryId;
  final String title;
  final String body;
  final String repetition;
  final String narrator;
  final String reason;
  final String type;
  final bool isQuran;

  String get arabic => body;
  String get reference => narrator;

  /// No count is invented when the source supplies no repetition instruction.
  int? get repetitions => const <String, int>{
    'مرة واحدة': 1,
    'ثلاث مرات': 3,
    'سبع مرات': 7,
    'عشر مرات': 10,
    'ثلاثا وثلاثين مرة': 33,
    'مائة مرة': 100,
  }[repetition];
}

class AthkarCategory {
  AthkarCategory({
    required this.id,
    required this.titleArabic,
    required List<AthkarEntry> entries,
  }) : entries = List<AthkarEntry>.unmodifiable(entries);

  final String id;
  final String titleArabic;
  final List<AthkarEntry> entries;

  String get nameKey => 'athkar_category_$id';
}

/// A controlled failure that never exposes religious content or asset internals.
class AthkarCatalogException implements Exception {
  const AthkarCatalogException(this.code);

  final String code;

  @override
  String toString() => 'AthkarCatalogException($code)';
}

class AthkarCatalog {
  AthkarCatalog({required List<AthkarCategory> categories})
    : categories = List<AthkarCategory>.unmodifiable(categories),
      entries = List<AthkarEntry>.unmodifiable(
        categories.expand((category) => category.entries),
      );

  static const assetPath = 'assets/athkar/catalog.json';
  static const primaryCategoryIds = [
    'morning',
    'evening',
    'after_prayer',
    'sleep',
  ];
  static const categoryIds = {
    ...primaryCategoryIds,
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
  };

  final List<AthkarCategory> categories;
  final List<AthkarEntry> entries;

  AthkarCategory? category(String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  AthkarEntry? entry(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  static Future<AthkarCatalog> load({AssetBundle? bundle}) async {
    final String source;
    try {
      source = await (bundle ?? rootBundle).loadString(assetPath, cache: false);
    } catch (_) {
      throw const AthkarCatalogException('asset_unavailable');
    }
    return decode(source);
  }

  static AthkarCatalog decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } catch (_) {
      throw const AthkarCatalogException('invalid_json');
    }
    return AthkarCatalog.fromJson(decoded);
  }

  factory AthkarCatalog.fromJson(Object? source) {
    if (source is! Map ||
        source['schemaVersion'] is! int ||
        source['schemaVersion'] != 1) {
      throw const AthkarCatalogException('unsupported_schema');
    }
    final rows = source['categories'];
    if (rows is! List || rows.isEmpty) {
      throw const AthkarCatalogException('invalid_categories');
    }
    final categories = <AthkarCategory>[];
    final seenCategories = <String>{};
    final seenEntries = <String>{};
    for (final row in rows) {
      if (row is! Map || row['id'] is! String) {
        throw const AthkarCatalogException('invalid_category');
      }
      final id = row['id'] as String;
      if (!categoryIds.contains(id) || !seenCategories.add(id)) {
        throw const AthkarCatalogException('invalid_category_id');
      }
      final title = row['titleArabic'];
      final rawEntries = row['entries'];
      if (title is! String ||
          title.trim().isEmpty ||
          rawEntries is! List ||
          rawEntries.isEmpty) {
        throw const AthkarCatalogException('invalid_category');
      }
      final entries = <AthkarEntry>[];
      for (final raw in rawEntries) {
        if (raw is! Map) {
          throw const AthkarCatalogException('invalid_entry');
        }
        final entryId = raw['id'];
        final sourceId = raw['sourceId'];
        if (entryId is! String ||
            sourceId is! int ||
            sourceId < 0 ||
            !RegExp('^$id:$sourceId(?::[a-f0-9]{12})?\$').hasMatch(entryId) ||
            !seenEntries.add(entryId)) {
          throw const AthkarCatalogException('invalid_entry_id');
        }
        for (final field in [
          'title',
          'body',
          'repetition',
          'narrator',
          'reason',
          'type',
        ]) {
          if (raw[field] is! String) {
            throw const AthkarCatalogException('invalid_entry_text');
          }
        }
        if ((raw['body'] as String).trim().isEmpty || raw['isQuran'] is! bool) {
          throw const AthkarCatalogException('invalid_entry');
        }
        entries.add(
          AthkarEntry(
            id: entryId,
            sourceId: sourceId,
            categoryId: id,
            title: raw['title'] as String,
            body: raw['body'] as String,
            repetition: raw['repetition'] as String,
            narrator: raw['narrator'] as String,
            reason: raw['reason'] as String,
            type: raw['type'] as String,
            isQuran: raw['isQuran'] as bool,
          ),
        );
      }
      categories.add(
        AthkarCategory(id: id, titleArabic: title, entries: entries),
      );
    }
    if (!seenCategories.containsAll(primaryCategoryIds)) {
      throw const AthkarCatalogException('missing_primary_categories');
    }
    return AthkarCatalog(categories: categories);
  }
}
