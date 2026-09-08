// ignore_for_file: avoid_print, deprecated_member_use, strict_top_level_inference

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/data/api/api_client.dart';
import 'package:zabi/data/model/response/city_model.dart';
import 'package:zabi/data/model/response/city_suggestion_model.dart';
import 'package:zabi/data/model/response/todays_prayer_time_model.dart';
import 'package:zabi/controller/theme_controller.dart';
import 'package:zabi/helper/location_helper.dart';
import 'package:zabi/util/app_constants.dart';
import 'package:zabi/view/base/custom_snackbar.dart';

class PrayerTimeController extends GetxController implements GetxService {
  final ApiClient apiClient;
  PrayerTimeController({required this.apiClient});

  // local variable
  RxBool isprayerTimeLoading = false.obs;
  PrayerTimeModel? prayerTimeModel;

  // Prayer Time
  TextEditingController citySearchController = TextEditingController();
  final RxString search = ''.obs;

  RxString fajrStart = "--".obs;
  RxString sunriseStart = "--".obs;
  RxString dhuhrStart = "--".obs;
  RxString asrStart = "--".obs;
  RxString magribStart = "--".obs;
  RxString ishaStart = "--".obs;
  RxString currentWaktTime = "--".obs;
  RxString currentWaqtName = "--".obs;

  RxString currentAddress = '--'.obs;
  RxString saveAddress = '--'.obs;
  RxBool isLocationDenied = false.obs;

  RxBool isPrayerTimes = false.obs;
  double? latitude;
  double? longitude;
  String? saveLocalStoreCity;
  Position? _lastPosition;
  static const String _prayerTimeCachePrefix = 'prayer_time_response_cache_v1_';
  static const String _prayerTimeCacheIndexKey =
      'prayer_time_response_cache_v1_index';
  static const String _prayerTimeCoveragePrefix =
      'prayer_time_response_cache_v2_coverage_';
  static const String _automaticLatitudeKey = 'prayer_time_automatic_latitude';
  static const String _automaticLongitudeKey =
      'prayer_time_automatic_longitude';
  static const String _automaticCityKey = 'prayer_time_automatic_city';
  static const int _maxCachedPrayerTimes = 430;
  static const int _offlineCalendarPastDays = 7;
  static const int _offlineCalendarFutureDays = 45;
  final Map<String, PrayerTimeModel> _prayerTimeCache = {};
  final Map<String, Future<PrayerTimeModel?>> _pendingPrayerTimeRequests = {};
  final Map<String, Future<int>> _pendingPrayerCalendarRequests = {};
  Map<String, dynamic>? _lastPrayerTimeRequestTemplate;
  bool _isWarmingPrayerTimeCache = false;

  Future<Position> _resolvePosition() async {
    final inMemory = _lastPosition;
    if (inMemory != null) return inMemory;

    final cached = await Geolocator.getLastKnownPosition();
    if (cached != null) {
      _lastPosition = cached;
      return cached;
    }

    final current = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    );
    _lastPosition = current;
    return current;
  }

  /// Picks the first non-empty city field of a [Placemark].
  /// `subAdministrativeArea` is often null on Android depending on the
  /// city/country, so we fall back through several fields and finally keep
  /// the previous address (or '--') instead of crashing on a null `!`.
  String _placemarkCity(Placemark placemark) {
    for (final value in [
      placemark.locality,
      placemark.subAdministrativeArea,
      placemark.administrativeArea,
      placemark.subLocality,
    ]) {
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return currentAddress.value;
  }

  Future<void> getLocation() async {
    bool serviceEnabled = false;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    LocationPermission permission;

    // A manually searched city with saved coordinates does not need GPS:
    // prayer times are computed for those coordinates instead.
    final savedManualCity = prefs.getString(AppConstants.saveCityName);
    if ((prefs.getBool(AppConstants.isPrayerTme) ?? false) &&
        savedManualCity != null &&
        prefs.getDouble(AppConstants.manualCityLat) != null &&
        prefs.getDouble(AppConstants.manualCityLng) != null) {
      isLocationDenied.value = false;
      await fetchPrayerTime(
        reload: false,
        isManualPrayerTme: true,
        manualCity: savedManualCity,
      );
      update();
      return;
    }

    // Geolocator is not implemented on every platform (e.g. Linux desktop).
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
        final position = await _resolvePosition();
        latitude = position.latitude;
        longitude = position.longitude;

        await prefs.setDouble(_automaticLatitudeKey, position.latitude);
        await prefs.setDouble(_automaticLongitudeKey, position.longitude);
        try {
          final addressList = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          currentAddress.value = _placemarkCity(addressList.first);
          await prefs.setString(_automaticCityKey, currentAddress.value);
        } catch (_) {
          currentAddress.value =
              prefs.getString(_automaticCityKey) ?? currentAddress.value;
        }

        final isPrayerTme = prefs.getBool(AppConstants.isPrayerTme);
        bool isTimeTrue = prefs.getBool(AppConstants.isPrayerTme) ?? false;

        isPrayerTimes.value = isTimeTrue;
        debugPrint("isTimeTrue: ${isPrayerTimes.value}");

        final saveCityName = prefs.getString(AppConstants.saveCityName);

        await fetchPrayerTime(
          reload: false,
          isManualPrayerTme: isPrayerTme ?? false,
          manualCity: saveCityName ?? currentAddress.toString(),
        );

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

  // Calculation Methods
  final List<Map<String, String>> _calculationMethod = [
    {'id': '0', 'value': 'JAFARI'},
    {'id': '1', 'value': 'KARACHI'},
    {'id': '2', 'value': 'ISNA'},
    {'id': '3', 'value': 'MWL'},
    {'id': '4', 'value': 'MAKKAH'},
    {'id': '5', 'value': 'EGYPT'},
    {'id': '7', 'value': 'TEHRAN'},
    {'id': '8', 'value': 'GULF'},
    {'id': '9', 'value': 'KUWAIT'},
    {'id': '10', 'value': 'QATAR'},
    {'id': '11', 'value': 'SINGAPORE'},
    {'id': '12', 'value': 'FRANCE'},
    {'id': '13', 'value': 'TURKEY'},
    {'id': '14', 'value': 'RUSSIA'},
    {'id': '15', 'value': 'MOONSIGHTING'},
    {'id': '16', 'value': 'DUBAI'},
    {'id': '17', 'value': 'JAKIM'},
    {'id': '18', 'value': 'TUNISIA'},
    {'id': '19', 'value': 'ALGERIA'},
    {'id': '20', 'value': 'KEMENAG'},
    {'id': '21', 'value': 'MOROCCO'},
    {'id': '22', 'value': 'PORTUGAL'},
    {'id': '23', 'value': 'JORDAN'},
  ];

  List<Map<String, String>> get calculationMethod => _calculationMethod;
  String? _selectedCalculationMethod;
  String? get selectedCalculationMethod => _selectedCalculationMethod;

  // Madhab List
  final List<Map<String, String>> _prayerMadhabList = [
    {'id': 'STANDARD', 'value': 'STANDARD'},
    {'id': 'HANAFI', 'value': 'HANAFI'},
  ];

  List<Map<String, String>> get prayerMadhabList => _prayerMadhabList;

  String? _selectedPrayerMadhab;
  String? get selectedPrayerMadhab => _selectedPrayerMadhab;

  /// Load the settings from local storage or set default values.
  Future<void> loadPrayerTimeSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    isManualPrayerTime.value =
        prefs.getBool(AppConstants.IS_MANUAL_PRAYER_TIME) ?? false;

    // Load Calculation Method
    String? savedMethod = prefs.getString('selectedCalculationMethod');
    if (savedMethod == null) {
      Map<String, String> defaultMethod = {'id': '1', 'value': 'KARACHI'};
      await prefs.setString('selectedCalculationMethod', defaultMethod['id']!);
      _selectedCalculationMethod = defaultMethod['id'];
    } else {
      _selectedCalculationMethod = savedMethod;
    }

    // Load Prayer Madhab
    String? savedMadhab = prefs.getString('selectedPrayerMadhab');
    if (savedMadhab == null) {
      Map<String, String> defaultMadhab = {
        'id': 'STANDARD',
        'value': 'STANDARD',
      };
      await prefs.setString('selectedPrayerMadhab', defaultMadhab['id']!);
      _selectedPrayerMadhab = defaultMadhab['id'];
    } else {
      _selectedPrayerMadhab = savedMadhab;
    }

    update();
  }

  /// Set a new calculation method and save it in local storage.
  Future<void> setSelectedCalculationMethod(String? value) async {
    if (value != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedCalculationMethod', value);
      _selectedCalculationMethod = value;
      update();
    }
  }

  /// Set a new prayer Madhab and save it in local storage.
  Future<void> setSelectedPrayerMadhab(String? value) async {
    if (value != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedPrayerMadhab', value);
      _selectedPrayerMadhab = value;
      update();
    }
  }

  var isManualPrayerTime = false.obs;

  String _normalizedCoordinate(dynamic value) {
    final coordinate = double.tryParse('$value');
    return coordinate == null ? '$value' : coordinate.toStringAsFixed(3);
  }

  String _prayerTimeCacheKey(Map<String, dynamic> requestBody) {
    final automatic = requestBody['type'] == 'automatic';
    return jsonEncode([
      requestBody['type'],
      requestBody['date'],
      automatic ? '' : '${requestBody['city']}'.trim().toLowerCase(),
      automatic
          ? _normalizedCoordinate(requestBody['lat'])
          : requestBody['lat'],
      automatic
          ? _normalizedCoordinate(requestBody['lng'])
          : requestBody['lng'],
      requestBody['prayer_method'],
      requestBody['school'],
      requestBody['timezone'],
    ]);
  }

  String _prayerTimeStorageKey(String cacheKey) {
    return '$_prayerTimeCachePrefix${base64Url.encode(utf8.encode(cacheKey))}';
  }

  Future<PrayerTimeModel?> _cachedPrayerTime(
    SharedPreferences prefs,
    String cacheKey,
  ) async {
    final memoryValue = _prayerTimeCache[cacheKey];
    if (memoryValue != null) return memoryValue;

    final storageKey = _prayerTimeStorageKey(cacheKey);
    final storedValue = prefs.getString(storageKey);
    if (storedValue == null) return null;

    try {
      final decoded = jsonDecode(storedValue) as Map<String, dynamic>;
      final model = PrayerTimeModel.fromJson(decoded);
      if (!_isUsablePrayerTime(model, cacheKey: cacheKey)) {
        await prefs.remove(storageKey);
        return null;
      }
      _rememberPrayerTime(cacheKey, model);
      return model;
    } catch (_) {
      await prefs.remove(storageKey);
      return null;
    }
  }

  bool _isUsablePrayerTime(
    PrayerTimeModel model, {
    String? expectedDate,
    String? cacheKey,
  }) {
    final data = model.data;
    if (model.status == false || data == null) return false;
    if (expectedDate != null && data.date != expectedDate) return false;
    if (cacheKey != null) {
      final keyParts = jsonDecode(cacheKey) as List<dynamic>;
      if (data.date == null || data.date != keyParts[1]) return false;
    }
    return [
      data.fajrStart,
      data.sunrise,
      data.zuhrStart,
      data.asrStart,
      data.maghribStart,
      data.ishaStart,
    ].every((value) => value != null && value != '0:00' && value.contains(':'));
  }

  void _rememberPrayerTime(String cacheKey, PrayerTimeModel model) {
    if (!_prayerTimeCache.containsKey(cacheKey) &&
        _prayerTimeCache.length >= _maxCachedPrayerTimes) {
      _prayerTimeCache.remove(_prayerTimeCache.keys.first);
    }
    _prayerTimeCache[cacheKey] = model;
  }

  Future<void> _storePrayerTime(
    SharedPreferences prefs,
    String cacheKey,
    PrayerTimeModel model,
  ) async {
    _rememberPrayerTime(cacheKey, model);
    final storageKey = _prayerTimeStorageKey(cacheKey);
    await prefs.setString(storageKey, jsonEncode(model.toJson()));

    final cacheIndex =
        prefs.getStringList(_prayerTimeCacheIndexKey)?.toList() ?? <String>[];
    cacheIndex
      ..remove(storageKey)
      ..add(storageKey);
    while (cacheIndex.length > _maxCachedPrayerTimes) {
      await prefs.remove(cacheIndex.removeAt(0));
    }
    await prefs.setStringList(_prayerTimeCacheIndexKey, cacheIndex);
  }

  Future<PrayerTimeModel?> _loadPrayerTime(
    SharedPreferences prefs,
    Map<String, dynamic> requestBody,
  ) async {
    final cacheKey = _prayerTimeCacheKey(requestBody);
    final cached = await _cachedPrayerTime(prefs, cacheKey);
    if (cached != null) return cached;

    // One calendar request fills J-7 through J+45, including the requested
    // date. The legacy daily endpoint remains a narrow fallback while backend
    // deployments propagate through caches and proxies.
    await _loadPrayerTimeCalendar(prefs, requestBody);
    final calendarValue = await _cachedPrayerTime(prefs, cacheKey);
    if (calendarValue != null) return calendarValue;

    final pending = _pendingPrayerTimeRequests[cacheKey];
    if (pending != null) return pending;

    final request = () async {
      final response = await apiClient.postData(
        AppConstants.TODAYS_PRAYER_TIME,
        requestBody,
      );
      if (response.statusCode != 200) return null;

      final model = PrayerTimeModel.fromJson(response.body);
      if (!_isUsablePrayerTime(model, expectedDate: '${requestBody['date']}')) {
        return null;
      }
      await _storePrayerTime(prefs, cacheKey, model);
      return model;
    }();
    _pendingPrayerTimeRequests[cacheKey] = request;
    try {
      return await request;
    } finally {
      _pendingPrayerTimeRequests.remove(cacheKey);
    }
  }

  String _coverageStorageKey(Map<String, dynamic> requestTemplate) {
    final contextKey = _prayerTimeCacheKey({...requestTemplate, 'date': ''});
    return '$_prayerTimeCoveragePrefix${base64Url.encode(utf8.encode(contextKey))}';
  }

  Future<int> _loadPrayerTimeCalendar(
    SharedPreferences prefs,
    Map<String, dynamic> requestBody,
  ) async {
    final template = Map<String, dynamic>.from(requestBody)..remove('date');
    final anchorDate = '${requestBody['date']}';
    final pendingKey = _prayerTimeCacheKey(requestBody);
    final pending = _pendingPrayerCalendarRequests[pendingKey];
    if (pending != null) return pending;

    final request = () async {
      final response = await apiClient.postData(
        AppConstants.PRAYER_TIME_CALENDAR,
        requestBody,
      );
      if (response.statusCode != 200 || response.body is! Map) return 0;

      final responseBody = Map<String, dynamic>.from(response.body as Map);
      if (responseBody['status'] != true || responseBody['data'] is! Map) {
        return 0;
      }

      final calendar = Map<String, dynamic>.from(responseBody['data'] as Map);
      final rawDays = calendar['days'];
      if (calendar['anchor_date'] != anchorDate ||
          calendar['past_days'] != _offlineCalendarPastDays ||
          calendar['future_days'] != _offlineCalendarFutureDays ||
          calendar['count'] !=
              _offlineCalendarPastDays + _offlineCalendarFutureDays + 1 ||
          rawDays is! List) {
        return 0;
      }

      var validCount = 0;
      var storedCount = 0;
      final seenDates = <String>{};

      for (final rawDay in rawDays) {
        if (rawDay is! Map) continue;
        final day = Map<String, dynamic>.from(rawDay);
        final dayDate = '${day['date']}';
        if (!seenDates.add(dayDate)) continue;

        final model = PrayerTimeModel.fromJson({
          'status': true,
          'message': responseBody['message'],
          'data': day,
        });
        if (!_isUsablePrayerTime(model, expectedDate: dayDate)) continue;

        final dayRequest = <String, dynamic>{...template, 'date': dayDate};
        final dayCacheKey = _prayerTimeCacheKey(dayRequest);
        final existing = await _cachedPrayerTime(prefs, dayCacheKey);
        await _storePrayerTime(prefs, dayCacheKey, model);
        validCount++;
        if (existing == null) storedCount++;
      }

      final expectedCount =
          _offlineCalendarPastDays + _offlineCalendarFutureDays + 1;
      if (validCount == expectedCount) {
        await prefs.setString(_coverageStorageKey(template), anchorDate);
      }

      return storedCount;
    }();

    _pendingPrayerCalendarRequests[pendingKey] = request;
    try {
      return await request;
    } finally {
      _pendingPrayerCalendarRequests.remove(pendingKey);
    }
  }

  /// Keeps an offline rolling calendar without delaying the Home screen.
  ///
  /// A single backend request returns J-7 through J+45. Entries are immutable
  /// for a date and calculation context; a failed request preserves every
  /// previously cached value.
  Future<int> warmPrayerTimeCache({DateTime? now}) async {
    if (_isWarmingPrayerTimeCache || _lastPrayerTimeRequestTemplate == null) {
      return 0;
    }

    _isWarmingPrayerTimeCache = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final template = Map<String, dynamic>.from(
        _lastPrayerTimeRequestTemplate!,
      );
      final today = DateUtils.dateOnly(now ?? DateTime.now());
      final coverageKey = _coverageStorageKey(template);
      if (prefs.getString(coverageKey) ==
          DateFormat('yyyy-MM-dd').format(today)) {
        return 0;
      }

      return _loadPrayerTimeCalendar(prefs, {
        ...template,
        'date': DateFormat('yyyy-MM-dd').format(today),
      });
    } finally {
      _isWarmingPrayerTimeCache = false;
    }
  }

  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  Future<PrayerTimeModel?> getPrayerTimeForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final manualMode =
        prefs.getBool(AppConstants.IS_MANUAL_PRAYER_TIME) ??
        isManualPrayerTime.value;
    return fetchPrayerTime(
      reload: false,
      isManualPrayerTme: manualMode,
      manualCity: prefs.getString(AppConstants.saveCityName),
      date: date,
      applyResult: false,
    );
  }

  Future<PrayerTimeModel?> fetchPrayerTime({
    bool reload = true,
    bool isManualPrayerTme = false,
    String? manualCity,
    DateTime? date,
    bool applyResult = true,
  }) async {
    try {
      await loadPrayerTimeSettings();
      if (reload) isprayerTimeLoading(true);

      SharedPreferences prefs = await SharedPreferences.getInstance();

      // A manually selected city that has saved coordinates (from the online
      // city search) is sent in "automatic" mode with the city coordinates,
      // so prayer times are computed on the fly for that exact location.
      final savedCity = prefs.getString(AppConstants.saveCityName);
      final cityLat = prefs.getDouble(AppConstants.manualCityLat);
      final cityLng = prefs.getDouble(AppConstants.manualCityLng);
      final bool useManualCityCoords =
          isManualPrayerTme &&
          manualCity != null &&
          manualCity == savedCity &&
          cityLat != null &&
          cityLng != null;

      // Geolocator is not implemented on every platform (e.g. Linux
      // desktop): fall back to the manually selected city in that case.
      Position? position;
      double? fallbackLatitude;
      double? fallbackLongitude;
      if (useManualCityCoords) {
        // No GPS fix needed, the city coordinates are used below.
      } else if (isGeolocatorSupported) {
        try {
          position = await _resolvePosition();
        } catch (_) {
          fallbackLatitude = prefs.getDouble(_automaticLatitudeKey);
          fallbackLongitude = prefs.getDouble(_automaticLongitudeKey);
          if (fallbackLatitude == null || fallbackLongitude == null) rethrow;
        }
      } else {
        isManualPrayerTme = true;
        manualCity ??= savedCity;
      }

      isManualPrayerTime.value = isManualPrayerTme;

      // Save the prayer time type to SharedPreferences
      await prefs.setBool(
        AppConstants.IS_MANUAL_PRAYER_TIME,
        isManualPrayerTme,
      );

      saveLocalStoreCity = prefs.getString(AppConstants.saveCityName);
      saveAddress.value = prefs.getString(AppConstants.saveCityName) ?? "";
      if (position != null) {
        await prefs.setDouble(_automaticLatitudeKey, position.latitude);
        await prefs.setDouble(_automaticLongitudeKey, position.longitude);
        try {
          final addressList = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          currentAddress.value = _placemarkCity(addressList.first);
          await prefs.setString(_automaticCityKey, currentAddress.value);
        } catch (_) {
          currentAddress.value =
              prefs.getString(_automaticCityKey) ?? currentAddress.value;
        }
        if (kDebugMode) {
          print("Address: ${currentAddress.value}");
        }
      } else if (!useManualCityCoords) {
        currentAddress.value =
            prefs.getString(_automaticCityKey) ?? currentAddress.value;
      }
      final requestedDate = date ?? DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd').format(requestedDate);

      var lat = useManualCityCoords
          ? cityLat
          : position?.latitude ?? fallbackLatitude ?? '';
      var lng = useManualCityCoords
          ? cityLng
          : position?.longitude ?? fallbackLongitude ?? '';
      var prayerMethod = _selectedCalculationMethod;
      var school = _selectedPrayerMadhab;
      var timezone = await FlutterTimezone.getLocalTimezone();

      final requestBody = <String, dynamic>{
        "type": (isManualPrayerTme && !useManualCityCoords)
            ? "manual"
            : "automatic",
        "date": formattedDate,
        "city": isManualPrayerTme ? manualCity ?? "" : currentAddress.value,
        "lat": "$lat",
        "lng": "$lng",
        "prayer_method": "$prayerMethod",
        "school": "$school",
        "timezone": timezone,
      };
      _lastPrayerTimeRequestTemplate = Map<String, dynamic>.from(requestBody)
        ..remove('date');
      final model = await _loadPrayerTime(prefs, requestBody);
      if (model != null && applyResult) {
        prayerTimeModel = model;
        if (_isToday(requestedDate)) {
          prayerNameAndTimes();
        }
        if (_isToday(requestedDate) && Get.isRegistered<ThemeController>()) {
          await Get.find<ThemeController>().updateDaylightTimes(
            prayerTimeModel?.data?.sunrise,
            prayerTimeModel?.data?.maghribStart,
          );
        }
        if (_isToday(requestedDate)) {
          unawaited(warmPrayerTimeCache());
        }
      }
      return model;
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching data: $e");
      }
      return null;
    } finally {
      if (reload) isprayerTimeLoading(false);
      update();
    }
  }

  // Get Prayer Owakt Function
  prayerNameAndTimes() {
    // Get Cuttent Time Variable =====>
    String currentTime = DateFormat.Hms().format(DateTime.now());
    // print("currentTime========> $currentTime");
    //18:15:56
    var finalCurrentTime = DateTime.parse('2000-01-01 $currentTime');
    var apiwaktTime = prayerTimeModel!.data!;
    if (finalCurrentTime.isBefore(
      DateTime.parse('2000-01-01 ${apiwaktTime.fajrStart}:00'),
    )) {
      currentWaqtName.value = "fajr".tr;
      currentWaktTime.value = apiwaktTime.fajrStart.toString();
    } else if (finalCurrentTime.isBefore(
      DateTime.parse('2000-01-01 ${apiwaktTime.sunrise}:00'),
    )) {
      currentWaqtName.value = "sunrise".tr;
      currentWaktTime.value = apiwaktTime.sunrise.toString();
    } else if (finalCurrentTime.isBefore(
      DateTime.parse('2000-01-01 ${apiwaktTime.zuhrStart}:00'),
    )) {
      currentWaqtName.value = DateTime.now().weekday == DateTime.friday
          ? "jumuah".tr
          : "dhuhr".tr;
      currentWaktTime.value = apiwaktTime.zuhrStart.toString();
    } else if (finalCurrentTime.isBefore(
      DateTime.parse('2000-01-01 ${apiwaktTime.asrStart}:00'),
    )) {
      currentWaqtName.value = "asr".tr;
      currentWaktTime.value = apiwaktTime.asrStart.toString();
    } else if (finalCurrentTime.isBefore(
      DateTime.parse('2000-01-01 ${apiwaktTime.maghribStart}:00'),
    )) {
      currentWaqtName.value = "magrib".tr;
      currentWaktTime.value = apiwaktTime.maghribStart.toString();
    } else if (finalCurrentTime.isBefore(
      DateTime.parse('2000-01-01 ${apiwaktTime.ishaStart}:00'),
    )) {
      currentWaqtName.value = "isha".tr;
      currentWaktTime.value = apiwaktTime.ishaStart.toString();
    } else if (finalCurrentTime.isAfter(
      DateTime.parse('2000-01-01 ${apiwaktTime.fajrStart}:00'),
    )) {
      currentWaqtName.value = "fajr".tr;
      currentWaktTime.value = apiwaktTime.fajrStart.toString();
    }
  }

  RxBool isCityListLoading = false.obs;
  CityesModel? cityModelData;

  // Online city search (Nominatim / OpenStreetMap)
  RxList<CitySuggestionModel> citySuggestions = <CitySuggestionModel>[].obs;
  Timer? _citySearchDebounce;

  /// Debounced entry point called from the search field.
  void onCitySearchChanged(String query) {
    search.value = query;
    _citySearchDebounce?.cancel();
    if (query.trim().length < 2) {
      citySuggestions.clear();
      return;
    }
    _citySearchDebounce = Timer(
      const Duration(milliseconds: 500),
      () => searchCitiesOnline(query.trim()),
    );
  }

  /// Search cities online via Nominatim (OpenStreetMap).
  Future<void> searchCitiesOnline(String query) async {
    try {
      isCityListLoading(true);
      final lang = Get.locale?.languageCode ?? 'en';
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=jsonv2&limit=8&addressdetails=1&accept-language=$lang',
      );
      final response = await http.get(
        uri,
        headers: const {'User-Agent': 'SalaTime/1.0 (contact@salatime.net)'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        citySuggestions.value = data
            .whereType<Map<String, dynamic>>()
            .map(CitySuggestionModel.fromJson)
            .where((city) => city.name.isNotEmpty)
            .toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error searching cities: $e");
      }
    } finally {
      isCityListLoading(false);
    }
  }

  Future<void> cityCategoryListData() async {
    try {
      isCityListLoading(true);
      update();

      final response = await apiClient.getData(AppConstants.CITY_LIST);

      if (response.statusCode == 200) {
        cityModelData = CityesModel.fromJson(response.body);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching data: $e");
      }
    } finally {
      isCityListLoading(false);
      update();
    }
  }

  // 12 or 24 hour format

  RxBool is24HourFormat = true.obs;

  Future<void> loadSwitchValue() async {
    final prefs = await SharedPreferences.getInstance();
    is24HourFormat.value = prefs.getBool('is24HrFormat') ?? true;
  }

  Future<void> updateSwitchValue(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is24HrFormat', value);
    is24HourFormat.value = value;
  }
}
