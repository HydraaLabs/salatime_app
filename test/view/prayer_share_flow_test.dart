import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/package_prayer_time_controller.dart';
import 'package:salatime/controller/prayer_time_adjustment.dart';
import 'package:salatime/data/api/api_client.dart';
import 'package:salatime/data/model/response/todays_prayer_time_model.dart';
import 'package:salatime/view/screens/prayer_share/prayer_month_screen.dart';
import 'package:salatime/view/screens/prayer_share/prayer_share_screen.dart';

Data _day(DateTime date) => Data(
  date: date.toIso8601String().split('T').first,
  fajrStart: '05:30',
  sunrise: '07:00',
  zuhrStart: '13:00',
  asrStart: '16:00',
  maghribStart: '19:30',
  ishaStart: '23:50',
);

class _PrayerController extends PrayerTimeController {
  _PrayerController(SharedPreferences prefs)
    : super(
        apiClient: ApiClient(
          appBaseUrl: 'https://example.invalid',
          sharedPreferences: prefs,
        ),
      );
  final List<DateTime> requested = [];
  bool partial = false;
  @override
  Future<PrayerTimeModel?> getPrayerTimeForDate(
    DateTime date, {
    bool allowNetwork = true,
  }) async {
    requested.add(date);
    return partial && date.day == 8
        ? null
        : PrayerTimeModel(status: true, data: _day(date));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
  final calls = <MethodCall>[];
  late _PrayerController prayers;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    prayers = Get.put(
      _PrayerController(prefs)
        ..isManualPrayerTime.value = true
        ..saveAddress.value = 'Fès'
        ..currentAddress.value = 'Old GPS city',
    );
    // Register using the base type used by the screens.
    Get.put<PrayerTimeController>(prayers);
    final offsets = Get.put(PrayerTimeAdjustmentController());
    await offsets.init();
    await offsets.updateAdjustment('isha', 20);
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async {
          calls.add(call);
          return 'dev.fluttercommunity.plus/share/dismissed';
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, null);
    Get.reset();
  });
  testWidgets('share action sends corrected times and selected manual city', (
    tester,
  ) async {
    prayers.prayerTimeModel = PrayerTimeModel(
      status: true,
      data: _day(DateTime(2026, 9, 12)),
    );
    await tester.pumpWidget(
      GetMaterialApp(
        home: PrayerShareScreen(initialDate: DateTime(2026, 9, 12)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('prayer_share_text'), 250);
    await tester.tap(find.text('prayer_share_text'));
    await tester.pumpAndSettle();
    expect(calls, hasLength(1));
    final text = (calls.single.arguments as Map)['text'] as String;
    expect(text, contains('Fès'));
    expect(text, isNot(contains('Old GPS city')));
    expect(text, contains('isha : 00:10'));
    expect(text, contains('September 13, 2026'));
    expect((calls.single.arguments as Map)['originWidth'], greaterThan(0));
  });
  testWidgets(
    'monthly calendar loads actual month and marks missing dates in export',
    (tester) async {
      prayers.partial = true;
      await tester.pumpWidget(
        GetMaterialApp(
          home: PrayerMonthScreen(initialDate: DateTime(2027, 2, 12)),
        ),
      );
      await tester.pumpAndSettle();
      expect(prayers.requested, hasLength(28));
      expect(prayers.requested.last, DateTime(2027, 2, 28));
      expect(find.text('prayer_month_missing'), findsOneWidget);
      await tester.tap(find.text('prayer_share_text'));
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      final text = (calls.single.arguments as Map)['text'] as String;
      expect(text, contains('Fès'));
      expect(text, contains('Monday, February 8, 2027\nprayer_month_missing'));
      expect(text, contains('isha : 00:10 (03/01/2027)'));
      expect(tester.takeException(), isNull);
    },
  );
}
