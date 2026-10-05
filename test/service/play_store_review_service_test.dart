import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/service/play_store_review_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late SharedPreferences prefs;
  late PlayStoreReviewService service;
  late List<Uri> opened;
  bool launchSucceeds = true;
  bool reviewAvailable = true;
  bool requestFails = false;
  int requests = 0;
  TargetPlatform platform = TargetPlatform.android;

  PlayStoreReviewService create() => PlayStoreReviewService(
    preferences: () async => prefs,
    now: () => now,
    platform: () => platform,
    reviewAvailable: () async => reviewAvailable,
    requestReview: () async {
      requests++;
      if (requestFails) throw StateError('Native review failed');
    },
    openUrl: (uri) async {
      opened.add(uri);
      return launchSucceeds;
    },
  );

  Future<void> eligible() async {
    await service.recordVisit();
    now = now.add(const Duration(days: 1));
    await service.recordVisit();
    now = now.add(const Duration(days: 2));
    await service.recordVisit();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime.utc(2026, 9, 13, 12);
    opened = [];
    launchSucceeds = true;
    reviewAvailable = true;
    requestFails = false;
    requests = 0;
    platform = TargetPlatform.android;
    service = create();
  });

  test(
    'fresh install and three-day boundary, without opening the Store',
    () async {
      await service.recordVisit();
      expect(
        await service.requestReviewIfEligible(canRequest: () => true),
        false,
      );
      now = now.add(const Duration(days: 1));
      await service.recordVisit();
      now = now.add(const Duration(days: 2) - const Duration(seconds: 1));
      await service.recordVisit();
      expect(
        await service.requestReviewIfEligible(canRequest: () => true),
        false,
      );
      now = now.add(const Duration(seconds: 1));
      expect(
        await service.requestReviewIfEligible(canRequest: () => true),
        true,
      );
      expect(opened, isEmpty);
    },
  );

  test(
    'many resumes on one day do not qualify as multiple usage days',
    () async {
      await Future.wait(List.generate(15, (_) => service.recordVisit()));
      now = now.add(const Duration(days: 20));
      await service.recordVisit();
      expect(
        await service.requestReviewIfEligible(canRequest: () => true),
        false,
      );
      now = now.add(const Duration(days: 1));
      await service.recordVisit();
      expect(
        await service.requestReviewIfEligible(canRequest: () => true),
        true,
      );
    },
  );

  test('clock rewind does not increase usage or bypass age/cooldown', () async {
    await service.recordVisit();
    now = now.subtract(const Duration(days: 10));
    await service.recordVisit();
    expect(
      await service.requestReviewIfEligible(canRequest: () => true),
      false,
    );
    now = now.add(const Duration(days: 17));
    await service.recordVisit();
    expect(
      await service.requestReviewIfEligible(canRequest: () => true),
      false,
    );
    now = now.add(const Duration(days: 1));
    await service.recordVisit();
    expect(await service.requestReviewIfEligible(canRequest: () => true), true);
    now = now.subtract(const Duration(days: 1));
    expect(
      await service.requestReviewIfEligible(canRequest: () => true),
      false,
    );
  });

  test('native attempts are serialized and preserved across restart', () async {
    await eligible();
    expect(
      await Future.wait([
        service.requestReviewIfEligible(canRequest: () => true),
        service.requestReviewIfEligible(canRequest: () => true),
      ]),
      [true, false],
    );
    service = create();
    expect(
      await service.requestReviewIfEligible(canRequest: () => true),
      false,
    );
  });

  test('native attempts wait 30 days and stop after three attempts', () async {
    await eligible();
    expect(await service.requestReviewIfEligible(canRequest: () => true), true);
    now = now.add(const Duration(days: 30) - const Duration(seconds: 1));
    expect(
      await service.requestReviewIfEligible(canRequest: () => true),
      false,
    );
    now = now.add(const Duration(seconds: 1));
    expect(await service.requestReviewIfEligible(canRequest: () => true), true);
    now = now.add(const Duration(days: 30));
    expect(await service.requestReviewIfEligible(canRequest: () => true), true);
    now = now.add(const Duration(days: 365));
    expect(
      await service.requestReviewIfEligible(canRequest: () => true),
      false,
    );
  });

  test('No thanks stops invitations permanently, even after restart', () async {
    await eligible();
    await service.decline();
    service = create();
    now = now.add(const Duration(days: 365));
    await service.recordVisit();
    expect(
      await service.requestReviewIfEligible(canRequest: () => true),
      false,
    );
    expect(opened, isEmpty);
  });

  test(
    'explicit store click uses fixed production listing and stops prompts',
    () async {
      await eligible();
      expect(await service.openStore(), true);
      expect(
        opened.single.toString(),
        'https://play.google.com/store/apps/details?id=net.salatime.app',
      );
      service = create();
      now = now.add(const Duration(days: 365));
      expect(
        await service.requestReviewIfEligible(canRequest: () => true),
        false,
      );
      // No inferred rating or submitted-review flag is recorded.
      final data = jsonDecode(
        prefs.getString(PlayStoreReviewService.storageKey)!,
      );
      expect(data.containsKey('rating'), false);
      expect(data.containsKey('reviewSubmitted'), false);
    },
  );

  test(
    'failed launch remains retryable and does not claim a submitted review',
    () async {
      await eligible();
      launchSucceeds = false;
      expect(await service.openStore(), false);
      expect(
        await service.requestReviewIfEligible(canRequest: () => true),
        true,
      );
      launchSucceeds = true;
      expect(await service.openStore(), true);
      expect(opened.length, 2);
    },
  );

  test('platform launch exception is handled', () async {
    service = PlayStoreReviewService(
      preferences: () async => prefs,
      now: () => now,
      openUrl: (_) async => throw StateError('No handler'),
    );
    expect(await service.openStore(), false);
  });

  test('corrupt history starts a new waiting period', () async {
    await prefs.setString(PlayStoreReviewService.storageKey, '{broken');
    await service.recordVisit();
    expect(
      await service.requestReviewIfEligible(canRequest: () => true),
      false,
    );
    final data = jsonDecode(
      prefs.getString(PlayStoreReviewService.storageKey)!,
    );
    expect(data['days'], 1);
  });

  for (final target in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('native review on $target retains only attempt timing', () async {
      platform = target;
      await eligible();
      expect(
        await service.requestReviewIfEligible(canRequest: () => true),
        true,
      );
      expect(requests, 1);
      expect(opened, isEmpty);
      final history =
          jsonDecode(prefs.getString(PlayStoreReviewService.storageKey)!)
              as Map<String, dynamic>;
      expect(history['stopped'], false);
      expect(history['invitations'], 1);
      expect(history.containsKey('rating'), false);
      expect(history.containsKey('reviewSubmitted'), false);
      now = now.add(PlayStoreReviewService.reminderDelay);
      expect(
        await service.requestReviewIfEligible(canRequest: () => true),
        true,
      );
      expect(requests, 2);
    });
  }

  test('iOS manual action opens the App Store review page', () async {
    platform = TargetPlatform.iOS;
    expect(await service.openStore(), true);
    expect(
      opened.single.toString(),
      'https://apps.apple.com/app/id6812923710?action=write-review',
    );
    expect(requests, 0);
  });

  test(
    'unsupported platforms never open a store or request a review',
    () async {
      platform = TargetPlatform.linux;
      await eligible();
      expect(await service.openStore(), false);
      expect(
        await service.requestReviewIfEligible(canRequest: () => true),
        false,
      );
      expect(opened, isEmpty);
      expect(requests, 0);
    },
  );

  test('unavailable review API does not consume an attempt', () async {
    await eligible();
    reviewAvailable = false;
    expect(
      await service.requestReviewIfEligible(canRequest: () => true),
      false,
    );
    expect(requests, 0);
    service = create();
    reviewAvailable = true;
    expect(await service.requestReviewIfEligible(canRequest: () => true), true);
    expect(requests, 1);
  });

  test(
    'default native adapter invokes availability then request channel',
    () async {
      await eligible();
      const channel = MethodChannel('dev.britannio.in_app_review');
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return call.method == 'isAvailable' ? true : null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      service = PlayStoreReviewService(
        preferences: () async => prefs,
        now: () => now,
        platform: () => TargetPlatform.iOS,
      );
      expect(
        await service.requestReviewIfEligible(canRequest: () => true),
        true,
      );
      expect(calls, ['isAvailable', 'requestReview']);
      expect(opened, isEmpty);
    },
  );

  test(
    'default native adapter missing from an older binary stays retryable',
    () async {
      await eligible();
      final previous = prefs.getString(PlayStoreReviewService.storageKey);
      service = PlayStoreReviewService(
        preferences: () async => prefs,
        now: () => now,
        platform: () => TargetPlatform.android,
      );
      expect(
        await service.requestReviewIfEligible(canRequest: () => true),
        false,
      );
      expect(prefs.getString(PlayStoreReviewService.storageKey), previous);
    },
  );

  test('a failed native call restores the prior persisted cooldown', () async {
    await eligible();
    expect(await service.requestReviewIfEligible(canRequest: () => true), true);
    now = now.add(PlayStoreReviewService.reminderDelay);
    final previous = prefs.getString(PlayStoreReviewService.storageKey);
    requestFails = true;
    expect(
      await service.requestReviewIfEligible(canRequest: () => true),
      false,
    );
    expect(prefs.getString(PlayStoreReviewService.storageKey), previous);
    service = create();
    requestFails = false;
    expect(await service.requestReviewIfEligible(canRequest: () => true), true);
    expect(requests, 3);
  });

  test('navigation during availability does not consume an attempt', () async {
    await eligible();
    final available = Completer<bool>();
    final checking = Completer<void>();
    service = PlayStoreReviewService(
      preferences: () async => prefs,
      now: () => now,
      platform: () => platform,
      reviewAvailable: () {
        checking.complete();
        return available.future;
      },
      requestReview: () async => requests++,
    );
    var visible = true;
    final pending = service.requestReviewIfEligible(canRequest: () => visible);
    await checking.future;
    visible = false;
    available.complete(true);
    expect(await pending, false);
    expect(requests, 0);
    service = create();
    expect(await service.requestReviewIfEligible(canRequest: () => true), true);
  });

  test(
    'navigation during persisted reservation does not consume cooldown',
    () async {
      await eligible();
      final previous = prefs.getString(PlayStoreReviewService.storageKey);
      expect(
        await service.requestReviewIfEligible(
          canRequest: () {
            final history =
                jsonDecode(prefs.getString(PlayStoreReviewService.storageKey)!)
                    as Map<String, dynamic>;
            // Simulate the home becoming hidden while its claim is saved.
            return history['lastInvitation'] == null;
          },
        ),
        false,
      );
      expect(requests, 0);
      expect(prefs.getString(PlayStoreReviewService.storageKey), previous);
      service = create();
      expect(
        await service.requestReviewIfEligible(canRequest: () => true),
        true,
      );
      expect(requests, 1);
    },
  );

  test(
    'manual rate remains available after declining automatic invitations',
    () async {
      await service.decline();
      expect(await service.openStore(), true);
      expect(opened.length, 1);
      expect(
        await service.requestReviewIfEligible(canRequest: () => true),
        false,
      );
    },
  );

  Future<void> legacyHistory({
    int invitations = 3,
    bool stopped = false,
    int days = 3,
    Duration age = const Duration(days: 10),
    int version = 1,
  }) => prefs.setString(
    PlayStoreReviewService.storageKey,
    jsonEncode({
      'version': version,
      'firstUse': now.subtract(age).toIso8601String(),
      'lastDay': '2026-09-13',
      'days': days,
      'invitations': invitations,
      'lastInvitation': now.toIso8601String(),
      'stopped': stopped,
    }),
  );

  for (final target in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final attempts in [1, 3]) {
      test(
        'legacy $attempts reservations do not block first native $target request',
        () async {
          platform = target;
          await legacyHistory(invitations: attempts);
          expect(
            await service.requestReviewIfEligible(canRequest: () => true),
            true,
          );
          expect(requests, 1);
          final history =
              jsonDecode(prefs.getString(PlayStoreReviewService.storageKey)!)
                  as Map<String, dynamic>;
          expect(history['version'], 2);
          expect(history['invitations'], 1);
          expect(history['days'], 3);
          expect(
            history['firstUse'],
            now.subtract(const Duration(days: 10)).toIso8601String(),
          );
          expect(history['lastDay'], '2026-09-13');
          service = create();
          expect(
            await service.requestReviewIfEligible(canRequest: () => true),
            false,
          );
          expect(requests, 1);
        },
      );
    }
  }

  test('legacy explicit refusal survives native migration', () async {
    await legacyHistory(stopped: true);
    await service.recordVisit();
    expect(
      await service.requestReviewIfEligible(canRequest: () => true),
      false,
    );
    final history = jsonDecode(
      prefs.getString(PlayStoreReviewService.storageKey)!,
    );
    expect(history['version'], 2);
    expect(history['stopped'], true);
    expect(requests, 0);
    expect(await service.openStore(), true);
  });

  test(
    'legacy migration persists when usage days are already capped',
    () async {
      await legacyHistory();
      await service.recordVisit();
      final history = jsonDecode(
        prefs.getString(PlayStoreReviewService.storageKey)!,
      );
      expect(history['version'], 2);
      expect(history['days'], 3);
      expect(history['lastDay'], '2026-09-13');
      expect(history['invitations'], 0);
      expect(history['lastInvitation'], isNull);
    },
  );

  test('legacy migration never bypasses age or usage-day thresholds', () async {
    await legacyHistory(days: 2);
    expect(
      await service.requestReviewIfEligible(canRequest: () => true),
      false,
    );
    await legacyHistory(age: const Duration(days: 2));
    expect(
      await service.requestReviewIfEligible(canRequest: () => true),
      false,
    );
    expect(requests, 0);
  });

  test(
    'existing v2 native attempts are never reset during migration',
    () async {
      await legacyHistory(version: 2);
      final previous = prefs.getString(PlayStoreReviewService.storageKey);
      await service.recordVisit();
      expect(
        await service.requestReviewIfEligible(canRequest: () => true),
        false,
      );
      expect(prefs.getString(PlayStoreReviewService.storageKey), previous);
      expect(requests, 0);
    },
  );
}
