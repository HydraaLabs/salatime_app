import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Location dialogs belong to the app, rather than to an individual screen.
/// Share a foreground request and serialize Always requests across both plugins.
class LocationPermissionCoordinator {
  LocationPermissionCoordinator._();

  static final instance = LocationPermissionCoordinator._();

  Future<void>? _requests;
  Future<LocationPermission>? _foreground;
  List<bool Function()>? _foregroundOwners;
  Future<PermissionStatus>? _always;
  List<bool Function()>? _alwaysOwners;

  static bool get isForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  static bool isGranted(LocationPermission permission) =>
      permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always ||
      (kIsWeb && permission == LocationPermission.unableToDetermine);

  Future<T> _serialize<T>(Future<T> Function() action) {
    final previous = _requests;
    final result = previous == null
        ? Future<T>.sync(action)
        : previous.then((_) => action());
    // A failed native request must not block the next explicit attempt.
    late final Future<void> tail;
    void clear() {
      if (identical(_requests, tail)) _requests = null;
    }

    tail = result.then<void>(
      (_) => clear(),
      onError: (Object error, StackTrace stack) => clear(),
    );
    _requests = tail;
    return result;
  }

  bool _canPrompt(List<bool Function()> owners) =>
      isForeground && owners.any((owner) => owner());

  Future<LocationPermission> _shareForeground(
    Future<LocationPermission> Function(bool Function() canPrompt) action, {
    bool Function()? canRequest,
  }) {
    final owner = canRequest ?? () => true;
    final pending = _foreground;
    if (pending != null) {
      _foregroundOwners!.add(owner);
      return pending;
    }
    final owners = <bool Function()>[owner];
    _foregroundOwners = owners;
    final result = _serialize(() async {
      final permission = await action(() => _canPrompt(owners));
      // iOS can complete the permission future just before its dialog closes.
      // Let that lifecycle transition finish before starting GPS or Always.
      await _waitForForeground();
      return permission;
    });
    _foreground = result;
    void clear() {
      if (identical(_foreground, result)) {
        _foreground = null;
        _foregroundOwners = null;
      }
    }

    result.then<void>(
      (_) => clear(),
      onError: (Object error, StackTrace stack) => clear(),
    );
    return result;
  }

  Future<LocationPermission> ensureForeground({bool Function()? canRequest}) =>
      _shareForeground((canPrompt) async {
        final permission = await Geolocator.checkPermission();
        if (permission != LocationPermission.denied || !canPrompt()) {
          return permission;
        }
        return Geolocator.requestPermission();
      }, canRequest: canRequest);

  /// Travel settings already use permission_handler. They join the same
  /// foreground request even when another screen initiated it via Geolocator.
  Future<PermissionStatus> ensureForegroundWithPermissionHandler({
    bool Function()? canRequest,
  }) async {
    final permission = await _shareForeground((canPrompt) async {
      var status = await Permission.location.status;
      if (status.isDenied && canPrompt()) {
        status = await Permission.location.request();
      }
      if (status.isGranted) return LocationPermission.whileInUse;
      if (status.isPermanentlyDenied || status.isRestricted) {
        return LocationPermission.deniedForever;
      }
      return LocationPermission.denied;
    }, canRequest: canRequest);
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => PermissionStatus.granted,
      LocationPermission.deniedForever => PermissionStatus.permanentlyDenied,
      _ => PermissionStatus.denied,
    };
  }

  Future<PermissionStatus> ensureAlways({bool Function()? canRequest}) {
    final owner = canRequest ?? () => true;
    final pending = _always;
    if (pending != null) {
      _alwaysOwners!.add(owner);
      return pending;
    }
    final owners = <bool Function()>[owner];
    _alwaysOwners = owners;
    final result = _serialize(() async {
      final status = await Permission.locationAlways.status;
      if (!status.isDenied ||
          !await _waitForForeground() ||
          !_canPrompt(owners)) {
        return status;
      }
      if (!await Permission.location.isGranted || !_canPrompt(owners)) {
        return status;
      }
      final permission = await Permission.locationAlways.request();
      await _waitForForeground();
      return permission;
    });
    _always = result;
    void clear() {
      if (identical(_always, result)) {
        _always = null;
        _alwaysOwners = null;
      }
    }

    result.then<void>(
      (_) => clear(),
      onError: (Object error, StackTrace stack) => clear(),
    );
    return result;
  }
}

Future<bool> _waitForForeground() async {
  if (LocationPermissionCoordinator.isForeground) return true;
  if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.inactive) {
    return false;
  }
  final waiter = _DialogLifecycleWaiter();
  WidgetsBinding.instance.addObserver(waiter);
  final timeout = Timer(const Duration(seconds: 2), () => waiter.finish(false));
  try {
    return await waiter.result.future;
  } finally {
    timeout.cancel();
    WidgetsBinding.instance.removeObserver(waiter);
  }
}

class _DialogLifecycleWaiter with WidgetsBindingObserver {
  final result = Completer<bool>();

  void finish(bool foreground) {
    if (!result.isCompleted) result.complete(foreground);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) finish(true);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      finish(false);
    }
  }
}
