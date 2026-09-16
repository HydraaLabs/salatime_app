import 'prayer_time_adjustment.dart';
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
import 'package:salatime/data/api/api_client.dart';
import 'package:salatime/data/model/response/city_model.dart';
import 'package:salatime/data/model/response/city_suggestion_model.dart';
import 'package:salatime/data/model/response/todays_prayer_time_model.dart';
import 'package:salatime/controller/theme_controller.dart';
import 'package:salatime/helper/location_helper.dart';
import 'package:salatime/helper/location_auto_update_service.dart';
import 'package:salatime/helper/local_prayer_calculator.dart';
import 'package:salatime/helper/automatic_prayer_method.dart';
import 'package:salatime/helper/ramadan_isha_settings.dart';
import 'package:salatime/helper/prayer_calculation_methods.dart';
import 'package:salatime/helper/salat_waqt_service.dart';
import 'package:salatime/service/preference_cloud_sync.dart';
import 'package:salatime/util/app_constants.dart';
import 'package:salatime/view/base/custom_snackbar.dart';

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
  void useCurrentPosition(Position position) => _lastPosition = position;
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
  DateTime? _remoteRetryAfter;

  String? get prayerTimeZone =>
      _lastPrayerTimeRequestTemplate?['timezone'] as String?;

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

  Future<void> _cacheAutomaticLocation(
    SharedPreferences prefs,
    Position position,
  ) async {
    await prefs.setDouble(_automaticLatitudeKey, position.latitude);
    await prefs.setDouble(_automaticLongitudeKey, position.longitude);
    try {
      final addressList = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final address = addressList.first;
      currentAddress.value = _placemarkCity(address);
      await prefs.setString(_automaticCityKey, currentAddress.value);
      await AutomaticPrayerMethod.saveCountry(
        prefs,
        manual: false,
        code: address.isoCountryCode,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      // A cached country is only reusable when its coordinates still match.
      currentAddress.value =
          prefs.getString(_automaticCityKey) ?? currentAddress.value;
    }
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

        await _cacheAutomaticLocation(prefs, position);

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

  List<Map<String, String>> get calculationMethod => [
    for (final method in PrayerCalculationMethods.all)
      {'id': method.id, 'value': method.fallbackName},
  ];

  bool get usesManualPrayerTimetable =>
      _lastPrayerTimeRequestTemplate?['type'] == 'manual';

  Future<void> _methodWrites = Future<void>.value();
  int _calculationRevision = 0;
  String? _selectedCalculationMethod;
  String? get selectedCalculationMethod => _selectedCalculationMethod;
  bool _automaticCalculationMethod = false;
  bool get automaticCalculationMethod => _automaticCalculationMethod;
  String? _calculationCountry;
  String? get calculationCountry => _calculationCountry;

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
    final write = _methodWrites.then((_) => _loadCalculationSettings());
    _methodWrites = write.catchError((Object _) {});
    await write;
  }

  Future<void> _loadCalculationSettings({bool? manualLocation}) async {
    final prefs = await SharedPreferences.getInstance();

    isManualPrayerTime.value =
        prefs.getBool(AppConstants.IS_MANUAL_PRAYER_TIME) ?? false;

    final savedMethod = prefs.getString('selectedCalculationMethod');
    final automatic =
        prefs.getBool(AutomaticPrayerMethod.enabledKey) ??
        (savedMethod == null);
    if (!prefs.containsKey(AutomaticPrayerMethod.enabledKey)) {
      if (!await prefs.setBool(AutomaticPrayerMethod.enabledKey, automatic)) {
        throw StateError('Automatic calculation preference could not be saved');
      }
    }
    _calculationCountry = AutomaticPrayerMethod.configuredCountry(
      prefs,
      manual: manualLocation,
    );
    final lastAutomatic = prefs.getString(AutomaticPrayerMethod.lastMethodKey);
    final manualMethod = PrayerCalculationMethods.contains(savedMethod)
        ? savedMethod!
        : PrayerCalculationMethods.defaultId;
    final method = automatic
        ? AutomaticPrayerMethod.methodForCountry(_calculationCountry) ??
              (PrayerCalculationMethods.contains(lastAutomatic)
                  ? lastAutomatic!
                  : manualMethod)
        : manualMethod;
    // The cloud field remains the user's manual choice. Moving between countries
    // must not overwrite a manual choice on another device.
    if (savedMethod != manualMethod) {
      await _persistCalculationMethod(manualMethod);
    }
    if (automatic && lastAutomatic != method) {
      await _persistCalculationMethod(method, automatic: true);
    }
    _automaticCalculationMethod = automatic;
    if (_selectedCalculationMethod != method) _calculationRevision++;
    _selectedCalculationMethod = method;

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

  /// Persist a validated method without starting device or network work.
  Future<void> setSelectedCalculationMethod(String? value) async {
    if (value == null) return;
    if (!PrayerCalculationMethods.contains(value)) {
      throw ArgumentError.value(value, 'value', 'Unknown calculation method');
    }
    final write = _methodWrites.then(
      (_) => _persistCalculationChoice(value, automatic: false),
    );
    _methodWrites = write.catchError((Object _) {});
    await write;
  }

  Future<void> _persistCalculationChoice(
    String value, {
    required bool automatic,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getBool(AutomaticPrayerMethod.enabledKey);
    try {
      if (!await prefs.setBool(AutomaticPrayerMethod.enabledKey, automatic)) {
        throw StateError('Automatic calculation preference could not be saved');
      }
      await _persistCalculationMethod(value, automatic: automatic);
    } catch (_) {
      try {
        if (previous == null) {
          await prefs.remove(AutomaticPrayerMethod.enabledKey);
        } else {
          await prefs.setBool(AutomaticPrayerMethod.enabledKey, previous);
        }
      } catch (_) {
        // Preserve the original persistence failure for the settings screen.
      }
      rethrow;
    }
    _automaticCalculationMethod = automatic;
    update();
  }

  Future<void> setAutomaticCalculationMethod(bool enabled) async {
    final write = _methodWrites.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      _calculationCountry = AutomaticPrayerMethod.configuredCountry(prefs);
      final saved =
          _selectedCalculationMethod ??
          prefs.getString('selectedCalculationMethod');
      final lastAutomatic = prefs.getString(
        AutomaticPrayerMethod.lastMethodKey,
      );
      final method =
          (enabled
              ? AutomaticPrayerMethod.methodForCountry(_calculationCountry) ??
                    (PrayerCalculationMethods.contains(lastAutomatic)
                        ? lastAutomatic
                        : null)
              : null) ??
          (PrayerCalculationMethods.contains(saved)
              ? saved!
              : PrayerCalculationMethods.defaultId);
      await _persistCalculationChoice(method, automatic: enabled);
    });
    _methodWrites = write.catchError((Object _) {});
    await write;
  }

  Future<void> selectAutomaticCalculationMethod(bool enabled) async {
    if (enabled) await _resolveConfiguredCountry();
    PreferenceCloudSync.instance.noteLocalChange();
    await setAutomaticCalculationMethod(enabled);
    PreferenceCloudSync.instance.noteLocalChange();
    _refreshCalculation();
  }

  /// An explicit opt-in can upgrade an existing saved city without asking for
  /// GPS or location permission. Passive refreshes never perform this lookup.
  Future<void> _resolveConfiguredCountry() async {
    final prefs = await SharedPreferences.getInstance();
    if (AutomaticPrayerMethod.configuredCountry(prefs) != null) return;
    final manual =
        !(prefs.getBool(LocationAutoUpdateService.enabledKey) ?? false) &&
        (prefs.getBool(AppConstants.isPrayerTme) ??
            prefs.getBool(AppConstants.IS_MANUAL_PRAYER_TIME) ??
            false);
    final latKey = manual ? AppConstants.manualCityLat : _automaticLatitudeKey;
    final lngKey = manual ? AppConstants.manualCityLng : _automaticLongitudeKey;
    final lat = prefs.getDouble(latKey);
    final lng = prefs.getDouble(lngKey);
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180) {
      return;
    }
    try {
      final addresses = await placemarkFromCoordinates(
        lat,
        lng,
      ).timeout(const Duration(seconds: 5));
      if (addresses.isEmpty ||
          prefs.getDouble(latKey) != lat ||
          prefs.getDouble(lngKey) != lng) {
        return;
      }
      await AutomaticPrayerMethod.saveCountry(
        prefs,
        manual: manual,
        code: addresses.first.isoCountryCode,
        latitude: lat,
        longitude: lng,
      );
    } catch (_) {
      // Offline/unavailable geocoding leaves the previous method in place.
    }
  }

  Future<void> _persistCalculationMethod(
    String value, {
    bool automatic = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = automatic
        ? AutomaticPrayerMethod.lastMethodKey
        : 'selectedCalculationMethod';
    final previous = prefs.getString(key);
    try {
      if (!await prefs.setString(key, value)) {
        throw StateError('Calculation method could not be saved');
      }
    } catch (_) {
      // SharedPreferences updates its memory cache before writing to the device.
      try {
        if (previous == null) {
          await prefs.remove(key);
        } else {
          await prefs.setString(key, previous);
        }
      } catch (_) {
        // Keep the original persistence error visible to the selection screen.
      }
      rethrow;
    }
    if (_selectedCalculationMethod != value) _calculationRevision++;
    _selectedCalculationMethod = value;
    update();
  }

  /// A settings tap waits only for local persistence. Recalculation uses the
  /// existing passive scheduler; cloud upload keeps its one-minute quiet period.
  Future<void> selectCalculationMethod(String id) async {
    if (!PrayerCalculationMethods.contains(id)) {
      throw ArgumentError.value(id, 'id', 'Unknown calculation method');
    }
    PreferenceCloudSync.instance.noteLocalChange();
    await setSelectedCalculationMethod(id);
    PreferenceCloudSync.instance.noteLocalChange();
    _refreshCalculation();
  }

  void _refreshCalculation() {
    unawaited(
      SalatWaqtService.requestRefresh().catchError((Object error) {
        // The scheduler persists its failure status for the alarm diagnostics.
        debugPrint('Calculation method refresh failed: $error');
      }),
    );
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
      automatic ? requestBody['prayer_method'] : null,
      automatic ? requestBody['school'] : null,
      requestBody['timezone'],
    ]);
  }

  String _prayerTimeStorageKey(String cacheKey) {
    return '$_prayerTimeCachePrefix${base64Url.encode(utf8.encode(cacheKey))}';
  }

  Iterable<String> _legacyManualCacheKeys(
    SharedPreferences prefs,
    String cacheKey,
  ) sync* {
    final requested = jsonDecode(cacheKey) as List;
    if (requested[0] != 'manual' ||
        requested[5] != null ||
        requested[6] != null) {
      return;
    }
    // Older releases keyed city timetables by method and school even though
    // neither changes published times. Match the same date/city/zone only.
    final candidates = <String>{
      ...?prefs.getStringList(_prayerTimeCacheIndexKey)?.reversed,
      ...prefs.getKeys().where((key) => key.startsWith(_prayerTimeCachePrefix)),
    };
    for (final storageKey in candidates) {
      if (!storageKey.startsWith(_prayerTimeCachePrefix)) continue;
      try {
        final oldKey = utf8.decode(
          base64Url.decode(storageKey.substring(_prayerTimeCachePrefix.length)),
        );
        if (oldKey == cacheKey) continue;
        final parts = jsonDecode(oldKey);
        if (parts is! List || parts.length != 8 || parts[0] != 'manual') {
          continue;
        }
        parts[5] = null;
        parts[6] = null;
        if (jsonEncode(parts) == cacheKey) yield oldKey;
      } catch (_) {
        // Ignore unrelated or malformed legacy cache entries.
      }
    }
  }

  Future<PrayerTimeModel?> _cachedPrayerTime(
    SharedPreferences prefs,
    String cacheKey,
  ) async {
    final memoryValue = _prayerTimeCache[cacheKey];
    if (memoryValue != null) return memoryValue;

    final storageKey = _prayerTimeStorageKey(cacheKey);
    final storedValue = prefs.getString(storageKey);
    if (storedValue == null) {
      for (final oldKey in _legacyManualCacheKeys(prefs, cacheKey)) {
        final legacy = await _cachedPrayerTime(prefs, oldKey);
        if (legacy != null) {
          _rememberPrayerTime(cacheKey, legacy);
          return legacy;
        }
      }
      return null;
    }

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
    final validClock = RegExp(r'^(?:[01]?\d|2[0-3]):[0-5]\d$');
    return [
      data.fajrStart,
      data.sunrise,
      data.zuhrStart,
      data.asrStart,
      data.maghribStart,
      data.ishaStart,
    ].every(
      (value) => value != null && value != '0:00' && validClock.hasMatch(value),
    );
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
    Map<String, dynamic> requestBody, {
    bool allowNetwork = true,
  }) async {
    if (requestBody['type'] == 'automatic') {
      return LocalPrayerCalculator.calculate(
        RamadanIshaSettings.enrichRequest(requestBody, prefs),
      );
    }
    final cacheKey = _prayerTimeCacheKey(requestBody);
    final cached = await _cachedPrayerTime(prefs, cacheKey);
    if (cached != null) return cached;
    if (!allowNetwork ||
        (_remoteRetryAfter?.isAfter(DateTime.now()) ?? false)) {
      return null;
    }

    final pending = _pendingPrayerTimeRequests[cacheKey];
    if (pending != null) return pending;

    final request = () async {
      try {
        await _loadPrayerTimeCalendar(prefs, requestBody);
        final calendarValue = await _cachedPrayerTime(prefs, cacheKey);
        if (calendarValue != null) return calendarValue;
        final response = await apiClient
            .postData(AppConstants.TODAYS_PRAYER_TIME, requestBody)
            .timeout(const Duration(seconds: 4));
        if (response.statusCode == 200 &&
            response.body is Map<String, dynamic>) {
          final model = PrayerTimeModel.fromJson(response.body);
          if (_isUsablePrayerTime(
            model,
            expectedDate: '${requestBody['date']}',
          )) {
            await _storePrayerTime(prefs, cacheKey, model);
            return model;
          }
        }
      } catch (error) {
        debugPrint('Prayer calendar unavailable: $error');
      }
      _remoteRetryAfter = DateTime.now().add(const Duration(minutes: 2));
      // A manually maintained timetable must not be replaced by invented times.
      return null;
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
      final response = await apiClient
          .postData(AppConstants.PRAYER_TIME_CALENDAR, requestBody)
          .timeout(const Duration(seconds: 5));
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
    } catch (error) {
      debugPrint('Prayer calendar sync failed: $error');
      return 0;
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
    if (_isWarmingPrayerTimeCache ||
        _lastPrayerTimeRequestTemplate == null ||
        _lastPrayerTimeRequestTemplate?['type'] == 'automatic' ||
        (_remoteRetryAfter?.isAfter(DateTime.now()) ?? false)) {
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

      return await _loadPrayerTimeCalendar(prefs, {
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

  Future<Map<String, dynamic>?> _restoreConfiguredTemplate(
    SharedPreferences prefs,
  ) async {
    final useAutomaticLocation =
        prefs.getBool(LocationAutoUpdateService.enabledKey) ?? false;
    final manual =
        !useAutomaticLocation &&
        (prefs.getBool(AppConstants.isPrayerTme) ??
            prefs.getBool(AppConstants.IS_MANUAL_PRAYER_TIME) ??
            false);
    final city = prefs.getString(AppConstants.saveCityName);
    final lat = manual
        ? prefs.getDouble(AppConstants.manualCityLat)
        : _lastPosition?.latitude ?? prefs.getDouble(_automaticLatitudeKey);
    final lng = manual
        ? prefs.getDouble(AppConstants.manualCityLng)
        : _lastPosition?.longitude ?? prefs.getDouble(_automaticLongitudeKey);
    final coordinates =
        lat != null &&
        lng != null &&
        lat.isFinite &&
        lng.isFinite &&
        lat.abs() <= 90 &&
        lng.abs() <= 180;
    if (!coordinates && (!manual || city == null || city.trim().isEmpty)) {
      return null;
    }
    final zone = await FlutterTimezone.getLocalTimezone();
    isManualPrayerTime.value = manual;
    if (manual) {
      saveAddress.value = city ?? '';
    } else {
      currentAddress.value =
          prefs.getString(_automaticCityKey) ?? currentAddress.value;
    }
    return {
      'type': coordinates ? 'automatic' : 'manual',
      'city': manual ? city : currentAddress.value,
      'lat': coordinates ? '$lat' : '',
      'lng': coordinates ? '$lng' : '',
      'prayer_method': _selectedCalculationMethod,
      'school': _selectedPrayerMadhab,
      'timezone': zone,
    };
  }

  /// Reload cloud preferences using only the already configured city/template.
  /// Never opens a location/notification permission dialog or requests GPS.
  Future<void> refreshConfiguredPrayerTime() async {
    await loadPrayerTimeSettings();
    final revision = _calculationRevision;
    final prefs = await SharedPreferences.getInstance();
    final template =
        _lastPrayerTimeRequestTemplate ??
        await _restoreConfiguredTemplate(prefs);
    if (template == null || revision != _calculationRevision) return;
    // A city's published timetable is independent of calculation preferences.
    // Preserve its cache identity when saving a method for future local use.
    _lastPrayerTimeRequestTemplate = template['type'] == 'manual'
        ? template
        : {
            ...template,
            'prayer_method': _selectedCalculationMethod,
            'school': _selectedPrayerMadhab,
          };
    final model = await getPrayerTimeForDate(
      DateTime.now(),
      allowNetwork: false,
    );
    if (model != null && revision == _calculationRevision) {
      prayerTimeModel = model;
      prayerNameAndTimes();
      if (Get.isRegistered<ThemeController>()) {
        await Get.find<ThemeController>().updateDaylightTimes(
          model.data?.sunrise,
          model.data?.maghribStart,
        );
      }
      update();
    }
  }

  Future<PrayerTimeModel?> getPrayerTimeForDate(
    DateTime date, {
    bool allowNetwork = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final template = _lastPrayerTimeRequestTemplate;
    if (template != null) {
      return _loadPrayerTime(prefs, {
        ...template,
        'date': DateFormat('yyyy-MM-dd').format(date),
      }, allowNetwork: allowNetwork);
    }
    if (!allowNetwork) return null;
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
      var revision = _calculationRevision;
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
      if (isManualPrayerTme) {
        // Neither a saved city nor a manually maintained timetable needs GPS.
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
        await _cacheAutomaticLocation(prefs, position);
        if (kDebugMode) {
          print("Address: ${currentAddress.value}");
        }
      } else if (!useManualCityCoords) {
        currentAddress.value =
            prefs.getString(_automaticCityKey) ?? currentAddress.value;
      }
      if (revision != _calculationRevision) return null;
      final resolve = _methodWrites.then(
        (_) => _loadCalculationSettings(manualLocation: isManualPrayerTme),
      );
      _methodWrites = resolve.catchError((Object _) {});
      await resolve;
      revision = _calculationRevision;
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
      if (revision == _calculationRevision) {
        _lastPrayerTimeRequestTemplate = Map<String, dynamic>.from(requestBody)
          ..remove('date');
      }
      final model = await _loadPrayerTime(prefs, requestBody);
      if (model != null && applyResult && revision == _calculationRevision) {
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
    var apiwaktTime = PrayerTimeAdjustmentController.adjustedDay(
      prayerTimeModel!.data,
    )!;
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
