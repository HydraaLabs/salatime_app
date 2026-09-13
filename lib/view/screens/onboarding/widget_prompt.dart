import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/helper/prayer_widget_sync.dart';
import 'package:zabi/view/screens/onboarding/prayer_widget_preview.dart';

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
      final size = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => const _WidgetPicker(),
      );
      if (size != null) {
        await PrayerWidgetSync.refresh();
        await channel.invokeMethod<bool>('pin', {'size': size});
      }
    } on PlatformException {
      /* The launcher may not support pinning. */
    } on MissingPluginException {
      /* No Android widget host on this platform. */
    }
  }
}

class _WidgetPicker extends StatefulWidget {
  const _WidgetPicker();

  @override
  State<_WidgetPicker> createState() => _WidgetPickerState();
}

class _WidgetPickerState extends State<_WidgetPicker> {
  String selectedSize = 'medium';

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: RadioGroup<String>(
            groupValue: selectedSize,
            onChanged: (value) {
              if (value != null) setState(() => selectedSize = value);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: IconButton(
                    tooltip: 'close'.tr,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
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
                for (final option in [
                  (size: 'small', columns: 2, rows: 1),
                  (size: 'medium', columns: 4, rows: 1),
                  (size: 'large', columns: 5, rows: 2),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: selectedSize == option.size
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).dividerColor,
                          width: selectedSize == option.size ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          RadioListTile<String>(
                            key: ValueKey('widget_option_${option.size}'),
                            value: option.size,
                            title: Text('widget_size_${option.size}'.tr),
                            subtitle: Text(
                              '${option.columns} × ${option.rows}',
                              textDirection: TextDirection.ltr,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'widget_preview'.tr,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 6),
                                PrayerWidgetPreview(size: option.size),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, selectedSize),
                  child: Text('widget_add'.tr),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('widget_later'.tr),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
