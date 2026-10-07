import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/home_layout_controller.dart';
import 'package:salatime/controller/nearby_mosque_controller.dart';
import 'package:salatime/view/screens/nearby_mosque/nearby_mosque_screen.dart';

class _Mosques extends NearbyMosqueController {
  _Mosques() {
    isLocationDenied.value = true;
  }

  int locationCalls = 0;
  final pendingLocation = Completer<void>();

  @override
  Future<void> getLocation() {
    locationCalls++;
    return pendingLocation.future;
  }
}

void main() {
  tearDown(Get.reset);

  testWidgets(
    'Mosques initializes GPS once through parent/theme and controller rebuilds',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      Get.put(HomeLayoutController(sharedPreferences: prefs));
      final controller =
          Get.put<NearbyMosqueController>(_Mosques()) as _Mosques;
      Widget app(Brightness brightness) => GetMaterialApp(
        theme: ThemeData(brightness: brightness),
        home: const NearbyMosque(appBackButton: false),
      );
      await tester.pumpWidget(app(Brightness.light));
      await tester.pump();
      expect(controller.locationCalls, 1);

      await tester.pumpWidget(app(Brightness.dark));
      await tester.pump();
      controller.update();
      await tester.pump();
      await tester.pumpWidget(app(Brightness.light));
      await tester.pump();
      expect(controller.locationCalls, 1);

      controller.pendingLocation.complete();
      await tester.pump();
      controller.update();
      await tester.pump();
      expect(controller.locationCalls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
