import 'package:zabi/helper/islamic_calendar.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zabi/controller/home_layout_controller.dart';
import 'package:zabi/controller/internet_check_controller.dart';
import 'package:zabi/controller/package_prayer_time_controller.dart';
import 'package:zabi/controller/prayer_time_adjustment.dart';
import 'package:zabi/controller/quran_settings_controller.dart';
import 'package:zabi/helper/location_auto_update_service.dart';
import 'package:zabi/helper/salat_waqt_service.dart';
import 'package:zabi/view/screens/home/classic/classic_home_screen.dart';
import 'package:zabi/view/screens/home/modern/modern_home_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? _midnight;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _armMidnightRefresh();
    unawaited(IslamicCalendarPreferences.initialize());
    _loadInitialData();
  }

  void _armMidnightRefresh() {
    _midnight?.cancel();
    final now = DateTime.now();
    _midnight = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      () {
        if (!mounted) return;
        _refreshAlarms();
        _armMidnightRefresh();
      },
    );
  }

  void _refreshAlarms() {
    unawaited(
      SalatWaqtService.initializeSalatWaqt().catchError((Object error) {
        Get.log('Unable to refresh prayer alarms: $error');
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAlarms();
      _armMidnightRefresh();
    } else if (state == AppLifecycleState.paused) {
      _midnight?.cancel();
    }
  }

  @override
  void dispose() {
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _loadInitialData() {
    Get.find<InternetController>().checkConnection();
    Get.find<SettingsController>().fetchMosqueSettingsData();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prayerTimeController = Get.find<PrayerTimeController>();

      // 1. Get location first
      await prayerTimeController.getLocation();

      // 2. Load settings. getLocation() already refreshes prayer times.
      prayerTimeController.loadSwitchValue();
      prayerTimeController.loadPrayerTimeSettings();

      // 3. Init adjustment
      await Get.find<PrayerTimeAdjustmentController>().init();
      _refreshAlarms();

      // 4. Adapt adhan times when the user moves (if opted in)
      LocationAutoUpdateService.start();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final layout = Get.find<HomeLayoutController>().currentLayout.value;
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.03),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: child,
          ),
        ),
        child: layout == HomeLayoutController.classic
            ? const ClassicHomeScreen(key: ValueKey('classic'))
            : ModernHomeScreen(key: ValueKey('modern')),
      );
    });
  }
}
