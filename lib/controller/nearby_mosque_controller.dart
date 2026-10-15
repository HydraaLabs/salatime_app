// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/helper/location_helper.dart';
import 'package:salatime/helper/location_permission_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:salatime/helper/debug_http_client.dart';
import 'package:http/http.dart' as http;
import 'package:salatime/util/app_constants.dart';
import 'dart:convert';

import 'package:salatime/view/base/custom_snackbar.dart';

class NearbyMosqueController extends GetxController {
  NearbyMosqueController({
    http.Client? client,
    void Function(String message, {bool isError})? notify,
  }) : _http = client ?? appHttpClient,
       _notify = notify ?? _showSnackBar;

  final http.Client _http;
  final void Function(String message, {bool isError}) _notify;

  static void _showSnackBar(String message, {bool isError = false}) =>
      showCustomSnackBar(message, isError: isError);
  GlobalKey<FormState> nearbyMosqueFormKey = GlobalKey<FormState>();

  // Get Address Variable =====>
  var location = '';
  double? latitude;
  double? longitude;
  RxString currentAddress = '--'.obs;
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

  Future<void>? _locating;

  Future<void> getLocation() {
    final pending = _locating;
    if (pending != null) return pending;
    return _locating = _getLocation().whenComplete(() => _locating = null);
  }

  Future<void> _getLocation() async {
    final prefs = await SharedPreferences.getInstance();
    if (isClosed || !LocationPermissionCoordinator.isForeground) return;
    try {
      if (!isGeolocatorSupported) {
        isLocationDenied.value = true;
        await prefs.setBool('isLocationDenied', true);
        return;
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (isClosed || !LocationPermissionCoordinator.isForeground) return;
      if (!serviceEnabled) {
        isLocationDenied.value = true;
        await Geolocator.openLocationSettings();
        return;
      }
      final permission = await LocationPermissionCoordinator.instance
          .ensureForeground(canRequest: () => !isClosed);
      if (isClosed || !LocationPermissionCoordinator.isForeground) return;
      if (!LocationPermissionCoordinator.isGranted(permission)) {
        await _locationDenied(
          prefs,
          permanently: permission == LocationPermission.deniedForever,
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (isClosed || !LocationPermissionCoordinator.isForeground) return;
      userLocation.value = '${position.latitude},${position.longitude}';
      searchNearbyPlaces();
      update();
    } catch (_) {
      // Both permission checks and position acquisition can fail natively.
      // Calls started by the screen must not escape as unhandled futures.
      if (!isClosed && LocationPermissionCoordinator.isForeground) {
        await _locationDenied(prefs);
      }
    }
  }

  Future<void> _locationDenied(
    SharedPreferences prefs, {
    bool permanently = false,
  }) async {
    isLocationDenied.value = true;
    await prefs.setBool('isLocationDenied', true);
    if (isClosed || !LocationPermissionCoordinator.isForeground) return;
    showCustomSnackBar(
      'for_getting_Automatic_Prayer_Time_Nearby_Mosque_Qibla_Compass_need_to_enable_location_permission'
          .tr,
      isError: true,
      onTap: permanently ? () => openAppSettings() : null,
    );
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

  Future<void> searchNearbyPlaces() async {
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
        print(
          'Overpass: invalid userLocation "${userLocation.value}", '
          'retrying getLocation()',
        );
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

    isLoading(true);
    try {
      final language = Get.locale?.languageCode ?? 'en';
      var results = await _fromSalaTime(lat, lng, kmToRadious, language);
      results ??= await _fromOverpass(lat, lng, kmToRadious);
      if (results != null) {
        places.value = results;
        await _saveResults(lat, lng, kmToRadious, results);
        return;
      }
      final saved = await _savedResults(lat, lng, kmToRadious);
      if (saved != null) {
        places.value = saved;
        _notify('nearby_mosques_saved_results'.tr);
        return;
      }
      places.value = [];
      _notify('nearby_mosques_unavailable'.tr, isError: true);
    } catch (e) {
      places.value = [];
      if (kDebugMode) print('Nearby mosques error: $e');
      _notify('nearby_mosques_unavailable'.tr, isError: true);
    } finally {
      isLoading(false);
    }
  }

  /// SalaTime's cached OpenStreetMap proxy: one request, results already
  /// filtered by radius, sorted and named in the app language.
  Future<List<Map<String, dynamic>>?> _fromSalaTime(
    double lat,
    double lng,
    int radiusKm,
    String language,
  ) async {
    try {
      final uri = Uri.parse('${AppConstants.BASE_URL}/api/mosques/nearby')
          .replace(
            queryParameters: {
              'lat': lat.toStringAsFixed(5),
              'lng': lng.toStringAsFixed(5),
              'radius': '$radiusKm',
              'lang': language,
            },
          );
      final response = await _http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return null;
      final decoded = json.decode(response.body);
      if (decoded is! Map || decoded['status'] != true) return null;
      final mosques = decoded['mosques'];
      if (mosques is! List) return null;
      return [
        for (final mosque in mosques.whereType<Map>())
          if (mosque['lat'] is num && mosque['lng'] is num)
            _place(
              name: mosque['name'] as String?,
              address: mosque['address'] as String?,
              lat: (mosque['lat'] as num).toDouble(),
              lng: (mosque['lng'] as num).toDouble(),
              distance: (mosque['distance'] as num?)?.toDouble() ?? 0,
            ),
      ];
    } catch (e) {
      if (kDebugMode) print('SalaTime mosques proxy failed: $e');
      return null;
    }
  }

  /// Direct OpenStreetMap fallback, used only when the proxy is unreachable.
  Future<List<Map<String, dynamic>>?> _fromOverpass(
    double lat,
    double lng,
    int radiusKm,
  ) async {
    final radius = 1000 * radiusKm;
    final query =
        '[out:json][timeout:15];('
        'node["amenity"="place_of_worship"]["religion"="muslim"](around:$radius,$lat,$lng);'
        'way["amenity"="place_of_worship"]["religion"="muslim"](around:$radius,$lat,$lng);'
        ');out center;';
    for (final endpoint in _overpassUrls) {
      try {
        final response = await _http
            .post(
              Uri.parse(endpoint),
              headers: {'User-Agent': _overpassUserAgent},
              body: {'data': query},
            )
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) continue;
        final elements = json.decode(response.body)['elements'];
        if (elements is! List) continue;
        final results = <Map<String, dynamic>>[];
        for (final element in elements) {
          final eLat = (element['lat'] ?? element['center']?['lat'])
              ?.toDouble();
          final eLng = (element['lon'] ?? element['center']?['lon'])
              ?.toDouble();
          if (eLat == null || eLng == null) continue;
          final Map tags = element['tags'] ?? {};
          final address = [
            tags['addr:housenumber'],
            tags['addr:street'],
            tags['addr:city'],
          ].whereType<String>().join(' ');
          results.add(
            _place(
              name: tags['name'] as String?,
              address: address,
              lat: eLat,
              lng: eLng,
              distance: _distance(lat, lng, eLat, eLng),
            ),
          );
        }
        results.sort(
          (a, b) =>
              (a['distance'] as double).compareTo(b['distance'] as double),
        );
        return results;
      } catch (e) {
        if (kDebugMode) print('Overpass $endpoint failed: $e');
      }
    }
    return null;
  }

  /// The shape the screen has used since the Google Places integration.
  Map<String, dynamic> _place({
    required String? name,
    required String? address,
    required double lat,
    required double lng,
    required double distance,
  }) => {
    'name': (name == null || name.trim().isEmpty)
        ? 'nearby_mosque_unnamed'.tr
        : name,
    'vicinity': (address == null || address.trim().isEmpty) ? '--' : address,
    'geometry': {
      'location': {'lat': lat, 'lng': lng},
    },
    'distance': distance,
  };

  double _distance(double lat, double lng, double toLat, double toLng) =>
      isGeolocatorSupported
      ? Geolocator.distanceBetween(lat, lng, toLat, toLng)
      : 0;

  static const _savedKey = 'nearby_mosques_last_v1';

  /// The last successful search, kept for when every source is unavailable.
  Future<void> _saveResults(
    double lat,
    double lng,
    int radiusKm,
    List<Map<String, dynamic>> results,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _savedKey,
        json.encode({
          'lat': lat,
          'lng': lng,
          'radius': radiusKm,
          'results': results,
        }),
      );
    } catch (_) {
      // Saving is a convenience; the current results are already shown.
    }
  }

  /// Saved results for a search made within 1 km with at least this radius.
  Future<List<Map<String, dynamic>>?> _savedResults(
    double lat,
    double lng,
    int radiusKm,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = json.decode(prefs.getString(_savedKey) ?? '');
      if (saved is! Map ||
          (saved['radius'] as num) < radiusKm ||
          _distance(
                lat,
                lng,
                (saved['lat'] as num).toDouble(),
                (saved['lng'] as num).toDouble(),
              ) >
              1000) {
        return null;
      }
      final results = [
        for (final item in (saved['results'] as List).whereType<Map>())
          Map<String, dynamic>.from(item),
      ];
      return results
          .where(
            (item) => (item['distance'] as num).toDouble() <= radiusKm * 1000,
          )
          .toList();
    } catch (_) {
      return null;
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
