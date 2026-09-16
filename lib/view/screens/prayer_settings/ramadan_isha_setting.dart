import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/helper/ramadan_isha_settings.dart';
import 'package:salatime/helper/salat_waqt_service.dart';

/// An optional convention for locally calculated times; published calendars
/// remain authoritative and do not display this control.
class RamadanIshaSetting extends StatefulWidget {
  const RamadanIshaSetting({super.key});

  @override
  State<RamadanIshaSetting> createState() => _RamadanIshaSettingState();
}

class _RamadanIshaSettingState extends State<RamadanIshaSetting> {
  int _interval = 0;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) setState(() => _interval = RamadanIshaSettings.read(prefs));
    } catch (_) {
      if (mounted) setState(() => _error = 'please_try_again'.tr);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _select(int? value) async {
    if (_busy || value == null || value == _interval) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await RamadanIshaSettings.setInterval(value);
      if (mounted) setState(() => _interval = value);
      await SalatWaqtService.requestRefresh();
    } catch (_) {
      if (mounted) setState(() => _error = 'alarm_refresh_failed'.tr);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DropdownButtonFormField<int>(
        key: ValueKey('ramadan-isha-$_interval'),
        initialValue: _interval,
        isExpanded: true,
        itemHeight: null,
        decoration: InputDecoration(labelText: 'ramadan_isha_title'.tr),
        items: [
          for (final minutes in [0, 90, 120])
            DropdownMenuItem<int>(
              value: minutes,
              child: Text(
                minutes == 0
                    ? 'ramadan_isha_method'.tr
                    : 'ramadan_isha_interval'.trParams({'minutes': '$minutes'}),
              ),
            ),
        ],
        onChanged: _busy ? null : _select,
      ),
      const SizedBox(height: 8),
      Text(
        'ramadan_isha_description'.tr,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      const SizedBox(height: 12),
    ],
  );
}
