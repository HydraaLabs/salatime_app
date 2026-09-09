import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zabi/helper/offline_quran_loader.dart';

class _CountingBundle extends CachingAssetBundle {
  int reads = 0;
  bool fail = false;
  @override
  Future<ByteData> load(String key) {
    reads++;
    if (fail) throw StateError('temporarily unavailable asset');
    return rootBundle.load(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'concurrent index loads read each surah once and preserve translation',
    () async {
      final bundle = _CountingBundle();
      final loader = QuranLoader(bundle: bundle);
      await Future.wait([
        loader.loadAllVerses(totalSurah: 2),
        loader.loadAllVerses(totalSurah: 2),
      ]);
      expect(bundle.reads, 2);
      expect(loader.allVerses.length, 293);
      final first = loader.allVerses.first;
      expect(first['translated_name'], contains('Entirely Merciful'));
      expect(first['_searchText'], contains('entirely merciful'));
      expect(first['_searchText'], contains(normalizeQuranSearch('بسم الله')));
      expect(first['page_key'], 0);
      expect(first['chapter']['id'], 1);
      await loader.loadAllVerses(totalSurah: 2);
      expect(bundle.reads, 2);
    },
  );

  test('asset failure does not poison the index cache', () async {
    final bundle = _CountingBundle()..fail = true;
    final loader = QuranLoader(bundle: bundle);
    await expectLater(loader.loadAllVerses(totalSurah: 1), throwsStateError);
    expect(loader.allVerses, isEmpty);
    bundle.fail = false;
    await loader.loadAllVerses(totalSurah: 1);
    expect(loader.allVerses.length, 7);
  });

  test('all 114 bundled surahs can be indexed', () async {
    final loader = QuranLoader();
    await loader.loadAllVerses();
    expect(loader.allVerses.length, 6236);
    expect(loader.allVerses.last['chapter']['id'], 114);
  });
}
