import 'package:flutter_test/flutter_test.dart';
import 'package:salatime/helper/salat_waqt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a failed alarm refresh after a settings change never escapes',
    () async {
      // A device whose alarms could not all be scheduled (SALAMTIME-J).
      SharedPreferences.setMockInitialValues({
        SalatWaqtService.failedKey: true,
      });
      await expectLater(
        SalatWaqtService.initializeSalatWaqt(),
        throwsA(isA<StateError>()),
      );
      await expectLater(SalatWaqtService.refreshAfterChange(), completes);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SalatWaqtService.failedKey), isTrue);
    },
  );
}
