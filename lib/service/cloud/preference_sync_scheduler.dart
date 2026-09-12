import 'dart:async';

/// Batches automatic cloud work after edits settle. Persisting an outbox never
/// requires a network connection, and no UI callback awaits this scheduler.
class PreferenceSyncScheduler {
  PreferenceSyncScheduler({
    required this.synchronize,
    required this.checkpoint,
    this.onError,
    this.quietPeriod = const Duration(seconds: 60),
    this.pollInterval = const Duration(seconds: 30),
    this.checkpointDelay = const Duration(milliseconds: 500),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Future<void> Function() synchronize;
  final Future<void> Function() checkpoint;
  final void Function(Object error)? onError;
  final Duration quietPeriod;
  final Duration pollInterval;
  final Duration checkpointDelay;
  final DateTime Function() _now;
  Timer? _quietTimer;
  Timer? _pollTimer;
  Timer? _checkpointTimer;
  DateTime? _notBefore;
  Future<void>? _running;
  Future<void>? _saving;
  bool _enabled = false;
  bool _foreground = true;
  bool _disposed = false;
  bool _autoQueued = false;

  bool get _active => _enabled && _foreground && !_disposed;

  void setEnabled(bool enabled) {
    if (_disposed) return;
    _enabled = enabled;
    if (!enabled) {
      _notBefore = null;
      _autoQueued = false;
      _checkpointTimer?.cancel();
    }
    _restartTimers();
  }

  void setForeground(bool foreground) {
    if (_disposed) return;
    _foreground = foreground;
    _restartTimers();
    if (!foreground) {
      _checkpointTimer?.cancel();
      unawaited(saveLocal());
    }
  }

  void _restartTimers() {
    _quietTimer?.cancel();
    _pollTimer?.cancel();
    if (!_active) return;
    _pollTimer = Timer.periodic(pollInterval, (_) {
      unawaited(requestAutomatic());
    });
    if (_notBefore != null) _armQuietTimer();
  }

  void noteChange() {
    if (!_enabled || _disposed) return;
    _notBefore = _now().add(quietPeriod);
    _checkpointTimer?.cancel();
    _checkpointTimer = Timer(checkpointDelay, () => unawaited(saveLocal()));
    if (_active) _armQuietTimer();
  }

  void _armQuietTimer() {
    _quietTimer?.cancel();
    if (!_active || _notBefore == null) return;
    final wait = _notBefore!.difference(_now());
    _quietTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
      unawaited(requestAutomatic());
    });
  }

  Future<void> saveLocal() {
    if (!_enabled || _disposed) return Future.value();
    if (_saving != null) return _saving!;
    final task = _persist();
    _saving = task;
    return task;
  }

  Future<void> _persist() async {
    try {
      await Future<void>.sync(checkpoint);
    } catch (error) {
      if (!_disposed) onError?.call(error);
    } finally {
      _saving = null;
    }
  }

  Future<void> requestAutomatic() {
    if (!_active) return Future.value();
    if (_notBefore != null && _now().isBefore(_notBefore!)) {
      _armQuietTimer();
      return Future.value();
    }
    if (_running != null) {
      _autoQueued = true;
      return _running!;
    }
    _quietTimer?.cancel();
    _notBefore = null;
    return _start();
  }

  /// A deliberate "sync now" bypasses the edit debounce, but still shares one run.
  Future<void> requestNow() {
    if (!_enabled || _disposed) return Future.value();
    _quietTimer?.cancel();
    _notBefore = null;
    if (_running != null) {
      _autoQueued = true;
      return _running!;
    }
    return _start();
  }

  Future<void> _start() {
    final task = _execute();
    _running = task;
    return task;
  }

  Future<void> _execute() async {
    try {
      await Future<void>.sync(synchronize);
    } catch (error) {
      if (!_disposed) onError?.call(error);
    } finally {
      _running = null;
      if (_autoQueued && _active) {
        _autoQueued = false;
        unawaited(requestAutomatic());
      }
    }
  }

  void dispose() {
    _disposed = true;
    _quietTimer?.cancel();
    _pollTimer?.cancel();
    _checkpointTimer?.cancel();
    _autoQueued = false;
  }
}
