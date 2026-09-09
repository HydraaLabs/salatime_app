import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:zabi/controller/package_prayer_time_controller.dart';
import 'package:zabi/view/base/custom_snackbar.dart';

class InternetController extends GetxController {
  InternetController({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final hasInternet = true.obs;
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  int _eventVersion = 0;

  static bool hasConnection(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  @override
  void onInit() {
    super.onInit();
    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        _eventVersion++;
        _applyConnection(results, notify: true);
      },
      onError: (Object error) {
        debugPrint('Connectivity listener unavailable: $error');
      },
    );
    unawaited(checkConnection());
  }

  void _applyConnection(
    List<ConnectivityResult> results, {
    bool notify = false,
  }) {
    if (isClosed) return;
    final connected = hasConnection(results);
    final changed = hasInternet.value != connected;
    hasInternet.value = connected;
    if (!changed) return;

    // Native events can arrive before the navigator has been mounted.
    if (notify && Get.overlayContext != null) {
      showCustomSnackBar(
        connected ? 'online_back_message'.tr : 'offline_message'.tr,
        isError: !connected,
      );
    }
    if (connected && Get.isRegistered<PrayerTimeController>()) {
      unawaited(Get.find<PrayerTimeController>().warmPrayerTimeCache());
    }
  }

  Future<void> checkConnection() async {
    final version = _eventVersion;
    try {
      final results = await _connectivity.checkConnectivity();
      // A slow initial check must not overwrite a more recent stream event.
      if (version == _eventVersion) _applyConnection(results);
    } catch (error) {
      debugPrint('Connectivity check unavailable: $error');
    }
  }

  @override
  void onClose() {
    unawaited(_subscription?.cancel());
    super.onClose();
  }
}
