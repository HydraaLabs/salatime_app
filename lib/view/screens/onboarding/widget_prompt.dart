import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WidgetPrompt {
  static const channel = MethodChannel('net.salatime.app/prayer_widget');
  static const seenKey = 'home_widget_prompt_seen_v1';
  static Future<void> showOnce(
    BuildContext context,
    SharedPreferences prefs,
  ) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        prefs.getBool(seenKey) == true) {
      return;
    }
    try {
      if (await channel.invokeMethod<bool>('canPin') != true ||
          !context.mounted) {
        return;
      }
      await prefs.setBool(seenKey, true);
      if (!context.mounted) return;
      final add = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: IconButton(
                      tooltip: 'close'.tr,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  Icon(
                    Icons.widgets_outlined,
                    size: 64,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'widget_prompt_title'.tr,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text('widget_prompt_body'.tr, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('widget_add'.tr),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('widget_later'.tr),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (add == true) {
        await channel.invokeMethod<bool>('pin', {'size': 'large'});
      }
    } on PlatformException {
      /* The launcher may not support pinning. */
    } on MissingPluginException {
      /* No Android widget host on this platform. */
    }
  }
}
