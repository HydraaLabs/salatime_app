package com.dexterous.flutterlocalnotifications;

import android.app.AlarmManager;
import android.app.Application;
import android.content.Context;
import org.json.JSONArray;
import org.json.JSONObject;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.Shadows;
import org.robolectric.annotation.Config;
import static org.junit.Assert.*;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 33, manifest = Config.NONE, application = Application.class)
public class SalaTimeAlarmRestoreReceiverTest {
    private JSONObject alarm(int id, long at, String kind) throws Exception {
        return new JSONObject().put("id", id).put("scheduleMode", "exactAllowWhileIdle")
            .put("payload", new JSONObject().put("id", id).put("at", at).put("prayerId", 1).put("kind", kind).toString());
    }
    @Test public void rebootDropsExpiredPrayersAndFallsBackWithoutExactPermission() throws Exception {
        Context app = RuntimeEnvironment.getApplication();
        Shadows.shadowOf((AlarmManager) app.getSystemService(Context.ALARM_SERVICE)).setCanScheduleExactAlarms(false);
        JSONArray rows = new JSONArray().put(alarm(12000001, 100, "adhan"))
            .put(alarm(12000011, 110, "before"))
            .put(alarm(12000101, 1000, "adhan"))
            .put(new JSONObject().put("id", 8).put("payload", "unrelated"));
        app.getSharedPreferences("scheduled_notifications", 0).edit().putString("scheduled_notifications", rows.toString()).commit();
        assertTrue(SalaTimeAlarmRestoreReceiver.repairCache(app, 500));
        JSONArray restored = new JSONArray(app.getSharedPreferences("scheduled_notifications", 0).getString("scheduled_notifications", "[]"));
        assertEquals(2, restored.length());
        assertEquals(12000101, restored.getJSONObject(0).getInt("id"));
        assertEquals("inexactAllowWhileIdle", restored.getJSONObject(0).getString("scheduleMode"));
        assertEquals(8, restored.getJSONObject(1).getInt("id"));
        assertFalse(SalaTimeAlarmRestoreReceiver.repairCache(app, 500));
    }
    @Test public void exactPermissionRestoredUpgradesOnlyOurFutureAlarms() throws Exception {
        Context app = RuntimeEnvironment.getApplication();
        Shadows.shadowOf((AlarmManager) app.getSystemService(Context.ALARM_SERVICE)).setCanScheduleExactAlarms(true);
        JSONObject future = alarm(12000101, 1000, "adhan").put("scheduleMode", "inexactAllowWhileIdle");
        app.getSharedPreferences("scheduled_notifications", 0).edit().putString("scheduled_notifications", new JSONArray().put(future).toString()).commit();
        assertFalse(SalaTimeAlarmRestoreReceiver.repairCache(app, 500));
        JSONObject restored = new JSONArray(app.getSharedPreferences("scheduled_notifications", 0).getString("scheduled_notifications", "[]")).getJSONObject(0);
        assertEquals("exactAllowWhileIdle", restored.getString("scheduleMode"));
    }
    private JSONObject extra(int id, long at) throws Exception {
        return new JSONObject().put("id", id).put("scheduleMode", "exactAllowWhileIdle")
            .put("payload", new JSONObject().put("id", id).put("at", at)
                .put("kind", "extra_reminder").put("type", "morning").put("date", "2026-09-12").toString());
    }
    @Test public void expiredExtraRemindersAreDroppedBeforePluginRescheduling() throws Exception {
        Context app = RuntimeEnvironment.getApplication();
        JSONObject expired = extra(22000001, 100);
        JSONObject upcoming = extra(22000002, 1000);
        JSONObject unrelated = new JSONObject().put("id", 8).put("payload", "unrelated");
        app.getSharedPreferences("scheduled_notifications", 0).edit().putString("scheduled_notifications",
            new JSONArray().put(expired).put(upcoming).put(unrelated).toString()).commit();
        // Missed extra reminders do not create a misleading "missed prayer" notification.
        assertFalse(SalaTimeAlarmRestoreReceiver.repairCache(app, 500));
        JSONArray restored = new JSONArray(app.getSharedPreferences("scheduled_notifications", 0)
            .getString("scheduled_notifications", "[]"));
        assertEquals(2, restored.length());
        assertEquals(22000002, restored.getJSONObject(0).getInt("id"));
        assertEquals(8, restored.getJSONObject(1).getInt("id"));
    }
    @Test public void newlySupportedExtrasRestoreAndExpireLikeExistingReminders() throws Exception {
        Context app = RuntimeEnvironment.getApplication();
        org.robolectric.shadows.ShadowAlarmManager.setCanScheduleExactAlarms(false);
        JSONArray rows = new JSONArray();
        String[] types = {"fajrAlarm", "bedtime", "middleNight", "monday", "thursday"};
        for (int i = 0; i < types.length; i++) {
            for (boolean expired : new boolean[] {true, false}) {
                int id = 21207100 + i * 10 + (expired ? 0 : 1);
                JSONObject row = extra(id, expired ? 100 : 1000);
                JSONObject payload = new JSONObject(row.getString("payload"));
                payload.put("type", types[i]);
                rows.put(row.put("payload", payload.toString()));
            }
        }
        app.getSharedPreferences("scheduled_notifications", 0).edit()
            .putString("scheduled_notifications", rows.toString()).commit();
        assertFalse(SalaTimeAlarmRestoreReceiver.repairCache(app, 500));
        JSONArray restored = new JSONArray(app.getSharedPreferences("scheduled_notifications", 0)
            .getString("scheduled_notifications", "[]"));
        assertEquals(types.length, restored.length());
        for (int i = 0; i < restored.length(); i++) {
            assertEquals("inexactAllowWhileIdle", restored.getJSONObject(i).getString("scheduleMode"));
            assertEquals(types[i], new JSONObject(restored.getJSONObject(i).getString("payload")).getString("type"));
        }
    }

    @Test public void futureExtraRemindersFollowExactPermissionChanges() throws Exception {
        Context app = RuntimeEnvironment.getApplication();
        org.robolectric.shadows.ShadowAlarmManager.setCanScheduleExactAlarms(false);
        app.getSharedPreferences("scheduled_notifications", 0).edit().putString("scheduled_notifications",
            new JSONArray().put(extra(22000002, 1000)).toString()).commit();
        SalaTimeAlarmRestoreReceiver.repairCache(app, 500);
        JSONObject restored = new JSONArray(app.getSharedPreferences("scheduled_notifications", 0)
            .getString("scheduled_notifications", "[]")).getJSONObject(0);
        assertEquals("inexactAllowWhileIdle", restored.getString("scheduleMode"));
        org.robolectric.shadows.ShadowAlarmManager.setCanScheduleExactAlarms(true);
        SalaTimeAlarmRestoreReceiver.repairCache(app, 500);
        restored = new JSONArray(app.getSharedPreferences("scheduled_notifications", 0)
            .getString("scheduled_notifications", "[]")).getJSONObject(0);
        assertEquals("exactAllowWhileIdle", restored.getString("scheduleMode"));
    }

}
