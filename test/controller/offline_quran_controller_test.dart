import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:salatime/controller/offline_quran_controller.dart';
import 'package:salatime/helper/offline_quran_loader.dart';

class _Loader extends QuranLoader {
  final ready = Completer<void>();
  int loads = 0;
  @override
  Future<void> loadAllVerses({
    int totalSurah = 114,
    String languageCode = 'en',
  }) {
    loads++;
    return ready.future;
  }

  @override
  List<Map<String, dynamic>> get allVerses => [
    {'id': 1, '_searchText': 'بسم الله\nentirely merciful'},
    {'id': 2, '_searchText': 'رب العالمين\nlord of the worlds'},
  ];
}

class _LanguageLoader extends QuranLoader {
  final calls = <String>[];
  final gates = <String, Completer<void>>{};
  String current = '';
  bool fail = false;
  @override
  Future<void> loadAllVerses({
    int totalSurah = 114,
    String languageCode = 'en',
  }) async {
    calls.add(languageCode);
    await gates[languageCode]?.future;
    if (fail) throw StateError('Edition unavailable');
    current = languageCode;
  }

  @override
  List<Map<String, dynamic>> get allVerses => [
    {'id': current, '_searchText': 'الله $current'},
  ];
}

void main() {
  tearDown(Get.reset);

  testWidgets(
    'loads on demand, searches pending query, cancels cleared queries',
    (tester) async {
      final loader = _Loader();
      final controller = Get.put(OfflineQuranController(loader: loader));
      expect(loader.loads, 0);
      final loading = controller.initLoader();
      controller.initLoader();
      expect(loader.loads, 1);
      controller.search('MERCIFUL');
      loader.ready.complete();
      await loading;
      expect(controller.isQuranSearching.value, isFalse);
      expect(controller.results.single['id'], 1);
      controller.search('بِسْمِ اللَّهِ');
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.results.single['id'], 1);
      controller.search('lord');
      controller.clearSearch();
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.results, isEmpty);
      controller.search('lord');
      await Get.delete<OfflineQuranController>();
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.results, isEmpty);
    },
  );
  testWidgets(
    'language refresh rebuilds an already opened search but does not start one eagerly',
    (tester) async {
      var language = 'fr';
      final loader = _LanguageLoader();
      final controller = Get.put(
        OfflineQuranController(loader: loader, languageCode: () => language),
      );
      await controller.refreshTranslation();
      expect(loader.calls, isEmpty);
      await controller.initLoader();
      controller.search('الله');
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.results.single['id'], 'fr');
      language = 'ar';
      await controller.refreshTranslation();
      expect(loader.calls, ['fr', 'ar']);
      expect(controller.results.single['id'], 'ar');
    },
  );
  testWidgets(
    'late search completion cannot reintroduce the previous language',
    (tester) async {
      var language = 'en';
      final loader = _LanguageLoader()..gates['en'] = Completer<void>();
      final controller = Get.put(
        OfflineQuranController(loader: loader, languageCode: () => language),
      );
      final english = controller.initLoader();
      language = 'fr';
      await controller.refreshTranslation();
      expect(controller.verses.single['id'], 'fr');
      loader.gates['en']!.complete();
      await english;
      expect(controller.verses.single['id'], 'fr');
      expect(controller.isQuranSearching.value, isFalse);
    },
  );
  testWidgets(
    'failed translated search clears old results and retries without English fallback',
    (tester) async {
      var language = 'en';
      final loader = _LanguageLoader();
      final controller = Get.put(
        OfflineQuranController(loader: loader, languageCode: () => language),
      );
      await controller.initLoader();
      language = 'fr';
      loader.fail = true;
      await controller.refreshTranslation();
      expect(controller.verses, isEmpty);
      expect(controller.searchError.value, 'quran_translation_unavailable');
      loader.fail = false;
      await controller.initLoader();
      expect(controller.verses.single['id'], 'fr');
      expect(controller.searchError.value, isNull);
    },
  );
}
