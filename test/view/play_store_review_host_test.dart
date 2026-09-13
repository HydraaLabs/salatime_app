import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:zabi/service/play_store_review_service.dart';
import 'package:zabi/view/base/play_store_review_host.dart';
import 'package:zabi/view/base/play_store_review_prompt.dart';

class _ReviewService extends PlayStoreReviewService {
  int visits = 0;
  int claims = 0;
  int declines = 0;
  int storeOpens = 0;
  bool eligible = true;
  Future<void> Function()? visitHandler;
  Future<bool> Function()? claimHandler;

  @override
  Future<void> recordVisit() async {
    visits++;
    await visitHandler?.call();
  }

  @override
  Future<bool> claimInvitation() async {
    claims++;
    return await claimHandler?.call() ?? eligible;
  }

  @override
  Future<void> decline() async {
    declines++;
  }

  @override
  Future<bool> openStore() async {
    storeOpens++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _ReviewService service;
  late ValueNotifier<bool> home;
  late GlobalKey<NavigatorState> navigator;
  int prompts = 0;
  Future<PlayStoreReviewChoice?> Function(BuildContext)? prompt;

  setUp(() {
    service = _ReviewService();
    home = ValueNotifier(true);
    navigator = GlobalKey<NavigatorState>();
    prompts = 0;
    prompt = null;
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });
  tearDown(() {
    home.dispose();
    Get.reset();
  });

  Future<void> render(WidgetTester tester, {bool enabled = true}) async {
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
              showPrompt: (context) async {
                prompts++;
                return await prompt?.call(context);
              },
              child: const Text('SalaTime home'),
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
  }

  testWidgets(
    'an eligible home waits 30 seconds and dismissal never opens the Store',
    (tester) async {
      await render(tester);
      await tester.pump(const Duration(seconds: 29));
      expect(service.visits, 0);
      expect(prompts, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(service.visits, 1);
      expect(service.claims, 1);
      expect(prompts, 1);
      expect(service.storeOpens, 0);
      expect(service.declines, 0);
      await tester.pump(const Duration(minutes: 5));
      expect(prompts, 1);
      await disposeHost(tester);
    },
  );

  testWidgets(
    'hidden tabs cancel the countdown and return starts a full quiet period',
    (tester) async {
      await render(tester);
      await tester.pump(const Duration(seconds: 20));
      home.value = false;
      await tester.pump();
      await tester.pump(const Duration(minutes: 1));
      expect(service.visits, 0);
      home.value = true;
      await tester.pump();
      await tester.pump(const Duration(seconds: 29));
      expect(prompts, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(prompts, 1);
      expect(service.storeOpens, 0);
      await disposeHost(tester);
    },
  );

  testWidgets(
    'a covering route prevents requests and popping it rearms the home',
    (tester) async {
      await render(tester);
      await tester.pump(const Duration(seconds: 20));
      unawaited(
        navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Reader')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 1));
      expect(service.visits, 0);
      expect(prompts, 0);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 29));
      expect(prompts, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(prompts, 1);
      await disposeHost(tester);
    },
  );

  testWidgets(
    'background time never counts and resume starts a fresh 30 seconds',
    (tester) async {
      await render(tester);
      await tester.pump(const Duration(seconds: 20));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 5));
      expect(service.visits, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 29));
      expect(prompts, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(prompts, 1);
      await disposeHost(tester);
    },
  );

  testWidgets(
    'a stale visit does not claim an invitation for an offstage home',
    (tester) async {
      final visit = Completer<void>();
      service.visitHandler = () => visit.future;
      await render(tester);
      await tester.pump(const Duration(seconds: 30));
      expect(service.visits, 1);
      home.value = false;
      await tester.pump();
      visit.complete();
      await tester.pump();
      expect(service.claims, 0);
      expect(prompts, 0);
      expect(service.storeOpens, 0);
      await disposeHost(tester);
    },
  );

  testWidgets(
    'a stale claim cannot prompt; returning during that claim still rearms a full delay',
    (tester) async {
      final claim = Completer<bool>();
      service.claimHandler = () => claim.future;
      await render(tester);
      await tester.pump(const Duration(seconds: 30));
      expect(service.claims, 1);
      home.value = false;
      await tester.pump();
      home.value = true;
      await tester.pump();
      claim.complete(true);
      await tester.pump();
      expect(prompts, 0);
      expect(service.storeOpens, 0);
      service.claimHandler = null;
      await tester.pump(const Duration(seconds: 29));
      expect(service.claims, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(service.claims, 2);
      expect(prompts, 1);
      await disposeHost(tester);
    },
  );

  testWidgets('ineligible or disabled hosts never prompt or open the Store', (
    tester,
  ) async {
    service.eligible = false;
    await render(tester);
    await tester.pump(const Duration(seconds: 30));
    expect(service.claims, 1);
    expect(prompts, 0);
    await disposeHost(tester);
    await render(tester, enabled: false);
    await tester.pump(const Duration(minutes: 1));
    expect(service.visits, 1);
    expect(service.storeOpens, 0);
    await disposeHost(tester);
  });

  testWidgets(
    'only explicit rate opens the Store, while never stops invitations',
    (tester) async {
      prompt = (_) async => PlayStoreReviewChoice.never;
      await render(tester);
      await tester.pump(const Duration(seconds: 30));
      expect(service.declines, 1);
      expect(service.storeOpens, 0);
      await disposeHost(tester);
      prompt = (_) async => PlayStoreReviewChoice.rate;
      await render(tester);
      await tester.pump(const Duration(seconds: 30));
      expect(service.storeOpens, 1);
      await disposeHost(tester);
    },
  );

  testWidgets('a prompt result after disposal cannot open the Store', (
    tester,
  ) async {
    final result = Completer<PlayStoreReviewChoice?>();
    prompt = (_) => result.future;
    await render(tester);
    await tester.pump(const Duration(seconds: 30));
    expect(prompts, 1);
    await disposeHost(tester);
    result.complete(PlayStoreReviewChoice.rate);
    await tester.pump();
    expect(service.storeOpens, 0);
  });

  testWidgets(
    'an explicit rate choice still works when its dialog changes route visibility',
    (tester) async {
      prompt = (context) => showDialog<PlayStoreReviewChoice>(
        context: context,
        builder: (context) => AlertDialog(
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(PlayStoreReviewChoice.rate),
              child: const Text('Open Play Store'),
            ),
          ],
        ),
      );
      await render(tester);
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(prompts, 1);
      expect(service.storeOpens, 0);
      await tester.tap(find.text('Open Play Store'));
      await tester.pumpAndSettle();
      expect(service.storeOpens, 1);
      await disposeHost(tester);
    },
  );
}
