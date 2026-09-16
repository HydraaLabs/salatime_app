package com.dexterous.flutterlocalnotifications;

import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.service.notification.StatusBarNotification;
import androidx.core.app.NotificationCompat;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import org.json.JSONObject;

/** Display IDs are independent from the unique IDs used to schedule future alarms. */
public class SalaTimeNotificationTray extends BroadcastReceiver {
    static final int PRAYER_ID = 9901;
    static final int REMINDER_ID = 9902;
    static final long REMINDER_DURATION = 60000;
    private static final String STORE = "salatime_notification_tray";
    private static final String EXPIRES = "reminderExpiresAt";

    static int displayId(NotificationDetails details) {
        try {
            JSONObject payload = new JSONObject(details.payload);
            return "adhan".equals(payload.optString("kind")) && !payload.optBoolean("test", false)
                    ? PRAYER_ID : REMINDER_ID;
        } catch (Exception ignored) { return details.id; }
    }

    private static NotificationManager manager(Context context) {
        return (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
    }

    static synchronized void post(Context context, NotificationDetails details, Notification notification) {
        int id = displayId(details);
        if (id == REMINDER_ID) {
            long now = System.currentTimeMillis();
            long expires = now + REMINDER_DURATION;
            try {
                JSONObject payload = new JSONObject(details.payload);
                if ("before".equals(payload.optString("kind"))) {
                    long prayerAt = payload.optLong("prayerAt", expires);
                    if (prayerAt > now) expires = Math.min(expires, prayerAt);
                }
            } catch (Exception ignored) { /* The native expiry still bounds the alert. */ }
            notification = new NotificationCompat.Builder(context, notification)
                    .setTimeoutAfter(expires - now).setOnlyAlertOnce(false).setNumber(0).build();
            context.getSharedPreferences(STORE, 0).edit().putLong(EXPIRES, expires).commit();
            armExpiry(context, expires);
        } else if (id == PRAYER_ID) {
            clearReminder(context);
        }
        manager(context).notify(id, notification);
        SalaTimeAdhanNotificationReceiver.onPosted(context, details);
        cleanupLegacy(context);
    }

    static synchronized void foregroundPosted(Context context, NotificationDetails details) {
        SalaTimeAdhanNotificationReceiver.onPosted(context, details);
        if (displayId(details) == PRAYER_ID) clearReminder(context);
        cleanupLegacy(context);
    }

    /** Only our old prayer/reminder IDs are removed; future AlarmManager entries are untouched. */
    static synchronized void cleanupLegacy(Context context) {
        for (StatusBarNotification row : manager(context).getActiveNotifications()) {
            int id = row.getId();
            boolean legacy = (id >= 10000000 && id < 30000000)
                    || (id >= 1 && id <= 5) || (id >= 1001 && id <= 1005)
                    || (id >= 2001 && id <= 2005);
            if (!legacy) continue;
            Notification notification = row.getNotification();
            if ((notification.flags & Notification.FLAG_FOREGROUND_SERVICE) != 0) continue;
            if (Build.VERSION.SDK_INT >= 26) {
                String channel = notification.getChannelId();
                if (channel == null || !(channel.startsWith("adhan_") || channel.startsWith("before_adhan_")
                        || channel.startsWith("after_adhan_") || channel.startsWith("extra_")
                        || channel.equals(SalaTimeAdhanNotification.TRACKING_CHANNEL))) continue;
            }
            manager(context).cancel(row.getTag(), id);
        }
    }

    private static PendingIntent expiry(Context context) {
        return PendingIntent.getBroadcast(context, 0, new Intent(context, SalaTimeNotificationTray.class),
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private static void armExpiry(Context context, long at) {
        AlarmManager alarms = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        PendingIntent operation = expiry(context);
        try {
            if (Build.VERSION.SDK_INT >= 31 && !alarms.canScheduleExactAlarms()) {
                throw new SecurityException("Exact alarms unavailable");
            }
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, operation);
        } catch (SecurityException denied) {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, operation);
        }
    }

    private static void clearReminder(Context context) {
        manager(context).cancel(REMINDER_ID);
        ((AlarmManager) context.getSystemService(Context.ALARM_SERVICE)).cancel(expiry(context));
        context.getSharedPreferences(STORE, 0).edit().remove(EXPIRES).apply();
    }

    static synchronized void expire(Context context, long now) {
        long at = context.getSharedPreferences(STORE, 0).getLong(EXPIRES, 0);
        if (at > now) { armExpiry(context, at); return; } // An older delivery must not hide a newer alert.
        clearReminder(context);
    }

    @Override public void onReceive(Context context, Intent intent) {
        expire(context, System.currentTimeMillis());
    }
}
