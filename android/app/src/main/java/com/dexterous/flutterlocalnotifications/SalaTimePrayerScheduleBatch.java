package com.dexterous.flutterlocalnotifications;

import android.content.Context;
import android.content.SharedPreferences;
import androidx.core.app.NotificationManagerCompat;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.dexterous.flutterlocalnotifications.models.SoundSource;
import java.util.HashMap;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.json.JSONArray;
import org.json.JSONObject;

/** Version-pinned adapter for flutter_local_notifications 17.2.4's cache.
 * Persists a calculated reserve once instead of scheduling and rewriting it per row. */
public final class SalaTimePrayerScheduleBatch {
    private static final int TEST_ID = 1999000001;
    private SalaTimePrayerScheduleBatch() {}

    private static boolean managedId(int id) {
        return (id >= 10000000 && id < 30000000) || id == TEST_ID;
    }

    public static Map<String, Object> apply(Context context,
            List<Map<String, Object>> notifications, List<Integer> cancelIds) throws Exception {
        synchronized (SalaTimePrayerAlarms.class) {
            Map<Integer, JSONObject> replacements = new LinkedHashMap<>();
            Set<Integer> cancellations = new LinkedHashSet<>();
            for (Integer id : cancelIds) {
                if (id == null || !managedId(id)) {
                    throw new IllegalArgumentException("Unmanaged prayer cancellation");
                }
                cancellations.add(id);
            }
            // Validate the complete request before touching the durable cache or alarms.
            for (Map<String, Object> arguments : notifications) {
                NotificationDetails details = NotificationDetails.from(arguments);
                JSONObject row = new JSONObject(FlutterLocalNotificationsPlugin.buildGson().toJson(details));
                if (details.id == null || !managedId(details.id)
                        || SalaTimePrayerAlarms.prayer(row) == null
                        || details.scheduledDateTime == null || details.timeZoneName == null) {
                    throw new IllegalArgumentException("Invalid prayer reserve entry");
                }
                if (details.sound != null && !details.sound.isEmpty()
                        && (details.soundSource == null || details.soundSource == SoundSource.RawResource)
                        && context.getResources().getIdentifier(details.sound, "raw", context.getPackageName()) == 0) {
                    throw new IllegalArgumentException("Missing prayer sound resource");
                }
                if (replacements.put(details.id, row) != null) {
                    throw new IllegalArgumentException("Duplicate prayer reserve entry");
                }
            }
            JSONArray current = SalaTimePrayerAlarms.cached(context);
            long now = System.currentTimeMillis();
            Map<Integer, Long> elapsedReplacements = new HashMap<>();
            for (Iterator<Map.Entry<Integer, JSONObject>> iterator = replacements.entrySet().iterator(); iterator.hasNext();) {
                Map.Entry<Integer, JSONObject> entry = iterator.next();
                JSONObject payload = SalaTimePrayerAlarms.prayer(entry.getValue());
                // Flutter may stage a row immediately before native delivery.
                // Do not resurrect one that was consumed before this commit;
                // only the SAME instant still cached belongs to a queued delivery.
                if (payload == null || payload.optLong("at") <= now) {
                    if (payload != null) elapsedReplacements.put(entry.getKey(), payload.optLong("at"));
                    iterator.remove();
                }
            }
            JSONArray merged = new JSONArray();
            for (int i = 0; i < current.length(); i++) {
                JSONObject row = current.getJSONObject(i);
                int id = row.optInt("id", -1);
                boolean owned = managedId(id) && SalaTimePrayerAlarms.prayer(row) != null;
                if (!owned && (replacements.containsKey(id) || elapsedReplacements.containsKey(id)
                        || cancellations.contains(id))) {
                    throw new IllegalArgumentException("Cannot replace another notification's cache entry");
                }
                if (owned && elapsedReplacements.containsKey(id)
                        && SalaTimePrayerAlarms.prayer(row).optLong("at") != elapsedReplacements.get(id)) {
                    // A changed time expired during staging. The old time was
                    // explicitly replaced and must not survive as a later alert.
                    cancellations.add(id);
                }
                if (!owned || (!replacements.containsKey(id) && !cancellations.contains(id))) {
                    merged.put(row);
                }
            }
            for (JSONObject row : replacements.values()) merged.put(row);
            SharedPreferences preferences = context.getSharedPreferences(SalaTimePrayerAlarms.STORE, 0);
            if (!preferences.edit().putString(SalaTimePrayerAlarms.STORE, merged.toString()).commit()) {
                throw new IllegalStateException("Unable to save prayer reserve");
            }
            int failed = 0;
            for (Integer id : cancellations) {
                if (replacements.containsKey(id)) continue;
                try {
                    SalaTimePrayerAlarms.cancel(context, id);
                    SalaTimePrayerAlarms.cancelLegacy(context, id);
                    NotificationManagerCompat.from(context).cancel(id);
                } catch (RuntimeException error) {
                    failed++;
                }
            }
            Map<String, Object> result = new HashMap<>(SalaTimePrayerAlarms.routeAll(context));
            result.put("failed", ((Number) result.getOrDefault("failed", 0)).intValue() + failed);
            return result;
        }
    }
}
