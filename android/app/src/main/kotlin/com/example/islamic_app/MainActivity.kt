package com.example.zabi

import android.hardware.GeomagneticField
import android.content.Intent
import android.provider.Settings
import android.view.KeyEvent
import com.dexterous.flutterlocalnotifications.SalaTimeAdhanService
import com.dexterous.flutterlocalnotifications.SalaTimePrayerAlarms
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceFragmentActivity() {
    private val adhanVolumeKeys = AdhanVolumeKeyDispatcher(SalaTimeAdhanService::stopFromVolumeKey)

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (adhanVolumeKeys.dispatch(event.action, event.keyCode, event.repeatCount)) return true
        return super.dispatchKeyEvent(event)
    }

    private val silenceAccessReceiver = AutomaticSilenceReceiver()

    override fun onStart() {
        super.onStart()
        androidx.core.content.ContextCompat.registerReceiver(this, silenceAccessReceiver,
            android.content.IntentFilter(android.app.NotificationManager.ACTION_NOTIFICATION_POLICY_ACCESS_GRANTED_CHANGED),
            androidx.core.content.ContextCompat.RECEIVER_NOT_EXPORTED)
    }

    override fun onStop() {
        runCatching { unregisterReceiver(silenceAccessReceiver) }
        super.onStop()
    }

    private var soundImportResult: MethodChannel.Result? = null
    private val soundExecutor = java.util.concurrent.Executors.newSingleThreadExecutor()

    @Deprecated("Android activity result bridge for Flutter")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 8471) return
        val reply = soundImportResult ?: return
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            soundImportResult = null
            reply.success(null)
            return
        }
        soundExecutor.execute {
            try {
                val imported = PersonalSoundFiles.importSound(applicationContext, uri)
                runOnUiThread { if (soundImportResult === reply) { soundImportResult = null; reply.success(imported) } }
            } catch (error: Exception) {
                val code = error.message?.takeIf { it in listOf("sound_too_large", "sound_duration_invalid", "sound_invalid", "sound_library_full") } ?: "sound_import_failed"
                runOnUiThread { if (soundImportResult === reply) { soundImportResult = null; reply.error(code, code, null) } }
            }
        }
    }

    override fun onDestroy() {
        soundImportResult?.error("sound_import_cancelled", "sound_import_cancelled", null)
        soundImportResult = null
        soundExecutor.shutdown()
        super.onDestroy()
    }

    override fun onResume() {
        super.onResume()
        LauncherBadgeCleaner.clearDeliveredNotifications(this)
        runCatching { AutomaticSilence.refresh(this) }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "net.salatime.app/automatic_silence")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "get" -> { AutomaticSilence.refresh(this); result.success(AutomaticSilence.status(this)) }
                        "set" -> { AutomaticSilence.configure(this, call.arguments as? Map<*, *> ?: emptyMap<String, Any>()); result.success(AutomaticSilence.status(this)) }
                        "requestAccess" -> { AutomaticSilence.openAccessSettings(this); result.success(null) }
                        "requestExact" -> { AutomaticSilence.openExactSettings(this); result.success(null) }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    val code = error.message?.takeIf { it in listOf("silence_unsupported", "silence_access_needed", "silence_exact_needed") } ?: "silence_save_error"
                    result.error(code, code, null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "net.salatime.app/personal_sounds")
            .setMethodCallHandler { call, result ->
                if (call.method != "import") { result.notImplemented(); return@setMethodCallHandler }
                if (soundImportResult != null) { result.error("sound_import_busy", "sound_import_busy", null); return@setMethodCallHandler }
                soundImportResult = result
                try {
                    startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        type = "audio/*"
                        addCategory(Intent.CATEGORY_OPENABLE)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }, 8471)
                } catch (error: Exception) { soundImportResult = null; result.error("sound_import_failed", "sound_import_failed", null) }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "net.salatime.app/prayer_widget")
            .setMethodCallHandler { call, result ->
                try {
                    val prefs = getSharedPreferences("salatime_widget_options", MODE_PRIVATE)
                    when (call.method) {
                        "get" -> result.success(mapOf(
                            "countdown" to prefs.getBoolean("countdown", true),
                            "seconds" to prefs.getBoolean("seconds", true),
                            "city" to prefs.getBoolean("city", true),
                            "date" to prefs.getBoolean("date", true),
                            "illustration" to prefs.getBoolean("illustration", true),
                            "opacity" to prefs.getInt("opacity", 100)))
                        "set" -> {
                            val edit = prefs.edit()
                            for (key in listOf("countdown", "seconds", "city", "date", "illustration")) {
                                call.argument<Boolean>(key)?.let { edit.putBoolean(key, it) }
                            }
                            call.argument<Number>("opacity")?.let { edit.putInt("opacity", it.toInt().coerceIn(0, 100)) }
                            edit.apply()
                            PrayerWidgetProvider.refreshAll(this)
                            result.success(null)
                        }
                        "canPin" -> {
                            val manager = android.appwidget.AppWidgetManager.getInstance(this)
                            val hasWidget = listOf(PrayerWidgetProvider::class.java, SmallPrayerWidgetProvider::class.java, LargePrayerWidgetProvider::class.java)
                                .any { manager.getAppWidgetIds(android.content.ComponentName(this, it)).isNotEmpty() }
                            result.success(!hasWidget && android.os.Build.VERSION.SDK_INT >= 26 && manager.isRequestPinAppWidgetSupported)
                        }
                        "pin" -> {
                            val manager = android.appwidget.AppWidgetManager.getInstance(this)
                            val provider = when (call.argument<String>("size")) {
                                "small" -> SmallPrayerWidgetProvider::class.java
                                "large" -> LargePrayerWidgetProvider::class.java
                                else -> PrayerWidgetProvider::class.java
                            }
                            result.success(android.os.Build.VERSION.SDK_INT >= 26 && manager.isRequestPinAppWidgetSupported &&
                                manager.requestPinAppWidget(android.content.ComponentName(this, provider), null, null))
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) { result.error("widget_settings_failed", error.message, null) }
            }

        val prayerSchedule = PrayerScheduleBackgroundHandler(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "net.salatime.app/prayer_schedule")
            .setMethodCallHandler { call, result ->
                if (prayerSchedule.handle(call, result)) return@setMethodCallHandler
                try {
                    when (call.method) {
                        "status" -> result.success(SalaTimePrayerAlarms.status(this))
                        "soundSettings" -> { startActivity(Intent(Settings.ACTION_SOUND_SETTINGS)); result.success(null) }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) { result.error("alarm_operation_failed", error.message, null) }
            }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "net.salatime.app/geomagnetic"
        ).setMethodCallHandler { call, result ->
            if (call.method != "getDeclination") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val latitude = call.argument<Number>("latitude")?.toDouble()
            val longitude = call.argument<Number>("longitude")?.toDouble()
            val altitude = call.argument<Number>("altitude")?.toDouble() ?: 0.0
            val timestamp = call.argument<Number>("timestamp")?.toLong()
                ?: System.currentTimeMillis()

            if (latitude == null || longitude == null) {
                result.error("INVALID_LOCATION", "Latitude and longitude are required", null)
                return@setMethodCallHandler
            }

            val field = GeomagneticField(
                latitude.toFloat(),
                longitude.toFloat(),
                altitude.toFloat(),
                timestamp
            )
            result.success(field.declination.toDouble())
        }
    }
}

/** Retains consumed key sequences after the adhan service has already stopped. */
internal class AdhanVolumeKeyDispatcher(private val stopFromVolumeKey: (Int) -> Boolean) {
    private val consumedKeys = mutableSetOf<Int>()

    fun dispatch(action: Int, keyCode: Int, repeatCount: Int = 0): Boolean {
        if (keyCode != KeyEvent.KEYCODE_VOLUME_UP &&
            keyCode != KeyEvent.KEYCODE_VOLUME_DOWN &&
            keyCode != KeyEvent.KEYCODE_VOLUME_MUTE) return false

        return when (action) {
            KeyEvent.ACTION_DOWN -> {
                if (repeatCount > 0 && keyCode in consumedKeys) {
                    true
                } else {
                    // A release may be lost when the window loses focus. A new
                    // physical press must still control normal media afterward.
                    consumedKeys.remove(keyCode)
                    if (stopFromVolumeKey(keyCode)) {
                        consumedKeys.add(keyCode)
                        true
                    } else {
                        false
                    }
                }
            }
            KeyEvent.ACTION_UP -> consumedKeys.remove(keyCode)
            else -> false
        }
    }
}
