import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/service/analytics/app_analytics_service.dart';
import 'package:salatime/view/base/catalog_search_field.dart';

class _Sink implements AppAnalyticsSink {
  final events = <String>[];
  @override
  Future<void> setCollectionEnabled(bool enabled) async {}
  @override
  Future<void> screenViewed(String screenName) async =>
      events.add('screen:$screenName');
  @override
  Future<void> appAction(String eventName) async => events.add(eventName);
  @override
  Future<void> resetData() async {}
}

void main() {
  late _Sink sink;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final previous = AppAnalyticsService.instance;
    sink = _Sink();
    final analytics = AppAnalyticsService(
      preferences: await SharedPreferences.getInstance(),
      sink: sink,
      enabledInBuild: true,
    );
    AppAnalyticsService.instance = analytics;
    addTearDown(() {
      AppAnalyticsService.instance = previous;
      analytics.collectionPreference.dispose();
    });
    await analytics.initialize();
  });
  tearDown(Get.reset);

  Future<List<String>> type(
    WidgetTester tester,
    List<String> queries, {
    AppAnalyticsAction? action,
  }) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final received = <String>[];
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: CatalogSearchField(
            controller: controller,
            onChanged: received.add,
            hintText: 'Search',
            fieldKey: const ValueKey('search'),
            analyticsAction: action,
          ),
        ),
      ),
    );
    for (final query in queries) {
      await tester.enterText(find.byKey(const ValueKey('search')), query);
      await tester.pump();
    }
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    return received;
  }

  testWidgets('the first typed query reports the feature once, without text', (
    tester,
  ) async {
    final received = await type(tester, [
      'al',
      'albaqarah',
      '',
      'yasin',
    ], action: AppAnalyticsAction.surahSearch);
    expect(received, ['al', 'albaqarah', '', 'yasin']);
    expect(sink.events, ['surah_search']);
  });

  testWidgets('blank input does not count as a search', (tester) async {
    await type(tester, [' ', '   '], action: AppAnalyticsAction.reciterSearch);
    expect(sink.events, isEmpty);
  });

  testWidgets('a field without an action never reports', (tester) async {
    await type(tester, ['mishary']);
    expect(sink.events, isEmpty);
  });

  test('new feature actions carry fixed names only', () {
    expect(
      [
        AppAnalyticsAction.surahSearch,
        AppAnalyticsAction.reciterSearch,
        AppAnalyticsAction.readingCloudPrompt,
        AppAnalyticsAction.prayerDayToday,
      ].map((action) => action.eventName),
      [
        'surah_search',
        'reciter_search',
        'reading_cloud_prompt',
        'prayer_day_today',
      ],
    );
  });
}
