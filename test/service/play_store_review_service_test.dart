import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/service/play_store_review_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late SharedPreferences prefs;
  late PlayStoreReviewService service;
  late List<Uri> opened;
  bool launchSucceeds = true;

  PlayStoreReviewService create() => PlayStoreReviewService(
    preferences: () async => prefs,
    now: () => now,
    openUrl: (uri) async {
      opened.add(uri);
      return launchSucceeds;
    },
  );

  Future<void> eligible() async {
    await service.recordVisit();
    now = now.add(const Duration(days: 1));
    await service.recordVisit();
    now = now.add(const Duration(days: 6));
    await service.recordVisit();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime.utc(2026, 9, 13, 12);
    opened = [];
    launchSucceeds = true;
    service = create();
  });

  test(
    'fresh install and seven-day boundary, without opening the Store',
    () async {
      await service.recordVisit();
      expect(await service.claimInvitation(), false);
      now = now.add(const Duration(days: 1));
      await service.recordVisit();
      now = now.add(const Duration(days: 6) - const Duration(seconds: 1));
      await service.recordVisit();
      expect(await service.claimInvitation(), false);
      now = now.add(const Duration(seconds: 1));
      expect(await service.claimInvitation(), true);
      expect(opened, isEmpty);
    },
  );

  test(
    'many resumes on one day do not qualify as multiple usage days',
    () async {
      await Future.wait(List.generate(15, (_) => service.recordVisit()));
      now = now.add(const Duration(days: 20));
      await service.recordVisit();
      expect(await service.claimInvitation(), false);
      now = now.add(const Duration(days: 1));
      await service.recordVisit();
      expect(await service.claimInvitation(), true);
    },
  );

  test('clock rewind does not increase usage or bypass age/cooldown', () async {
    await service.recordVisit();
    now = now.subtract(const Duration(days: 10));
    await service.recordVisit();
    expect(await service.claimInvitation(), false);
    now = now.add(const Duration(days: 17));
    await service.recordVisit();
    expect(await service.claimInvitation(), false);
    now = now.add(const Duration(days: 1));
    await service.recordVisit();
    expect(await service.claimInvitation(), true);
    now = now.subtract(const Duration(days: 1));
    expect(await service.claimInvitation(), false);
  });

  test('claims are serialized and preserved across restart', () async {
    await eligible();
    expect(
      await Future.wait([service.claimInvitation(), service.claimInvitation()]),
      [true, false],
    );
    service = create();
    expect(await service.claimInvitation(), false);
  });

  test(
    'Later/Back waits 30 days and invitations stop after three attempts',
    () async {
      await eligible();
      expect(await service.claimInvitation(), true);
      now = now.add(const Duration(days: 30) - const Duration(seconds: 1));
      expect(await service.claimInvitation(), false);
      now = now.add(const Duration(seconds: 1));
      expect(await service.claimInvitation(), true);
      now = now.add(const Duration(days: 30));
      expect(await service.claimInvitation(), true);
      now = now.add(const Duration(days: 365));
      expect(await service.claimInvitation(), false);
    },
  );

  test('No thanks stops invitations permanently, even after restart', () async {
    await eligible();
    await service.decline();
    service = create();
    now = now.add(const Duration(days: 365));
    await service.recordVisit();
    expect(await service.claimInvitation(), false);
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
      expect(await service.claimInvitation(), false);
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
      expect(await service.claimInvitation(), true);
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
    expect(await service.claimInvitation(), false);
    final data = jsonDecode(
      prefs.getString(PlayStoreReviewService.storageKey)!,
    );
    expect(data['days'], 1);
  });

  test(
    'manual rate remains available after declining automatic invitations',
    () async {
      await service.decline();
      expect(await service.openStore(), true);
      expect(opened.length, 1);
      expect(await service.claimInvitation(), false);
    },
  );
}
