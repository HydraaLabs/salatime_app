package com.example.zabi

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.systemchannels.ProcessTextChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.text.ProcessTextPlugin
import java.util.concurrent.atomic.AtomicBoolean

/** Keeps text-selection actions usable when Android cannot launch their activity. */
class SafeProcessTextPlugin(channel: ProcessTextChannel) : ProcessTextPlugin(channel) {
    override fun processTextAction(
        id: String,
        text: String,
        readOnly: Boolean,
        result: MethodChannel.Result
    ) {
        val reply = SingleProcessTextReply(result)
        try {
            super.processTextAction(id, text, readOnly, reply)
        } catch (error: ActivityNotFoundException) {
            finishFailedLaunch(reply, error)
        } catch (error: IllegalStateException) {
            finishFailedLaunch(reply, error)
        } catch (error: SecurityException) {
            finishFailedLaunch(reply, error)
        }
    }

    private fun finishFailedLaunch(reply: SingleProcessTextReply, error: RuntimeException) {
        // The engine registers the pending result before startActivityForResult.
        // Its channel's exception handler otherwise replies without removing it,
        // so a later cancellation tries to complete the same Dart request twice.
        reply.error("text_action_unavailable", error.message, null)
        super.onActivityResult(reply.hashCode(), Activity.RESULT_CANCELED, null)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean =
        super.onActivityResult(
            requestCode,
            if (resultCode == Activity.RESULT_OK && data == null) Activity.RESULT_CANCELED else resultCode,
            data
        )

    companion object {
        fun install(engine: FlutterEngine) {
            if (engine.plugins.has(SafeProcessTextPlugin::class.java)) return
            engine.plugins.remove(ProcessTextPlugin::class.java)
            engine.plugins.add(SafeProcessTextPlugin(engine.processTextChannel))
        }
    }
}

internal class SingleProcessTextReply(private val delegate: MethodChannel.Result) : MethodChannel.Result {
    private val completed = AtomicBoolean(false)

    override fun success(result: Any?) {
        if (completed.compareAndSet(false, true)) delegate.success(result)
    }

    override fun error(code: String, message: String?, details: Any?) {
        if (completed.compareAndSet(false, true)) delegate.error(code, message, details)
    }

    override fun notImplemented() {
        if (completed.compareAndSet(false, true)) delegate.notImplemented()
    }
}
