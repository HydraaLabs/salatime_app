import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/helper/location_auto_update_service.dart';
import 'package:salatime/view/screens/location/background_location_screen.dart';

/// Makes travel updates discoverable after onboarding, including limited access.
class AutomaticLocationTile extends StatefulWidget {
  const AutomaticLocationTile({super.key});

  @override
  State<AutomaticLocationTile> createState() => _AutomaticLocationTileState();
}

class _AutomaticLocationTileState extends State<AutomaticLocationTile>
    with WidgetsBindingObserver {
  bool _enabled = false;
  bool _always = false;
  bool _foreground = false;
  bool _busy = false;
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LocationAutoUpdateService.settingsRevision.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    LocationAutoUpdateService.settingsRevision.removeListener(_reload);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _reload();
  }

  Future<void> _reload() async {
    if (!LocationAutoUpdateService.isSupported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled =
          prefs.getBool(LocationAutoUpdateService.enabledKey) ?? false;
      final always = await Permission.locationAlways.isGranted;
      final foreground = always || await Permission.location.isGranted;
      await LocationAutoUpdateService.start();
      if (mounted) {
        setState(() {
          _error = null;
          _enabled = enabled;
          _always = always;
          _foreground = foreground;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loaded = true;
          _error = 'travel_location_error'.tr;
        });
      }
    }
  }

  Future<void> _change(bool enabled) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (enabled) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const BackgroundLocationScreen(fromSettings: true),
          ),
        );
      } else {
        await LocationAutoUpdateService.disable();
      }
      await _reload();
    } catch (_) {
      if (mounted) setState(() => _error = 'travel_location_error'.tr);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!LocationAutoUpdateService.isSupported) return const SizedBox.shrink();
    final status = !_enabled
        ? 'travel_location_off'
        : _always
        ? 'travel_location_background'
        : _foreground
        ? 'travel_location_foreground'
        : 'travel_location_denied';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('travel_location_title'.tr),
          subtitle: Text('${'travel_location_summary'.tr}\n${status.tr}'),
          value: _enabled,
          onChanged: _busy || !_loaded ? null : _change,
        ),
        if (_loaded && !_always)
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    await openAppSettings();
                  },
            child: Text('open_settings'.tr),
          ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}
