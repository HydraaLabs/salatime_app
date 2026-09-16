import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/helper/adhan_notification_service_helper.dart';
import 'package:salatime/helper/prayer_alarm_health.dart';
import 'package:salatime/helper/prayer_notification_preferences.dart';
import 'package:salatime/helper/salat_waqt_service.dart';
import 'package:salatime/view/base/custom_app_bar.dart';
import 'package:salatime/view/screens/notification/widgets/prayer_alarm_health_card.dart';

class UpcomingPrayerAlarmsScreen extends StatefulWidget {
  const UpcomingPrayerAlarmsScreen({super.key});

  @override
  State<UpcomingPrayerAlarmsScreen> createState() =>
      _UpcomingPrayerAlarmsScreenState();
}

class _UpcomingPrayerAlarmsScreenState
    extends State<UpcomingPrayerAlarmsScreen> {
  List<Map<String, dynamic>> _alarms = [];
  List<String> _skipped = [];
  bool _loading = true;
  bool _failed = false;
  int? _windowDays;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (mounted) setState(() => _loading = true);
    try {
      await initializeDateFormatting();
      if (refresh) await SalatWaqtService.initializeSalatWaqt();
      final pending = await AdhanNotificationServiceImpl()
          .getPendingNotifications();
      final ids = pending.map((p) => p.id).toSet();
      final alarms =
          (await SalatWaqtService.readSchedule())
              .where(
                (item) =>
                    _validAlarm(item) &&
                    ids.contains(item['id']) &&
                    (item['at'] as int) > DateTime.now().millisecondsSinceEpoch,
              )
              .toList()
            ..sort((a, b) => (a['at'] as int).compareTo(b['at'] as int));
      final prefs = await SharedPreferences.getInstance();
      final health = await PrayerAlarmHealth.status();
      if (!mounted) return;
      setState(() {
        _alarms = alarms;
        _skipped = (prefs.getStringList(SalatWaqtService.skippedKey) ?? [])
            .where((key) => _skippedPrayer(key) != null)
            .toList();
        _failed = prefs.getBool(SalatWaqtService.failedKey) ?? false;
        _windowDays = health?['armedWindowDays'] as int?;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _skip(String key, bool skip) async {
    setState(() => _loading = true);
    try {
      await SalatWaqtService.skipPrayer(key, skip);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  PrayerNotificationPrayer? _prayer(Object? id, Object? date) {
    if (id is! int || id < 1 || id > 6 || date is! String) return null;
    final parsed = DateTime.tryParse(date);
    if (parsed == null || parsed.toIso8601String().split('T').first != date) {
      return null;
    }
    return PrayerNotificationPrayer.fromLegacyId(id, date: parsed);
  }

  bool _validAlarm(Map<String, dynamic> alarm) =>
      alarm['id'] is int &&
      alarm['at'] is int &&
      _prayer(alarm['prayerId'], alarm['date']) != null &&
      alarm['key'] == '${alarm['date']}:${alarm['prayerId']}' &&
      const ['adhan', 'before', 'after'].contains(alarm['kind']);

  PrayerNotificationPrayer? _skippedPrayer(String key) {
    final parts = key.split(':');
    if (parts.length != 2) return null;
    return _prayer(int.tryParse(parts.last), parts.first);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'upcoming_prayer_alarms'.tr,
        isBackButtonExist: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(refresh: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const PrayerAlarmHealthCard(),
                  Text(
                    _windowDays == null
                        ? 'alarm_window_description'.tr
                        : 'alarm_rolling_window_description'.trParams({
                            'days': '$_windowDays',
                          }),
                  ),
                  const SizedBox(height: 12),
                  if (_failed)
                    ListTile(
                      leading: const Icon(Icons.error_outline),
                      title: Text('alarm_refresh_failed'.tr),
                    ),
                  if (_alarms.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('no_upcoming_alarms'.tr),
                    ),
                  if (_alarms.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'alarms_scheduled_until'.trParams({
                          'date': DateFormat.yMMMd(Get.locale?.languageCode)
                              .add_Hm()
                              .format(
                                DateTime.fromMillisecondsSinceEpoch(
                                  _alarms.last['at'] as int,
                                ),
                              ),
                        }),
                      ),
                    ),
                  for (final alarm in _alarms)
                    ListTile(
                      leading: Icon(
                        alarm['kind'] == 'adhan'
                            ? Icons.notifications_active_outlined
                            : Icons.alarm,
                      ),
                      title: Text(
                        '${_prayer(alarm['prayerId'], alarm['date'])!.titleKey.tr}${alarm['kind'] == 'before'
                            ? ' · ${'before_adhan'.tr}'
                            : alarm['kind'] == 'after'
                            ? ' · ${'iqama_reminder_title'.tr}'
                            : ''}',
                      ),
                      subtitle: Text(
                        DateFormat.yMMMd(
                          Get.locale?.languageCode,
                        ).add_Hm().format(
                          DateTime.fromMillisecondsSinceEpoch(
                            alarm['at'] as int,
                          ),
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: 'skip_this_prayer'.tr,
                        onPressed: () => _skip(alarm['key'] as String, true),
                        icon: const Icon(Icons.notifications_off_outlined),
                      ),
                    ),
                  if (_skipped.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'skipped_prayer_alarms'.tr,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  for (final key in _skipped)
                    ListTile(
                      title: Text(
                        '${_skippedPrayer(key)!.titleKey.tr} · ${key.split(':').first}',
                      ),
                      trailing: TextButton(
                        onPressed: () => _skip(key, false),
                        child: Text('restore_alarm'.tr),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
