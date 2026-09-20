import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/home_layout_controller.dart';
import 'package:salatime/controller/internet_check_controller.dart';
import 'package:salatime/controller/nearby_mosque_controller.dart';
import 'package:salatime/theme/modern_light_theme.dart';
import 'package:salatime/helper/athkar_catalog.dart';
import 'package:salatime/view/base/bottom_navbar.dart';
import 'package:salatime/view/base/custom_app_bar.dart';
import 'package:salatime/view/screens/category/category_screen.dart';
import 'package:salatime/view/screens/compass/compass_screen.dart';
import 'package:salatime/view/screens/dhikr/dhikr_screen.dart';
import 'package:salatime/view/screens/nearby_mosque/nearby_mosque_screen.dart';

class _Internet extends InternetController {
  @override
  // Navigation tests explicitly control connectivity without a platform stream.
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> checkConnection() async {}
}

class _Mosques extends NearbyMosqueController {
  _Mosques() {
    isLocationDenied.value = true;
  }
  @override
  // The callback test uses the existing denied-location view, without GPS.
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> getLocation() async {}
}

class _Strings extends Translations {
  @override
  Map<String, Map<String, String>> get keys => const {
    'fr': {
      'nav_today': 'Aujourd’hui',
      'nav_qibla': 'Qibla',
      'nav_dhikr': 'Zikr',
      'nav_mosques': 'Mosquées',
      'nav_more': 'Plus',
      'athkar_title': 'Invocations',
    },
  };
}

class _Page extends StatefulWidget {
  const _Page({
    super.key,
    required this.index,
    required this.active,
    required this.returnHome,
  });
  final int index;
  final bool active;
  final VoidCallback returnHome;
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  int count = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: CustomAppBar(
      title: 'Page ${widget.index}',
      isBackButtonExist: widget.index != 0,
      onBackPressed: widget.returnHome,
    ),
    body: Column(
      children: [
        Text('page-${widget.index}:$count'),
        TextButton(
          key: ValueKey('increment-${widget.index}'),
          onPressed: () => setState(() => count++),
          child: const Text('Increment'),
        ),
        TextButton(
          key: ValueKey('detail-${widget.index}'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Detail')),
                body: const Text('Nested detail'),
              ),
            ),
          ),
          child: const Text('Open detail'),
        ),
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HomeLayoutController layout;
  late _Internet internet;
  late AthkarCatalog athkar;
  setUpAll(() async {
    // File-backed assets finish outside the widget test's simulated clock.
    // The callback test still renders the real bundled Athkar collection.
    athkar = await AthkarCatalog.load();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    layout = Get.put(HomeLayoutController(sharedPreferences: prefs));
    internet = _Internet();
    Get.put<InternetController>(internet);
  });
  tearDown(Get.reset);

  Widget shell() => BottomNavbarScreen(
    pageBuilder: (context, index, active, returnHome) => _Page(
      key: ValueKey('page-$index'),
      index: index,
      active: active,
      returnHome: returnHome,
    ),
  );
  Widget app({Widget? home, bool launcher = false}) => GetMaterialApp(
    theme: modernLight,
    locale: const Locale('fr'),
    translations: _Strings(),
    home:
        home ??
        (launcher
            ? Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).push(MaterialPageRoute<void>(builder: (_) => shell())),
                    child: const Text('Launch shell'),
                  ),
                ),
              )
            : shell()),
  );
  Finder item(int index) => find.byKey(ValueKey('bottom-nav-item-$index'));
  Finder back() => find.byIcon(
    layout.currentLayout.value == HomeLayoutController.modern
        ? Icons.arrow_back_ios_new
        : Icons.arrow_back_ios,
  );
  Future<void> select(WidgetTester tester, int index) async {
    await tester.tap(item(index));
    await tester.pumpAndSettle();
  }

  void expectHome(WidgetTester tester) {
    expect(find.text('page-0:0'), findsOneWidget);
    for (var index = 1; index <= 4; index++) {
      expect(
        tester.widget<Semantics>(item(index)).properties.selected,
        isFalse,
      );
    }
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform: tablet rail navigates and preserves state across window resizing',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(find.byType(NavigationRail), findsOneWidget);
        await tester.tap(find.text('Zikr'));
        await tester.pumpAndSettle();
        expect(find.text('page-2:0'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('increment-2')));
        await tester.pumpAndSettle();
        await tester.binding.setSurfaceSize(const Size(390, 844));
        await tester.pumpAndSettle();
        expect(find.byType(NavigationRail), findsNothing);
        expect(find.text('page-2:1'), findsOneWidget);
        await tester.binding.setSurfaceSize(const Size(800, 350));
        await tester.pumpAndSettle();
        expect(find.byType(NavigationRail), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.binding.setSurfaceSize(const Size(800, 1280));
        await tester.pumpAndSettle();
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.text('page-2:1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
  for (final style in [
    HomeLayoutController.modern,
    HomeLayoutController.classic,
  ]) {
    testWidgets(
      '$style: home is initial and absent from the four-item menu; every arrow returns home',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await layout.setUserLayout(style);
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expectHome(tester);
        expect(find.text('Aujourd’hui'), findsNothing);
        expect(find.byKey(const ValueKey('bottom-nav-item-0')), findsNothing);
        expect(find.byType(_Page, skipOffstage: false), findsOneWidget);
        for (var index = 1; index <= 4; index++) {
          await select(tester, index);
          expect(find.text('page-$index:0'), findsOneWidget);
          expect(
            tester.widget<Semantics>(item(index)).properties.selected,
            isTrue,
          );
          expect(back(), findsOneWidget);
          await tester.tap(back());
          await tester.pumpAndSettle();
          expectHome(tester);
        }
        expect(find.byType(_Page, skipOffstage: false), findsNWidgets(5));
      },
    );
  }

  testWidgets(
    'returning home preserves visited page state and deactivates Qibla until reopened',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await select(tester, 1);
      expect(
        tester.widget<_Page>(find.byKey(const ValueKey('page-1'))).active,
        isTrue,
      );
      await tester.tap(back());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<_Page>(
              find.byKey(const ValueKey('page-1'), skipOffstage: false),
            )
            .active,
        isFalse,
      );
      await select(tester, 2);
      await tester.tap(find.byKey(const ValueKey('increment-2')));
      await tester.pump();
      await tester.tap(back());
      await tester.pumpAndSettle();
      await select(tester, 2);
      expect(find.text('page-2:1'), findsOneWidget);
      await select(tester, 1);
      expect(
        tester.widget<_Page>(find.byKey(const ValueKey('page-1'))).active,
        isTrue,
      );
    },
  );

  testWidgets(
    'Android back returns from each tab to home before permitting the shell route to close',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app(launcher: true));
      await tester.tap(find.text('Launch shell'));
      await tester.pumpAndSettle();
      for (var index = 1; index <= 4; index++) {
        await select(tester, index);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expectHome(tester);
        expect(find.byType(BottomNavbarScreen), findsOneWidget);
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Launch shell'), findsOneWidget);
      expect(find.byType(BottomNavbarScreen), findsNothing);
    },
  );

  testWidgets(
    'a nested route pops to its tab; the following back returns home',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await select(tester, 4);
      await tester.tap(find.byKey(const ValueKey('detail-4')));
      await tester.pumpAndSettle();
      expect(find.text('Nested detail'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('page-4:0'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expectHome(tester);
    },
  );

  testWidgets(
    'returning home and reopening offline Zikr do not depend on internet',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await select(tester, 3);
      internet.hasInternet.value = false;
      await tester.tap(back());
      await tester.pumpAndSettle();
      expectHome(tester);
      await select(tester, 2);
      expect(find.text('page-2:0'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
    },
  );

  for (final destination in ['qibla', 'mosques', 'zikr', 'more']) {
    testWidgets(
      '$destination: actual page appbar invokes its home callback without popping the route',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var calls = 0;
        void returnHome() {
          calls++;
        }

        // A navigation test must not wait for real location permissions on
        // macOS hosts (Linux previously skipped this platform path).
        const permissions = MethodChannel(
          'flutter.baseflow.com/permissions/methods',
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          permissions,
          (_) async => 2, // restricted
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            permissions,
            null,
          ),
        );
        Get.put<NearbyMosqueController>(_Mosques());
        final screen = switch (destination) {
          'qibla' => CompassScreen(
            appBackButton: true,
            isActive: true,
            onBackPressed: returnHome,
          ),
          'mosques' => NearbyMosque(
            appBackButton: true,
            onBackPressed: returnHome,
          ),
          'zikr' => DhikrScreen(
            appBackButton: true,
            onBackPressed: returnHome,
            loadCatalog: () async => athkar,
          ),
          _ => CategoryScreen(appBackButton: true, onBackPressed: returnHome),
        };
        await tester.pumpWidget(app(home: screen));
        await tester.pumpAndSettle();
        expect(back(), findsOneWidget);
        await tester.tap(back());
        await tester.pump();
        expect(calls, 1);
        expect(find.byType(CustomAppBar), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
