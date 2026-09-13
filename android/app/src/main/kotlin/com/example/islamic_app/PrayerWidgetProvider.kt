package com.example.zabi

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

open class PrayerWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        refreshAll(context)
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        refreshAll(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == REFRESH) refreshAll(context)
    }

    override fun onDisabled(context: Context) {
        refreshAll(context)
    }

    companion object {
        private const val REFRESH = "net.salatime.app.WIDGET_REFRESH"
        private const val GREEN = 0xFF2F5233.toInt()
        private const val COUNTDOWN_WARNING = 0xFFC62828.toInt()
        private const val WARNING_WINDOW_MS = 45 * 60000L
        private const val MUTED = 0xFF4C7A50.toInt()
        private const val WHITE = 0xFFFAF5E9.toInt()
        private val slots = intArrayOf(R.id.widget_slot_0, R.id.widget_slot_1, R.id.widget_slot_2, R.id.widget_slot_3, R.id.widget_slot_4)
        private val names = intArrayOf(R.id.widget_slot_name_0, R.id.widget_slot_name_1, R.id.widget_slot_name_2, R.id.widget_slot_name_3, R.id.widget_slot_name_4)
        private val times = intArrayOf(R.id.widget_slot_time_0, R.id.widget_slot_time_1, R.id.widget_slot_time_2, R.id.widget_slot_time_3, R.id.widget_slot_time_4)

        @JvmStatic fun openApp(context: Context): PendingIntent = PendingIntent.getActivity(
            context, 7001, Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        private fun refreshIntent(context: Context) = PendingIntent.getBroadcast(
            context, 7002, Intent(context, PrayerWidgetProvider::class.java).setAction(REFRESH),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // The launcher chooses the matching layout on Android 12+, including on rotation.
        // Older launchers notify onAppWidgetOptionsChanged when the user resizes it.
        internal fun responsiveViews(context: Context, options: Bundle, now: Long): RemoteViews {
            val compact = createViews(context, expanded = false, now = now)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                return RemoteViews(mapOf(
                    SizeF(180f, 80f) to compact,
                    SizeF(240f, 180f) to createViews(context, expanded = true, now = now)
                ))
            }
            val expanded by lazy { createViews(context, expanded = true, now = now) }
            val portrait = if (options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) >= 240 &&
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT) >= 180) expanded else compact
            val landscape = if (options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH) >= 240 &&
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) >= 180) expanded else compact
            return RemoteViews(landscape, portrait)
        }

        internal fun createViews(context: Context, expanded: Boolean, now: Long): RemoteViews {
            val prefs = context.getSharedPreferences("salatime_prayer_widget", Context.MODE_PRIVATE)
            val locale = Locale.forLanguageTag(prefs.getString("locale", Locale.getDefault().toLanguageTag())!!)
            val zone = TimeZone.getTimeZone(prefs.getString("timeZone", TimeZone.getDefault().id))
            // Existing widgets retain the app's default 24-hour format during upgrade.
            val hour24 = prefs.getBoolean("use24HourFormat", context.getSharedPreferences("FlutterSharedPreferences", 0)
                .getBoolean("flutter.is24HrFormat", true))
            val formatters = mutableMapOf<String, SimpleDateFormat>()
            fun format(pattern: String, at: Long): String = formatters.getOrPut(pattern) {
                SimpleDateFormat(pattern, locale).apply { timeZone = zone }
            }.format(Date(at))
            val prayers = readPrayers(context)
            val options = context.getSharedPreferences("salatime_widget_options", Context.MODE_PRIVATE)
            val showCountdown = options.getBoolean("countdown", true)
            val next = prayers.firstOrNull { it.optLong("at") > now }
            val recent = prayers.lastOrNull { it.optLong("at") <= now && now - it.optLong("at") < 90 * 60000 }
            val elapsed = showCountdown && recent != null
            val displayed = if (elapsed) recent else next
            val views = RemoteViews(context.packageName, if (expanded) R.layout.prayer_widget_expanded else R.layout.prayer_widget)
            val city = prefs.getString("city", "") ?: ""
            val prayer = displayed?.optString("name") ?: "SalaTime"
            val sinceTemplate = prefs.getString("sinceLabel", context.getString(R.string.prayer_widget_since_label))!!
            val title = if (elapsed) sinceTemplate.replace("@prayer", prayer)
                else prefs.getString("nextLabel", context.getString(R.string.prayer_widget_next_label))
            val at = displayed?.optLong("at")
            val timeText = at?.let { format(if (hour24) "HH:mm" else "h:mm", it) } ?: "—:—"
            val period = if (at != null && !hour24) format("a", at) else ""
            val date = at?.let { format(android.text.format.DateFormat.getBestDateTimePattern(locale, "EEEdMMM"), it) } ?: ""
            val empty = prefs.getString("emptyLabel", context.getString(R.string.prayer_widget_open_label))
            views.setInt(R.id.widget_root, "setLayoutDirection", if (locale.language in listOf("ar", "fa", "ur")) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR)
            // The prayer name already occupies the next line; repeating it here
            // truncates the useful elapsed-time label on narrow launchers.
            val visibleTitle = if (elapsed) sinceTemplate.replace("@prayer", "").trim() else title
            views.setTextViewText(R.id.widget_title, if (displayed == null) empty else visibleTitle)
            views.setTextViewText(R.id.widget_city, city)
            views.setTextViewText(R.id.widget_prayer, prayer)
            views.setTextViewText(R.id.widget_time, timeText)
            // Framework autosizing starts on API 26. Keep API 24/25 legible at
            // the minimum supported width as well.
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                views.setTextViewTextSize(R.id.widget_prayer, TypedValue.COMPLEX_UNIT_SP, 16f)
                views.setTextViewTextSize(R.id.widget_time, TypedValue.COMPLEX_UNIT_SP, 24f)
                views.setTextViewTextSize(R.id.widget_countdown, TypedValue.COMPLEX_UNIT_SP, 14f)
            }
            views.setTextViewText(R.id.widget_date, if (expanded || period.isEmpty()) date else "$period · $date")
            if (expanded) {
                views.setTextViewText(R.id.widget_period, period)
                views.setViewVisibility(R.id.widget_period, if (period.isEmpty()) View.GONE else View.VISIBLE)
                // The strip and the date both follow the next prayer's calendar day,
                // so after Isha it consistently shows tomorrow, in the selected city's zone.
                val dateKey = displayed?.optString("date")?.takeIf { it.isNotEmpty() } ?: at?.let { format("yyyy-MM-dd", it) }
                val day = if (at == null) emptyList() else prayers.filter {
                    (it.optString("date").takeIf { date -> date.isNotEmpty() } ?: format("yyyy-MM-dd", it.optLong("at"))) == dateKey
                }.take(5)
                views.setViewVisibility(R.id.widget_day_schedule, if (day.isEmpty()) View.GONE else View.VISIBLE)
                for (i in slots.indices) {
                    val item = day.getOrNull(i)
                    val selected = item != null && item.optLong("at") == at
                    val name = item?.optString("shortName", item.optString("name")) ?: ""
                    val time = item?.let { format(if (hour24) "HH:mm" else "h:mm a", it.optLong("at")) } ?: ""
                    views.setViewVisibility(slots[i], if (item == null) View.INVISIBLE else View.VISIBLE)
                    views.setInt(slots[i], "setBackgroundResource", if (selected) R.drawable.prayer_widget_active else 0)
                    views.setTextViewText(names[i], name)
                    views.setTextViewText(times[i], time)
                    views.setTextColor(names[i], if (selected) WHITE else MUTED)
                    views.setTextColor(times[i], if (selected) WHITE else GREEN)
                }
            }
            views.setViewVisibility(R.id.widget_city, if (options.getBoolean("city", true)) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.widget_date, if (options.getBoolean("date", true)) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.widget_illustration, if (options.getBoolean("illustration", true) && options.getInt("opacity", 100) > 0) View.VISIBLE else View.GONE)
            views.setInt(R.id.widget_background, "setImageAlpha", options.getInt("opacity", 100).coerceIn(0, 100) * 255 / 100)
            val countdown = displayed != null && showCountdown
            val countdownColor = if (countdown && !elapsed && at != null &&
                at - now in 1 until WARNING_WINDOW_MS) COUNTDOWN_WARNING else GREEN
            views.setTextColor(R.id.widget_time, countdownColor)
            views.setTextColor(R.id.widget_countdown, countdownColor)
            if (countdown) {
                if (expanded) views.setViewVisibility(R.id.widget_period, View.GONE)
                else views.setTextViewText(R.id.widget_date, date)
            }
            val seconds = options.getBoolean("seconds", true)
            if (countdown && !seconds) {
                val minutes = (if (elapsed) (now - (at ?: now)) / 60000 else ((at ?: now) - now + 59999) / 60000).coerceAtLeast(0)
                views.setTextViewText(R.id.widget_time, String.format(locale, "%02d:%02d", minutes / 60, minutes % 60))
            }
            views.setViewVisibility(R.id.widget_time, if (countdown && seconds) View.GONE else View.VISIBLE)
            views.setViewVisibility(R.id.widget_countdown, if (countdown && seconds) View.VISIBLE else View.GONE)
            views.setChronometerCountDown(R.id.widget_countdown, !elapsed)
            views.setChronometer(R.id.widget_countdown, android.os.SystemClock.elapsedRealtime() + ((at ?: now) - now), null, countdown && seconds)
            views.setContentDescription(R.id.widget_root, if (at == null) "$empty. $city" else "$title, $prayer, $timeText $period, $date, $city")
            views.setOnClickPendingIntent(R.id.widget_root, openApp(context))
            return views
        }

        private fun readPrayers(context: Context): List<JSONObject> {
            val prefs = context.getSharedPreferences("salatime_prayer_widget", Context.MODE_PRIVATE)
            val array = runCatching { JSONArray(prefs.getString("prayers", "[]")) }.getOrDefault(JSONArray())
            return (0 until array.length()).mapNotNull { array.optJSONObject(it) }
                .filter { it.optLong("at") > 0 }.sortedBy { it.optLong("at") }
        }

        @JvmStatic fun refreshAll(context: Context) {
            refreshAll(context, System.currentTimeMillis())
        }

        internal fun refreshAll(context: Context, now: Long) {
            val manager = AppWidgetManager.getInstance(context)
            var hasWidgets = false
            for (provider in listOf(PrayerWidgetProvider::class.java, SmallPrayerWidgetProvider::class.java, LargePrayerWidgetProvider::class.java)) {
                for (id in manager.getAppWidgetIds(ComponentName(context, provider))) {
                    hasWidgets = true
                    val views = when (provider) {
                        SmallPrayerWidgetProvider::class.java -> createViews(context, false, now)
                        LargePrayerWidgetProvider::class.java -> createViews(context, true, now)
                        else -> responsiveViews(context, manager.getAppWidgetOptions(id), now)
                    }
                    manager.updateAppWidget(id, views)
                }
            }
            if (!hasWidgets) {
                (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(refreshIntent(context))
                return
            }
            val all = readPrayers(context)
            val nextAt = all.firstOrNull { it.optLong("at") > now }?.optLong("at")
            val recentAt = all.lastOrNull { it.optLong("at") <= now && now - it.optLong("at") < 90 * 60000 }?.optLong("at")
            val options = context.getSharedPreferences("salatime_widget_options", Context.MODE_PRIVATE)
            val expiry = if (options.getBoolean("countdown", true)) recentAt?.plus(90 * 60000) else null
            // Chronometer ticks do not reapply RemoteViews colors. Refresh once
            // when the remaining time becomes strictly less than 45 minutes.
            val warningAt = if (options.getBoolean("countdown", true))
                nextAt?.minus(WARNING_WINDOW_MS)?.plus(1)?.takeIf { it > now } else null
            val at = listOfNotNull(nextAt, expiry, warningAt).minOrNull()
            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarm.cancel(refreshIntent(context))
            if (at != null) {
                val minuteCountdown = options.getBoolean("countdown", true) && !options.getBoolean("seconds", true)
                val refreshAt = if (minuteCountdown) minOf(at, now + 60000) else at
                // Non-wakeup refresh: the native chronometer handles second ticks.
                try {
                    if (Build.VERSION.SDK_INT < 31 || alarm.canScheduleExactAlarms()) {
                        alarm.setExact(AlarmManager.RTC, refreshAt, refreshIntent(context))
                    } else {
                        alarm.set(AlarmManager.RTC, refreshAt, refreshIntent(context))
                    }
                } catch (_: SecurityException) {
                    // Exact access may be revoked between the check and scheduling.
                    alarm.set(AlarmManager.RTC, refreshAt, refreshIntent(context))
                }
            }
        }
    }
}

class SmallPrayerWidgetProvider : PrayerWidgetProvider()
class LargePrayerWidgetProvider : PrayerWidgetProvider()
