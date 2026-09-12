import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Open a route to the selected mosque using the device's current location.
/// The HTTPS Maps URL also works when only a browser is installed.
Future<bool> openMosqueDirections({
  required double latitude,
  required double longitude,
}) async {
  if (!latitude.isFinite ||
      !longitude.isFinite ||
      latitude.abs() > 90 ||
      longitude.abs() > 180) {
    return false;
  }

  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '$latitude,$longitude',
    'dir_action': 'navigate',
  });

  // canLaunchUrl can return false under Android package visibility restrictions
  // even when launchUrl succeeds. Attempt the launch and handle its real result.
  for (final mode in [
    LaunchMode.externalApplication,
    LaunchMode.inAppBrowserView,
  ]) {
    try {
      if (await launchUrl(uri, mode: mode)) return true;
    } on PlatformException {
      // A missing/disabled external activity must still allow the browser fallback.
    } on MissingPluginException {
      // Unsupported hosts should report a failure without an unhandled exception.
    }
  }
  return false;
}
