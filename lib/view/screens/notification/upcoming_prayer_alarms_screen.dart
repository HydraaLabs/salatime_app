import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/helper/adhan_notification_service_helper.dart';
import 'package:zabi/helper/salat_waqt_service.dart';
import 'package:zabi/view/base/custom_app_bar.dart';

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
  bool _inexact = false;
  bool _failed = false;

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
                    ids.contains(item['id']) &&
                    (item['at'] as int) > DateTime.now().millisecondsSinceEpoch,
              )
              .toList()
            ..sort((a, b) => (a['at'] as int).compareTo(b['at'] as int));
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _alarms = alarms;
        _skipped = prefs.getStringList(SalatWaqtService.skippedKey) ?? [];
        _inexact = prefs.getBool(SalatWaqtService.inexactKey) ?? false;
        _failed = prefs.getBool(SalatWaqtService.failedKey) ?? false;
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

  Future<void> _requestExact() async {
    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();
    if (mounted) await _load(refresh: true);
  }

  String _name(int id) => ['fajr', 'dhuhr', 'asr', 'magrib', 'isha'][id - 1].tr;

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
                  Text('alarm_window_description'.tr),
                  const SizedBox(height: 12),
                  if (_failed)
                    ListTile(
                      leading: const Icon(Icons.error_outline),
                      title: Text('alarm_refresh_failed'.tr),
                    ),
                  if (_inexact && Platform.isAndroid)
                    Card(
                      child: ListTile(
                        title: Text('alarm_precision_limited'.tr),
                        subtitle: Text('alarm_precision_description'.tr),
                        trailing: IconButton(
                          onPressed: _requestExact,
                          tooltip: 'alarm_allow_exact'.tr,
                          icon: const Icon(Icons.settings),
                        ),
                      ),
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
                        '${_name(alarm['prayerId'] as int)}${alarm['kind'] == 'before'
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
                        '${_name(int.parse(key.split(':').last))} · ${key.split(':').first}',
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
