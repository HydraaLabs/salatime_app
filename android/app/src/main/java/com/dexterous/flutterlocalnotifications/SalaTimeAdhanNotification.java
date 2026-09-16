package com.dexterous.flutterlocalnotifications;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.os.Build;
import android.os.SystemClock;
import android.text.TextUtils;
import android.view.View;
import android.widget.RemoteViews;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import com.example.zabi.R;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import java.util.Locale;
import org.json.JSONObject;

/** SystemUI owns the elapsed timer, including after the audio service exits. */
final class SalaTimeAdhanNotification {
    static final long HOUR = 60 * 60 * 1000L;
    static final long WARNING_WINDOW = 45 * 60 * 1000L;
    static final String TRACKING_CHANNEL = "prayer_tracking_no_badge_v1";
    private SalaTimeAdhanNotification() {}

    static long prayerAt(JSONObject payload) {
        return payload.optLong("prayerAt", payload.optLong("at", 0));
    }

    static JSONObject nextPrayer(JSONObject payload) {
        JSONObject next = payload.optJSONObject("nextPrayer");
        return next != null && prayerAt(next) > prayerAt(payload) ? next : null;
    }

    static long nextTransition(JSONObject payload, long now) {
        JSONObject next = nextPrayer(payload);
        if (next == null) return 0; // Compatible with alarms saved before this feature.
        long at = prayerAt(payload);
        long nextAt = prayerAt(next);
        if (now >= nextAt) return 0;
        long countdownAt = Math.min(at + HOUR, nextAt - HOUR);
        if (now < countdownAt) return countdownAt;
        long warningAt = nextAt - WARNING_WINDOW + 1;
        return now < warningAt ? warningAt : nextAt;
    }

    static NotificationCompat.Builder builder(Context context, NotificationDetails details) {
        return decorate(context, details, FlutterLocalNotificationsPlugin.createNotification(context, details));
    }

    /** Completed/muted adhans are status updates, not urgent alarms. */
    static Notification silentNotification(Context context, NotificationDetails details, long now) {
        Notification base = FlutterLocalNotificationsPlugin.createNotification(context, details);
        NotificationCompat.Builder builder = decorate(context, details, base, now).setSilent(true);
        JSONObject payload;
        try { payload = new JSONObject(details.payload); }
        catch (Exception ignored) { return builder.build(); }
        if (!"adhan".equals(payload.optString("kind"))) return builder.build();
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return null;
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
            NotificationChannel source = manager.getNotificationChannel(details.channelId);
            // Moving to the status channel must not bypass a disabled prayer channel.
            if (source != null && source.getImportance() == NotificationManager.IMPORTANCE_NONE) return null;
            if (Build.VERSION.SDK_INT >= 28 && source != null && source.getGroup() != null) {
                android.app.NotificationChannelGroup group = manager.getNotificationChannelGroup(source.getGroup());
                if (group != null && group.isBlocked()) return null;
            }
            NotificationChannel tracking = manager.getNotificationChannel(TRACKING_CHANNEL);
            if (tracking == null) {
                Configuration configuration = new Configuration(context.getResources().getConfiguration());
                String locale = payload.optString("locale", "");
                if (!locale.isEmpty()) configuration.setLocale(Locale.forLanguageTag(locale.replace('_', '-')));
                String name = context.createConfigurationContext(configuration)
                        .getString(R.string.prayer_notification_tracking);
                tracking = new NotificationChannel(TRACKING_CHANNEL, name, NotificationManager.IMPORTANCE_LOW);
                tracking.setSound(null, null);
                tracking.enableVibration(false);
                tracking.enableLights(false);
                tracking.setShowBadge(false);
                manager.createNotificationChannel(tracking);
            }
            if (tracking.getImportance() == NotificationManager.IMPORTANCE_NONE) return null;
            builder.setChannelId(TRACKING_CHANNEL);
        }
        return builder.setPriority(NotificationCompat.PRIORITY_LOW)
                .setCategory(NotificationCompat.CATEGORY_STATUS)
                .setOngoing(false).setAutoCancel(true).setOnlyAlertOnce(true)
                .setNumber(0).setBadgeIconType(NotificationCompat.BADGE_ICON_NONE).build();
    }

    static NotificationCompat.Builder decorate(Context context, NotificationDetails details, Notification base) {
        return decorate(context, details, base, System.currentTimeMillis());
    }

    static NotificationCompat.Builder decorate(Context context, NotificationDetails details, Notification base, long now) {
        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, base);
        JSONObject payload;
        try { payload = new JSONObject(details.payload); }
        catch (Exception ignored) { return builder; }
        long at = prayerAt(payload);
        if (!"adhan".equals(payload.optString("kind")) || at <= 0
                || payload.optBoolean("test", false) || at > now) return builder;

        JSONObject next = nextPrayer(payload);
        boolean countdown = next != null && now < prayerAt(next)
                && (now >= at + HOUR || prayerAt(next) - now <= HOUR);
        JSONObject shown = countdown ? next : payload;
        long target = prayerAt(shown);
        boolean urgent = countdown && target - now < WARNING_WINDOW;

        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.adhan_notification);
        String date = shown.optString("hijriDate", "");
        String prayer = shown.optString("prayerName", details.title == null ? "" : details.title);
        String time = shown.optString("prayerTime", "");
        views.setTextViewText(R.id.adhan_notification_date, date);
        views.setViewVisibility(R.id.adhan_notification_date, date.isEmpty() ? View.GONE : View.VISIBLE);
        views.setTextViewText(R.id.adhan_notification_prayer, time.isEmpty() ? prayer : prayer + " · " + time);
        String language = payload.optString("locale", "");
        if (!language.isEmpty()) {
            views.setInt(R.id.adhan_notification_root, "setLayoutDirection",
                    TextUtils.getLayoutDirectionFromLocale(Locale.forLanguageTag(language.replace('_', '-'))));
        }
        // Use the scheduled prayer instant, not the time audio finished or a
        // delayed alarm arrived. SystemUI ticks between the scheduled transitions.
        long baseTime = SystemClock.elapsedRealtime() + target - now;
        views.setChronometer(R.id.adhan_notification_elapsed, baseTime, null, true);
        views.setChronometerCountDown(R.id.adhan_notification_elapsed, countdown);
        views.setTextColor(R.id.adhan_notification_elapsed, context.getColor(
                urgent ? R.color.adhan_countdown_red : R.color.adhan_elapsed_green));
        // Chronometer supplies its own spoken duration; label the adjacent
        // prayer so screen readers also announce what that duration refers to.
        views.setContentDescription(R.id.adhan_notification_prayer,
                shown.optString(countdown ? "nextLabel" : "elapsedLabel", prayer)
                        + (time.isEmpty() ? "" : " · " + time));
        return builder.setStyle(new NotificationCompat.DecoratedCustomViewStyle())
                .setContentTitle(prayer)
                .setContentText(countdown ? shown.optString("nextLabel", prayer) + " · " + time : details.body)
                .setCustomContentView(views).setCustomBigContentView(views.clone())
                .setCustomHeadsUpContentView(views.clone())
                .setLargeIcon((Bitmap) null).setColorized(false)
                .setWhen(at).setShowWhen(true).setOnlyAlertOnce(true)
                .setNumber(0).setBadgeIconType(NotificationCompat.BADGE_ICON_NONE);
    }
}
