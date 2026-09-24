import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/helper/location_auto_update_service.dart';
import 'package:salatime/helper/route_helper.dart';

/// A neutral explanation immediately followed by the system permission dialog.
/// Opened only by opting into travel updates in prayer settings on either OS.
class BackgroundLocationScreen extends StatefulWidget {
  const BackgroundLocationScreen({super.key, this.fromSettings = false});

  final bool fromSettings;

  static Future<bool> shouldShow() async {
    // Background tracking is optional on both OSes, not part of onboarding.
    return false;
  }

  @override
  State<BackgroundLocationScreen> createState() =>
      _BackgroundLocationScreenState();
}

class _BackgroundLocationScreenState extends State<BackgroundLocationScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bg_location_prompt_shown', true);
    if (!mounted) return;
    if (widget.fromSettings) {
      Navigator.of(context).pop();
    } else {
      Get.offAllNamed(RouteHelper.bottomNavbar);
    }
  }

  Future<void> _requestPermission() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var foreground = await Permission.location.status;
      if (foreground.isDenied) foreground = await Permission.location.request();
      if (foreground.isGranted) {
        final always = await Permission.locationAlways.status;
        if (always.isDenied) await Permission.locationAlways.request();
        // The system may grant only While Using or defer the Always prompt.
        // Keep the user's opt-in, without pretending background access exists.
        if (await Permission.location.isGranted ||
            await Permission.locationAlways.isGranted) {
          await LocationAutoUpdateService.enable();
        }
      }
      // Respect refusals. No automatic Settings prompt or permission loop.
      await _finish();
    } catch (_) {
      if (mounted) setState(() => _error = 'travel_location_error'.tr);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    return PopScope(
      canPop: !ios && !_busy,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 72,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'background_location_title'.tr,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'background_location_description'.tr,
                      textAlign: TextAlign.center,
                    ),
                    if (!ios) ...[
                      const SizedBox(height: 16),
                      Text(
                        'travel_location_android_permission'.tr,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _requestPermission,
                        child: Text('onboarding_next'.tr),
                      ),
                    ),
                    if (!ios)
                      TextButton(
                        onPressed: _busy ? null : _finish,
                        child: Text('no_thanks'.tr),
                      ),
                    // Recovery after a platform error is not a pre-permission
                    // alternative; never trap someone on an unavailable API.
                    if (_error != null && ios)
                      TextButton(onPressed: _finish, child: Text('close'.tr)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
