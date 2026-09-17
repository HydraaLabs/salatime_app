import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/home_layout_controller.dart';
import 'package:salatime/controller/internet_check_controller.dart';
import 'package:salatime/controller/localization_controller.dart';
import 'package:salatime/controller/theme_controller.dart';
import 'package:salatime/data/api/api_client.dart';
import 'package:salatime/helper/route_helper.dart';
import 'package:salatime/main.dart';
import 'package:salatime/util/app_constants.dart';

class _InternetController extends InternetController {
  // Keep the app shell test independent of device connectivity services.
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'iOS status bar follows the app theme after returning from a dark AppBar',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        AppConstants.THEME_MODE_KEY: ThemeController.light,
      });
      final preferences = await SharedPreferences.getInstance();
      final theme = Get.put(ThemeController(sharedPreferences: preferences));
      Get.put(HomeLayoutController(sharedPreferences: preferences));
      Get.put<InternetController>(_InternetController());
      Get.put(
        LocalizationController(
          sharedPreferences: preferences,
          apiClient: ApiClient(
            appBaseUrl: AppConstants.BASE_URL,
            sharedPreferences: preferences,
          ),
        ),
      );
      final originalRoutes = RouteHelper.routes;
      RouteHelper.routes = [
        GetPage(
          name: '/status-bar-home',
          page: () => const Scaffold(body: Text('Home without AppBar')),
        ),
        GetPage(
          name: '/status-bar-details',
          page: () => Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.black,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              title: const Text('Dark AppBar'),
            ),
          ),
        ),
      ];
      addTearDown(() {
        RouteHelper.routes = originalRoutes;
        Get.reset();
      });
      await tester.pumpWidget(
        MyApp(languages: const {}, initialRoute: '/status-bar-home'),
      );
      await tester.pumpAndSettle();

      Get.toNamed<void>('/status-bar-details');
      await tester.pumpAndSettle();
      expect(SystemChrome.latestStyle!.statusBarBrightness, Brightness.dark);
      Get.back<void>();
      await tester.pumpAndSettle();

      expect(find.text('Home without AppBar'), findsOneWidget);
      expect(SystemChrome.latestStyle!.statusBarBrightness, Brightness.light);
      expect(
        SystemChrome.latestStyle!.statusBarIconBrightness,
        Brightness.dark,
      );

      await theme.setMode(ThemeController.dark);
      await tester.pumpAndSettle();
      expect(SystemChrome.latestStyle!.statusBarBrightness, Brightness.dark);
      expect(
        SystemChrome.latestStyle!.statusBarIconBrightness,
        Brightness.light,
      );
      await theme.setMode(ThemeController.light);
      await tester.pumpAndSettle();
      expect(SystemChrome.latestStyle!.statusBarBrightness, Brightness.light);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );
}
