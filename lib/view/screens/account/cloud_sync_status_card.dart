import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zabi/service/preference_cloud_sync.dart';
import 'package:zabi/service/cloud/preference_device.dart';

class CloudSyncStatusCard extends StatelessWidget {
  const CloudSyncStatusCard({super.key});
  @override
  Widget build(BuildContext context) => Obx(() {
    final sync = PreferenceCloudSync.instance;
    final value = sync.status.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_outlined,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'cloud_preferences_title'.tr,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value.tr),
            if (AppPreferenceDevice.personalSoundsLocal.value)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('cloud_personal_sounds_local'.tr),
              ),
            if (AppPreferenceDevice.silenceNeedsActivation.value)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('cloud_silence_device_permission'.tr),
              ),
            if (value == 'cloud_conflict')
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => sync.resolveConflict(keepLocal: false),
                    child: Text('cloud_use_account'.tr),
                  ),
                  OutlinedButton(
                    onPressed: () => sync.resolveConflict(keepLocal: true),
                    child: Text('cloud_use_device'.tr),
                  ),
                ],
              )
            else if (value != 'cloud_signed_out')
              TextButton.icon(
                onPressed: value == 'cloud_syncing' ? null : sync.sync,
                icon: const Icon(Icons.sync),
                label: Text('cloud_sync_now'.tr),
              ),
          ],
        ),
      ),
    );
  });
}
