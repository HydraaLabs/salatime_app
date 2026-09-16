import 'package:salatime/service/personal_notification_sounds.dart';
import 'dart:io';
import 'dart:convert';
import 'notification_sound_catalog.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// Adapter pinned to flutter_local_notifications 17.2.4, like the native cache.
// ignore: implementation_imports
import 'package:flutter_local_notifications/src/platform_specifics/android/method_channel_mappers.dart';
// ignore: implementation_imports
import 'package:flutter_local_notifications/src/tz_datetime_mapper.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:salatime/util/app_constants.dart';
import 'package:salatime/helper/local_prayer_calculator.dart';
import 'package:salatime/helper/prayer_alarm_health.dart';

abstract class AdhanNotificationService {
  // Future<void> checkAndRequestPermissions();
  Future<void> initializeNotification();
  Future<bool> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
    String? payload,
    String? sound,
    String? channel,
  });
  Future<void> cancelNotification(int id);
  Future<List<PendingNotificationRequest>> getPendingNotifications();
  Future<List<ActiveNotification>> getActiveNotifications();
  Future<void> cancelAllNotifications();
  Future<void> sendNotification({required String title, required String body});
}

class AdhanNotificationServiceImpl implements AdhanNotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  final List<String> _legacyChannelsToRetire = [];
  bool _schedulingFailed = false;
  bool get schedulingFailed => _schedulingFailed;
  bool usedInexactAlarms = false;
  tz.Location? _location;
  bool? _exactAllowed;
  final bool batchAndroidScheduling;
  bool _nativeBatchUnavailable = false;
  bool _nativeScheduleApplied = false;
  bool get nativeScheduleApplied =>
      _nativeScheduleApplied &&
      !_schedulingFailed &&
      _stagedSchedules.isEmpty &&
      _stagedCancellations.isEmpty;
  final _stagedSchedules =
      <
        int,
        ({Map<String, Object?> arguments, Future<bool> Function() fallback})
      >{};
  final _stagedCancellations = <int>{};

  AdhanNotificationServiceImpl({this.batchAndroidScheduling = false})
    : _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin() {
    LocalPrayerCalculator.initializeTimeZones();
  }

  bool get _canUseNativeSchedule =>
      !_nativeBatchUnavailable &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;

  static bool _managedId(int id) =>
      (id >= 10000000 && id < 30000000) || id == 1999000001;

  bool _managedPayload(int id, String? payload) {
    if (!_managedId(id) || payload == null) return false;
    try {
      final data = jsonDecode(payload);
      return data is Map &&
          data['id'] == id &&
          const [
            'adhan',
            'before',
            'after',
            'extra_reminder',
          ].contains(data['kind']);
    } catch (_) {
      return false;
    }
  }

  /// Persist the calculated reserve once, then let native code arm its window.
  /// A superseded Flutter pass flushes here before saving its manifest too.
  Future<void> flushPendingAndroidSchedule() async {
    if (_stagedSchedules.isEmpty && _stagedCancellations.isEmpty) return;
    final schedules = Map.of(_stagedSchedules);
    final cancellations = _stagedCancellations.toList();
    _nativeScheduleApplied = false;
    try {
      final result = await PrayerAlarmHealth.channel
          .invokeMapMethod<String, dynamic>('applyScheduleChanges', {
            'notifications': schedules.values
                .map((entry) => entry.arguments)
                .toList(),
            'cancelIds': cancellations,
          });
      if (result == null) {
        throw MissingPluginException('Native batch scheduling unavailable');
      }
      usedInexactAlarms |= result['inexact'] == true;
      _schedulingFailed |= (result['failed'] as int? ?? 0) > 0;
      _nativeScheduleApplied = true;
    } on MissingPluginException {
      // A Dart update may run on an older Android binary. Keep its established
      // plugin registrations and route them individually when supported.
      _nativeBatchUnavailable = true;
      for (final id in cancellations) {
        await cancelNotification(id);
      }
      var failed = false;
      for (final entry in schedules.values) {
        if (!await entry.fallback()) failed = true;
      }
      if (failed) {
        _schedulingFailed = true;
        // Some individual plugin writes may have succeeded. Let the manifest
        // checkpoint retain their ownership; the final health flag reports the
        // partial failure, and the next refresh retries missing pending IDs.
      }
    } catch (_) {
      _schedulingFailed = true;
      rethrow;
    }
    _stagedSchedules.clear();
    _stagedCancellations.clear();
  }

  // Future<void> _checkNotificationPermission() async {
  //   if (Platform.isAndroid || Platform.isIOS) {
  //     var status = await Permission.notification.status;
  //     if (!status.isGranted) {
  //       await Permission.notification.request();
  //     }
  //   }
  // }

  @override
  Future<void> initializeNotification({bool requestPermissions = true}) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings("@mipmap/launcher_icon");

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
          requestAlertPermission: requestPermissions,
          requestBadgePermission: false,
          requestSoundPermission: requestPermissions,
          defaultPresentAlert: true,
          defaultPresentBadge: false,
          defaultPresentSound: true,
        );

    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
          linux: initializationSettingsLinux,
        );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _notificationTapBackground,
    );
    await _prepareChannelsWithoutBadges();

    if (!requestPermissions) return;

    if (Platform.isAndroid) {
      final androidVersion =
          int.tryParse(
            Platform.operatingSystemVersion
                .replaceAll(RegExp(r'[^0-9.]'), '')
                .split('.')
                .first,
          ) ??
          0;

      if (androidVersion >= 13) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        }
      }
    } else if (Platform.isIOS) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: false, sound: true);
    }
  }

  static String _channelWithoutBadge(String id) => '${id}_no_badge_v1';

  static bool _isLegacyPrayerChannel(String id) {
    final key = id.replaceFirst(RegExp(r'^(?:before_|after_)?adhan_'), '');
    return NotificationSoundCatalog.contains(key);
  }

  Future<void> _prepareChannelsWithoutBadges() async {
    final android = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    final channels = await android.getNotificationChannels() ?? [];
    _legacyChannelsToRetire.clear();
    _schedulingFailed = false;
    for (final old in channels.where((c) => _isLegacyPrayerChannel(c.id))) {
      // Android cannot change badge policy on an existing channel. Preserve
      // the user's sound, vibration and disabled-channel settings in its replacement.
      if (!channels.any((c) => c.id == _channelWithoutBadge(old.id))) {
        await android.createNotificationChannel(
          AndroidNotificationChannel(
            _channelWithoutBadge(old.id),
            old.name,
            description: old.description,
            groupId: old.groupId,
            importance: old.importance,
            playSound: old.playSound,
            sound: old.sound,
            enableVibration: old.enableVibration,
            vibrationPattern: old.vibrationPattern,
            enableLights: old.enableLights,
            ledColor: old.ledColor,
            audioAttributesUsage: old.audioAttributesUsage,
            showBadge: false,
          ),
        );
      }
      _legacyChannelsToRetire.add(old.id);
    }
  }

  /// Remove delivered legacy notifications (and their launcher count) only
  /// after all prayer alarms have been rescheduled onto the replacement channels.
  Future<void> retireLegacyBadgeChannels() async {
    if (_schedulingFailed) return;
    final android = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    for (final id in _legacyChannelsToRetire) {
      await android?.deleteNotificationChannel(id);
    }
    _legacyChannelsToRetire.clear();
  }

  // @override
  // Future<void> checkAndRequestPermissions() async {
  //   await _checkNotificationPermission();
  // }

  @override
  Future<bool> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
    String? payload,
    String? sound,
    String? channel,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await PersonalNotificationSounds.load(prefs);
    final selectedSound =
        sound ??
        prefs.getString(AppConstants.SELECTED_NOTIFICATION_SOUND_KEY) ??
        AppConstants.DEFAULT_NOTIFICATION_SOUND;
    final selectedChannel = channel ?? 'adhan_$selectedSound';

    try {
      // Never turn a missed occurrence into tomorrow's prayer at today's time.
      if (!dateTime.isAfter(DateTime.now())) return false;
      _location ??= tz.getLocation(await FlutterTimezone.getLocalTimezone());
      final scheduledDate = dateTime is tz.TZDateTime
          ? dateTime
          : tz.TZDateTime.from(dateTime, _location!);
      final android = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final exactAllowed = _exactAllowed ??=
          await android?.canScheduleExactNotifications() ?? true;
      var mode = exactAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
      if (_canUseNativeSchedule && _managedPayload(id, payload)) {
        final details = _getNotificationDetails(
          sound: selectedSound,
          channel: selectedChannel,
          when: dateTime.millisecondsSinceEpoch,
        );
        _stagedSchedules[id] = (
          arguments: {
            'id': id,
            'title': title,
            'body': body,
            'payload': payload,
            'platformSpecifics': {
              ...details.android!.toMap(),
              'scheduleMode': mode.name,
            },
            ...scheduledDate.toMap(),
          },
          fallback: () => scheduleNotification(
            id: id,
            title: title,
            body: body,
            dateTime: scheduledDate,
            payload: payload,
            sound: selectedSound,
            channel: selectedChannel,
          ),
        );
        _stagedCancellations.remove(id);
        if (!batchAndroidScheduling) await flushPendingAndroidSchedule();
        return true;
      }
      Future<void> schedule(AndroidScheduleMode schedulingMode) =>
          _flutterLocalNotificationsPlugin.zonedSchedule(
            id,
            title,
            body,
            scheduledDate,
            _getNotificationDetails(
              sound: selectedSound,
              channel: selectedChannel,
              when: dateTime.millisecondsSinceEpoch,
            ),
            androidScheduleMode: schedulingMode,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: payload,
          );
      try {
        await schedule(mode);
      } on PlatformException catch (error) {
        // The permission can be revoked between the check and registration.
        if (error.code != 'exact_alarms_not_permitted') rethrow;
        _exactAllowed = false;
        mode = AndroidScheduleMode.inexactAllowWhileIdle;
        await schedule(mode);
      }
      usedInexactAlarms |= mode == AndroidScheduleMode.inexactAllowWhileIdle;
      // Route immediately: batching this until after the 30-day refresh would
      // temporarily double the alarms and exceed Samsung's per-app limit.
      try {
        final routed = await PrayerAlarmHealth.route(id);
        usedInexactAlarms |= routed?['inexact'] == true;
        _schedulingFailed |= (routed?['failed'] as int? ?? 0) > 0;
      } on PlatformException catch (error) {
        // The plugin alarm remains armed if the native replacement fails.
        _schedulingFailed = true;
        debugPrint('Native prayer alarm routing failed: $error');
      }
      return true;
    } catch (e) {
      _schedulingFailed = true;
      // Scheduling can fail on platforms without full support
      // (e.g. Linux desktop) — log and continue instead of crashing.
      debugPrint('Failed to schedule notification $id: $e');
      return false;
    }
  }

  @override
  Future<void> cancelAllNotifications() async {
    await PrayerAlarmHealth.cancel();
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  @override
  Future<void> cancelNotification(int id) async {
    if (_canUseNativeSchedule && _managedId(id)) {
      _stagedSchedules.remove(id);
      _stagedCancellations.add(id);
      if (!batchAndroidScheduling) await flushPendingAndroidSchedule();
      return;
    }
    await PrayerAlarmHealth.cancel(id: id);
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  @override
  Future<List<ActiveNotification>> getActiveNotifications() async {
    return _flutterLocalNotificationsPlugin.getActiveNotifications();
  }

  @override
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  void _onDidReceiveLocalNotification(
    int id,
    String? title,
    String? body,
    String? payload,
  ) async {
    // Implement your own local notification handler here
  }

  void _onDidReceiveNotificationResponse(
    NotificationResponse notificationResponse,
  ) async {
    // final String? payload = notificationResponse.payload;
    // Implement your own notification response handler here
  }

  @pragma('vm:entry-point')
  static void _notificationTapBackground(
    NotificationResponse notificationResponse,
  ) {
    // Implement your own background notification handler here
  }

  NotificationDetails _getNotificationDetails({
    String? channel,
    String? sound,
    int? when,
  }) {
    final personal = PersonalNotificationSounds.find(sound);
    final silent =
        sound == 'silent' ||
        (sound?.startsWith('custom_') == true &&
            (!PersonalNotificationSounds.supported || personal == null));
    final iosSound = silent
        ? null
        : (personal != null ? personal['path'] : '$sound.aiff');
    final androidSound = sound;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelWithoutBadge(channel ?? 'channelId'),
        channel ?? 'channelName',
        channelShowBadge: false,
        number: 0,
        // HIGH is the highest app channel level; MAX is reserved for Android.
        // createIfNotExists keeps the user's existing channel settings intact.
        importance: Importance.high,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        when: when,
        audioAttributesUsage: channel?.startsWith('adhan_') ?? false
            ? AudioAttributesUsage.alarm
            : AudioAttributesUsage.notification,
        sound: silent
            ? null
            : personal != null
            ? UriAndroidNotificationSound(personal['path']!)
            : RawResourceAndroidNotificationSound(androidSound),
        playSound: !silent,
        enableVibration: true,
        largeIcon: const DrawableResourceAndroidBitmap('dark_icon'),
        colorized: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: !silent,
        presentBadge: false,
        badgeNumber: 0,
        sound: iosSound,
      ),
    );
  }

  @override
  Future<void> sendNotification({
    required String title,
    required String body,
  }) async {
    await _flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      _getNotificationDetails(
        channel: AppConstants.DEFAULT_NOTIFICATION_SOUND,
        sound: AppConstants.DEFAULT_NOTIFICATION_SOUND,
      ),
      payload: 'Default_Sound',
    );
  }
}
