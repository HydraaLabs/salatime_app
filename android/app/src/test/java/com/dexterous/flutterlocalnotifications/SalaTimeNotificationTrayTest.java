package com.dexterous.flutterlocalnotifications;

import static org.junit.Assert.*;
import android.app.AlarmManager;
import android.app.Application;
import android.app.Notification;
import android.app.NotificationManager;
import android.content.Context;
import android.os.Build;
import androidx.core.app.NotificationCompat;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.dexterous.flutterlocalnotifications.models.NotificationStyle;
import com.dexterous.flutterlocalnotifications.models.styles.DefaultStyleInformation;
import org.json.JSONArray;
import org.json.JSONObject;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.Shadows;
import org.robolectric.annotation.Config;
import org.robolectric.annotation.LooperMode;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = {24, 33}, application = Application.class)
@LooperMode(LooperMode.Mode.PAUSED)
public class SalaTimeNotificationTrayTest {
    private final Application app = RuntimeEnvironment.getApplication();
    private final NotificationManager manager = (NotificationManager)app.getSystemService(Context.NOTIFICATION_SERVICE);
    private final AlarmManager alarms = (AlarmManager)app.getSystemService(Context.ALARM_SERVICE);

    private NotificationDetails details(int id, String kind) throws Exception {
        NotificationDetails d = new NotificationDetails();
        d.id = id;
        d.title = "Prayer " + id;
        d.body = "Reminder";
        d.icon = "@mipmap/launcher_icon";
        d.channelId = kind.equals("adhan") ? "adhan_test_no_badge" : kind + "_adhan_test_no_badge";
        d.channelName = "Test";
        d.importance = NotificationManager.IMPORTANCE_HIGH;
        d.priority = NotificationCompat.PRIORITY_HIGH;
        d.playSound = false;
        d.style = NotificationStyle.Default;
        d.styleInformation = new DefaultStyleInformation(false, false);
        d.channelShowBadge = false;
        d.autoCancel = true;
        long at = System.currentTimeMillis() - 1000;
        d.payload = new JSONObject().put("id", id).put("kind", kind).put("prayerId", 1)
                .put("at", at).put("prayerAt", kind.equals("before") ? at + 300000 : at).toString();
        return d;
    }

    private void reminder(NotificationDetails d) {
        SalaTimeNotificationTray.post(app, d, FlutterLocalNotificationsPlugin.createNotification(app, d));
    }

    @Test public void repeatedPrayersUseOneCardAndDoNotChangeTheirAlarmIds() throws Exception {
        for (int i = 0; i < 8; i++) {
            NotificationDetails d = details(12000001 + i, "adhan");
            SalaTimePrayerAlarmReceiver.showSilent(app, d);
            assertEquals(1, manager.getActiveNotifications().length);
            assertEquals(SalaTimeNotificationTray.PRAYER_ID, manager.getActiveNotifications()[0].getId());
            assertEquals("Prayer " + (12000001 + i), manager.getActiveNotifications()[0].getNotification().extras.getString(Notification.EXTRA_TITLE));
            assertEquals(12000001 + i, d.id.intValue());
        }
    }

    @Test public void remindersShareOneTemporaryCardAndOnlyPrayerRemainsAfterExpiry() throws Exception {
        SalaTimePrayerAlarmReceiver.showSilent(app, details(12000001, "adhan"));
        for (int i = 0; i < 12; i++) {
            NotificationDetails d = details(12000011 + i, i % 2 == 0 ? "before" : "after");
            reminder(d);
            assertEquals(2, manager.getActiveNotifications().length);
            Notification n = Shadows.shadowOf(manager).getNotification(SalaTimeNotificationTray.REMINDER_ID);
            assertEquals(d.title, n.extras.getString(Notification.EXTRA_TITLE));
            if (Build.VERSION.SDK_INT >= 26) assertTrue(n.getTimeoutAfter() <= 60000 && n.getTimeoutAfter() > 0);
        }
        SalaTimeNotificationTray.expire(app, System.currentTimeMillis() + 61000);
        assertEquals(1, manager.getActiveNotifications().length);
        assertEquals(SalaTimeNotificationTray.PRAYER_ID, manager.getActiveNotifications()[0].getId());
        assertTrue(Shadows.shadowOf(alarms).getScheduledAlarms().isEmpty());
    }

    @Test public void prayerArrivalRemovesTheBeforeReminderImmediately() throws Exception {
        reminder(details(12000011, "before"));
        SalaTimePrayerAlarmReceiver.showSilent(app, details(12000001, "adhan"));
        assertEquals(1, manager.getActiveNotifications().length);
        assertEquals(SalaTimeNotificationTray.PRAYER_ID, manager.getActiveNotifications()[0].getId());
        assertTrue(Shadows.shadowOf(alarms).getScheduledAlarms().isEmpty());
    }

    @Test public void staleExpiryDoesNotRemoveANewerReminder() throws Exception {
        long now = System.currentTimeMillis();
        NotificationDetails before = details(12000011, "before");
        before.payload = new JSONObject(before.payload).put("prayerAt", now + 10000).toString();
        reminder(before);
        assertEquals(now + 10000, Shadows.shadowOf(alarms).getScheduledAlarms().get(0).triggerAtTime);
        reminder(details(12000021, "after"));
        SalaTimeNotificationTray.expire(app, now + 11000);
        assertEquals(1, manager.getActiveNotifications().length);
        SalaTimeNotificationTray.expire(app, now + 61000);
        assertEquals(0, manager.getActiveNotifications().length);
    }

    @Test public void cleanupRemovesLegacyPileWithoutCancellingFutureAlarmsOrOtherFeatures() throws Exception {
        for (int id : new int[] {1, 1001, 2001, 12000001, 12000011, 12000021}) {
            NotificationDetails d = details(id, "adhan");
            manager.notify(id, FlutterLocalNotificationsPlugin.createNotification(app, d));
        }
        NotificationDetails other = details(8, "other");
        manager.notify(8, FlutterLocalNotificationsPlugin.createNotification(app, other));
        NotificationDetails future = details(12000101, "adhan");
        future.payload = new JSONObject(future.payload).put("at", System.currentTimeMillis() + 3600000).toString();
        JSONObject row = new JSONObject(FlutterLocalNotificationsPlugin.buildGson().toJson(future));
        String cache = new JSONArray().put(row).toString();
        app.getSharedPreferences(SalaTimePrayerAlarms.STORE, 0).edit().putString(SalaTimePrayerAlarms.STORE, cache).commit();
        SalaTimePrayerAlarms.register(app, row, System.currentTimeMillis());
        SalaTimePrayerAlarmReceiver.showSilent(app, details(12000002, "adhan"));
        assertEquals(2, manager.getActiveNotifications().length);
        assertNotNull(Shadows.shadowOf(manager).getNotification(8));
        assertNotNull(Shadows.shadowOf(manager).getNotification(SalaTimeNotificationTray.PRAYER_ID));
        assertEquals(cache, app.getSharedPreferences(SalaTimePrayerAlarms.STORE, 0).getString(SalaTimePrayerAlarms.STORE, ""));
        assertEquals(1, Shadows.shadowOf(alarms).getScheduledAlarms().size());
    }

    @Test public void savedLegacyCountdownIsMovedToTheSingleCardOnRestore() throws Exception {
        NotificationDetails d = details(12000001, "adhan");
        manager.notify(d.id, FlutterLocalNotificationsPlugin.createNotification(app, d));
        app.getSharedPreferences("salatime_adhan_notification", 0).edit().putString("notification",
                FlutterLocalNotificationsPlugin.buildGson().toJson(d)).commit();
        SalaTimeAdhanNotificationReceiver.restore(app);
        assertEquals(1, manager.getActiveNotifications().length);
        assertEquals(SalaTimeNotificationTray.PRAYER_ID, manager.getActiveNotifications()[0].getId());
        assertNotNull(manager.getActiveNotifications()[0].getNotification().contentView);
    }
}
