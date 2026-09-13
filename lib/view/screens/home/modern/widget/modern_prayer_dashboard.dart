import 'package:zabi/service/preference_cloud_sync.dart';
import 'package:zabi/helper/prayer_notification_preferences.dart';
import 'package:zabi/controller/prayer_time_adjustment.dart';
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:zabi/helper/islamic_calendar.dart';
import 'package:zabi/controller/package_prayer_time_controller.dart';
import 'package:zabi/data/model/response/todays_prayer_time_model.dart';
import 'package:zabi/helper/date_converter.dart';
import 'package:zabi/helper/prayer_display_phase.dart';
import 'package:zabi/helper/salat_waqt_service.dart';
import 'package:zabi/helper/translator_helper.dart';
import 'package:zabi/theme/modern_light_theme.dart';
import 'package:zabi/theme/brand_colors.dart';
import 'package:zabi/util/dimensions.dart';
import 'package:zabi/util/images.dart';
import 'package:zabi/util/styles.dart';
import 'package:zabi/view/base/custom_snackbar.dart';
import 'package:zabi/view/screens/notification/widgets/salat_waqt_repository.dart';

class ModernPrayerDashboard extends StatefulWidget {
  final PrayerTimeController prayerTimeController;
  final DateTime Function() now;
  final SalatWaqtRepository? notificationRepository;
  final Future<void> Function()? rescheduleNotifications;

  const ModernPrayerDashboard({
    super.key,
    required this.prayerTimeController,
    this.now = DateTime.now,
    this.notificationRepository,
    this.rescheduleNotifications,
  });

  @override
  State<ModernPrayerDashboard> createState() => _ModernPrayerDashboardState();
}

class _ModernPrayerDashboardState extends State<ModernPrayerDashboard> {
  Timer? _ticker;
  Duration? _remaining;
  PrayerDisplayPhase? _phase;
  Data? _previousDay;
  Data? _nextDay;
  PrayerDisplayPhase? _nextPrayer;
  DateTime? _previousDayRequested;
  PrayerTimeModel? _neighborModel;
  Object? _neighborContext;
  bool _loadingNeighbors = false;
  StreamSubscription<void>? _notificationChanges;
  final Map<PrayerNotificationPrayer, bool> _notificationStates = {};
  final Set<int> _updatingPrayerIds = {};
  bool _notificationStatesLoaded = false;
  late DateTime _selectedDate;
  late DateTime _lastToday;
  PrayerTimeModel? _displayedPrayerTimeModel;
  bool _isChangingDate = false;

  @override
  void initState() {
    super.initState();
    _notificationChanges = PrayerNotificationPreferences.changes.listen((_) {
      if (mounted) unawaited(_loadNotificationStates());
    });
    final now = widget.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _lastToday = _selectedDate;
    _displayedPrayerTimeModel = widget.prayerTimeController.prayerTimeModel;
    _recomputeCountdown();
    unawaited(_loadNotificationStates());
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _recomputeCountdown(),
    );
  }

  Future<void> _loadNotificationStates() async {
    try {
      final prayers = await PrayerNotificationPreferences.load();
      if (!mounted) return;
      setState(() {
        _notificationStates
          ..clear()
          ..addEntries(
            prayers
                .where((p) => p.phase == PrayerNotificationPhase.adhan)
                .map((prayer) => MapEntry(prayer.prayer, prayer.enabled)),
          );
        _notificationStatesLoaded = true;
      });
    } catch (error) {
      Get.log('Failed to load prayer notification states: $error');
    }
  }

  Future<void> _togglePrayerNotification(_PrayerEntry prayer) async {
    final prayerId = prayer.notificationId;
    if (prayerId == null ||
        !_notificationStatesLoaded ||
        _updatingPrayerIds.contains(prayerId)) {
      return;
    }

    final selectedPrayer = PrayerNotificationPrayer.fromLegacyId(
      prayerId,
      date: _selectedDate,
    );
    final previousValue = _notificationStates[selectedPrayer] ?? false;
    final nextValue = !previousValue;
    PreferenceCloudSync.instance.noteLocalChange();
    setState(() {
      _notificationStates[selectedPrayer] = nextValue;
      _updatingPrayerIds.add(prayerId);
    });

    var saved = false;
    try {
      await PrayerNotificationPreferences.setPrayerAdhanEnabled(
        selectedPrayer,
        nextValue,
      );
      saved = true;
      PreferenceCloudSync.instance.noteLocalChange();

      unawaited(_refreshPrayerNotifications(nextValue));
    } catch (error) {
      Get.log('Failed to update prayer notification $prayerId: $error');
      if (!saved && mounted) {
        setState(() => _notificationStates[selectedPrayer] = previousValue);
      }
    } finally {
      if (mounted) {
        setState(() => _updatingPrayerIds.remove(prayerId));
      }
    }
  }

  Future<void> _refreshPrayerNotifications(bool enabled) async {
    try {
      if (enabled) await SalatWaqtService.checkNotificationPermission();
      await (widget.rescheduleNotifications?.call() ??
          SalatWaqtService.requestRefresh());
    } catch (error) {
      Get.log('Failed to refresh prayer notifications: $error');
    }
  }

  @override
  void dispose() {
    unawaited(_notificationChanges?.cancel());
    _ticker?.cancel();
    super.dispose();
  }

  Object get _currentNeighborContext {
    final controller = widget.prayerTimeController;
    return (
      controller.latitude,
      controller.longitude,
      controller.isManualPrayerTime.value,
      controller.saveAddress.value,
      controller.currentAddress.value,
      controller.selectedCalculationMethod,
      controller.selectedPrayerMadhab,
      controller.prayerTimeZone,
    );
  }

  void _recomputeCountdown() {
    final now = widget.now();
    final currentModel = widget.prayerTimeController.prayerTimeModel;
    if (!_isSameDate(_lastToday, now)) {
      if (!_isChangingDate && _isSameDate(_selectedDate, _lastToday)) {
        _selectedDate = DateTime(now.year, now.month, now.day);
        _displayedPrayerTimeModel = currentModel;
      }
      _lastToday = DateTime(now.year, now.month, now.day);
    }
    final currentContext = _currentNeighborContext;
    final changedContext =
        !identical(_neighborModel, currentModel) ||
        _neighborContext != currentContext;
    if (changedContext) {
      _previousDay = null;
      _nextDay = null;
    }
    if (!_loadingNeighbors &&
        (_previousDayRequested == null ||
            !_isSameDate(_previousDayRequested!, now) ||
            changedContext ||
            ((_nextDay == null || _previousDay == null) &&
                now.difference(_previousDayRequested!).inMinutes >= 1))) {
      _previousDayRequested = now;
      _neighborModel = currentModel;
      _neighborContext = currentContext;
      _loadingNeighbors = true;
      unawaited(_loadPreviousDay(now, currentModel, currentContext));
    }
    final phase = PrayerDisplayPhase.resolve(
      now,
      widget.prayerTimeController.prayerTimeModel?.data,
      previousDay: _previousDay,
      adjustments: PrayerTimeAdjustmentController.displayOffsets,
    );
    final nextPrayer = PrayerDisplayPhase.next(now, [
      _previousDay,
      widget.prayerTimeController.prayerTimeModel?.data,
      _nextDay,
    ], adjustments: PrayerTimeAdjustmentController.displayOffsets);
    final target = nextPrayer?.startedAt;
    if (!mounted) return;
    setState(() {
      _phase = phase;
      _nextPrayer = nextPrayer;
      _remaining = phase?.elapsed ?? target?.difference(now);
    });
  }

  Future<void> _loadPreviousDay(
    DateTime now,
    PrayerTimeModel? model,
    Object context,
  ) async {
    bool isCurrent() =>
        mounted &&
        _isSameDate(now, widget.now()) &&
        identical(model, widget.prayerTimeController.prayerTimeModel) &&
        context == _currentNeighborContext;
    try {
      final previous = await widget.prayerTimeController.getPrayerTimeForDate(
        DateTime(now.year, now.month, now.day - 1),
        allowNetwork: false,
      );
      if (!isCurrent()) return;
      final next = await widget.prayerTimeController.getPrayerTimeForDate(
        DateTime(now.year, now.month, now.day + 1),
        allowNetwork: false,
      );
      if (!isCurrent()) return;
      _previousDay = previous?.data;
      _nextDay = next?.data;
    } catch (_) {
      // Keep the next-prayer display when neighboring dates are unavailable.
    } finally {
      _loadingNeighbors = false;
    }
    if (mounted) _recomputeCountdown();
  }

  static bool _isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  Future<void> _changeDate(int dayOffset) async {
    if (_isChangingDate) return;

    final previousDate = _selectedDate;
    final previousModel = _displayedPrayerTimeModel;
    final targetDate = DateTime(
      previousDate.year,
      previousDate.month,
      previousDate.day + dayOffset,
    );
    final today = widget.now();

    if (_isSameDate(targetDate, today)) {
      setState(() {
        _selectedDate = DateTime(today.year, today.month, today.day);
        _displayedPrayerTimeModel = widget.prayerTimeController.prayerTimeModel;
      });
      return;
    }

    setState(() {
      _selectedDate = targetDate;
      _isChangingDate = true;
    });

    final model = await widget.prayerTimeController.getPrayerTimeForDate(
      targetDate,
    );
    if (!mounted) return;

    setState(() {
      _isChangingDate = false;
      if (model != null) {
        _displayedPrayerTimeModel = model;
      } else {
        _selectedDate = previousDate;
        _displayedPrayerTimeModel = previousModel;
      }
    });
    if (model == null) {
      showCustomSnackBar('please_try_again'.tr, isError: true);
    }
  }

  String get _countdownText {
    final remaining = _remaining;
    if (remaining == null) return '--:--:--';
    final safe = remaining.isNegative ? Duration.zero : remaining;
    final hours = safe.inHours.toString().padLeft(2, '0');
    final minutes = (safe.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (safe.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  List<_PrayerEntry> _prayers(PrayerTimeModel? prayerTimeModel) {
    final data = PrayerTimeAdjustmentController.adjustedDay(
      prayerTimeModel?.data,
    );
    return [
      _PrayerEntry(
        notificationId: 1,
        labelKey: 'fajr',
        time: data?.fajrStart,
        icon: Images.ModernPrayer_FajrSunrise,
      ),
      _PrayerEntry(
        notificationId: 6,
        labelKey: 'sunrise',
        time: data?.sunrise,
        icon: Images.Sunrise,
      ),
      _PrayerEntry(
        notificationId: 2,
        labelKey: _selectedDate.weekday == DateTime.friday ? 'jumuah' : 'dhuhr',
        time: data?.zuhrStart,
        icon: Images.ModernPrayer_DhuhrSun,
      ),
      _PrayerEntry(
        notificationId: 3,
        labelKey: 'asr',
        time: data?.asrStart,
        icon: Images.ModernPrayer_AsrCloudy,
      ),
      _PrayerEntry(
        notificationId: 4,
        labelKey: 'magrib',
        time: data?.maghribStart,
        icon: Images.ModernPrayer_MaghribSunset,
      ),
      _PrayerEntry(
        notificationId: 5,
        labelKey: 'isha',
        time: data?.ishaStart,
        icon: Images.ModernPrayer_IshaMoon,
      ),
    ];
  }

  int _nextPrayerIndex(List<_PrayerEntry> prayers) {
    final selected = _phase?.prayerKey ?? _nextPrayer?.prayerKey;
    return prayers.indexWhere((prayer) => prayer.labelKey == selected);
  }

  String _location() {
    final controller = widget.prayerTimeController;
    final preferred = controller.isManualPrayerTime.value
        ? controller.saveAddress.value
        : controller.currentAddress.value;
    final fallback = controller.isManualPrayerTime.value
        ? controller.currentAddress.value
        : controller.saveAddress.value;
    for (final value in [preferred, fallback]) {
      if (value.trim().isNotEmpty && value.trim() != '--') return value.trim();
    }
    return 'SalaTime';
  }

  @override
  Widget build(BuildContext context) {
    final today = widget.now();
    final isShowingToday = _isSameDate(_selectedDate, today);
    final displayedModel = isShowingToday
        ? widget.prayerTimeController.prayerTimeModel
        : _displayedPrayerTimeModel;
    final prayers = _prayers(displayedModel);
    final activeIndex = isShowingToday ? _nextPrayerIndex(prayers) : -1;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final materialLocalizations = MaterialLocalizations.of(context);
    final hijri = IslamicCalendarPreferences.date(_selectedDate);
    final hijriDateText = translateText(
      '${hijri.hDay} ${'hijri_month_${hijri.hMonth}'.tr} ${hijri.hYear}',
    );
    final gregorianDateText = translateText(
      materialLocalizations.formatFullDate(_selectedDate),
    );

    return Column(
      children: [
        SizedBox(
          height: 351,
          child: Stack(
            children: [
              _PrayerHero(
                prayerName:
                    _phase?.prayerKey.tr ??
                    _nextPrayer?.prayerKey.tr ??
                    'next_prayer'.tr,
                elapsed: _phase != null,
                approaching: PrayerDisplayPhase.isApproaching(
                  _remaining,
                  elapsed: _phase != null,
                ),
                countdown: translateText(_countdownText),
                location: _location(),
                isDark: isDark,
              ),
              PositionedDirectional(
                start: Dimensions.PADDING_SIZE_DEFAULT,
                end: Dimensions.PADDING_SIZE_DEFAULT,
                bottom: 0,
                child: _DateBar(
                  hijriDateText: hijriDateText,
                  gregorianDateText: gregorianDateText,
                  isLoading: _isChangingDate,
                  onPrevious: _isChangingDate ? null : () => _changeDate(-1),
                  onNext: _isChangingDate ? null : () => _changeDate(1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(
            horizontal: Dimensions.PADDING_SIZE_DEFAULT,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(Dimensions.RADIUS_EXTRA_LARGE),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < prayers.length; index++) ...[
                _PrayerRow(
                  prayer: prayers[index],
                  isActive: index == activeIndex,
                  is24HourFormat:
                      widget.prayerTimeController.is24HourFormat.value,
                  notificationEnabled: prayers[index].notificationId == null
                      ? null
                      : _notificationStates[PrayerNotificationPrayer.fromLegacyId(
                          prayers[index].notificationId!,
                          date: _selectedDate,
                        )],
                  notificationUpdating:
                      prayers[index].notificationId != null &&
                      _updatingPrayerIds.contains(
                        prayers[index].notificationId,
                      ),
                  onNotificationPressed: prayers[index].notificationId == null
                      ? null
                      : () => _togglePrayerNotification(prayers[index]),
                ),
                if (index != prayers.length - 1)
                  Divider(
                    height: 1,
                    indent: 58,
                    color: Theme.of(context).dividerColor.withOpacity(0.4),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PrayerHero extends StatelessWidget {
  final String prayerName;
  final String countdown;
  final String location;
  final bool isDark;
  final bool elapsed;
  final bool approaching;

  const _PrayerHero({
    required this.prayerName,
    required this.countdown,
    required this.location,
    required this.isDark,
    required this.elapsed,
    required this.approaching,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 315,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            Images.ModernIllustration_MosqueHeader,
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
            filterQuality: FilterQuality.high,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xE615261E), Color(0xB32F5233)]
                    : const [Color(0xDB2F5233), Color(0x994C7A50)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 42),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    elapsed
                        ? 'time_since_prayer'.trParams({'prayer': prayerName})
                        : 'next_prayer'.tr,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: robotoMedium.copyWith(
                      color: Colors.white.withOpacity(0.88),
                      fontSize: Dimensions.FONT_SIZE_LARGE,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      elapsed
                          ? countdown
                          : (prayerName == '--' ? '—' : prayerName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: robotoBold.copyWith(
                        color: Colors.white,
                        fontSize: 48,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (!elapsed)
                    Text(
                      '${'countdown_prefix'.tr} $countdown',
                      style: robotoRegular.copyWith(
                        color: approaching
                            ? BrandColors.countdownWarningOnPrimary
                            : Colors.white,
                        fontSize: Dimensions.FONT_SIZE_OVER_LARGE,
                        letterSpacing: 0.5,
                      ),
                    ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: robotoMedium.copyWith(
                            color: Colors.white,
                            fontSize: Dimensions.FONT_SIZE_LARGE,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateBar extends StatelessWidget {
  final String hijriDateText;
  final String gregorianDateText;
  final bool isLoading;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _DateBar({
    required this.hijriDateText,
    required this.gregorianDateText,
    required this.isLoading,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColorModern.primaryGreenDark,
        borderRadius: BorderRadius.circular(Dimensions.RADIUS_LARGE),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('prayer_date_previous'),
            onPressed: onPrevious,
            tooltip: 'previous_day'.tr,
            icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  hijriDateText,
                  key: const ValueKey('hijri_date_text'),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: robotoBold.copyWith(
                    color: Colors.white,
                    fontSize: Dimensions.FONT_SIZE_LARGE,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLoading) ...[
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        gregorianDateText,
                        key: const ValueKey('gregorian_date_text'),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: robotoRegular.copyWith(
                          color: Colors.white.withOpacity(0.76),
                          fontSize: Dimensions.FONT_SIZE_SMALL,
                          height: 1.05,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('prayer_date_next'),
            onPressed: onNext,
            tooltip: 'next_day'.tr,
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerEntry {
  final int? notificationId;
  final String labelKey;
  final String? time;
  final String icon;

  const _PrayerEntry({
    this.notificationId,
    required this.labelKey,
    required this.time,
    required this.icon,
  });
}

class _PrayerRow extends StatelessWidget {
  final _PrayerEntry prayer;
  final bool isActive;
  final bool is24HourFormat;
  final bool? notificationEnabled;
  final bool notificationUpdating;
  final VoidCallback? onNotificationPressed;

  const _PrayerRow({
    required this.prayer,
    required this.isActive,
    required this.is24HourFormat,
    required this.notificationEnabled,
    required this.notificationUpdating,
    required this.onNotificationPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final foreground = isActive ? accent : theme.textTheme.bodyLarge?.color;
    final time = prayer.time == null
        ? '--:--'
        : DateConverter.formatPrayerTime(prayer.time!, is24HourFormat);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 58,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 12, 0),
      color: isActive
          ? (theme.brightness == Brightness.dark
                ? accent.withOpacity(0.18)
                : AppColorModern.chipGreenBackground)
          : Colors.transparent,
      child: Row(
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: SvgPicture.asset(prayer.icon, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              prayer.labelKey.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: robotoMedium.copyWith(
                color: foreground,
                fontSize: Dimensions.FONT_SIZE_LARGE,
              ),
            ),
          ),
          Text(
            translateText(time),
            style: robotoMedium.copyWith(
              color: foreground,
              fontSize: Dimensions.FONT_SIZE_LARGE,
            ),
          ),
          const SizedBox(width: 12),
          if (prayer.notificationId != null)
            SizedBox.square(
              dimension: 48,
              child: notificationUpdating
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    )
                  : IconButton(
                      key: ValueKey(
                        'prayer_notification_${prayer.notificationId}',
                      ),
                      tooltip:
                          (notificationEnabled == true
                                  ? 'disable_prayer_notifications'
                                  : 'enable_prayer_notifications')
                              .trParams({'prayer': prayer.labelKey.tr}),
                      onPressed: notificationEnabled == null
                          ? null
                          : onNotificationPressed,
                      icon: Icon(
                        notificationEnabled == true
                            ? Icons.notifications_rounded
                            : Icons.notifications_none_rounded,
                        size: 23,
                        color: notificationEnabled == true
                            ? accent
                            : theme.hintColor,
                      ),
                    ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}
