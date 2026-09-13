import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:salatime/helper/prayer_notification_preferences.dart';
import 'package:salatime/service/first_launch_setup_service.dart';
import 'package:salatime/view/screens/reminders/additional_reminders_screen.dart';
import 'package:salatime/view/screens/settings/widgets/automatic_silence_settings.dart';
import 'notification_phase_screen.dart';
import 'upcoming_prayer_alarms_screen.dart';

/// The same notification categories are available during setup and afterwards.
class NotificationSettingsMenu extends StatelessWidget {
  const NotificationSettingsMenu({super.key, this.soundPreview});

  final Future<void> Function(String path)? soundPreview;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final phase in PrayerNotificationPhase.values) ...[
            ListTile(
              key: ValueKey('notification_category_${phase.name}'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: Icon(switch (phase) {
                PrayerNotificationPhase.before =>
                  Icons.notifications_none_rounded,
                PrayerNotificationPhase.adhan => Icons.mosque_outlined,
                PrayerNotificationPhase.after =>
                  Icons.notifications_active_outlined,
              }, color: Theme.of(context).colorScheme.primary),
              title: Text(notificationPhaseTitle(phase).tr),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => NotificationPhaseScreen(
                    phase: phase,
                    soundPreview: soundPreview,
                  ),
                ),
              ),
            ),
            const Divider(height: 1, indent: 20, endIndent: 20),
          ],
          ListTile(
            key: const ValueKey('notification_category_other'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Icon(
              Icons.notifications_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text('other_notifications'.tr),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AdditionalRemindersScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  Future<void> _requestBatteryAccess(BuildContext context) async {
    final granted =
        await FirstLaunchSetupService.requestBatteryOptimizationExemption();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          (granted
                  ? 'battery_optimization_granted'
                  : 'battery_optimization_not_granted')
              .tr,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('notification_settings'.tr)),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const NotificationSettingsMenu(),
          if (Platform.isAndroid) ...[
            const SizedBox(height: 20),
            const AutomaticSilenceSettings(),
          ],
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.event_available_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text('upcoming_prayer_alarms'.tr),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const UpcomingPrayerAlarmsScreen(),
                ),
              ),
            ),
          ),
          if (Platform.isAndroid) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _requestBatteryAccess(context),
              icon: const Icon(Icons.battery_saver_outlined),
              label: Text('allow_background_activity'.tr),
            ),
          ],
        ],
      ),
    ),
  );
}
