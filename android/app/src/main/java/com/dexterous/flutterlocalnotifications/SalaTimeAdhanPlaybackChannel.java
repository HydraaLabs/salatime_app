package com.dexterous.flutterlocalnotifications;

import android.app.NotificationChannel;
import android.app.NotificationChannelGroup;
import android.app.NotificationManager;
import android.content.Context;
import android.content.res.Configuration;
import android.os.Build;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.example.zabi.R;
import java.util.Locale;
import org.json.JSONObject;

/** A visible playback alert with audio owned exclusively by the stoppable player. */
final class SalaTimeAdhanPlaybackChannel {
    static final String ID = "prayer_playback_no_badge_v1";

    private SalaTimeAdhanPlaybackChannel() {}

    static NotificationChannel prepare(Context context, NotificationDetails details, JSONObject payload) {
        if (Build.VERSION.SDK_INT < 26) return null;
        NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        NotificationChannel source = manager.getNotificationChannel(details.channelId);
        // A user's lower source importance must not gain an intrusive alert by
        // moving to a different channel. Source sound/access are checked by caller.
        if (source == null || source.getImportance() < NotificationManager.IMPORTANCE_HIGH) return null;
        NotificationChannel playback = manager.getNotificationChannel(ID);
        if (playback == null) {
            Configuration configuration = new Configuration(context.getResources().getConfiguration());
            String locale = payload.optString("locale", "");
            if (!locale.isEmpty()) configuration.setLocale(Locale.forLanguageTag(locale.replace('_', '-')));
            String name = context.createConfigurationContext(configuration)
                    .getString(R.string.prayer_notification_playback);
            playback = new NotificationChannel(ID, name, NotificationManager.IMPORTANCE_HIGH);
            playback.setSound(null, null);
            playback.enableVibration(false);
            playback.enableLights(false);
            playback.setShowBadge(false);
            manager.createNotificationChannel(playback);
        }
        // Existing settings, including a disabled or lowered playback channel,
        // belong to the user. Never recreate it to regain importance or access.
        return playback;
    }

    static boolean isBlocked(Context context, String id) {
        if (Build.VERSION.SDK_INT < 26 || id == null) return false;
        NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        NotificationChannel channel = manager.getNotificationChannel(id);
        if (channel == null || channel.getImportance() == NotificationManager.IMPORTANCE_NONE) return true;
        if (Build.VERSION.SDK_INT >= 28 && channel.getGroup() != null) {
            NotificationChannelGroup group = manager.getNotificationChannelGroup(channel.getGroup());
            return group != null && group.isBlocked();
        }
        return false;
    }
}
