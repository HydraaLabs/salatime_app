import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:salatime/view/screens/onboarding/ios_widget_instructions.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:salatime/helper/prayer_widget_sync.dart';

class PrayerWidgetSettings extends StatefulWidget {
  const PrayerWidgetSettings({super.key});
  @override
  State<PrayerWidgetSettings> createState() => _PrayerWidgetSettingsState();
}

class _PrayerWidgetSettingsState extends State<PrayerWidgetSettings> {
  static const channel = MethodChannel('net.salatime.app/prayer_widget');
  Map<String, dynamic>? values;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await channel.invokeMapMethod<String, dynamic>('get');
      if (mounted) setState(() => values = data);
    } catch (_) {
      if (mounted) setState(() => error = 'widget_settings_error'.tr);
    }
  }

  Future<void> _save(String key, dynamic value) async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await channel.invokeMethod<void>('set', {key: value});
      if (mounted) setState(() => values![key] = value);
    } catch (_) {
      if (mounted) setState(() => error = 'widget_settings_error'.tr);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      leading: Icon(
        Icons.widgets_outlined,
        color: Theme.of(context).primaryColor,
      ),
      title: Text('widget_settings'.tr),
      children: [
        if (error != null)
          Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
        if (values == null && error == null)
          const Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(),
          ),
        if (values != null) ...[
          for (final entry in {
            'countdown': 'widget_countdown',
            'seconds': 'widget_seconds',
            'city': 'widget_city',
            'date': 'widget_date',
            'illustration': 'widget_illustration',
          }.entries)
            SwitchListTile(
              title: Text(entry.value.tr),
              value: values![entry.key] as bool,
              onChanged: saving ? null : (value) => _save(entry.key, value),
            ),
          SwitchListTile(
            title: Text('widget_transparent'.tr),
            value: values!['opacity'] == 0,
            onChanged: saving
                ? null
                : (value) => _save('opacity', value ? 0 : 100),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Text('${'widget_opacity'.tr} · ${values!['opacity']}%'),
                Slider(
                  value: (values!['opacity'] as num).toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 10,
                  onChanged: saving
                      ? null
                      : (value) => _save('opacity', value.round()),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  (defaultTargetPlatform == TargetPlatform.iOS
                          ? 'widget_ios_hint'
                          : 'widget_resize_hint')
                      .tr,
                ),
                const SizedBox(height: 12),
                for (final size in ['small', 'medium', 'large'])
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_to_home_screen),
                    label: Text('widget_add_$size'.tr),
                    onPressed: () async {
                      try {
                        await PrayerWidgetSync.refresh();
                        if (defaultTargetPlatform == TargetPlatform.iOS) {
                          if (context.mounted) {
                            await IosWidgetInstructions.show(context, size);
                          }
                          return;
                        }
                        final supported = await channel.invokeMethod<bool>(
                          'pin',
                          {'size': size},
                        );
                        if (mounted && supported != true) {
                          setState(() => error = 'widget_add_manual'.tr);
                        }
                      } catch (_) {
                        if (mounted) {
                          setState(() => error = 'widget_settings_error'.tr);
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}
