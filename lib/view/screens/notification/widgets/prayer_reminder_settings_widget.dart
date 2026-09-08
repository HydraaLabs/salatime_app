import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zabi/controller/prayer_reminder_controller.dart';
import 'package:zabi/util/dimensions.dart';
import 'package:zabi/util/styles.dart';

class PrayerReminderSettingsWidget extends StatelessWidget {
  const PrayerReminderSettingsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<PrayerReminderController>()
        ? Get.find<PrayerReminderController>()
        : Get.put(PrayerReminderController());

    return Obx(
      () => Padding(
        padding: const EdgeInsets.only(top: Dimensions.PADDING_SIZE_DEFAULT),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.FONT_SIZE_DEFAULT,
              ),
              child: Text(
                'additional_prayer_reminders'.tr,
                style: robotoMedium.copyWith(
                  fontSize: Dimensions.FONT_SIZE_LARGE,
                ),
              ),
            ),
            _ReminderCard(
              type: PrayerReminderType.before,
              title: 'before_adhan'.tr,
              description: 'before_adhan_description'.tr,
              enabled: controller.beforeEnabled.value,
              minutes: controller.beforeMinutes.value,
              sound: controller.beforeSound.value,
              controller: controller,
            ),
            _ReminderCard(
              type: PrayerReminderType.after,
              title: 'after_adhan'.tr,
              description: 'after_adhan_description'.tr,
              enabled: controller.afterEnabled.value,
              minutes: controller.afterMinutes.value,
              sound: controller.afterSound.value,
              controller: controller,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.type,
    required this.title,
    required this.description,
    required this.enabled,
    required this.minutes,
    required this.sound,
    required this.controller,
  });

  final PrayerReminderType type;
  final String title;
  final String description;
  final bool enabled;
  final int minutes;
  final String sound;
  final PrayerReminderController controller;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: Theme.of(context).cardColor,
      shadowColor: Get.isDarkMode ? Colors.grey[800] : Colors.grey[200],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimensions.RADIUS_DEFAULT),
      ),
      child: Column(
        children: [
          SwitchListTile(
            activeThumbColor: primaryColor,
            activeTrackColor: primaryColor.withValues(alpha: 0.45),
            title: Text(title, style: robotoMedium),
            subtitle: Text(description, style: robotoRegular),
            value: enabled,
            onChanged: (value) => controller.setEnabled(type, value),
          ),
          if (enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimensions.PADDING_SIZE_DEFAULT,
                0,
                Dimensions.PADDING_SIZE_DEFAULT,
                Dimensions.PADDING_SIZE_DEFAULT,
              ),
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: minutes,
                    isExpanded: true,
                    decoration: _inputDecoration(
                      context,
                      type == PrayerReminderType.before
                          ? 'minutes_before'.tr
                          : 'minutes_after'.tr,
                      Icons.schedule,
                    ),
                    items: PrayerReminderController.minuteOptions
                        .map(
                          (value) => DropdownMenuItem<int>(
                            value: value,
                            child: Text('$value ${'minutes'.tr}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) controller.setMinutes(type, value);
                    },
                  ),
                  const SizedBox(height: Dimensions.PADDING_SIZE_DEFAULT),
                  DropdownButtonFormField<String>(
                    initialValue: sound,
                    isExpanded: true,
                    decoration: _inputDecoration(
                      context,
                      'reminder_sound'.tr,
                      Icons.notifications_active_outlined,
                    ),
                    items: controller.sounds
                        .map(
                          (option) => DropdownMenuItem<String>(
                            value: option['key'],
                            child: Text(option['labelKey']!.tr),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) controller.setSound(type, value);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context,
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Dimensions.RADIUS_DEFAULT),
      ),
    );
  }
}
