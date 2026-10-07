import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/home_layout_controller.dart';
import 'package:salatime/controller/internet_check_controller.dart';
import 'package:salatime/service/analytics/analytics_navigator_observer.dart';
import 'package:salatime/view/base/bottom_navbar.dart';

class _Internet extends InternetController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> checkConnection() async {}
}

void main() {
  late _Internet internet;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.put(
      HomeLayoutController(
        sharedPreferences: await SharedPreferences.getInstance(),
      ),
    );
    internet = _Internet();
    Get.put<InternetController>(internet);
  });
  tearDown(Get.reset);

  Widget app(List<String> seen) => GetMaterialApp(
    navigatorObservers: [AnalyticsNavigatorObserver(onScreenViewed: seen.add)],
    home: BottomNavbarScreen(
      onScreenViewed: seen.add,
      pageBuilder: (context, index, active, returnHome) => Column(
        children: [
          Text('page-$index'),
          TextButton(onPressed: returnHome, child: const Text('Home')),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: '/account'),
                builder: (_) => const Scaffold(body: Text('Account')),
              ),
            ),
            child: const Text('Detail'),
          ),
        ],
      ),
    ),
  );
  Future<void> select(WidgetTester tester, int index) async {
    await tester.tap(find.byKey(ValueKey('bottom-nav-item-$index')));
    await tester.pumpAndSettle();
  }

  testWidgets('only visible tabs count, with initial home and home return', (
    tester,
  ) async {
    final seen = <String>[];
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(seen));
    await tester.pumpAndSettle();
    expect(seen, ['home']);
    await select(tester, 1);
    await select(tester, 1);
    await select(tester, 2);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await select(tester, 2);
    expect(seen, ['home', 'qibla', 'dhikr', 'home', 'dhikr']);
  });

  testWidgets('a blocked offline tab and a popup do not become page views', (
    tester,
  ) async {
    final seen = <String>[];
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(seen));
    await tester.pumpAndSettle();
    internet.hasInternet.value = false;
    await select(tester, 3);
    expect(find.byType(Dialog), findsOneWidget);
    expect(seen, ['home']);
    Get.back<void>();
    await tester.pumpAndSettle();
    expect(seen, ['home']);
  });

  testWidgets('popping a detail restores the active tab rather than home', (
    tester,
  ) async {
    final seen = <String>[];
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(seen));
    await tester.pumpAndSettle();
    await select(tester, 4);
    await tester.tap(find.text('Detail'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(seen, ['home', 'more', 'account', 'more']);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(seen.last, 'home');
  });
}
