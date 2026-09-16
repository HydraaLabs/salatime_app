package com.example.zabi

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.dexterous.flutterlocalnotifications.SalaTimePrayerAlarms
import com.dexterous.flutterlocalnotifications.SalaTimePrayerScheduleBatch
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor
import java.util.concurrent.Executors

/** One queue across activity/engine recreation; jobs never retain an Activity. */
internal class PrayerScheduleBackgroundHandler(
    context: Context,
    private val executor: Executor = sharedExecutor,
    private val mainHandler: Handler = Handler(Looper.getMainLooper()),
    private val operation: (Context, MethodCall) -> Any? = ::performOperation,
) {
    private val appContext = context.applicationContext

    /** UI-only operations are deliberately left to MainActivity. */
    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        if (call.method !in backgroundMethods) return false
        val code = if (call.method == "update") "alarm_routing_failed" else "alarm_operation_failed"
        try {
            executor.execute {
                try {
                    val value = operation(appContext, call)
                    mainHandler.post { result.success(value) }
                } catch (error: Exception) {
                    mainHandler.post { result.error(code, error.message, null) }
                }
            }
        } catch (error: Exception) {
            mainHandler.post { result.error(code, error.message, null) }
        }
        return true
    }

    companion object {
        private val backgroundMethods = setOf("update", "updateWidget", "route", "routeAll", "cancel", "cancelAll", "applyScheduleChanges")
        private val sharedExecutor: Executor = Executors.newSingleThreadExecutor { runnable ->
            Thread({
                android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_BACKGROUND)
                runnable.run()
            }, "salatime-prayer-schedule").apply { isDaemon = true }
        }

        private fun performOperation(context: Context, call: MethodCall): Any? = when (call.method) {
            "applyScheduleChanges" -> SalaTimePrayerScheduleBatch.apply(
                context,
                call.argument<List<Map<String, Any>>>("notifications") ?: emptyList(),
                call.argument<List<Int>>("cancelIds") ?: emptyList(),
            )
            "updateWidget" -> {
                val preferences = context.getSharedPreferences("salatime_prayer_widget", Context.MODE_PRIVATE).edit()
                for (key in listOf("prayers", "city", "nextLabel", "sinceLabel", "emptyLabel", "locale", "timeZone")) {
                    call.argument<String>(key)?.let { preferences.putString(key, it) }
                }
                call.argument<Boolean>("use24HourFormat")?.let { preferences.putBoolean("use24HourFormat", it) }
                preferences.apply()
                PrayerWidgetProvider.refreshAll(context)
                null
            }
            "update" -> {
                val preferences = context.getSharedPreferences("salatime_prayer_widget", Context.MODE_PRIVATE).edit()
                for (key in listOf("alarms", "prayers", "city", "nextLabel", "sinceLabel", "emptyLabel", "missedTitle", "missedBody", "locale", "timeZone")) {
                    call.argument<String>(key)?.let { preferences.putString(key, it) }
                }
                call.argument<Boolean>("use24HourFormat")?.let { preferences.putBoolean("use24HourFormat", it) }
                preferences.apply()
                PrayerWidgetProvider.refreshAll(context)
                runCatching { AutomaticSilence.refresh(context) }
                if (call.argument<Boolean>("scheduleAlreadyApplied") == true) {
                    SalaTimePrayerAlarms.refreshWindowIfNeeded(context)
                } else {
                    // A refresh without changes still repairs native registrations.
                    SalaTimePrayerAlarms.routeAll(context)
                }
            }
            "routeAll" -> SalaTimePrayerAlarms.routeAll(context)
            "route" -> {
                val id = call.argument<Number>("id")?.toInt()
                if (id == null) SalaTimePrayerAlarms.routeAll(context) else SalaTimePrayerAlarms.route(context, id)
            }
            "cancel" -> {
                val id = call.argument<Number>("id")?.toInt() ?: throw IllegalArgumentException("Missing alarm id")
                SalaTimePrayerAlarms.cancel(context, id)
                null
            }
            "cancelAll" -> {
                SalaTimePrayerAlarms.cancelAll(context)
                null
            }
            else -> throw IllegalArgumentException("Unsupported background operation")
        }
    }
}
