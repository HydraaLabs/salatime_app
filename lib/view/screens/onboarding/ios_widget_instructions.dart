import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:salatime/view/screens/onboarding/prayer_widget_preview.dart';

class IosWidgetInstructions {
  static Future<void> show(BuildContext context, String size) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('widget_prompt_title'.tr),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('widget_size_$size'.tr),
                const SizedBox(height: 12),
                PrayerWidgetPreview(size: size),
                const SizedBox(height: 16),
                Text('widget_ios_steps'.tr),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('close'.tr),
            ),
          ],
        ),
      );
}
