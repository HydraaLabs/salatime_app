import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Instrument the installed plugin without adding a production dependency.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:salatime/controller/prayer_time_adjustment.dart';

const _key = PrayerTimeAdjustmentController.storageKey;

class _ControlledStore extends InMemorySharedPreferencesStore {
  _ControlledStore(Map<String, Object> values)
    : super.withData({
        for (final entry in values.entries) 'flutter.${entry.key}': entry.value,
      });

  final readStarted = Completer<void>();
  final writeStarted = Completer<void>();
  Completer<void>? readGate;
  Completer<void>? writeGate;
  bool rejectWrites = false;
  bool throwOnRejection = false;
  String? rejectOnly;
  int reads = 0;
  final writes = <Object>[];

  @override
  Future<Map<String, Object>> getAll() async {
    reads++;
    if (!readStarted.isCompleted) readStarted.complete();
    await readGate?.future;
    return super.getAll();
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.$_key') {
      writes.add(value);
      if (!writeStarted.isCompleted) {
        writeStarted.complete();
        await writeGate?.future;
      }
      if (rejectWrites && (rejectOnly == null || value == rejectOnly)) {
        if (throwOnRejection) throw PlatformException(code: 'storage_failed');
        return false;
      }
    }
    return super.setValue(valueType, key, value);
  }

  void release() {
    if (readGate?.isCompleted == false) readGate!.complete();
    if (writeGate?.isCompleted == false) writeGate!.complete();
  }
}

Map<String, int> _values(PrayerTimeAdjustmentController controller) => {
  for (final key in PrayerTimeAdjustmentController.prayerKeys)
    key: ?controller.getAdjustmentMinutes(key),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _ControlledStore? store;

  _ControlledStore install([Object? saved]) {
    final values = <String, Object>{_key: ?saved};
    SharedPreferences.setMockInitialValues(values);
    final installed = _ControlledStore(values);
    SharedPreferencesStorePlatform.instance = installed;
    store = installed;
    return installed;
  }

  setUp(() {
    Get.testMode = true;
    install();
  });
  tearDown(() async {
    store?.release();
    // Drain onInit calls as well as writes before resetting the plugin cache.
    await PrayerTimeAdjustmentController().init();
    Get.reset();
  });

  test(
    'editing before initialization preserves existing saved offsets',
    () async {
      install(jsonEncode({'asr': -3}));
      final controller = PrayerTimeAdjustmentController();
      await controller.updateAdjustment('fajr', 7);
      expect(_values(controller), {'fajr': 7, 'asr': -3});
      final restarted = PrayerTimeAdjustmentController();
      await restarted.init();
      expect(_values(restarted), {'fajr': 7, 'asr': -3});
    },
  );

  test(
    'onInit, explicit init and an early edit share pending storage setup',
    () async {
      final platform = install(jsonEncode({'sunrise': -2}))
        ..readGate = Completer<void>();
      final controller = Get.put(PrayerTimeAdjustmentController());
      final pending = Future.wait([
        controller.init(),
        controller.initializeAdjustmentServices(),
        controller.updateAdjustment('fajr', 4),
      ]);
      await platform.readStarted.future;
      expect(platform.writes, isEmpty);
      platform.readGate!.complete();
      await pending;
      expect(platform.reads, 1);
      expect(_values(controller), {'fajr': 4, 'sunrise': -2});
    },
  );

  test(
    'partially invalid JSON preserves valid entries and the original storage',
    () async {
      final raw = jsonEncode({
        'fajr': 5,
        'sunrise': -2,
        'zuhr': 121,
        'asr': '7',
        'maghrib': null,
        'isha': 1.5,
        'sehri': -120,
        'iftar': 120,
        'unknown': 8,
      });
      final platform = install(raw);
      final controller = PrayerTimeAdjustmentController();
      await controller.init();
      expect(_values(controller), {
        'fajr': 5,
        'sunrise': -2,
        'sehri': -120,
        'iftar': 120,
      });
      expect((await SharedPreferences.getInstance()).get(_key), raw);
      expect(platform.writes, isEmpty);
    },
  );

  for (final raw in <Object>['not-json', '[1,2]', 'null', 42]) {
    test('invalid stored group ($raw) stays untouched when read', () async {
      final platform = install(raw);
      final controller = PrayerTimeAdjustmentController();
      await controller.init();
      expect(_values(controller), isEmpty);
      expect((await SharedPreferences.getInstance()).get(_key), raw);
      expect(platform.writes, isEmpty);
    });
  }

  test(
    'unknown keys and out-of-range offsets cannot change stored settings',
    () async {
      final raw = jsonEncode({'asr': 3});
      final platform = install(raw);
      final controller = PrayerTimeAdjustmentController();
      await controller.init();
      for (final key in ['', 'unknown', 'dhuhr']) {
        await expectLater(
          controller.updateAdjustment(key, 5),
          throwsArgumentError,
        );
        await expectLater(
          controller.resetPrayerTime(prayerKey: key),
          throwsArgumentError,
        );
      }
      for (final minutes in [-121, 121, 10000]) {
        await expectLater(
          controller.updateAdjustment('asr', minutes),
          throwsRangeError,
        );
      }
      expect(_values(controller), {'asr': 3});
      expect((await SharedPreferences.getInstance()).get(_key), raw);
      expect(platform.writes, isEmpty);
      expect(controller.isResetting.value, isFalse);
    },
  );

  test(
    'all supported keys accept both boundaries and zero removes an offset',
    () async {
      final controller = PrayerTimeAdjustmentController();
      for (final key in PrayerTimeAdjustmentController.prayerKeys) {
        await controller.updateAdjustment(key, -120);
        expect(controller.getAdjustmentMinutes(key), -120);
        await controller.updateAdjustment(key, 120);
        expect(controller.getAdjustmentMinutes(key), 120);
        await controller.updateAdjustment(key, 0);
        expect(controller.getAdjustmentMinutes(key), isNull);
        expect(controller.isAdjusted(key), isFalse);
      }
      expect(
        jsonDecode((await SharedPreferences.getInstance()).getString(_key)!),
        {},
      );
    },
  );

  test(
    'scheduler reload between blocked rapid edits cannot undo newer changes',
    () async {
      final platform = install(jsonEncode({'asr': -2}))
        ..writeGate = Completer<void>();
      final controller = PrayerTimeAdjustmentController();
      await controller.init();
      final pending = Future.wait([
        controller.updateAdjustment('fajr', 5),
        controller.init(),
        controller.updateAdjustment('asr', 8),
        controller.updateAdjustment('fajr', 0),
        controller.init(),
      ]);
      await platform.writeStarted.future;
      expect(_values(controller), {'fajr': 5, 'asr': -2});
      expect(platform.writes, hasLength(1));
      platform.writeGate!.complete();
      await pending;
      expect(platform.writes.map((raw) => jsonDecode(raw as String)).toList(), [
        {'asr': -2, 'fajr': 5},
        {'fajr': 5, 'asr': 8},
        {'asr': 8},
      ]);
      expect(_values(controller), {'asr': 8});
      final restarted = PrayerTimeAdjustmentController();
      await restarted.init();
      expect(_values(restarted), {'asr': 8});
    },
  );

  test(
    'two controller instances merge their edits through the shared queue',
    () async {
      final first = PrayerTimeAdjustmentController();
      final second = PrayerTimeAdjustmentController();
      await Future.wait([
        first.updateAdjustment('sunrise', -2),
        second.updateAdjustment('asr', 5),
      ]);
      await first.init();
      expect(_values(first), {'sunrise': -2, 'asr': 5});
      expect(_values(second), _values(first));
    },
  );

  for (final throws in [false, true]) {
    test(
      'failed write (throws=$throws) rolls back display and preference cache',
      () async {
        final original = jsonEncode({'fajr': 5, 'asr': -3});
        final platform = install(original)
          ..writeGate = Completer<void>()
          ..rejectWrites = true
          ..throwOnRejection = throws;
        final controller = PrayerTimeAdjustmentController();
        await controller.init();
        final check = expectLater(
          controller.updateAdjustment('fajr', 10),
          throws ? throwsA(isA<PlatformException>()) : throwsStateError,
        );
        await platform.writeStarted.future;
        expect(controller.getAdjustmentMinutes('fajr'), 10);
        platform.writeGate!.complete();
        await check;
        expect(_values(controller), {'fajr': 5, 'asr': -3});
        expect(
          (await SharedPreferences.getInstance()).getString(_key),
          original,
        );
        expect((await platform.getAll())['flutter.$_key'], original);

        platform.rejectWrites = false;
        await controller.updateAdjustment('isha', 6);
        expect(_values(controller), {'fajr': 5, 'asr': -3, 'isha': 6});
      },
    );
  }

  for (final original in <Object?>[null, 42]) {
    test(
      'failed first edit restores the original stored value ($original)',
      () async {
        install(original).rejectWrites = true;
        final controller = PrayerTimeAdjustmentController();
        await expectLater(
          controller.updateAdjustment('isha', 6),
          throwsStateError,
        );
        expect(_values(controller), isEmpty);
        expect((await SharedPreferences.getInstance()).get(_key), original);
      },
    );
  }

  test('an external restore during a failed write is preserved', () async {
    final attempted = jsonEncode({'fajr': 10});
    final platform = install(jsonEncode({'fajr': 5}))
      ..writeGate = Completer<void>()
      ..rejectWrites = true
      ..rejectOnly = attempted;
    final controller = PrayerTimeAdjustmentController();
    final check = expectLater(
      controller.updateAdjustment('fajr', 10),
      throwsStateError,
    );
    await platform.writeStarted.future;
    final prefs = await SharedPreferences.getInstance();
    final restored = jsonEncode({'asr': 4});
    await prefs.setString(_key, restored);
    platform.writeGate!.complete();
    await check;
    expect(_values(controller), {'asr': 4});
    expect(prefs.getString(_key), restored);
    expect((await platform.getAll())['flutter.$_key'], restored);
  });

  test(
    'reset one prayer preserves others and reset all survives a restart',
    () async {
      install(jsonEncode({'fajr': 5, 'asr': -3}));
      final controller = PrayerTimeAdjustmentController();
      await controller.resetPrayerTime(prayerKey: 'fajr');
      expect(_values(controller), {'asr': -3});
      await controller.resetPrayerTime();
      expect(_values(controller), isEmpty);
      expect(controller.isResetting.value, isFalse);
      final restarted = PrayerTimeAdjustmentController();
      await restarted.init();
      expect(_values(restarted), isEmpty);
    },
  );

  test(
    'a failed reset restores offsets and releases the resetting state',
    () async {
      final original = jsonEncode({'fajr': 5, 'asr': -3});
      final platform = install(original)
        ..writeGate = Completer<void>()
        ..rejectWrites = true;
      final controller = PrayerTimeAdjustmentController();
      await controller.init();
      final check = expectLater(controller.resetPrayerTime(), throwsStateError);
      await platform.writeStarted.future;
      expect(controller.isResetting.value, isTrue);
      expect(_values(controller), isEmpty);
      platform.writeGate!.complete();
      await check;
      expect(_values(controller), {'fajr': 5, 'asr': -3});
      expect(controller.isResetting.value, isFalse);
      expect((await SharedPreferences.getInstance()).getString(_key), original);
    },
  );

  test(
    'loading externally restored offsets notifies controller listeners',
    () async {
      final controller = PrayerTimeAdjustmentController();
      await controller.init();
      final observed = <Map<String, int>>[];
      final remove = controller.addListener(
        () => observed.add(_values(controller)),
      );
      addTearDown(remove);
      await (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode({'isha': 7}),
      );
      await controller.init();
      expect(observed.last, {'isha': 7});
      expect(controller.getAdjustedTimeString('isha', '23:58'), '00:05');
    },
  );
}
