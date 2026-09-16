package com.dexterous.flutterlocalnotifications;

import static org.junit.Assert.*;

import android.app.Application;
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
public class SalaTimeAdhanPermissionChangeTest {
    private static final String CHANNEL = "adhan_permission_change_test";
    private Application app;
    private AudioManager audio;
    private NotificationManager notifications;
    private ServiceController<SalaTimeAdhanService> controller;
    private final List<MediaPlayer> players = new ArrayList<>();

    @Before public void setup() {
        app = RuntimeEnvironment.getApplication();
        audio = (AudioManager) app.getSystemService(Context.AUDIO_SERVICE);
        notifications = (NotificationManager) app.getSystemService(Context.NOTIFICATION_SERVICE);
        audio.setMode(AudioManager.MODE_NORMAL);
        audio.setRingerMode(AudioManager.RINGER_MODE_NORMAL);
        audio.setStreamVolume(AudioManager.STREAM_ALARM, 5, 0);
        Shadows.shadowOf(audio).setNextFocusRequestResponse(AudioManager.AUDIOFOCUS_REQUEST_GRANTED);
        ShadowMediaPlayer.setCreateListener((player, shadow) -> players.add(player));
    }

    @After public void cleanup() {
        if (controller != null) controller.destroy();
        ShadowMediaPlayer.setCreateListener(null);
        PowerManager.WakeLock lock = ShadowPowerManager.getLatestWakeLock();
        if (lock != null && lock.isHeld()) lock.release();
    }

    private ShadowMediaPlayer start(int preparationMs) throws Exception {
        Uri sound = Uri.parse("android.resource://" + app.getPackageName() + "/raw/azan_2");
        ShadowMediaPlayer.addMediaInfo(DataSource.toDataSource(app, sound),
                new ShadowMediaPlayer.MediaInfo(180000, preparationMs));
        long at = System.currentTimeMillis() - 1000;
        NotificationDetails details = new NotificationDetails();
        details.id = 12000001;
        details.title = "Fajr";
        details.body = "Prayer at 05:36";
        details.icon = "@mipmap/launcher_icon";
        details.channelId = CHANNEL;
        details.channelName = "Adhan";
        details.importance = NotificationManager.IMPORTANCE_HIGH;
        details.priority = NotificationCompat.PRIORITY_HIGH;
        details.playSound = true;
        details.sound = "azan_2";
        details.style = NotificationStyle.Default;
        details.styleInformation = new DefaultStyleInformation(false, false);
        details.autoCancel = true;
        details.channelShowBadge = false;
        details.payload = new JSONObject().put("id", details.id).put("prayerId", 1)
                .put("kind", "adhan").put("at", at).put("prayerAt", at).toString();
        SalaTimePrayerAlarms.record(app, new JSONObject(details.payload), System.currentTimeMillis(), "on_time");
        controller = Robolectric.buildService(SalaTimeAdhanService.class).create();
        controller.get().onStartCommand(new Intent(app, SalaTimeAdhanService.class)
                .putExtra("notification", FlutterLocalNotificationsPlugin.buildGson().toJson(details)), 0, 1);
        Shadows.shadowOf(Looper.getMainLooper()).idle();
        assertEquals(1, players.size());
        ShadowMediaPlayer player = Shadows.shadowOf(players.get(0));
        assertEquals(preparationMs == 0, player.isReallyPlaying());
        assertTrue(ShadowPowerManager.getLatestWakeLock().isHeld());
        return player;
    }

    private void assertStopped(ShadowMediaPlayer player) {
        assertEquals(ShadowMediaPlayer.State.END, player.getState());
        assertFalse(player.isReallyPlaying());
        assertFalse(ShadowPowerManager.getLatestWakeLock().isHeld());
        assertTrue(Shadows.shadowOf(controller.get()).isStoppedBySelf());
        assertEquals("audio_muted", SalaTimePrayerAlarms.status(app).get("outcome"));
        assertEquals(5, audio.getStreamVolume(AudioManager.STREAM_ALARM));
        if (Build.VERSION.SDK_INT >= 26) {
            assertNotNull(Shadows.shadowOf(audio).getLastAbandonedAudioFocusRequest());
        } else {
            assertNotNull(Shadows.shadowOf(audio).getLastAbandonedAudioFocusListener());
        }
        assertFalse(Shadows.shadowOf(app).hasReceiverForIntent(new Intent(Intent.ACTION_SCREEN_OFF)));
    }

    @Test public void notificationsDisabledBeforePreparationCompletesNeverStartAudio() throws Exception {
        ShadowMediaPlayer player = start(100);
        Shadows.shadowOf(notifications).setNotificationsEnabled(false);
        // Complete before the first 250 ms poll: this must be checked at onPrepared.
        Shadows.shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(100));
        assertStopped(player);
    }

    @Test public void notificationsDisabledDuringPlaybackStopAndReenableDoesNotReplay() throws Exception {
        ShadowMediaPlayer player = start(0);
        Shadows.shadowOf(notifications).setNotificationsEnabled(false);
        Shadows.shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(250));
        assertStopped(player);
        Shadows.shadowOf(notifications).setNotificationsEnabled(true);
        Shadows.shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(2));
        assertStopped(player);
        assertEquals(1, players.size());
        assertNull(Shadows.shadowOf(app).getNextStartedService());
    }

    private void disableChannel() {
        NotificationChannel channel = notifications.getNotificationChannel(CHANNEL);
        channel.setImportance(NotificationManager.IMPORTANCE_NONE);
        notifications.createNotificationChannel(channel);
        assertEquals(NotificationManager.IMPORTANCE_NONE,
                notifications.getNotificationChannel(CHANNEL).getImportance());
    }

    @Test @Config(sdk = 33) public void channelDisabledBeforePreparationCompletesNeverStartsAudio() throws Exception {
        ShadowMediaPlayer player = start(100);
        disableChannel();
        Shadows.shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(100));
        assertStopped(player);
        assertEquals(0, notifications.getActiveNotifications().length);
    }

    @Test @Config(sdk = 33) public void channelDisabledDuringPlaybackStopsAudio() throws Exception {
        ShadowMediaPlayer player = start(0);
        disableChannel();
        Shadows.shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(250));
        assertStopped(player);
        assertEquals(0, notifications.getActiveNotifications().length);
    }

    @Test public void unchangedPermissionKeepsPlayingAcrossChecks() throws Exception {
        ShadowMediaPlayer player = start(0);
        Shadows.shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(2));
        assertTrue(player.isReallyPlaying());
        assertEquals(1, players.size());
        assertTrue(ShadowPowerManager.getLatestWakeLock().isHeld());
        assertEquals("audio_started", SalaTimePrayerAlarms.status(app).get("outcome"));
    }
}
