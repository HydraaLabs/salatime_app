import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Device-local invitation history. No satisfaction answer or rating is stored
/// or sent to account/cloud preferences; only invitation timing and opt-out.
class PlayStoreReviewService {
  PlayStoreReviewService({
    Future<SharedPreferences> Function()? preferences,
    DateTime Function()? now,
    Future<bool> Function(Uri)? openUrl,
    Future<bool> Function()? reviewAvailable,
    Future<void> Function()? requestReview,
    TargetPlatform Function()? platform,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now,
       _openUrl = openUrl ?? _launchExternal,
       _reviewAvailable = reviewAvailable ?? InAppReview.instance.isAvailable,
       _requestReview = requestReview ?? InAppReview.instance.requestReview,
       _platform = platform ?? (() => defaultTargetPlatform);

  static final instance = PlayStoreReviewService();
  static const storageKey = 'play_store_review_invitation_v1';
  static const minimumAge = Duration(days: 3);
  static const reminderDelay = Duration(days: 30);
  static const minimumDays = 3;
  static const maximumInvitations = 3;
  static final storeUri = Uri.https('play.google.com', '/store/apps/details', {
    'id': 'net.salatime.app',
  });
  static final appStoreUri = Uri.https('apps.apple.com', '/app/id6812923710', {
    'action': 'write-review',
  });

  final Future<SharedPreferences> Function() _preferences;
  final DateTime Function() _now;
  final Future<bool> Function(Uri) _openUrl;
  final Future<bool> Function() _reviewAvailable;
  final Future<void> Function() _requestReview;
  final TargetPlatform Function() _platform;
  Future<void> _pending = Future.value();

  static Future<bool> _launchExternal(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  // Serialize visits, automatic claims and manual actions so a late write
  // cannot undo a refusal or cause two simultaneous invitations.
  Future<T> _withState<T>(
    Future<T> Function(SharedPreferences, _ReviewHistory) action,
  ) {
    final result = Completer<T>();
    _pending = _pending.then((_) async {
      try {
        final prefs = await _preferences();
        final state = _ReviewHistory.read(prefs.getString(storageKey), _now());
        result.complete(await action(prefs, state));
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  Future<void> recordVisit() => _withState((prefs, state) async {
    if (state.stopped || state.days >= minimumDays) return;
    final now = _now();
    final day = _day(now);
    // Only advancing calendar dates count, never repeated resumes or clock
    // rewinds. Three days suffice; no unbounded usage history is retained.
    if (day.compareTo(state.lastDay) <= 0) return;
    state.lastDay = day;
    state.days = (state.days + 1).clamp(0, minimumDays);
    await _save(prefs, state);
  });

  bool _eligible(_ReviewHistory state, DateTime now) =>
      !state.stopped &&
      state.days >= minimumDays &&
      now.difference(state.firstUse) >= minimumAge &&
      state.invitations < maximumInvitations &&
      (state.lastInvitation == null ||
          now.difference(state.lastInvitation!) >= reminderDelay);

  /// Requests the system sheet directly, without filtering by satisfaction.
  /// A successful API call means only an attempt: the stores may suppress it.
  /// Visibility is checked again after every asynchronous preparation step.
  Future<bool> requestReviewIfEligible({required bool Function() canRequest}) =>
      _withState((prefs, state) async {
        if (kIsWeb ||
            (_platform() != TargetPlatform.android &&
                _platform() != TargetPlatform.iOS) ||
            !_eligible(state, _now()) ||
            !canRequest()) {
          return false;
        }
        try {
          if (!await _reviewAvailable() ||
              !canRequest() ||
              !_eligible(state, _now())) {
            return false;
          }
        } catch (_) {
          return false;
        }

        final previousInvitation = state.lastInvitation;
        final previousCount = state.invitations;
        state.lastInvitation = _now();
        state.invitations++;
        await _save(prefs, state);
        if (canRequest()) {
          try {
            await _requestReview();
            // No permanent opt-out or submitted-review flag can be inferred.
            return true;
          } catch (_) {
            // A missing plugin or native error must remain retryable.
          }
        }
        // Navigation during the durable reservation must not consume a
        // 30-day cooldown when the native API was never called.
        state.lastInvitation = previousInvitation;
        state.invitations = previousCount;
        await _save(prefs, state);
        return false;
      });

  Future<void> decline() => _withState((prefs, state) async {
    state.stopped = true;
    await _save(prefs, state);
  });

  /// Also used by the settings button. Opening the listing stops invitations;
  /// it does not mean a review was submitted (neither store provides a result).
  Future<bool> openStore() async {
    if (kIsWeb) return false;
    final uri = switch (_platform()) {
      TargetPlatform.android => storeUri,
      TargetPlatform.iOS => appStoreUri,
      _ => null,
    };
    if (uri == null) return false;
    bool opened;
    try {
      opened = await _openUrl(uri);
    } catch (_) {
      return false;
    }
    if (opened) {
      try {
        await decline();
      } catch (_) {
        // A local write failure must not misreport an already-opened Store.
      }
    }
    return opened;
  }

  static Future<void> _save(
    SharedPreferences prefs,
    _ReviewHistory state,
  ) async {
    if (!await prefs.setString(storageKey, jsonEncode(state.toJson()))) {
      throw StateError('Could not save review invitation history');
    }
  }

  static String _day(DateTime now) =>
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

class _ReviewHistory {
  _ReviewHistory(this.firstUse);
  final DateTime firstUse;
  String lastDay = '';
  int days = 0;
  int invitations = 0;
  DateTime? lastInvitation;
  bool stopped = false;

  static _ReviewHistory read(String? raw, DateTime now) {
    try {
      final json = jsonDecode(raw ?? '') as Map<String, dynamic>;
      if (json['version'] != 1) return _ReviewHistory(now);
      final state = _ReviewHistory(DateTime.parse(json['firstUse'] as String));
      state.lastDay = json['lastDay'] as String;
      state.days = (json['days'] as int).clamp(0, 3);
      state.invitations = (json['invitations'] as int).clamp(0, 3);
      state.stopped = json['stopped'] as bool;
      state.lastInvitation = json['lastInvitation'] == null
          ? null
          : DateTime.parse(json['lastInvitation'] as String);
      return state;
    } catch (_) {
      // Missing/corrupt state starts a fresh waiting period, never a prompt.
      return _ReviewHistory(now);
    }
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'firstUse': firstUse.toUtc().toIso8601String(),
    'lastDay': lastDay,
    'days': days,
    'invitations': invitations,
    'lastInvitation': lastInvitation?.toUtc().toIso8601String(),
    'stopped': stopped,
  };
}
