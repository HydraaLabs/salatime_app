package com.dexterous.flutterlocalnotifications;

import static org.junit.Assert.*;

import android.app.Application;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Build;
import android.os.Looper;
import android.os.PowerManager;
import androidx.core.app.NotificationCompat;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.dexterous.flutterlocalnotifications.models.NotificationStyle;
import com.dexterous.flutterlocalnotifications.models.styles.DefaultStyleInformation;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import org.json.JSONArray;
import org.json.JSONObject;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.Shadows;
import org.robolectric.android.controller.ServiceController;
import org.robolectric.annotation.Config;
import org.robolectric.annotation.LooperMode;
import org.robolectric.shadows.ShadowMediaPlayer;
import org.robolectric.shadows.ShadowPowerManager;
import org.robolectric.shadows.util.DataSource;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = {24, 33}, application = Application.class)
@LooperMode(LooperMode.Mode.PAUSED)
public class SalaTimeAdhanPlaybackPriorityTest {
    private static final String SOURCE = "adhan_priority_test";
    private Application app;
    private NotificationManager notifications;
    private ServiceController<SalaTimeAdhanService> controller;
    private Uri sound;
    private final List<MediaPlayer> players = new ArrayList<>();

    @Before public void setup() {
        app = RuntimeEnvironment.getApplication();
        notifications = (NotificationManager) app.getSystemService(Context.NOTIFICATION_SERVICE);
        AudioManager audio = (AudioManager) app.getSystemService(Context.AUDIO_SERVICE);
        audio.setMode(AudioManager.MODE_NORMAL);
        audio.setRingerMode(AudioManager.RINGER_MODE_NORMAL);
        audio.setStreamVolume(AudioManager.STREAM_ALARM, 5, 0);
        Shadows.shadowOf(audio).setNextFocusRequestResponse(AudioManager.AUDIOFOCUS_REQUEST_GRANTED);
        ShadowMediaPlayer.setCreateListener((player, shadow) -> players.add(player));
        sound = Uri.parse("android.resource://" + app.getPackageName() + "/raw/azan_2");
        ShadowMediaPlayer.addMediaInfo(DataSource.toDataSource(app, sound),
                new ShadowMediaPlayer.MediaInfo(180000, 0));
    }

    @After public void cleanup() {
        if (controller != null) controller.destroy();
        ShadowMediaPlayer.setCreateListener(null);
        PowerManager.WakeLock lock = ShadowPowerManager.getLatestWakeLock();
        if (lock != null && lock.isHeld()) lock.release();
    }

    private NotificationDetails details(int id) throws Exception {
        NotificationDetails details = new NotificationDetails();
        details.id = id;
        details.title = "Fajr";
        details.body = "Prayer at 05:36";
        details.icon = "@mipmap/launcher_icon";
        details.channelId = SOURCE;
        details.channelName = "Adhan";
        details.importance = NotificationManager.IMPORTANCE_HIGH;
        details.priority = NotificationCompat.PRIORITY_MAX;
        details.playSound = true;
        details.sound = "azan_2";
        details.style = NotificationStyle.Default;
        details.styleInformation = new DefaultStyleInformation(false, false);
        details.autoCancel = true;
        details.channelShowBadge = false;
        long at = System.currentTimeMillis() - 1000;
        details.payload = new JSONObject().put("id", id).put("prayerId", 1)
                .put("kind", "adhan").put("at", at).put("prayerAt", at).toString();
        return details;
    }

    private void channel(String id, int importance, Uri channelSound) {
        NotificationChannel channel = new NotificationChannel(id, "Adhan", importance);
        channel.setSound(channelSound, null);
        notifications.createNotificationChannel(channel);
    }

    private void start(NotificationDetails details) throws Exception {
        SalaTimePrayerAlarms.record(app, new JSONObject(details.payload), System.currentTimeMillis(), "on_time");
        controller = Robolectric.buildService(SalaTimeAdhanService.class).create();
        controller.get().onStartCommand(new Intent(app, SalaTimeAdhanService.class)
                .putExtra("notification", FlutterLocalNotificationsPlugin.buildGson().toJson(details)), 0, 1);
        Shadows.shadowOf(Looper.getMainLooper()).idle();
    }

    private Notification current() {
        return Shadows.shadowOf(notifications).getNotification(SalaTimeNotificationTray.PRAYER_ID);
    }

    private void assertPlaying() {
        assertEquals(1, players.size());
        assertTrue(Shadows.shadowOf(players.get(0)).isReallyPlaying());
    }

    @Test public void newAdhanReplacesTrackingAsNewAlertThenReturnsToQuietTracking() throws Exception {
        SalaTimePrayerAlarmReceiver.showSilent(app, details(12000001));
        assertEquals(NotificationCompat.PRIORITY_LOW, current().priority);
        assertTrue((current().flags & Notification.FLAG_ONLY_ALERT_ONCE) != 0);
        start(details(12000002));
        assertPlaying();
        Notification active = current();
        assertEquals(1, notifications.getActiveNotifications().length);
        assertEquals(NotificationCompat.PRIORITY_MAX, active.priority);
        assertEquals(NotificationCompat.CATEGORY_ALARM, active.category);
        assertEquals(0, active.flags & Notification.FLAG_ONLY_ALERT_ONCE);
        assertTrue((active.flags & Notification.FLAG_ONGOING_EVENT) != 0);
        assertNull(active.sound);
        if (Build.VERSION.SDK_INT >= 26) {
            assertEquals(SalaTimeAdhanPlaybackChannel.ID, active.getChannelId());
            assertEquals(Notification.GROUP_ALERT_ALL, active.getGroupAlertBehavior());
            NotificationChannel playback = notifications.getNotificationChannel(active.getChannelId());
            assertEquals(NotificationManager.IMPORTANCE_HIGH, playback.getImportance());
            assertNull(playback.getSound());
            assertFalse(playback.shouldVibrate());
            assertFalse(playback.canShowBadge());
            assertEquals(sound, notifications.getNotificationChannel(SOURCE).getSound());
        }
        if (Build.VERSION.SDK_INT >= 31) {
            // The platform has no public getter for Builder's foreground policy.
            assertTrue(org.robolectric.util.ReflectionHelpers.<Boolean>callInstanceMethod(
                    active, "shouldShowForegroundImmediately"));
        }
        Shadows.shadowOf(players.get(0)).invokeCompletionListener();
        assertEquals(NotificationCompat.PRIORITY_LOW, current().priority);
        assertEquals(NotificationCompat.CATEGORY_STATUS, current().category);
        assertTrue((current().flags & Notification.FLAG_ONLY_ALERT_ONCE) != 0);
        assertNull(current().sound);
        if (Build.VERSION.SDK_INT >= 26) {
            assertEquals(SalaTimeAdhanNotification.TRACKING_CHANNEL, current().getChannelId());
        }
    }

    @Test public void directlyDeliveredNewAdhanDoesNotInheritTrackingAlertOnce() throws Exception {
        SalaTimePrayerAlarmReceiver.showSilent(app, details(12000001));
        NotificationDetails next = details(12000002);
        next.sound = null; // Default notification sound follows the direct receiver path.
        JSONObject row = new JSONObject(FlutterLocalNotificationsPlugin.buildGson().toJson(next));
        app.getSharedPreferences(SalaTimePrayerAlarms.STORE, 0).edit()
                .putString(SalaTimePrayerAlarms.STORE, new JSONArray().put(row).toString()).commit();
        new SalaTimePrayerAlarmReceiver().onReceive(app,
                new Intent(app, SalaTimePrayerAlarmReceiver.class).putExtra("id", next.id.intValue())
                        .putExtra("at", new JSONObject(next.payload).getLong("at")));
        assertEquals(1, notifications.getActiveNotifications().length);
        assertEquals(NotificationCompat.PRIORITY_MAX, current().priority);
        assertEquals(0, current().flags & Notification.FLAG_ONLY_ALERT_ONCE);
        assertTrue(players.isEmpty());
    }

    @Test @Config(sdk = 33) public void loweredSourceIsNotPromotedIntoPlaybackChannel() throws Exception {
        channel(SOURCE, NotificationManager.IMPORTANCE_DEFAULT, sound);
        start(details(12000001));
        assertPlaying();
        assertEquals(SOURCE, current().getChannelId());
        assertEquals(NotificationManager.IMPORTANCE_DEFAULT,
                notifications.getNotificationChannel(SOURCE).getImportance());
        assertNull(notifications.getNotificationChannel(SalaTimeAdhanPlaybackChannel.ID));
    }

    @Test @Config(sdk = 33) public void mutedSourceIsNotBypassedByPlaybackChannel() throws Exception {
        channel(SOURCE, NotificationManager.IMPORTANCE_HIGH, null);
        start(details(12000001));
        assertTrue(players.isEmpty());
        assertNull(notifications.getNotificationChannel(SalaTimeAdhanPlaybackChannel.ID));
        assertEquals(SalaTimeAdhanNotification.TRACKING_CHANNEL, current().getChannelId());
    }

    @Test @Config(sdk = 33) public void disabledSourcePreventsPlaybackAndTracking() throws Exception {
        channel(SOURCE, NotificationManager.IMPORTANCE_NONE, sound);
        start(details(12000001));
        assertTrue(players.isEmpty());
        assertNull(notifications.getNotificationChannel(SalaTimeAdhanPlaybackChannel.ID));
        assertNull(current());
    }

    @Test @Config(sdk = 33) public void disabledPlaybackChannelPreventsAudioWithoutResettingUserChoice() throws Exception {
        channel(SalaTimeAdhanPlaybackChannel.ID, NotificationManager.IMPORTANCE_NONE, null);
        start(details(12000001));
        assertTrue(players.isEmpty());
        assertEquals(NotificationManager.IMPORTANCE_NONE,
                notifications.getNotificationChannel(SalaTimeAdhanPlaybackChannel.ID).getImportance());
        assertEquals("audio_muted", SalaTimePrayerAlarms.status(app).get("outcome"));
    }

    @Test @Config(sdk = 33) public void loweredPlaybackChannelKeepsItsImportanceDuringAudio() throws Exception {
        channel(SalaTimeAdhanPlaybackChannel.ID, NotificationManager.IMPORTANCE_LOW, null);
        start(details(12000001));
        assertPlaying();
        assertEquals(SalaTimeAdhanPlaybackChannel.ID, current().getChannelId());
        assertEquals(NotificationManager.IMPORTANCE_LOW,
                notifications.getNotificationChannel(SalaTimeAdhanPlaybackChannel.ID).getImportance());
    }

    @Test @Config(sdk = 33) public void userSoundOnPlaybackChannelDoesNotStartSecondSystemSound() throws Exception {
        Uri addedSound = Uri.parse("content://settings/system/notification_sound");
        channel(SalaTimeAdhanPlaybackChannel.ID, NotificationManager.IMPORTANCE_HIGH, addedSound);
        start(details(12000001));
        assertPlaying();
        assertNull(current().sound);
        assertEquals(Notification.GROUP_ALERT_SUMMARY, current().getGroupAlertBehavior());
        assertEquals(addedSound, notifications.getNotificationChannel(SalaTimeAdhanPlaybackChannel.ID).getSound());
        assertEquals(sound, notifications.getNotificationChannel(SOURCE).getSound());
    }

    @Test @Config(sdk = 33) public void disablingPlaybackChannelDuringAudioReleasesPlayer() throws Exception {
        start(details(12000001));
        assertPlaying();
        NotificationChannel playback = notifications.getNotificationChannel(SalaTimeAdhanPlaybackChannel.ID);
        playback.setImportance(NotificationManager.IMPORTANCE_NONE);
        notifications.createNotificationChannel(playback);
        Shadows.shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(250));
        assertEquals(ShadowMediaPlayer.State.END, Shadows.shadowOf(players.get(0)).getState());
        assertFalse(ShadowPowerManager.getLatestWakeLock().isHeld());
        assertTrue(Shadows.shadowOf(controller.get()).isStoppedBySelf());
        assertEquals("audio_muted", SalaTimePrayerAlarms.status(app).get("outcome"));
    }
}
