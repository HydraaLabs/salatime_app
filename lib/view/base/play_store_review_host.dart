import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zabi/service/play_store_review_service.dart';
import 'package:zabi/view/base/custom_snackbar.dart';
import 'package:zabi/view/base/play_store_review_prompt.dart';

/// Lives in the navigation shell: retained/offstage tabs must not prompt.
class PlayStoreReviewHost extends StatefulWidget {
  const PlayStoreReviewHost({
    super.key,
    required this.isHome,
    required this.child,
    this.service,
    this.enabled,
    this.showPrompt = showPlayStoreReviewPrompt,
  });

  final bool isHome;
  final Widget child;
  final PlayStoreReviewService? service;
  final bool? enabled;
  final Future<PlayStoreReviewChoice?> Function(BuildContext) showPrompt;
  static const quietTime = Duration(seconds: 30);

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
          defaultTargetPlatform == TargetPlatform.android &&
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
    if (_visible && !_busy) {
      _timer = Timer(PlayStoreReviewHost.quietTime, _tryPrompt);
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
    var promptShown = false;
    try {
      // Count an actual quiet visit, not notification wakes or setup launches.
      await _service.recordVisit();
      if (!_visible || generation != _generation) return;
      final claimed = await _service.claimInvitation();
      if (!claimed || !mounted || !_visible || generation != _generation) {
        return;
      }
      promptShown = true;
      final choice = await widget.showPrompt(context);
      if (!mounted) return;
      if (choice == PlayStoreReviewChoice.never) {
        await _service.decline();
      } else if (choice == PlayStoreReviewChoice.rate) {
        final opened = await _service.openStore();
        if (!opened && mounted && _foreground) {
          showCustomSnackBar('review_store_unavailable'.tr, isError: true);
        }
      }
    } catch (_) {
      // This optional feature must never prevent using the app offline.
    } finally {
      _busy = false;
      // No periodic polling: a future home visit/resume can try again.
      // A return while a previous claim was pending could not arm its timer.
      if (!promptShown && generation != _generation && _visible) _schedule();
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
