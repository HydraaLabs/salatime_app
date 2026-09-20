import 'package:salatime/view/screens/daily/daily_verse_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:salatime/controller/package_prayer_time_controller.dart';
import 'package:salatime/shimmer/all_shimmer_loder.dart';
import 'package:salatime/theme/modern_light_theme.dart';
import 'package:salatime/util/dimensions.dart';
import 'package:salatime/view/screens/home/modern/widget/modern_daily_hadith_card.dart';
import 'package:salatime/view/screens/home/modern/widget/modern_prayer_dashboard.dart';
import 'package:salatime/view/screens/home/modern/widget/modern_quran_reading_card.dart';

class ModernHomeScreen extends StatelessWidget {
  const ModernHomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return GetBuilder<PrayerTimeController>(
      builder: (prayerTimeController) {
        final isInitialLoading =
            prayerTimeController.isprayerTimeLoading.value &&
            prayerTimeController.prayerTimeModel == null;

        return Scaffold(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).scaffoldBackgroundColor
              : AppColorModern.scaffoldBackground,
          body: isInitialLoading
              ? const SafeArea(child: DashbordShimmerScreen())
              : SafeArea(
                  bottom: false,
                  child: _buildBody(context, prayerTimeController),
                ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    PrayerTimeController prayerTimeController,
  ) {
    final dailyCards = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.PADDING_SIZE_DEFAULT,
      ),
      child: Column(
        children: const [
          SizedBox(height: Dimensions.PADDING_SIZE_DEFAULT),
          ModernDailyHadithCard(),
          SizedBox(height: Dimensions.PADDING_SIZE_DEFAULT),
          DailyVerseCard(),
          SizedBox(height: Dimensions.PADDING_SIZE_DEFAULT),
          ModernQuranReadingCard(),
          SizedBox(height: Dimensions.PADDING_SIZE_LARGE * 2),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(0.0, 1400.0);
        final wide = width >= 840;
        final prayerWidth = wide ? (width * 6 / 11).floorToDouble() : width;
        // Keep the same widget ancestry across rotation so the dashboard's
        // selected day and daily-card state survive the layout change.
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Center(
            child: SizedBox(
              width: width,
              child: Wrap(
                children: [
                  SizedBox(
                    width: prayerWidth,
                    child: ModernPrayerDashboard(
                      prayerTimeController: prayerTimeController,
                    ),
                  ),
                  SizedBox(
                    width: wide ? width - prayerWidth : width,
                    child: dailyCards,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
