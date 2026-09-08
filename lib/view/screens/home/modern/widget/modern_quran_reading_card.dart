// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:zabi/controller/quran_milestone_controller.dart';
import 'package:zabi/helper/route_helper.dart';
import 'package:zabi/theme/modern_light_theme.dart';
import 'package:zabi/util/dimensions.dart';
import 'package:zabi/util/images.dart';
import 'package:zabi/util/styles.dart';

class ModernQuranReadingCard extends StatelessWidget {
  const ModernQuranReadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<QuranMilestoneController>(
      builder: (controller) {
        final read = controller.pagesReadToday.value;
        final goal = controller.dailyGoal.value;
        final ratio = controller.progressRatio.clamp(0.0, 1.0);
        final percent = (ratio * 100).round();
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Material(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(Dimensions.RADIUS_EXTRA_LARGE),
          clipBehavior: Clip.antiAlias,
          elevation: isDark ? 0 : 3,
          shadowColor: Colors.black.withOpacity(0.15),
          child: InkWell(
            onTap: () => Get.toNamed(RouteHelper.suraList),
            child: Padding(
              padding: const EdgeInsets.all(Dimensions.PADDING_SIZE_DEFAULT),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColorModern.primaryGreenDark,
                      shape: BoxShape.circle,
                    ),
                    child: SvgPicture.asset(
                      Images.ModernIcon_NavCenterRehal,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: Dimensions.PADDING_SIZE_DEFAULT),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'quran_reading_progress_title'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: robotoBold.copyWith(
                            fontSize: Dimensions.FONT_SIZE_LARGE,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'quran_progress_summary'.trParams({
                            'read': '$read',
                            'goal': '$goal',
                          }),
                          style: robotoRegular.copyWith(
                            color: Theme.of(context).hintColor,
                            fontSize: Dimensions.FONT_SIZE_SMALL,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 8,
                                  backgroundColor: isDark
                                      ? Colors.white.withOpacity(0.16)
                                      : AppColorModern.progressTrack,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        AppColorModern.emerald,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$percent %',
                              style: robotoBold.copyWith(
                                color: AppColorModern.emerald,
                                fontSize: Dimensions.FONT_SIZE_SMALL,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: FilledButton(
                            onPressed: () => Get.toNamed(RouteHelper.suraList),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColorModern.emerald,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                            ),
                            child: Text(
                              'continue_reading'.tr,
                              style: robotoMedium.copyWith(
                                color: Colors.white,
                                fontSize: Dimensions.FONT_SIZE_SMALL,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
