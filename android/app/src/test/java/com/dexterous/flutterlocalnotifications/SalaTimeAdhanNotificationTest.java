package com.dexterous.flutterlocalnotifications;

import static org.junit.Assert.*;
import android.app.Application;
import android.app.AlarmManager;
import android.content.Intent;
import android.os.Build;
import android.app.Notification;
import android.app.NotificationManager;
import android.content.Context;
import android.os.SystemClock;
import android.view.View;
import android.widget.Chronometer;
import android.widget.FrameLayout;
import android.widget.TextView;
import androidx.core.app.NotificationCompat;
import com.example.zabi.R;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.dexterous.flutterlocalnotifications.models.NotificationStyle;
import com.dexterous.flutterlocalnotifications.models.styles.DefaultStyleInformation;
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
public class SalaTimeAdhanNotificationTest {
    private final Application app = RuntimeEnvironment.getApplication();

    private NotificationDetails details() throws Exception {
        NotificationDetails d = new NotificationDetails();
        d.id = 12000031;
        d.title = "Dohr";
        d.body = "Prayer at 13:20";
        d.icon = "@mipmap/launcher_icon";
        d.channelId = "adhan_notification_test_no_badge";
        d.channelName = "Adhan";
        d.importance = NotificationManager.IMPORTANCE_HIGH;
        d.priority = NotificationCompat.PRIORITY_HIGH;
        d.style = NotificationStyle.Default;
        d.styleInformation = new DefaultStyleInformation(false, false);
        d.autoCancel = true;
        d.playSound = false;
        d.channelShowBadge = false;
        d.payload = new JSONObject().put("kind", "adhan")
                .put("prayerAt", System.currentTimeMillis() - 398000)
                .put("prayerName", "Dohr").put("prayerTime", "13:20")
                .put("hijriDate", "4 Rabia ath-Thani 1448")
                .put("locale", "fr").put("elapsedLabel", "Temps écoulé depuis Dohr").toString();
        return d;
    }

    private View inflate(Notification n) {
        assertNotNull(n.contentView);
        return n.contentView.apply(app, new FrameLayout(app));
    }

    @Test public void displaysPrayerDateAndGreenElapsedTimeWithoutABadge() throws Exception {
        NotificationDetails d = details();
        Notification n = SalaTimeAdhanNotification.builder(app, d).build();
        View root = inflate(n);
        assertEquals("4 Rabia ath-Thani 1448", ((TextView)root.findViewById(R.id.adhan_notification_date)).getText().toString());
        assertEquals("Dohr · 13:20", ((TextView)root.findViewById(R.id.adhan_notification_prayer)).getText().toString());
        Chronometer timer = root.findViewById(R.id.adhan_notification_elapsed);
        assertEquals(System.currentTimeMillis() - new JSONObject(d.payload).getLong("prayerAt"),
                SystemClock.elapsedRealtime() - timer.getBase(), 1000);
        assertFalse(timer.isCountDown());
        assertEquals(app.getColor(R.color.adhan_elapsed_green), timer.getCurrentTextColor());
        assertEquals("Temps écoulé depuis Dohr · 13:20",
                root.findViewById(R.id.adhan_notification_prayer).getContentDescription());
        assertFalse(timer.getContentDescription().toString().isEmpty());
        assertEquals(0, n.number);
        assertTrue((n.flags & Notification.FLAG_ONLY_ALERT_ONCE) != 0);
        assertNotNull(n.bigContentView);
        assertNotNull(n.headsUpContentView);
        assertNotNull(n.contentIntent);
    }

    @Test public void silentReplacementKeepsOriginalPrayerInstant() throws Exception {
        NotificationDetails d = details();
        long originalBase = ((Chronometer)inflate(SalaTimeAdhanNotification.builder(app, d).build())
                .findViewById(R.id.adhan_notification_elapsed)).getBase();
        SalaTimePrayerAlarmReceiver.showSilent(app, d);
        NotificationManager manager = (NotificationManager)app.getSystemService(Context.NOTIFICATION_SERVICE);
        Notification n = Shadows.shadowOf(manager).getNotification(d.id);
        Chronometer timer = inflate(n).findViewById(R.id.adhan_notification_elapsed);
        // Application wall time and Robolectric uptime are separate clocks.
        assertEquals(originalBase, timer.getBase(), 1000);
        long elapsed = SystemClock.elapsedRealtime() - timer.getBase();
        SystemClock.sleep(60000);
        assertEquals(elapsed + 60000, SystemClock.elapsedRealtime() - timer.getBase());
        assertNull(n.sound);
        assertEquals(0, n.flags & Notification.FLAG_ONGOING_EVENT);
        assertTrue(n.actions == null || n.actions.length == 0);
    }

    @Test @Config(qualifiers = "night") public void supportsDarkThemeAndArabicDirection() throws Exception {
        NotificationDetails d = details();
        d.payload = new JSONObject(d.payload).put("locale", "ar").toString();
        View root = inflate(SalaTimeAdhanNotification.builder(app, d).build());
        assertEquals(View.LAYOUT_DIRECTION_RTL, root.findViewById(R.id.adhan_notification_root).getLayoutDirection());
        Chronometer timer = root.findViewById(R.id.adhan_notification_elapsed);
        assertEquals(0xff81c784, timer.getCurrentTextColor());
        assertEquals(View.LAYOUT_DIRECTION_LTR, timer.getLayoutDirection());
    }

    @Test public void otherRemindersTestsAndInvalidDatesKeepStandardNotification() throws Exception {
        for (String payload : new String[] {
                "{\"kind\":\"before\",\"prayerAt\":1}",
                "{\"kind\":\"after\",\"prayerAt\":1}",
                "{\"kind\":\"extra_reminder\",\"prayerAt\":1}",
                "{\"kind\":\"adhan\",\"prayerAt\":1,\"test\":true}",
                "{\"kind\":\"adhan\",\"prayerAt\":0}",
                "{\"kind\":\"adhan\",\"prayerAt\":9223372036854775807}", "invalid"}) {
            NotificationDetails d = details();
            d.payload = payload;
            assertNull(SalaTimeAdhanNotification.builder(app, d).getContentView());
        }
    }
    private NotificationDetails withNext() throws Exception {
        NotificationDetails d = details();
        JSONObject payload = new JSONObject(d.payload);
        long at = SalaTimeAdhanNotification.prayerAt(payload);
        payload.put("nextPrayer", new JSONObject().put("prayerAt", at + 4 * SalaTimeAdhanNotification.HOUR)
                .put("prayerName", "Assr").put("prayerTime", "17:20")
                .put("hijriDate", "4 Rabia ath-Thani 1448").put("nextLabel", "Prochaine prière : Assr"));
        d.payload = payload.toString();
        return d;
    }

    private Notification atTime(NotificationDetails d, long now) {
        return SalaTimeAdhanNotification.decorate(app, d,
                FlutterLocalNotificationsPlugin.createNotification(app, d), now).build();
    }

    @Test public void switchesAtOneHourAndTurnsRedExactlyOneHourBeforeNext() throws Exception {
        NotificationDetails d = withNext();
        long at = SalaTimeAdhanNotification.prayerAt(new JSONObject(d.payload));
        long hour = SalaTimeAdhanNotification.HOUR;
        Chronometer elapsed = inflate(atTime(d, at + hour - 1)).findViewById(R.id.adhan_notification_elapsed);
        assertFalse(elapsed.isCountDown());
        assertEquals(app.getColor(R.color.adhan_elapsed_green), elapsed.getCurrentTextColor());
        View next = inflate(atTime(d, at + hour));
        assertEquals("Assr · 17:20", ((TextView)next.findViewById(R.id.adhan_notification_prayer)).getText().toString());
        Chronometer countdown = next.findViewById(R.id.adhan_notification_elapsed);
        assertTrue(countdown.isCountDown());
        assertEquals(3 * hour, countdown.getBase() - SystemClock.elapsedRealtime());
        assertEquals(app.getColor(R.color.adhan_elapsed_green), countdown.getCurrentTextColor());
        for (long now : new long[] {at + 3 * hour - 1, at + 3 * hour, at + 3 * hour + 1}) {
            Chronometer timer = inflate(atTime(d, now)).findViewById(R.id.adhan_notification_elapsed);
            assertTrue(timer.isCountDown());
            assertEquals(app.getColor(now < at + 3 * hour
                    ? R.color.adhan_elapsed_green : R.color.adhan_countdown_red), timer.getCurrentTextColor());
        }
    }

    @Test public void boundaryPlanDoesNotPollAndHandlesCloseOrMissingNextPrayer() throws Exception {
        JSONObject payload = new JSONObject(withNext().payload);
        long at = SalaTimeAdhanNotification.prayerAt(payload);
        long hour = SalaTimeAdhanNotification.HOUR;
        assertEquals(at + hour, SalaTimeAdhanNotification.nextTransition(payload, at));
        assertEquals(at + 3 * hour, SalaTimeAdhanNotification.nextTransition(payload, at + hour));
        assertEquals(at + 4 * hour, SalaTimeAdhanNotification.nextTransition(payload, at + 3 * hour));
        assertEquals(0, SalaTimeAdhanNotification.nextTransition(payload, at + 4 * hour));
        payload.getJSONObject("nextPrayer").put("prayerAt", at + hour / 2);
        assertEquals(at + hour / 2, SalaTimeAdhanNotification.nextTransition(payload, at));
        payload.getJSONObject("nextPrayer").put("prayerAt", at - 1);
        assertEquals(0, SalaTimeAdhanNotification.nextTransition(payload, at));
        payload.remove("nextPrayer");
        assertEquals(0, SalaTimeAdhanNotification.nextTransition(payload, at));
    }

    private NotificationManager notifications() {
        return (NotificationManager)app.getSystemService(Context.NOTIFICATION_SERVICE);
    }

    private org.robolectric.shadows.ShadowAlarmManager alarms() {
        return Shadows.shadowOf((AlarmManager)app.getSystemService(Context.ALARM_SERVICE));
    }

    @Test public void backgroundTransitionsStaySilentAndStopAtNextPrayer() throws Exception {
        alarms().setCanScheduleExactAlarms(true);
        NotificationDetails d = withNext();
        long at = SalaTimeAdhanNotification.prayerAt(new JSONObject(d.payload));
        long hour = SalaTimeAdhanNotification.HOUR;
        SalaTimePrayerAlarmReceiver.showSilent(app, d);
        assertEquals(1, alarms().getScheduledAlarms().size());
        assertEquals(at + hour, alarms().getScheduledAlarms().get(0).triggerAtTime);
        for (long now : new long[] {at + hour, at + 3 * hour}) {
            SalaTimeAdhanNotificationReceiver.refresh(app, d.id, now);
            Notification n = Shadows.shadowOf(notifications()).getNotification(d.id);
            Chronometer timer = inflate(n).findViewById(R.id.adhan_notification_elapsed);
            assertTrue(timer.isCountDown());
            assertEquals(app.getColor(now == at + hour ? R.color.adhan_elapsed_green
                    : R.color.adhan_countdown_red), timer.getCurrentTextColor());
            assertNull(n.sound);
            assertNull(n.vibrate);
            assertEquals(0, n.number);
            assertTrue(n.actions == null || n.actions.length == 0);
            assertEquals(1, alarms().getScheduledAlarms().size());
            assertEquals(now == at + hour ? at + 3 * hour : at + 4 * hour,
                    alarms().getScheduledAlarms().get(0).triggerAtTime);
        }
        SalaTimeAdhanNotificationReceiver.refresh(app, d.id, at + 4 * hour);
        assertEquals(0, notifications().getActiveNotifications().length);
        assertTrue(alarms().getScheduledAlarms().isEmpty());
        assertNull(Shadows.shadowOf(app).getNextStartedService());
    }

    @Test public void dismissalIsRespectedAndANewPrayerReplacesTheOldOne() throws Exception {
        NotificationDetails d = withNext();
        long at = SalaTimeAdhanNotification.prayerAt(new JSONObject(d.payload));
        SalaTimePrayerAlarmReceiver.showSilent(app, d);
        notifications().cancel(d.id);
        SalaTimeAdhanNotificationReceiver.refresh(app, d.id, at + SalaTimeAdhanNotification.HOUR);
        assertEquals(0, notifications().getActiveNotifications().length);
        assertTrue(alarms().getScheduledAlarms().isEmpty());
        SalaTimePrayerAlarmReceiver.showSilent(app, d);
        NotificationDetails newer = withNext();
        newer.id = d.id + 1;
        SalaTimePrayerAlarmReceiver.showSilent(app, newer);
        assertEquals(1, notifications().getActiveNotifications().length);
        assertEquals((int)newer.id, notifications().getActiveNotifications()[0].getId());
        SalaTimeAdhanNotificationReceiver.refresh(app, d.id, at + 5 * SalaTimeAdhanNotification.HOUR);
        assertEquals("Stale deliveries must not dismiss the new prayer", 1, notifications().getActiveNotifications().length);
    }

    @Test public void persistedStateRestoresWithoutReplacingTheAudioStopAction() throws Exception {
        NotificationDetails d = withNext();
        Notification ongoing = SalaTimeAdhanNotification.builder(app, d).setOngoing(true)
                .addAction(0, "Arrêter", null).build();
        notifications().notify(d.id, ongoing);
        SalaTimeAdhanNotificationReceiver.onPosted(app, d);
        new SalaTimeAdhanNotificationReceiver().onReceive(app,
                new Intent().putExtra("id", d.id));
        Notification kept = Shadows.shadowOf(notifications()).getNotification(d.id);
        assertEquals("Arrêter", kept.actions[0].title);
        assertTrue((kept.flags & Notification.FLAG_ONGOING_EVENT) != 0);
        // A reboot clears notifications. Restoration must not resurrect them.
        notifications().cancelAll();
        SalaTimeAdhanNotificationReceiver.restore(app);
        assertTrue(alarms().getScheduledAlarms().isEmpty());
        assertEquals(0, notifications().getActiveNotifications().length);
    }

    @Test @Config(sdk = 33) public void deniedExactPermissionUsesASilentInexactFallback() throws Exception {
        alarms().setCanScheduleExactAlarms(false);
        SalaTimePrayerAlarmReceiver.showSilent(app, withNext());
        assertEquals(1, alarms().getScheduledAlarms().size());
        assertNull(((AlarmManager)app.getSystemService(Context.ALARM_SERVICE)).getNextAlarmClock());
    }

}
