// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zabi/controller/theme_controller.dart';
import 'package:zabi/theme/modern_light_theme.dart';
import 'package:zabi/util/dimensions.dart';
import 'package:zabi/util/styles.dart';

class ThemeModeDWWidget extends StatelessWidget {
  const ThemeModeDWWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThemeController>(
      builder: (controller) {
        return ListTile(
          minVerticalPadding: 0,
          contentPadding: const EdgeInsets.all(5),
          title: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(5),
            ),
            child: ExpansionTile(
              collapsedShape: const RoundedRectangleBorder(
                side: BorderSide.none,
              ),
              shape: const RoundedRectangleBorder(side: BorderSide.none),
              title: Row(
                children: [
                  Icon(
                    Icons.brightness_auto_outlined,
                    size: 25,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: Dimensions.PADDING_SIZE_DEFAULT),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'theme_mode_title'.tr,
                          style: robotoMedium.copyWith(
                            fontSize: Dimensions.FONT_SIZE_LARGE,
                          ),
                        ),
                        Text(
                          _labelFor(controller.mode).tr,
                          style: robotoRegular.copyWith(
                            fontSize: Dimensions.FONT_SIZE_SMALL,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              children: [
                _ThemeModeOption(
                  icon: Icons.brightness_auto_rounded,
                  title: 'theme_mode_auto'.tr,
                  description: 'theme_mode_auto_desc'.tr,
                  selected: controller.mode == ThemeController.daylight,
                  onTap: () => controller.setMode(ThemeController.daylight),
                ),
                _ThemeModeOption(
                  icon: Icons.light_mode_outlined,
                  title: 'theme_mode_light'.tr,
                  selected: controller.mode == ThemeController.light,
                  onTap: () => controller.setMode(ThemeController.light),
                ),
                _ThemeModeOption(
                  icon: Icons.dark_mode_outlined,
                  title: 'theme_mode_dark'.tr,
                  selected: controller.mode == ThemeController.dark,
                  onTap: () => controller.setMode(ThemeController.dark),
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

class _ThemeModeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeModeOption({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 10, 18, 10),
        child: Row(
          children: [
            Icon(icon, color: AppColorModern.emerald),
            const SizedBox(width: Dimensions.PADDING_SIZE_DEFAULT),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: robotoMedium),
                  if (description != null)
                    Text(
                      description!,
                      style: robotoRegular.copyWith(
                        fontSize: Dimensions.FONT_SIZE_SMALL,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected
                  ? AppColorModern.emerald
                  : Theme.of(context).hintColor,
            ),
          ],
        ),
      ),
    );
  }
}
