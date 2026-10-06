import 'dart:convert';
import 'preference_schema.dart';

typedef Document = Map<String, dynamic>;

class CloudDocument {
  const CloudDocument(this.version, this.preferences);
  final int version;
  final Document preferences;
}

class PreferenceConflict implements Exception {
  PreferenceConflict(this.current);
  final CloudDocument current;
}

abstract class PreferenceRemote {
  Future<CloudDocument> get(String account);
  Future<CloudDocument> put(String account, int version, Document preferences);
}

abstract class PreferenceDevice {
  Future<Document> capture();
  Future<void> apply(Document preferences);
  Future<Document?> readCache(String key);
  Future<void> writeCache(String key, Document value);
}

/// Devices with asynchronous writes can stop a stale cloud restoration as soon
/// as the user edits locally. Plain in-memory devices keep the original API.
abstract class GuardedPreferenceDevice implements PreferenceDevice {
  Future<bool> applyIfCurrent(Document preferences, bool Function() isCurrent);
}

/// Serializes local mutations and checks the account generation after every
/// network wait. A late response from account A can never touch account B.
class PreferenceSyncEngine {
  PreferenceSyncEngine(
    this.remote,
    this.device, {
    this.onStatus,
    Document? initialLanguageChoice,
  }) : _initialLanguageChoice = _languageChoice(initialLanguageChoice);
  final PreferenceRemote remote;
  final PreferenceDevice device;
  final void Function(String)? onStatus;
  String? account;
  int _generation = 0;
  String? _deviceOwner;
  Document? _deviceLanguage;
  bool _ownerLoaded = false;
  Future<void> _queue = Future.value();
  bool _applyingPreferences = false;
  bool get isApplyingPreferences => _applyingPreferences;
  int _localRevision = 0;
  void noteLocalChange() => _localRevision++;
  final Document? _initialLanguageChoice;
  Document? _pendingLanguageChoice;
  String? _pendingLanguageOwner;
  Document? _accountLanguageFallback;
  static Document? _languageChoice(Document? value) {
    if (value == null) return null;
    final clean = PreferenceSchema.clean({
      'language': value['language'],
      'country': value['country'],
    });
    return clean.containsKey('language') ? clean : null;
  }

  /// A guest's deliberate language selection is the only first-login override.
  /// Other settings still restore from the existing account document.
  void noteLanguageChoice(Document choice) {
    final clean = _languageChoice(choice);
    if (clean == null) return;
    _pendingLanguageChoice = clean;
    _pendingLanguageOwner = account;
    if (_deviceOwner == account) _deviceLanguage = clean;
    noteLocalChange();
  }

  Document? _choiceFor(String? owner) =>
      _pendingLanguageOwner == owner ? _pendingLanguageChoice : null;
  static Document? _cachedChoice(Object? value) =>
      value is Map ? _languageChoice(Map<String, dynamic>.from(value)) : null;
  String status = 'cloud_signed_out';
  Document? _conflictLocal;
  CloudDocument? _conflictRemote;
  void _state(String value) {
    status = value;
    onStatus?.call(value);
  }

  Future<void> _serial(Future<void> Function() work) {
    final result = _queue.then((_) => work());
    _queue = result.catchError((_) {});
    return result;
  }

  bool _current(String id, int generation) =>
      account == id && _generation == generation;
  static dynamic _canonical(dynamic value) {
    // JSON servers may serialize 22.0 as 22. Both describe the same preference.
    if (value is double &&
        value.isFinite &&
        value == value.truncateToDouble()) {
      return value.toInt();
    }
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  static bool same(dynamic a, dynamic b) =>
      jsonEncode(_canonical(a)) == jsonEncode(_canonical(b));
  static String _key(String id) => 'account:$id';

  Future<bool> _apply(Document preferences, {int? localRevision}) async {
    final generation = _generation;
    bool current() =>
        generation == _generation &&
        (localRevision == null || localRevision == _localRevision);
    if (!current()) return false;
    _applyingPreferences = true;
    try {
      if (device is GuardedPreferenceDevice) {
        return await (device as GuardedPreferenceDevice).applyIfCurrent(
          preferences,
          current,
        );
      }
      await device.apply(preferences);
      return true;
    } finally {
      _applyingPreferences = false;
    }
  }

  /// Persist the current account's outbox without starting an HTTP request.
  /// Native settings are already durable; this also keeps its account backup current.
  Future<void> checkpoint() {
    final id = account;
    final generation = _generation;
    if (id == null) return Future.value();
    return _serial(() async {
      if (!_current(id, generation)) return;
      final local = PreferenceSchema.clean(await device.capture());
      if (!_current(id, generation)) return;
      final saved = await device.readCache(_key(id)) ?? {};
      if (!_current(id, generation)) return;
      final choice = _choiceFor(id);
      if (choice != null) local.addAll(choice);
      _deviceLanguage = _languageChoice(local);
      await device.writeCache(_key(id), {
        ...saved,
        'local': local,
        'languageChoice': ?choice,
      });
    });
  }

  Future<void> selectAccount(
    String? next, {
    bool synchronize = true,
    Document? languageFallback,
  }) {
    if (account == next) return Future.value();
    final previousChoice = _pendingLanguageChoice;
    final previousChoiceOwner = _pendingLanguageOwner;
    if (_pendingLanguageOwner != null && _pendingLanguageOwner != next) {
      _pendingLanguageChoice = null;
      _pendingLanguageOwner = null;
    }
    if (_pendingLanguageChoice != null && next != null) {
      _pendingLanguageOwner = next;
    }
    _accountLanguageFallback = _languageChoice(languageFallback);
    final generation = ++_generation;
    account = next;
    _conflictLocal = null;
    _conflictRemote = null;
    _state(next == null ? 'cloud_signed_out' : 'cloud_syncing');
    return _serial(() async {
      if (generation != _generation) return;
      if (!_ownerLoaded) {
        final savedOwner = await device.readCache('deviceOwner');
        if (generation != _generation) return;
        _deviceOwner = savedOwner?['id'] as String?;
        _ownerLoaded = true;
        if (_deviceOwner == null) {
          _pendingLanguageChoice ??= _initialLanguageChoice;
          if (_pendingLanguageChoice != null) _pendingLanguageOwner = next;
        }
      }
      final selectionRevision = _localRevision;
      final local = PreferenceSchema.clean(await device.capture());
      if (_deviceOwner != null) {
        final saved = await device.readCache(_key(_deviceOwner!)) ?? {};
        final ownedChoice = previousChoiceOwner == _deviceOwner
            ? previousChoice
            : null;
        if (ownedChoice != null) {
          local.addAll(ownedChoice);
        } else if (_choiceFor(next) != null && next != _deviceOwner) {
          // A selection for the next account can occur before this capture.
          // Preserve the actual previous owner's locale in its own outbox.
          final ownedLanguage =
              _cachedChoice(saved['local']) ??
              _deviceLanguage ??
              _initialLanguageChoice;
          local.remove('language');
          local.remove('country');
          local.addAll(ownedLanguage ?? {});
        }
        await device.writeCache(_key(_deviceOwner!), {
          ...saved,
          'local': local,
          'languageChoice': ?ownedChoice,
        });
      } else {
        await device.writeCache('guest', {'local': local});
      }
      if (generation != _generation) return;
      final saved = next == null
          ? await device.readCache('guest')
          : await device.readCache(_key(next));
      final guest = await device.readCache('guest');
      final target = PreferenceSchema.clean(
        saved?['local'] ?? guest?['local'] ?? local,
      );
      if (generation != _generation) return;
      if (next != null) {
        if (saved == null) target.addAll(_accountLanguageFallback ?? {});
        target.addAll(
          _choiceFor(next) ?? _cachedChoice(saved?['languageChoice']) ?? {},
        );
      }
      await _apply(target, localRevision: selectionRevision);
      if (generation != _generation) return;
      final selectedLocal = PreferenceSchema.clean(await device.capture());
      if (generation != _generation) return;
      _deviceOwner = next;
      _deviceLanguage = _languageChoice(selectedLocal);
      await device.writeCache('deviceOwner', {'id': next});
      if (synchronize && next != null && _current(next, generation)) {
        await _sync(next, generation);
      }
    });
  }

  Future<void> sync() {
    final id = account;
    final generation = _generation;
    if (id == null) return Future.value();
    return _serial(
      () => _current(id, generation) ? _sync(id, generation) : Future.value(),
    );
  }

  Future<void> _sync(String id, int generation, {bool? keepLocal}) async {
    final saved = await device.readCache(_key(id)) ?? {};
    final languageChoice =
        _choiceFor(id) ?? _cachedChoice(saved['languageChoice']);
    final local = PreferenceSchema.clean(await device.capture());
    final base = PreferenceSchema.clean(saved['base']);
    await device.writeCache(_key(id), {
      ...saved,
      'local': local,
      'languageChoice': ?languageChoice,
    }); // Outbox survives process death before the network starts.
    if (keepLocal == null && _conflictRemote != null) {
      _state('cloud_conflict');
      return;
    }
    _state('cloud_syncing');
    try {
      var remoteDoc = await remote.get(id);
      if (!_current(id, generation)) return;
      for (var attempt = 0; attempt < 3; attempt++) {
        final remotePrefs = PreferenceSchema.clean(remoteDoc.preferences);
        final localFlat = PreferenceSchema.flatten(local),
            baseFlat = PreferenceSchema.flatten(base),
            remoteFlat = PreferenceSchema.flatten(remotePrefs);
        final effectiveRemote = <String, dynamic>{
          ...remoteFlat,
          if (!remoteFlat.containsKey('language')) ...?_accountLanguageFallback,
        };
        final merged = <String, dynamic>{...effectiveRemote};
        final conflicts = <String>[];
        if (keepLocal == false) {
          // Explicitly choosing the account copy discards this device's conflicting edits.
        } else if (base.isEmpty) {
          if (remoteDoc.version == 0 || remotePrefs.isEmpty) {
            merged.addAll(localFlat);
          }
          if (!remoteFlat.containsKey('language')) {
            merged.addAll(_accountLanguageFallback ?? {});
          }
          // First login on another device restores the existing account before uploading anything.
          // Preserve just an explicit guest language, never a full local snapshot.
          if (languageChoice != null) merged.addAll(languageChoice);
        } else {
          for (final key in {...baseFlat.keys, ...localFlat.keys}) {
            if (same(localFlat[key], baseFlat[key])) continue;
            final selectedCountry =
                key == 'country' &&
                languageChoice != null &&
                (same(effectiveRemote['language'], baseFlat['language']) ||
                    same(effectiveRemote['language'], localFlat['language']));
            if (keepLocal != true &&
                !selectedCountry &&
                !same(effectiveRemote[key], baseFlat[key]) &&
                !same(effectiveRemote[key], localFlat[key])) {
              conflicts.add(key);
            }
            if (localFlat.containsKey(key)) {
              merged[key] = localFlat[key];
            } else {
              merged.remove(key);
            }
          }
        }
        if (conflicts.isNotEmpty) {
          _conflictLocal = local;
          _conflictRemote = remoteDoc;
          _state('cloud_conflict');
          return;
        }
        var result = CloudDocument(
          remoteDoc.version,
          PreferenceSchema.expand(merged),
        );
        try {
          if (!same(PreferenceSchema.flatten(result.preferences), remoteFlat)) {
            result = await remote.put(
              id,
              remoteDoc.version,
              result.preferences,
            );
          }
        } on PreferenceConflict catch (e) {
          remoteDoc = e.current;
          continue;
        }
        if (!_current(id, generation)) return;
        _accountLanguageFallback =
            _languageChoice(result.preferences) ?? _accountLanguageFallback;
        // Edits made while an HTTP request was pending win locally and become the next outbox.
        final applyRevision = _localRevision;
        final latest = PreferenceSchema.flatten(
          PreferenceSchema.clean(await device.capture()),
        );
        final applied = PreferenceSchema.flatten(
          PreferenceSchema.clean(result.preferences),
        );
        for (final key in {...latest.keys, ...localFlat.keys}) {
          if (!same(latest[key], localFlat[key])) {
            if (latest.containsKey(key)) {
              applied[key] = latest[key];
            } else {
              applied.remove(key);
            }
          }
        }
        final completed = await _apply(
          PreferenceSchema.expand(applied),
          localRevision: applyRevision,
        );
        if (!_current(id, generation)) return;
        final after = PreferenceSchema.clean(await device.capture());
        if (!_current(id, generation)) return;
        _deviceLanguage = _languageChoice(after);
        final acknowledgedLanguage =
            languageChoice != null &&
            (keepLocal == false ||
                languageChoice.entries.every(
                  (entry) => same(result.preferences[entry.key], entry.value),
                ));
        if (identical(_choiceFor(id), languageChoice) && acknowledgedLanguage) {
          _pendingLanguageChoice = null;
          _pendingLanguageOwner = null;
        }
        final pendingLanguage =
            _choiceFor(id) ?? (acknowledgedLanguage ? null : languageChoice);
        await device.writeCache(_key(id), {
          'version': result.version,
          // A superseded apply may have written only part of the remote copy.
          // Keep the earlier merge base so untouched remote fields can still
          // arrive on the next run, instead of becoming accidental local undo.
          'base': completed
              ? PreferenceSchema.clean(result.preferences)
              : (base.isEmpty ? local : base),
          'local': after,
          'languageChoice': ?pendingLanguage,
        });
        _conflictLocal = null;
        _conflictRemote = null;
        _state(
          completed &&
                  same(
                    PreferenceSchema.flatten(after),
                    PreferenceSchema.flatten(result.preferences),
                  )
              ? 'cloud_synced'
              : 'cloud_pending',
        );
        return;
      }
      _state('cloud_pending');
    } catch (_) {
      if (_current(id, generation)) _state('cloud_offline');
    }
  }

  Future<void> resolveConflict({required bool keepLocal}) {
    final id = account;
    final generation = _generation;
    if (id == null || _conflictLocal == null) return Future.value();
    return _serial(
      () => _current(id, generation)
          ? _sync(id, generation, keepLocal: keepLocal)
          : Future.value(),
    );
  }
}
