package com.example.zabi

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONArray
import java.text.DateFormat
import java.util.Date

class PrayerWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        refreshAll(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == REFRESH) refreshAll(context)
    }

    override fun onDisabled(context: Context) {
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(refreshIntent(context))
    }

    companion object {
        private const val REFRESH = "net.salatime.app.WIDGET_REFRESH"

        @JvmStatic fun openApp(context: Context): PendingIntent = PendingIntent.getActivity(
            context, 7001, Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        private fun refreshIntent(context: Context) = PendingIntent.getBroadcast(
            context, 7002, Intent(context, PrayerWidgetProvider::class.java).setAction(REFRESH),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        @JvmStatic fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, PrayerWidgetProvider::class.java))
            if (ids.isEmpty()) return
            val prefs = context.getSharedPreferences("salatime_prayer_widget", Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            val prayers = runCatching { JSONArray(prefs.getString("prayers", "[]")) }.getOrDefault(JSONArray())
            val next = (0 until prayers.length()).mapNotNull { prayers.optJSONObject(it) }
                .filter { it.optLong("at") > now }.minByOrNull { it.optLong("at") }
            val views = RemoteViews(context.packageName, R.layout.prayer_widget)
            views.setTextViewText(R.id.widget_title, prefs.getString("nextLabel", "SalaTime"))
            views.setTextViewText(R.id.widget_city, prefs.getString("city", ""))
            views.setTextViewText(R.id.widget_prayer, next?.optString("name") ?: "SalaTime")
            val at = next?.optLong("at")
            val timeText = if (at != null) {
                android.text.format.DateFormat.getTimeFormat(context).format(Date(at)) + " · " +
                    DateFormat.getDateInstance(DateFormat.MEDIUM).format(Date(at))
            } else prefs.getString("emptyLabel", "Open SalaTime")
            views.setTextViewText(R.id.widget_time, timeText)
            views.setOnClickPendingIntent(R.id.widget_root, openApp(context))
            manager.updateAppWidget(ids, views)
            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarm.cancel(refreshIntent(context))
            if (at != null) {
                // Widget refresh is cosmetic: no exact-alarm or wake lock permission.
                alarm.setWindow(AlarmManager.RTC, at + 1000, 10 * 60 * 1000L, refreshIntent(context))
            }
        }
    }
}
