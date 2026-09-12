package com.dexterous.flutterlocalnotifications;

import android.app.AlarmManager;
import android.app.Application;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.ContextWrapper;
import android.content.ComponentName;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Looper;
import android.os.PowerManager;
import android.media.AudioAttributes;
import android.media.AudioManager;
import android.media.MediaPlayer;
import org.robolectric.Robolectric;
import org.robolectric.android.controller.ServiceController;
import org.robolectric.shadows.ShadowMediaPlayer;
import org.robolectric.shadows.ShadowPowerManager;
import org.robolectric.shadows.util.DataSource;
import androidx.core.app.NotificationCompat;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.dexterous.flutterlocalnotifications.models.NotificationStyle;
import com.dexterous.flutterlocalnotifications.models.styles.DefaultStyleInformation;
import org.json.JSONArray;
import org.json.JSONObject;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.Shadows;
import org.robolectric.annotation.Config;
import java.time.Duration;
import static org.junit.Assert.*;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = {24, 33}, application = Application.class)
public class SalaTimePrayerAlarmsTest {
    private Context app;
    private AlarmManager manager;
    private long now;
    private static final int ID = 12000001;

    @Before public void setup() {
        app = RuntimeEnvironment.getApplication();
        manager = (AlarmManager) app.getSystemService(Context.ALARM_SERVICE);
        Shadows.shadowOf(manager).setCanScheduleExactAlarms(true);
        now = System.currentTimeMillis();
    }

    private NotificationDetails details() {
        NotificationDetails d = new NotificationDetails();
        d.id = ID;
        d.title = "Fajr";
        d.body = "Prayer at 05:36";
        d.icon = "@mipmap/launcher_icon";
        d.channelId = "adhan_azan_2_no_badge_v1";
        d.channelName = "Adhan";
        d.importance = NotificationManager.IMPORTANCE_HIGH;
        d.priority = NotificationCompat.PRIORITY_HIGH;
        d.playSound = true;
        d.sound = "azan_2";
        d.style = NotificationStyle.Default;
        d.styleInformation = new DefaultStyleInformation(false, false);
        d.autoCancel = true;
        d.channelShowBadge = false;
        return d;
    }

    private JSONObject row(long at, String kind) throws Exception {
        NotificationDetails d = details();
        d.payload = new JSONObject().put("id", ID).put("prayerId", 1).put("kind", kind)
                .put("at", at).put("prayerAt", "before".equals(kind) ? at + 600000 : at).toString();
        return new JSONObject(FlutterLocalNotificationsPlugin.buildGson().toJson(d));
    }

    private void save(JSONObject... rows) {
        JSONArray values = new JSONArray();
        for (JSONObject row : rows) values.put(row);
        app.getSharedPreferences(SalaTimePrayerAlarms.STORE, 0).edit()
                .putString(SalaTimePrayerAlarms.STORE, values.toString()).commit();
    }

    private Intent delivery(long at) {
        return new Intent(app, SalaTimePrayerAlarmReceiver.class).putExtra("id", ID).putExtra("at", at);
    }

    @Test public void adhanUsesVisibleAlarmClockAndShortcutOpensApp() throws Exception {
        long at = now + 600000;
        JSONObject row = row(at, "adhan");
        save(row);
        PendingIntent legacy = PendingIntent.getBroadcast(app, ID,
                new Intent(app, ScheduledNotificationReceiver.class), PendingIntent.FLAG_IMMUTABLE);
        manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, legacy);
        assertEquals(1, SalaTimePrayerAlarms.route(app, ID).get("routed"));
        assertEquals(at, manager.getNextAlarmClock().getTriggerTime());
        assertTrue(Shadows.shadowOf(manager.getNextAlarmClock().getShowIntent()).isActivityIntent());
        assertEquals(1, Shadows.shadowOf(manager).getScheduledAlarms().size());
        assertNotNull(SalaTimePrayerAlarms.find(app, ID));
        assertNotNull(SalaTimePrayerAlarms.operation(app, ID, false));
        assertTrue((Shadows.shadowOf(SalaTimePrayerAlarms.operation(app, ID, false))
                .getSavedIntent().getFlags() & Intent.FLAG_RECEIVER_FOREGROUND) != 0);
    }

    @Test public void reminderDoesNotReplaceNextPrayerClockAndCancellationRemovesIt() throws Exception {
        JSONObject adhan = row(now + 600000, "adhan");
        SalaTimePrayerAlarms.register(app, adhan, now);
        JSONObject before = row(now + 60000, "before");
        JSONObject payload = SalaTimePrayerAlarms.prayer(before);
        payload.put("id", ID + 10);
        before.put("id", ID + 10).put("payload", payload.toString());
        assertEquals("exactAllowWhileIdle", SalaTimePrayerAlarms.register(app, before, now));
        assertEquals(now + 600000, manager.getNextAlarmClock().getTriggerTime());
        SalaTimePrayerAlarms.cancel(app, ID);
        assertNull(SalaTimePrayerAlarms.operation(app, ID, false));
        assertEquals(1, Shadows.shadowOf(manager).getScheduledAlarms().size());
    }

    @Test public void deniedExactPermissionFallsBackWithoutDroppingThePrayer() throws Exception {
        if (Build.VERSION.SDK_INT < 31) return;
        Shadows.shadowOf(manager).setCanScheduleExactAlarms(false);
        JSONObject row = row(now + 60000, "adhan");
        save(row);
        assertEquals("inexactAllowWhileIdle", SalaTimePrayerAlarms.register(app, row, now));
        assertNull(manager.getNextAlarmClock());
        assertEquals(1, Shadows.shadowOf(manager).getScheduledAlarms().size());
        assertNotNull(SalaTimePrayerAlarms.find(app, ID));
    }

    @Test public void staleBeforeReminderIsDiscardedAtUnlock() throws Exception {
        long at = now - 36 * 60000;
        save(row(at, "before"));
        new SalaTimePrayerAlarmReceiver().onReceive(app, delivery(at));
        assertNull(SalaTimePrayerAlarms.find(app, ID));
        assertNull(Shadows.shadowOf((Application) app).getNextStartedService());
        assertEquals(0, ((NotificationManager) app.getSystemService(Context.NOTIFICATION_SERVICE)).getActiveNotifications().length);
    }

    @Test public void deliveredCancelledOrRescheduledBroadcastCannotPlay() throws Exception {
        save(row(now + 60000, "adhan"));
        new SalaTimePrayerAlarmReceiver().onReceive(app, delivery(now - 60000));
        assertNotNull(SalaTimePrayerAlarms.find(app, ID));
        save();
        new SalaTimePrayerAlarmReceiver().onReceive(app, delivery(now));
        assertNull(Shadows.shadowOf((Application) app).getNextStartedService());
    }

    @Test public void earlyBroadcastIsRearmedAndDoesNotConsumePrayer() throws Exception {
        long at = now + 60000;
        save(row(at, "adhan"));
        new SalaTimePrayerAlarmReceiver().onReceive(app, delivery(at));
        assertNotNull(SalaTimePrayerAlarms.find(app, ID));
        assertEquals(at, manager.getNextAlarmClock().getTriggerTime());
        assertNull(Shadows.shadowOf((Application) app).getNextStartedService());
    }

    @Test public void adhanReceivedOnTimeStartsAudioOnlyOnce() throws Exception {
        long at = now - 1000;
        save(row(at, "adhan"));
        new SalaTimePrayerAlarmReceiver().onReceive(app, delivery(at));
        Intent service = Shadows.shadowOf((Application) app).getNextStartedService();
        assertNotNull(service);
        assertEquals(SalaTimeAdhanService.class.getName(), service.getComponent().getClassName());
        assertNull(SalaTimePrayerAlarms.find(app, ID));
        new SalaTimePrayerAlarmReceiver().onReceive(app, delivery(at));
        assertNull(Shadows.shadowOf((Application) app).getNextStartedService());
        SalaTimeAlarmWakeLock.complete(service);
    }

    @Test public void lateAdhanIsSilentAndShowsOriginalTime() throws Exception {
        long at = now - 26 * 60000;
        save(row(at, "adhan"));
        new SalaTimePrayerAlarmReceiver().onReceive(app, delivery(at));
        assertNull(Shadows.shadowOf((Application) app).getNextStartedService());
        android.service.notification.StatusBarNotification[] notifications =
                ((NotificationManager) app.getSystemService(Context.NOTIFICATION_SERVICE)).getActiveNotifications();
        assertEquals(1, notifications.length);
        assertEquals(at, notifications[0].getNotification().when);
        assertNull(notifications[0].getNotification().sound);
        assertEquals("late_silent", SalaTimePrayerAlarms.status(app).get("outcome"));
        assertTrue(((Number) SalaTimePrayerAlarms.status(app).get("delayMs")).longValue() >= 26 * 60000);
    }

    @Test public void foreignNotificationsAndMutedChannelsArePreserved() throws Exception {
        JSONObject foreign = new JSONObject().put("id", 8).put("payload", "unrelated");
        save(foreign);
        assertEquals(0, SalaTimePrayerAlarms.routeAll(app).get("routed"));
        assertNotNull(SalaTimePrayerAlarms.find(app, 8));
        NotificationDetails d = details();
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationChannel channel = new NotificationChannel(d.channelId, "Muted", NotificationManager.IMPORTANCE_HIGH);
            channel.setSound(null, null);
            ((NotificationManager) app.getSystemService(Context.NOTIFICATION_SERVICE)).createNotificationChannel(channel);
            assertNull(SalaTimeAdhanService.playableSound(app, d));
        } else {
            assertEquals(Uri.parse("android.resource://" + app.getPackageName() + "/raw/azan_2"), SalaTimeAdhanService.playableSound(app, d));
            d.playSound = false;
            assertNull(SalaTimeAdhanService.playableSound(app, d));
        }
    }

    @Test public void bundledMoatheniSoundsPlayForAdhanAndUnsafeResourcesAreRejected() {
        NotificationDetails d = details();
        for (String sound : new String[] {"moatheni_water", "moatheni_short3", "noti_beep"}) {
            assertTrue(com.example.zabi.BundledNotificationSounds.contains(sound));
            d.sound = sound;
            assertEquals(Uri.parse("android.resource://" + app.getPackageName() + "/raw/" + sound),
                    SalaTimeAdhanService.playableSound(app, d));
        }
        for (String sound : new String[] {"silent", "azan_999", "moatheni_unknown", "../private", "content://foreign/audio", null}) {
            d.sound = sound;
            assertNull(SalaTimeAdhanService.playableSound(app, d));
        }
        d.sound = "moatheni_short3";
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationChannel channel = new NotificationChannel(d.channelId, "Muted", NotificationManager.IMPORTANCE_HIGH);
            channel.setSound(null, null);
            ((NotificationManager) app.getSystemService(Context.NOTIFICATION_SERVICE)).createNotificationChannel(channel);
            assertNull(SalaTimeAdhanService.playableSound(app, d));
        }
    }

    @Test public void sunriseIsASeparateValidatedNotificationAndDoesNotAliasFajr() throws Exception {
        JSONObject row = row(now + 600000, "adhan");
        JSONObject payload = new JSONObject(row.getString("payload"));
        payload.put("prayerId", 6);
        row.put("payload", payload.toString());
        assertNull(SalaTimePrayerAlarms.prayer(row));
        payload.put("prayer", "sunrise");
        row.put("payload", payload.toString());
        assertEquals(6, SalaTimePrayerAlarms.prayer(row).getInt("prayerId"));
        payload.put("prayerId", 7);
        row.put("payload", payload.toString());
        assertNull(SalaTimePrayerAlarms.prayer(row));
    }

    @Test public void extraRemindersRouteWithoutPrayerIdAndExpireWhenStale() throws Exception {
        JSONObject payload = new JSONObject().put("id", 20207100).put("kind", "extra_reminder")
                .put("type", "duha").put("date", "2026-09-12").put("at", now + 60000);
        JSONObject row = new JSONObject().put("id", 20207100).put("payload", payload.toString());
        assertNotNull(SalaTimePrayerAlarms.prayer(row));
        assertEquals("on_time", SalaTimePrayerAlarms.deliveryPolicy(payload, now + 60000));
        assertEquals("expired", SalaTimePrayerAlarms.deliveryPolicy(payload, now + 181000));
        payload.put("date", "2026-99-99");
        row.put("payload", payload.toString());
        assertNull(SalaTimePrayerAlarms.prayer(row));
        payload.put("date", "2026-09-12").put("type", "foreign");
        row.put("payload", payload.toString());
        assertNull(SalaTimePrayerAlarms.prayer(row));
    }

    @Test public void newExtraReminderTypesRouteFromBothStableIdBanks() throws Exception {
        String[] types = {"fajrAlarm", "bedtime", "middleNight", "monday", "thursday"};
        for (int i = 0; i < types.length; i++) {
            int id = (i < 3 ? 21207100 : 20207100) + i;
            JSONObject payload = new JSONObject().put("id", id).put("kind", "extra_reminder")
                    .put("type", types[i]).put("date", "2026-09-12").put("at", now + 60000);
            JSONObject row = new JSONObject().put("id", id).put("payload", payload.toString());
            assertNotNull(types[i], SalaTimePrayerAlarms.prayer(row));
            assertEquals("exactAllowWhileIdle", SalaTimePrayerAlarms.register(app, row, now));
            assertNotNull(SalaTimePrayerAlarms.operation(app, id, false));
        }
    }

    @Test public void personalAdhanUsesPrivateUriAndRespectsMutedChannel() throws Exception {
        NotificationDetails d = details();
        d.sound = "content://" + app.getPackageName() + ".personal-sounds/sounds/custom_"
                + new String(new char[64]).replace('\0', 'a') + ".mp3";
        assertEquals(Uri.parse(d.sound), SalaTimeAdhanService.playableSound(app, d));
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationChannel channel = new NotificationChannel(d.channelId, "Muted", NotificationManager.IMPORTANCE_HIGH);
            channel.setSound(null, null);
            ((NotificationManager) app.getSystemService(Context.NOTIFICATION_SERVICE)).createNotificationChannel(channel);
            assertNull(SalaTimeAdhanService.playableSound(app, d));
        }
        d.playSound = false;
        assertNull(SalaTimeAdhanService.playableSound(app, d));
    }

    @Test public void fullAdhanUsesAlarmAudioAndReleasesResourcesOnStop() throws Exception {
        assertPlaybackFinishes(true);
    }

    @Test public void fullAdhanFinishesWithoutRestartOrWakeLockLeak() throws Exception {
        assertPlaybackFinishes(false);
    }

    @Test public void zeroAlarmVolumeAndDeniedAudioFocusStaySilent() throws Exception {
        AudioManager audio = (AudioManager) app.getSystemService(Context.AUDIO_SERVICE);
        final MediaPlayer[] created = new MediaPlayer[1];
        ShadowMediaPlayer.setCreateListener((media, shadow) -> created[0] = media);
        for (int volume : new int[] {0, 5}) {
            audio.setStreamVolume(AudioManager.STREAM_ALARM, volume, 0);
            Shadows.shadowOf(audio).setNextFocusRequestResponse(AudioManager.AUDIOFOCUS_REQUEST_FAILED);
            ServiceController<SalaTimeAdhanService> controller = Robolectric.buildService(SalaTimeAdhanService.class).create();
            JSONObject row = row(now - 1000, "adhan");
            SalaTimePrayerAlarms.record(app, SalaTimePrayerAlarms.prayer(row), now, "on_time");
            controller.get().onStartCommand(new Intent(app, SalaTimeAdhanService.class)
                    .putExtra("notification", row.toString()), 0, 1);
            assertNull(created[0]);
            assertNull(ShadowPowerManager.getLatestWakeLock());
            assertTrue(Shadows.shadowOf(controller.get()).isStoppedBySelf());
            assertEquals(volume == 0 ? "audio_muted" : "audio_interrupted",
                    SalaTimePrayerAlarms.status(app).get("outcome"));
            controller.destroy();
        }
    }

    @Test public void coldAlarmKeepsCpuAwakeUntilThePlayerTakesOver() throws Exception {
        long at = now - 1000;
        save(row(at, "adhan"));
        new SalaTimePrayerAlarmReceiver().onReceive(app, delivery(at));
        Intent start = Shadows.shadowOf((Application) app).getNextStartedService();
        PowerManager.WakeLock handoff = ShadowPowerManager.getLatestWakeLock();
        assertNotNull("The receiver must protect the gap before the service starts", handoff);
        assertTrue(handoff.isHeld());

        AudioManager audio = (AudioManager) app.getSystemService(Context.AUDIO_SERVICE);
        audio.setStreamVolume(AudioManager.STREAM_ALARM, 5, 0);
        Shadows.shadowOf(audio).setNextFocusRequestResponse(AudioManager.AUDIOFOCUS_REQUEST_GRANTED);
        Uri sound = Uri.parse("android.resource://" + app.getPackageName() + "/raw/azan_2");
        ShadowMediaPlayer.addMediaInfo(DataSource.toDataSource(app, sound), new ShadowMediaPlayer.MediaInfo(180000, 0));
        final MediaPlayer[] created = new MediaPlayer[1];
        ShadowMediaPlayer.setCreateListener((media, shadow) -> created[0] = media);
        ServiceController<SalaTimeAdhanService> controller = Robolectric.buildService(SalaTimeAdhanService.class).create();
        assertTrue(handoff.isHeld());
        controller.get().onStartCommand(start, 0, 1);
        Shadows.shadowOf(Looper.getMainLooper()).idle();
        PowerManager.WakeLock playback = ShadowPowerManager.getLatestWakeLock();
        assertNotSame(handoff, playback);
        assertTrue(playback.isHeld());
        assertFalse("Release the startup lock once the player owns its lock", handoff.isHeld());
        assertNotNull(created[0]);
        assertTrue(Shadows.shadowOf(created[0]).isReallyPlaying());
        Shadows.shadowOf(created[0]).invokeCompletionListener();
        assertFalse(playback.isHeld());
        assertFalse(handoff.isHeld());
        controller.destroy();
    }

    @Test public void startupLockExpiresAndAServiceArrivingThreeMinutesLateStaysSilent() throws Exception {
        long at = now - 1000;
        save(row(at, "adhan"));
        new SalaTimePrayerAlarmReceiver().onReceive(app, delivery(at));
        Intent start = Shadows.shadowOf((Application) app).getNextStartedService();
        PowerManager.WakeLock handoff = ShadowPowerManager.getLatestWakeLock();
        assertNotNull(handoff);
        assertTrue(handoff.isHeld());
        Shadows.shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(61));
        assertFalse("A service that never starts must not drain the battery", handoff.isHeld());
        // Robolectric advances Handler uptime independently of Java wall time.
        // Model a queued service whose original prayer timestamp is now 3 min old.
        long overdueAt = System.currentTimeMillis() - 3 * 60000 - 1000;
        JSONObject overdue = row(overdueAt, "adhan");
        start.putExtra("notification", overdue.toString());
        SalaTimePrayerAlarms.record(app, SalaTimePrayerAlarms.prayer(overdue), overdueAt + 1000, "on_time");
        final MediaPlayer[] created = new MediaPlayer[1];
        ShadowMediaPlayer.setCreateListener((media, shadow) -> created[0] = media);
        ServiceController<SalaTimeAdhanService> controller = Robolectric.buildService(SalaTimeAdhanService.class).create();
        controller.get().onStartCommand(start, 0, 1);
        assertNull(created[0]);
        assertFalse(handoff.isHeld());
        assertTrue(Shadows.shadowOf(controller.get()).isStoppedBySelf());
        assertEquals("late_silent", SalaTimePrayerAlarms.status(app).get("outcome"));
        assertTrue(((Number) SalaTimePrayerAlarms.status(app).get("delayMs")).longValue() >= 3 * 60000);
        controller.destroy();
    }

    @Test public void rejectedServiceStartReleasesTheStartupLockAndKeepsANotification() throws Exception {
        Context rejected = new ContextWrapper(app) {
            @Override public ComponentName startService(Intent intent) { throw new IllegalStateException("Service unavailable"); }
            @Override public ComponentName startForegroundService(Intent intent) { throw new IllegalStateException("Service unavailable"); }
        };
        long at = now - 1000;
        save(row(at, "adhan"));
        new SalaTimePrayerAlarmReceiver().onReceive(rejected, delivery(at));
        PowerManager.WakeLock handoff = ShadowPowerManager.getLatestWakeLock();
        assertNotNull(handoff);
        assertFalse(handoff.isHeld());
        assertEquals("audio_unavailable", SalaTimePrayerAlarms.status(app).get("outcome"));
        assertEquals(1, ((NotificationManager) app.getSystemService(Context.NOTIFICATION_SERVICE)).getActiveNotifications().length);
    }

    @Test public void rebootAndAppUpdateRestoreFuturePrayersWithoutReplayingExpiredOnes() throws Exception {
        for (String action : new String[] {Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED}) {
            NotificationManager notifications = (NotificationManager) app.getSystemService(Context.NOTIFICATION_SERVICE);
            notifications.cancelAll();
            long futureAt = now + 6 * 60 * 60000;
            JSONObject future = row(futureAt, "adhan").put("millisecondsSinceEpoch", futureAt);
            JSONObject expired = row(now - 26 * 60000, "adhan");
            JSONObject expiredPayload = SalaTimePrayerAlarms.prayer(expired);
            expiredPayload.put("id", ID + 1);
            expired.put("id", ID + 1).put("payload", expiredPayload.toString());
            JSONObject foreign = row(futureAt, "adhan").put("id", 8)
                    .put("payload", "unrelated").put("millisecondsSinceEpoch", futureAt);
            save(future, expired, foreign);
            SalaTimePrayerAlarms.register(app, future, now);
            new SalaTimeAlarmRestoreReceiver().onReceive(app, new Intent(action));
            assertNotNull(SalaTimePrayerAlarms.find(app, ID));
            assertNotNull(SalaTimePrayerAlarms.find(app, 8));
            assertNull(SalaTimePrayerAlarms.find(app, ID + 1));
            assertEquals(futureAt, manager.getNextAlarmClock().getTriggerTime());
            assertEquals(2, Shadows.shadowOf(manager).getScheduledAlarms().size());
            assertNull(Shadows.shadowOf((Application) app).getNextStartedService());
            android.service.notification.StatusBarNotification[] posted = notifications.getActiveNotifications();
            assertEquals(Intent.ACTION_BOOT_COMPLETED.equals(action) ? 1 : 0, posted.length);
            if (posted.length > 0) assertNull(posted[0].getNotification().sound);
        }
    }

    private void assertPlaybackFinishes(boolean stopByUser) throws Exception {
        AudioManager audio = (AudioManager) app.getSystemService(Context.AUDIO_SERVICE);
        audio.setStreamVolume(AudioManager.STREAM_ALARM, 5, 0);
        Shadows.shadowOf(audio).setNextFocusRequestResponse(AudioManager.AUDIOFOCUS_REQUEST_GRANTED);
        Uri sound = Uri.parse("android.resource://" + app.getPackageName() + "/raw/azan_2");
        ShadowMediaPlayer.addMediaInfo(DataSource.toDataSource(app, sound), new ShadowMediaPlayer.MediaInfo(180000, 0));
        final MediaPlayer[] created = new MediaPlayer[1];
        ShadowMediaPlayer.setCreateListener((media, shadow) -> created[0] = media);
        ServiceController<SalaTimeAdhanService> controller = Robolectric.buildService(SalaTimeAdhanService.class).create();
        SalaTimeAdhanService service = controller.get();
        JSONObject row = row(now - 1000, "adhan");
        SalaTimePrayerAlarms.record(app, SalaTimePrayerAlarms.prayer(row), now, "on_time");
        service.onStartCommand(new Intent(app, SalaTimeAdhanService.class).putExtra("notification", row.toString()), 0, 1);
        Shadows.shadowOf(Looper.getMainLooper()).idle();
        assertNotNull(SalaTimePrayerAlarms.status(app).toString(), created[0]);
        ShadowMediaPlayer media = Shadows.shadowOf(created[0]);
        assertTrue(media.isReallyPlaying());
        assertEquals(AudioAttributes.USAGE_ALARM, media.getAudioAttributes().getUsage());
        assertTrue(ShadowPowerManager.getLatestWakeLock().isHeld());
        assertNull(Shadows.shadowOf(service).getLastForegroundNotification().sound);
        long delay = ((Number) SalaTimePrayerAlarms.status(app).get("delayMs")).longValue();
        if (stopByUser) service.onStartCommand(new Intent(app, SalaTimeAdhanService.class).setAction(SalaTimeAdhanService.STOP), 0, 2);
        else media.invokeCompletionListener();
        assertEquals(ShadowMediaPlayer.State.END, media.getState());
        assertFalse(ShadowPowerManager.getLatestWakeLock().isHeld());
        assertTrue(Shadows.shadowOf(service).isStoppedBySelf());
        assertEquals(delay, ((Number) SalaTimePrayerAlarms.status(app).get("delayMs")).longValue());
        assertEquals(stopByUser ? "audio_stopped" : "audio_completed", SalaTimePrayerAlarms.status(app).get("outcome"));
        controller.destroy();
    }
}
