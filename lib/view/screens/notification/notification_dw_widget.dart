import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'notification_settings_screen.dart';

/// Settings entry point. Detailed notification controls live on their own pages.
class NofificationDWWidget extends StatelessWidget {
  const NofificationDWWidget({super.key});

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      key: const ValueKey('open_notification_settings'),
      leading: Icon(
        Icons.notifications_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text('notification_settings'.tr),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const NotificationSettingsScreen(),
        ),
      ),
    ),
  );
}
