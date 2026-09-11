package com.example.zabi

import android.hardware.GeomagneticField
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
                    for (key in listOf("alarms", "prayers", "city", "nextLabel", "emptyLabel", "missedTitle", "missedBody")) {
                        call.argument<String>(key)?.let { preferences.putString(key, it) }
                    }
                    preferences.apply()
                    PrayerWidgetProvider.refreshAll(this)
                    result.success(null)
                } else result.notImplemented()
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
