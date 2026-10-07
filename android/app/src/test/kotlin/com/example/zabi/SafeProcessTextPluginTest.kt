package com.example.zabi

import android.app.Activity
import android.app.Application
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.ApplicationInfo
import android.content.pm.ResolveInfo
import io.flutter.embedding.engine.FlutterJNI
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.systemchannels.ProcessTextChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.text.ProcessTextPlugin
import java.lang.reflect.Proxy
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE, application = Application::class)
class SafeProcessTextPluginTest {
    class TextActivity : Activity() {
        var requestCode: Int? = null
        var launchError: RuntimeException? = null
        override fun startActivityForResult(intent: Intent, requestCode: Int) {
            this.requestCode = requestCode
            launchError?.let { throw it }
        }
    }

    private class Reply : MethodChannel.Result {
        var calls = 0
        var errorCode: String? = null
        var value: Any? = null
        override fun success(result: Any?) { check(++calls == 1) { "Reply already submitted" }; value = result }
        override fun error(code: String, message: String?, details: Any?) { check(++calls == 1) { "Reply already submitted" }; errorCode = code }
        override fun notImplemented() { check(++calls == 1) { "Reply already submitted" } }
    }

    private data class Harness(val activity: TextActivity, val channel: ProcessTextChannel, val plugin: ProcessTextPlugin) {
        fun launch(reply: Reply) {
            plugin.queryTextActions()
            channel.parsingMethodHandler.onMethodCall(
                MethodCall("ProcessText.processTextAction", arrayListOf("TranslateActivity", "hello", false)), reply
            )
        }
    }

    private fun harness(safe: Boolean = true): Harness {
        val app = RuntimeEnvironment.getApplication()
        val activity = Robolectric.buildActivity(TextActivity::class.java).setup().get()
        val resolveInfo = ResolveInfo().apply {
            nonLocalizedLabel = "Translate"
            activityInfo = ActivityInfo().apply {
                name = "TranslateActivity"
                packageName = "example.translate"
                applicationInfo = ApplicationInfo()
            }
        }
        Shadows.shadowOf(app.packageManager).addResolveInfoForIntent(
            Intent(Intent.ACTION_PROCESS_TEXT).setType("text/plain"), resolveInfo
        )
        val executor = DartExecutor(FlutterJNI(), app.assets)
        val channel = ProcessTextChannel(executor, app.packageManager)
        val plugin = if (safe) SafeProcessTextPlugin(channel) else ProcessTextPlugin(channel)
        val binding = Proxy.newProxyInstance(
            ActivityPluginBinding::class.java.classLoader,
            arrayOf(ActivityPluginBinding::class.java)
        ) { _, method, _ ->
            when (method.name) { "getActivity" -> activity; "getLifecycle" -> Any(); else -> null }
        } as ActivityPluginBinding
        plugin.onAttachedToActivity(binding)
        return Harness(activity, channel, plugin)
    }

    @Test fun failedLaunchIsCompletedOnceEvenWhenAndroidLaterReturnsCancellation() {
        for (error in listOf(IllegalStateException("activity state"), ActivityNotFoundException("missing action"), SecurityException("activity access"))) {
            val harness = harness()
            harness.activity.launchError = error
            val reply = Reply()
            harness.launch(reply)
            assertEquals("text_action_unavailable", reply.errorCode)
            assertEquals(1, reply.calls)
            assertFalse(harness.plugin.onActivityResult(harness.activity.requestCode!!, Activity.RESULT_CANCELED, null))
            assertEquals(1, reply.calls)
        }
    }

    @Test fun successfulTextActionAndCancellationPreserveTheirResults() {
        val harness = harness()
        val reply = Reply()
        harness.launch(reply)
        val request = harness.activity.requestCode!!
        assertTrue(harness.plugin.onActivityResult(request, Activity.RESULT_OK, Intent().putExtra(Intent.EXTRA_PROCESS_TEXT, "bonjour")))
        assertEquals("bonjour", reply.value)
        assertFalse(harness.plugin.onActivityResult(request, Activity.RESULT_CANCELED, null))
        assertEquals(1, reply.calls)

        val cancelled = Reply()
        harness.launch(cancelled)
        assertTrue(harness.plugin.onActivityResult(harness.activity.requestCode!!, Activity.RESULT_CANCELED, null))
        assertNull(cancelled.value)
        assertEquals(1, cancelled.calls)
    }

    @Test fun emptySuccessfulAndroidResultIsTreatedAsCancellation() {
        val harness = harness()
        val reply = Reply()
        harness.launch(reply)
        assertTrue(harness.plugin.onActivityResult(harness.activity.requestCode!!, Activity.RESULT_OK, null))
        assertEquals(1, reply.calls)
        assertNull(reply.value)
    }

    @Test fun legacyEngineReproducesDoubleReplyAfterFailedLaunch() {
        val harness = harness(safe = false)
        harness.activity.launchError = IllegalStateException("activity state")
        val reply = Reply()
        harness.launch(reply)
        assertEquals(1, reply.calls)
        assertThrows(IllegalStateException::class.java) {
            harness.plugin.onActivityResult(harness.activity.requestCode!!, Activity.RESULT_CANCELED, null)
        }
    }
}
