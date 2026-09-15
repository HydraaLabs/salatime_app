import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Device-local invitation history. No satisfaction answer or rating is stored
/// or sent to account/cloud preferences; only invitation timing and opt-out.
class PlayStoreReviewService {
  PlayStoreReviewService({
    Future<SharedPreferences> Function()? preferences,
    DateTime Function()? now,
    Future<bool> Function(Uri)? openUrl,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now,
       _openUrl = openUrl ?? _launchExternal;

  static final instance = PlayStoreReviewService();
  static const storageKey = 'play_store_review_invitation_v1';
  static const minimumAge = Duration(days: 3);
  static const reminderDelay = Duration(days: 30);
  static const minimumDays = 3;
  static const maximumInvitations = 3;
  static final storeUri = Uri.https('play.google.com', '/store/apps/details', {
    'id': 'net.salatime.app',
  });

  final Future<SharedPreferences> Function() _preferences;
  final DateTime Function() _now;
  final Future<bool> Function(Uri) _openUrl;
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

  /// Reserve the invitation durably BEFORE displaying it. Dismissing the
  /// dialog (including Back) thus has the same cooldown as "Later".
  Future<bool> claimInvitation() => _withState((prefs, state) async {
    final now = _now();
    if (state.stopped ||
        state.days < minimumDays ||
        now.difference(state.firstUse) < minimumAge ||
        state.invitations >= maximumInvitations ||
        (state.lastInvitation != null &&
            now.difference(state.lastInvitation!) < reminderDelay)) {
      return false;
    }
    state.lastInvitation = now;
    state.invitations++;
    await _save(prefs, state);
    return true;
  });

  Future<void> decline() => _withState((prefs, state) async {
    state.stopped = true;
    await _save(prefs, state);
  });

  /// Also used by the settings button. Opening the listing stops invitations;
  /// it does not mean a review was submitted (Google provides no such result).
  Future<bool> openStore() async {
    bool opened;
    try {
      opened = await _openUrl(storeUri);
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
