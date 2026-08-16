import 'dart:io';

import 'package:flutter/foundation.dart';

/// Geolocator has no implementation on some platforms (e.g. Linux desktop).
/// Use this guard before any Geolocator call to avoid a MissingPluginException.
bool get isGeolocatorSupported =>
    kIsWeb ||
    Platform.isAndroid ||
    Platform.isIOS ||
    Platform.isMacOS ||
    Platform.isWindows;
