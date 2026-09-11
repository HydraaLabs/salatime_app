package com.example.zabi

import android.app.AlarmManager
import android.app.Application
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [24, 33], manifest = Config.NONE, application = Application::class)
class LauncherBadgeCleanerTest {
    private lateinit var app: Application
    private lateinit var manager: NotificationManager

    @Before fun setUp() {
        app = RuntimeEnvironment.getApplication()
        manager = app.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(
                "legacy-prayer", "Prayer", NotificationManager.IMPORTANCE_HIGH
            ).apply { setShowBadge(true) })
        }
    }

    @Suppress("DEPRECATION")
    private fun notification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(app, "legacy-prayer")
        } else Notification.Builder(app)
        return builder.setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Prayer").build()
    }

    @Test fun clearsTaggedAndUntaggedAlertsWithoutWaitingForPrayerScheduling() {
        manager.notify(1, notification())
        manager.notify("prayer", 1, notification())
        assertEquals(2, manager.activeNotifications.size)
        LauncherBadgeCleaner.clearDeliveredNotifications(app)
        assertTrue(manager.activeNotifications.isEmpty())
        // Reopening the app is harmless, and also clears subsequently delivered alerts.
        LauncherBadgeCleaner.clearDeliveredNotifications(app)
        manager.notify(2, notification())
        LauncherBadgeCleaner.clearDeliveredNotifications(app)
        assertTrue(manager.activeNotifications.isEmpty())
    }

    @Test fun keepsOngoingPlaybackAndForegroundServiceNotifications() {
        manager.notify(1, notification())
        manager.notify(2, notification().apply { flags = flags or Notification.FLAG_ONGOING_EVENT })
        manager.notify(3, notification().apply { flags = flags or Notification.FLAG_FOREGROUND_SERVICE })
        LauncherBadgeCleaner.clearDeliveredNotifications(app)
        assertEquals(setOf(2, 3), manager.activeNotifications.map { it.id }.toSet())
    }

    @Test fun keepsFuturePrayerAlarmEvenWhenItSharesTheDeliveredNotificationId() {
        val alarms = app.getSystemService(AlarmManager::class.java)
        val pending = PendingIntent.getBroadcast(app, 1,
            Intent("net.salatime.app.TEST_PRAYER").setPackage(app.packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        alarms.set(AlarmManager.ELAPSED_REALTIME_WAKEUP,
            SystemClock.elapsedRealtime() + 60000, pending)
        manager.notify(1, notification())
        LauncherBadgeCleaner.clearDeliveredNotifications(app)
        assertTrue(manager.activeNotifications.isEmpty())
        assertEquals(1, Shadows.shadowOf(alarms).scheduledAlarms.size)
    }
}
