package com.dexterous.flutterlocalnotifications;

import android.app.Notification;
import android.content.Context;
import android.graphics.Bitmap;
import android.os.SystemClock;
import android.text.TextUtils;
import android.view.View;
import android.widget.RemoteViews;
import androidx.core.app.NotificationCompat;
import com.example.zabi.R;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import java.util.Locale;
import org.json.JSONObject;

/** SystemUI owns the elapsed timer, including after the audio service exits. */
final class SalaTimeAdhanNotification {
    static final long HOUR = 60 * 60 * 1000L;
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
        if (now < at + HOUR) return Math.min(at + HOUR, nextAt);
        return now < nextAt - HOUR ? nextAt - HOUR : nextAt;
    }

    static NotificationCompat.Builder builder(Context context, NotificationDetails details) {
        return decorate(context, details, FlutterLocalNotificationsPlugin.createNotification(context, details));
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
        boolean countdown = next != null && now >= at + HOUR && now < prayerAt(next);
        JSONObject shown = countdown ? next : payload;
        long target = prayerAt(shown);
        boolean urgent = countdown && target - now <= HOUR;

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
