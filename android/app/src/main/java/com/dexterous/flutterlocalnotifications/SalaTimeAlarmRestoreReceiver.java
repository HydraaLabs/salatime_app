package com.dexterous.flutterlocalnotifications;

import android.app.AlarmManager;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.util.Log;
import androidx.core.app.NotificationCompat;
import com.example.zabi.PrayerWidgetProvider;
import org.json.JSONArray;
import org.json.JSONObject;

/** Compatibility adapter for flutter_local_notifications 17.2.4's persisted alarms.
 * Same package permits calling its rescheduler without reflection or a fork.
 * Covered by native tests; review when upgrading the notifications plugin.
 */
public class SalaTimeAlarmRestoreReceiver extends BroadcastReceiver {
    private static final String STORE = "scheduled_notifications";
    @Override public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        if (!Intent.ACTION_BOOT_COMPLETED.equals(action)
                && !Intent.ACTION_MY_PACKAGE_REPLACED.equals(action)
                && !Intent.ACTION_TIME_CHANGED.equals(action)
                && !Intent.ACTION_TIMEZONE_CHANGED.equals(action)
                && !AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED.equals(action)) return;
        SalaTimeAdhanNotificationReceiver.restore(context);
        try {
            boolean missed = repairCache(context, System.currentTimeMillis());
            // Time/permission changes may happen with all custom alarms still
            // armed. Avoid doubling the 450-alarm window while rebuilding it.
            SalaTimePrayerAlarms.cancelAll(context);
            try { FlutterLocalNotificationsPlugin.rescheduleNotifications(context); }
            finally { SalaTimePrayerAlarms.routeAll(context); }
            if (missed && Intent.ACTION_BOOT_COMPLETED.equals(action)) showMissedNotice(context);
            PrayerWidgetProvider.refreshAll(context);
        } catch (Exception error) {
            Log.e("SalaTimeAlarms", "Could not restore prayer alarms", error);
        }
    }

    public static boolean repairCache(Context context, long now) throws Exception {
        SharedPreferences preferences = context.getSharedPreferences(STORE, Context.MODE_PRIVATE);
        JSONArray old = new JSONArray(preferences.getString(STORE, "[]"));
        JSONArray future = new JSONArray();
        AlarmManager manager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        boolean exact = Build.VERSION.SDK_INT < 31 || manager.canScheduleExactAlarms();
        boolean missed = false;
        for (int i = 0; i < old.length(); i++) {
            JSONObject notification = old.getJSONObject(i);
            // Use the same ownership/shape check as native delivery. Extra reminders
            // intentionally have no prayerId and must also be pruned/downgraded at boot.
            JSONObject payload = SalaTimePrayerAlarms.prayer(notification);
            if (payload == null) { future.put(notification); continue; }
            int id = notification.getInt("id");
            if (payload.getLong("at") <= now) {
                SalaTimePrayerAlarms.cancel(context, id);
                SalaTimePrayerAlarms.cancelLegacy(context, id);
                if ("adhan".equals(payload.optString("kind"))) missed = true;
                continue;
            }
            notification.put("scheduleMode", exact ? "exactAllowWhileIdle" : "inexactAllowWhileIdle");
            future.put(notification);
        }
        // Persist before rescheduling: expired prayers must never play together at boot.
        if (!preferences.edit().putString(STORE, future.toString()).commit()) {
            throw new IllegalStateException("Unable to save restored prayer schedule");
        }
        return missed;
    }

    private void showMissedNotice(Context context) {
        NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        String channel = "prayer_missed_no_badge_v1";
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationChannel config = new NotificationChannel(channel, "SalaTime", NotificationManager.IMPORTANCE_LOW);
            config.setShowBadge(false);
            config.setSound(null, null);
            config.enableVibration(false);
            manager.createNotificationChannel(config);
        }
        SharedPreferences preferences = context.getSharedPreferences("salatime_prayer_widget", Context.MODE_PRIVATE);
        try {
            manager.notify(9900, new NotificationCompat.Builder(context, channel)
                    .setSmallIcon(com.example.zabi.R.mipmap.launcher_icon)
                    .setContentTitle(preferences.getString("missedTitle", "SalaTime"))
                    .setContentText(preferences.getString("missedBody", "Open SalaTime to view prayer times."))
                    .setContentIntent(PrayerWidgetProvider.openApp(context))
                    .setSilent(true).setNumber(0).setAutoCancel(true).build());
        } catch (SecurityException ignored) { /* Notifications disabled by the user. */ }
    }
}
