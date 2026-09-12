package com.example.zabi

import android.app.Application
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
}
