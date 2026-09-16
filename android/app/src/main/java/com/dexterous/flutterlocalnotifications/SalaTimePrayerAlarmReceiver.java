package com.dexterous.flutterlocalnotifications;

import android.app.Notification;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;
import androidx.core.app.NotificationManagerCompat;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import org.json.JSONObject;

public class SalaTimePrayerAlarmReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        receiveAt(context, intent, System.currentTimeMillis());
    }

    void receiveAt(Context context, Intent intent, long now) {
        synchronized (SalaTimePrayerAlarms.class) {
            receiveLocked(context, intent, now);
        }
    }

    private void receiveLocked(Context context, Intent intent, long now) {
        boolean consumed = false;
        try {
            int id = intent.getIntExtra("id", -1);
            JSONObject row = SalaTimePrayerAlarms.find(context, id);
            if (row == null) return; // Already delivered, cancelled or skipped.
            JSONObject payload = SalaTimePrayerAlarms.prayer(row);
            if (payload == null || payload.getLong("at") != intent.getLongExtra("at", -1)) return;
            String policy = SalaTimePrayerAlarms.deliveryPolicy(payload, now);
            if ("early".equals(policy)) {
                SalaTimePrayerAlarms.register(context, row, now);
                return;
            }
            FlutterLocalNotificationsPlugin.removeNotificationFromCache(context, id);
            consumed = true;
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
                    && SalaTimeAdhanService.isDeviceMuted(context)) {
                SalaTimePrayerAlarms.record(context, payload, now, "audio_muted");
                showSilent(context, details);
            } else if ("adhan".equals(payload.getString("kind"))
                    && details.sound != null && ((com.example.zabi.BundledNotificationSounds.contains(details.sound) && !"silent".equals(details.sound)) || com.example.zabi.PersonalSoundFiles.isSoundUri(context, details.sound))) {
                try {
                    SalaTimeAlarmWakeLock.start(context,
                            new Intent(context, SalaTimeAdhanService.class)
                                    .putExtra("notification", row.toString()));
                } catch (RuntimeException unavailable) {
                    SalaTimePrayerAlarms.record(context, payload, now, "audio_unavailable");
                    // Never replace a controllable player with an alarm-channel
                    // sound that ignores mute/stop controls if startup fails.
                    showSilent(context, details);
                    Log.w("SalaTimeAlarms", "Adhan service unavailable; keeping a silent notification", unavailable);
                }
            } else {
                if ("adhan".equals(payload.getString("kind"))) {
                    if (!Boolean.TRUE.equals(details.playSound)) {
                        showSilent(context, details);
                    } else {
                        SalaTimeNotificationTray.post(context, details,
                                SalaTimeAdhanNotification.builder(context, details)
                                        .setOnlyAlertOnce(false).build());
                    }
                } else {
                    SalaTimeNotificationTray.post(context, details,
                            FlutterLocalNotificationsPlugin.createNotification(context, details));
                }
            }
        } catch (Exception error) {
            Log.e("SalaTimeAlarms", "Could not deliver prayer alarm", error);
        } finally {
            if (consumed) {
                try { SalaTimePrayerAlarms.renewIfNeeded(context, now); }
                catch (Exception error) { Log.e("SalaTimeAlarms", "Could not extend the prayer alarm window", error); }
            }
        }
    }

    static void showSilent(Context context, NotificationDetails details) {
        Notification notification = SalaTimeAdhanNotification.silentNotification(context, details, System.currentTimeMillis());
        if (notification == null) {
            NotificationManagerCompat.from(context).cancel(SalaTimeNotificationTray.displayId(details));
            return;
        }
        SalaTimeNotificationTray.post(context, details, notification);
    }
}
