/// Detect civil-time changes while the app stays open, independently of timers
/// using the wall clock. Resuming the app already causes a full prayer refresh.
class DeviceClockChange {
  Duration? _offset;
  String? _zone;
  int? _utcMilliseconds;
  Duration? _elapsed;

  bool observe(DateTime now, Duration elapsed) {
    final previous = _utcMilliseconds;
    final changed =
        previous != null &&
        (_offset != now.timeZoneOffset ||
            _zone != now.timeZoneName ||
            ((now.millisecondsSinceEpoch - previous) -
                        (elapsed - _elapsed!).inMilliseconds)
                    .abs() >
                5000);
    _offset = now.timeZoneOffset;
    _zone = now.timeZoneName;
    _utcMilliseconds = now.millisecondsSinceEpoch;
    _elapsed = elapsed;
    return changed;
  }
}
