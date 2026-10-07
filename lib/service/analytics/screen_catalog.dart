import 'package:flutter/widgets.dart';

/// Stable, app-owned screen names. Route arguments and queries never enter
/// analytics, even when a route contains a surah, account or search value.
class AnalyticsScreenCatalog {
  static const Map<String, String> routes = {
    '/home': 'home',
    '/firstLaunchSetup': 'onboarding',
    '/backgroundLocation': 'background_location',
    '/dhikr': 'dhikr',
    '/dhikrCount': 'dhikr_counter',
    '/addDhikr': 'dhikr_add',
    '/Compass': 'qibla',
    '/nearByMosque': 'mosques',
    '/dua': 'dua',
    '/duaView': 'dua_detail',
    '/duaAdd': 'dua_add',
    '/sifatName': 'names_of_allah',
    '/sifatNameDetaile': 'names_of_allah_detail',
    '/hadithChapters': 'hadith_chapters',
    '/allHadith': 'hadith_list',
    '/hadithDetails': 'hadith_detail',
    '/hadithBookName': 'hadith_books',
    '/haramIngredientsFood': 'food_ingredients',
    '/haramFoodDetaile': 'food_ingredient_detail',
    '/zakatCalculator': 'zakat_calculator',
    '/zakatDetaile': 'zakat_detail',
    '/suraList': 'quran_surahs',
    '/suraDetaile': 'quran_reader',
    '/settings': 'settings',
    '/recters': 'reciters',
    '/audioList': 'audio_player',
    '/prayerAdjustment': 'prayer_adjustment',
    '/calculationMethod': 'calculation_method',
    '/account': 'account',
    '/readingProgress': 'reading_progress',
    '/prayerMarkers': 'prayer_markers',
    '/islamicCalendar': 'islamic_calendar',
    '/prayerShare': 'prayer_share',
    '/additionalReminders': 'additional_reminders',
    '/reminderTiming': 'reminder_timing',
    '/prayerMonth': 'prayer_month',
    '/personalDhikr': 'personal_dhikr',
    '/athkarCategory': 'athkar_category',
    '/notificationSettings': 'notification_settings',
    '/notificationPhase': 'notification_phase',
    '/upcomingPrayerAlarms': 'upcoming_prayer_alarms',
    '/offlineQuranReader': 'offline_quran_reader',
    '/wallpaperDetail': 'wallpaper_detail',
    '/localDhikrCount': 'local_dhikr_counter',
    '/localDuaView': 'local_dua_detail',
    '/more': 'more',
  };

  static final Set<String> screenNames = Set.unmodifiable(routes.values);

  // A weak route association lets back navigation restore the actual visible
  // tab. It holds only catalog names, never route arguments or user data.
  static final Expando<String> _tabScreens = Expando<String>();

  static void setTabScreen(Route<dynamic> route, String screen) {
    if (screenNames.contains(screen)) _tabScreens[route] = screen;
  }

  static String? fromRoute(Route<dynamic>? route) => route == null
      ? null
      : _tabScreens[route] ?? fromRouteName(route.settings.name);

  // The shell's '/bottomNavbar' route deliberately has no screen mapping:
  // its IndexedStack reports the tab actually visible, including after a pop.
  static String? fromRouteName(String? routeName) => routes[routeName];

  static String forTab(int index) => switch (index) {
    0 => 'home',
    1 => 'qibla',
    2 => 'dhikr',
    3 => 'mosques',
    4 => 'more',
    _ => throw RangeError.range(index, 0, 4, 'index'),
  };
}
