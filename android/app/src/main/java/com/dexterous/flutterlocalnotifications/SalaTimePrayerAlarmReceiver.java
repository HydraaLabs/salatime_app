package com.dexterous.flutterlocalnotifications;

import android.app.Notification;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.content.ContextCompat;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import org.json.JSONObject;

public class SalaTimePrayerAlarmReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        try {
            int id = intent.getIntExtra("id", -1);
            JSONObject row = SalaTimePrayerAlarms.find(context, id);
            if (row == null) return; // Already delivered, cancelled or skipped.
            JSONObject payload = SalaTimePrayerAlarms.prayer(row);
            if (payload == null || payload.getLong("at") != intent.getLongExtra("at", -1)) return;
            long now = System.currentTimeMillis();
            String policy = SalaTimePrayerAlarms.deliveryPolicy(payload, now);
            if ("early".equals(policy)) {
                SalaTimePrayerAlarms.register(context, row, now);
                return;
            }
            FlutterLocalNotificationsPlugin.removeNotificationFromCache(context, id);
            SalaTimePrayerAlarms.cancel(context, id);
            SalaTimePrayerAlarms.record(context, payload, now, policy);
            if ("expired".equals(policy)) return;
            NotificationDetails details = FlutterLocalNotificationsPlugin.buildGson()
                    .fromJson(row.toString(), NotificationDetails.class);
            details.when = payload.getLong("at");
            details.showWhen = true;
            if ("late_silent".equals(policy)) {
                showSilent(context, details);
            } else if ("adhan".equals(payload.getString("kind"))
                    && details.sound != null && details.sound.startsWith("azan_")) {
                try {
                    ContextCompat.startForegroundService(context,
                            new Intent(context, SalaTimeAdhanService.class)
                                    .putExtra("notification", row.toString()));
                } catch (RuntimeException unavailable) {
                    SalaTimePrayerAlarms.record(context, payload, now, "audio_unavailable");
                    FlutterLocalNotificationsPlugin.showNotification(context, details);
                    Log.w("SalaTimeAlarms", "Adhan service unavailable; using notification sound", unavailable);
                }
            } else {
                FlutterLocalNotificationsPlugin.showNotification(context, details);
            }
        } catch (Exception error) {
            Log.e("SalaTimeAlarms", "Could not deliver prayer alarm", error);
        }
    }

    static void showSilent(Context context, NotificationDetails details) {
        Notification notification = new NotificationCompat.Builder(context,
                FlutterLocalNotificationsPlugin.createNotification(context, details))
                .setSilent(true).build();
        NotificationManagerCompat.from(context).notify(details.id, notification);
    }
}
