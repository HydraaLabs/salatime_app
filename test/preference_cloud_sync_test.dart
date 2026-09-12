import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:zabi/helper/notification_sound_catalog.dart';
import 'package:zabi/helper/prayer_notification_preferences.dart';
import 'package:zabi/helper/additional_reminder_plan.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/service/cloud/preference_device.dart';
import 'package:zabi/service/mobile_auth_service.dart';
import 'package:zabi/service/preference_cloud_sync.dart';
import 'package:zabi/service/cloud/preference_remote.dart';
import 'package:zabi/service/cloud/preference_schema.dart';
import 'package:zabi/service/cloud/preference_sync_engine.dart';

Document copy(Document value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)));

class FakeDevice implements PreferenceDevice {
  Document local = {'schemaVersion': 1, 'themeMode': 'light', 'language': 'fr'};
  final caches = <String, Document>{};
  @override
  Future<Document> capture() async => copy(local);
  @override
  Future<void> apply(Document values) async {
    local = copy(values);
  }

  @override
  Future<Document?> readCache(String key) async =>
      caches[key] == null ? null : copy(caches[key]!);
  @override
  Future<void> writeCache(String key, Document values) async {
    caches[key] = copy(values);
  }
}

class GuardedFakeDevice extends FakeDevice implements GuardedPreferenceDevice {
  Future<void> Function()? duringApply;
  @override
  Future<bool> applyIfCurrent(
    Document values,
    bool Function() isCurrent,
  ) async {
    if (!isCurrent()) return false;
    if (duringApply != null) {
      // One remote field landed before the user edited during an async wait.
      local['themeMode'] = values['themeMode'];
      await duringApply!();
    }
    if (!isCurrent()) return false;
    await apply(values);
    return true;
  }
}

class CloudTestSessionStore implements AuthSessionStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class FakeRemote implements PreferenceRemote {
  final values = <String, CloudDocument>{};
  final writes = <String>[];
  bool offline = false;
  Future<CloudDocument> Function(String)? read;
  Future<CloudDocument> Function(String, int, Document)? write;
  @override
  Future<CloudDocument> get(String id) async {
    if (offline) throw StateError('offline');
    if (read != null) return read!(id);
    return values[id] ?? const CloudDocument(0, {});
  }

  @override
  Future<CloudDocument> put(String id, int version, Document prefs) async {
    if (offline) throw StateError('offline');
    if (write != null) return write!(id, version, prefs);
    final current = values[id] ?? const CloudDocument(0, {});
    if (current.version != version) throw PreferenceConflict(current);
    writes.add(id);
    final next = CloudDocument(version + 1, copy(prefs));
    values[id] = next;
    return next;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeDevice device;
  late FakeRemote remote;
  late PreferenceSyncEngine sync;
  setUp(() {
    device = FakeDevice();
    remote = FakeRemote();
    sync = PreferenceSyncEngine(remote, device);
  });
  test(
    'first account saves local preferences, another device restores account preferences',
    () async {
      await sync.selectAccount('a');
      expect(remote.values['a']!.preferences['language'], 'fr');
      expect(sync.status, 'cloud_synced');
      final another = FakeDevice()
        ..local = {'schemaVersion': 1, 'themeMode': 'dark', 'language': 'en'};
      await PreferenceSyncEngine(remote, another).selectAccount('a');
      expect(another.local['themeMode'], 'light');
      expect(another.local['language'], 'fr');
      expect(remote.writes.length, 1);
    },
  );
  test(
    'offline changes survive process restart and retry without losing edits',
    () async {
      await sync.selectAccount('a');
      remote.offline = true;
      device.local['themeMode'] = 'dark';
      await sync.sync();
      expect(sync.status, 'cloud_offline');
      expect(device.caches['account:a']!['local']['themeMode'], 'dark');
      remote.offline = false;
      await PreferenceSyncEngine(remote, device).selectAccount('a');
      expect(remote.values['a']!.preferences['themeMode'], 'dark');
    },
  );
  test(
    'independent edits on two devices merge without losing either field',
    () async {
      await sync.selectAccount('a');
      device.local['themeMode'] = 'dark';
      remote.values['a'] = const CloudDocument(2, {
        'schemaVersion': 1,
        'themeMode': 'light',
        'language': 'en',
      });
      await sync.sync();
      expect(remote.values['a']!.preferences, {
        'schemaVersion': 1,
        'themeMode': 'dark',
        'language': 'en',
      });
      expect(sync.status, 'cloud_synced');
    },
  );
  test(
    'same-field conflict waits for an explicit choice and remote copy can win',
    () async {
      await sync.selectAccount('a');
      device.local['themeMode'] = 'dark';
      remote.values['a'] = const CloudDocument(2, {
        'schemaVersion': 1,
        'themeMode': 'daylight',
        'language': 'fr',
      });
      await sync.sync();
      expect(sync.status, 'cloud_conflict');
      expect(device.local['themeMode'], 'dark');
      expect(remote.writes.length, 1);
      await sync.resolveConflict(keepLocal: false);
      expect(device.local['themeMode'], 'daylight');
      expect(sync.status, 'cloud_synced');
    },
  );
  test(
    'explicit local conflict resolution still uses the latest server version',
    () async {
      await sync.selectAccount('a');
      device.local['themeMode'] = 'dark';
      remote.values['a'] = const CloudDocument(2, {
        'schemaVersion': 1,
        'themeMode': 'daylight',
        'language': 'en',
      });
      await sync.sync();
      await sync.resolveConflict(keepLocal: true);
      expect(remote.values['a']!.version, 3);
      expect(remote.values['a']!.preferences['themeMode'], 'dark');
      expect(remote.values['a']!.preferences['language'], 'en');
    },
  );
  test(
    '409 retries a disjoint merge against returned current version',
    () async {
      await sync.selectAccount('a');
      device.local['themeMode'] = 'dark';
      var first = true;
      remote.write = (id, version, prefs) async {
        if (first) {
          first = false;
          throw PreferenceConflict(
            const CloudDocument(2, {
              'schemaVersion': 1,
              'themeMode': 'light',
              'language': 'en',
            }),
          );
        }
        expect(version, 2);
        return CloudDocument(3, prefs);
      };
      await sync.sync();
      expect(device.local['themeMode'], 'dark');
      expect(device.local['language'], 'en');
      expect(sync.status, 'cloud_synced');
    },
  );
  test(
    'account switch does not upload account A settings to a new empty account B',
    () async {
      await sync.selectAccount('a');
      device.local['themeMode'] = 'dark';
      await sync.sync();
      await sync.selectAccount('b');
      expect(remote.values['b']!.preferences['themeMode'], 'light');
      expect(device.local['themeMode'], 'light');
      await sync.selectAccount('a');
      expect(device.local['themeMode'], 'dark');
    },
  );
  test('late account A response never applies to account B', () async {
    final gate = Completer<CloudDocument>();
    remote.read = (id) => id == 'a'
        ? gate.future
        : Future.value(
            const CloudDocument(1, {
              'schemaVersion': 1,
              'themeMode': 'daylight',
              'language': 'en',
            }),
          );
    final first = sync.selectAccount('a');
    await Future<void>.delayed(Duration.zero);
    final second = sync.selectAccount('b');
    gate.complete(
      const CloudDocument(1, {
        'schemaVersion': 1,
        'themeMode': 'dark',
        'language': 'fr',
      }),
    );
    await first;
    await second;
    expect(device.local['themeMode'], 'daylight');
    expect(sync.account, 'b');
    expect(remote.writes, isEmpty);
  });
  test(
    'rapid A to B to C switch preserves actual device owner rather than intermediate account',
    () async {
      await sync.selectAccount('a');
      device.local['themeMode'] = 'dark';
      final b = sync.selectAccount('b');
      final c = sync.selectAccount('c');
      await b;
      await c;
      expect(device.caches['account:a']!['local']['themeMode'], 'dark');
      expect(device.caches['account:b'], isNull);
      expect(remote.values['c']!.preferences['themeMode'], 'light');
    },
  );
  test(
    'local edit during upload remains local and gets queued for next sync',
    () async {
      await sync.selectAccount('a');
      device.local['themeMode'] = 'dark';
      remote.write = (id, version, prefs) async {
        device.local['language'] = 'ar';
        return CloudDocument(version + 1, prefs);
      };
      await sync.sync();
      expect(device.local['language'], 'ar');
      expect(sync.status, 'cloud_pending');
    },
  );
  test(
    'whitelist excludes secrets, precise location, OS grants and personal file URIs',
    () {
      final result = PreferenceSchema.clean({
        'schemaVersion': 1,
        'accessToken': 'secret',
        'latitude': 34.123,
        'permissions': {'notifications': true},
        'themeMode': 'dark',
        'sounds': {
          'adhan': 'content://private/audio.mp3',
          'before': 'custom_${'a' * 64}',
          'after': 'silent',
        },
        'silence': {
          'enabled': true,
          'access': true,
          'ruleId': 'os-private',
          'duration': -1,
        },
        'reader': {'font': '../../private', 'arabicSize': 100000},
        'widgets': {'opacity': 500, 'city': true},
      });
      expect(result['sounds'], {
        'adhan': 'azan_2',
        'before': 'noti_beep',
        'after': 'silent',
      });
      expect(result['silence'], {'enabled': true});
      expect(result['widgets'], {'city': true});
      expect(jsonEncode(result), isNot(contains('secret')));
      expect(jsonEncode(result), isNot(contains('content://')));
      expect(result.containsKey('latitude'), false);
    },
  );
  test(
    'app snapshot exports bundled fallback while leaving own personal selection intact',
    () async {
      SharedPreferences.setMockInitialValues({
        'selectedSoundName': 'custom_${'a' * 64}',
        'theme_mode': 'dark',
        'manual_city_lat': 34.4,
        'secure_token': 'secret',
        'personal_notification_sounds_v1': 'private',
      });
      final prefs = await SharedPreferences.getInstance();
      final adapter = AppPreferenceDevice(
        prefs,
        scope: 'test',
        reloadControllers: false,
      );
      final snapshot = await adapter.capture();
      expect(snapshot['sounds']['adhan'], 'azan_2');
      expect(jsonEncode(snapshot), isNot(contains('private')));
      expect(jsonEncode(snapshot), isNot(contains('secret')));
      await adapter.apply({...snapshot, 'themeMode': 'light'});
      expect(prefs.getString('selectedSoundName'), 'custom_${'a' * 64}');
      expect(prefs.getString('theme_mode'), 'light');
    },
  );
  test(
    'fresh device receiving personal sound reference safely uses bundled sound',
    () async {
      SharedPreferences.setMockInitialValues({'selectedSoundName': 'azan_1'});
      final prefs = await SharedPreferences.getInstance();
      await AppPreferenceDevice(
        prefs,
        scope: 'fresh',
        reloadControllers: false,
      ).apply({
        'schemaVersion': 1,
        'sounds': {'adhan': 'custom_${'b' * 64}'},
      });
      expect(prefs.getString('selectedSoundName'), 'azan_2');
    },
  );
  test(
    'preferences 401 clears the current authenticated session and secure token',
    () async {
      final store = CloudTestSessionStore();
      final auth = MobileAuthService(
        storage: store,
        apiBaseUrl: 'https://example.invalid',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': {
                'token': 'a-token',
                'user': {'id': 'a', 'name': 'A', 'email': 'a@example.invalid'},
              },
            }),
            200,
          ),
        ),
      );
      await auth.login(email: 'a@example.invalid', password: 'password');
      final api = HttpPreferenceRemote(
        baseUrl: auth.baseUrl,
        tokenFor: (_) => auth.accessToken(),
        onUnauthorized: (id, token) =>
            PreferenceCloudSync.clearRejectedSession(auth, id, token),
        client: MockClient((_) async => http.Response('{}', 401)),
      );
      await expectLater(api.get('a'), throwsStateError);
      expect(auth.user.value, isNull);
      expect(await auth.accessToken(), isNull);
      expect(store.values, isEmpty);
    },
  );
  test(
    'late preferences 401 cannot revoke a replacement session even for the same account',
    () async {
      for (final newAccount in ['b', 'a']) {
        var sessionAccount = 'a';
        var tokenVersion = 1;
        final auth = MobileAuthService(
          storage: CloudTestSessionStore(),
          apiBaseUrl: 'https://example.invalid',
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'data': {
                  'token': 'token-$tokenVersion',
                  'user': {
                    'id': sessionAccount,
                    'name': sessionAccount,
                    'email': '$sessionAccount@example.invalid',
                  },
                },
              }),
              200,
            ),
          ),
        );
        await auth.login(email: 'a@example.invalid', password: 'password');
        final response = Completer<http.Response>();
        final sent = Completer<void>();
        final api = HttpPreferenceRemote(
          baseUrl: auth.baseUrl,
          tokenFor: (_) => auth.accessToken(),
          onUnauthorized: (id, token) =>
              PreferenceCloudSync.clearRejectedSession(auth, id, token),
          client: MockClient((_) {
            sent.complete();
            return response.future;
          }),
        );
        final oldRequest = expectLater(api.get('a'), throwsStateError);
        await sent.future;
        await auth.clearSession();
        sessionAccount = newAccount;
        tokenVersion = 2;
        await auth.login(
          email: '$newAccount@example.invalid',
          password: 'password',
        );
        response.complete(http.Response('{}', 401));
        await oldRequest;
        expect(auth.user.value!.id, newAccount);
        expect(await auth.accessToken(), 'token-2');
      }
    },
  );
  test(
    'PHP integer serialization of font sizes does not cause repeated uploads',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final adapter = AppPreferenceDevice(
        prefs,
        scope: 'php-numbers',
        reloadControllers: false,
      );
      remote.write = (id, version, values) async {
        final stored = copy(values);
        stored['reader']['arabicSize'] = (stored['reader']['arabicSize'] as num)
            .toInt();
        stored['reader']['translationSize'] =
            (stored['reader']['translationSize'] as num).toInt();
        final doc = CloudDocument(version + 1, stored);
        remote.writes.add(id);
        remote.values[id] = doc;
        return doc;
      };
      final engine = PreferenceSyncEngine(remote, adapter);
      await engine.selectAccount('a');
      for (var poll = 0; poll < 3; poll++) {
        await engine.sync();
        expect(engine.status, 'cloud_synced');
      }
      expect(remote.writes, ['a']);
      expect(remote.values['a']!.version, 1);
      expect(PreferenceSyncEngine.same(22.0, 22), true);
      expect(PreferenceSyncEngine.same(22.5, 22), false);
    },
  );
  test('every bundled Moatheni choice survives cloud validation', () {
    for (final key in NotificationSoundCatalog.keys) {
      final clean = PreferenceSchema.clean({
        'sounds': {'adhan': key, 'before': key, 'after': key},
        'additionalReminders': {
          'duha': {'enabled': true, 'sound': key, 'minutes': 20},
        },
      });
      expect(clean['sounds']['adhan'], key);
      expect(clean['sounds']['before'], key);
      expect(clean['additionalReminders']['duha']['sound'], key);
    }
  });
  test('resetting all prayer adjustments reaches another device', () async {
    SharedPreferences.setMockInitialValues({
      'prayerAdjustments': '{"fajr":7,"asr":3}',
    });
    final prefs = await SharedPreferences.getInstance();
    final adapter = AppPreferenceDevice(
      prefs,
      scope: 'reset',
      reloadControllers: false,
    );
    final engine = PreferenceSyncEngine(remote, adapter);
    await engine.selectAccount('a');
    await prefs.setString('prayerAdjustments', '{}');
    await engine.sync();
    expect(remote.values['a']!.preferences['prayerAdjustments']['fajr'], 0);
    await prefs.setString('prayerAdjustments', '{"fajr":7,"asr":3}');
    await adapter.apply(remote.values['a']!.preferences);
    expect(jsonDecode(prefs.getString('prayerAdjustments')!)['fajr'], 0);
    expect(jsonDecode(prefs.getString('prayerAdjustments')!)['asr'], 0);
  });
  test(
    'cloud silence restore keeps OS activation a local explicit action',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final methods = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(AppPreferenceDevice.silenceChannel, (
        call,
      ) async {
        methods.add(call);
        return {'supported': true, 'enabled': false, 'access': false};
      });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(
          AppPreferenceDevice.silenceChannel,
          null,
        );
      });
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final adapter = AppPreferenceDevice(
        prefs,
        scope: 'dnd',
        reloadControllers: false,
      );
      await adapter.apply({
        'silence': {'enabled': true, 'delay': 8, 'duration': 25},
      });
      final write = methods.singleWhere((call) => call.method == 'set');
      expect(write.arguments, {'delay': 8, 'duration': 25});
      expect(
        methods.every((call) => call.method == 'get' || call.method == 'set'),
        true,
      );
      expect(AppPreferenceDevice.silenceNeedsActivation.value, true);
      expect((await adapter.capture())['silence']['enabled'], true);
      await adapter.apply({
        'silence': {'enabled': false, 'delay': 8, 'duration': 25},
      });
      expect(
        methods.lastWhere((call) => call.method == 'set').arguments['enabled'],
        false,
      );
      expect(AppPreferenceDevice.silenceNeedsActivation.value, false);
    },
  );
  test(
    'HTTP requests send version and safe preferences, do not follow token-bearing redirects',
    () async {
      final client = MockClient((request) async {
        expect(request.followRedirects, false);
        expect(request.headers['Authorization'], 'Bearer scoped');
        final body = jsonDecode(request.body);
        expect(body['version'], 7);
        expect(body['preferences'], {'schemaVersion': 1, 'themeMode': 'dark'});
        return http.Response(
          jsonEncode({
            'data': {'version': 8, 'preferences': body['preferences']},
          }),
          200,
        );
      });
      final api = HttpPreferenceRemote(
        baseUrl: 'https://example.invalid',
        tokenFor: (id) async => id == 'a' ? 'scoped' : null,
        client: client,
      );
      final result = await api.put('a', 7, {
        'schemaVersion': 1,
        'themeMode': 'dark',
        'token': 'secret',
      });
      expect(result.version, 8);
      await expectLater(api.get('b'), throwsStateError);
    },
  );
  test(
    'all prayer phase tuples normalize personal sounds to their dedicated defaults',
    () {
      final clean = PreferenceSchema.clean({
        'schemaVersion': 1,
        'prayerNotificationSettings': {
          for (final phase in PrayerNotificationPhase.values)
            phase.name: {
              for (final prayer in PrayerNotificationPrayer.values)
                prayer.name: {
                  'enabled': prayer != PrayerNotificationPrayer.sunrise,
                  'sound': 'custom_${'a' * 64}',
                  'minutes': phase == PrayerNotificationPhase.adhan ? 0 : 60,
                  'localUri': 'content://private-file',
                },
            },
        },
      });
      expect(
        PreferenceSchema.prayerPhases,
        PrayerNotificationPhase.values.map((v) => v.name).toSet(),
      );
      expect(
        PreferenceSchema.notificationPrayers,
        PrayerNotificationPrayer.values.map((v) => v.name).toSet(),
      );
      for (final phase in PrayerNotificationPhase.values) {
        for (final prayer in PrayerNotificationPrayer.values) {
          final row =
              clean['prayerNotificationSettings'][phase.name][prayer.name];
          expect(
            row['sound'],
            PrayerNotificationSetting.defaults(prayer, phase).sound,
          );
          expect(NotificationSoundCatalog.contains(row['sound']), true);
          expect(row.containsKey('localUri'), false);
        }
      }
      expect(jsonEncode(clean), isNot(contains('custom_')));
      expect(jsonEncode(clean), isNot(contains('content://')));
    },
  );
  test('notification schema rejects invalid phases, fields and JSON types', () {
    final clean = PreferenceSchema.clean({
      'prayerNotificationSettings': {
        'invalid': {
          'fajr': {'enabled': true},
        },
        'before': {
          'fajr': {'enabled': 'true', 'minutes': 121, 'secret': 'x'},
          'unknown': {},
        },
        'adhan': {
          'jumaa': {'enabled': false, 'minutes': 1, 'sound': 'silent'},
        },
        'after': {
          'sunrise': {'enabled': true, 'minutes': '10'},
        },
      },
    });
    expect(clean['prayerNotificationSettings'], {
      'before': {'fajr': {}},
      'adhan': {
        'jumaa': {'enabled': false, 'sound': 'silent'},
      },
      'after': {
        'sunrise': {'enabled': true},
      },
    });
  });
  test(
    'additional reminder types, contextual sounds and timing limits survive portable schema',
    () {
      expect(
        PreferenceSchema.extraTypes,
        AdditionalReminderType.values.map((v) => v.name).toSet(),
      );
      final extras = {
        for (final type in AdditionalReminderType.values)
          type.name: {
            ...AdditionalReminderSetting.defaults(type).toJson(),
            'sound': 'custom_${'b' * 64}',
            'useDefaultSound': true,
          },
      };
      final clean = PreferenceSchema.clean({'additionalReminders': extras});
      for (final type in AdditionalReminderType.values) {
        expect(
          PreferenceSchema.extraAnchors[type.name],
          AdditionalReminderSetting.allowedAnchors(type).toSet(),
        );
        final row = clean['additionalReminders'][type.name];
        expect(row['sound'], AdditionalReminderSetting.defaults(type).sound);
        expect(row['useDefaultSound'], true);
        expect(row['minutes'], extras[type.name]!['minutes']);
      }
      final invalid = PreferenceSchema.clean({
        'additionalReminders': {
          'fajrAlarm': {'minutes': 121},
          'bedtime': {'minutes': 121},
          'middleNight': {'minutes': -1},
          'lastThird': {'minutes': 121},
          'mondayThursday': {'useDefaultSound': 'true'},
        },
      });
      for (final row in (invalid['additionalReminders'] as Map).values) {
        expect(row, isEmpty);
      }
    },
  );
  test(
    'notification overrides roundtrip, retain local personal audio, and reset on another device',
    () async {
      final custom = 'custom_${'c' * 64}';
      final original = {
        'before': {
          'fajr': {'enabled': true, 'minutes': 7, 'sound': custom},
        },
      };
      SharedPreferences.setMockInitialValues({
        PrayerNotificationPreferences.storageKey: jsonEncode(original),
      });
      final prefs = await SharedPreferences.getInstance();
      final adapter = AppPreferenceDevice(
        prefs,
        scope: 'notifications',
        reloadControllers: false,
      );
      final snapshot = await adapter.capture();
      expect(
        snapshot['prayerNotificationSettings']['before']['fajr']['sound'],
        'moatheni_before_prayer_fajr',
      );
      expect(AppPreferenceDevice.personalSoundsLocal.value, true);
      final updated = copy(snapshot);
      updated['prayerNotificationSettings']['before']['fajr']['minutes'] = 11;
      await adapter.apply(updated);
      var local = await PrayerNotificationPreferences.loadOverrides(prefs);
      expect(local['before']['fajr']['minutes'], 11);
      expect(local['before']['fajr']['sound'], custom);
      // A portable export restores the correct bundled fallback on a fresh device.
      await PrayerNotificationPreferences.replaceOverrides({}, prefs);
      await adapter.apply(updated);
      local = await PrayerNotificationPreferences.loadOverrides(prefs);
      expect(local['before']['fajr']['sound'], 'moatheni_before_prayer_fajr');
      final engine = PreferenceSyncEngine(remote, adapter);
      await engine.selectAccount('a');
      await PrayerNotificationPreferences.replaceOverrides({}, prefs);
      await engine.sync();
      expect(
        remote.values['a']!.preferences['prayerNotificationSettings'],
        isEmpty,
      );
      await PrayerNotificationPreferences.replaceOverrides(original, prefs);
      await adapter.apply(remote.values['a']!.preferences);
      expect(await PrayerNotificationPreferences.loadOverrides(prefs), isEmpty);
      expect(engine.status, 'cloud_synced');
    },
  );
  test(
    'new notification settings are backed up separately for each account',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final adapter = AppPreferenceDevice(
        prefs,
        scope: 'accounts-notifications',
        reloadControllers: false,
      );
      final engine = PreferenceSyncEngine(remote, adapter);
      await engine.selectAccount('a');
      await PrayerNotificationPreferences.replaceOverrides({
        'adhan': {
          'sunrise': {'enabled': true, 'minutes': 0, 'sound': 'silent'},
        },
      }, prefs);
      await adapter.apply({
        'additionalReminders': {
          'fajrAlarm': {
            'enabled': true,
            'sound': 'moatheni_ring1',
            'minutes': 42,
          },
        },
      });
      await engine.sync();
      await engine.selectAccount('b');
      expect((await adapter.capture())['prayerNotificationSettings'], isEmpty);
      expect(
        (await adapter
            .capture())['additionalReminders']['fajrAlarm']['enabled'],
        false,
      );
      await engine.selectAccount('a');
      expect(
        (await adapter
            .capture())['prayerNotificationSettings']['adhan']['sunrise']['enabled'],
        true,
      );
      expect(
        (await adapter
            .capture())['additionalReminders']['fajrAlarm']['minutes'],
        42,
      );
      expect(
        remote.values['b']!.preferences['prayerNotificationSettings'],
        isEmpty,
      );
    },
  );
  test(
    'reset markers merge with an independent prayer edit regardless of map order',
    () async {
      device.local['prayerNotificationSettings'] = {
        'before': {
          'fajr': {'enabled': true, 'minutes': 5},
        },
      };
      await sync.selectAccount('a');
      device.local['prayerNotificationSettings']['after'] = {
        'isha': {'enabled': true, 'minutes': 10},
      };
      remote.values['a'] = const CloudDocument(2, {
        'schemaVersion': 1,
        'themeMode': 'light',
        'language': 'fr',
        'prayerNotificationSettings': {},
      });
      await sync.sync();
      expect(sync.status, 'cloud_synced');
      expect(device.local['prayerNotificationSettings'], {
        'after': {
          'isha': {'enabled': true, 'minutes': 10},
        },
      });
      expect(PreferenceSchema.expand({'parent.child': 1, 'parent': {}}), {
        'parent': {'child': 1},
      });
      expect(PreferenceSchema.expand({'parent': {}, 'parent.child': 1}), {
        'parent': {'child': 1},
      });
    },
  );

  test(
    'older account backups migrate global prayer choices and combined fasting clocks without data loss',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final adapter = AppPreferenceDevice(
        prefs,
        scope: 'old-backup',
        reloadControllers: false,
      );
      await adapter
          .capture(); // The v2 key already exists before the old cloud document arrives.
      await adapter.apply({
        'schemaVersion': 1,
        'sounds': {'adhan': 'silent'},
        'prayerNotifications': {
          '1': false,
          '2': true,
          '3': true,
          '4': true,
          '5': true,
        },
        'additionalReminders': {
          'mondayThursday': {
            'enabled': true,
            'sound': 'moatheni_thursday_fasting',
            'minutes': 1234,
          },
          'whiteDays': {'enabled': true, 'sound': 'silent', 'minutes': 1321},
          'duha': {'enabled': true, 'sound': 'noti_beep', 'minutes': 21},
        },
      });
      final captured = await adapter.capture();
      final prayers = await PrayerNotificationPreferences.load(prefs);
      expect(
        prayers
            .firstWhere(
              (s) =>
                  s.phase == PrayerNotificationPhase.adhan &&
                  s.prayer == PrayerNotificationPrayer.fajr,
            )
            .enabled,
        false,
      );
      expect(
        prayers
            .firstWhere(
              (s) =>
                  s.phase == PrayerNotificationPhase.adhan &&
                  s.prayer == PrayerNotificationPrayer.asr,
            )
            .sound,
        'silent',
      );
      expect(captured['prayerNotifications']['1'], false);
      final extras = captured['additionalReminders'];
      for (final type in ['monday', 'thursday']) {
        expect(extras[type]['enabled'], true);
        expect(extras[type]['anchor'], 'clock');
        expect(extras[type]['minutes'], 1234);
        expect(extras[type]['sound'], 'moatheni_thursday_fasting');
        expect(extras[type]['useDefaultSound'], false);
      }
      expect(extras['mondayThursday']['enabled'], false);
      expect(extras['whiteDays']['anchor'], 'clock');
      expect(extras['whiteDays']['minutes'], 1321);
      expect(extras['duha']['anchor'], 'afterSunrise');
      expect(extras['duha']['minutes'], 21);
      expect(extras['duha']['sound'], 'moatheni_duha');
      expect(extras['duha']['useDefaultSound'], true);
      final engine = PreferenceSyncEngine(remote, adapter);
      await engine.selectAccount('a');
      await engine.sync();
      expect(engine.status, 'cloud_synced');
    },
  );
  test(
    'legacy reminder master flags reflect authoritative per-prayer settings',
    () async {
      SharedPreferences.setMockInitialValues({
        'before_adhan_reminder_enabled': false,
        'after_adhan_reminder_enabled': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final adapter = AppPreferenceDevice(
        prefs,
        scope: 'legacy-masters',
        reloadControllers: false,
      );
      await PrayerNotificationPreferences.replaceOverrides({
        'before': {
          'fajr': {'enabled': true},
        },
        'after': {
          'isha': {'enabled': true},
        },
      }, prefs);
      final enabled = await adapter.capture();
      expect(enabled['reminders']['beforeEnabled'], true);
      expect(enabled['reminders']['afterEnabled'], true);
      await prefs.setBool('before_adhan_reminder_enabled', true);
      await prefs.setBool('after_adhan_reminder_enabled', true);
      await PrayerNotificationPreferences.replaceOverrides({
        for (final phase in [
          PrayerNotificationPhase.before,
          PrayerNotificationPhase.after,
        ])
          phase.name: {
            for (final prayer in PrayerNotificationPrayer.values)
              prayer.name: {'enabled': false},
          },
      }, prefs);
      final disabled = await adapter.capture();
      expect(disabled['reminders']['beforeEnabled'], false);
      expect(disabled['reminders']['afterEnabled'], false);
      // A v2 restore owns its settings even when a legacy companion flag disagrees.
      enabled['reminders']['beforeEnabled'] = false;
      await adapter.apply(enabled);
      expect((await adapter.capture())['reminders']['beforeEnabled'], true);
    },
  );
  test(
    'deferred account selection and local checkpoint persist edits before any network work',
    () async {
      await sync.selectAccount('a', synchronize: false);
      expect(remote.writes, isEmpty);
      device.local['themeMode'] = 'dark';
      await sync.checkpoint();
      expect(device.caches['account:a']!['local']['themeMode'], 'dark');
      expect(remote.writes, isEmpty);
      // Logout before the minute elapses still keeps the latest account's outbox.
      device.local['language'] = 'ar';
      await sync.selectAccount(null, synchronize: false);
      expect(device.caches['account:a']!['local']['language'], 'ar');
      expect(device.local['themeMode'], 'light');
      await sync.selectAccount('a', synchronize: false);
      expect(device.local['themeMode'], 'dark');
      expect(device.local['language'], 'ar');
      await sync.sync();
      expect(remote.values['a']!.preferences['language'], 'ar');
    },
  );

  test(
    'account checkpoint awaiting an older request cannot write into the next account',
    () async {
      await sync.selectAccount('a');
      final gate = Completer<CloudDocument>();
      remote.read = (_) => gate.future;
      device.local['themeMode'] = 'dark';
      final running = sync.sync();
      await Future<void>.delayed(Duration.zero);
      final save = sync.checkpoint();
      final switchAccount = sync.selectAccount('b', synchronize: false);
      gate.complete(
        const CloudDocument(1, {
          'schemaVersion': 1,
          'themeMode': 'light',
          'language': 'fr',
        }),
      );
      await running;
      await save;
      await switchAccount;
      expect(device.caches['account:a']!['local']['themeMode'], 'dark');
      expect(device.local['themeMode'], 'light');
      expect(remote.values['b'], isNull);
    },
  );
  for (final firstLogin in [false, true]) {
    test(
      'local edit during partial restoration preserves pending remote fields (first login: $firstLogin)',
      () async {
        final guarded = GuardedFakeDevice();
        final engine = PreferenceSyncEngine(remote, guarded);
        await engine.selectAccount('a', synchronize: !firstLogin);
        remote.values['a'] = const CloudDocument(2, {
          'schemaVersion': 1,
          'themeMode': 'dark',
          'language': 'ar',
        });
        guarded.duringApply = () async {
          expect(engine.isApplyingPreferences, true);
          engine.noteLocalChange();
          guarded.local['use24HourFormat'] = false;
        };
        await engine.sync();
        expect(guarded.local['themeMode'], 'dark');
        expect(guarded.local['language'], 'fr');
        expect(guarded.local['use24HourFormat'], false);
        expect(engine.status, 'cloud_pending');
        expect(guarded.caches['account:a']!['base']['language'], 'fr');
        guarded.duringApply = null;
        await engine.sync();
        expect(engine.status, 'cloud_synced');
        expect(guarded.local['themeMode'], 'dark');
        expect(guarded.local['language'], 'ar');
        expect(guarded.local['use24HourFormat'], false);
        expect(remote.values['a']!.preferences['language'], 'ar');
        expect(remote.values['a']!.preferences['use24HourFormat'], false);
      },
    );
  }
  test(
    'app adapter stops stale writes after an asynchronous preference save',
    () async {
      SharedPreferences.setMockInitialValues({
        'theme_mode': 'light',
        'language_code': 'fr',
      });
      final prefs = await SharedPreferences.getInstance();
      final adapter = AppPreferenceDevice(
        prefs,
        scope: 'guard-test',
        reloadControllers: false,
      );
      final completed = await adapter.applyIfCurrent({
        'schemaVersion': 1,
        'themeMode': 'dark',
        'language': 'ar',
      }, () => prefs.getString('theme_mode') != 'dark');
      expect(completed, false);
      expect(prefs.getString('theme_mode'), 'dark');
      expect(prefs.getString('language_code'), 'fr');
    },
  );
}
