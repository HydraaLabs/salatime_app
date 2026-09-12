import 'package:zabi/service/preference_cloud_sync.dart';
import 'package:zabi/view/screens/notification/widgets/sound_selection_field.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:zabi/controller/noti_sound_controller.dart';
import 'package:zabi/controller/package_prayer_time_controller.dart';
import 'package:zabi/helper/prayer_alarm_health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/helper/additional_reminder_plan.dart';
import 'package:zabi/helper/salat_waqt_service.dart';
import 'package:zabi/service/personal_notification_sounds.dart';

class AdditionalRemindersScreen extends StatefulWidget {
  const AdditionalRemindersScreen({super.key, this.refreshSchedule});
  final Future<void> Function()? refreshSchedule;

  @override
  State<AdditionalRemindersScreen> createState() =>
      _AdditionalRemindersScreenState();
}

class _AdditionalRemindersScreenState extends State<AdditionalRemindersScreen> {
  List<AdditionalReminderSetting>? _settings;
  AudioPlayer? _player;
  int _previewGeneration = 0;
  int _loadGeneration = 0;
  int _saveGeneration = 0;
  StreamSubscription<void>? _changes;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _changes = AdditionalReminderPreferences.changes.listen((_) {
      if (mounted) unawaited(_load());
    });
    _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      await PersonalNotificationSounds.load();
      final settings = await AdditionalReminderPreferences.load();
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _settings = settings;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _error = 'extra_reminders_save_error'.tr);
      }
    }
  }

  Future<void> _save(
    AdditionalReminderSetting original, {
    bool? enabled,
    String? sound,
    int? minutes,
    String? anchor,
    bool? useDefaultSound,
  }) async {
    if (_saving || _settings == null) return;
    final previous = _settings!.firstWhere((s) => s.type == original.type);
    final generation = ++_saveGeneration;
    PreferenceCloudSync.instance.noteLocalChange();
    _loadGeneration++;
    setState(() {
      _saving = true;
      _error = null;
      _settings = [
        for (final setting in _settings!)
          if (setting.type == original.type)
            setting.copyWith(
              enabled: enabled,
              sound: sound,
              minutes: minutes,
              anchor: anchor,
              useDefaultSound: useDefaultSound,
            )
          else
            setting,
      ];
    });
    try {
      // Patch the latest preferences atomically, including cloud changes made
      // while a sound or timing selector was open.
      final setting = await AdditionalReminderPreferences.update(
        original.type,
        enabled: enabled,
        sound: sound,
        minutes: minutes,
        anchor: anchor,
        useDefaultSound: useDefaultSound,
      );
      PreferenceCloudSync.instance.noteLocalChange();
      unawaited(
        _applyNotifications(
          generation,
          enabled: setting.enabled,
          requestPermission: enabled == true && !previous.enabled,
        ),
      );
    } catch (_) {
      await _load();
      if (mounted) setState(() => _error = 'extra_reminders_save_error'.tr);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _applyNotifications(
    int generation, {
    required bool enabled,
    required bool requestPermission,
  }) async {
    try {
      if (requestPermission) {
        await SalatWaqtService.checkNotificationPermission();
      }
      await (widget.refreshSchedule?.call() ??
          SalatWaqtService.requestRefresh());
      if (!mounted || generation != _saveGeneration) return;
      if (enabled) {
        final status = await PrayerAlarmHealth.status();
        final prefs = await SharedPreferences.getInstance();
        final message = status?['notifications'] == false
            ? 'extra_reminders_permission_needed'
            : (!Get.isRegistered<PrayerTimeController>() ||
                  Get.find<PrayerTimeController>().prayerTimeZone == null)
            ? 'daily_markers_empty'
            : prefs.getBool(SalatWaqtService.failedKey) == true
            ? 'extra_reminders_save_error'
            : null;
        if (mounted && generation == _saveGeneration && message != null) {
          setState(() => _error = message.tr);
        }
      }
    } catch (_) {
      if (mounted && generation == _saveGeneration) {
        setState(() => _error = 'extra_reminders_save_error'.tr);
      }
    }
  }

  Future<void> _preview(String key) async {
    if (!mounted) return;
    final generation = ++_previewGeneration;
    try {
      await _player?.stop();
      if (!mounted || generation != _previewGeneration) return;
      if (key == 'silent') return;
      final sound = NotiSoundController.availableSounds.firstWhere(
        (item) => item['key'] == key,
      );
      _player ??= AudioPlayer();
      if (key.startsWith('custom_')) {
        await _player!.setUrl(sound['path']!);
      } else {
        await _player!.setAsset(sound['path']!);
      }
      if (mounted && generation == _previewGeneration) {
        unawaited(_player!.play().catchError((Object _) {}));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'extra_reminders_preview_error'.tr);
    }
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    _loadGeneration++;
    _previewGeneration++;
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        'extra_reminders_title'.tr,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    body: SafeArea(
      top: false,
      child: _settings == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                for (final type in AdditionalReminderPreferences.visibleTypes)
                  _card(
                    _settings!.firstWhere((setting) => setting.type == type),
                  ),
              ],
            ),
    ),
  );

  Widget _card(AdditionalReminderSetting setting) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            key: ValueKey('extra_${setting.type.name}'),
            title: Text(setting.titleKey.tr),
            value: setting.enabled,
            onChanged: _saving
                ? null
                : (value) => _save(setting, enabled: value),
          ),
          if (setting.enabled) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SoundSelectionField(
                key: ValueKey('${setting.type.name}_${setting.sound}'),
                selectedKey: setting.sound,
                compact: true,
                allowImport: true,
                label: 'reminder_sound'.tr,
                onPreview: _preview,
                onStopPreview: () async {
                  _previewGeneration++;
                  await _player?.stop();
                },
                onChanged: _saving
                    ? null
                    : (value) async {
                        await _save(
                          setting,
                          sound: value,
                          useDefaultSound: false,
                        );
                        await _preview(value);
                      },
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              key: ValueKey('extra_time_${setting.type.name}'),
              title: Text('extra_reminder_time'.tr),
              subtitle: Text(
                '${setting.timingLabelKey.tr} · ${setting.usesClock ? TimeOfDay(hour: setting.minutes ~/ 60, minute: setting.minutes % 60).format(context) : '${setting.minutes} ${'minutes'.tr}'}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _saving
                  ? null
                  : () async {
                      if (setting.usesClock) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: setting.minutes ~/ 60,
                            minute: setting.minutes % 60,
                          ),
                        );
                        if (time != null && mounted) {
                          await _save(
                            setting,
                            minutes: time.hour * 60 + time.minute,
                          );
                        }
                      } else {
                        final value = await Navigator.of(context)
                            .push<AdditionalReminderSetting>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    _ReminderTimingScreen(setting: setting),
                              ),
                            );
                        if (value != null && mounted) {
                          await _save(
                            setting,
                            minutes: value.minutes == setting.minutes
                                ? null
                                : value.minutes,
                            anchor:
                                value.effectiveAnchor == setting.effectiveAnchor
                                ? null
                                : value.effectiveAnchor,
                          );
                        }
                      }
                    },
            ),
            if (!setting.useDefaultSound)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  icon: const Icon(Icons.settings_backup_restore),
                  label: Text('extra_reminder_restore_default_sound'.tr),
                  onPressed: _saving
                      ? null
                      : () => _save(
                          setting,
                          sound: AdditionalReminderSetting.defaults(
                            setting.type,
                          ).sound,
                          useDefaultSound: true,
                        ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReminderTimingScreen extends StatefulWidget {
  const _ReminderTimingScreen({required this.setting});
  final AdditionalReminderSetting setting;
  @override
  State<_ReminderTimingScreen> createState() => _ReminderTimingScreenState();
}

class _ReminderTimingScreenState extends State<_ReminderTimingScreen> {
  late AdditionalReminderSetting _setting = widget.setting;
  @override
  Widget build(BuildContext context) {
    final type = _setting.type;
    final choices =
        [
          AdditionalReminderType.fajrAlarm,
          AdditionalReminderType.duha,
          AdditionalReminderType.evening,
        ].contains(type)
        ? AdditionalReminderSetting.allowedAnchors(type)
        : <String>[];
    return Scaffold(
      appBar: AppBar(title: Text('extra_reminder_time'.tr)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _setting.titleKey.tr,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (choices.isNotEmpty)
              Card(
                child: Column(
                  children: [
                    for (final anchor in choices)
                      Semantics(
                        checked: _setting.effectiveAnchor == anchor,
                        child: ListTile(
                          key: ValueKey('extra_anchor_$anchor'),
                          leading: Icon(
                            _setting.effectiveAnchor == anchor
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                          ),
                          title: Text('extra_time_$anchor'.tr),
                          onTap: () => setState(
                            () => _setting = _setting.copyWith(anchor: anchor),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_setting.timingLabelKey.tr),
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: ValueKey('extra_minutes_${_setting.minutes}'),
              initialValue: _setting.minutes,
              isExpanded: true,
              menuMaxHeight: 320,
              decoration: InputDecoration(
                labelText: 'minutes'.tr,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (var minute = 0; minute <= 120; minute++)
                  DropdownMenuItem(value: minute, child: Text('$minute')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _setting = _setting.copyWith(minutes: value));
                }
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context, _setting),
              child: Text('extra_reminder_save_time'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
