import 'dart:async';

/// Coalesces preference edits while keeping one scheduling pass in flight.
/// Every caller in a burst waits for the latest requested revision, including
/// edits made while an earlier pass was still running.
class PrayerRefreshCoordinator {
  PrayerRefreshCoordinator({
    required this.refresh,
    this.delay = const Duration(milliseconds: 250),
  });

  final Future<void> Function({
    required bool requestPermissions,
    required bool Function() isCurrent,
  })
  refresh;
  final Duration delay;
  Timer? _timer;
  Completer<void>? _settled;
  bool _running = false;
  bool _requestPermissions = false;
  int _revision = 0;

  Future<void> request({
    bool immediate = false,
    bool requestPermissions = false,
  }) {
    _revision++;
    _requestPermissions |= requestPermissions;
    final completion = _settled ??= Completer<void>();
    if (!_running) {
      if (immediate) {
        _timer?.cancel();
        _timer = null;
        unawaited(_drain());
      } else {
        // Bound the wait from the first edit: a continuous sequence of taps
        // must not postpone disabling an alarm indefinitely.
        _timer ??= Timer(delay, () {
          _timer = null;
          unawaited(_drain());
        });
      }
    }
    return completion.future;
  }

  Future<void> _drain() async {
    if (_running) return;
    _running = true;
    while (true) {
      final revision = _revision;
      final permissions = _requestPermissions;
      _requestPermissions = false;
      Object? failure;
      StackTrace? failureStack;
      try {
        await refresh(
          requestPermissions: permissions,
          isCurrent: () => revision == _revision,
        );
      } catch (error, stack) {
        failure = error;
        failureStack = stack;
      }
      if (revision != _revision) continue;
      final completion = _settled!;
      _settled = null;
      _running = false;
      if (failure != null) {
        completion.completeError(failure, failureStack);
      } else {
        completion.complete();
      }
      return;
    }
  }
}
