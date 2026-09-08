// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:flutter_compass_v2/flutter_compass_v2.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:zabi/helper/location_helper.dart';
import 'package:zabi/helper/qiblah_helper.dart';
import 'package:zabi/shimmer/all_shimmer_loder.dart';
import 'package:zabi/util/dimensions.dart';
import 'package:zabi/util/images.dart';
import 'package:zabi/util/styles.dart';

class QiblahCompassWidget extends StatefulWidget {
  final bool isActive;

  const QiblahCompassWidget({super.key, this.isActive = true});

  @override
  State<QiblahCompassWidget> createState() => _QiblahCompassWidgetState();
}

class _QiblahCompassWidgetState extends State<QiblahCompassWidget> {
  double _previousDevice = 0;
  double _previousQiblah = 0;

  Stream<_QiblahReading>? _qiblahStream;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _qiblahStream = _createQiblahStream();
    }
  }

  @override
  void didUpdateWidget(covariant QiblahCompassWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) return;
    _qiblahStream = widget.isActive ? _createQiblahStream() : null;
  }

  /// The flutter_qiblah singleton stream can get stuck forever (created once
  /// in an error state, or the underlying
  /// [Geolocator.getPositionStream] never emits on some devices). Build our own
  /// stream instead: one position fix + live compass events.
  Stream<_QiblahReading> _createQiblahStream() async* {
    if (!isGeolocatorSupported) {
      throw StateError('location_not_available');
    }

    final position = await _getBestAvailablePosition();
    final qiblahBearing = QiblahHelper.bearingFromTrueNorth(
      position.latitude,
      position.longitude,
    );
    final declination = await QiblahHelper.magneticDeclination(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      measuredAt: position.timestamp,
    );

    final events = FlutterCompass.events;
    if (events == null) {
      throw StateError('compass_not_available');
    }

    DateTime? lastEmission;
    double? lastHeading;
    await for (final event in events) {
      final magneticHeading = event.heading;
      if (magneticHeading == null) continue;

      final trueHeading = QiblahHelper.normalizeDegrees(
        magneticHeading + declination,
      );
      final now = DateTime.now();
      final elapsed = lastEmission == null
          ? const Duration(days: 1)
          : now.difference(lastEmission);
      final delta = lastHeading == null
          ? 360.0
          : (((trueHeading - lastHeading + 540) % 360) - 180).abs();

      // Android can emit around 30 readings/second. Limiting UI updates keeps
      // the compass responsive without rebuilding the full widget every tick.
      if (elapsed < const Duration(milliseconds: 50) ||
          (delta < 0.5 && elapsed < const Duration(milliseconds: 200))) {
        continue;
      }

      lastEmission = now;
      lastHeading = trueHeading;
      yield _QiblahReading(
        trueHeading: trueHeading,
        qiblahBearing: qiblahBearing,
        clockwiseAngle: QiblahHelper.clockwiseAngleToQiblah(
          trueHeading: trueHeading,
          qiblahBearing: qiblahBearing,
        ),
      );
    }
  }

  Future<Position> _getBestAvailablePosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      final lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) return lastKnownPosition;
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<_QiblahReading>(
      stream: _qiblahStream,
      builder: (_, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'location_service_permission_denied_for_getting_this_service_please_enable_location'
                    .tr,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const QuiblaeShimmerScreen();
        }

        final qiblahDirection = snapshot.data!;
        final angleToQiblah = QiblahHelper.angularDistanceToQiblah(
          trueHeading: qiblahDirection.trueHeading,
          qiblahBearing: qiblahDirection.qiblahBearing,
        );
        double deviceAngle = _normalizeAngle(
          qiblahDirection.trueHeading,
          _previousDevice,
        );
        double qiblahAngle = _normalizeAngle(
          qiblahDirection.clockwiseAngle,
          _previousQiblah,
        );

        final previousDevice = _previousDevice;
        final previousQiblah = _previousQiblah;
        _previousDevice = deviceAngle;
        _previousQiblah = qiblahAngle;

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: RepaintBoundary(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Compass background (rotates with device)
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: previousDevice,
                          end: deviceAngle,
                        ),
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOutCubic,
                        builder: (_, angle, child) {
                          return Transform.rotate(
                            angle: (-angle) * (pi / 180),
                            child: child,
                          );
                        },
                        child: Image.asset(
                          Images.Compass,
                          height: 330,
                          fit: BoxFit.fill,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      // Needle (rotates towards Qiblah)
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: previousQiblah,
                          end: qiblahAngle,
                        ),
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        builder: (_, angle, child) {
                          return Transform.rotate(
                            angle: angle * (pi / 180),
                            child: child,
                          );
                        },
                        child: Image.asset(
                          Images.Compass_Needle,
                          height: 400,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32.0,
                  vertical: 10.0,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).hintColor.withOpacity(0.05),
                      Theme.of(context).hintColor.withOpacity(0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18.0),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${angleToQiblah.round()}°',
                      style: robotoMedium.copyWith(
                        fontSize: Dimensions.FONT_SIZE_EXTRA_LARGE,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      'device_angle_to_qibla'.tr,
                      style: robotoMedium.copyWith(
                        fontSize: Dimensions.FONT_SIZE_DEFAULT,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40.0),
            ],
          ),
        );
      },
    );
  }

  double _normalizeAngle(double current, double previous) {
    double diff = current - previous;
    if (diff.abs() > 180) {
      if (diff > 0) {
        current -= 360;
      } else {
        current += 360;
      }
    }
    return current;
  }
}

class _QiblahReading {
  final double trueHeading;
  final double qiblahBearing;
  final double clockwiseAngle;

  const _QiblahReading({
    required this.trueHeading,
    required this.qiblahBearing,
    required this.clockwiseAngle,
  });
}
