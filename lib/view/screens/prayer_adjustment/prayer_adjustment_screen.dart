import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zabi/controller/package_prayer_time_controller.dart';
import 'package:zabi/controller/prayer_time_adjustment.dart';
import 'package:zabi/helper/salat_waqt_service.dart';
import 'package:zabi/service/preference_cloud_sync.dart';
import 'package:zabi/view/base/custom_app_bar.dart';

class PrayerAdjustmentScreen extends StatefulWidget {
  const PrayerAdjustmentScreen({
    super.key,
    required this.appBackButton,
    this.reschedule,
    this.noteLocalChange,
  });
  final bool appBackButton;
  final Future<void> Function()? reschedule;
  final VoidCallback? noteLocalChange;
  @override
  State<PrayerAdjustmentScreen> createState() => _PrayerAdjustmentScreenState();
}

class _PrayerAdjustmentScreenState extends State<PrayerAdjustmentScreen> {
  late final PrayerTimeAdjustmentController adjustment;
  late Future<void> ready;
  bool saving = false;
  String? _error;
  int _saveGeneration = 0;
  @override
  void initState() {
    super.initState();
    adjustment = Get.isRegistered<PrayerTimeAdjustmentController>()
        ? Get.find<PrayerTimeAdjustmentController>()
        : Get.put(PrayerTimeAdjustmentController());
    ready = adjustment.init();
  }

  Future<void> change(String key, int delta) async {
    if (saving) return;
    final previous = adjustment.getAdjustmentMinutes(key) ?? 0;
    final next = (previous + delta).clamp(-120, 120);
    if (previous == next) return;
    final generation = ++_saveGeneration;
    (widget.noteLocalChange ?? PreferenceCloudSync.instance.noteLocalChange)();
    setState(() {
      saving = true;
      _error = null;
    });
    try {
      await adjustment.updateAdjustment(key, next);
      (widget.noteLocalChange ??
          PreferenceCloudSync.instance.noteLocalChange)();
      Get.find<PrayerTimeController>().update();
      // The buttons only wait for local storage, never Android scheduling/GPS.
      unawaited(_refreshSchedule(generation));
    } catch (_) {
      if (mounted) setState(() => _error = 'prayer_adjustment_error'.tr);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _refreshSchedule(int generation) async {
    try {
      await (widget.reschedule?.call() ?? SalatWaqtService.requestRefresh());
    } catch (_) {
      if (mounted && generation == _saveGeneration) {
        setState(() => _error = 'prayer_adjustment_error'.tr);
      }
    }
  }

  String _labelKey(String key) => switch (key) {
    'zuhr' => 'dhuhr',
    'maghrib' => 'magrib',
    'sehri' => 'sehri_end',
    'iftar' => 'iftar_start',
    _ => key,
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: CustomAppBar(
      title: 'adjust_prayer_time'.tr,
      isBackButtonExist: widget.appBackButton,
    ),
    body: FutureBuilder<void>(
      future: ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('please_try_again'.tr, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() {
                      ready = adjustment.init();
                      _error = null;
                    }),
                    child: Text('try_again'.tr),
                  ),
                ],
              ),
            ),
          );
        }
        return GetBuilder<PrayerTimeController>(
          builder: (controller) {
            final data = controller.prayerTimeModel?.data;
            if (data == null) {
              return Center(child: Text('no_data_found'.tr));
            }
            final times = {
              'fajr': data.fajrStart,
              'sunrise': data.sunrise,
              'zuhr': data.zuhrStart,
              'asr': data.asrStart,
              'maghrib': data.maghribStart,
              'isha': data.ishaStart,
              'sehri': data.sehriEnd,
              'iftar': data.iftarStart,
            };
            return GetBuilder<PrayerTimeAdjustmentController>(
              builder: (adjustment) => Column(
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final entry in times.entries)
                          if (entry.value != null)
                            Card(
                              key: ValueKey('prayer-adjustment-${entry.key}'),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_labelKey(entry.key).tr} · ${adjustment.getAdjustedTimeString(entry.key, entry.value!)}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${adjustment.getAdjustmentMinutes(entry.key) ?? 0} ${'min'.tr}',
                                          ),
                                        ),
                                        IconButton(
                                          key: ValueKey(
                                            'prayer-adjustment-${entry.key}-minus',
                                          ),
                                          tooltip: 'prayer_minus_minute'.tr,
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                          ),
                                          color: Theme.of(context).primaryColor,
                                          onPressed:
                                              saving ||
                                                  (adjustment.getAdjustmentMinutes(
                                                            entry.key,
                                                          ) ??
                                                          0) <=
                                                      -120
                                              ? null
                                              : () => change(entry.key, -1),
                                        ),
                                        IconButton(
                                          key: ValueKey(
                                            'prayer-adjustment-${entry.key}-plus',
                                          ),
                                          tooltip: 'prayer_plus_minute'.tr,
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                          ),
                                          color: Theme.of(context).primaryColor,
                                          onPressed:
                                              saving ||
                                                  (adjustment.getAdjustmentMinutes(
                                                            entry.key,
                                                          ) ??
                                                          0) >=
                                                      120
                                              ? null
                                              : () => change(entry.key, 1),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}
