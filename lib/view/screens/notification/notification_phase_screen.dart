import 'package:zabi/service/preference_cloud_sync.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:zabi/controller/noti_sound_controller.dart';
import 'package:zabi/helper/prayer_notification_preferences.dart';
import 'package:zabi/helper/salat_waqt_service.dart';
import 'package:zabi/service/personal_notification_sounds.dart';
import 'widgets/sound_selection_field.dart';

String notificationPhaseTitle(PrayerNotificationPhase phase) => switch (phase) {
  PrayerNotificationPhase.before => 'before_adhan',
  PrayerNotificationPhase.adhan => 'on_adhan',
  PrayerNotificationPhase.after => 'after_adhan',
};

String notificationPrayerTitle(PrayerNotificationPrayer prayer) =>
    switch (prayer) {
      PrayerNotificationPrayer.fajr => 'fajr',
      PrayerNotificationPrayer.sunrise => 'sunrise',
      PrayerNotificationPrayer.dhuhr => 'dhuhr',
      PrayerNotificationPrayer.jumaa => 'notification_jumaa',
      PrayerNotificationPrayer.asr => 'asr',
      PrayerNotificationPrayer.maghrib => 'magrib',
      PrayerNotificationPrayer.isha => 'isha',
    };

class NotificationPhaseScreen extends StatefulWidget {
  const NotificationPhaseScreen({
    super.key,
    required this.phase,
    this.reschedule,
    this.soundPreview,
    this.requestPermissions = true,
  });

  final PrayerNotificationPhase phase;
  final Future<void> Function()? reschedule;
  final Future<void> Function(String path)? soundPreview;
  final bool requestPermissions;

  @override
  State<NotificationPhaseScreen> createState() =>
      _NotificationPhaseScreenState();
}

class _NotificationPhaseScreenState extends State<NotificationPhaseScreen>
    with WidgetsBindingObserver {
  List<PrayerNotificationSetting>? _settings;
  bool _saving = false;
  String? _error;
  AudioPlayer? _player;
  int _previewGeneration = 0;
  int _loadGeneration = 0;
  int _saveGeneration = 0;
  StreamSubscription<void>? _changes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _changes = PrayerNotificationPreferences.changes.listen((_) {
      if (mounted) unawaited(_load());
    });
    _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      await PersonalNotificationSounds.load();
      final settings = await PrayerNotificationPreferences.load();
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _settings = settings.where((s) => s.phase == widget.phase).toList();
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'extra_reminders_save_error'.tr);
    }
  }

  Future<void> _save(
    PrayerNotificationPrayer prayer, {
    bool? enabled,
    String? sound,
    int? minutes,
  }) async {
    if (_saving) return;
    final previous = _settings!.firstWhere((s) => s.prayer == prayer);
    final generation = ++_saveGeneration;
    PreferenceCloudSync.instance.noteLocalChange();
    _loadGeneration++;
    setState(() {
      _saving = true;
      _error = null;
      _settings = [
        for (final setting in _settings!)
          if (setting.prayer == prayer)
            setting.copyWith(enabled: enabled, sound: sound, minutes: minutes)
          else
            setting,
      ];
    });
    try {
      await PrayerNotificationPreferences.update(
        prayer,
        widget.phase,
        enabled: enabled,
        sound: sound,
        minutes: minutes,
      );
      // Only local persistence is awaited by the controls. Android scheduling
      // and any permission prompt must not lock the rest of the settings page.
      PreferenceCloudSync.instance.noteLocalChange();
      unawaited(
        _applyNotifications(
          generation,
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
    required bool requestPermission,
  }) async {
    try {
      if (requestPermission && widget.requestPermissions) {
        await SalatWaqtService.checkNotificationPermission();
      }
      await (widget.reschedule?.call() ?? SalatWaqtService.requestRefresh());
    } catch (_) {
      if (mounted && generation == _saveGeneration) {
        setState(() => _error = 'extra_reminders_save_error'.tr);
      }
    }
  }

  Future<void> _stopPreview() async {
    _previewGeneration++;
    try {
      await _player?.stop();
    } catch (_) {
      /* Navigation stays available. */
    }
  }

  Future<void> _preview(String key) async {
    await _stopPreview();
    if (!mounted || key == 'silent') return;
    final generation = _previewGeneration;
    try {
      final sound = NotiSoundController.availableSounds.firstWhere(
        (s) => s['key'] == key,
      );
      if (widget.soundPreview != null) {
        await widget.soundPreview!(sound['path']!);
        return;
      }
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_stopPreview());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_changes?.cancel());
    _loadGeneration++;
    _previewGeneration++;
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _chooseMinutes(PrayerNotificationSetting setting) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(
          (widget.phase == PrayerNotificationPhase.before
                  ? 'minutes_before'
                  : 'minutes_after')
              .tr,
        ),
        children: [
          for (var minute = 0; minute <= 120; minute++)
            SimpleDialogOption(
              key: ValueKey('notification_minutes_$minute'),
              onPressed: () => Navigator.pop(context, minute),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: Text('$minute ${'minutes'.tr}')),
                    if (setting.minutes == minute)
                      Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (mounted && selected != null) {
      await _save(setting.prayer, minutes: selected);
    }
  }

  Widget _card(PrayerNotificationSetting setting) => Card(
    margin: const EdgeInsets.only(bottom: 20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: ValueKey(
            'notification_${widget.phase.name}_${setting.prayer.name}',
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          title: Text(notificationPrayerTitle(setting.prayer).tr),
          value: setting.enabled,
          activeThumbColor: Theme.of(context).colorScheme.primary,
          onChanged: _saving
              ? null
              : (value) => _save(setting.prayer, enabled: value),
        ),
        if (setting.enabled) ...[
          const Divider(height: 1, indent: 20, endIndent: 20),
          SoundSelectionField(
            key: ValueKey(
              'notification_sound_${widget.phase.name}_${setting.prayer.name}',
            ),
            selectedKey: setting.sound,
            label: 'notification_sound_label'.tr,
            compact: true,
            allowImport: true,
            onPreview: _preview,
            onStopPreview: _stopPreview,
            onChanged: _saving
                ? null
                : (sound) => _save(setting.prayer, sound: sound),
          ),
          if (widget.phase != PrayerNotificationPhase.adhan) ...[
            const Divider(height: 1, indent: 20, endIndent: 20),
            ListTile(
              key: ValueKey(
                'notification_time_${widget.phase.name}_${setting.prayer.name}',
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              title: Text('notification_time_label'.tr),
              trailing: Text(
                '${setting.minutes} ${'minutes'.tr}',
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
              onTap: _saving ? null : () => _chooseMinutes(setting),
            ),
          ],
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(notificationPhaseTitle(widget.phase).tr)),
    body: SafeArea(
      top: false,
      child: _settings == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                for (final setting in _settings!) _card(setting),
              ],
            ),
    ),
  );
}
