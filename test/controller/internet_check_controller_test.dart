import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:zabi/controller/internet_check_controller.dart';

class _Connectivity implements Connectivity {
  final events = StreamController<List<ConnectivityResult>>.broadcast();
  final initial = Completer<List<ConnectivityResult>>();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() => initial.future;
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => events.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  test('uses every reported network transport', () {
    expect(InternetController.hasConnection([]), isFalse);
    expect(
      InternetController.hasConnection([ConnectivityResult.none]),
      isFalse,
    );
    expect(
      InternetController.hasConnection([
        ConnectivityResult.none,
        ConnectivityResult.wifi,
      ]),
      isTrue,
    );
  });

  test(
    'new network event wins over a slow initial check and closes listener',
    () async {
      final connectivity = _Connectivity();
      final controller = Get.put(
        InternetController(connectivity: connectivity),
      );
      expect(connectivity.events.hasListener, isTrue);
      connectivity.events.add([ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.hasInternet.value, isFalse);
      connectivity.initial.complete([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.hasInternet.value, isFalse);
      await Get.delete<InternetController>();
      expect(connectivity.events.hasListener, isFalse);
      await connectivity.events.close();
    },
  );

  test(
    'unavailable native connectivity does not cause an unhandled error',
    () async {
      final connectivity = _Connectivity();
      final controller = Get.put(
        InternetController(connectivity: connectivity),
      );
      connectivity.initial.completeError(
        StateError('native check unavailable'),
      );
      connectivity.events.addError(StateError('native stream unavailable'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.hasInternet.value, isTrue);
      await Get.delete<InternetController>();
      await connectivity.events.close();
    },
  );
}
