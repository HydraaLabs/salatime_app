import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/controller/home_layout_controller.dart';
import 'package:zabi/helper/theme_helper.dart';
import 'package:zabi/service/first_launch_setup_service.dart';
import 'package:zabi/util/app_constants.dart';

import 'controller/internet_check_controller.dart';
import 'controller/localization_controller.dart';
import 'controller/theme_controller.dart';
import 'helper/audio_service_helper.dart';
import 'helper/get_di.dart' as di;
import 'helper/route_helper.dart';
import 'util/messages.dart';
import 'view/screens/location/background_location_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the AudioHandler
  await AudioServiceHelper.init();
  Map<String, Map<String, String>> languages = await di.init();
  final preferences = await SharedPreferences.getInstance();
  final initialRoute = FirstLaunchSetupService(preferences).shouldShow
      ? RouteHelper.firstLaunchSetup
      : await BackgroundLocationScreen.shouldShow()
      ? RouteHelper.backgroundLocation
      : RouteHelper.bottomNavbar;
  runApp(MyApp(languages: languages, initialRoute: initialRoute));
}

class MyApp extends StatelessWidget {
  final Map<String, Map<String, String>> languages;
  final String initialRoute;
  MyApp({super.key, required this.languages, required this.initialRoute});

  final InternetController internetController = Get.put(InternetController());

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThemeController>(
      builder: (themeController) {
        return GetBuilder<LocalizationController>(
          builder: (localizeController) {
            return GetX<HomeLayoutController>(
              builder: (layoutController) {
                return GetMaterialApp(
                  title: AppConstants.APP_NAME,
                  debugShowCheckedModeBanner: false,
                  navigatorKey: Get.key,
                  theme: getAppTheme(themeController.darkTheme),
                  locale: localizeController.locale,
                  initialRoute: initialRoute,
                  getPages: RouteHelper.routes,
                  defaultTransition: Transition.topLevel,
                  translations: Messages(languages: languages),
                  fallbackLocale: Locale(
                    AppConstants.languages[0].languageCode!,
                    AppConstants.languages[0].countryCode,
                  ),
                  transitionDuration: const Duration(milliseconds: 500),
                  builder: (context, child) {
                    Theme.of(context);

                    return AnnotatedRegion<SystemUiOverlayStyle>(
                      value: SystemUiOverlayStyle(
                        statusBarColor: Colors.transparent,
                        statusBarIconBrightness: themeController.darkTheme
                            ? Brightness.light
                            : Brightness.dark,
                        systemNavigationBarColor: Theme.of(
                          context,
                        ).scaffoldBackgroundColor,
                        systemNavigationBarIconBrightness:
                            themeController.darkTheme
                            ? Brightness.light
                            : Brightness.dark,
                      ),
                      child: Overlay(
                        initialEntries: [
                          OverlayEntry(
                            builder: (context) => SafeArea(
                              top: false,
                              bottom: Platform.isAndroid,
                              child: child!,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
