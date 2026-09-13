import 'dart:async';
import 'package:salatime/service/preference_cloud_sync.dart';
import 'package:salatime/service/reading/reading_progress_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/home_layout_controller.dart';
import 'package:salatime/helper/theme_helper.dart';
import 'package:salatime/service/first_launch_setup_service.dart';
import 'package:salatime/util/app_constants.dart';

import 'controller/internet_check_controller.dart';
import 'controller/localization_controller.dart';
import 'controller/theme_controller.dart';
import 'helper/audio_service_helper.dart';
import 'helper/get_di.dart' as di;
import 'helper/route_helper.dart';
import 'util/messages.dart';
import 'view/screens/location/background_location_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SentryFlutter.init((options) {
    options.dsn = const String.fromEnvironment(
      'SALATIME_SENTRY_DSN',
      defaultValue:
          'https://27e1be168bc55d72f29af823f175dbc5@o4511371910184960.ingest.de.sentry.io/4512053084356688',
    );
    options.environment = 'production';
    options.sendDefaultPii = false;
    options.attachScreenshot = false;
    options.enablePrintBreadcrumbs = false;
    options.recordHttpBreadcrumbs = false;
    options.captureFailedRequests = false;
    options.captureNativeFailedRequests = false;
    options.enableUserInteractionBreadcrumbs = false;
    options.enableUserInteractionTracing = false;
    options.tracesSampleRate = 0.05;
  }, appRunner: _bootstrapApp);
}

Future<void> _bootstrapApp() async {
  // Initialize the AudioHandler
  await AudioServiceHelper.init();
  Map<String, Map<String, String>> languages = await di.init();
  final preferences = await SharedPreferences.getInstance();
  final initialRoute = FirstLaunchSetupService(preferences).shouldShow
      ? RouteHelper.firstLaunchSetup
      : await BackgroundLocationScreen.shouldShow()
      ? RouteHelper.backgroundLocation
      : RouteHelper.bottomNavbar;
  runApp(
    SentryWidget(
      child: MyApp(languages: languages, initialRoute: initialRoute),
    ),
  );
  // Account/cloud failures never block offline prayer times or onboarding.
  unawaited(PreferenceCloudSync.instance.initialize().catchError((_) {}));
  unawaited(ReadingProgressService.instance.initialize().catchError((_) {}));
}

class MyApp extends StatelessWidget {
  final Map<String, Map<String, String>> languages;
  final String initialRoute;
  MyApp({super.key, required this.languages, required this.initialRoute});

  final InternetController internetController = Get.find<InternetController>();

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
                  localizationsDelegates: GlobalMaterialLocalizations.delegates,
                  supportedLocales: AppConstants.languages
                      .map(
                        (language) => Locale(
                          language.languageCode!,
                          language.countryCode,
                        ),
                      )
                      .toList(),
                  initialRoute: initialRoute,
                  getPages: RouteHelper.routes,
                  navigatorObservers: [SentryNavigatorObserver()],
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
