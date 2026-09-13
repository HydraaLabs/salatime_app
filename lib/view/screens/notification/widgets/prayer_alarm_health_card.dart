import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zabi/helper/adhan_notification_service_helper.dart';
import 'package:zabi/helper/prayer_alarm_health.dart';
import 'package:zabi/helper/salat_waqt_service.dart';
import 'package:zabi/service/first_launch_setup_service.dart';

class PrayerAlarmHealthCard extends StatefulWidget {
  const PrayerAlarmHealthCard({super.key});

  @override
  State<PrayerAlarmHealthCard> createState() => _PrayerAlarmHealthCardState();
}

class _PrayerAlarmHealthCardState extends State<PrayerAlarmHealthCard>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _status;
  bool _busy = false;
  bool _loading = false;
  DateTime? _testAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || _loading) {
      return;
    }
    _loading = true;
    try {
      var status = await PrayerAlarmHealth.status();
      if (status == null) {
        final android = FlutterLocalNotificationsPlugin()
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        status = {
          'exact': await android?.canScheduleExactNotifications() ?? false,
          'notifications': await Permission.notification.isGranted,
          'batteryExempt':
              await Permission.ignoreBatteryOptimizations.isGranted,
        };
      }
      final pending = await AdhanNotificationServiceImpl()
          .getPendingNotifications();
      DateTime? testAt;
      for (final request in pending.where(
        (p) => p.id == SalatWaqtService.testAlarmId,
      )) {
        try {
          final data = jsonDecode(request.payload ?? '{}') as Map;
          final at = DateTime.fromMillisecondsSinceEpoch(data['at'] as int);
          if (at.isAfter(DateTime.now())) testAt = at;
        } catch (_) {
          /* A previous binary may use a different test payload. */
        }
      }
      if (!mounted) return;
      setState(() {
        _status = status;
        _testAt = testAt;
      });
    } catch (error) {
      debugPrint('Alarm health could not be refreshed: $error');
    } finally {
      _loading = false;
    }
  }

  Future<void> _action(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('alarm_refresh_failed'.tr)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() async {
    final at = await SalatWaqtService.scheduleTestAdhan();
    if (!mounted) return;
    setState(() => _testAt = at);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) return const SizedBox.shrink();
    final delayMinutes = ((status['delayMs'] as num? ?? 0) / 60000).floor();
    final volume = status['alarmVolume'] as int?;
    final maximum = status['alarmVolumeMax'] as int?;
    final failedAudio = const [
      'audio_error',
      'audio_timeout',
      'audio_unavailable',
    ].contains(status['outcome']);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'alarm_test_title'.tr,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('alarm_volume_note'.tr),
            if (volume != null && maximum != null && maximum > 0)
              Text(
                'alarm_volume_level'.trParams({
                  'percent': '${(volume * 100 / maximum).round()}',
                }),
              ),
            if (delayMinutes >= 2) ...[
              const SizedBox(height: 8),
              Text('alarm_last_delay'.trParams({'minutes': '$delayMinutes'})),
            ],
            if (failedAudio) Text('alarm_audio_failed'.tr),
            if (status['outcome'] == 'audio_muted')
              Text('alarm_audio_muted'.tr),
            if (status['notifications'] != true)
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => _action(() async {
                        await FirstLaunchSetupService.requestNotificationPermission();
                        if (await Permission.notification.isPermanentlyDenied) {
                          await openAppSettings();
                        }
                      }),
                icon: const Icon(Icons.notifications_active_outlined),
                label: Text('enable_prayer_notifications'.tr),
              ),
            if (status['exact'] != true) ...[
              const SizedBox(height: 8),
              Text('alarm_precision_description'.tr),
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => _action(() async {
                        await FlutterLocalNotificationsPlugin()
                            .resolvePlatformSpecificImplementation<
                              AndroidFlutterLocalNotificationsPlugin
                            >()
                            ?.requestExactAlarmsPermission();
                        await SalatWaqtService.initializeSalatWaqt();
                      }),
                icon: const Icon(Icons.alarm),
                label: Text('alarm_allow_exact'.tr),
              ),
            ],
            if (status['batteryExempt'] != true)
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => _action(() async {
                        await FirstLaunchSetupService.requestBatteryOptimizationExemption();
                      }),
                icon: const Icon(Icons.battery_saver_outlined),
                label: Text('allow_background_activity'.tr),
              ),
            if ('${status['manufacturer']}'.toLowerCase() == 'samsung') ...[
              const SizedBox(height: 8),
              Text('alarm_samsung_sleep'.tr),
            ],
            const SizedBox(height: 12),
            Text(
              (_testAt == null
                      ? 'alarm_test_instructions'
                      : 'alarm_test_scheduled')
                  .tr,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _action(
                          _testAt == null
                              ? _test
                              : () async {
                                  await AdhanNotificationServiceImpl()
                                      .cancelNotification(
                                        SalatWaqtService.testAlarmId,
                                      );
                                  if (mounted) setState(() => _testAt = null);
                                },
                        ),
                  icon: Icon(_testAt == null ? Icons.alarm_add : Icons.close),
                  label: Text(
                    (_testAt == null
                            ? 'alarm_test_in_one_minute'
                            : 'alarm_test_cancel')
                        .tr,
                  ),
                ),
                if (volume != null)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _action(
                            () => PrayerAlarmHealth.channel.invokeMethod<void>(
                              'soundSettings',
                            ),
                          ),
                    icon: const Icon(Icons.volume_up_outlined),
                    label: Text('alarm_sound_settings'.tr),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
