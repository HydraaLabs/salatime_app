package com.dexterous.flutterlocalnotifications;

import static org.junit.Assert.*;

import android.app.Application;
import android.app.Notification;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.media.AudioAttributes;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.PowerManager;
import android.view.KeyEvent;
import androidx.core.app.NotificationCompat;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.dexterous.flutterlocalnotifications.models.NotificationStyle;
import com.dexterous.flutterlocalnotifications.models.styles.DefaultStyleInformation;
import java.lang.reflect.Field;
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
import org.robolectric.shadows.ShadowMediaPlayer;
import org.robolectric.shadows.ShadowPowerManager;
import org.robolectric.shadows.util.DataSource;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = {24, 33}, application = Application.class)
public class SalaTimeAdhanControlsTest {
    private static final int ID = 12000031;
    private static final int[] STREAMS = {
            AudioManager.STREAM_ALARM, AudioManager.STREAM_MUSIC,
            AudioManager.STREAM_RING, AudioManager.STREAM_NOTIFICATION
    };
    private Application app;
    private AudioManager audio;
    private PowerManager power;
    private ServiceController<SalaTimeAdhanService> controller;
    private final List<MediaPlayer> players = new ArrayList<>();

    @Before public void setup() {
        app = RuntimeEnvironment.getApplication();
        audio = (AudioManager) app.getSystemService(Context.AUDIO_SERVICE);
        power = (PowerManager) app.getSystemService(Context.POWER_SERVICE);
        audio.setMode(AudioManager.MODE_NORMAL);
        audio.setRingerMode(AudioManager.RINGER_MODE_NORMAL);
        for (int stream : STREAMS) audio.setStreamVolume(stream, 4, 0);
        Shadows.shadowOf(audio).setNextFocusRequestResponse(AudioManager.AUDIOFOCUS_REQUEST_GRANTED);
        Shadows.shadowOf(power).setIsInteractive(true);
        ShadowMediaPlayer.setCreateListener((player, shadow) -> players.add(player));
        Uri sound = Uri.parse("android.resource://" + app.getPackageName() + "/raw/azan_2");
        ShadowMediaPlayer.addMediaInfo(DataSource.toDataSource(app, sound),
                new ShadowMediaPlayer.MediaInfo(180000, 0));
    }

    @After public void cleanup() {
        if (controller != null) controller.destroy();
        ShadowMediaPlayer.setCreateListener(null);
        PowerManager.WakeLock lock = ShadowPowerManager.getLatestWakeLock();
        if (lock != null && lock.isHeld()) lock.release();
    }

    private JSONObject row() throws Exception {
        long at = System.currentTimeMillis() - 1000;
        NotificationDetails details = new NotificationDetails();
        details.id = ID;
        details.title = "Fajr";
        details.body = "Prayer at 05:36";
        details.icon = "@mipmap/launcher_icon";
        details.channelId = "adhan_azan_2_no_badge_controls_v1";
        details.channelName = "Adhan";
        details.importance = NotificationManager.IMPORTANCE_HIGH;
        details.priority = NotificationCompat.PRIORITY_HIGH;
        details.playSound = true;
        details.sound = "azan_2";
        details.style = NotificationStyle.Default;
        details.styleInformation = new DefaultStyleInformation(false, false);
        details.autoCancel = true;
        details.channelShowBadge = false;
        details.payload = new JSONObject().put("id", ID).put("prayerId", 1)
                .put("kind", "adhan").put("at", at).put("prayerAt", at).toString();
        return new JSONObject(FlutterLocalNotificationsPlugin.buildGson().toJson(details));
    }

    private ShadowMediaPlayer start() throws Exception {
        players.clear();
        JSONObject row = row();
        SalaTimePrayerAlarms.record(app, SalaTimePrayerAlarms.prayer(row),
                System.currentTimeMillis(), "on_time");
        controller = Robolectric.buildService(SalaTimeAdhanService.class).create();
        controller.get().onStartCommand(new Intent(app, SalaTimeAdhanService.class)
                .putExtra("notification", row.toString()), 0, 1);
        Shadows.shadowOf(Looper.getMainLooper()).idle();
        assertEquals(SalaTimePrayerAlarms.status(app).toString(), 1, players.size());
        ShadowMediaPlayer player = Shadows.shadowOf(players.get(0));
        assertTrue(player.isReallyPlaying());
        Notification live = Shadows.shadowOf((NotificationManager)app.getSystemService(Context.NOTIFICATION_SERVICE)).getNotification(SalaTimeNotificationTray.PRAYER_ID);
        assertEquals(NotificationCompat.PRIORITY_HIGH, live.priority);
        assertEquals(NotificationCompat.CATEGORY_ALARM, live.category);
        assertTrue((live.flags & Notification.FLAG_ONGOING_EVENT) != 0);
        assertEquals(AudioAttributes.USAGE_ALARM, player.getAudioAttributes().getUsage());
        assertTrue(ShadowPowerManager.getLatestWakeLock().isHeld());
        assertNotNull(Shadows.shadowOf(audio).getLastAudioFocusRequest());
        assertTrue(controlHandler().hasMessages(0));
        assertTrue(Shadows.shadowOf(app).hasReceiverForIntent(new Intent(Intent.ACTION_SCREEN_OFF)));
        return player;
    }

    // This private Handler owns only the short control poll and playback timeout.
    // Runnable posts have what=0 on both tested SDKs, so cleanup is observable
    // without depending on private MessageQueue fields or a Robolectric scheduler.
    private Handler controlHandler() throws Exception {
        Field field = SalaTimeAdhanService.class.getDeclaredField("handler");
        field.setAccessible(true);
        return (Handler) field.get(controller.get());
    }

    private void advance(long milliseconds) {
        Shadows.shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(milliseconds));
    }

    private void assertResourcesReleased(ShadowMediaPlayer player, Handler handler) {
        assertEquals(ShadowMediaPlayer.State.END, player.getState());
        assertFalse(player.isReallyPlaying());
        assertFalse(ShadowPowerManager.getLatestWakeLock().isHeld());
        if (Build.VERSION.SDK_INT >= 26) {
            assertNotNull(Shadows.shadowOf(audio).getLastAbandonedAudioFocusRequest());
        } else {
            assertNotNull(Shadows.shadowOf(audio).getLastAbandonedAudioFocusListener());
        }
        assertFalse("Control poll and timeout must be removed", handler.hasMessages(0));
        assertFalse(Shadows.shadowOf(app).hasReceiverForIntent(new Intent(Intent.ACTION_SCREEN_OFF)));
        assertFalse(Shadows.shadowOf(app).hasReceiverForIntent(new Intent(Intent.ACTION_SCREEN_ON)));
        assertFalse(SalaTimeAdhanService.stopFromVolumeKey(KeyEvent.KEYCODE_VOLUME_UP));
    }

    private void assertStopped(ShadowMediaPlayer player, Handler handler) {
        assertResourcesReleased(player, handler);
        assertTrue(Shadows.shadowOf(controller.get()).isStoppedBySelf());
        assertEquals("audio_stopped", SalaTimePrayerAlarms.status(app).get("outcome"));
        Notification kept = Shadows.shadowOf((NotificationManager)app.getSystemService(Context.NOTIFICATION_SERVICE)).getNotification(SalaTimeNotificationTray.PRAYER_ID);
        assertEquals(NotificationCompat.PRIORITY_LOW, kept.priority);
        assertEquals(NotificationCompat.CATEGORY_STATUS, kept.category);
        if (Build.VERSION.SDK_INT >= 26) assertEquals(SalaTimeAdhanNotification.TRACKING_CHANNEL, kept.getChannelId());
    }

    private void volumeChangesStop(int stream) throws Exception {
        for (int delta : new int[] {-1, 1}) {
            for (int reset : STREAMS) audio.setStreamVolume(reset, 4, 0);
            ShadowMediaPlayer player = start();
            Handler handler = controlHandler();
            int initial = audio.getStreamVolume(stream);
            audio.setStreamVolume(stream, initial + delta, 0);
            advance(249);
            assertTrue("Playback remains normal before the 250 ms poll", player.isReallyPlaying());
            advance(1);
            assertStopped(player, handler);
            audio.setStreamVolume(stream, initial, 0);
            advance(1000);
            assertEquals(1, players.size());
            assertStopped(player, handler);
            controller.destroy();
            controller = null;
        }
    }

    @Test public void unchangedVolumesKeepPlayingAcrossControlPolls() throws Exception {
        ShadowMediaPlayer player = start();
        advance(1250);
        assertTrue(player.isReallyPlaying());
        assertTrue(ShadowPowerManager.getLatestWakeLock().isHeld());
        assertTrue(controlHandler().hasMessages(0));
        assertEquals("audio_started", SalaTimePrayerAlarms.status(app).get("outcome"));
    }

    @Test public void alarmVolumeIncreaseAndDecreaseStopWithoutReplay() throws Exception {
        volumeChangesStop(AudioManager.STREAM_ALARM);
    }

    @Test public void musicVolumeIncreaseAndDecreaseStopWithoutReplay() throws Exception {
        volumeChangesStop(AudioManager.STREAM_MUSIC);
    }

    @Test public void ringVolumeIncreaseAndDecreaseStopWithoutReplay() throws Exception {
        volumeChangesStop(AudioManager.STREAM_RING);
    }

    @Test public void notificationVolumeIncreaseAndDecreaseStopWithoutReplay() throws Exception {
        volumeChangesStop(AudioManager.STREAM_NOTIFICATION);
    }

    @Test public void eachVolumeKeyStopsImmediatelyEvenWhenAlreadyAtMaximum() throws Exception {
        for (int key : new int[] {KeyEvent.KEYCODE_VOLUME_UP, KeyEvent.KEYCODE_VOLUME_DOWN,
                KeyEvent.KEYCODE_VOLUME_MUTE}) {
            for (int stream : STREAMS) {
                audio.setStreamVolume(stream, audio.getStreamMaxVolume(stream), 0);
            }
            ShadowMediaPlayer player = start();
            Handler handler = controlHandler();
            assertTrue(SalaTimeAdhanService.stopFromVolumeKey(key));
            assertStopped(player, handler);
            for (int stream : STREAMS) {
                assertEquals(audio.getStreamMaxVolume(stream), audio.getStreamVolume(stream));
            }
            advance(1000);
            assertStopped(player, handler);
            assertEquals(1, players.size());
            controller.destroy();
            controller = null;
        }
    }

    @Test public void unrelatedKeysAndVolumeKeysWithoutAdhanAreIgnored() throws Exception {
        for (int key : new int[] {KeyEvent.KEYCODE_VOLUME_UP, KeyEvent.KEYCODE_VOLUME_DOWN,
                KeyEvent.KEYCODE_VOLUME_MUTE, KeyEvent.KEYCODE_A}) {
            assertFalse(SalaTimeAdhanService.stopFromVolumeKey(key));
        }
        ShadowMediaPlayer player = start();
        assertFalse(SalaTimeAdhanService.stopFromVolumeKey(KeyEvent.KEYCODE_A));
        assertFalse(SalaTimeAdhanService.stopFromVolumeKey(KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE));
        advance(250);
        assertTrue(player.isReallyPlaying());
    }

    @Test public void screenOffTransitionStopsPlaybackAndReleasesResources() throws Exception {
        ShadowMediaPlayer player = start();
        Handler handler = controlHandler();
        app.sendBroadcast(new Intent(Intent.ACTION_SCREEN_OFF));
        Shadows.shadowOf(Looper.getMainLooper()).idle();
        assertStopped(player, handler);
        app.sendBroadcast(new Intent(Intent.ACTION_SCREEN_ON));
        advance(1000);
        assertStopped(player, handler);
        assertEquals(1, players.size());
    }

    @Test public void screenAlreadyOffDoesNotBlockAdhanButNextScreenOnStopsIt() throws Exception {
        Shadows.shadowOf(power).setIsInteractive(false);
        assertFalse(power.isInteractive());
        ShadowMediaPlayer player = start();
        Handler handler = controlHandler();
        advance(1000);
        assertTrue(player.isReallyPlaying());
        app.sendBroadcast(new Intent(Intent.ACTION_SCREEN_ON));
        Shadows.shadowOf(Looper.getMainLooper()).idle();
        assertStopped(player, handler);
        advance(1000);
        assertEquals(1, players.size());
    }

    @Test public void explicitStopRemovesMonitoringAndTimeoutPermanently() throws Exception {
        ShadowMediaPlayer player = start();
        Handler handler = controlHandler();
        controller.get().onStartCommand(new Intent(app, SalaTimeAdhanService.class)
                .setAction(SalaTimeAdhanService.STOP), 0, 2);
        assertStopped(player, handler);
        audio.setStreamVolume(AudioManager.STREAM_MUSIC, 1, 0);
        app.sendBroadcast(new Intent(Intent.ACTION_SCREEN_OFF));
        advance(9 * 60000);
        assertStopped(player, handler);
        assertEquals(1, players.size());
    }

    @Test public void destroyingServiceRemovesMonitoringWithoutResumingAudio() throws Exception {
        ShadowMediaPlayer player = start();
        Handler handler = controlHandler();
        controller.destroy();
        controller = null;
        assertResourcesReleased(player, handler);
        audio.setStreamVolume(AudioManager.STREAM_NOTIFICATION, 1, 0);
        app.sendBroadcast(new Intent(Intent.ACTION_SCREEN_ON));
        advance(9 * 60000);
        assertResourcesReleased(player, handler);
        assertEquals(1, players.size());
        assertEquals("audio_started", SalaTimePrayerAlarms.status(app).get("outcome"));
    }
}
