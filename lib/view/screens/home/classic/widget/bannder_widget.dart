import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:salatime/helper/islamic_calendar.dart';
import 'package:salatime/controller/package_prayer_time_controller.dart';
import 'package:salatime/controller/prayer_time_adjustment.dart';
import 'package:salatime/data/model/response/todays_prayer_time_model.dart';
import 'package:salatime/helper/prayer_display_phase.dart';
import 'package:salatime/helper/translator_helper.dart';
import 'package:salatime/theme/brand_colors.dart';
import 'package:salatime/util/images.dart';

class BannerWidget extends StatefulWidget {
  const BannerWidget({super.key});
  @override
  State<BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<BannerWidget> {
  Timer? _timer;
  Data? previous;
  Data? tomorrow;
  DateTime? loadedDay;
  PrayerTimeModel? loadedModel;
  Object? loadedContext;
  DateTime? lastAttempt;
  bool loadingDays = false;
  final controller = Get.find<PrayerTimeController>();
  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Object get currentContext => (
    controller.latitude,
    controller.longitude,
    controller.isManualPrayerTime.value,
    controller.saveAddress.value,
    controller.currentAddress.value,
    controller.selectedCalculationMethod,
    controller.selectedPrayerMadhab,
    controller.prayerTimeZone,
  );

  void _tick() {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final model = controller.prayerTimeModel;
    final context = currentContext;
    final changedContext =
        !identical(loadedModel, model) || loadedContext != context;
    if (changedContext) {
      previous = null;
      tomorrow = null;
    }
    if (!loadingDays &&
        (loadedDay != day ||
            changedContext ||
            ((previous == null || tomorrow == null) &&
                (lastAttempt == null ||
                    now.difference(lastAttempt!).inMinutes >= 1)))) {
      loadedDay = day;
      loadedModel = model;
      loadedContext = context;
      lastAttempt = now;
      loadingDays = true;
      unawaited(_loadDays(day, model, context));
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadDays(
    DateTime day,
    PrayerTimeModel? model,
    Object context,
  ) async {
    bool isCurrent() =>
        mounted &&
        loadedDay == day &&
        identical(model, controller.prayerTimeModel) &&
        context == currentContext;
    try {
      final before = await controller.getPrayerTimeForDate(
        DateTime(day.year, day.month, day.day - 1),
        allowNetwork: false,
      );
      if (!isCurrent()) return;
      final after = await controller.getPrayerTimeForDate(
        DateTime(day.year, day.month, day.day + 1),
        allowNetwork: false,
      );
      if (!isCurrent()) return;
      setState(() {
        previous = before?.data;
        tomorrow = after?.data;
      });
    } catch (_) {
      // Cached neighbors can be retried after the current location is loaded.
    } finally {
      loadingDays = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final day = controller.prayerTimeModel?.data;
    final adjustments = PrayerTimeAdjustmentController.displayOffsets;
    final phase = PrayerDisplayPhase.resolve(
      now,
      day,
      previousDay: previous,
      adjustments: adjustments,
    );
    final next = PrayerDisplayPhase.next(now, [
      previous,
      day,
      tomorrow,
    ], adjustments: adjustments);
    final name = phase?.prayerKey.tr ?? next?.prayerKey.tr ?? 'next_prayer'.tr;
    final time = phase?.elapsed ?? next?.startedAt.difference(now);
    final hijri = IslamicCalendarPreferences.date(now);
    final label = phase == null
        ? 'next_prayer'.tr
        : 'time_since_prayer'.trParams({'prayer': name});
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: BrandColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  if (phase == null)
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      translateText(
                        time == null
                            ? '--:--:--'
                            : PrayerDisplayPhase.format(time),
                      ),
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color:
                            PrayerDisplayPhase.isApproaching(
                              time,
                              elapsed: phase != null,
                            )
                            ? BrandColors.countdownWarningOnPrimary
                            : Colors.white,
                        fontSize: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    MaterialLocalizations.of(context).formatFullDate(now),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    translateText(
                      '${hijri.hDay} ${'hijri_month_${hijri.hMonth}'.tr} ${hijri.hYear}',
                    ),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            if (constraints.maxWidth >= 460) ...[
              const SizedBox(width: 20),
              Image.asset(
                Images.Banner_Image,
                width: 130,
                height: 120,
                fit: BoxFit.contain,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
