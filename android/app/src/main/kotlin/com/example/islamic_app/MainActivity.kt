package com.example.zabi

import android.hardware.GeomagneticField
import android.content.Intent
import android.provider.Settings
import com.dexterous.flutterlocalnotifications.SalaTimePrayerAlarms
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceFragmentActivity() {
    override fun onResume() {
        super.onResume()
        LauncherBadgeCleaner.clearDeliveredNotifications(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "net.salatime.app/prayer_schedule")
            .setMethodCallHandler { call, result ->
                if (call.method == "update") {
                    val preferences = getSharedPreferences("salatime_prayer_widget", MODE_PRIVATE).edit()
                    for (key in listOf("alarms", "prayers", "city", "nextLabel", "emptyLabel", "missedTitle", "missedBody", "locale", "timeZone")) {
                        call.argument<String>(key)?.let { preferences.putString(key, it) }
                    }
                    call.argument<Boolean>("use24HourFormat")?.let {
                        preferences.putBoolean("use24HourFormat", it)
                    }
                    preferences.apply()
                    PrayerWidgetProvider.refreshAll(this)
                    try { result.success(SalaTimePrayerAlarms.routeAll(this)) }
                    catch (error: Exception) { result.error("alarm_routing_failed", error.message, null) }
                } else {
                    try {
                        when (call.method) {
                            "route" -> {
                                val id = call.argument<Number>("id")?.toInt()
                                result.success(if (id == null) SalaTimePrayerAlarms.routeAll(this)
                                    else SalaTimePrayerAlarms.route(this, id))
                            }
                            "cancel" -> {
                                SalaTimePrayerAlarms.cancel(this, call.argument<Number>("id")!!.toInt())
                                result.success(null)
                            }
                            "cancelAll" -> { SalaTimePrayerAlarms.cancelAll(this); result.success(null) }
                            "status" -> result.success(SalaTimePrayerAlarms.status(this))
                            "soundSettings" -> { startActivity(Intent(Settings.ACTION_SOUND_SETTINGS)); result.success(null) }
                            else -> result.notImplemented()
                        }
                    } catch (error: Exception) { result.error("alarm_operation_failed", error.message, null) }
                }
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
