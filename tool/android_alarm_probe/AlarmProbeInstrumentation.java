package net.salatime.alarmprobe;

import android.app.Activity;
import android.app.Instrumentation;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.SharedPreferences;
import android.media.AudioAttributes;
import android.media.AudioManager;
import android.net.Uri;
import android.os.Bundle;
import android.os.PowerManager;
import android.service.notification.StatusBarNotification;
import java.lang.reflect.Method;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.Map;
import java.util.TimeZone;
import org.json.JSONArray;
import org.json.JSONObject;

/** Standalone debug-only probe. Never packaged in the SalaTime application. */
public final class AlarmProbeInstrumentation extends Instrumentation {
    private static final String TARGET = "net.salatime.app.preview";
    private static final String PREFIX = "com.dexterous.flutterlocalnotifications.";
    private static final String STORE = "scheduled_notifications";
    private static final String SNAPSHOT = "salatime_alarm_probe";
    private static final String DELIVERY = "salatime_alarm_delivery";
    private static final String PLAYBACK_CHANNEL = "prayer_playback_no_badge_v1";
    private static final String TITLE = "SalaTime — test technique";
    private static final int ID = 1999000001;
    private Bundle arguments;

    private static final class ProbeFailure extends IllegalStateException {
        ProbeFailure(String message) { super(message); }
    }

    @Override public void onCreate(Bundle args) {
        super.onCreate(args);
        arguments = args == null ? new Bundle() : args;
        start();
    }

    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            Context context = getTargetContext();
            if (!TARGET.equals(context.getPackageName())) throw new ProbeFailure("Preview only");
            String mode = arguments.getString("mode", "status");
            JSONObject output;
            if ("schedule".equals(mode)) output = schedule(context);
            else if ("cleanup".equals(mode)) output = cleanup(context);
            else if ("status".equals(mode)) output = status(context);
            else if ("renew".equals(mode)) {
                call(context, "SalaTimePrayerAlarms", "maintainWindow",
                        new Class<?>[]{Context.class, long.class}, context, System.currentTimeMillis());
                output = status(context).put("maintenance", "called_with_actual_time");
            }
            else throw new ProbeFailure("Unknown probe mode");
            result.putString("probe", output.toString());
            finish(Activity.RESULT_OK, result);
        } catch (Throwable error) {
            // Do not emit application payloads or arbitrary preference contents.
            Throwable cause = error.getCause() == null ? error : error.getCause();
            result.putString("probe_error", cause.getClass().getSimpleName());
            if (cause instanceof ProbeFailure) result.putString("probe_reason", cause.getMessage());
            result.putString("probe_action", "Inspect probe state, then run cleanup if scheduled");
            finish(Activity.RESULT_CANCELED, result);
        }
    }

    private Object call(Context context, String name, String method, Class<?>[] types, Object... args)
            throws Exception {
        Class<?> owner = context.getClassLoader().loadClass(PREFIX + name);
        Method target = owner.getDeclaredMethod(method, types);
        target.setAccessible(true);
        return target.invoke(null, args);
    }

    private NotificationManager notifications(Context context) {
        return (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
    }

    private JSONObject schedule(Context context) throws Exception {
        int delay = Integer.parseInt(arguments.getString("delay", "60"));
        if (delay < 30 || delay > 120) throw new ProbeFailure("Delay must be 30..120 seconds");
        String sound = arguments.getString("sound", "noti_beep_beep");
        if (!sound.matches("noti_1|noti_beep|noti_beep_beep")) {
            throw new ProbeFailure("Only existing bounded test sounds are allowed");
        }
        if (context.getResources().getIdentifier(sound, "raw", TARGET) == 0) {
            throw new ProbeFailure("Test sound absent from this build");
        }
        SharedPreferences snapshot = context.getSharedPreferences(SNAPSHOT, 0);
        if (snapshot.contains("at")) throw new ProbeFailure("Clean previous probe first");
        for (StatusBarNotification active : notifications(context).getActiveNotifications()) {
            if (active.getId() == 9902
                    || (active.getNotification().flags & Notification.FLAG_FOREGROUND_SERVICE) != 0) {
                throw new ProbeFailure("Existing reminder or foreground notification");
            }
        }
        long now = System.currentTimeMillis();
        long at = now + delay * 1000L;
        JSONArray rows = new JSONArray(context.getSharedPreferences(STORE, 0).getString(STORE, "[]"));
        JSONObject template = null;
        for (int i = 0; i < rows.length(); i++) {
            JSONObject row = rows.getJSONObject(i);
            if (row.optInt("id") == ID) throw new ProbeFailure("Test ID already exists");
            JSONObject payload;
            try { payload = new JSONObject(row.optString("payload", "{}")); }
            catch (Exception ignored) { continue; }
            long scheduledAt = payload.optLong("at");
            if (scheduledAt > now && scheduledAt <= at + 120000L) {
                throw new ProbeFailure("A real alarm is too close to the probe");
            }
            if (template == null && "adhan".equals(payload.optString("kind"))) {
                template = new JSONObject(row.toString());
            }
        }
        if (template == null) throw new ProbeFailure("No current adhan row to preserve model compatibility");
        String channel = "adhan_probe_" + at + "_no_badge_v1";
        JSONObject oldDelivery = new JSONObject(context.getSharedPreferences(DELIVERY, 0).getAll());
        if (!snapshot.edit().putLong("at", at).putString("channel", channel)
                .putString("delivery", oldDelivery.toString()).commit()) {
            throw new ProbeFailure("Could not save private probe snapshot");
        }
        NotificationChannel config = new NotificationChannel(channel, "SalaTime test technique",
                NotificationManager.IMPORTANCE_HIGH);
        config.setShowBadge(false);
        config.enableVibration(false);
        config.setSound(Uri.parse("android.resource://" + TARGET + "/raw/" + sound),
                new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build());
        notifications(context).createNotificationChannel(config);
        JSONObject payload = new JSONObject().put("id", ID).put("prayerId", 1)
                .put("at", at).put("prayerAt", at).put("kind", "adhan")
                .put("test", true).put("locale", "fr").put("stopLabel", "Arrêter le test");
        SimpleDateFormat utc = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.ROOT);
        utc.setTimeZone(TimeZone.getTimeZone("UTC"));
        template.put("id", ID).put("title", TITLE).put("body", "Vérification de l'alarme native")
                .put("payload", payload.toString()).put("sound", sound).put("soundSource", "RawResource")
                .put("channelId", channel).put("channelName", "SalaTime test technique")
                .put("importance", 4).put("priority", 2).put("channelShowBadge", false)
                .put("audioAttributesUsage", 4).put("playSound", true).put("enableVibration", false)
                .put("when", at).put("showWhen", true).put("millisecondsSinceEpoch", at)
                .put("scheduledDateTime", utc.format(new Date(at))).put("timeZoneName", "UTC")
                .put("scheduleMode", "exactAllowWhileIdle").put("fullScreenIntent", false);
        for (String key : new String[]{"scheduledNotificationRepeatFrequency", "matchDateTimeComponents",
                "repeatInterval", "repeatIntervalMilliseconds", "tag", "actions"}) template.remove(key);
        Class<?> model = context.getClassLoader().loadClass(PREFIX + "models.NotificationDetails");
        Object gson = call(context, "FlutterLocalNotificationsPlugin", "buildGson", new Class<?>[0]);
        Object details = gson.getClass().getMethod("fromJson", String.class, Class.class)
                .invoke(gson, template.toString(), model);
        call(context, "FlutterLocalNotificationsPlugin", "saveScheduledNotification",
                new Class<?>[]{Context.class, model}, context, details);
        SharedPreferences cache = context.getSharedPreferences(STORE, 0);
        if (!cache.edit().putString(STORE, cache.getString(STORE, "[]")).commit()) {
            throw new ProbeFailure("Could not flush cached test notification");
        }
        Object routed = call(context, "SalaTimePrayerAlarms", "route",
                new Class<?>[]{Context.class, int.class}, context, ID);
        return status(context).put("scheduledAt", at).put("delaySeconds", delay)
                .put("sound", sound).put("route", new JSONObject((Map<?, ?>) routed));
    }

    private JSONObject status(Context context) throws Exception {
        Map<?, ?> health = (Map<?, ?>) call(context, "SalaTimePrayerAlarms", "status",
                new Class<?>[]{Context.class}, context);
        JSONObject output = new JSONObject(health);
        SharedPreferences snapshot = context.getSharedPreferences(SNAPSHOT, 0);
        output.put("probeAt", snapshot.getLong("at", 0));
        output.put("processId", android.os.Process.myPid());
        output.put("screenInteractive", ((PowerManager) context.getSystemService(Context.POWER_SERVICE)).isInteractive());
        output.put("ringerMode", ((AudioManager) context.getSystemService(Context.AUDIO_SERVICE)).getRingerMode());
        NotificationChannel source = notifications(context).getNotificationChannel(snapshot.getString("channel", ""));
        NotificationChannel playback = notifications(context).getNotificationChannel(PLAYBACK_CHANNEL);
        output.put("probeChannelImportance", source == null ? JSONObject.NULL : source.getImportance());
        output.put("playbackChannelImportance", playback == null ? JSONObject.NULL : playback.getImportance());
        output.put("playbackChannelSound", playback != null && playback.getSound() != null);
        return output;
    }

    private JSONObject cleanup(Context context) throws Exception {
        SharedPreferences snapshot = context.getSharedPreferences(SNAPSHOT, 0);
        long at = snapshot.getLong("at", 0);
        if (at == 0) return new JSONObject().put("cleanup", "no_probe_snapshot");
        call(context, "SalaTimePrayerAlarms", "cancel", new Class<?>[]{Context.class, int.class}, context, ID);
        call(context, "SalaTimePrayerAlarms", "cancelLegacy", new Class<?>[]{Context.class, int.class}, context, ID);
        call(context, "FlutterLocalNotificationsPlugin", "removeNotificationFromCache",
                new Class<?>[]{Context.class, Integer.class}, context, Integer.valueOf(ID));
        SharedPreferences cache = context.getSharedPreferences(STORE, 0);
        if (!cache.edit().putString(STORE, cache.getString(STORE, "[]")).commit()) {
            throw new ProbeFailure("Could not flush test notification removal");
        }
        for (StatusBarNotification active : notifications(context).getActiveNotifications()) {
            CharSequence title = active.getNotification().extras.getCharSequence(Notification.EXTRA_TITLE);
            if (active.getId() == 9902 && TITLE.contentEquals(title == null ? "" : title)) {
                call(context, "SalaTimeNotificationTray", "clearReminder", new Class<?>[]{Context.class}, context);
            }
        }
        SharedPreferences delivery = context.getSharedPreferences(DELIVERY, 0);
        boolean restore = delivery.getLong("plannedAt", 0) == at;
        if (restore) {
            JSONObject old = new JSONObject(snapshot.getString("delivery", "{}"));
            SharedPreferences.Editor edit = delivery.edit().clear();
            java.util.Iterator<String> keys = old.keys();
            while (keys.hasNext()) {
                String key = keys.next(); Object value = old.get(key);
                if (value instanceof Number) edit.putLong(key, ((Number) value).longValue());
                else if (value instanceof Boolean) edit.putBoolean(key, (Boolean) value);
                else if (value instanceof String) edit.putString(key, (String) value);
            }
            if (!edit.commit()) throw new ProbeFailure("Could not restore delivery metrics");
        }
        notifications(context).deleteNotificationChannel(snapshot.getString("channel", ""));
        if (!context.deleteSharedPreferences(SNAPSHOT)) throw new ProbeFailure("Could not remove probe snapshot");
        return new JSONObject().put("cleanup", "done").put("deliveryMetricsRestored", restore);
    }
}
