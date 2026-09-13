// These test doubles deliberately skip device/network initialization.
// ignore_for_file: must_call_super

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/internet_check_controller.dart';
import 'package:salatime/controller/package_prayer_time_controller.dart';
import 'package:salatime/controller/prayer_time_adjustment.dart';
import 'package:salatime/controller/quran_settings_controller.dart';
import 'package:salatime/data/api/api_client.dart';
import 'package:salatime/data/model/response/mosque_settings_model.dart' as mosque;
import 'package:salatime/data/model/response/todays_prayer_time_model.dart';
import 'package:salatime/data/repository/quran_setting_repo.dart';
import 'package:salatime/view/screens/home/classic/classic_home_screen.dart';
import 'package:salatime/view/screens/home/classic/widget/today_prayer_list_item.dart';

class _Internet extends InternetController {
  @override
  void onInit() {}
}

class _Settings extends SettingsController {
  _Settings(QuranSettingsRepo repo) : super(quranSettingRepo: repo);
  @override
  void onInit() {}
}

class _PrayerTimes extends PrayerTimeController {
  _PrayerTimes({required super.apiClient});
  @override
  void onInit() {}
  @override
  Future<PrayerTimeModel?> getPrayerTimeForDate(
    DateTime date, {
    bool allowNetwork = true,
  }) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  testWidgets('classic manual timetable applies and observes prayer offsets', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final client = ApiClient(
      appBaseUrl: 'https://example.invalid',
      sharedPreferences: prefs,
    );
    Get.put<InternetController>(_Internet());
    final settings = Get.put<SettingsController>(
      _Settings(QuranSettingsRepo(sharedPreferences: prefs, apiClient: client)),
    );
    settings.isMosqueSettingsLoading.value = false;
    settings.mosqueSettingsApiData = mosque.MosqueSettingsModel(
      data: mosque.Data(mosqueName: 'SalaTime', mosqueAddress: 'Fès'),
    );
    final prayers = Get.put<PrayerTimeController>(
      _PrayerTimes(apiClient: client),
    );
    prayers.isManualPrayerTime.value = true;
    prayers.isprayerTimeLoading.value = false;
    prayers.is24HourFormat.value = true;
    prayers.prayerTimeModel = PrayerTimeModel(
      data: Data(
        date: '2026-09-12',
        fajrStart: '05:36',
        sunrise: '07:01',
        zuhrStart: '13:16',
        asrStart: '16:48',
        maghribStart: '19:31',
        ishaStart: '20:55',
      ),
    );
    final adjustments = Get.put(PrayerTimeAdjustmentController());
    await tester.runAsync(adjustments.init);
    await tester.pumpWidget(const GetMaterialApp(home: ClassicHomeScreen()));
    await tester.pump();

    TodaysprayerWidget card(String label) => tester
        .widgetList<TodaysprayerWidget>(find.byType(TodaysprayerWidget))
        .singleWhere((widget) => widget.prayerName == label);
    expect(card('asr').adhan, '16:48');
    expect(card('sunrise').sunriseStart, '07:01');

    await tester.runAsync(() async {
      await adjustments.updateAdjustment('asr', 5);
      await adjustments.updateAdjustment('sunrise', -2);
    });
    await tester.pump();
    expect(card('asr').adhan, '16:53');
    expect(card('asr').isAdjusted, isTrue);
    expect(card('sunrise').sunriseStart, '06:59');
    expect(prayers.prayerTimeModel!.data!.asrStart, '16:48');
    expect(prayers.prayerTimeModel!.data!.sunrise, '07:01');

    await tester.runAsync(adjustments.resetPrayerTime);
    await tester.pump();
    expect(card('asr').adhan, '16:48');
    expect(card('asr').isAdjusted, isFalse);
    expect(card('sunrise').sunriseStart, '07:01');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
