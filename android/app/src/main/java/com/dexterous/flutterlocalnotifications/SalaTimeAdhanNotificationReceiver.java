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
import androidx.core.app.NotificationCompat;
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
            NotificationDetails previous = saved(context);
            if (previous != null && !previous.id.equals(details.id)) {
                ((NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE)).cancel(previous.id);
            }
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
    }

    static void refresh(Context context, int expectedId, long now) {
        try {
            NotificationDetails details = saved(context);
            if (details == null) { clear(context); return; }
            if (expectedId != -1 && expectedId != details.id) return; // A newer prayer replaced it.
            NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
            Notification active = null;
            for (StatusBarNotification row : manager.getActiveNotifications()) {
                if (row.getId() == details.id && row.getTag() == null) active = row.getNotification();
            }
            // In particular, never restore a user-dismissed notification or one cleared at reboot.
            if (active == null) { clear(context); return; }
            JSONObject payload = new JSONObject(details.payload);
            JSONObject next = SalaTimeAdhanNotification.nextPrayer(payload);
            if (now < SalaTimeAdhanNotification.prayerAt(payload)
                    || (next != null && now >= SalaTimeAdhanNotification.prayerAt(next))) {
                manager.cancel(details.id);
                clear(context);
                return;
            }
            if ((active.flags & Notification.FLAG_ONGOING_EVENT) == 0) {
                Notification base = FlutterLocalNotificationsPlugin.createNotification(context, details);
                Notification notification = SalaTimeAdhanNotification.decorate(context, details, base, now)
                        .setSilent(true).setOnlyAlertOnce(true).setPriority(NotificationCompat.PRIORITY_LOW).build();
                manager.notify(details.id, notification);
            }
            // An in-flight audio notification keeps its stop action. Its first transition is still an hour away.
            schedule(context, details, payload, now);
        } catch (Exception error) {
            Log.w("SalaTimeAlarms", "Could not update notification countdown", error);
        }
    }
}
