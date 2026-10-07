import 'dart:async';

import 'package:flutter/material.dart';
import 'package:salatime/service/app_update_service.dart';
import 'package:salatime/view/base/app_update_banner.dart';

class AppUpdateNoticeHost extends StatefulWidget {
  const AppUpdateNoticeHost({
    super.key,
    required this.isHome,
    required this.builder,
    this.service,
  });

  final bool isHome;
  final AppUpdateService? service;
  final Widget Function(BuildContext, Widget? banner, bool pauseReview) builder;
  static const quietTime = Duration(seconds: 2);

  @override
  State<AppUpdateNoticeHost> createState() => _AppUpdateNoticeHostState();
}

class _AppUpdateNoticeHostState extends State<AppUpdateNoticeHost>
    with WidgetsBindingObserver {
  Timer? _timer;
  ModalRoute<dynamic>? _route;
  bool _foreground = false;
  bool _checking = false;
  bool _opening = false;
  bool _openFailed = false;

  AppUpdateService get _service => widget.service ?? AppUpdateService.instance;
  bool get _visible =>
      mounted && _foreground && widget.isHome && _route?.isCurrent == true;

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _service.availableUpdate.addListener(_updateChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    _schedule();
  }

  @override
  void didUpdateWidget(AppUpdateNoticeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      (oldWidget.service ?? AppUpdateService.instance).availableUpdate
          .removeListener(_updateChanged);
      _service.availableUpdate.addListener(_updateChanged);
    }
    if (oldWidget.isHome != widget.isHome ||
        oldWidget.service != widget.service) {
      _schedule();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _foreground = state == AppLifecycleState.resumed);
    _schedule();
  }

  void _updateChanged() {
    if (mounted) setState(() => _openFailed = false);
  }

  void _schedule() {
    _timer?.cancel();
    if (_visible && !_checking) {
      _timer = Timer(AppUpdateNoticeHost.quietTime, _check);
    }
  }

  Future<void> _check() async {
    if (!_visible || _checking) return;
    setState(() => _checking = true);
    try {
      await _service.checkForUpdate();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _open(AvailableAppUpdate update) async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _openFailed = false;
    });
    final opened = await _service.openStore(update);
    if (mounted) {
      setState(() {
        _opening = false;
        _openFailed = !opened;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _service.availableUpdate.removeListener(_updateChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final update = _visible ? _service.availableUpdate.value : null;
    final banner = update == null
        ? null
        : AppUpdateBanner(
            version: update.version,
            busy: _opening,
            openFailed: _openFailed,
            onUpdate: () => unawaited(_open(update)),
            onLater: () => unawaited(_service.dismiss(update)),
          );
    return widget.builder(context, banner, _checking || update != null);
  }
}
