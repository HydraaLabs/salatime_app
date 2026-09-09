// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zabi/controller/theme_controller.dart';
import 'package:zabi/util/dimensions.dart';
import 'package:zabi/util/styles.dart';

class ThemeModeDWWidget extends StatelessWidget {
  const ThemeModeDWWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThemeController>(
      builder: (controller) {
        return Padding(
          padding: const EdgeInsets.all(5),
          child: Material(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(5),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.brightness_6_outlined,
                        size: 25,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: Dimensions.PADDING_SIZE_DEFAULT),
                      Expanded(
                        child: Text(
                          'theme_mode_title'.tr,
                          style: robotoMedium.copyWith(
                            fontSize: Dimensions.FONT_SIZE_LARGE,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final mode in const [
                  ThemeController.light,
                  ThemeController.dark,
                  ThemeController.daylight,
                ])
                  RadioListTile<String>(
                    value: mode,
                    groupValue: controller.mode,
                    activeColor: Theme.of(context).colorScheme.primary,
                    title: Text(_labelFor(mode).tr, style: robotoMedium),
                    subtitle: mode == ThemeController.daylight
                        ? Text('theme_mode_auto_desc'.tr)
                        : null,
                    onChanged: (value) {
                      if (value != null) controller.setMode(value);
                    },
                  ),
                const SizedBox(height: Dimensions.PADDING_SIZE_EXTRA_SMALL),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _labelFor(String mode) => switch (mode) {
    ThemeController.light => 'theme_mode_light',
    ThemeController.dark => 'theme_mode_dark',
    _ => 'theme_mode_auto',
  };
}
