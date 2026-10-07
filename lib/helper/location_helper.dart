import 'package:flutter/foundation.dart';

/// Geolocator has no implementation on some platforms (e.g. Linux desktop).
/// Use this guard before any Geolocator call to avoid a MissingPluginException.
bool get isGeolocatorSupported =>
    kIsWeb ||
    switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      _ => false,
    };
