// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/helper/location_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:zabi/helper/debug_http_client.dart';
import 'dart:convert';

import 'package:zabi/view/base/custom_snackbar.dart';

class NearbyMosqueController extends GetxController {
  GlobalKey<FormState> nearbyMosqueFormKey = GlobalKey<FormState>();

  // Get Address Variable =====>
  var location = '';
  double? latitude;
  double? longitude;
  RxString currentAddress = '--'.obs;
  late StreamSubscription<Position> streamSubscription;
  late LocationSettings locationSettings;
  RxBool isLocationDenied = false.obs;

  // local variable
  var userLocation = ''.obs;
  var places = [].obs;
  RxBool isLoading = false.obs;
  List<String> splitKm = [];
  int kmToRadious = 2;

  var km = '2  KM'.obs;

  @override
  void onInit() {
    super.onInit();
    // getLocation();
    loadKmDropdownValue(km.value);
  }

  Future<void> getLocation() async {
    bool serviceEnabled = false;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    LocationPermission permission;

    // Geolocator is not implemented on every platform (e.g. Linux desktop).
    // Gracefully fall back instead of throwing a MissingPluginException.
    if (!isGeolocatorSupported) {
      isLocationDenied.value = true;
      await prefs.setBool("isLocationDenied", true);
      debugPrint('Geolocator is not supported on this platform');
      return;
    }

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // If not enabled, prompt user to enable location services
      await Geolocator.openLocationSettings();
      return;
    }

    // Check location permission status
    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      // If permission is denied, request permission from the user
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        //   If permission is still denied, show a message to the user using GetX's Snackbar
        showCustomSnackBar(
          "for_getting_Automatic_Prayer_Time_Nearby_Mosque_Qibla_Compass_need_to_enable_location_permission"
              .tr,
          isError: true,
        );

        await prefs.setBool("isLocationDenied", true);
        bool? storedFontSize = prefs.getBool("isLocationDenied");
        if (storedFontSize != null) {
          isLocationDenied.value = storedFontSize;
        }

        return;
      }
    } else if (permission == LocationPermission.deniedForever) {
      // If permission is permanently denied, show a message to the user using GetX's Snackbar
      showCustomSnackBar(
        "for_getting_Automatic_Prayer_Time_Nearby_Mosque_Qibla_Compass_need_to_enable_location_permission"
            .tr,
        isError: true,
        onTap: () => openAppSettings(),
      );

      await prefs.setBool("isLocationDenied", true);
      bool? storedFontSize = prefs.getBool("isLocationDenied");
      if (storedFontSize != null) {
        isLocationDenied.value = storedFontSize;
      }
      return;
    }

    // If permission is granted, retrieve the current position

    if (serviceEnabled) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        userLocation.value = '${position.latitude},${position.longitude}';
        searchNearbyPlaces();
        update();
      } catch (e) {
        await prefs.setBool("isLocationDenied", true);
        bool? storedFontSize = prefs.getBool("isLocationDenied");
        if (storedFontSize != null) {
          isLocationDenied.value = storedFontSize;
        }
        showCustomSnackBar(
          "for_getting_Automatic_Prayer_Time_Nearby_Mosque_Qibla_Compass_need_to_enable_location_permission"
              .tr,
          isError: true,
          onTap: () => openAppSettings(),
        );
      }
    }
  }

  // Overpass API (OpenStreetMap) — free, no API key required.
  // Main endpoint + public mirrors, tried in order on failure (some
  // endpoints are unreachable/throttled from certain mobile networks).
  static const List<String> _overpassUrls = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.nchc.org.tw/api/interpreter',
  ];
  static const String _overpassUserAgent =
      'SalaTime/1.0 (contact: contact@salatime.net)';

  void searchNearbyPlaces() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool("isLocationDenied", false);
    bool? storedFontSize = prefs.getBool("isLocationDenied");
    if (storedFontSize != null) {
      isLocationDenied.value = storedFontSize;
    }

    // userLocation is stored as "lat,lng" by getLocation().
    var parts = userLocation.value.split(',');
    var lat = parts.length == 2 ? double.tryParse(parts[0]) : null;
    var lng = parts.length == 2 ? double.tryParse(parts[1]) : null;
    if (lat == null || lng == null) {
      // No valid coordinates yet: try to fetch the position once.
      // getLocation() re-triggers searchNearbyPlaces() on success.
      if (kDebugMode) {
        print('Overpass: invalid userLocation "${userLocation.value}", '
            'retrying getLocation()');
      }
      await getLocation();
      parts = userLocation.value.split(',');
      lat = parts.length == 2 ? double.tryParse(parts[0]) : null;
      lng = parts.length == 2 ? double.tryParse(parts[1]) : null;
      if (lat != null && lng != null) return; // nested search is running
      showCustomSnackBar(
        "for_getting_Automatic_Prayer_Time_Nearby_Mosque_Qibla_Compass_need_to_enable_location_permission"
            .tr,
        isError: true,
      );
      return;
    }

    final int radius = 1000 * kmToRadious;
    final String query = '[out:json];('
        'node["amenity"="place_of_worship"]["religion"="muslim"](around:$radius,$lat,$lng);'
        'way["amenity"="place_of_worship"]["religion"="muslim"](around:$radius,$lat,$lng);'
        ');out center;';

    isLoading(true);
    try {
      // Try each Overpass endpoint once, in order, until one answers.
      String? responseBody;
      for (final endpoint in _overpassUrls) {
        try {
          final response = await appHttpClient
              .post(
                Uri.parse(endpoint),
                headers: {'User-Agent': _overpassUserAgent},
                body: {'data': query},
              )
              .timeout(const Duration(seconds: 40));

          if (response.statusCode != 200) {
            if (kDebugMode) {
              print('Overpass $endpoint failed: '
                  'status ${response.statusCode}');
            }
            continue;
          }
          responseBody = response.body;
          break;
        } catch (e) {
          if (kDebugMode) {
            print('Overpass $endpoint failed: $e');
          }
        }
      }

      if (responseBody == null) {
        // All endpoints failed.
        places.value = [];
        showCustomSnackBar("please_try_again".tr, isError: true);
        return;
      }

      final decoded = json.decode(responseBody);
      final List elements = decoded['elements'] ?? [];
      final List<Map<String, dynamic>> results = [];

      for (final element in elements) {
        // Nodes carry lat/lng directly; ways carry a "center".
        final double? eLat = (element['lat'] ?? element['center']?['lat'])
            ?.toDouble();
        final double? eLng = (element['lon'] ?? element['center']?['lon'])
            ?.toDouble();
        if (eLat == null || eLng == null) continue;

        final Map tags = element['tags'] ?? {};
        final addressParts = <String>[
          if (tags['addr:housenumber'] != null) '${tags['addr:housenumber']}',
          if (tags['addr:street'] != null) '${tags['addr:street']}',
          if (tags['addr:city'] != null) '${tags['addr:city']}',
        ];

        double distance = 0;
        if (isGeolocatorSupported) {
          distance = Geolocator.distanceBetween(lat, lng, eLat, eLng);
        }

        // Keep the same shape the screen used with Google Places so the
        // view does not need to change.
        results.add({
          'name': tags['name'] ?? 'Mosquée',
          'vicinity': addressParts.isEmpty ? '--' : addressParts.join(' '),
          'geometry': {
            'location': {'lat': eLat, 'lng': eLng},
          },
          'distance': distance,
        });
      }

      results.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );
      places.value = results;
    } catch (e) {
      places.value = [];
      if (kDebugMode) {
        print("Overpass api Error: $e");
      }
      showCustomSnackBar("please_try_again".tr, isError: true);
    } finally {
      isLoading(false);
    }
  }

  // search by distance function
  void loadKmDropdownValue(String newValue) async {
    km.value = newValue;
    splitKm = km.split(" ");
    kmToRadious = int.parse(splitKm[0]);
    update();
  }
}
