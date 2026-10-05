import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:salatime/service/play_store_review_service.dart';

/// Lives in the navigation shell: retained/offstage tabs must not prompt.
class PlayStoreReviewHost extends StatefulWidget {
  const PlayStoreReviewHost({
    super.key,
    required this.isHome,
    required this.child,
    this.service,
    this.enabled,
  });

  final bool isHome;
  final Widget child;
  final PlayStoreReviewService? service;
  final bool? enabled;
  static const quietTime = Duration(seconds: 10);

  @override
  State<PlayStoreReviewHost> createState() => _PlayStoreReviewHostState();
}

class _PlayStoreReviewHostState extends State<PlayStoreReviewHost>
    with WidgetsBindingObserver {
  Timer? _timer;
  ModalRoute<dynamic>? _route;
  bool _foreground = false;
  bool _busy = false;
  int _generation = 0;
  PlayStoreReviewService get _service =>
      widget.service ?? PlayStoreReviewService.instance;
  bool get _enabled =>
      widget.enabled ??
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS) &&
          const String.fromEnvironment(
                'SALATIME_APPLICATION_ID',
                defaultValue: 'net.salatime.app',
              ) ==
              'net.salatime.app');
  bool get _visible =>
      mounted &&
      _enabled &&
      _foreground &&
      widget.isHome &&
      _route?.isCurrent == true;

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ModalRoute notifies us when another screen/dialog covers the shell and
    // again when it is popped, including routes opened from Quran cards.
    _route = ModalRoute.of(context);
    _schedule();
  }

  @override
  void didUpdateWidget(PlayStoreReviewHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isHome != widget.isHome ||
        oldWidget.enabled != widget.enabled) {
      _schedule();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _schedule();
  }

  void _schedule() {
    _generation++;
    _timer?.cancel();
    if (_enabled && _foreground) {
      // Brief prayer checks and Quran visits are real usage too. The quiet
      // home timer controls presentation, never whether a day is counted.
      unawaited(_recordVisit());
    }
    if (_visible && !_busy) {
      _timer = Timer(PlayStoreReviewHost.quietTime, _tryPrompt);
    }
  }

  Future<void> _recordVisit() async {
    try {
      await _service.recordVisit();
    } catch (_) {
      // An optional local counter must not interrupt the app.
    }
  }

  Future<void> _tryPrompt() async {
    if (!_visible || _busy) return;
    if (Get.isDialogOpen == true ||
        Get.isBottomSheetOpen == true ||
        Get.isSnackbarOpen) {
      _schedule();
      return;
    }
    final generation = _generation;
    _busy = true;
    var requested = false;
    try {
      requested = await _service.requestReviewIfEligible(
        canRequest: () =>
            _visible &&
            generation == _generation &&
            Get.isDialogOpen != true &&
            Get.isBottomSheetOpen != true &&
            !Get.isSnackbarOpen,
      );
    } catch (_) {
      // This optional feature must never prevent using the app offline.
    } finally {
      _busy = false;
      // No periodic polling: a future home visit/resume can try again.
      // A return while a previous claim was pending could not arm its timer.
      if (!requested && generation != _generation && _visible) _schedule();
    }
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
