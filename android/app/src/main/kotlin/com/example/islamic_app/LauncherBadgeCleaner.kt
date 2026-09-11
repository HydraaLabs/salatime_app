package com.example.zabi

import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.util.Log

internal object LauncherBadgeCleaner {
    fun clearDeliveredNotifications(context: Context) {
        try {
            val manager = context.getSystemService(NotificationManager::class.java) ?: return
            for (active in manager.activeNotifications) {
                val protectedFlags = Notification.FLAG_ONGOING_EVENT or
                    Notification.FLAG_FOREGROUND_SERVICE
                if (active.notification.flags and protectedFlags == 0) {
                    // Only dismiss already delivered alerts. Unlike the Flutter plugin's
                    // cancel/cancelAll, this does not remove scheduled prayer alarms.
                    // Include tagged notifications and legacy channels, even when the
                    // network or exact-alarm permission prevents channel migration.
                    manager.cancel(active.tag, active.id)
                }
            }
        } catch (error: RuntimeException) {
            // A launcher/device-specific failure must never prevent the app opening.
            Log.w("SalaTimeBadge", "Unable to clear delivered notifications", error)
        }
    }
}
