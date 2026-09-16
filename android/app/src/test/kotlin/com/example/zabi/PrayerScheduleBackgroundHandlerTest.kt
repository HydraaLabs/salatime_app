package com.example.zabi

import android.app.Application
import android.app.AlarmManager
import android.content.Context
import android.content.ContextWrapper
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executor
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.TimeUnit
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneOffset
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config
import org.robolectric.annotation.LooperMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [29], manifest = Config.NONE, application = Application::class)
@LooperMode(LooperMode.Mode.PAUSED)
class PrayerScheduleBackgroundHandlerTest {
    private lateinit var app: Application
    private lateinit var executor: ExecutorService
    private val responses = mutableListOf<Response>()

    private data class Response(val label: String, val value: Any?, val code: String?, val onMain: Boolean)
    private inner class Reply(private val label: String) : MethodChannel.Result {
        override fun success(result: Any?) = record(result, null)
        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = record(errorMessage, errorCode)
        override fun notImplemented() = record(null, "not_implemented")
        private fun record(value: Any?, code: String?) {
            responses.add(Response(label, value, code, Looper.myLooper() === Looper.getMainLooper()))
        }
    }

    @Before fun setup() {
        app = RuntimeEnvironment.getApplication()
        responses.clear()
        executor = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "test-prayer-worker").apply { isDaemon = true }
        }
        app.getSharedPreferences("salatime_prayer_widget", 0).edit().clear().apply()
        app.getSharedPreferences(AutomaticSilence.PREFS, 0).edit().clear().apply()
    }

    @After fun teardown() {
        executor.shutdownNow()
        assertTrue(executor.awaitTermination(5, TimeUnit.SECONDS))
        Shadows.shadowOf(Looper.getMainLooper()).idle()
    }

    private fun drain() {
        executor.submit {}.get(5, TimeUnit.SECONDS)
        Shadows.shadowOf(Looper.getMainLooper()).idle()
    }

    @Test fun aBlockedOperationLeavesTheMainLooperResponsiveAndUsesOnlyApplicationContext() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        var onWorker = false
        var actualContext: Context? = null
        val channel = PrayerScheduleBackgroundHandler(ContextWrapper(app), executor, operation = { context, _ ->
            onWorker = Looper.myLooper() !== Looper.getMainLooper()
            actualContext = context
            entered.countDown()
            check(release.await(5, TimeUnit.SECONDS))
            "routed"
        })
        try {
            assertTrue(channel.handle(MethodCall("routeAll", null), Reply("routeAll")))
            assertTrue(entered.await(5, TimeUnit.SECONDS))
            var mainTick = false
            Handler(Looper.getMainLooper()).post { mainTick = true }
            Shadows.shadowOf(Looper.getMainLooper()).idle()
            assertTrue(mainTick)
            assertTrue(responses.isEmpty())
            assertTrue(onWorker)
            assertSame(app, actualContext)
        } finally {
            release.countDown()
        }
        drain()
        assertEquals(listOf(Response("routeAll", "routed", null, true)), responses)
    }

    @Test fun updatesRoutesAndCancellationsKeepWorkAndReplyOrderAcrossHandlers() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val performed = Collections.synchronizedList(mutableListOf<String>())
        val operation: (Context, MethodCall) -> Any? = { _, call ->
            performed.add(call.method)
            if (call.method == "update") {
                entered.countDown()
                check(release.await(5, TimeUnit.SECONDS))
            }
            call.method
        }
        val first = PrayerScheduleBackgroundHandler(app, executor, operation = operation)
        val second = PrayerScheduleBackgroundHandler(ContextWrapper(app), executor, operation = operation)
        val methods = listOf("update", "cancel", "route", "routeAll", "cancelAll")
        try {
            assertTrue(first.handle(MethodCall("update", emptyMap<String, Any>()), Reply("update")))
            assertTrue(entered.await(5, TimeUnit.SECONDS))
            for (method in methods.drop(1)) {
                assertTrue(second.handle(MethodCall(method, mapOf("id" to 7)), Reply(method)))
            }
            assertEquals(listOf("update"), performed.toList())
            assertTrue(responses.isEmpty())
        } finally {
            release.countDown()
        }
        drain()
        assertEquals(methods, performed.toList())
        assertEquals(methods, responses.map { it.label })
        assertTrue(responses.all { it.onMain && it.code == null })
    }

    @Test fun operationFailuresKeepTheirCodesAndDoNotStopTheNextRequest() {
        val channel = PrayerScheduleBackgroundHandler(app, executor, operation = { _, call ->
            if (call.method != "route") throw IllegalStateException("failed ${call.method}")
            "recovered"
        })
        for (method in listOf("update", "cancel", "route")) {
            assertTrue(channel.handle(MethodCall(method, null), Reply(method)))
        }
        drain()
        assertEquals(listOf("alarm_routing_failed", "alarm_operation_failed", null), responses.map { it.code })
        assertEquals("recovered", responses.last().value)
        assertTrue(responses.all { it.onMain })
    }

    @Test fun statusSoundSettingsAndUnknownMethodsStayWithTheUiHandler() {
        var calls = 0
        val channel = PrayerScheduleBackgroundHandler(app, executor, operation = { _, _ -> calls++; null })
        for (method in listOf("status", "soundSettings", "unknown")) {
            assertFalse(channel.handle(MethodCall(method, null), Reply(method)))
        }
        drain()
        assertEquals(0, calls)
        assertTrue(responses.isEmpty())
    }

    @Test fun aRealUpdatePreservesWidgetMetadataAndRefreshesAutomaticSilence() {
        app.getSharedPreferences(AutomaticSilence.PREFS, 0).edit().putBoolean("active", true).apply()
        val channel = PrayerScheduleBackgroundHandler(app, executor)
        val args = mapOf(
            "city" to "Fès", "prayers" to "[]", "alarms" to "[]", "timeZone" to "Africa/Casablanca",
            "sinceLabel" to "Temps écoulé depuis @prayer", "locale" to "fr", "use24HourFormat" to true,
        )
        assertTrue(channel.handle(MethodCall("update", args), Reply("update")))
        drain()
        assertEquals(1, responses.size)
        assertNull(responses.single().code)
        assertTrue(responses.single().onMain)
        val preferences = app.getSharedPreferences("salatime_prayer_widget", 0)
        for ((key, value) in args) {
            if (value is String) assertEquals(value, preferences.getString(key, null))
        }
        assertTrue(preferences.getBoolean("use24HourFormat", false))
        assertFalse(app.getSharedPreferences(AutomaticSilence.PREFS, 0).getBoolean("active", true))
    }

    @Test fun rejectedSubmissionsAlsoReplyOnMainExactlyOnce() {
        val rejecting = Executor { throw RejectedExecutionException("stopped") }
        val channel = PrayerScheduleBackgroundHandler(app, rejecting)
        assertTrue(channel.handle(MethodCall("cancelAll", null), Reply("cancelAll")))
        Shadows.shadowOf(Looper.getMainLooper()).idle()
        assertEquals(listOf(Response("cancelAll", "stopped", "alarm_operation_failed", true)), responses)
    }

    @Test fun widgetOnlyUpdatePreservesAlarmManifestAndDoesNotRunAutomaticSilence() {
        val preferences = app.getSharedPreferences("salatime_prayer_widget", 0)
        preferences.edit().putString("alarms", "preserved-alarm-manifest")
            .putString("missedTitle", "preserved-title").apply()
        app.getSharedPreferences(AutomaticSilence.PREFS, 0).edit().putBoolean("active", true).apply()
        val channel = PrayerScheduleBackgroundHandler(app, executor)
        val prayers = """[{"at":2000000000000,"name":"Asr"}]"""
        assertTrue(channel.handle(MethodCall("updateWidget", mapOf(
            "prayers" to prayers, "city" to "Fès", "locale" to "fr",
            "timeZone" to "Africa/Casablanca", "use24HourFormat" to true,
            // The display-only operation cannot overwrite alarm data even if supplied.
            "alarms" to "[]", "missedTitle" to "changed",
        )), Reply("widget")))
        drain()
        assertNull(responses.single().code)
        assertTrue(responses.single().onMain)
        assertEquals(prayers, preferences.getString("prayers", null))
        assertEquals("Fès", preferences.getString("city", null))
        assertEquals("preserved-alarm-manifest", preferences.getString("alarms", null))
        assertEquals("preserved-title", preferences.getString("missedTitle", null))
        assertTrue(app.getSharedPreferences(AutomaticSilence.PREFS, 0).getBoolean("active", false))
    }

    @Test fun realBatchThenWidgetUpdateReusesArmedWindowButOrdinaryRefreshRepairsIt() {
        val channel = PrayerScheduleBackgroundHandler(app, executor)
        app.getSharedPreferences("salatime_prayer_widget", 0).edit().putString("timeZone", "UTC").commit()
        val at = System.currentTimeMillis() + 60000
        val notification = mapOf(
            "id" to 12000001, "title" to "Fajr", "body" to "Prayer",
            "scheduledDateTime" to LocalDateTime.ofInstant(Instant.ofEpochMilli(at), ZoneOffset.UTC).toString(),
            "timeZoneName" to "UTC",
            "payload" to """{"id":12000001,"prayerId":1,"kind":"adhan","at":$at,"prayerAt":$at}""",
            "platformSpecifics" to mapOf(
                "style" to 0, "styleInformation" to mapOf("htmlFormatTitle" to false, "htmlFormatContent" to false),
                "channelId" to "batch_test", "channelName" to "Prayer", "channelAction" to 0,
                "importance" to 4, "priority" to 2, "playSound" to false, "scheduleMode" to "exactAllowWhileIdle",
            ),
        )
        assertTrue(channel.handle(MethodCall("applyScheduleChanges", mapOf(
            "notifications" to listOf(notification), "cancelIds" to emptyList<Int>(),
        )), Reply("batch")))
        drain()
        assertNull(responses.last().code)
        assertEquals(1, (responses.last().value as Map<*, *>)["routed"])
        val manager = app.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        fun prayerAlarms() = Shadows.shadowOf(manager).scheduledAlarms.filter {
            val receiver = Shadows.shadowOf(it.operation).savedIntent.component?.className
            receiver == "com.dexterous.flutterlocalnotifications.SalaTimePrayerAlarmReceiver" ||
                receiver == "com.dexterous.flutterlocalnotifications.SalaTimePrayerWindowReceiver"
        }
        val before = prayerAlarms()
        assertEquals(2, before.size)
        val metadata = mapOf("city" to "Fès", "prayers" to "[]", "alarms" to "[]", "timeZone" to "UTC")
        assertTrue(channel.handle(MethodCall("update", metadata + ("scheduleAlreadyApplied" to true)), Reply("handoff")))
        drain()
        assertNull(responses.last().code)
        assertEquals(0, (responses.last().value as Map<*, *>)["routed"])
        assertEquals(before, prayerAlarms())
        assertEquals("Fès", app.getSharedPreferences("salatime_prayer_widget", 0).getString("city", null))

        assertTrue(channel.handle(MethodCall("update", metadata), Reply("ordinary")))
        drain()
        assertNull(responses.last().code)
        assertEquals(1, (responses.last().value as Map<*, *>)["routed"])
        assertFalse(before == prayerAlarms())

        assertTrue(channel.handle(MethodCall("update", metadata + mapOf(
            "scheduleAlreadyApplied" to true, "timeZone" to "Asia/Tokyo",
        )), Reply("zone-changed")))
        drain()
        assertNull(responses.last().code)
        assertEquals(1, (responses.last().value as Map<*, *>)["routed"])
        assertEquals("Asia/Tokyo", app.getSharedPreferences("salatime_alarm_window", 0).getString("timeZone", null))
    }
}
