import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:salatime/helper/prayer_refresh_coordinator.dart';

void main() {
  test('a burst shares one passive refresh and one completion', () async {
    var calls = 0;
    final coordinator = PrayerRefreshCoordinator(
      delay: const Duration(milliseconds: 5),
      refresh: ({required requestPermissions, required isCurrent}) async {
        calls++;
        expect(requestPermissions, false);
        expect(isCurrent(), true);
      },
    );
    final futures = List.generate(15, (_) => coordinator.request());
    expect(futures.every((future) => identical(future, futures.first)), true);
    expect(calls, 0);
    await Future.wait(futures);
    expect(calls, 1);
  });

  test(
    'edits during an active refresh invalidate it and wait for latest revision',
    () async {
      final firstRelease = Completer<void>();
      final secondStarted = Completer<void>();
      final secondRelease = Completer<void>();
      var calls = 0;
      late bool Function() firstIsCurrent;
      final coordinator = PrayerRefreshCoordinator(
        refresh: ({required requestPermissions, required isCurrent}) async {
          calls++;
          if (calls == 1) {
            firstIsCurrent = isCurrent;
            await firstRelease.future;
          } else {
            secondStarted.complete();
            await secondRelease.future;
          }
        },
      );
      final initial = coordinator.request(immediate: true);
      expect(firstIsCurrent(), true);
      final edits = List.generate(8, (_) => coordinator.request());
      expect(firstIsCurrent(), false);
      var completed = false;
      final completion = Future.wait([
        initial,
        ...edits,
      ]).then((_) => completed = true);
      firstRelease.complete();
      await secondStarted.future;
      expect(calls, 2);
      expect(completed, false);
      secondRelease.complete();
      await completion;
      expect(completed, true);
    },
  );

  test(
    'immediate refresh flushes debounce and permission requests are not inherited by passive reruns',
    () async {
      final release = Completer<void>();
      final permissionCalls = <bool>[];
      final coordinator = PrayerRefreshCoordinator(
        refresh: ({required requestPermissions, required isCurrent}) async {
          permissionCalls.add(requestPermissions);
          if (permissionCalls.length == 1) await release.future;
        },
      );
      final delayed = coordinator.request();
      final immediate = coordinator.request(
        immediate: true,
        requestPermissions: true,
      );
      expect(permissionCalls, [true]);
      final passive = coordinator.request();
      release.complete();
      await Future.wait([delayed, immediate, passive]);
      expect(permissionCalls, [true, false]);
    },
  );

  test(
    'terminal errors reach callers and a later request can recover',
    () async {
      var fail = true;
      final coordinator = PrayerRefreshCoordinator(
        refresh: ({required requestPermissions, required isCurrent}) async {
          if (fail) throw StateError('schedule failure');
        },
      );
      await expectLater(coordinator.request(immediate: true), throwsStateError);
      fail = false;
      await coordinator.request(immediate: true);
    },
  );

  test(
    'superseded failure does not reject a successful latest revision',
    () async {
      final release = Completer<void>();
      var calls = 0;
      final coordinator = PrayerRefreshCoordinator(
        refresh: ({required requestPermissions, required isCurrent}) async {
          if (++calls == 1) {
            await release.future;
            throw StateError('old revision failed');
          }
        },
      );
      final first = coordinator.request(immediate: true);
      final latest = coordinator.request();
      release.complete();
      await Future.wait([first, latest]);
      expect(calls, 2);
    },
  );
}
