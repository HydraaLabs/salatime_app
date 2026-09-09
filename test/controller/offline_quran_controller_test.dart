import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:zabi/controller/offline_quran_controller.dart';
import 'package:zabi/helper/offline_quran_loader.dart';

class _Loader extends QuranLoader {
  final ready = Completer<void>();
  int loads = 0;
  @override
  Future<void> loadAllVerses({int totalSurah = 114}) {
    loads++;
    return ready.future;
  }

  @override
  List<Map<String, dynamic>> get allVerses => [
    {'id': 1, '_searchText': 'بسم الله\nentirely merciful'},
    {'id': 2, '_searchText': 'رب العالمين\nlord of the worlds'},
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
}
