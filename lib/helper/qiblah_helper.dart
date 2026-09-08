import 'dart:math' show atan2, cos, pi, sin, tan;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class QiblahHelper {
  QiblahHelper._();

  static const double kaabaLatitude = 21.4225;
  static const double kaabaLongitude = 39.8262;

  static const MethodChannel _geomagneticChannel = MethodChannel(
    'net.salatime.app/geomagnetic',
  );

  /// Initial great-circle bearing from a location to the Kaaba, expressed as
  /// degrees clockwise from true north.
  static double bearingFromTrueNorth(double latitude, double longitude) {
    final latitudeRadians = latitude * (pi / 180);
    final kaabaLatitudeRadians = kaabaLatitude * (pi / 180);
    final longitudeDelta = (kaabaLongitude - longitude) * (pi / 180);
    final y = sin(longitudeDelta);
    final x =
        cos(latitudeRadians) * tan(kaabaLatitudeRadians) -
        sin(latitudeRadians) * cos(longitudeDelta);

    return normalizeDegrees(atan2(y, x) * (180 / pi));
  }

  /// Converts a magnetic Android heading to true north. On iOS the compass
  /// plugin already supplies a true heading, so no correction is required.
  static Future<double> magneticDeclination({
    required double latitude,
    required double longitude,
    required double altitude,
    required DateTime measuredAt,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) return 0;

    try {
      return await _geomagneticChannel
              .invokeMethod<double>('getDeclination', <String, Object>{
                'latitude': latitude,
                'longitude': longitude,
                'altitude': altitude,
                'timestamp': measuredAt.millisecondsSinceEpoch,
              }) ??
          0;
    } on MissingPluginException {
      return 0;
    } on PlatformException {
      return 0;
    }
  }

  static double clockwiseAngleToQiblah({
    required double trueHeading,
    required double qiblahBearing,
  }) {
    return normalizeDegrees(qiblahBearing - trueHeading);
  }

  static double angularDistanceToQiblah({
    required double trueHeading,
    required double qiblahBearing,
  }) {
    final clockwise = clockwiseAngleToQiblah(
      trueHeading: trueHeading,
      qiblahBearing: qiblahBearing,
    );
    return clockwise > 180 ? 360 - clockwise : clockwise;
  }

  static double normalizeDegrees(double angle) => (angle + 360) % 360;
}
