import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android owns persistence so prayer silence also works while Flutter is closed.
class AutomaticSilenceStatus {
  const AutomaticSilenceStatus({
    this.supported = false,
    this.access = false,
    this.exact = false,
    this.enabled = false,
    this.delay = 5,
    this.duration = 20,
    this.fridayDuration = 45,
    this.fridayOverride = false,
    this.prayers = const [1, 2, 3, 4, 5],
    this.ruleAvailable = false,
    this.hasSchedule = false,
  });

  factory AutomaticSilenceStatus.fromMap(Map<String, dynamic> map) {
    int number(String key, int fallback, int min, int max) =>
        ((map[key] as num?)?.toInt() ?? fallback).clamp(min, max);
    return AutomaticSilenceStatus(
      supported: map['supported'] == true,
      access: map['access'] == true,
      exact: map['exact'] == true,
      enabled: map['enabled'] == true,
      delay: number('delay', 5, 0, 60),
      duration: number('duration', 20, 5, 120),
      fridayDuration: number('fridayDuration', 45, 5, 120),
      fridayOverride: map['fridayOverride'] == true,
      prayers: map['prayers'] is List
          ? (map['prayers'] as List)
                .whereType<num>()
                .map((e) => e.toInt())
                .where((e) => e >= 1 && e <= 5)
                .toSet()
                .toList()
          : const [1, 2, 3, 4, 5],
      ruleAvailable: map['ruleAvailable'] == true,
      hasSchedule: map['hasSchedule'] == true,
    );
  }

  final bool supported, access, exact, enabled, fridayOverride;
  final bool ruleAvailable, hasSchedule;
  final int delay, duration, fridayDuration;
  final List<int> prayers;
}

class AutomaticSilenceService {
  static const channel = MethodChannel('net.salatime.app/automatic_silence');
  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<AutomaticSilenceStatus> load() async {
    if (!isAndroid) return const AutomaticSilenceStatus();
    try {
      final data = await channel.invokeMapMethod<String, dynamic>('get');
      return AutomaticSilenceStatus.fromMap(data ?? {});
    } on MissingPluginException {
      return const AutomaticSilenceStatus();
    }
  }

  static Future<AutomaticSilenceStatus> save(
    Map<String, dynamic> values,
  ) async {
    final data = await channel.invokeMapMethod<String, dynamic>('set', values);
    return AutomaticSilenceStatus.fromMap(data ?? {});
  }

  static Future<void> requestAccess() => channel.invokeMethod('requestAccess');
  static Future<void> requestExact() => channel.invokeMethod('requestExact');
}
