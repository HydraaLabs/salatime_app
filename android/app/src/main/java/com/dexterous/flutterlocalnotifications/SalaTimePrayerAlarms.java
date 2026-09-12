package com.dexterous.flutterlocalnotifications;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.media.AudioManager;
import android.os.Build;
import android.os.PowerManager;
import android.util.Log;
import androidx.core.app.NotificationManagerCompat;
import com.example.zabi.PrayerWidgetProvider;
import java.util.HashMap;
import java.util.Map;
import org.json.JSONArray;
import org.json.JSONObject;

/** Adapter for flutter_local_notifications 17.2.4. Its cache remains the single
 * source of pending notifications; only SalaTime prayer PendingIntents are routed here. */
public final class SalaTimePrayerAlarms {
    static final String STORE = "scheduled_notifications";
    static final String DELIVERY_STORE = "salatime_alarm_delivery";
    static final long LATE_TOLERANCE_MS = 2 * 60 * 1000L;
    private SalaTimePrayerAlarms() {}

    static JSONArray cached(Context context) throws Exception {
        return new JSONArray(context.getSharedPreferences(STORE, 0).getString(STORE, "[]"));
    }

    static JSONObject prayer(JSONObject notification) {
        try {
            JSONObject payload = new JSONObject(notification.optString("payload", ""));
            int id = notification.getInt("id");
            int prayerId = payload.getInt("prayerId");
            String kind = payload.getString("kind");
            if (id < 10000000 || payload.getInt("id") != id || prayerId < 1 || prayerId > 5
                    || payload.getLong("at") <= 0
                    || !(kind.equals("adhan") || kind.equals("before") || kind.equals("after"))) return null;
            return payload;
        } catch (Exception ignored) { return null; }
    }

    static JSONObject find(Context context, int id) throws Exception {
        JSONArray rows = cached(context);
        for (int i = 0; i < rows.length(); i++) {
            JSONObject row = rows.getJSONObject(i);
            if (row.optInt("id", -1) == id) return row;
        }
        return null;
    }

    public static boolean exactAllowed(Context context) {
        AlarmManager manager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        return Build.VERSION.SDK_INT < 31 || manager.canScheduleExactAlarms();
    }

    static PendingIntent operation(Context context, int id, boolean create) {
        return PendingIntent.getBroadcast(context, id, new Intent(context, SalaTimePrayerAlarmReceiver.class),
                (create ? PendingIntent.FLAG_UPDATE_CURRENT : PendingIntent.FLAG_NO_CREATE)
                        | PendingIntent.FLAG_IMMUTABLE);
    }

    static void cancelLegacy(Context context, int id) {
        PendingIntent pending = PendingIntent.getBroadcast(context, id,
                new Intent(context, ScheduledNotificationReceiver.class),
                PendingIntent.FLAG_NO_CREATE | PendingIntent.FLAG_IMMUTABLE);
        if (pending != null) {
            ((AlarmManager) context.getSystemService(Context.ALARM_SERVICE)).cancel(pending);
            pending.cancel();
        }
    }

    public static void cancel(Context context, int id) {
        PendingIntent pending = operation(context, id, false);
        if (pending != null) {
            ((AlarmManager) context.getSystemService(Context.ALARM_SERVICE)).cancel(pending);
            pending.cancel();
        }
    }

    public static void cancelAll(Context context) throws Exception {
        JSONArray rows = cached(context);
        for (int i = 0; i < rows.length(); i++) {
            JSONObject row = rows.getJSONObject(i);
            if (prayer(row) != null) cancel(context, row.getInt("id"));
        }
    }

    static String register(Context context, JSONObject row, long now) throws Exception {
        JSONObject payload = prayer(row);
        if (payload == null || payload.getLong("at") <= now) return null;
        int id = row.getInt("id");
        Intent intent = new Intent(context, SalaTimePrayerAlarmReceiver.class)
                .putExtra("id", id).putExtra("at", payload.getLong("at"));
        PendingIntent pending = PendingIntent.getBroadcast(context, id, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        AlarmManager manager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        String mode;
        try {
            if (!exactAllowed(context)) throw new SecurityException("Exact alarms unavailable");
            if ("adhan".equals(payload.getString("kind"))) {
                // Unlike allowWhileIdle, a visible alarm clock is not batched with
                // nearby reminders in Doze. The clock shortcut must OPEN the app,
                // never send the broadcast (which would trigger a prayer early).
                manager.setAlarmClock(new AlarmManager.AlarmClockInfo(payload.getLong("at"),
                        PrayerWidgetProvider.openApp(context)), pending);
                mode = "alarmClock";
            } else {
                manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, payload.getLong("at"), pending);
                mode = "exactAllowWhileIdle";
            }
        } catch (SecurityException denied) {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, payload.getLong("at"), pending);
            mode = "inexactAllowWhileIdle";
        }
        // Leave the plugin's alarm intact if registration above fails.
        cancelLegacy(context, id);
        return mode;
    }

    public static Map<String, Object> route(Context context, int id) throws Exception {
        JSONObject row = find(context, id);
        String mode = row == null ? null : register(context, row, System.currentTimeMillis());
        Map<String, Object> result = new HashMap<>();
        result.put("routed", mode == null ? 0 : 1);
        result.put("failed", 0);
        result.put("inexact", "inexactAllowWhileIdle".equals(mode));
        return result;
    }

    public static Map<String, Object> routeAll(Context context) throws Exception {
        int routed = 0, failed = 0;
        boolean inexact = false;
        JSONArray rows = cached(context);
        long now = System.currentTimeMillis();
        for (int i = 0; i < rows.length(); i++) {
            try {
                String mode = register(context, rows.getJSONObject(i), now);
                if (mode != null) routed++;
                inexact |= "inexactAllowWhileIdle".equals(mode);
            } catch (Exception error) {
                failed++;
                Log.e("SalaTimeAlarms", "Could not route a prayer alarm", error);
            }
        }
        Map<String, Object> result = new HashMap<>();
        result.put("routed", routed);
        result.put("failed", failed);
        result.put("inexact", inexact);
        return result;
    }

    static String deliveryPolicy(JSONObject payload, long now) {
        long at = payload.optLong("at");
        if (now < at) return "early";
        String kind = payload.optString("kind");
        boolean late = now - at > LATE_TOLERANCE_MS;
        if ("before".equals(kind) && now >= payload.optLong("prayerAt", at)) return "expired";
        if (late) return "adhan".equals(kind) ? "late_silent" : "expired";
        return "on_time";
    }

    static void record(Context context, JSONObject payload, long now, String outcome) {
        if (!"adhan".equals(payload.optString("kind"))) return;
        context.getSharedPreferences(DELIVERY_STORE, 0).edit()
                .putLong("plannedAt", payload.optLong("at"))
                .putLong("deliveredAt", now)
                .putLong("delayMs", Math.max(0, now - payload.optLong("at")))
                .putString("outcome", outcome).apply();
    }

    public static Map<String, Object> status(Context context) {
        Map<String, Object> result = new HashMap<>();
        result.put("exact", exactAllowed(context));
        result.put("notifications", NotificationManagerCompat.from(context).areNotificationsEnabled());
        PowerManager power = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
        result.put("batteryExempt", power.isIgnoringBatteryOptimizations(context.getPackageName()));
        AudioManager audio = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        result.put("alarmVolume", audio.getStreamVolume(AudioManager.STREAM_ALARM));
        result.put("alarmVolumeMax", audio.getStreamMaxVolume(AudioManager.STREAM_ALARM));
        result.put("manufacturer", Build.MANUFACTURER);
        android.content.SharedPreferences delivery = context.getSharedPreferences(DELIVERY_STORE, 0);
        if (delivery.contains("plannedAt")) {
            result.put("plannedAt", delivery.getLong("plannedAt", 0));
            result.put("deliveredAt", delivery.getLong("deliveredAt", 0));
            result.put("delayMs", delivery.getLong("delayMs", 0));
            result.put("outcome", delivery.getString("outcome", ""));
        }
        return result;
    }
}
