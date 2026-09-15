import 'dart:async';
import 'dart:convert';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salatime/helper/athkar_catalog.dart';
import 'package:salatime/service/mobile_auth_service.dart';
import 'package:salatime/service/reading/reading_progress_service.dart';

class MemoryStore implements ReadingProgressStore {
  final values = <String, Map<String, dynamic>>{};
  int writes = 0;
  Completer<void>? gate;
  bool fail = false;
  int? failAt;
  @override
  Future<Map<String, dynamic>?> read(String key) async => values[key];
  @override
  Future<void> write(String key, Map<String, dynamic> document) async {
    writes++;
    await gate?.future;
    if (fail || writes == failAt) throw StateError('storage unavailable');
    values[key] = jsonDecode(jsonEncode(document)) as Map<String, dynamic>;
  }
}

class FakeAuth extends MobileAuthService {
  FakeAuth({String origin = 'https://example.test'})
    : super(apiBaseUrl: origin);
  String? token;
  int cleared = 0;
  @override
  Future<void> initialize() async {}
  @override
  Future<String?> accessToken() async => token;
  void signIn(String id, [String? bearer]) {
    token = bearer ?? 'token-$id';
    user.value = MobileUser(
      id: id,
      name: id,
      email: '$id@example.test',
      emailVerified: false,
      hasPassword: true,
    );
  }

  @override
  Future<void> clearSession({String? expectedToken}) async {
    if (expectedToken != null && token != expectedToken) return;
    cleared++;
    token = null;
    user.value = null;
  }
}

class FakeRemote implements ReadingProgressRemote {
  final batches = <List<ReadingProgressOperation>>[];
  final pulls = <int>[];
  final tokens = <String>[];
  final records = <String, Map<String, dynamic>>{};
  final received = <String>{};
  int revision = 0;
  bool fail = false;
  Future<ReadingProgressAcknowledgement> Function(
    List<ReadingProgressOperation>,
  )?
  onPush;
  Future<ReadingProgressPage> Function(int)? onPull;
  @override
  Future<ReadingProgressAcknowledgement> push(
    String token,
    List<ReadingProgressOperation> operations,
  ) async {
    tokens.add(token);
    batches.add(List.of(operations));
    if (fail) throw const ReadingProgressRemoteException(503);
    if (onPush != null) return onPush!(operations);
    final affected = <String>{};
    for (final operation in operations) {
      affected.add(operation.entry.key);
      if (received.add(operation.id)) {
        records[operation.entry.key] = {
          ...operation.entry.toJson(),
          'count':
              operation.merge &&
                  (records[operation.entry.key]?['count'] as int? ?? 0) >
                      operation.entry.count
              ? records[operation.entry.key]!['count']
              : operation.entry.count,
          'revision': ++revision,
        };
      }
    }
    return ReadingProgressAcknowledgement(
      acknowledged: operations.map((op) => op.id).toList(),
      entries: affected.map((key) => records[key]!).toList(),
    );
  }

  @override
  Future<ReadingProgressPage> pull(String token, int after) async {
    tokens.add(token);
    pulls.add(after);
    if (fail) throw const ReadingProgressRemoteException(503);
    if (onPull != null) return onPull!(after);
    final page =
        records.values
            .where((entry) => (entry['revision'] as int) > after)
            .toList()
          ..sort(
            (a, b) => (a['revision'] as int).compareTo(b['revision'] as int),
          );
    return ReadingProgressPage(
      entries: page,
      cursor: page.isEmpty ? after : page.last['revision'] as int,
      hasMore: false,
    );
  }
}

final catalog = AthkarCatalog(
  categories: [
    AthkarCategory(
      id: 'morning',
      titleArabic: '',
      entries: [
        const AthkarEntry(
          id: 'morning:1',
          sourceId: 1,
          categoryId: 'morning',
          body: 'ذكر',
          repetition: 'ثلاث مرات',
        ),
        const AthkarEntry(
          id: 'morning:2',
          sourceId: 2,
          categoryId: 'morning',
          body: 'دعاء',
        ),
      ],
    ),
  ],
);
const quran = ReadingProgressKind.quran;
const athkar = ReadingProgressKind.athkar;
Future<void> settle() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ReadingProgressService make({
  FakeAuth? auth,
  MemoryStore? store,
  FakeRemote? remote,
  DateTime Function()? now,
  bool automatic = false,
}) => ReadingProgressService(
  auth: auth ?? FakeAuth(),
  store: store ?? MemoryStore(),
  remote: remote ?? FakeRemote(),
  catalog: catalog,
  now: now ?? () => DateTime(2026, 9, 13, 14),
  observeLifecycle: false,
  automaticSync: automatic,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'login merges guest Athkar and Quran history without duplicates or cloud loss',
    () async {
      final auth = FakeAuth();
      final remote = FakeRemote();
      final service = make(auth: auth, remote: remote);
      await service.initialize();
      await service.setCount(athkar, 'morning:1', 2);
      await service.setCount(athkar, 'morning:2', 1, day: '2026-09-12');
      await service.setCount(quran, '1:1', 1);
      remote.records['athkar|2026-09-13|morning:1'] = {
        'kind': 'athkar',
        'itemKey': 'morning:1',
        'day': '2026-09-13',
        'count': 3,
        'revision': 1,
      };
      remote.records['quran|2026-09-13|1:2'] = {
        'kind': 'quran',
        'itemKey': '1:2',
        'day': '2026-09-13',
        'count': 1,
        'revision': 2,
      };
      remote.revision = 2;
      auth.signIn('A');
      await settle();
      expect(service.todayCount(athkar, 'morning:1'), 2);
      expect(service.stats.todayQuranVerses, 1);
      await service.syncNow();
      expect(service.todayCount(athkar, 'morning:1'), 3);
      expect(service.stats.todayQuranVerses, 2);
      expect(service.stats.lifetimeAthkarCompleted, 2);
      expect(service.stats.activeDays, 2);
      expect(remote.batches.single.every((op) => op.merge), isTrue);
      // An explicit later uncheck must remain possible and not be resurrected.
      await service.setCount(quran, '1:1', 0);
      await service.syncNow();
      await auth.clearSession();
      await settle();
      auth.signIn('A');
      await settle();
      await service.syncNow();
      expect(service.todayCount(quran, '1:1'), 0);
      expect(service.pendingOperationCount, 0);
      service.dispose();
    },
  );

  test(
    'existing signed-in installations recover guest cache offline after upgrade',
    () async {
      final store = MemoryStore();
      final guest = make(store: store);
      await guest.initialize();
      await guest.setCount(athkar, 'morning:1', 3);
      guest.dispose();
      final auth = FakeAuth()..signIn('A');
      final remote = FakeRemote()..fail = true;
      final service = make(auth: auth, store: store, remote: remote);
      await service.initialize();
      expect(service.stats.todayAthkarCompleted, 1);
      await expectLater(
        service.syncNow(),
        throwsA(isA<ReadingProgressRemoteException>()),
      );
      final id = remote.batches.single.single.id;
      service.dispose();
      final restarted = make(auth: auth, store: store, remote: remote);
      await restarted.initialize();
      expect(restarted.stats.todayAthkarCompleted, 1);
      expect(restarted.pendingOperationCount, 1);
      remote.fail = false;
      await restarted.syncNow();
      expect(remote.batches.last.single.id, id);
      expect(remote.batches.last.single.merge, isTrue);
      expect(restarted.stats.todayAthkarCompleted, 1);
      restarted.dispose();
    },
  );

  for (final failedStep in [1, 2, 3]) {
    test(
      'guest transfer recovers after storage failure at step $failedStep',
      () async {
        final store = MemoryStore();
        final guest = make(store: store);
        await guest.initialize();
        await guest.setCount(quran, '1:1', 1);
        guest.dispose();
        store.failAt = store.writes + failedStep;
        final account = make(store: store, auth: FakeAuth()..signIn('A'));
        await expectLater(account.initialize(), throwsStateError);
        account.dispose();
        store.failAt = null;
        final remote = FakeRemote();
        final retry = make(
          store: store,
          remote: remote,
          auth: FakeAuth()..signIn('A'),
        );
        await retry.initialize();
        expect(retry.stats.todayQuranVerses, 1);
        expect(retry.pendingOperationCount, 1);
        await retry.syncNow();
        expect(remote.revision, 1);
        retry.dispose();
      },
    );
  }

  test('interrupted guest transfer cannot leak into another account', () async {
    final store = MemoryStore();
    final guest = make(store: store);
    await guest.initialize();
    await guest.setCount(quran, '1:1', 1);
    guest.dispose();
    store.failAt = store.writes + 2; // Recipient is journaled, copy fails.
    final first = make(store: store, auth: FakeAuth()..signIn('A'));
    await expectLater(first.initialize(), throwsStateError);
    first.dispose();
    store.failAt = null;
    final auth = FakeAuth()..signIn('B');
    final service = make(store: store, auth: auth);
    await service.initialize();
    expect(service.entries, isEmpty);
    auth.signIn('A');
    await settle();
    expect(service.stats.todayQuranVerses, 1);
    await auth.clearSession();
    await settle();
    // New guest activity can belong to the next account.
    await service.setCount(quran, '1:2', 1);
    auth.signIn('B');
    await settle();
    expect(service.todayCount(quran, '1:2'), 1);
    expect(service.todayCount(quran, '1:1'), 0);
    service.dispose();
  });

  test('login flushes in-flight guest taps before transfer', () async {
    final auth = FakeAuth();
    final store = MemoryStore();
    final service = make(auth: auth, store: store);
    await service.initialize();
    store.gate = Completer<void>();
    final save = service.setCount(athkar, 'morning:1', 3);
    auth.signIn('A');
    await settle();
    store.gate!.complete();
    await save;
    await settle();
    expect(service.stats.todayAthkarCompleted, 1);
    expect(service.pendingOperationCount, 1);
    service.dispose();
  });

  test(
    'guest restart completes a claimed transfer before accepting new readings',
    () async {
      final store = MemoryStore();
      final guest = make(store: store);
      await guest.initialize();
      await guest.setCount(quran, '1:1', 1);
      guest.dispose();
      store.failAt = store.writes + 3; // Copy saved, clearing guest failed.
      final first = make(store: store, auth: FakeAuth()..signIn('A'));
      await expectLater(first.initialize(), throwsStateError);
      first.dispose();
      store.failAt = null;
      final auth = FakeAuth();
      final restart = make(store: store, auth: auth);
      await restart.initialize();
      expect(restart.entries, isEmpty);
      await restart.setCount(quran, '1:2', 1);
      auth.signIn('B');
      await settle();
      expect(restart.todayCount(quran, '1:1'), 0);
      expect(restart.todayCount(quran, '1:2'), 1);
      auth.signIn('A');
      await settle();
      expect(restart.todayCount(quran, '1:1'), 1);
      expect(restart.todayCount(quran, '1:2'), 0);
      expect(restart.pendingOperationCount, 1);
      restart.dispose();
    },
  );

  test(
    'guest import stays local for one minute and later edits reset debounce',
    () {
      fakeAsync((async) {
        final auth = FakeAuth();
        final remote = FakeRemote();
        final start = DateTime(2026, 9, 13, 14);
        final service = make(
          auth: auth,
          remote: remote,
          automatic: true,
          now: () => start.add(async.elapsed),
        );
        service.initialize();
        async.flushMicrotasks();
        service.setCount(quran, '1:1', 1);
        async.flushMicrotasks();
        auth.signIn('A');
        async.flushMicrotasks();
        expect(service.stats.todayQuranVerses, 1);
        expect(remote.batches, isEmpty);
        async.elapse(const Duration(seconds: 40));
        service.setCount(quran, '1:2', 1);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 59));
        expect(remote.batches, isEmpty);
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(service.pendingOperationCount, 0);
        expect(service.stats.todayQuranVerses, 2);
        service.dispose();
      });
    },
  );
  test('canonical Quran bounds include 87:19 and exactly 6236 verses', () {
    expect(QuranReadingKeys.verseCounts.length, 114);
    expect(QuranReadingKeys.verseCounts.reduce((a, b) => a + b), 6236);
    expect(QuranReadingKeys.contains('87:19'), isTrue);
    for (final key in [
      '0:1',
      '115:1',
      '1:8',
      '01:1',
      '2:287',
      '87:20',
      '1:0',
    ]) {
      expect(QuranReadingKeys.contains(key), isFalse);
    }
    expect(QuranReadingKeys.keysForSurah(2).length, 286);
  });
  test(
    'guest readings persist after restart and never create an upload outbox',
    () async {
      final store = MemoryStore();
      final service = make(store: store);
      await service.initialize();
      await service.setCount(quran, '1:1', 1);
      await service.setCount(athkar, 'morning:1', 3);
      expect(service.pendingOperationCount, 0);
      service.dispose();
      final restart = make(store: store);
      await restart.initialize();
      expect(restart.todayCount(quran, '1:1'), 1);
      expect(restart.stats.todayAthkarCompleted, 1);
      expect(restart.status, 'cloud_signed_out');
      restart.dispose();
    },
  );
  test(
    'rapid increments are immediately optimistic with storage blocked',
    () async {
      final store = MemoryStore()..gate = Completer<void>();
      final service = make(store: store);
      await service.initialize();
      final writes = [
        service.increment(athkar, 'morning:1'),
        service.increment(athkar, 'morning:1'),
        service.increment(athkar, 'morning:1'),
      ];
      expect(service.todayCount(athkar, 'morning:1'), 3);
      store.gate!.complete();
      await Future.wait(writes);
      expect(service.isComplete(athkar, 'morning:1'), isTrue);
      service.dispose();
    },
  );
  test(
    'failed optimistic write rolls back without undoing later pending edits',
    () async {
      final store = MemoryStore()
        ..gate = Completer<void>()
        ..fail = true;
      final service = make(store: store);
      await service.initialize();
      final first = service.setCount(quran, '1:1', 1);
      final failed = expectLater(first, throwsStateError);
      final second = service.setCount(quran, '1:2', 1);
      final failed2 = expectLater(second, throwsStateError);
      expect(service.stats.todayQuranVerses, 2);
      store.gate!.complete();
      await failed;
      await failed2;
      expect(service.stats.todayQuranVerses, 0);
      expect(store.values, isEmpty);
      service.dispose();
    },
  );
  test(
    'surah write is atomic once locally and uploaded in chunks100',
    () async {
      final store = MemoryStore();
      final remote = FakeRemote();
      final auth = FakeAuth()..signIn('A');
      final service = make(store: store, remote: remote, auth: auth);
      await service.initialize();
      await service.setMany(quran, {
        for (final key in QuranReadingKeys.keysForSurah(2)) key: 1,
      });
      expect(store.writes, 1);
      expect(service.stats.todayQuranSurahs, 1);
      await service.syncNow();
      expect(remote.batches.map((b) => b.length), [100, 100, 86]);
      expect(remote.pulls, [0]);
      expect(service.pendingOperationCount, 0);
      expect(service.status, 'cloud_synced');
      service.dispose();
    },
  );
  test('offline outbox survives restart and retries immutable UUIDs', () async {
    final store = MemoryStore();
    final remote = FakeRemote()..fail = true;
    final auth = FakeAuth()..signIn('A');
    var service = make(store: store, remote: remote, auth: auth);
    await service.initialize();
    await service.setCount(quran, '1:1', 1);
    await expectLater(
      service.syncNow(),
      throwsA(isA<ReadingProgressRemoteException>()),
    );
    final id = remote.batches.single.single.id;
    expect(service.status, 'cloud_offline');
    service.dispose();
    service = make(store: store, remote: remote, auth: auth);
    await service.initialize();
    remote.fail = false;
    await service.syncNow();
    expect(remote.batches.last.single.id, id);
    expect(service.pendingOperationCount, 0);
    service.dispose();
  });
  test(
    'changes during POST stay overlaid and are not acknowledged by that request',
    () async {
      final auth = FakeAuth()..signIn('A');
      final remote = FakeRemote();
      final gate = Completer<ReadingProgressAcknowledgement>();
      remote.onPush = (_) => gate.future;
      final service = make(auth: auth, remote: remote);
      await service.initialize();
      await service.setCount(quran, '1:1', 1);
      final syncing = service.syncNow();
      await settle();
      await service.setCount(quran, '1:1', 0);
      final sent = remote.batches.single.single;
      gate.complete(
        ReadingProgressAcknowledgement(
          acknowledged: [sent.id, 'not-sent'],
          entries: [
            {...sent.entry.toJson(), 'revision': 1},
          ],
        ),
      );
      remote.revision = 1;
      await syncing;
      expect(service.todayCount(quran, '1:1'), 0);
      expect(service.pendingOperationCount, 1);
      expect(service.status, 'cloud_pending');
      remote.onPush = null;
      await service.syncNow();
      expect(service.pendingOperationCount, 0);
      service.dispose();
    },
  );
  test(
    'duplicate retry cannot overwrite newer server value and POST cannot skip GET history',
    () async {
      final remote = FakeRemote();
      final auth = FakeAuth()..signIn('A');
      final store = MemoryStore();
      remote.records['quran|2026-09-12|1:2'] = {
        'kind': 'quran',
        'itemKey': '1:2',
        'day': '2026-09-12',
        'count': 1,
        'revision': 1,
      };
      remote.revision = 1;
      final service = make(auth: auth, remote: remote, store: store);
      await service.initialize();
      await service.setCount(quran, '1:1', 1);
      await service.syncNow();
      expect(remote.pulls.first, 0);
      expect(service.count(quran, '1:2', day: '2026-09-12'), 1);
      expect(service.stats.quranUniqueVerses, 2);
      service.dispose();
    },
  );
  test(
    'GET pagination persists cursor and pending local edits overlay pulled values',
    () async {
      final remote = FakeRemote();
      final auth = FakeAuth()..signIn('A');
      remote.onPull = (after) async => ReadingProgressPage(
        entries: [
          {
            'kind': 'quran',
            'itemKey': after == 0 ? '1:1' : '1:2',
            'day': '2026-09-13',
            'count': 1,
            'revision': after + 1,
          },
        ],
        cursor: after + 1,
        hasMore: after == 0,
      );
      final service = make(auth: auth, remote: remote);
      await service.initialize();
      await service.syncNow();
      expect(remote.pulls, [0, 1]);
      expect(service.stats.todayQuranVerses, 2);
      service.dispose();
    },
  );
  test(
    'guest transfer belongs only to its recipient and ignores late 401 responses',
    () async {
      final auth = FakeAuth();
      final remote = FakeRemote();
      final gate = Completer<ReadingProgressPage>();
      final service = make(auth: auth, remote: remote);
      await service.initialize();
      await service.setCount(quran, '1:3', 1);
      auth.signIn('A');
      await settle();
      expect(service.stats.todayQuranVerses, 1);
      await service.setCount(quran, '1:1', 1);
      remote.onPull = (_) => gate.future;
      final syncing = service.syncNow();
      await settle();
      auth.signIn('B');
      await settle();
      expect(service.stats.todayQuranVerses, 0);
      await service.setCount(quran, '1:2', 1);
      gate.completeError(const ReadingProgressRemoteException(401));
      await syncing;
      expect(auth.cleared, 0);
      expect(service.todayCount(quran, '1:2'), 1);
      expect(service.todayCount(quran, '1:1'), 0);
      auth.signIn('A');
      await settle();
      expect(service.todayCount(quran, '1:1'), 1);
      expect(service.todayCount(quran, '1:2'), 0);
      await auth.clearSession();
      await settle();
      expect(service.todayCount(quran, '1:3'), 0);
      service.dispose();
    },
  );
  test(
    'changing same account bearer ignores rejection of older session',
    () async {
      final auth = FakeAuth()..signIn('A', 'old');
      final remote = FakeRemote();
      final gate = Completer<ReadingProgressPage>();
      remote.onPull = (_) => gate.future;
      final service = make(auth: auth, remote: remote);
      await service.initialize();
      final syncing = service.syncNow();
      await settle();
      auth.signIn('A', 'new');
      await settle();
      gate.completeError(const ReadingProgressRemoteException(401));
      await syncing;
      expect(auth.cleared, 0);
      expect(auth.token, 'new');
      service.dispose();
    },
  );
  test('401 on current exact session clears only that session', () async {
    final auth = FakeAuth()..signIn('A');
    final remote = FakeRemote()
      ..onPull = (_) async => throw const ReadingProgressRemoteException(401);
    final service = make(auth: auth, remote: remote);
    await service.initialize();
    await expectLater(
      service.syncNow(),
      throwsA(isA<ReadingProgressRemoteException>()),
    );
    await settle();
    expect(auth.cleared, 1);
    expect(service.status, 'cloud_signed_out');
    service.dispose();
  });
  test(
    'API origin is part of local scope and cache contains no bearer or profile',
    () async {
      final store = MemoryStore();
      final a = make(store: store, auth: FakeAuth()..signIn('A'));
      await a.initialize();
      await a.setCount(quran, '1:1', 1);
      a.dispose();
      final b = make(
        store: store,
        auth: FakeAuth(origin: 'https://other.test')..signIn('A'),
      );
      await b.initialize();
      expect(b.stats.todayQuranVerses, 0);
      final raw = jsonEncode(store.values);
      expect(raw, isNot(contains('token-A')));
      expect(raw, isNot(contains('@example')));
      b.dispose();
    },
  );
  test(
    'validation rejects bad day, verse, count and unknown athkar before writing',
    () async {
      final store = MemoryStore();
      final service = make(store: store);
      await service.initialize();
      for (final day in [
        '1999-12-31',
        '2101-01-01',
        '2026-02-30',
        '2026-1-01',
      ]) {
        await expectLater(
          service.setCount(quran, '1:1', 1, day: day),
          throwsArgumentError,
        );
      }
      await expectLater(service.setCount(quran, '1:8', 1), throwsArgumentError);
      await expectLater(service.setCount(quran, '1:1', 2), throwsRangeError);
      await expectLater(
        service.setCount(athkar, 'morning:1', 4),
        throwsRangeError,
      );
      await expectLater(
        service.setCount(athkar, 'missing', 1),
        throwsArgumentError,
      );
      expect(store.writes, 0);
      service.dispose();
    },
  );
  test(
    'invalid remote records never advance cursor or save partial response',
    () async {
      final remote = FakeRemote()
        ..onPull = (_) async => const ReadingProgressPage(
          entries: [
            {
              'kind': 'quran',
              'itemKey': '87:20',
              'day': '2026-09-13',
              'count': 1,
              'revision': 1,
            },
          ],
          cursor: 1,
          hasMore: false,
        );
      final store = MemoryStore();
      final service = make(
        auth: FakeAuth()..signIn('A'),
        store: store,
        remote: remote,
      );
      await service.initialize();
      await expectLater(service.syncNow(), throwsArgumentError);
      expect(store.writes, 0);
      expect(service.entries, isEmpty);
      service.dispose();
    },
  );
  test(
    'midnight resets today without deleting history; streak ignores empty days',
    () async {
      var now = DateTime(2026, 9, 13, 23, 59);
      final service = make(now: () => now);
      await service.initialize();
      await service.setCount(quran, '1:1', 1, day: '2026-09-12');
      await service.setCount(quran, '1:1', 1);
      await service.setCount(athkar, 'morning:1', 2);
      expect(service.stats.currentStreak, 2);
      expect(service.stats.todayAthkarCompleted, 0);
      expect(service.stats.quranUniqueVerses, 1);
      now = DateTime(2026, 9, 14, 0, 1);
      service.refreshDay();
      expect(service.stats.todayQuranVerses, 0);
      expect(service.stats.currentStreak, 2);
      expect(service.lastDays().last.day, '2026-09-14');
      expect(service.lastDays().last.active, isFalse);
      now = DateTime(2026, 9, 15);
      service.refreshDay();
      expect(service.stats.currentStreak, 0);
      expect(service.stats.activeDays, 2);
      service.dispose();
    },
  );
  test(
    'checked verse totals and surah completion reverse when unchecked; freeform athkar target1',
    () async {
      final service = make();
      await service.initialize();
      expect(service.stats.currentStreak, 0);
      expect(service.lastDays().length, 7);
      await service.setMany(quran, {
        for (final key in QuranReadingKeys.keysForSurah(1)) key: 1,
      });
      expect(service.stats.todayQuranSurahs, 1);
      await service.setCount(quran, '1:7', 0);
      expect(service.stats.todayQuranSurahs, 0);
      expect(service.stats.quranUniqueVerses, 6);
      await service.setCount(athkar, 'morning:2', 1);
      expect(service.stats.todayAthkarCompleted, 1);
      service.dispose();
    },
  );
  test(
    'GET in flight keeps a newer local unchecked value over the pulled value',
    () async {
      final auth = FakeAuth()..signIn('A');
      final remote = FakeRemote();
      final gate = Completer<ReadingProgressPage>();
      final service = make(auth: auth, remote: remote);
      await service.initialize();
      await service.setCount(quran, '1:1', 1);
      await service.syncNow();
      remote.onPull = (_) => gate.future;
      final sync = service.syncNow();
      await settle();
      await service.setCount(quran, '1:1', 0);
      gate.complete(
        const ReadingProgressPage(
          entries: [
            {
              'kind': 'quran',
              'itemKey': '1:1',
              'day': '2026-09-13',
              'count': 1,
              'revision': 2,
            },
          ],
          cursor: 2,
          hasMore: false,
        ),
      );
      await sync;
      expect(service.todayCount(quran, '1:1'), 0);
      expect(service.pendingOperationCount, 1);
      service.dispose();
    },
  );
  test(
    'acknowledgement storage failure retains UUID for idempotent retry',
    () async {
      final auth = FakeAuth()..signIn('A');
      final remote = FakeRemote();
      final store = MemoryStore();
      final service = make(auth: auth, remote: remote, store: store);
      await service.initialize();
      await service.setCount(quran, '1:1', 1);
      store.fail = true;
      await expectLater(service.syncNow(), throwsStateError);
      final id = remote.batches.single.single.id;
      expect(service.pendingOperationCount, 1);
      expect(remote.revision, 1);
      // A different device unchecks it after the first request was accepted.
      remote.records['quran|2026-09-13|1:1'] = {
        'kind': 'quran',
        'itemKey': '1:1',
        'day': '2026-09-13',
        'count': 0,
        'revision': 2,
      };
      remote.revision = 2;
      store.fail = false;
      await service.syncNow();
      expect(remote.batches.last.single.id, id);
      expect(remote.revision, 2);
      expect(service.todayCount(quran, '1:1'), 0);
      expect(service.pendingOperationCount, 0);
      service.dispose();
    },
  );
  test(
    'unrelated acknowledged UUID does not delete an operation that was never sent',
    () async {
      final auth = FakeAuth()..signIn('A');
      final remote = FakeRemote();
      final gate = Completer<ReadingProgressAcknowledgement>();
      final store = MemoryStore();
      final service = make(auth: auth, remote: remote, store: store);
      await service.initialize();
      await service.setCount(quran, '1:1', 1);
      remote.onPush = (_) => gate.future;
      final sync = service.syncNow();
      await settle();
      await service.setCount(quran, '1:2', 1);
      final unsent =
          (store.values.values.single['outbox'] as List).last['id'] as String;
      gate.complete(
        ReadingProgressAcknowledgement(
          acknowledged: [remote.batches.single.single.id, unsent],
          entries: const [],
        ),
      );
      await sync;
      expect(service.pendingOperationCount, 1);
      service.dispose();
    },
  );
  test(
    'account switch during a blocked local write cannot move its data to the new account',
    () async {
      final auth = FakeAuth()..signIn('A');
      final store = MemoryStore();
      final service = make(auth: auth, store: store);
      await service.initialize();
      store.gate = Completer<void>();
      final save = service.setCount(quran, '1:1', 1);
      auth.signIn('B');
      await settle();
      expect(service.initialized, isFalse);
      expect(service.entries, isEmpty);
      store.gate!.complete();
      await save;
      await settle();
      expect(service.initialized, isTrue);
      expect(service.todayCount(quran, '1:1'), 0);
      auth.signIn('A');
      await settle();
      expect(service.todayCount(quran, '1:1'), 1);
      service.dispose();
    },
  );
  test('remote cursor is not persisted when saving a page fails', () async {
    final auth = FakeAuth()..signIn('A');
    final store = MemoryStore()..fail = true;
    final remote = FakeRemote()..revision = 1;
    remote.records['quran|2026-09-13|1:1'] = {
      'kind': 'quran',
      'itemKey': '1:1',
      'day': '2026-09-13',
      'count': 1,
      'revision': 1,
    };
    final service = make(auth: auth, store: store, remote: remote);
    await service.initialize();
    await expectLater(service.syncNow(), throwsStateError);
    expect(service.entries, isEmpty);
    store.fail = false;
    await service.syncNow();
    expect(remote.pulls, [0, 0]);
    expect(service.todayCount(quran, '1:1'), 1);
    service.dispose();
  });
  test(
    'malformed pagination and noninteger counts are rejected without partial commits',
    () async {
      final auth = FakeAuth()..signIn('A');
      final store = MemoryStore();
      final remote = FakeRemote();
      final service = make(auth: auth, store: store, remote: remote);
      await service.initialize();
      remote.onPull = (_) async =>
          const ReadingProgressPage(entries: [], cursor: 0, hasMore: true);
      await expectLater(service.syncNow(), throwsFormatException);
      remote.onPull = (_) async => const ReadingProgressPage(
        entries: [
          {
            'kind': 'quran',
            'itemKey': '1:1',
            'day': '2026-09-13',
            'count': 1.0,
            'revision': 1,
          },
        ],
        cursor: 1,
        hasMore: false,
      );
      await expectLater(service.syncNow(), throwsFormatException);
      expect(store.writes, 0);
      service.dispose();
    },
  );
  test(
    'cursor jumps and out-of-order revisions never discard unseen history',
    () async {
      final auth = FakeAuth()..signIn('A');
      final store = MemoryStore();
      final remote = FakeRemote();
      final service = make(auth: auth, store: store, remote: remote);
      await service.initialize();
      final row = <String, dynamic>{
        'kind': 'quran',
        'itemKey': '1:1',
        'day': '2026-09-13',
        'count': 1,
        'revision': 1,
      };
      for (final page in [
        const ReadingProgressPage(entries: [], cursor: 100, hasMore: false),
        ReadingProgressPage(entries: [row], cursor: 100, hasMore: false),
        ReadingProgressPage(
          entries: [
            {...row, 'revision': 2},
            row,
          ],
          cursor: 1,
          hasMore: false,
        ),
        ReadingProgressPage(
          entries: [
            {...row, 'revision': 9007199254740992},
          ],
          cursor: 9007199254740992,
          hasMore: false,
        ),
      ]) {
        remote.onPull = (_) async => page;
        await expectLater(service.syncNow(), throwsFormatException);
        expect(store.writes, 0);
        expect(service.entries, isEmpty);
      }
      service.dispose();
    },
  );
  test(
    'profile refresh preserves the edit debounce without hiding local readings',
    () {
      fakeAsync((async) {
        final start = DateTime(2026, 9, 13, 14);
        final auth = FakeAuth()..signIn('A');
        final remote = FakeRemote();
        final service = make(
          auth: auth,
          remote: remote,
          automatic: true,
          now: () => start.add(async.elapsed),
        );
        service.initialize();
        async.flushMicrotasks();
        service.setCount(quran, '1:1', 1);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 40));
        auth.signIn('A');
        async.flushMicrotasks();
        expect(service.initialized, isTrue);
        expect(service.todayCount(quran, '1:1'), 1);
        expect(remote.batches, isEmpty);
        async.elapse(const Duration(seconds: 19));
        async.flushMicrotasks();
        expect(remote.batches, isEmpty);
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(service.pendingOperationCount, 0);
        service.dispose();
      });
    },
  );
  test(
    'opening history respects the last edit deadline while explicit sync bypasses it',
    () {
      fakeAsync((async) {
        final start = DateTime(2026, 9, 13, 14);
        final auth = FakeAuth()..signIn('A');
        final remote = FakeRemote();
        final service = make(
          auth: auth,
          remote: remote,
          automatic: true,
          now: () => start.add(async.elapsed),
        );
        service.initialize();
        async.flushMicrotasks();
        final initialPulls = remote.pulls.length;
        service.loadHistory();
        async.flushMicrotasks();
        expect(remote.pulls.length, greaterThan(initialPulls));
        service.setCount(quran, '1:1', 1);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 40));
        service.loadHistory();
        async.flushMicrotasks();
        expect(remote.batches, isEmpty);
        async.elapse(const Duration(seconds: 19));
        async.flushMicrotasks();
        expect(remote.batches, isEmpty);
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(remote.batches.length, 1);
        expect(service.pendingOperationCount, 0);
        service.setCount(quran, '1:2', 1);
        async.flushMicrotasks();
        service.syncNow();
        async.flushMicrotasks();
        expect(remote.batches.length, 2);
        expect(service.pendingOperationCount, 0);
        service.dispose();
      });
    },
  );
  test(
    'automatic sync waits60 seconds after last edit, retries offline, pauses in background',
    () {
      fakeAsync((async) {
        final start = DateTime(2026, 9, 13, 14);
        final remote = FakeRemote();
        final service = make(
          auth: FakeAuth()..signIn('A'),
          remote: remote,
          automatic: true,
          now: () => start.add(async.elapsed),
        );
        service.initialize();
        async.flushMicrotasks();
        remote.pulls.clear();
        service.setCount(quran, '1:1', 1);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 40));
        async.flushMicrotasks();
        expect(remote.batches, isEmpty);
        service.setCount(quran, '1:2', 1);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 59));
        async.flushMicrotasks();
        expect(remote.batches, isEmpty);
        remote.fail = true;
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(remote.batches.length, 1);
        expect(service.status, 'cloud_offline');
        remote.fail = false;
        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();
        expect(service.pendingOperationCount, 0);
        service.didChangeAppLifecycleState(AppLifecycleState.paused);
        service.setCount(quran, '1:3', 1);
        async.flushMicrotasks();
        final requests = remote.batches.length;
        async.elapse(const Duration(minutes: 3));
        async.flushMicrotasks();
        expect(remote.batches.length, requests);
        service.didChangeAppLifecycleState(AppLifecycleState.resumed);
        async.flushMicrotasks();
        expect(service.pendingOperationCount, 0);
        service.dispose();
      });
    },
  );
}
