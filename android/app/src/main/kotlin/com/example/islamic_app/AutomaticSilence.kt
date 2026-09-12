package com.example.zabi

import android.app.Activity
import android.app.AlarmManager
import android.app.AlertDialog
import android.app.AutomaticZenRule
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.service.notification.Condition
import org.json.JSONArray
import java.util.Calendar
import java.util.TimeZone

/** Owns one Android rule; never writes the global interruption filter or ringer volume. */
object AutomaticSilence {
    internal const val PREFS = "salatime_automatic_silence"
    private const val ACTION_TICK = "net.salatime.app.AUTOMATIC_SILENCE_TICK"
    internal val conditionId: Uri = Uri.parse("condition://net.salatime.app/prayer-silence")
    internal data class Window(val start: Long, val end: Long)

    fun supported() = Build.VERSION.SDK_INT >= 29
    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private fun manager(context: Context) = context.getSystemService(NotificationManager::class.java)
    private fun exactAllowed(context: Context) = Build.VERSION.SDK_INT < 31 ||
        context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()

    fun status(context: Context): Map<String, Any> {
        val p = prefs(context)
        val access = supported() && manager(context).isNotificationPolicyAccessGranted
        val rule = if (access) runCatching {
            p.getString("ruleId", null)?.let { manager(context).getAutomaticZenRule(it) }
        }.getOrNull() else null
        return mapOf(
            "supported" to supported(), "access" to access,
            "exact" to exactAllowed(context),
            "enabled" to p.getBoolean("enabled", false),
            "delay" to p.getInt("delay", 5), "duration" to p.getInt("duration", 20),
            "fridayDuration" to p.getInt("fridayDuration", 45),
            "fridayOverride" to p.getBoolean("fridayOverride", false),
            "prayers" to (p.getStringSet("prayers", setOf("1", "2", "3", "4", "5")) ?: emptySet()).mapNotNull { it.toIntOrNull() }.sorted(),
            "ruleAvailable" to (rule?.isEnabled == true),
            "hasSchedule" to windows(context).any { it.end > System.currentTimeMillis() }
        )
    }

    /** Called only by the settings UI. Enabling is never inferred from a permission grant. */
    fun configure(context: Context, values: Map<*, *>) {
        val p = prefs(context)
        val enabled = values["enabled"] as? Boolean ?: p.getBoolean("enabled", false)
        if (enabled) {
            check(supported()) { "silence_unsupported" }
            check(manager(context).isNotificationPolicyAccessGranted) { "silence_access_needed" }
            check(exactAllowed(context)) { "silence_exact_needed" }
        }
        val edit = p.edit().putBoolean("enabled", enabled)
        for ((key, bounds) in mapOf("delay" to 0..60, "duration" to 5..120, "fridayDuration" to 5..120)) {
            (values[key] as? Number)?.toInt()?.let { edit.putInt(key, it.coerceIn(bounds)) }
        }
        (values["fridayOverride"] as? Boolean)?.let { edit.putBoolean("fridayOverride", it) }
        (values["prayers"] as? List<*>)?.let { items ->
            edit.putStringSet("prayers", items.mapNotNull { (it as? Number)?.toInt()?.takeIf { id -> id in 1..5 }?.toString() }.toSet())
        }
        edit.apply()
        if (enabled && values["enabled"] == true) {
            try { ensureRule(context) }
            catch (error: Exception) { p.edit().putBoolean("enabled", false).apply(); throw error }
        }
        refresh(context)
    }

    private fun ensureRule(context: Context) {
        if (!supported()) return
        val p = prefs(context)
        val n = manager(context)
        val id = p.getString("ruleId", null)
        val existing = id?.let { n.getAutomaticZenRule(it) }
        if (existing != null) {
            if (!existing.isEnabled) {
                existing.isEnabled = true
                n.updateAutomaticZenRule(id, existing)
            }
            return
        }
        val rule = AutomaticZenRule(
            context.getString(R.string.automatic_silence_rule), null,
            ComponentName(context, SilenceRuleSettingsActivity::class.java), conditionId,
            null, NotificationManager.INTERRUPTION_FILTER_ALARMS, true
        )
        val newId = n.addAutomaticZenRule(rule)
        check(!newId.isNullOrEmpty()) { "silence_save_error" }
        p.edit().putString("ruleId", newId).putBoolean("active", false).apply()
    }

    internal fun mergeWindows(input: List<Window>): List<Window> {
        val result = mutableListOf<Window>()
        for (window in input.filter { it.end > it.start }.sortedBy { it.start }) {
            val previous = result.lastOrNull()
            if (previous != null && window.start <= previous.end) {
                result[result.lastIndex] = Window(previous.start, maxOf(previous.end, window.end))
            } else result.add(window)
        }
        return result
    }

    internal fun windows(context: Context): List<Window> {
        val p = prefs(context)
        val data = context.getSharedPreferences("salatime_prayer_widget", Context.MODE_PRIVATE)
        val rows = runCatching { JSONArray(data.getString("prayers", "[]")) }.getOrDefault(JSONArray())
        val selected = p.getStringSet("prayers", setOf("1", "2", "3", "4", "5")) ?: emptySet()
        val zone = TimeZone.getTimeZone(data.getString("timeZone", TimeZone.getDefault().id))
        val result = mutableListOf<Window>()
        for (index in 0 until minOf(rows.length(), 1000)) {
            val row = rows.optJSONObject(index) ?: continue
            val prayerId = row.optInt("prayerId", 0)
            val at = row.optLong("at", 0)
            if (prayerId !in 1..5 || prayerId.toString() !in selected || at <= 0) continue
            val friday = Calendar.getInstance(zone).apply { timeInMillis = at }.get(Calendar.DAY_OF_WEEK) == Calendar.FRIDAY
            val duration = if (prayerId == 2 && friday && p.getBoolean("fridayOverride", false))
                p.getInt("fridayDuration", 45) else p.getInt("duration", 20)
            val start = at + p.getInt("delay", 5).coerceIn(0, 60) * 60000L
            result.add(Window(start, start + duration.coerceIn(5, 120) * 60000L))
        }
        return mergeWindows(result)
    }

    private fun alarmIntent(context: Context) = PendingIntent.getBroadcast(
        context, 7019, Intent(context, AutomaticSilenceReceiver::class.java).setAction(ACTION_TICK),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    internal fun nextBoundary(windows: List<Window>, now: Long): Long? =
        windows.asSequence().flatMap { sequenceOf(it.start, it.end) }.filter { it > now }.minOrNull()

    /** Re-evaluates persisted epochs after a schedule update, alarm, resume, reboot or permission change. */
    fun refresh(context: Context, now: Long = System.currentTimeMillis(), restore: Boolean = false) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val tick = alarmIntent(context)
        if (!supported()) { alarms.cancel(tick); return }
        val p = prefs(context)
        val n = manager(context)
        if (!n.isNotificationPolicyAccessGranted) {
            alarms.cancel(tick)
            p.edit().putBoolean("active", false).apply()
            return
        }
        val id = p.getString("ruleId", null) ?: run { alarms.cancel(tick); return }
        // Keep the existing end alarm when Android temporarily fails to answer this query.
        val rule = n.getAutomaticZenRule(id)
        if (rule == null || !rule.isEnabled) {
            alarms.cancel(tick)
            // A user-deleted/disabled rule stays that way until explicitly enabled in SalaTime.
            p.edit().putBoolean("enabled", false).putBoolean("active", false).apply()
            return
        }
        val ready = p.getBoolean("enabled", false) && exactAllowed(context)
        val times = if (ready) windows(context) else emptyList()
        val currentWindow = times.firstOrNull { now >= it.start && now < it.end }
        var active = currentWindow != null
        val next = nextBoundary(times, now)
        if (next != null) {
            try {
                // Install the end transition before enabling silence. Same PendingIntent replaces the old alarm.
                alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, tick)
            } catch (_: SecurityException) {
                active = false
                alarms.cancel(tick)
            }
        } else alarms.cancel(tick)
        val wasActive = p.getBoolean("active", false)
        val priorEnd = p.getLong("activeEnd", 0)
        val newPeriod = active && wasActive && priorEnd > 0 && priorEnd <= currentWindow!!.start
        if (newPeriod) {
            // A previous end alarm may have been missed while the device was off. A fresh prayer after a gap
            // resets only the expired period's snooze, never a snooze inside the current period.
            n.setAutomaticZenRuleState(id, Condition(conditionId, context.getString(R.string.automatic_silence_rule), Condition.STATE_FALSE))
        }
        // Repeated TRUE does not clear Android's manual snooze; never emit FALSE/TRUE on an ordinary resume.
        if (restore || newPeriod || active != wasActive || !active) {
            n.setAutomaticZenRuleState(id, Condition(conditionId, context.getString(R.string.automatic_silence_rule),
                if (active) Condition.STATE_TRUE else Condition.STATE_FALSE))
            p.edit().putBoolean("active", active).putLong("activeEnd", if (active) currentWindow!!.end else 0).apply()
        }
    }

    fun openAccessSettings(activity: Activity) {
        activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
    }

    fun openExactSettings(activity: Activity) {
        if (Build.VERSION.SDK_INT >= 31) activity.startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
            Uri.parse("package:${activity.packageName}")))
    }
}

class AutomaticSilenceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        runCatching { AutomaticSilence.refresh(context, restore = intent.action == Intent.ACTION_BOOT_COMPLETED) }
    }
}

/** Android's rule editor entry point; all detailed options remain available in the Flutter settings. */
class SilenceRuleSettingsActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AlertDialog.Builder(this)
            .setTitle(R.string.automatic_silence_rule)
            .setMessage(R.string.automatic_silence_description)
            .setPositiveButton(R.string.automatic_silence_open) { _, _ ->
                startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP))
                finish()
            }
            .setNegativeButton(R.string.automatic_silence_disable) { _, _ ->
                runCatching { AutomaticSilence.configure(this, mapOf("enabled" to false)) }
                finish()
            }
            .setOnCancelListener { finish() }
            .show()
    }
}
