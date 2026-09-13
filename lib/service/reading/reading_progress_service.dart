import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:zabi/helper/athkar_catalog.dart';
import 'package:zabi/service/cloud/preference_sync_scheduler.dart';
import 'package:zabi/service/mobile_auth_service.dart';
import 'reading_progress_models.dart';
import 'reading_progress_remote.dart';
import 'reading_progress_store.dart';

export 'reading_progress_models.dart';
export 'reading_progress_remote.dart';
export 'reading_progress_store.dart';

/// Explicit readings only. Guest history is never implicitly copied to an account.
class ReadingProgressService extends ChangeNotifier
    with WidgetsBindingObserver {
  ReadingProgressService({
    MobileAuthService? auth,
    ReadingProgressStore? store,
    ReadingProgressRemote? remote,
    AthkarCatalog? catalog,
    DateTime Function()? now,
    this.observeLifecycle = true,
    this.automaticSync = true,
    String Function()? operationId,
  }) : _auth = auth ?? MobileAuthService.instance,
       _store = store ?? SharedPreferencesReadingProgressStore(),
       _catalog = catalog,
       _now = now ?? DateTime.now,
       _operationId = operationId ?? _uuid {
    _remote = remote ?? HttpReadingProgressRemote(baseUrl: _auth.baseUrl);
    _scheduler = PreferenceSyncScheduler(
      synchronize: _sync,
      checkpoint: flushLocal,
      now: _now,
      onError: (_) {
        if (!_disposed) _setStatus('cloud_offline');
      },
    );
    _today = _day(_now());
  }

  static final instance = ReadingProgressService();
  final MobileAuthService _auth;
  final ReadingProgressStore _store;
  late final ReadingProgressRemote _remote;
  late final PreferenceSyncScheduler _scheduler;
  AthkarCatalog? _catalog;
  final DateTime Function() _now;
  final String Function() _operationId;
  final bool observeLifecycle;
  final bool automaticSync;
  final Map<String, _ReadingState> _states = {};
  final List<_Mutation> _pending = [];
  Map<String, ReadingProgressEntry> _visible = {};
  Map<String, ReadingDailyStats>? _dailyCache;
  ReadingProgressStats? _statsCache;
  Future<void>? _initializing;
  Future<void>? _syncing;
  Completer<void>? _queue;
  Worker? _authWorker;
  Timer? _midnight;
  String? _owner;
  String? _account;
  String? _token;
  int _generation = 0;
  bool _disposed = false;
  bool _foreground = true;
  bool _observing = false;
  bool initialized = false;
  String status = 'cloud_signed_out';
  late String _today;
  String get today => _day(_now());
  List<ReadingProgressEntry> get entries => List.unmodifiable(_visible.values);
  int get pendingOperationCount =>
      _state.outbox.length +
      _pending
          .where((m) => m.owner == _owner)
          .fold<int>(0, (n, m) => n + m.operations.length);
  _ReadingState get _state => _states[_owner] ?? _ReadingState();

  Future<void> initialize() {
    if (initialized) return Future.value();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _initialize() async {
    _catalog ??= await AthkarCatalog.load();
    if (_disposed) return;
    _authWorker ??= ever<MobileUser?>(_auth.user, (_) {
      unawaited(
        _selectSession().catchError((Object _) {
          _setStatus('cloud_offline');
        }),
      );
    });
    await _selectSession();
    if (observeLifecycle && !_disposed && !_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
      _armMidnight();
    }
    // Restoring the offline profile must not wait for a network /me response.
    unawaited(_auth.initialize().catchError((Object _) {}));
  }

  Future<void> _selectSession() async {
    final generation = ++_generation;
    final account = _auth.user.value?.id;
    final accountChanged = _owner == null || account != _account;
    if (accountChanged) {
      initialized = false;
      _scheduler.setEnabled(false);
      _visible = {};
      _invalidate();
    }
    final token = await _auth.accessToken();
    if (_disposed ||
        generation != _generation ||
        account != _auth.user.value?.id) {
      return;
    }
    if (!accountChanged && token == _token && initialized) {
      // A profile refresh must not cancel the pending edit debounce.
      if (automaticSync) unawaited(_scheduler.requestAutomatic());
      return;
    }
    if (!accountChanged) {
      initialized = false;
      _scheduler.setEnabled(false);
    }
    final owner =
        'reading_progress_v1_${sha256.convert(utf8.encode(jsonEncode([_auth.baseUrl, account == null ? 'guest' : 'account', account])))}';
    await _serial(() async {
      if (!_states.containsKey(owner)) {
        _states[owner] = _decodeState(await _store.read(owner));
      }
      if (_disposed || generation != _generation) return;
      _owner = owner;
      _account = account;
      _token = token;
      initialized = true;
      _rebuild();
      _setStatus(
        account == null
            ? 'cloud_signed_out'
            : _state.outbox.isEmpty
            ? 'cloud_synced'
            : 'cloud_pending',
      );
      _scheduler.setEnabled(automaticSync && account != null && token != null);
      if (automaticSync) unawaited(_scheduler.requestAutomatic());
    });
  }

  int target(ReadingProgressKind kind, String itemKey) {
    if (kind == ReadingProgressKind.quran) {
      if (!QuranReadingKeys.contains(itemKey)) {
        throw ArgumentError('Invalid Quran verse');
      }
      return 1;
    }
    final entry = _catalog?.entry(itemKey);
    if (entry == null) throw ArgumentError('Unknown Athkar entry');
    return entry.repetitions ?? 1;
  }

  int count(ReadingProgressKind kind, String itemKey, {String? day}) =>
      _visible['${kind.name}|${day ?? today}|$itemKey']?.count ?? 0;
  int todayCount(ReadingProgressKind kind, String itemKey) =>
      count(kind, itemKey);
  bool isComplete(ReadingProgressKind kind, String itemKey, {String? day}) =>
      count(kind, itemKey, day: day) >= target(kind, itemKey);

  Future<void> increment(
    ReadingProgressKind kind,
    String itemKey, {
    String? day,
  }) {
    if (!initialized) {
      return initialize().then((_) => increment(kind, itemKey, day: day));
    }
    return setCount(
      kind,
      itemKey,
      min(target(kind, itemKey), count(kind, itemKey, day: day) + 1),
      day: day,
    );
  }

  Future<void> setCount(
    ReadingProgressKind kind,
    String itemKey,
    int value, {
    String? day,
  }) => setMany(kind, {itemKey: value}, day: day);

  Future<void> setMany(
    ReadingProgressKind kind,
    Map<String, int> counts, {
    String? day,
  }) {
    if (!initialized) {
      return initialize().then((_) => setMany(kind, counts, day: day));
    }
    if (_disposed) {
      return Future.error(StateError('Reading service is disposed'));
    }
    final selectedDay = day ?? today;
    if (!_validDay(selectedDay)) {
      return Future.error(ArgumentError('Invalid reading day'));
    }
    final operations = <ReadingProgressOperation>[];
    try {
      for (final entry in counts.entries) {
        if (entry.value < 0 || entry.value > target(kind, entry.key)) {
          throw RangeError('Invalid reading count');
        }
        if (count(kind, entry.key, day: selectedDay) == entry.value) continue;
        operations.add(
          ReadingProgressOperation(
            id: _operationId(),
            entry: ReadingProgressEntry(
              kind: kind,
              itemKey: entry.key,
              day: selectedDay,
              count: entry.value,
            ),
          ),
        );
      }
    } catch (error) {
      return Future.error(error);
    }
    if (operations.isEmpty) return Future.value();
    final mutation = _Mutation(_owner!, _account != null, operations);
    _pending.add(mutation);
    _rebuild(); // Taps see the latest count before any storage or network await.
    if (mutation.account) _setStatus('cloud_pending');
    _scheduler.noteChange();
    return _serial(() async {
      try {
        final candidate = _states[mutation.owner]!.copy();
        if (mutation.account) {
          candidate.outbox.addAll(operations);
        } else {
          for (final operation in operations) {
            candidate.entries[operation.entry.key] = operation.entry;
          }
        }
        await _store.write(mutation.owner, candidate.json());
        _states[mutation.owner] = candidate;
      } catch (_) {
        if (_owner == mutation.owner && mutation.account) {
          _setStatus('cloud_offline');
        }
        rethrow;
      } finally {
        _pending.remove(mutation);
        if (_owner == mutation.owner && !_disposed) _rebuild();
      }
    });
  }

  /// Waits only for local atomic writes, never for an HTTP request.
  Future<void> flushLocal() async {
    while (_queue != null) {
      await _queue!.future;
    }
  }

  /// Opening history follows the automatic edit debounce; only Sync now bypasses it.
  Future<void> loadHistory() async {
    await initialize();
    if (automaticSync) await _scheduler.requestAutomatic();
  }

  Future<void> syncNow() async {
    await initialize();
    if (_account == null || _token == null) return;
    if (automaticSync) {
      await _scheduler.requestNow();
    } else {
      await _sync();
    }
  }

  Future<void> _sync() =>
      _syncing ??= _synchronize().whenComplete(() => _syncing = null);

  Future<bool> _current(String owner, int generation, String token) async {
    final currentToken = await _auth.accessToken();
    return !_disposed &&
        generation == _generation &&
        owner == _owner &&
        _account == _auth.user.value?.id &&
        token == currentToken;
  }

  Future<void> _synchronize() async {
    await flushLocal();
    final owner = _owner;
    final token = _token;
    final generation = _generation;
    if (!initialized || _account == null || owner == null || token == null) {
      return;
    }
    if (!await _current(owner, generation, token)) return;
    _setStatus('cloud_syncing');
    try {
      // Freeze this run's IDs. New edits retain their own debounce and outbox.
      final ids = _state.outbox.map((op) => op.id).toSet();
      while (ids.isNotEmpty) {
        if (!await _current(owner, generation, token)) return;
        final batch = _states[owner]!.outbox
            .where((op) => ids.contains(op.id))
            .take(100)
            .toList();
        if (batch.isEmpty) break;
        final reply = await _remote.push(token, batch);
        if (!await _current(owner, generation, token)) return;
        final sent = batch.map((op) => op.id).toSet();
        final acknowledged = reply.acknowledged.where(sent.contains).toSet();
        if (acknowledged.isEmpty) {
          throw const FormatException('No reading operations acknowledged');
        }
        final remoteEntries = reply.entries
            .map((json) => _parseEntry(json, remote: true))
            .toList();
        await _commitRemote(
          owner,
          generation,
          remoteEntries,
          acknowledged: acknowledged,
        );
        ids.removeAll(acknowledged);
        if (acknowledged.length != sent.length) break;
      }
      while (await _current(owner, generation, token)) {
        final after = _states[owner]!.cursor;
        final page = await _remote.pull(token, after);
        if (!await _current(owner, generation, token)) return;
        if (page.cursor < after ||
            (page.hasMore && (page.cursor == after || page.entries.isEmpty))) {
          throw const FormatException('Invalid reading pagination');
        }
        final records = page.entries
            .map((json) => _parseEntry(json, remote: true))
            .toList();
        var lastRevision = after;
        for (final record in records) {
          if (record.revision <= lastRevision) {
            throw const FormatException('Invalid reading revision order');
          }
          lastRevision = record.revision;
        }
        // GET's cursor describes exactly the returned page, never unseen rows.
        if (page.cursor != lastRevision ||
            page.cursor > 9007199254740991 ||
            records.length > 500) {
          throw const FormatException('Invalid reading cursor');
        }
        await _commitRemote(owner, generation, records, cursor: page.cursor);
        if (!page.hasMore) break;
      }
      if (await _current(owner, generation, token)) {
        _setStatus(
          pendingOperationCount == 0 ? 'cloud_synced' : 'cloud_pending',
        );
      }
    } catch (error) {
      if (!await _current(owner, generation, token)) return;
      _setStatus('cloud_offline');
      if (error is ReadingProgressRemoteException && error.statusCode == 401) {
        // A rejection of an old bearer must never log out a newer session.
        if (await _current(owner, generation, token) &&
            generation == _generation &&
            _account == _auth.user.value?.id) {
          await _auth.clearSession(expectedToken: token);
        }
      }
      rethrow;
    }
  }

  Future<void> _commitRemote(
    String owner,
    int generation,
    List<ReadingProgressEntry> records, {
    Set<String> acknowledged = const {},
    int? cursor,
  }) => _serial(() async {
    if (generation != _generation || _disposed) return;
    final candidate = _states[owner]!.copy();
    for (final record in records) {
      if (record.revision >= (candidate.entries[record.key]?.revision ?? -1)) {
        candidate.entries[record.key] = record;
      }
    }
    candidate.outbox.removeWhere(
      (operation) => acknowledged.contains(operation.id),
    );
    if (cursor != null) candidate.cursor = cursor;
    await _store.write(owner, candidate.json());
    _states[owner] = candidate;
    if (owner == _owner && generation == _generation && !_disposed) _rebuild();
  });

  _ReadingState _decodeState(Map<String, dynamic>? json) {
    if (json == null) return _ReadingState();
    if (json['schema'] != 1 ||
        json['cursor'] is! int ||
        json['cursor'] < 0 ||
        json['entries'] is! List ||
        json['outbox'] is! List) {
      throw const FormatException('Invalid reading cache');
    }
    final state = _ReadingState(cursor: json['cursor']);
    for (final raw in json['entries']) {
      final entry = _parseEntry(Map<String, dynamic>.from(raw as Map));
      state.entries[entry.key] = entry;
    }
    final ids = <String>{};
    for (final raw in json['outbox']) {
      final id = raw['id'];
      if (id is! String || !_validUuid(id) || !ids.add(id)) {
        throw const FormatException('Invalid reading outbox');
      }
      state.outbox.add(
        ReadingProgressOperation(
          id: id,
          entry: _parseEntry(Map<String, dynamic>.from(raw as Map)),
        ),
      );
    }
    return state;
  }

  ReadingProgressEntry _parseEntry(
    Map<String, dynamic> json, {
    bool remote = false,
  }) {
    final kind = switch (json['kind']) {
      'athkar' => ReadingProgressKind.athkar,
      'quran' => ReadingProgressKind.quran,
      _ => throw const FormatException('Invalid reading kind'),
    };
    final key = json['itemKey'];
    final day = json['day'];
    final value = json['count'];
    final revision = json['revision'] ?? (remote ? null : 0);
    if (key is! String ||
        day is! String ||
        !_validDay(day) ||
        value is! int ||
        revision is! int ||
        revision < (remote ? 1 : 0) ||
        revision > 9007199254740991) {
      throw const FormatException('Invalid reading record');
    }
    if (value < 0 || value > target(kind, key)) {
      throw const FormatException('Invalid reading count');
    }
    return ReadingProgressEntry(
      kind: kind,
      itemKey: key,
      day: day,
      count: value,
      revision: revision,
    );
  }

  Future<T> _serial<T>(Future<T> Function() work) async {
    final previous = _queue;
    final barrier = Completer<void>();
    _queue = barrier;
    if (previous != null) await previous.future;
    try {
      return await work();
    } finally {
      if (identical(_queue, barrier)) _queue = null;
      barrier.complete();
    }
  }

  void _rebuild() {
    final visible = Map<String, ReadingProgressEntry>.of(_state.entries);
    for (final operation in _state.outbox) {
      visible[operation.entry.key] = operation.entry;
    }
    for (final mutation in _pending.where((m) => m.owner == _owner)) {
      for (final operation in mutation.operations) {
        visible[operation.entry.key] = operation.entry;
      }
    }
    _visible = visible;
    _invalidate();
  }

  void _invalidate() {
    _dailyCache = null;
    _statsCache = null;
    if (!_disposed) notifyListeners();
  }

  void _setStatus(String value) {
    if (!_disposed && status != value) {
      status = value;
      notifyListeners();
    }
  }

  Map<String, ReadingDailyStats> get _days {
    if (_dailyCache != null) return _dailyCache!;
    final athkar = <String, List<int>>{};
    final verses = <String, Map<int, Set<int>>>{};
    for (final entry in _visible.values.where((e) => e.count > 0)) {
      if (entry.kind == ReadingProgressKind.athkar) {
        final values = athkar.putIfAbsent(entry.day, () => [0, 0]);
        values[1] += entry.count;
        if (entry.count >= target(entry.kind, entry.itemKey)) values[0]++;
      } else {
        final parts = entry.itemKey.split(':').map(int.parse).toList();
        verses
            .putIfAbsent(entry.day, () => {})
            .putIfAbsent(parts[0], () => {})
            .add(parts[1]);
      }
    }
    return _dailyCache = {
      for (final day in {...athkar.keys, ...verses.keys})
        day: ReadingDailyStats(
          day: day,
          athkarCompleted: athkar[day]?[0] ?? 0,
          athkarRepetitions: athkar[day]?[1] ?? 0,
          quranVerses:
              verses[day]?.values.fold<int>(0, (n, set) => n + set.length) ?? 0,
          quranSurahs:
              verses[day]?.entries
                  .where(
                    (e) =>
                        e.value.length ==
                        QuranReadingKeys.verseCounts[e.key - 1],
                  )
                  .length ??
              0,
        ),
    };
  }

  ReadingDailyStats statsForDay(String day) =>
      _days[day] ?? ReadingDailyStats(day: day);
  List<ReadingDailyStats> lastDays([int days = 7]) {
    if (days < 1 || days > 36600) throw RangeError.range(days, 1, 36600);
    final now = _now();
    return List.unmodifiable(
      List.generate(
        days,
        (index) => statsForDay(
          _day(DateTime(now.year, now.month, now.day - days + index + 1)),
        ),
      ),
    );
  }

  ReadingProgressStats get stats {
    if (_today != today) {
      _today = today;
      _statsCache = null;
    }
    if (_statsCache != null) return _statsCache!;
    final daily = statsForDay(today);
    final now = _now();
    var date = DateTime(now.year, now.month, now.day);
    if (!statsForDay(_day(date)).active) {
      date = DateTime(date.year, date.month, date.day - 1);
    }
    var streak = 0;
    while (statsForDay(_day(date)).active) {
      streak++;
      date = DateTime(date.year, date.month, date.day - 1);
    }
    return _statsCache = ReadingProgressStats(
      todayAthkarCompleted: daily.athkarCompleted,
      todayQuranVerses: daily.quranVerses,
      todayQuranSurahs: daily.quranSurahs,
      quranUniqueVerses: _visible.values
          .where((e) => e.kind == ReadingProgressKind.quran && e.count == 1)
          .map((e) => e.itemKey)
          .toSet()
          .length,
      lifetimeAthkarCompleted: _days.values.fold(
        0,
        (n, day) => n + day.athkarCompleted,
      ),
      currentStreak: streak,
      activeDays: _days.values.where((day) => day.active).length,
      last7Days: lastDays(),
    );
  }

  void refreshDay() {
    if (_today != today) {
      _today = today;
      _invalidate();
    }
  }

  void _armMidnight() {
    _midnight?.cancel();
    if (!observeLifecycle || !_foreground || _disposed) return;
    final now = _now();
    _midnight = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      () {
        refreshDay();
        _armMidnight();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _scheduler.setForeground(_foreground);
    if (_foreground) {
      refreshDay();
      _armMidnight();
      if (automaticSync) unawaited(_scheduler.requestAutomatic());
    } else {
      _midnight?.cancel();
      unawaited(flushLocal());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _scheduler.dispose();
    _midnight?.cancel();
    _authWorker?.dispose();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static bool _validDay(String day) {
    if (!RegExp(
      r'^20[0-9]{2}-[0-9]{2}-[0-9]{2}$|^2100-[0-9]{2}-[0-9]{2}$',
    ).hasMatch(day)) {
      return false;
    }
    final date = DateTime.tryParse(day);
    return date != null && _day(date) == day;
  }

  static bool _validUuid(String value) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
  static String _uuid() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

class _Mutation {
  _Mutation(this.owner, this.account, this.operations);
  final String owner;
  final bool account;
  final List<ReadingProgressOperation> operations;
}

class _ReadingState {
  _ReadingState({this.cursor = 0});
  final entries = <String, ReadingProgressEntry>{};
  final outbox = <ReadingProgressOperation>[];
  int cursor;
  _ReadingState copy() => _ReadingState(cursor: cursor)
    ..entries.addAll(entries)
    ..outbox.addAll(outbox);
  Map<String, dynamic> json() => {
    'schema': 1,
    'cursor': cursor,
    'entries': entries.values.map((e) => e.toJson()).toList(),
    'outbox': outbox.map((op) => op.toJson()).toList(),
  };
}
