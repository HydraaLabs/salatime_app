// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zabi/helper/route_helper.dart';
import 'package:zabi/theme/modern_light_theme.dart';
import 'package:zabi/util/dimensions.dart';
import 'package:zabi/util/images.dart';
import 'package:zabi/util/styles.dart';

class ModernDailyHadithCard extends StatelessWidget {
  final DateTime Function() now;

  const ModernDailyHadithCard({super.key, this.now = DateTime.now});

  static int indexForDate(DateTime date) {
    final localDay = DateTime(date.year, date.month, date.day);
    final epoch = DateTime(2024, 1, 1);
    final days = localDay.difference(epoch).inDays;
    return ((days % 3) + 3) % 3;
  }

  @override
  Widget build(BuildContext context) {
    final index = indexForDate(now()) + 1;
    final source = switch (index) {
      1 => 'Sahih al-Bukhari, 1',
      2 => 'Sahih al-Bukhari, 5027',
      _ => 'Sahih Muslim, 2593',
    };
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(Dimensions.RADIUS_EXTRA_LARGE),
      clipBehavior: Clip.antiAlias,
      elevation: isDark ? 0 : 3,
      shadowColor: Colors.black.withOpacity(0.15),
      child: InkWell(
        onTap: () => Get.toNamed(RouteHelper.hadithBookName),
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.PADDING_SIZE_DEFAULT),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 68,
                height: 68,
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColorModern.tintCream,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(Images.ModernIllustration_HadithOfDay),
              ),
              const SizedBox(width: Dimensions.PADDING_SIZE_DEFAULT),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'hadith_of_the_day_title'.tr,
                      style: robotoBold.copyWith(
                        fontSize: Dimensions.FONT_SIZE_LARGE,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'daily_hadith_$index'.tr,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: robotoRegular.copyWith(
                        fontSize: Dimensions.FONT_SIZE_DEFAULT,
                        height: 1.35,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      source,
                      style: robotoMedium.copyWith(
                        color: AppColorModern.emerald,
                        fontSize: Dimensions.FONT_SIZE_EXTRA_SMALL,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColorModern.emerald,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
