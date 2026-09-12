import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zabi/controller/noti_sound_controller.dart';
import 'package:zabi/helper/salat_waqt_service.dart';
import 'package:zabi/util/app_constants.dart';
import 'package:zabi/util/dimensions.dart';

import 'import_sound_button.dart';
import 'sound_selection_field.dart';

class NotificationSoundSelector extends StatefulWidget {
  const NotificationSoundSelector({super.key});

  @override
  State<NotificationSoundSelector> createState() =>
      _NotificationSoundSelectorState();
}

class _NotificationSoundSelectorState extends State<NotificationSoundSelector> {
  @override
  void dispose() {
    if (Get.isRegistered<NotiSoundController>()) {
      Get.find<NotiSoundController>().stopSound();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<NotiSoundController>()) {
      Get.put(NotiSoundController());
    }
    return GetBuilder<NotiSoundController>(
      builder: (controller) => Obx(() {
        final selectedPath = controller.selectedSound.value;
        final selected = controller.sounds.where(
          (sound) => sound['path'] == selectedPath,
        );
        return Padding(
          padding: const EdgeInsets.all(Dimensions.PADDING_SIZE_DEFAULT),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SoundSelectionField(
                selectedKey: selected.isEmpty
                    ? AppConstants.DEFAULT_NOTIFICATION_SOUND
                    : selected.first['key']!,
                label: 'choose_sound_for_notification'.tr,
                onPreview: (key) => controller.playSound(
                  controller.sounds.firstWhere(
                    (sound) => sound['key'] == key,
                  )['path']!,
                ),
                onStopPreview: controller.stopSound,
                onChanged: (key) async {
                  await controller.selectSound(
                    controller.sounds.firstWhere(
                      (sound) => sound['key'] == key,
                    )['path'],
                  );
                  await SalatWaqtService.initializeSalatWaqt();
                },
              ),
              ImportSoundButton(
                onImported: (sound) async {
                  await controller.selectSound(sound['path']);
                  controller.update();
                  await SalatWaqtService.initializeSalatWaqt();
                },
              ),
            ],
          ),
        );
      }),
    );
  }
}
