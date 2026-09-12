import 'package:flutter/material.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zabi/helper/location_helper.dart';
import 'package:zabi/shimmer/all_shimmer_loder.dart';
import 'package:zabi/view/base/custom_app_bar.dart';
import 'package:zabi/view/screens/compass/widget/qiblah_compass.dart';
import 'package:zabi/view/screens/compass/widget/qibla_map.dart';

class CompassScreen extends StatefulWidget {
  final bool appBackButton;
  final VoidCallback? onBackPressed;
  final bool isActive;

  const CompassScreen({
    super.key,
    required this.appBackButton,
    this.isActive = true,
    this.onBackPressed,
  });

  @override
  State<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends State<CompassScreen> {
  /// Returns null when everything is ready, otherwise a translation key
  /// describing why the Qiblah compass cannot start.
  late Future<String?> _initFuture;
  bool _showMap = false;

  @override
  void initState() {
    super.initState();
    _initFuture = _checkQiblahRequirements();
  }

  Future<String?> _checkQiblahRequirements() async {
    final supported = await FlutterQiblah.androidDeviceSensorSupport();
    if (supported != true) {
      return 'our_compass_not_support_in_your_device';
    }

    if (isGeolocatorSupported) {
      var status = await Permission.location.status;
      if (status.isDenied) {
        status = await Permission.location.request();
      }
      if (status.isPermanentlyDenied || status.isRestricted) {
        return 'location_service_denied_forever_for_getting_this_service_please_enable_location';
      }
      if (!status.isGranted) {
        return 'location_service_permission_denied_for_getting_this_service_please_enable_location';
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        return 'please_enable_location_service';
      }
    }
    return null;
  }

  void _retry() {
    // Reset the cached qiblah stream so it can restart after the user
    // granted the permission or enabled the location service.
    FlutterQiblah().dispose();
    setState(() {
      _initFuture = _checkQiblahRequirements();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Appbar start ===>
      appBar: CustomAppBar(
        title: 'qibla_compass'.tr,
        isBackButtonExist: widget.appBackButton,
        onBackPressed: widget.onBackPressed,
        actions: [
          IconButton(
            tooltip: (_showMap ? 'qibla_compass' : 'qibla_map').tr,
            icon: Icon(_showMap ? Icons.explore_outlined : Icons.map_outlined),
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
        ],
      ),

      // body start---> 21.44136615878186, 91.98412914734926
      body: _showMap
          ? const QiblaMap()
          : FutureBuilder<String?>(
              future: _initFuture,
              builder: (_, snapshot) {
                // Loading section---->
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const QuiblaeShimmerScreen();
                }
                // Error message show here--.
                if (snapshot.hasError) {
                  return Center(
                    child: Text("error: ${snapshot.error.toString()}".tr),
                  );
                }

                final errorKey = snapshot.data;
                if (errorKey == null) {
                  // QiblahCompass page return here-->
                  return QiblahCompassWidget(isActive: widget.isActive);
                }
                // error message---.
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(errorKey.tr, textAlign: TextAlign.center),
                        const SizedBox(height: 16.0),
                        ElevatedButton(
                          onPressed: _retry,
                          child: Text('try_again'.tr),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() => _showMap = true),
                          icon: const Icon(Icons.map_outlined),
                          label: Text('qibla_map'.tr),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
