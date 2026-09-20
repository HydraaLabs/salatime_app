package com.dexterous.flutterlocalnotifications;

import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.service.notification.StatusBarNotification;
import android.util.Log;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import org.json.JSONObject;

/** One persisted notification and one boundary alarm, independent of the audio service. */
public class SalaTimeAdhanNotificationReceiver extends BroadcastReceiver {
    private static final String STORE = "salatime_adhan_notification";
    private static final String ROW = "notification";

    private static SharedPreferences preferences(Context context) {
        return context.getSharedPreferences(STORE, Context.MODE_PRIVATE);
    }

    private static NotificationDetails saved(Context context) {
        String json = preferences(context).getString(ROW, null);
        return json == null ? null : FlutterLocalNotificationsPlugin.buildGson()
                .fromJson(json, NotificationDetails.class);
    }

    private static PendingIntent operation(Context context, int id) {
        return PendingIntent.getBroadcast(context, 0,
                new Intent(context, SalaTimeAdhanNotificationReceiver.class).putExtra("id", id),
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private static void clear(Context context) {
        AlarmManager alarms = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        alarms.cancel(operation(context, -1));
        preferences(context).edit().remove(ROW).apply();
    }

    private static void schedule(Context context, NotificationDetails details, JSONObject payload, long now) {
        AlarmManager alarms = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        PendingIntent operation = operation(context, details.id);
        long at = SalaTimeAdhanNotification.nextTransition(payload, now);
        if (at <= now) { alarms.cancel(operation); return; }
        // These are silent display changes, never alarm-clock/audio deliveries.
        // Exact permission is shared with existing prayer alarms; no new prompt.
        try {
            if (Build.VERSION.SDK_INT >= 31 && !alarms.canScheduleExactAlarms()) {
                throw new SecurityException("Exact alarms unavailable");
            }
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, operation);
        } catch (SecurityException denied) {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, operation);
        }
    }

    static void onPosted(Context context, NotificationDetails details) {
        try {
            JSONObject payload = new JSONObject(details.payload);
            if (!"adhan".equals(payload.optString("kind")) || payload.optBoolean("test", false)
                    || SalaTimeAdhanNotification.prayerAt(payload) <= 0) return;
            if (!preferences(context).edit().putString(ROW,
                    FlutterLocalNotificationsPlugin.buildGson().toJson(details)).commit()) {
                throw new IllegalStateException("Could not save notification transition");
            }
            schedule(context, details, payload, System.currentTimeMillis());
        } catch (Exception error) {
            Log.w("SalaTimeAlarms", "Could not schedule notification transition", error);
        }
    }

    @Override public void onReceive(Context context, Intent intent) {
        refresh(context, intent.getIntExtra("id", -1), System.currentTimeMillis());
    }

    static void restore(Context context) {
        refresh(context, -1, System.currentTimeMillis());
        SalaTimeNotificationTray.cleanupLegacy(context);
        SalaTimeNotificationTray.expire(context, System.currentTimeMillis());
    }

    static void refresh(Context context, int expectedId, long now) {
        // A background refresh must not overwrite the next prayer between its
        // notification post and saved-state commit (the display ID is shared).
        synchronized (SalaTimeNotificationTray.class) {
            refreshLocked(context, expectedId, now);
        }
    }

    private static void refreshLocked(Context context, int expectedId, long now) {
        try {
            NotificationDetails details = saved(context);
            if (details == null) { clear(context); return; }
            if (expectedId != -1 && expectedId != details.id) return; // A newer prayer replaced it.
            NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
            Notification active = null;
            int visibleId = SalaTimeNotificationTray.PRAYER_ID;
            // Adopt the notification saved by a pre-single-card version if still visible.
            for (StatusBarNotification row : manager.getActiveNotifications()) {
                if (row.getTag() == null && (row.getId() == SalaTimeNotificationTray.PRAYER_ID || row.getId() == details.id)) {
                    if (active == null || row.getId() == SalaTimeNotificationTray.PRAYER_ID) {
                        active = row.getNotification();
                        visibleId = row.getId();
                    }
                }
            }
            // In particular, never restore a user-dismissed notification or one cleared at reboot.
            if (active == null) { clear(context); return; }
            JSONObject payload = new JSONObject(details.payload);
            JSONObject next = SalaTimeAdhanNotification.nextPrayer(payload);
            if (now < SalaTimeAdhanNotification.prayerAt(payload)
                    || (next != null && now >= SalaTimeAdhanNotification.prayerAt(next))) {
                manager.cancel(visibleId);
                clear(context);
                return;
            }
            if ((active.flags & Notification.FLAG_ONGOING_EVENT) == 0) {
                Notification notification = SalaTimeAdhanNotification.silentNotification(context, details, now);
                if (notification == null) {
                    manager.cancel(visibleId);
                    clear(context);
                    return;
                }
                // Re-rank this existing card using its update time. Its custom
                // chronometer remains anchored to the scheduled prayer, and a
                // first late delivery still shows its original event time.
                notification.when = now;
                // One UI can retain the original position on an in-place update
                // even after `when` changes. Repost only this active, silent card
                // so its creation time is renewed too; never interrupt live audio.
                manager.cancel(visibleId);
                manager.notify(SalaTimeNotificationTray.PRAYER_ID, notification);
            }
            // An in-flight audio notification keeps its stop action. Its first transition is still an hour away.
            schedule(context, details, payload, now);
        } catch (Exception error) {
            Log.w("SalaTimeAlarms", "Could not update notification countdown", error);
        }
    }
}
