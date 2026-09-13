import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:salatime/service/automatic_silence_service.dart';

class AutomaticSilenceSettings extends StatefulWidget {
  const AutomaticSilenceSettings({super.key});

  @override
  State<AutomaticSilenceSettings> createState() =>
      _AutomaticSilenceSettingsState();
}

class _AutomaticSilenceSettingsState extends State<AutomaticSilenceSettings>
    with WidgetsBindingObserver {
  AutomaticSilenceStatus? _value;
  String? _error;
  bool _busy = false;
  bool _pendingEnable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final result = await AutomaticSilenceService.load();
      if (!mounted) return;
      setState(() => _value = result);
      if (_pendingEnable && result.access && result.exact && !_busy) {
        _pendingEnable = false;
        await _save({'enabled': true});
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'silence_save_error');
    }
  }

  Future<void> _save(Map<String, dynamic> changes) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await AutomaticSilenceService.save(changes);
      if (mounted) setState(() => _value = result);
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _error =
              {
                'silence_unsupported',
                'silence_access_needed',
                'silence_exact_needed',
              }.contains(error.code)
              ? error.code
              : 'silence_save_error',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'silence_save_error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(bool enabled) async {
    _pendingEnable = enabled;
    if (enabled && !_value!.access) {
      setState(() => _error = 'silence_access_needed');
      await _permission(exact: false);
      return;
    }
    if (enabled && !_value!.exact) {
      setState(() => _error = 'silence_exact_needed');
      await _permission(exact: true);
      return;
    }
    _pendingEnable = false;
    await _save({'enabled': enabled});
  }

  Future<void> _permission({required bool exact}) async {
    try {
      if (exact) {
        await AutomaticSilenceService.requestExact();
      } else {
        await AutomaticSilenceService.requestAccess();
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'silence_save_error');
    }
  }

  Widget _minutes(String title, String setting, int value, int min, int max) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.tr),
            Row(
              children: [
                Expanded(child: Text('$value ${'silence_minutes'.tr}')),
                IconButton(
                  tooltip: 'silence_decrease'.tr,
                  onPressed: _busy || value <= min
                      ? null
                      : () => _save({setting: (value - 5).clamp(min, max)}),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                IconButton(
                  tooltip: 'silence_increase'.tr,
                  onPressed: _busy || value >= max
                      ? null
                      : () => _save({setting: (value + 5).clamp(min, max)}),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final value = _value;
    return Card(
      child: ExpansionTile(
        leading: Icon(
          Icons.do_not_disturb_on_outlined,
          color: Theme.of(context).primaryColor,
        ),
        title: Text('silence_title'.tr),
        children: [
          if (_error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(_error!.tr)),
          if (value == null && _error == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          if (value != null && !value.supported)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('silence_unsupported'.tr),
            ),
          if (value != null && value.supported) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('silence_description'.tr),
            ),
            SwitchListTile(
              title: Text('silence_enable'.tr),
              value: value.enabled,
              onChanged: _busy ? null : _toggle,
            ),
            if ((_pendingEnable || value.enabled) && !value.access)
              TextButton.icon(
                onPressed: () => _permission(exact: false),
                icon: const Icon(Icons.settings_outlined),
                label: Text('silence_open_access'.tr),
              ),
            if ((_pendingEnable || value.enabled) &&
                value.access &&
                !value.exact)
              TextButton.icon(
                onPressed: () => _permission(exact: true),
                icon: const Icon(Icons.alarm),
                label: Text('silence_open_exact'.tr),
              ),
            if (value.enabled && !value.hasSchedule)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('silence_no_schedule'.tr),
              ),
            const Divider(),
            for (final entry in const {
              1: 'fajr',
              2: 'dhuhr',
              3: 'asr',
              4: 'magrib',
              5: 'isha',
            }.entries)
              CheckboxListTile(
                title: Text(entry.value.tr),
                value: value.prayers.contains(entry.key),
                onChanged: _busy
                    ? null
                    : (checked) {
                        final selected = value.prayers.toSet();
                        if (checked == true) {
                          selected.add(entry.key);
                        } else {
                          selected.remove(entry.key);
                        }
                        _save({'prayers': selected.toList()..sort()});
                      },
              ),
            _minutes('silence_delay', 'delay', value.delay, 0, 60),
            _minutes('silence_duration', 'duration', value.duration, 5, 120),
            SwitchListTile(
              title: Text('silence_friday_override'.tr),
              value: value.fridayOverride,
              onChanged: _busy
                  ? null
                  : (enabled) => _save({'fridayOverride': enabled}),
            ),
            if (value.fridayOverride)
              _minutes(
                'silence_friday_duration',
                'fridayDuration',
                value.fridayDuration,
                5,
                120,
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('silence_restore_hint'.tr),
            ),
          ],
        ],
      ),
    );
  }
}
