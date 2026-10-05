import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:salatime/service/play_store_review_service.dart';
import 'package:salatime/view/base/play_store_review_host.dart';

class _ReviewService extends PlayStoreReviewService {
  int visits = 0;
  int eligibilityChecks = 0;
  int nativeRequests = 0;
  bool eligible = true;
  Future<bool> Function(bool Function())? requestHandler;

  @override
  Future<void> recordVisit() async {
    visits++;
  }

  @override
  Future<bool> requestReviewIfEligible({
    required bool Function() canRequest,
  }) async {
    eligibilityChecks++;
    final ready = await requestHandler?.call(canRequest) ?? true;
    if (!ready || !eligible || !canRequest()) return false;
    nativeRequests++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _ReviewService service;
  late ValueNotifier<bool> home;
  late GlobalKey<NavigatorState> navigator;

  setUp(() {
    service = _ReviewService();
    home = ValueNotifier(true);
    navigator = GlobalKey<NavigatorState>();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });

  tearDown(() {
    home.dispose();
    debugDefaultTargetPlatformOverride = null;
    Get.reset();
  });

  Future<void> render(WidgetTester tester, {bool? enabled}) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: home,
            builder: (context, isHome, child) => PlayStoreReviewHost(
              isHome: isHome,
              enabled: enabled,
              service: service,
              child: const Text('SalaTime shell'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> disposeHost(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '${platform.name} defaults to native review after ten quiet seconds',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        await render(tester);
        expect(service.visits, greaterThan(0));
        await tester.pump(const Duration(seconds: 9));
        expect(service.eligibilityChecks, 0);
        await tester.pump(const Duration(seconds: 1));
        expect(service.eligibilityChecks, 1);
        expect(service.nativeRequests, 1);
        expect(find.byType(AlertDialog), findsNothing);
        await tester.pump(const Duration(minutes: 5));
        expect(service.eligibilityChecks, 1);
        await disposeHost(tester);
      },
    );
  }

  testWidgets('Linux and explicitly disabled hosts never count or request', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await render(tester);
    await tester.pump(const Duration(minutes: 1));
    expect(service.visits, 0);
    expect(service.eligibilityChecks, 0);
    await disposeHost(tester);

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await render(tester, enabled: false);
    await tester.pump(const Duration(minutes: 1));
    expect(service.visits, 0);
    expect(service.nativeRequests, 0);
    await disposeHost(tester);
  });

  testWidgets('a brief foreground visit counts without waiting for a request', (
    tester,
  ) async {
    await render(tester);
    expect(service.visits, greaterThan(0));
    await tester.pump(const Duration(seconds: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 1));
    expect(service.eligibilityChecks, 0);
    expect(service.nativeRequests, 0);
    await disposeHost(tester);
  });

  testWidgets('an active non-home tab counts use but never requests a review', (
    tester,
  ) async {
    home.value = false;
    await render(tester);
    expect(service.visits, greaterThan(0));
    await tester.pump(const Duration(minutes: 1));
    expect(service.eligibilityChecks, 0);
    home.value = true;
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));
    expect(service.nativeRequests, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(service.nativeRequests, 1);
    await disposeHost(tester);
  });

  testWidgets('leaving home cancels and returning restarts the full delay', (
    tester,
  ) async {
    await render(tester);
    await tester.pump(const Duration(seconds: 6));
    home.value = false;
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    expect(service.eligibilityChecks, 0);
    home.value = true;
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));
    expect(service.nativeRequests, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(service.nativeRequests, 1);
    await disposeHost(tester);
  });

  testWidgets('a covering route suppresses requests until home returns', (
    tester,
  ) async {
    await render(tester);
    await tester.pump(const Duration(seconds: 6));
    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Reader'))),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 1));
    expect(service.eligibilityChecks, 0);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 9));
    expect(service.nativeRequests, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(service.nativeRequests, 1);
    await disposeHost(tester);
  });

  testWidgets('background time does not count toward the ten-second delay', (
    tester,
  ) async {
    await render(tester);
    await tester.pump(const Duration(seconds: 6));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 5));
    final visitsBeforeResume = service.visits;
    expect(service.eligibilityChecks, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(service.visits, greaterThan(visitsBeforeResume));
    await tester.pump(const Duration(seconds: 9));
    expect(service.nativeRequests, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(service.nativeRequests, 1);
    await disposeHost(tester);
  });

  testWidgets('a shell mounted in the background waits for foreground use', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await render(tester);
    await tester.pump(const Duration(minutes: 1));
    expect(service.visits, 0);
    expect(service.eligibilityChecks, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(service.visits, greaterThan(0));
    await tester.pump(const Duration(seconds: 10));
    expect(service.nativeRequests, 1);
    await disposeHost(tester);
  });

  testWidgets('an ineligible visit does not poll and a later visit can retry', (
    tester,
  ) async {
    service.eligible = false;
    await render(tester);
    await tester.pump(const Duration(seconds: 10));
    expect(service.eligibilityChecks, 1);
    expect(service.nativeRequests, 0);
    await tester.pump(const Duration(minutes: 5));
    expect(service.eligibilityChecks, 1);
    service.eligible = true;
    home.value = false;
    await tester.pump();
    home.value = true;
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(service.eligibilityChecks, 2);
    expect(service.nativeRequests, 1);
    await disposeHost(tester);
  });

  testWidgets(
    'returning while native availability is pending invalidates the old request',
    (tester) async {
      final available = Completer<bool>();
      bool Function()? pendingVisibility;
      service.requestHandler = (canRequest) {
        pendingVisibility = canRequest;
        return available.future;
      };
      await render(tester);
      await tester.pump(const Duration(seconds: 10));
      expect(service.eligibilityChecks, 1);
      expect(pendingVisibility!(), true);
      home.value = false;
      await tester.pump();
      expect(pendingVisibility!(), false);
      home.value = true;
      await tester.pump();
      expect(pendingVisibility!(), false);
      service.requestHandler = null;
      available.complete(true);
      await tester.pump();
      expect(service.nativeRequests, 0);
      await tester.pump(const Duration(seconds: 9));
      expect(service.eligibilityChecks, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(service.eligibilityChecks, 2);
      expect(service.nativeRequests, 1);
      await disposeHost(tester);
    },
  );

  testWidgets('backgrounding invalidates a pending native availability check', (
    tester,
  ) async {
    final available = Completer<bool>();
    bool Function()? pendingVisibility;
    service.requestHandler = (canRequest) {
      pendingVisibility = canRequest;
      return available.future;
    };
    await render(tester);
    await tester.pump(const Duration(seconds: 10));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(pendingVisibility!(), false);
    available.complete(true);
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    expect(service.nativeRequests, 0);
    expect(service.eligibilityChecks, 1);
    await disposeHost(tester);
  });

  testWidgets('a disposed host cannot complete a pending native request', (
    tester,
  ) async {
    final available = Completer<bool>();
    bool Function()? pendingVisibility;
    service.requestHandler = (canRequest) {
      pendingVisibility = canRequest;
      return available.future;
    };
    await render(tester);
    await tester.pump(const Duration(seconds: 10));
    await disposeHost(tester);
    expect(pendingVisibility!(), false);
    available.complete(true);
    await tester.pump();
    expect(service.nativeRequests, 0);
  });
}
