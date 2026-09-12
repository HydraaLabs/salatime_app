import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zabi/util/app_constants.dart';
import 'package:zabi/helper/local_prayer_calculator.dart';
import 'package:zabi/helper/prayer_alarm_health.dart';

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

  AdhanNotificationServiceImpl()
    : _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin() {
    LocalPrayerCalculator.initializeTimeZones();
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
  Future<void> initializeNotification() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings("@mipmap/launcher_icon");

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
          requestAlertPermission: true,
          requestBadgePermission: false,
          requestSoundPermission: true,
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

  static bool _isLegacyPrayerChannel(String id) => RegExp(
    r'^(?:(?:before_|after_)?adhan_)?(?:azan_[123]|noti_1|noti_beep(?:_beep)?)$',
  ).hasMatch(id);

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
    final iosSound = '$sound.aiff';
    final androidSound = sound;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelWithoutBadge(channel ?? 'channelId'),
        channel ?? 'channelName',
        channelShowBadge: false,
        number: 0,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        when: when,
        audioAttributesUsage: channel?.startsWith('adhan_') ?? false
            ? AudioAttributesUsage.alarm
            : AudioAttributesUsage.notification,
        sound: RawResourceAndroidNotificationSound(androidSound),
        playSound: true,
        enableVibration: true,
        largeIcon: const DrawableResourceAndroidBitmap('dark_icon'),
        colorized: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
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
