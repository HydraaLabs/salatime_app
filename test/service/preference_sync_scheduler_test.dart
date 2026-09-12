import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zabi/service/cloud/preference_sync_scheduler.dart';

void main() {
  test('every edit resets the full minute while polls cannot bypass it', () {
    fakeAsync((clock) {
      var uploads = 0;
      var saves = 0;
      final scheduler = PreferenceSyncScheduler(
        now: clock.getClock(DateTime(2026)).now,
        synchronize: () async {
          uploads++;
        },
        checkpoint: () async {
          saves++;
        },
      );
      scheduler.setEnabled(true);
      scheduler.noteChange();
      clock.elapse(const Duration(milliseconds: 500));
      expect(saves, 1);
      clock.elapse(const Duration(seconds: 29));
      scheduler.noteChange(); // A later edit extends the deadline to 89.5s.
      clock.elapse(const Duration(seconds: 59));
      expect(uploads, 0);
      expect(saves, 2);
      clock.elapse(const Duration(seconds: 1));
      expect(uploads, 1);
      scheduler.dispose();
    });
  });

  test(
    'pause saves locally and resume honors the remaining quiet interval',
    () {
      fakeAsync((clock) {
        var uploads = 0;
        var saves = 0;
        final scheduler = PreferenceSyncScheduler(
          now: clock.getClock(DateTime(2026)).now,
          synchronize: () async {
            uploads++;
          },
          checkpoint: () async {
            saves++;
          },
        );
        scheduler.setEnabled(true);
        scheduler.noteChange();
        clock.elapse(const Duration(seconds: 10));
        scheduler.setForeground(false);
        clock.flushMicrotasks();
        expect(saves, 2);
        clock.elapse(const Duration(seconds: 10));
        scheduler.setForeground(true);
        unawaited(scheduler.requestAutomatic());
        clock.elapse(const Duration(seconds: 39));
        expect(uploads, 0);
        clock.elapse(const Duration(seconds: 1));
        expect(uploads, 1);
        scheduler.noteChange();
        scheduler.setForeground(false);
        clock.elapse(const Duration(minutes: 2));
        expect(uploads, 1);
        scheduler.setForeground(true);
        unawaited(scheduler.requestAutomatic());
        clock.flushMicrotasks();
        expect(uploads, 2);
        scheduler.dispose();
      });
    },
  );

  test('rapid edits produce one local checkpoint and one deferred upload', () {
    fakeAsync((clock) {
      var uploads = 0;
      var saves = 0;
      final scheduler = PreferenceSyncScheduler(
        now: clock.getClock(DateTime(2026)).now,
        synchronize: () async {
          uploads++;
        },
        checkpoint: () async {
          saves++;
        },
      );
      scheduler.setEnabled(true);
      for (var i = 0; i < 20; i++) {
        scheduler.noteChange();
        clock.elapse(const Duration(milliseconds: 100));
      }
      expect(saves, 0);
      expect(uploads, 0);
      clock.elapse(const Duration(milliseconds: 400));
      expect(saves, 1);
      clock.elapse(const Duration(seconds: 60));
      expect(uploads, 1);
      scheduler.dispose();
    });
  });

  test('manual sync bypasses debounce and active requests are coalesced', () {
    fakeAsync((clock) {
      var uploads = 0;
      final gate = Completer<void>();
      final scheduler = PreferenceSyncScheduler(
        now: clock.getClock(DateTime(2026)).now,
        synchronize: () {
          uploads++;
          return uploads == 1 ? gate.future : Future.value();
        },
        checkpoint: () async {},
      );
      scheduler.setEnabled(true);
      scheduler.noteChange();
      unawaited(scheduler.requestNow());
      expect(uploads, 1);
      for (var i = 0; i < 10; i++) {
        unawaited(scheduler.requestNow());
      }
      expect(uploads, 1);
      gate.complete();
      clock.flushMicrotasks();
      expect(uploads, 2); // At most one follow-up, not ten queued runs.
      scheduler.dispose();
    });
  });

  test('new edits during a request delay any coalesced follow-up', () {
    fakeAsync((clock) {
      var uploads = 0;
      final gate = Completer<void>();
      final scheduler = PreferenceSyncScheduler(
        now: clock.getClock(DateTime(2026)).now,
        synchronize: () {
          uploads++;
          return uploads == 1 ? gate.future : Future.value();
        },
        checkpoint: () async {},
      );
      scheduler.setEnabled(true);
      unawaited(scheduler.requestAutomatic());
      clock.elapse(
        const Duration(seconds: 30),
      ); // Poll queues only one follow-up.
      scheduler.noteChange();
      gate.complete();
      clock.flushMicrotasks();
      expect(uploads, 1);
      clock.elapse(const Duration(seconds: 59));
      expect(uploads, 1);
      clock.elapse(const Duration(seconds: 1));
      expect(uploads, 2);
      scheduler.dispose();
    });
  });

  test(
    'logout and disposal cancel pending uploads and retry after errors remains possible',
    () {
      fakeAsync((clock) {
        var uploads = 0;
        var errors = 0;
        final scheduler = PreferenceSyncScheduler(
          now: clock.getClock(DateTime(2026)).now,
          synchronize: () {
            uploads++;
            if (uploads == 1) throw StateError('offline');
            return Future.value();
          },
          checkpoint: () async {},
          onError: (_) {
            errors++;
          },
        );
        scheduler.setEnabled(true);
        scheduler.noteChange();
        scheduler.setEnabled(false);
        clock.elapse(const Duration(minutes: 2));
        expect(uploads, 0);
        scheduler.setEnabled(true);
        unawaited(scheduler.requestNow());
        clock.flushMicrotasks();
        expect(errors, 1);
        unawaited(scheduler.requestNow());
        clock.flushMicrotasks();
        expect(uploads, 2);
        scheduler.noteChange();
        scheduler.dispose();
        clock.elapse(const Duration(minutes: 2));
        expect(uploads, 2);
      });
    },
  );
}
