import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:salatime/controller/offline_quran_controller.dart';
import 'package:salatime/controller/package_prayer_time_controller.dart';
import 'package:salatime/controller/prayer_time_adjustment.dart';
import 'package:salatime/data/model/response/todays_prayer_time_model.dart';
import 'package:salatime/helper/additional_reminder_plan.dart';
import 'package:salatime/helper/prayer_alarm_plan.dart';
import 'package:salatime/helper/route_helper.dart';
import 'package:salatime/view/screens/reminders/additional_reminders_screen.dart';

class DailyPrayerMarkers {
  const DailyPrayerMarkers(this.date, this.entries);
  final DateTime date;
  final List<({String label, tz.TZDateTime time})> entries;

  factory DailyPrayerMarkers.calculate({
    required Data day,
    Data? previous,
    required tz.Location zone,
    required List<AdditionalReminderSetting> settings,
    Map<String, int> adjustments = const {},
  }) {
    final date = DateTime.parse(day.date!);
    final prayers = PrayerOccurrence.fromDay(day, zone, adjustments);
    final previousPrayers = previous == null
        ? <PrayerOccurrence>[]
        : PrayerOccurrence.fromDay(previous, zone, adjustments);
    final reminders = buildAdditionalReminderPlan(
      days: [?previous, day],
      zone: zone,
      now: tz.TZDateTime(zone, date.year, date.month, date.day - 1),
      settings: [
        for (final item in settings.where(
          (item) => const {
            AdditionalReminderType.duha,
            AdditionalReminderType.morning,
            AdditionalReminderType.evening,
            AdditionalReminderType.friday,
          }.contains(item.type),
        ))
          item.copyWith(enabled: true),
      ],
      adjustments: adjustments,
    ).where((item) => item.date == day.date);
    final entries = <({String label, tz.TZDateTime time})>[
      for (final reminder in reminders)
        (label: reminder.setting.titleKey, time: reminder.time),
    ];
    if (prayers.length == 5 && previousPrayers.length == 5) {
      final night = calculatePrayerNight(
        previousMaghrib: previousPrayers[3].time,
        fajr: prayers[0].time,
      );
      if (night != null) {
        entries.add((label: 'daily_markers_middle_night', time: night.middle));
        entries.add((label: 'extra_reminder_lastThird', time: night.lastThird));
      }
    }
    entries.sort((a, b) => a.time.compareTo(b.time));
    return DailyPrayerMarkers(date, entries);
  }
}

class DailyPrayerMarkersScreen extends StatefulWidget {
  const DailyPrayerMarkersScreen({super.key, this.loadMarkers});
  final Future<DailyPrayerMarkers?> Function()? loadMarkers;

  @override
  State<DailyPrayerMarkersScreen> createState() =>
      _DailyPrayerMarkersScreenState();
}

class _DailyPrayerMarkersScreenState extends State<DailyPrayerMarkersScreen> {
  late Future<DailyPrayerMarkers?> _markers;

  @override
  void initState() {
    super.initState();
    _markers = _load();
  }

  Future<DailyPrayerMarkers?> _load() async {
    await initializeDateFormatting();
    if (widget.loadMarkers != null) return widget.loadMarkers!();
    if (!Get.isRegistered<PrayerTimeController>()) return null;
    final controller = Get.find<PrayerTimeController>();
    final zoneName = controller.prayerTimeZone;
    if (zoneName == null) return null;
    final zone = tz.getLocation(zoneName);
    final now = tz.TZDateTime.now(zone);
    final day = (await controller.getPrayerTimeForDate(
      now,
      allowNetwork: false,
    ))?.data;
    if (day == null) return null;
    final previous = (await controller.getPrayerTimeForDate(
      tz.TZDateTime(zone, now.year, now.month, now.day - 1),
      allowNetwork: false,
    ))?.data;
    final adjustments = <String, int>{};
    if (Get.isRegistered<PrayerTimeAdjustmentController>()) {
      final controller = Get.find<PrayerTimeAdjustmentController>();
      await controller.init();
      for (final key in ['fajr', 'sunrise', 'zuhr', 'asr', 'maghrib', 'isha']) {
        adjustments[key] = controller.getAdjustmentMinutes(key) ?? 0;
      }
    }
    return DailyPrayerMarkers.calculate(
      day: day,
      previous: previous,
      zone: zone,
      settings: await AdditionalReminderPreferences.load(),
      adjustments: adjustments,
    );
  }

  String _clock(BuildContext context, DateTime date, DateTime time) {
    final use24 = Get.isRegistered<PrayerTimeController>()
        ? Get.find<PrayerTimeController>().is24HourFormat.value
        : MediaQuery.alwaysUse24HourFormatOf(context);
    final clock = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: time.hour, minute: time.minute),
      alwaysUse24HourFormat: use24,
    );
    final sameDate =
        time.year == date.year &&
        time.month == date.month &&
        time.day == date.day;
    return sameDate
        ? clock
        : '${DateFormat.MMMd(Get.locale?.languageCode).format(time)} · $clock';
  }

  void _openKahf() {
    final controller = Get.isRegistered<OfflineQuranController>()
        ? Get.find<OfflineQuranController>()
        : Get.put(OfflineQuranController());
    controller.changeSurah(18);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        'daily_markers_title'.tr,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    body: SafeArea(
      top: false,
      child: FutureBuilder<DailyPrayerMarkers?>(
        future: _markers,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final markers = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'daily_markers_intro'.tr,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              if (markers == null || markers.entries.isEmpty)
                Text('daily_markers_empty'.tr)
              else ...[
                Text(
                  DateFormat.yMMMMEEEEd(
                    Get.locale?.languageCode,
                  ).format(markers.date),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      for (final entry in markers.entries)
                        ListTile(
                          leading: Icon(
                            Icons.schedule,
                            color: Theme.of(context).primaryColor,
                          ),
                          title: Text(entry.label.tr),
                          subtitle: Text(
                            _clock(context, markers.date, entry.time),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.auto_stories_outlined),
                      title: Text('daily_markers_kahf'.tr),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openKahf,
                    ),
                    ListTile(
                      leading: const Icon(Icons.favorite_outline),
                      title: Text('daily_adhkar_title'.tr),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Get.toNamed(RouteHelper.dhikr),
                    ),
                    ListTile(
                      leading: const Icon(Icons.notifications_outlined),
                      title: Text('extra_reminders_title'.tr),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Get.to(() => const AdditionalRemindersScreen());
                        if (mounted) setState(() => _markers = _load());
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
