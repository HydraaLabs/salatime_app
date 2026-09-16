package com.dexterous.flutterlocalnotifications;

import android.app.AlarmManager;
import android.app.Application;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Looper;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.json.JSONArray;
import org.json.JSONObject;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.Shadows;
import org.robolectric.annotation.Config;
import static org.junit.Assert.*;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 33, application = Application.class)
public class SalaTimePrayerScheduleBatchTest {
    private Context app;
    private long now;
    private static final int TEST_ID = 1999000001;

    @Before public void setup() {
        app = RuntimeEnvironment.getApplication();
        now = System.currentTimeMillis();
        app.getSharedPreferences(SalaTimePrayerAlarms.STORE, 0).edit().clear().commit();
        Shadows.shadowOf((AlarmManager) app.getSystemService(Context.ALARM_SERVICE)).setCanScheduleExactAlarms(true);
    }

    private Map<String, Object> arguments(int id, long at) throws Exception {
        Map<String, Object> style = new HashMap<>();
        style.put("htmlFormatTitle", false);
        style.put("htmlFormatContent", false);
        Map<String, Object> platform = new HashMap<>();
        platform.put("style", 0);
        platform.put("styleInformation", style);
        platform.put("channelId", "batch_prayer_no_badge_v1");
        platform.put("channelName", "Prayer");
        platform.put("channelAction", 0);
        platform.put("channelShowBadge", false);
        platform.put("importance", 4);
        platform.put("priority", 2);
        platform.put("playSound", false);
        platform.put("scheduleMode", "exactAllowWhileIdle");
        Map<String, Object> result = new HashMap<>();
        result.put("id", id);
        result.put("title", "Fajr");
        result.put("body", "Prayer");
        result.put("platformSpecifics", platform);
        result.put("scheduledDateTime", "2026-09-18T05:00:00");
        result.put("timeZoneName", "UTC");
        result.put("payload", new JSONObject().put("id", id).put("prayerId", 1)
                .put("kind", "adhan").put("at", at).put("prayerAt", at).toString());
        return result;
    }

    private JSONObject row(Map<String, Object> arguments) throws Exception {
        return new JSONObject(FlutterLocalNotificationsPlugin.buildGson()
                .toJson(NotificationDetails.from(arguments)));
    }

    private void save(JSONObject... rows) throws Exception {
        JSONArray data = new JSONArray();
        for (JSONObject row : rows) data.put(row);
        assertTrue(app.getSharedPreferences(SalaTimePrayerAlarms.STORE, 0).edit()
                .putString(SalaTimePrayerAlarms.STORE, data.toString()).commit());
    }

    @Test public void reserveIsCommittedOnceAndKeepsForeignNotificationsAndStandaloneTest() throws Exception {
        JSONObject foreign = new JSONObject().put("id", 77).put("payload", "another feature");
        JSONObject test = row(arguments(TEST_ID, now + 120000));
        JSONObject obsolete = row(arguments(12000009, now + 360000));
        save(foreign, test, obsolete);
        SharedPreferences cache = app.getSharedPreferences(SalaTimePrayerAlarms.STORE, 0);
        int[] writes = {0};
        SharedPreferences.OnSharedPreferenceChangeListener listener = (preferences, key) -> {
            if (SalaTimePrayerAlarms.STORE.equals(key)) writes[0]++;
        };
        cache.registerOnSharedPreferenceChangeListener(listener);
        try {
            List<Map<String, Object>> additions = new ArrayList<>();
            for (int i = 0; i < 450; i++) additions.add(arguments(12100000 + i, now + 600000L + i * 3600000L));
            Map<String, Object> result = SalaTimePrayerScheduleBatch.apply(app, additions, Collections.singletonList(12000009));
            Shadows.shadowOf(Looper.getMainLooper()).idle();
            assertEquals(0, result.get("failed"));
            assertEquals(1, writes[0]);
            assertEquals(452, SalaTimePrayerAlarms.cached(app).length());
            assertEquals(foreign.toString(), SalaTimePrayerAlarms.find(app, 77).toString());
            assertEquals(test.toString(), SalaTimePrayerAlarms.find(app, TEST_ID).toString());
            assertNull(SalaTimePrayerAlarms.find(app, 12000009));
            NotificationDetails restored = FlutterLocalNotificationsPlugin.buildGson().fromJson(
                    SalaTimePrayerAlarms.find(app, 12100000).toString(), NotificationDetails.class);
            assertEquals("UTC", restored.timeZoneName);
            assertFalse(restored.channelShowBadge);
            assertEquals(Integer.valueOf(2), restored.priority);
        } finally {
            cache.unregisterOnSharedPreferenceChangeListener(listener);
        }
    }

    @Test public void validationFailureLeavesCacheAndAlarmUnchanged() throws Exception {
        JSONObject existing = row(arguments(12000001, now + 600000));
        save(existing);
        SalaTimePrayerAlarms.route(app, 12000001);
        String before = SalaTimePrayerAlarms.cached(app).toString();
        Map<String, Object> invalid = arguments(12000002, now + 900000);
        invalid.put("payload", "invalid");
        try {
            SalaTimePrayerScheduleBatch.apply(app,
                    Arrays.asList(arguments(12000003, now + 1000000), invalid),
                    Collections.singletonList(12000001));
            fail("Invalid replacement must abort the transaction");
        } catch (IllegalArgumentException expected) { }
        assertEquals(before, SalaTimePrayerAlarms.cached(app).toString());
        assertNotNull(SalaTimePrayerAlarms.operation(app, 12000001, false));
    }

    @Test public void duplicateAndForeignEntriesCannotOverwriteOtherFeatures() throws Exception {
        JSONObject foreign = new JSONObject().put("id", 12000001).put("payload", "foreign");
        save(foreign);
        try {
            SalaTimePrayerScheduleBatch.apply(app, Collections.singletonList(arguments(12000001, now + 600000)), Collections.emptyList());
            fail("A foreign row must be preserved even when its ID looks managed");
        } catch (IllegalArgumentException expected) { }
        Map<String, Object> replacement = arguments(12000002, now + 600000);
        try {
            SalaTimePrayerScheduleBatch.apply(app, Arrays.asList(replacement, replacement), Collections.emptyList());
            fail("Duplicate IDs must be rejected");
        } catch (IllegalArgumentException expected) { }
        assertEquals(1, SalaTimePrayerAlarms.cached(app).length());
        assertEquals(foreign.toString(), SalaTimePrayerAlarms.find(app, 12000001).toString());
    }

    @Test public void elapsedReplacementNeverResurrectsConsumedOccurrenceButKeepsQueuedDelivery() throws Exception {
        Map<String, Object> consumed = arguments(12000001, now - 1000);
        Map<String, Object> queued = arguments(12000002, now - 1000);
        JSONObject stillQueued = row(queued);
        save(stillQueued);
        SalaTimePrayerScheduleBatch.apply(app, Arrays.asList(consumed, queued), Collections.emptyList());
        assertNull(SalaTimePrayerAlarms.find(app, 12000001));
        assertEquals(stillQueued.toString(), SalaTimePrayerAlarms.find(app, 12000002).toString());
        SalaTimePrayerScheduleBatch.apply(app, Collections.singletonList(queued), Collections.singletonList(12000002));
        assertNull(SalaTimePrayerAlarms.find(app, 12000002));
    }

    @Test public void standaloneTestCanBeExplicitlyReplacedAndCancelled() throws Exception {
        SalaTimePrayerScheduleBatch.apply(app, Collections.singletonList(arguments(TEST_ID, now + 60000)), Collections.emptyList());
        assertNotNull(SalaTimePrayerAlarms.find(app, TEST_ID));
        SalaTimePrayerScheduleBatch.apply(app, Collections.emptyList(), Collections.singletonList(TEST_ID));
        assertNull(SalaTimePrayerAlarms.find(app, TEST_ID));
        assertNull(SalaTimePrayerAlarms.operation(app, TEST_ID, false));
    }

    @Test public void elapsedChangedTimeCancelsObsoleteFutureAlarmWithoutResurrectingReplacement() throws Exception {
        int id = 12000001;
        save(row(arguments(id, now + 600000)));
        SalaTimePrayerAlarms.route(app, id);
        assertNotNull(SalaTimePrayerAlarms.operation(app, id, false));

        // Dart removed the staged cancellation when it queued this replacement.
        // Its earlier time then elapsed before the native transaction committed.
        SalaTimePrayerScheduleBatch.apply(app,
                Collections.singletonList(arguments(id, now - 1000)), Collections.emptyList());

        assertNull(SalaTimePrayerAlarms.find(app, id));
        assertNull(SalaTimePrayerAlarms.operation(app, id, false));
    }

    @Test public void elapsedReplacementCannotCancelForeignCacheEntry() throws Exception {
        int id = 12000001;
        JSONObject foreign = new JSONObject().put("id", id).put("payload", "foreign");
        save(foreign);
        try {
            SalaTimePrayerScheduleBatch.apply(app,
                    Collections.singletonList(arguments(id, now - 1000)), Collections.emptyList());
            fail("Elapsed replacements must also preserve foreign ownership");
        } catch (IllegalArgumentException expected) { }
        assertEquals(foreign.toString(), SalaTimePrayerAlarms.find(app, id).toString());
    }
}
