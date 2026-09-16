import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/helper/ramadan_isha_settings.dart';
import 'package:salatime/view/screens/prayer_settings/ramadan_isha_setting.dart';

class _Translations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en': {
      'ramadan_isha_title': 'Isha during Ramadan',
      'ramadan_isha_method': 'Calculation method',
      'ramadan_isha_interval': '@minutes min after Maghrib',
      'ramadan_isha_description': 'Applies only during Ramadan nights.',
    },
  };
}

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  Future<void> showSetting(WidgetTester tester, int interval) async {
    SharedPreferences.setMockInitialValues({
      RamadanIshaSettings.storageKey: interval,
    });
    await tester.pumpWidget(
      GetMaterialApp(
        locale: const Locale('en'),
        translations: _Translations(),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: RamadanIshaSetting(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('saved interval can be changed and restored to the method', (
    tester,
  ) async {
    await showSetting(tester, 90);
    expect(find.text('90 min after Maghrib'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ramadan-isha-90')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('120 min after Maghrib').last);
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(RamadanIshaSettings.read(prefs), 120);
    expect(find.byKey(const ValueKey('ramadan-isha-120')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ramadan-isha-120')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calculation method').last);
    await tester.pumpAndSettle();
    expect(RamadanIshaSettings.read(prefs), 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('fits a narrow screen with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await showSetting(tester, 120);
    expect(find.text('120 min after Maghrib'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
