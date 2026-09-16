package com.dexterous.flutterlocalnotifications;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.media.AudioManager;
import android.os.Build;
import android.os.PowerManager;
import android.util.Log;
import androidx.core.app.NotificationManagerCompat;
import com.example.zabi.PrayerWidgetProvider;
import java.util.HashMap;
import java.util.Calendar;
import java.util.Map;
import java.util.TimeZone;
import org.json.JSONArray;
import org.json.JSONObject;

/** Adapter for flutter_local_notifications 17.2.4. Its cache remains the single
 * source of pending notifications; only SalaTime prayer PendingIntents are routed here. */
public final class SalaTimePrayerAlarms {
    static final String STORE = "scheduled_notifications";
    static final String DELIVERY_STORE = "salatime_alarm_delivery";
    static final String WINDOW_STORE = "salatime_alarm_window";
    static final int ARMED_WINDOW_DAYS = 3;
    static final long LATE_TOLERANCE_MS = 2 * 60 * 1000L;
    private SalaTimePrayerAlarms() {}

    static synchronized JSONArray cached(Context context) throws Exception {
        return new JSONArray(context.getSharedPreferences(STORE, 0).getString(STORE, "[]"));
    }

    static JSONObject prayer(JSONObject notification) {
        try {
            JSONObject payload = new JSONObject(notification.optString("payload", ""));
            int id = notification.getInt("id");
            String kind = payload.getString("kind");
            if ("extra_reminder".equals(kind)) {
                if (id < 20000000 || id >= 30000000 || payload.getInt("id") != id
                        || payload.getLong("at") <= 0
                        || !payload.optString("type").matches("duha|lastThird|friday|morning|evening|mondayThursday|whiteDays|fajrAlarm|bedtime|middleNight|monday|thursday")
                        || !payload.optString("date").matches("[0-9]{4}-[0-9]{2}-[0-9]{2}")) return null;
                java.text.SimpleDateFormat date = new java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.ROOT);
                date.setLenient(false);
                date.parse(payload.getString("date"));
                return payload;
            }
            int prayerId = payload.getInt("prayerId");
            if (id < 10000000 || payload.getInt("id") != id || prayerId < 1 || prayerId > 6
                    || (prayerId == 6 && !"sunrise".equals(payload.optString("prayer")))
                    || payload.getLong("at") <= 0
                    || !(kind.equals("adhan") || kind.equals("before") || kind.equals("after"))) return null;
            return payload;
        } catch (Exception ignored) { return null; }
    }

    static synchronized JSONObject find(Context context, int id) throws Exception {
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

    public static synchronized void cancel(Context context, int id) {
        PendingIntent pending = operation(context, id, false);
        if (pending != null) {
            ((AlarmManager) context.getSystemService(Context.ALARM_SERVICE)).cancel(pending);
            pending.cancel();
        }
    }

    public static synchronized void cancelAll(Context context) throws Exception {
        JSONArray rows = cached(context);
        for (int i = 0; i < rows.length(); i++) {
            JSONObject row = rows.getJSONObject(i);
            if (prayer(row) != null) cancel(context, row.getInt("id"));
        }
        cancelMaintenance(context);
        context.getSharedPreferences(WINDOW_STORE, 0).edit().clear().apply();
    }

    private static TimeZone validZone(String name) {
        if (name == null || name.isEmpty()) return null;
        TimeZone zone = TimeZone.getTimeZone(name);
        return !"GMT".equals(zone.getID()) || "GMT".equals(name) || "UTC".equals(name) ? zone : null;
    }

    static TimeZone windowZone(Context context, JSONObject row) {
        TimeZone configured = validZone(context.getSharedPreferences("salatime_prayer_widget", 0)
                .getString("timeZone", null));
        if (configured != null) return configured;
        TimeZone stored = row == null ? null : validZone(row.optString("timeZoneName"));
        return stored == null ? TimeZone.getDefault() : stored;
    }

    static long midnightAfter(long now, TimeZone zone, int days) {
        Calendar date = Calendar.getInstance(zone);
        date.setTimeInMillis(now);
        date.add(Calendar.DATE, days);
        date.set(Calendar.HOUR_OF_DAY, 0);
        date.set(Calendar.MINUTE, 0);
        date.set(Calendar.SECOND, 0);
        date.set(Calendar.MILLISECOND, 0);
        return date.getTimeInMillis();
    }

    static long windowEnd(Context context, JSONObject row, long now) {
        return midnightAfter(now, windowZone(context, row), ARMED_WINDOW_DAYS);
    }

    static synchronized String register(Context context, JSONObject row, long now) throws Exception {
        JSONObject payload = prayer(row);
        if (payload == null || payload.getLong("at") <= now) return null;
        int id = row.getInt("id");
        if (payload.getLong("at") >= windowEnd(context, row, now)) {
            // Keep the full occurrence in the plugin cache as an offline reserve.
            // Its temporary plugin registration must not escape the active window.
            cancel(context, id);
            cancelLegacy(context, id);
            return null;
        }
        Intent intent = new Intent(context, SalaTimePrayerAlarmReceiver.class)
                .addFlags(Intent.FLAG_RECEIVER_FOREGROUND)
                .putExtra("id", id).putExtra("at", payload.getLong("at"));
        PendingIntent pending = PendingIntent.getBroadcast(context, id, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        AlarmManager manager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        String mode;
        try {
            if (!exactAllowed(context)) throw new SecurityException("Exact alarms unavailable");
            // Every enabled prayer/reminder has a user-selected time, including
            // optional Fajr and night alerts. allowWhileIdle can throttle nearby
            // alerts in Doze beyond our missed-reminder tolerance. The system's
            // next alarm therefore shows the earliest enabled occurrence.
            // Its shortcut opens the app; it must never trigger the receiver.
            manager.setAlarmClock(new AlarmManager.AlarmClockInfo(payload.getLong("at"),
                    PrayerWidgetProvider.openApp(context)), pending);
            mode = "alarmClock";
        } catch (SecurityException denied) {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, payload.getLong("at"), pending);
            mode = "inexactAllowWhileIdle";
        }
        // Leave the plugin's alarm intact if registration above fails.
        cancelLegacy(context, id);
        return mode;
    }

    public static synchronized Map<String, Object> route(Context context, int id) throws Exception {
        JSONObject row = find(context, id);
        long now = System.currentTimeMillis();
        String mode = row == null ? null : register(context, row, now);
        if (row != null && prayer(row) != null) armMaintenance(context, cached(context), now);
        Map<String, Object> result = new HashMap<>();
        result.put("routed", mode == null ? 0 : 1);
        result.put("failed", 0);
        result.put("inexact", "inexactAllowWhileIdle".equals(mode));
        return result;
    }

    public static synchronized Map<String, Object> routeAll(Context context) throws Exception {
        SalaTimeAdhanNotificationReceiver.restore(context);
        return routeWindow(context, System.currentTimeMillis());
    }

    static synchronized Map<String, Object> routeWindow(Context context, long now) throws Exception {
        int routed = 0, failed = 0;
        boolean inexact = false;
        JSONArray rows = cached(context);
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
        TimeZone zone = reserveZone(context, rows);
        armMaintenance(context, rows, now);
        context.getSharedPreferences(WINDOW_STORE, 0).edit()
                .putLong("windowEnd", midnightAfter(now, zone, ARMED_WINDOW_DAYS))
                .putString("timeZone", zone.getID())
                .putBoolean("exact", exactAllowed(context))
                .putBoolean("failed", failed > 0)
                .putLong("lastRenewalAt", now).apply();
        Map<String, Object> result = new HashMap<>();
        result.put("routed", routed);
        result.put("failed", failed);
        result.put("inexact", inexact);
        return result;
    }

    private static TimeZone reserveZone(Context context, JSONArray rows) {
        for (int i = 0; i < rows.length(); i++) {
            JSONObject row = rows.optJSONObject(i);
            if (row != null && prayer(row) != null) return windowZone(context, row);
        }
        return windowZone(context, null);
    }

    private static PendingIntent maintenance(Context context, boolean create) {
        return PendingIntent.getBroadcast(context, 0, new Intent(context, SalaTimePrayerWindowReceiver.class),
                (create ? PendingIntent.FLAG_UPDATE_CURRENT : PendingIntent.FLAG_NO_CREATE)
                        | PendingIntent.FLAG_IMMUTABLE);
    }

    private static void cancelMaintenance(Context context) {
        PendingIntent pending = maintenance(context, false);
        if (pending != null) {
            ((AlarmManager) context.getSystemService(Context.ALARM_SERVICE)).cancel(pending);
            pending.cancel();
        }
        context.getSharedPreferences(WINDOW_STORE, 0).edit().remove("nextRenewalAt").apply();
    }

    private static void armMaintenance(Context context, JSONArray rows, long now) {
        boolean future = false;
        for (int i = 0; i < rows.length(); i++) {
            JSONObject row = rows.optJSONObject(i);
            JSONObject payload = row == null ? null : prayer(row);
            if (payload != null && payload.optLong("at") > now) { future = true; break; }
        }
        if (!future) { cancelMaintenance(context); return; }
        long at = midnightAfter(now, reserveZone(context, rows), 1);
        // One inexact maintenance alarm, with two already-armed days of margin.
        // Actual prayer deliveries can also advance the window after midnight.
        ((AlarmManager) context.getSystemService(Context.ALARM_SERVICE))
                .setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, maintenance(context, true));
        context.getSharedPreferences(WINDOW_STORE, 0).edit().putLong("nextRenewalAt", at).apply();
    }

    /** Recheck a completed batch after widget metadata has been updated. */
    public static synchronized Map<String, Object> refreshWindowIfNeeded(Context context) throws Exception {
        return refreshWindowIfNeeded(context, System.currentTimeMillis());
    }

    static synchronized Map<String, Object> refreshWindowIfNeeded(Context context, long now) throws Exception {
        SharedPreferences state = context.getSharedPreferences(WINDOW_STORE, 0);
        JSONObject zoneHint = new JSONObject().put("timeZoneName", state.getString("timeZone", ""));
        TimeZone zone = windowZone(context, zoneHint);
        if (state.getLong("windowEnd", 0) == midnightAfter(now, zone, ARMED_WINDOW_DAYS)
                && zone.getID().equals(state.getString("timeZone", ""))
                && state.getBoolean("exact", false) == exactAllowed(context)
                && !state.getBoolean("failed", false)) {
            Map<String, Object> result = new HashMap<>();
            result.put("routed", 0);
            result.put("failed", 0);
            result.put("inexact", false);
            return result;
        }
        // Do not prune at <= now: a simultaneous alarm may still be queued for
        // delivery. Only its receiver consumes it; strict pruning is for boot.
        return routeWindow(context, now);
    }

    static synchronized void renewIfNeeded(Context context, long now) throws Exception {
        refreshWindowIfNeeded(context, now);
    }

    static synchronized void maintainWindow(Context context, long now) throws Exception {
        renewIfNeeded(context, now);
        // Also recover an unexpectedly early maintenance delivery without
        // rebuilding all alarms when the local calendar day has not changed.
        armMaintenance(context, cached(context), now);
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

    public static synchronized Map<String, Object> status(Context context) {
        Map<String, Object> result = new HashMap<>();
        result.put("exact", exactAllowed(context));
        result.put("notifications", NotificationManagerCompat.from(context).areNotificationsEnabled());
        PowerManager power = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
        result.put("batteryExempt", power.isIgnoringBatteryOptimizations(context.getPackageName()));
        AudioManager audio = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        result.put("alarmVolume", audio.getStreamVolume(AudioManager.STREAM_ALARM));
        result.put("alarmVolumeMax", audio.getStreamMaxVolume(AudioManager.STREAM_ALARM));
        result.put("manufacturer", Build.MANUFACTURER);
        result.put("armedWindowDays", ARMED_WINDOW_DAYS);
        SharedPreferences window = context.getSharedPreferences(WINDOW_STORE, 0);
        result.put("lastWindowRenewalAt", window.getLong("lastRenewalAt", 0));
        result.put("nextWindowRenewalAt", window.getLong("nextRenewalAt", 0));
        try {
            JSONArray rows = cached(context);
            int reserveCount = 0, armedCount = 0;
            long lastAt = 0, now = System.currentTimeMillis();
            for (int i = 0; i < rows.length(); i++) {
                JSONObject row = rows.optJSONObject(i);
                JSONObject payload = row == null ? null : prayer(row);
                if (payload == null || payload.optLong("at") <= now) continue;
                reserveCount++;
                lastAt = Math.max(lastAt, payload.optLong("at"));
                if (payload.optLong("at") < windowEnd(context, row, now)
                        && operation(context, row.optInt("id"), false) != null) armedCount++;
            }
            result.put("reserveCount", reserveCount);
            result.put("reserveLastAt", lastAt);
            result.put("armedCount", armedCount);
        } catch (Exception error) {
            Log.w("SalaTimeAlarms", "Could not inspect the alarm reserve", error);
        }
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
