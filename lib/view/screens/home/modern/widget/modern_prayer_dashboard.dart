// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import 'package:zabi/controller/package_prayer_time_controller.dart';
import 'package:zabi/data/model/response/todays_prayer_time_model.dart';
import 'package:zabi/helper/date_converter.dart';
import 'package:zabi/helper/salat_waqt_service.dart';
import 'package:zabi/helper/translator_helper.dart';
import 'package:zabi/theme/modern_light_theme.dart';
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
  late final SalatWaqtRepository _notificationRepository;
  final Map<int, bool> _notificationStates = {};
  final Set<int> _updatingPrayerIds = {};
  bool _notificationStatesLoaded = false;
  late DateTime _selectedDate;
  PrayerTimeModel? _displayedPrayerTimeModel;
  bool _isChangingDate = false;

  @override
  void initState() {
    super.initState();
    _notificationRepository =
        widget.notificationRepository ?? SalatWaqtRepository();
    final now = widget.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
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
      var prayers = await _notificationRepository.getSalatWaqtList();
      if (prayers.isEmpty) {
        await _notificationRepository.seedSalatWaqt();
        prayers = await _notificationRepository.getSalatWaqtList();
      }
      if (!mounted) return;
      setState(() {
        _notificationStates
          ..clear()
          ..addEntries(
            prayers.map(
              (prayer) => MapEntry(prayer.id, prayer.isNotificationEnabled),
            ),
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

    final previousValue = _notificationStates[prayerId] ?? false;
    final nextValue = !previousValue;
    setState(() {
      _notificationStates[prayerId] = nextValue;
      _updatingPrayerIds.add(prayerId);
    });

    var saved = false;
    try {
      final savedPrayer = await _notificationRepository.setNotificationEnabled(
        prayerId,
        nextValue,
      );
      if (savedPrayer == null) {
        throw StateError('Prayer notification $prayerId was not found');
      }
      saved = true;

      final reschedule = widget.rescheduleNotifications;
      if (reschedule != null) {
        await reschedule();
      } else {
        await SalatWaqtService.initializeSalatWaqt();
      }
    } catch (error) {
      Get.log('Failed to update prayer notification $prayerId: $error');
      if (!saved && mounted) {
        setState(() => _notificationStates[prayerId] = previousValue);
      }
    } finally {
      if (mounted) {
        setState(() => _updatingPrayerIds.remove(prayerId));
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _recomputeCountdown() {
    final target = _dateTimeForClock(
      widget.prayerTimeController.currentWaktTime.value,
      widget.now(),
    );
    if (!mounted) return;
    setState(() {
      _remaining = target?.difference(widget.now());
    });
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

  static DateTime? _dateTimeForClock(String? value, DateTime now) {
    if (value == null || value.trim().isEmpty || value == '--') return null;
    try {
      final parsed = DateFormat('HH:mm').parse(value.trim());
      var result = DateTime(
        now.year,
        now.month,
        now.day,
        parsed.hour,
        parsed.minute,
      );
      if (!result.isAfter(now)) result = result.add(const Duration(days: 1));
      return result;
    } catch (_) {
      return null;
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
    final data = prayerTimeModel?.data;
    return [
      _PrayerEntry(
        notificationId: 1,
        labelKey: 'fajr',
        time: data?.fajrStart,
        icon: Images.ModernPrayer_FajrSunrise,
      ),
      _PrayerEntry(
        labelKey: 'sunrise',
        time: data?.sunrise,
        icon: Images.Sunrise,
      ),
      _PrayerEntry(
        notificationId: 2,
        labelKey: data?.isJumma == true ? 'jumuah' : 'dhuhr',
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
    final now = widget.now();
    for (var index = 0; index < prayers.length; index++) {
      final time = prayers[index].time;
      if (time == null || time == '--') continue;
      try {
        final parsed = DateFormat('HH:mm').parse(time);
        final candidate = DateTime(
          now.year,
          now.month,
          now.day,
          parsed.hour,
          parsed.minute,
        );
        if (candidate.isAfter(now)) return index;
      } catch (_) {
        continue;
      }
    }
    return 0;
  }

  String _location() {
    final saved = widget.prayerTimeController.saveAddress.value.trim();
    if (saved.isNotEmpty && saved != '--') return saved;
    final current = widget.prayerTimeController.currentAddress.value.trim();
    if (current.isNotEmpty && current != '--') return current;
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
    final hijri = HijriCalendar.fromDate(_selectedDate);
    final hijriDateText = translateText(
      '${hijri.hDay} ${'hijri_month_${hijri.hMonth}'.tr} ${hijri.hYear}',
    );
    final gregorianDateText = materialLocalizations.formatFullDate(
      _selectedDate,
    );

    return Column(
      children: [
        SizedBox(
          height: 351,
          child: Stack(
            children: [
              _PrayerHero(
                prayerName: widget.prayerTimeController.currentWaqtName.value,
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
                      : _notificationStates[prayers[index].notificationId!],
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

  const _PrayerHero({
    required this.prayerName,
    required this.countdown,
    required this.location,
    required this.isDark,
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
                    ? const [Color(0xE615261E), Color(0xB31B5E3F)]
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
                    'next_prayer'.tr,
                    style: robotoMedium.copyWith(
                      color: Colors.white.withOpacity(0.88),
                      fontSize: Dimensions.FONT_SIZE_LARGE,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    prayerName == '--' ? '—' : prayerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: robotoBold.copyWith(
                      color: Colors.white,
                      fontSize: 48,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${'countdown_prefix'.tr} $countdown',
                    style: robotoRegular.copyWith(
                      color: Colors.white,
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
    final foreground = isActive
        ? AppColorModern.primaryGreenDark
        : Theme.of(context).textTheme.bodyLarge?.color;
    final time = prayer.time == null
        ? '--:--'
        : DateConverter.formatPrayerTime(prayer.time!, is24HourFormat);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 58,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 12, 0),
      color: isActive
          ? (Get.isDarkMode
                ? AppColorModern.emerald.withOpacity(0.18)
                : AppColorModern.chipGreenBackground)
          : Colors.transparent,
      child: Row(
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: SvgPicture.asset(prayer.icon, color: AppColorModern.emerald),
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
                        color: AppColorModern.emerald,
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
                            ? AppColorModern.emerald
                            : Theme.of(context).hintColor,
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
