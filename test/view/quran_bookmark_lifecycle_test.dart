import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:salatime/controller/bookmark_controller.dart';
import 'package:salatime/controller/offline_quran_controller.dart';
import 'package:salatime/controller/quran_controller.dart';
import 'package:salatime/controller/quran_settings_controller.dart';
import 'package:salatime/data/api/api_client.dart';
import 'package:salatime/data/model/response/bookmark_model.dart';
import 'package:salatime/data/model/response/sura_detile_model.dart';
import 'package:salatime/data/repository/quran_setting_repo.dart';
import 'package:salatime/data/repository/sifatname_list_repo.dart';
import 'package:salatime/view/screens/offline_quran/widgets/offline_arabic_quran.dart';
import 'package:salatime/view/screens/quran/widget/arabic_quran_widget.dart';

class _Bookmarks extends BookMarkController {
  @override
  Future<void> loadBookMarks() async {
    isLoading.value = false;
  }
}

class _Settings extends SettingsController {
  _Settings(QuranSettingsRepo repo) : super(quranSettingRepo: repo);
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClient(
      appBaseUrl: 'https://example.invalid',
      sharedPreferences: prefs,
    );
    Get.put<SettingsController>(
      _Settings(QuranSettingsRepo(sharedPreferences: prefs, apiClient: api)),
    );
    final data = SuraDetaileModel(
      data: Data(
        chapter: Chapter(id: 1, serialNumber: '1'),
        chapterInfo: List.generate(
          30,
          (index) => ChapterInfo(
            pageKey: index,
            pageNumber: index + 1,
            pageArabicAyah: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
            pageVerses: [],
          ),
        ),
      ),
    );
    Get.put(
      OfflineQuranController()
        ..suraDetailsApiData = data
        ..isSurahDetailsLoading.value = false,
    );
    Get.put(
      QuranController(
        quranRepo: QuranRepo(sharedPreferences: prefs, apiClient: api),
      )..suraDetaileApiData = data,
    );
    // Match the lazy shared controller used by the app. Eager Get.put would
    // hide the item-disposal bug because no GetBuilder would own the instance.
    Get.lazyPut<BookMarkController>(_Bookmarks.new);
  });
  tearDown(Get.reset);

  for (final offline in [true, false]) {
    testWidgets(
      '${offline ? 'offline' : 'online'} reader retains bookmarks when pages leave the viewport',
      (tester) async {
        tester.view.physicalSize = const Size(288, 448);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          GetMaterialApp(
            home: offline
                ? const OfflineArabicQuranAutoDetectScreen()
                : const ArabicQuranWidget(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final bookmarks = Get.find<BookMarkController>();
        final list = tester.widget<ScrollablePositionedList>(
          find.byType(ScrollablePositionedList),
        );
        list.itemScrollController!.jumpTo(index: 20);
        await tester.pumpAndSettle();
        list.itemScrollController!.jumpTo(index: 25);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(Get.isRegistered<BookMarkController>(), isTrue);
        expect(Get.find<BookMarkController>(), same(bookmarks));
        expect(bookmarks.isClosed, isFalse);

        bookmarks.bookMarks.add(
          BookMark(
            id: 1000000,
            serialNumber: '1',
            suraName: '',
            versesNumber: '',
            arabicName: '',
            translatedName: '',
            pageKey: '0',
            pageNumber: '1',
          ),
        );
        bookmarks.update();
        list.itemScrollController!.jumpTo(index: 0);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      },
    );
  }
}
