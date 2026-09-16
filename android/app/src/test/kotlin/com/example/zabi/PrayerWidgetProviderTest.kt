package com.example.zabi

import android.app.Application
import android.appwidget.AppWidgetManager
import android.widget.TextView
import android.widget.FrameLayout
import android.view.View
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33], manifest = Config.NONE, application = Application::class)
class PrayerWidgetProviderTest {
    @Test fun countdownTurnsRedStrictlyBelowFortyFiveMinutesAndResetsAfterPrayer() {
        val app = RuntimeEnvironment.getApplication()
        val at = java.time.Instant.parse("2026-09-13T16:00:00Z").toEpochMilli()
        app.getSharedPreferences("salatime_prayer_widget", 0).edit().clear()
            .putString("prayers", JSONArray().put(JSONObject().put("at", at).put("name", "Asr"))
                .put(JSONObject().put("at", at + 3 * 3600000).put("name", "Maghrib")).toString()).apply()
        for (expanded in listOf(false, true)) {
            for (seconds in listOf(false, true)) {
                app.getSharedPreferences("salatime_widget_options", 0).edit()
                    .putBoolean("countdown", true).putBoolean("seconds", seconds).apply()
                val views = PrayerWidgetProvider.createViews(app, expanded, at - 45 * 60000)
                val view = views.apply(app, FrameLayout(app))
                for ((now, expected) in listOf(
                    at - 45 * 60000 to 0xFF2F5233.toInt(),
                    at - 45 * 60000 + 1 to 0xFFC62828.toInt(),
                    at - 1 to 0xFFC62828.toInt(),
                    at to 0xFF2F5233.toInt(),
                    at + 90 * 60000 to 0xFF2F5233.toInt()
                )) {
                    PrayerWidgetProvider.createViews(app, expanded, now).reapply(app, view)
                    assertEquals(expected, view.findViewById<TextView>(R.id.widget_time).currentTextColor)
                    assertEquals(expected, view.findViewById<TextView>(R.id.widget_countdown).currentTextColor)
                }
            }
        }
    }

    @Test fun nearbyNextPrayerOverridesElapsedTimeAtOneHourForEveryWidgetMode() {
        val app = RuntimeEnvironment.getApplication()
        val previous = java.time.Instant.parse("2026-09-16T18:25:00Z").toEpochMilli()
        val next = previous + 90 * 60000
        app.getSharedPreferences("salatime_prayer_widget", 0).edit().clear()
            .putString("prayers", JSONArray()
                .put(JSONObject().put("at", previous).put("name", "Maghrib"))
                .put(JSONObject().put("at", next).put("name", "Isha")).toString()).apply()
        for (expanded in listOf(false, true)) {
            for (seconds in listOf(false, true)) {
                app.getSharedPreferences("salatime_widget_options", 0).edit().clear()
                    .putBoolean("countdown", true).putBoolean("seconds", seconds).apply()
                for ((remaining, expectedPrayer, expectedColor) in listOf(
                    Triple(60 * 60000L + 1, "Maghrib", 0xFF2F5233.toInt()),
                    Triple(60 * 60000L, "Isha", 0xFF2F5233.toInt()),
                    Triple(45 * 60000L, "Isha", 0xFF2F5233.toInt()),
                    Triple(45 * 60000L - 1, "Isha", 0xFFC62828.toInt()),
                    Triple(44 * 60000L + 59000, "Isha", 0xFFC62828.toInt())
                )) {
                    val view = PrayerWidgetProvider.createViews(app, expanded, next - remaining)
                        .apply(app, FrameLayout(app))
                    assertEquals(expectedPrayer, view.findViewById<TextView>(R.id.widget_prayer).text.toString())
                    assertEquals(expectedPrayer == "Isha",
                        view.findViewById<android.widget.Chronometer>(R.id.widget_countdown).isCountDown)
                    assertEquals(expectedColor, view.findViewById<TextView>(R.id.widget_time).currentTextColor)
                    assertEquals(expectedColor, view.findViewById<TextView>(R.id.widget_countdown).currentTextColor)
                }
            }
        }
    }

    @Test fun widgetSchedulesEarlySwitchThenStrictRedBoundaryWhenPrayersAreNinetyMinutesApart() {
        val app = RuntimeEnvironment.getApplication()
        val previous = System.currentTimeMillis()
        val next = previous + 90 * 60000
        app.getSharedPreferences("salatime_prayer_widget", 0).edit().clear()
            .putString("prayers", JSONArray()
                .put(JSONObject().put("at", previous).put("name", "Maghrib"))
                .put(JSONObject().put("at", next).put("name", "Isha")).toString()).apply()
        app.getSharedPreferences("salatime_widget_options", 0).edit().clear()
            .putBoolean("countdown", true).putBoolean("seconds", true).apply()
        val manager = Shadows.shadowOf(AppWidgetManager.getInstance(app))
        val id = manager.createWidget(SmallPrayerWidgetProvider::class.java, R.layout.prayer_widget)
        val alarms = Shadows.shadowOf(app.getSystemService(android.app.AlarmManager::class.java))
        PrayerWidgetProvider.refreshAll(app, previous)
        assertEquals("Maghrib", manager.getViewFor(id).findViewById<TextView>(R.id.widget_prayer).text.toString())
        assertEquals(next - 60 * 60000, alarms.peekNextScheduledAlarm()!!.triggerAtTime)
        PrayerWidgetProvider.refreshAll(app, next - 60 * 60000)
        assertEquals("Isha", manager.getViewFor(id).findViewById<TextView>(R.id.widget_prayer).text.toString())
        assertEquals(next - 45 * 60000 + 1, alarms.peekNextScheduledAlarm()!!.triggerAtTime)
        PrayerWidgetProvider.refreshAll(app, next - 45 * 60000 + 1)
        assertEquals(0xFFC62828.toInt(), manager.getViewFor(id)
            .findViewById<TextView>(R.id.widget_countdown).currentTextColor)
        assertEquals(next, alarms.peekNextScheduledAlarm()!!.triggerAtTime)
        assertEquals(1, alarms.scheduledAlarms.size)
    }

    @Test fun earlySwitchAcrossMidnightDisplaysTheNextPrayersDateAndDay() {
        val app = RuntimeEnvironment.getApplication()
        val next = java.time.Instant.parse("2026-09-17T00:15:00Z").toEpochMilli()
        app.getSharedPreferences("salatime_prayer_widget", 0).edit().clear()
            .putString("prayers", JSONArray()
                .put(JSONObject().put("at", next - 90 * 60000).put("name", "Previous"))
                .put(JSONObject().put("at", next).put("name", "Next"))
                .put(JSONObject().put("at", next + 8 * 3600000).put("name", "Later")).toString())
            .putString("locale", "en-US").putString("timeZone", "UTC").apply()
        app.getSharedPreferences("salatime_widget_options", 0).edit().clear()
            .putBoolean("countdown", true).putBoolean("seconds", true).apply()
        val view = PrayerWidgetProvider.createViews(app, true, next - 60 * 60000)
            .apply(app, FrameLayout(app))
        assertEquals("Next", view.findViewById<TextView>(R.id.widget_prayer).text.toString())
        assertTrue(view.findViewById<TextView>(R.id.widget_date).text.toString().contains("17"))
        assertEquals("Next", view.findViewById<TextView>(R.id.widget_slot_name_0).text.toString())
        assertEquals("Later", view.findViewById<TextView>(R.id.widget_slot_name_1).text.toString())
    }

    @Test fun clockAndEmptyWidgetStayGreenEvenInsideTheWarningWindow() {
        val app = RuntimeEnvironment.getApplication()
        val now = System.currentTimeMillis()
        val prefs = app.getSharedPreferences("salatime_prayer_widget", 0)
        prefs.edit().putString("prayers", JSONArray().put(JSONObject()
            .put("at", now + 10 * 60000).put("name", "Asr")).toString()).apply()
        for (expanded in listOf(false, true)) {
            val view = PrayerWidgetProvider.createViews(app, expanded, now).apply(app, FrameLayout(app))
            assertEquals(0xFF2F5233.toInt(), view.findViewById<TextView>(R.id.widget_time).currentTextColor)
        }
        prefs.edit().putString("prayers", "[]").apply()
        app.getSharedPreferences("salatime_widget_options", 0).edit().putBoolean("countdown", true).apply()
        val empty = PrayerWidgetProvider.createViews(app, false, now).apply(app, FrameLayout(app))
        assertEquals(0xFF2F5233.toInt(), empty.findViewById<TextView>(R.id.widget_time).currentTextColor)
    }

    @Test fun widgetSchedulesItsColorChangeWithoutFlutterOrSecondBySecondRefreshes() {
        val app = RuntimeEnvironment.getApplication()
        val now = System.currentTimeMillis()
        val at = now + 60 * 60000
        app.getSharedPreferences("salatime_prayer_widget", 0).edit().clear()
            .putString("prayers", JSONArray().put(JSONObject().put("at", at).put("name", "Asr")).toString()).apply()
        app.getSharedPreferences("salatime_widget_options", 0).edit()
            .putBoolean("countdown", true).putBoolean("seconds", true).apply()
        val manager = Shadows.shadowOf(AppWidgetManager.getInstance(app))
        val id = manager.createWidget(SmallPrayerWidgetProvider::class.java, R.layout.prayer_widget)
        PrayerWidgetProvider.refreshAll(app, now)
        val alarm = Shadows.shadowOf(app.getSystemService(android.app.AlarmManager::class.java))
        assertEquals(at - 45 * 60000 + 1, alarm.peekNextScheduledAlarm()!!.triggerAtTime)
        PrayerWidgetProvider.refreshAll(app, at - 45 * 60000 + 1)
        assertEquals(0xFFC62828.toInt(), manager.getViewFor(id)
            .findViewById<TextView>(R.id.widget_countdown).currentTextColor)
        assertEquals(at, alarm.peekNextScheduledAlarm()!!.triggerAtTime)
        assertEquals(1, alarm.scheduledAlarms.size)
    }

    @org.junit.Before fun legacyClockOption() {
        RuntimeEnvironment.getApplication().getSharedPreferences("salatime_widget_options", 0).edit().clear()
            .putBoolean("countdown", false).apply()
    }
    @Test fun elapsedPrayerWinsForNinetyMinutesThenNextPrayerTakesOver() {
        val app = RuntimeEnvironment.getApplication()
        val at = java.time.Instant.parse("2026-09-12T16:00:00Z").toEpochMilli()
        app.getSharedPreferences("salatime_prayer_widget", 0).edit().clear()
            .putString("prayers", JSONArray().put(JSONObject().put("at", at).put("name", "Asr"))
                .put(JSONObject().put("at", at + 3 * 3600000).put("name", "Maghrib")).toString())
            .putString("sinceLabel", "Temps écoulé depuis @prayer").apply()
        app.getSharedPreferences("salatime_widget_options", 0).edit().clear().putBoolean("seconds", false).apply()
        val elapsed = PrayerWidgetProvider.createViews(app, false, at + 34 * 60000).apply(app, FrameLayout(app))
        assertEquals("Asr", elapsed.findViewById<TextView>(R.id.widget_prayer).text.toString())
        assertEquals("Temps écoulé depuis", elapsed.findViewById<TextView>(R.id.widget_title).text.toString())
        assertEquals("Asr", elapsed.findViewById<TextView>(R.id.widget_prayer).text.toString())
        assertEquals("00:34", elapsed.findViewById<TextView>(R.id.widget_time).text.toString())
        val next = PrayerWidgetProvider.createViews(app, false, at + 90 * 60000).apply(app, FrameLayout(app))
        assertEquals("Maghrib", next.findViewById<TextView>(R.id.widget_prayer).text.toString())
        assertEquals("01:30", next.findViewById<TextView>(R.id.widget_time).text.toString())
    }

    @Test fun widgetSelectsFuturePrayerWithoutLaunchingFlutter() {
        val app = RuntimeEnvironment.getApplication()
        val now = System.currentTimeMillis()
        val prayers = JSONArray().put(JSONObject().put("at", now - 1000).put("name", "Fajr"))
            .put(JSONObject().put("at", now + 3600000).put("name", "Dhuhr"))
            .put(JSONObject().put("at", now + 7200000).put("name", "Asr"))
        app.getSharedPreferences("salatime_prayer_widget", 0).edit()
            .putString("prayers", prayers.toString()).putString("city", "Paris").apply()
        val manager = Shadows.shadowOf(AppWidgetManager.getInstance(app))
        val id = manager.createWidget(PrayerWidgetProvider::class.java, R.layout.prayer_widget)
        PrayerWidgetProvider.refreshAll(app)
        val view = manager.getViewFor(id)
        assertEquals("Dhuhr", view.findViewById<TextView>(R.id.widget_prayer).text.toString())
        assertEquals("Paris", view.findViewById<TextView>(R.id.widget_city).text.toString())
    }

    @Test fun expiredCalendarAsksToRefreshInsteadOfShowingAnOldPrayer() {
        val app = RuntimeEnvironment.getApplication()
        app.getSharedPreferences("salatime_prayer_widget", 0).edit()
            .putString("prayers", "[]").putString("emptyLabel", "Ouvrez SalaTime").apply()
        val manager = Shadows.shadowOf(AppWidgetManager.getInstance(app))
        val id = manager.createWidget(PrayerWidgetProvider::class.java, R.layout.prayer_widget)
        PrayerWidgetProvider.refreshAll(app)
        assertEquals("Ouvrez SalaTime", manager.getViewFor(id).findViewById<TextView>(R.id.widget_title).text.toString())
        assertEquals("—:—", manager.getViewFor(id).findViewById<TextView>(R.id.widget_time).text.toString())
    }

    @Test fun expandedWidgetShowsTheNextPrayersDayInTheSelectedCityTimeZone() {
        val app = RuntimeEnvironment.getApplication()
        val at = java.time.Instant.parse("2026-09-12T04:36:00Z").toEpochMilli()
        val prayers = JSONArray().put(JSONObject().put("at", at - 10 * 3600000).put("name", "Yesterday"))
            .put(JSONObject().put("at", at).put("name", "As-sobh").put("shortName", "Sobh"))
            .put(JSONObject().put("at", at + 8 * 3600000).put("name", "Dohr"))
        app.getSharedPreferences("salatime_prayer_widget", 0).edit().clear()
            .putString("prayers", prayers.toString()).putString("locale", "fr-FR")
            .putString("timeZone", "Africa/Casablanca").putBoolean("use24HourFormat", true).apply()
        val view = PrayerWidgetProvider.createViews(app, true, at - 3600000).apply(app, FrameLayout(app))
        assertEquals("05:36", view.findViewById<TextView>(R.id.widget_time).text.toString())
        assertEquals("Sobh", view.findViewById<TextView>(R.id.widget_slot_name_0).text.toString())
        assertEquals("05:36", view.findViewById<TextView>(R.id.widget_slot_time_0).text.toString())
        assertEquals(View.GONE, view.findViewById<View>(R.id.widget_period).visibility)
        assertEquals(0xFFFAF5E9.toInt(), view.findViewById<TextView>(R.id.widget_slot_time_0).currentTextColor)
        assertTrue(view.findViewById<TextView>(R.id.widget_date).text.toString().contains("12"))
    }

    @Test fun compactWidgetRespectsTwelveHourPreferenceAndKeepsTheDate() {
        val app = RuntimeEnvironment.getApplication()
        val at = java.time.Instant.parse("2026-09-12T16:00:00Z").toEpochMilli()
        app.getSharedPreferences("salatime_prayer_widget", 0).edit().clear()
            .putString("prayers", JSONArray().put(JSONObject().put("at", at).put("name", "Asr")).toString())
            .putString("locale", "en-US").putString("timeZone", "UTC").putBoolean("use24HourFormat", false).apply()
        val view = PrayerWidgetProvider.createViews(app, false, at - 3600000).apply(app, FrameLayout(app))
        assertEquals("4:00", view.findViewById<TextView>(R.id.widget_time).text.toString())
        val date = view.findViewById<TextView>(R.id.widget_date).text.toString()
        assertTrue(date.startsWith("PM · "))
        assertTrue(date.contains("12"))
    }
    @Test fun widgetOptionsKeepTextOpaqueAndEnableNativeCountdown() {
        val app = RuntimeEnvironment.getApplication()
        val now = System.currentTimeMillis()
        app.getSharedPreferences("salatime_prayer_widget", 0).edit().clear()
            .putString("prayers", JSONArray().put(JSONObject().put("at", now + 3600000).put("name", "Asr")).toString()).apply()
        app.getSharedPreferences("salatime_widget_options", 0).edit().clear()
            .putBoolean("countdown", true).putBoolean("city", false).putBoolean("date", false)
            .putBoolean("illustration", false).putInt("opacity", 40).apply()
        for (expanded in listOf(false, true)) {
            val view = PrayerWidgetProvider.createViews(app, expanded, now).apply(app, FrameLayout(app))
            assertEquals(View.GONE, view.findViewById<View>(R.id.widget_time).visibility)
            assertEquals(View.GONE, view.findViewById<View>(R.id.widget_city).visibility)
            assertEquals(View.GONE, view.findViewById<View>(R.id.widget_date).visibility)
            assertEquals(View.GONE, view.findViewById<View>(R.id.widget_illustration).visibility)
            assertEquals(102, view.findViewById<android.widget.ImageView>(R.id.widget_background).imageAlpha)
            val timer = view.findViewById<android.widget.Chronometer>(R.id.widget_countdown)
            assertEquals(View.VISIBLE, timer.visibility)
            assertTrue(timer.isCountDown)
            assertTrue(kotlin.math.abs(timer.base - android.os.SystemClock.elapsedRealtime() - 3600000) < 2000)
        }
    }

}
