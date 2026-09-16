package com.dexterous.flutterlocalnotifications;

import static org.junit.Assert.*;

import android.app.AlarmManager;
import android.app.Application;
import android.app.PendingIntent;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import androidx.core.app.NotificationCompat;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.dexterous.flutterlocalnotifications.models.NotificationStyle;
import com.dexterous.flutterlocalnotifications.models.ScheduleMode;
import com.dexterous.flutterlocalnotifications.models.styles.DefaultStyleInformation;
import java.text.SimpleDateFormat;
import java.time.Instant;
import java.util.Date;
import java.util.ArrayList;
import java.util.Locale;
import java.util.Map;
import java.util.TimeZone;
import org.json.JSONArray;
import org.json.JSONObject;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.Shadows;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = {24, 33}, application = Application.class)
public class SalaTimePrayerWindowTest {
    private Context app;
    private AlarmManager alarms;

    @Before public void setup() {
        app = RuntimeEnvironment.getApplication();
        alarms = (AlarmManager) app.getSystemService(Context.ALARM_SERVICE);
        Shadows.shadowOf(alarms).setCanScheduleExactAlarms(true);
        app.getSharedPreferences("salatime_prayer_widget", 0).edit().putString("timeZone", "UTC").commit();
    }

    private JSONObject row(int id, long at) throws Exception {
        SimpleDateFormat date = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.ROOT);
        date.setTimeZone(TimeZone.getTimeZone("UTC"));
        NotificationDetails details = new NotificationDetails();
        details.id = id;
        details.title = "Fajr";
        details.body = "Prayer";
        details.icon = "@mipmap/launcher_icon";
        details.channelId = "adhan_window_test_no_badge";
        details.channelName = "Adhan";
        details.importance = NotificationManager.IMPORTANCE_HIGH;
        details.priority = NotificationCompat.PRIORITY_MAX;
        details.playSound = false;
        details.style = NotificationStyle.Default;
        details.styleInformation = new DefaultStyleInformation(false, false);
        details.scheduleMode = ScheduleMode.exactAllowWhileIdle;
        details.scheduledDateTime = date.format(new Date(at));
        details.timeZoneName = "UTC";
        details.payload = new JSONObject().put("id", id).put("at", at)
                .put("prayerAt", at).put("prayerId", 1).put("kind", "adhan").toString();
        return new JSONObject(FlutterLocalNotificationsPlugin.buildGson().toJson(details));
    }

    private void save(JSONObject... rows) {
        JSONArray values = new JSONArray();
        for (JSONObject row : rows) values.put(row);
        app.getSharedPreferences(SalaTimePrayerAlarms.STORE, 0).edit()
                .putString(SalaTimePrayerAlarms.STORE, values.toString()).commit();
    }

    private long count(Class<?> receiver) {
        return Shadows.shadowOf(alarms).getScheduledAlarms().stream().filter(alarm ->
                receiver.getName().equals(Shadows.shadowOf(alarm.operation).getSavedIntent()
                        .getComponent().getClassName())).count();
    }

    @Test public void onlyThreeCalendarDaysAreArmedAndReserveIsUnchanged() throws Exception {
        long now = System.currentTimeMillis();
        long end = SalaTimePrayerAlarms.windowEnd(app, null, now);
        save(row(12000001, now + 60000), row(12000002, end - 1000),
                row(12000003, end), row(12000004, end + 20 * 86400000L));
        String before = SalaTimePrayerAlarms.cached(app).toString();
        assertEquals(2, SalaTimePrayerAlarms.routeWindow(app, now).get("routed"));
        assertEquals(2, count(SalaTimePrayerAlarmReceiver.class));
        assertEquals(1, count(SalaTimePrayerWindowReceiver.class));
        assertEquals(before, SalaTimePrayerAlarms.cached(app).toString());
        assertNull(SalaTimePrayerAlarms.operation(app, 12000003, false));
        assertEquals(3, SalaTimePrayerAlarms.status(app).get("armedWindowDays"));
        assertEquals(4, SalaTimePrayerAlarms.status(app).get("reserveCount"));
        assertEquals(2, SalaTimePrayerAlarms.status(app).get("armedCount"));
    }

    @Test public void calendarWindowRespectsDstRatherThanFixedSeventyTwoHours() {
        app.getSharedPreferences("salatime_prayer_widget", 0).edit().putString("timeZone", "Europe/Paris").commit();
        long spring = Instant.parse("2026-03-27T23:00:00Z").toEpochMilli();
        long autumn = Instant.parse("2026-10-23T22:00:00Z").toEpochMilli();
        assertEquals(71 * 3600000L, SalaTimePrayerAlarms.windowEnd(app, null, spring) - spring);
        assertEquals(73 * 3600000L, SalaTimePrayerAlarms.windowEnd(app, null, autumn) - autumn);
    }

    @Test public void invalidConfiguredZoneUsesSavedOccurrenceZone() throws Exception {
        app.getSharedPreferences("salatime_prayer_widget", 0).edit().putString("timeZone", "invalid/zone").commit();
        JSONObject row = row(12000001, 1).put("timeZoneName", "Asia/Tokyo");
        assertEquals("Asia/Tokyo", SalaTimePrayerAlarms.windowZone(app, row).getID());
        app.getSharedPreferences("salatime_prayer_widget", 0).edit().putString("timeZone", "Africa/Casablanca").commit();
        assertEquals("Africa/Casablanca", SalaTimePrayerAlarms.windowZone(app, row).getID());
    }

    @Test public void distantRouteCancelsBothRegistrationsButKeepsItsReserve() throws Exception {
        long at = SalaTimePrayerAlarms.windowEnd(app, null, System.currentTimeMillis()) + 60000;
        JSONObject row = row(12000001, at);
        save(row);
        PendingIntent legacy = PendingIntent.getBroadcast(app, 12000001,
                new Intent(app, ScheduledNotificationReceiver.class), PendingIntent.FLAG_IMMUTABLE);
        alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, legacy);
        alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at,
                SalaTimePrayerAlarms.operation(app, 12000001, true));
        assertEquals(0, SalaTimePrayerAlarms.route(app, 12000001).get("routed"));
        assertEquals(0, count(SalaTimePrayerAlarmReceiver.class));
        assertEquals(0, count(ScheduledNotificationReceiver.class));
        assertEquals(row.toString(), SalaTimePrayerAlarms.find(app, 12000001).toString());
        assertEquals(1, count(SalaTimePrayerWindowReceiver.class));
    }

    @Test public void nextDayMaintenanceArmsNewDayWithoutFlutterAndStaysUnique() throws Exception {
        long now = System.currentTimeMillis();
        long tomorrow = SalaTimePrayerAlarms.midnightAfter(now, TimeZone.getTimeZone("UTC"), 1);
        long fourthDay = SalaTimePrayerAlarms.windowEnd(app, null, now) + 60000;
        save(row(12000001, tomorrow + 60000), row(12000002, fourthDay));
        SalaTimePrayerAlarms.routeWindow(app, now);
        assertNull(SalaTimePrayerAlarms.operation(app, 12000002, false));
        SalaTimePrayerAlarms.maintainWindow(app, tomorrow + 1000);
        assertNotNull(SalaTimePrayerAlarms.operation(app, 12000002, false));
        assertEquals(2, count(SalaTimePrayerAlarmReceiver.class));
        assertEquals(1, count(SalaTimePrayerWindowReceiver.class));
        SalaTimePrayerAlarms.maintainWindow(app, tomorrow + 2000);
        assertEquals(1, count(SalaTimePrayerWindowReceiver.class));
        assertEquals(2, SalaTimePrayerAlarms.cached(app).length());
    }

    @Test public void sameDayDeliveriesDoNotRebuildWindowOrConsumeOtherDueAlarms() throws Exception {
        long now = System.currentTimeMillis();
        save(row(12000001, now), row(12000002, now + 60000));
        SalaTimePrayerAlarms.routeWindow(app, now);
        Object scheduled = Shadows.shadowOf(alarms).getScheduledAlarms().stream()
                .filter(alarm -> Shadows.shadowOf(alarm.operation).getSavedIntent()
                        .getComponent().getClassName().equals(SalaTimePrayerAlarmReceiver.class.getName()))
                .findFirst().get();
        SalaTimePrayerAlarms.renewIfNeeded(app, now + 1000);
        assertNotNull(SalaTimePrayerAlarms.find(app, 12000001));
        assertTrue(Shadows.shadowOf(alarms).getScheduledAlarms().contains(scheduled));
        assertEquals(now, app.getSharedPreferences(SalaTimePrayerAlarms.WINDOW_STORE, 0).getLong("lastRenewalAt", 0));
    }

    @Test public void receiverConsumptionAfterMidnightReplenishesAndPreservesSimultaneousReminder() throws Exception {
        long now = System.currentTimeMillis();
        long nextDay = SalaTimePrayerAlarms.midnightAfter(now, TimeZone.getTimeZone("UTC"), 1);
        long future = SalaTimePrayerAlarms.windowEnd(app, null, now) + 60000;
        save(row(12000001, nextDay), row(12000002, nextDay), row(12000003, future));
        SalaTimePrayerAlarms.routeWindow(app, now);
        new SalaTimePrayerAlarmReceiver().receiveAt(app,
                new Intent(app, SalaTimePrayerAlarmReceiver.class).putExtra("id", 12000001).putExtra("at", nextDay),
                nextDay + 1000);
        assertNull(SalaTimePrayerAlarms.find(app, 12000001));
        assertNotNull(SalaTimePrayerAlarms.find(app, 12000002));
        assertNotNull(SalaTimePrayerAlarms.operation(app, 12000003, false));
        assertEquals(1, count(SalaTimePrayerWindowReceiver.class));
    }

    @Test public void cancellingAllCancelsMaintenanceAndOnlyOwnedAlarms() throws Exception {
        long now = System.currentTimeMillis();
        save(row(12000001, now + 60000));
        SalaTimePrayerAlarms.routeWindow(app, now);
        PendingIntent foreign = PendingIntent.getBroadcast(app, 8, new Intent(app, ScheduledNotificationReceiver.class),
                PendingIntent.FLAG_IMMUTABLE);
        alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, now + 90000, foreign);
        SalaTimePrayerAlarms.cancelAll(app);
        assertEquals(0, count(SalaTimePrayerAlarmReceiver.class));
        assertEquals(0, count(SalaTimePrayerWindowReceiver.class));
        assertEquals(1, count(ScheduledNotificationReceiver.class));
    }

    @Test public void bootRestoresThreeDaysAndKeepsDistantAndForeignCacheRows() throws Exception {
        long now = System.currentTimeMillis();
        JSONObject near = row(12000001, now + 60000);
        JSONObject distant = row(12000002, SalaTimePrayerAlarms.windowEnd(app, null, now) + 60000);
        JSONObject foreign = row(8, now + 120000).put("payload", "unrelated");
        save(near, distant, foreign);
        new SalaTimeAlarmRestoreReceiver().onReceive(app, new Intent(Intent.ACTION_BOOT_COMPLETED));
        assertEquals(1, count(SalaTimePrayerAlarmReceiver.class));
        assertEquals(1, count(ScheduledNotificationReceiver.class));
        assertEquals(1, count(SalaTimePrayerWindowReceiver.class));
        assertEquals(3, SalaTimePrayerAlarms.cached(app).length());
        assertNull(SalaTimePrayerAlarms.operation(app, 12000002, false));
    }

    @Test public void completedBatchHandoffDoesNotRearmPrayersOrMaintenance() throws Exception {
        long now = System.currentTimeMillis();
        save(row(12000001, now + 60000));
        SalaTimePrayerAlarms.routeWindow(app, now);
        ArrayList<?> before = new ArrayList<>(Shadows.shadowOf(alarms).getScheduledAlarms());
        assertEquals(0, SalaTimePrayerAlarms.refreshWindowIfNeeded(app, now + 1000).get("routed"));
        assertEquals(before, new ArrayList<>(Shadows.shadowOf(alarms).getScheduledAlarms()));
        assertEquals(now, app.getSharedPreferences(SalaTimePrayerAlarms.WINDOW_STORE, 0)
                .getLong("lastRenewalAt", 0));
    }

    @Test public void completedBatchHandoffStillExtendsAfterCalendarDayChange() throws Exception {
        long now = System.currentTimeMillis();
        long tomorrow = SalaTimePrayerAlarms.midnightAfter(now, TimeZone.getTimeZone("UTC"), 1);
        long newDay = SalaTimePrayerAlarms.windowEnd(app, null, now) + 60000;
        save(row(12000001, tomorrow + 60000), row(12000002, newDay));
        SalaTimePrayerAlarms.routeWindow(app, now);
        assertNull(SalaTimePrayerAlarms.operation(app, 12000002, false));
        assertEquals(2, SalaTimePrayerAlarms.refreshWindowIfNeeded(app, tomorrow + 1000).get("routed"));
        assertNotNull(SalaTimePrayerAlarms.operation(app, 12000002, false));
    }

    @Test public void completedBatchHandoffRechecksChangedWidgetTimeZone() throws Exception {
        long now = Instant.parse("2026-09-16T00:30:00Z").toEpochMilli();
        long oldEnd = SalaTimePrayerAlarms.windowEnd(app, null, now);
        save(row(12000001, now + 60000), row(12000002, oldEnd - 3600000));
        SalaTimePrayerAlarms.routeWindow(app, now);
        assertNotNull(SalaTimePrayerAlarms.operation(app, 12000002, false));
        app.getSharedPreferences("salatime_prayer_widget", 0).edit()
                .putString("timeZone", "Pacific/Kiritimati").commit();
        assertEquals(1, SalaTimePrayerAlarms.refreshWindowIfNeeded(app, now + 1000).get("routed"));
        assertNull(SalaTimePrayerAlarms.operation(app, 12000002, false));
        assertEquals(2, SalaTimePrayerAlarms.cached(app).length());
    }

    @Test @Config(sdk = 33)
    public void completedBatchHandoffRechecksExactPermissionAndPriorFailure() throws Exception {
        long now = System.currentTimeMillis();
        save(row(12000001, now + 60000));
        SalaTimePrayerAlarms.routeWindow(app, now);
        Shadows.shadowOf(alarms).setCanScheduleExactAlarms(false);
        Map<String, Object> downgraded = SalaTimePrayerAlarms.refreshWindowIfNeeded(app, now + 1000);
        assertEquals(1, downgraded.get("routed"));
        assertEquals(true, downgraded.get("inexact"));
        app.getSharedPreferences(SalaTimePrayerAlarms.WINDOW_STORE, 0).edit()
                .putBoolean("failed", true).commit();
        assertEquals(1, SalaTimePrayerAlarms.refreshWindowIfNeeded(app, now + 2000).get("routed"));
        assertFalse(app.getSharedPreferences(SalaTimePrayerAlarms.WINDOW_STORE, 0)
                .getBoolean("failed", true));
    }
}
