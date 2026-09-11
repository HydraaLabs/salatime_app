package com.example.zabi

import android.app.Application
import android.appwidget.AppWidgetManager
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33], manifest = Config.NONE, application = Application::class)
class PrayerWidgetProviderTest {
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
        assertEquals("Ouvrez SalaTime", manager.getViewFor(id).findViewById<TextView>(R.id.widget_time).text.toString())
    }
}
