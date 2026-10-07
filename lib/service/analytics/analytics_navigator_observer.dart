import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:salatime/service/analytics/app_analytics_service.dart';
import 'package:salatime/service/analytics/screen_catalog.dart';

typedef AnalyticsScreenCallback = FutureOr<void> Function(String screenName);

/// Only app-owned page names are recorded. Dialogs, sheets, arbitrary route
/// strings and all arguments are excluded, including during back navigation.
class AnalyticsNavigatorObserver extends NavigatorObserver {
  AnalyticsNavigatorObserver({AnalyticsScreenCallback? onScreenViewed})
    : _onScreenViewed = onScreenViewed;

  final AnalyticsScreenCallback? _onScreenViewed;
  final List<Route<dynamic>> _pages = [];
  String? _lastScreen;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute) return;
    _pages.add(route);
    _report(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute) return;
    _pages.remove(route);
    _report(_pages.lastOrNull);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute) return;
    final wasVisible = identical(_pages.lastOrNull, route);
    _pages.remove(route);
    if (wasVisible) _report(_pages.lastOrNull);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute == null) return;
    final index = _pages.indexOf(oldRoute);
    if (index < 0) return;
    final wasVisible = index == _pages.length - 1;
    if (newRoute is PageRoute) {
      _pages[index] = newRoute;
    } else {
      _pages.removeAt(index);
    }
    if (wasVisible) _report(_pages.lastOrNull);
  }

  void _report(Route<dynamic>? route) {
    final screen = AnalyticsScreenCatalog.fromRoute(route);
    if (screen == null) {
      _lastScreen = null;
      return;
    }
    if (screen == _lastScreen) return;
    _lastScreen = screen;
    unawaited(
      Future<void>.sync(
        () => (_onScreenViewed ?? AppAnalyticsService.instance.screenViewed)(
          screen,
        ),
      ).catchError((Object _) {
        // Optional statistics must never affect navigation or offline use.
      }),
    );
  }
}
