package com.dexterous.flutterlocalnotifications;

import static org.junit.Assert.*;

import android.app.Application;
import android.app.Notification;
import android.app.NotificationManager;
import android.content.Context;
import android.content.ContextWrapper;
import android.content.Intent;
import android.media.AudioAttributes;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Build;
import android.os.Looper;
import android.os.PowerManager;
import android.service.notification.StatusBarNotification;
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
public class SalaTimeAdhanSilenceTest {
    private static final int ID = 12000001;
    private static final int[] STREAMS = {
        AudioManager.STREAM_ALARM, AudioManager.STREAM_MUSIC,
        AudioManager.STREAM_RING, AudioManager.STREAM_NOTIFICATION,
        AudioManager.STREAM_SYSTEM, AudioManager.STREAM_VOICE_CALL,
        AudioManager.STREAM_DTMF
    };
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
        for (int stream : STREAMS) audio.setStreamVolume(stream, 4, 0);
        audio.setStreamVolume(AudioManager.STREAM_ALARM, 5, 0);
        Shadows.shadowOf(audio).setNextFocusRequestResponse(AudioManager.AUDIOFOCUS_REQUEST_GRANTED);
        ShadowMediaPlayer.setCreateListener((player, shadow) -> players.add(player));
        mediaPreparationDelay(0);
    }

    @After public void cleanup() {
        if (controller != null) controller.destroy();
        ShadowMediaPlayer.setCreateListener(null);
        PowerManager.WakeLock lock = ShadowPowerManager.getLatestWakeLock();
        if (lock != null && lock.isHeld()) lock.release();
    }

    private void mediaPreparationDelay(int delayMs) {
        Uri sound = Uri.parse("android.resource://" + app.getPackageName() + "/raw/azan_2");
        ShadowMediaPlayer.addMediaInfo(DataSource.toDataSource(app, sound),
                new ShadowMediaPlayer.MediaInfo(180000, delayMs));
    }

    private JSONObject row(long at) throws Exception {
        NotificationDetails details = new NotificationDetails();
        details.id = ID;
        details.title = "Fajr";
        details.body = "Prayer at 05:36";
        details.icon = "@mipmap/launcher_icon";
        details.channelId = "adhan_azan_2_no_badge_v1";
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

    private Intent receive(Context context) throws Exception {
        long at = System.currentTimeMillis() - 1000;
        app.getSharedPreferences(SalaTimePrayerAlarms.STORE, 0).edit()
                .putString(SalaTimePrayerAlarms.STORE, new JSONArray().put(row(at)).toString()).commit();
        new SalaTimePrayerAlarmReceiver().onReceive(context,
                new Intent(app, SalaTimePrayerAlarmReceiver.class).putExtra("id", ID).putExtra("at", at));
        return Shadows.shadowOf(app).getNextStartedService();
    }

    private void start(Intent intent) {
        controller = Robolectric.buildService(SalaTimeAdhanService.class).create();
        controller.get().onStartCommand(intent, 0, 1);
    }

    private void startDirectly() throws Exception {
        JSONObject row = row(System.currentTimeMillis() - 1000);
        SalaTimePrayerAlarms.record(app, SalaTimePrayerAlarms.prayer(row),
                System.currentTimeMillis(), "on_time");
        start(new Intent(app, SalaTimeAdhanService.class).putExtra("notification", row.toString()));
    }

    private int[] volumes() {
        int[] values = new int[STREAMS.length];
        for (int i = 0; i < STREAMS.length; i++) values[i] = audio.getStreamVolume(STREAMS[i]);
        return values;
    }

    private void assertSilentNotification() {
        StatusBarNotification[] posted = notifications.getActiveNotifications();
        assertEquals("Keep the prayer visible even when audio is muted", 1, posted.length);
        assertEquals(ID, posted[0].getId());
        Notification notification = posted[0].getNotification();
        assertNull(notification.sound);
        assertNull(notification.vibrate);
        assertEquals(0, notification.defaults & (Notification.DEFAULT_SOUND | Notification.DEFAULT_VIBRATE));
        if (Build.VERSION.SDK_INT >= 26) {
            assertFalse(notifications.getNotificationChannel(notification.getChannelId()).canShowBadge());
        }
    }

    private void assertReceiverIsSilent(Context context) throws Exception {
        int[] before = volumes();
        assertNull("A muted prayer must not start a foreground audio service", receive(context));
        assertNull(SalaTimePrayerAlarms.find(app, ID));
        assertTrue(players.isEmpty());
        assertNull(ShadowPowerManager.getLatestWakeLock());
        assertNull(Shadows.shadowOf(audio).getLastAudioFocusRequest());
        assertSilentNotification();
        assertArrayEquals(before, volumes());
    }

    private void assertDirectServiceIsSilent() throws Exception {
        int[] before = volumes();
        startDirectly();
        Shadows.shadowOf(Looper.getMainLooper()).idle();
        assertTrue("Do not allocate a player while muted", players.isEmpty());
        assertNull(ShadowPowerManager.getLatestWakeLock());
        assertNull(Shadows.shadowOf(audio).getLastAudioFocusRequest());
        assertTrue(Shadows.shadowOf(controller.get()).isStoppedBySelf());
        assertSilentNotification();
        assertArrayEquals(before, volumes());
    }

    @Test public void silentReceiverDoesNotStartAudioAndKeepsSilentNotification() throws Exception {
        audio.setRingerMode(AudioManager.RINGER_MODE_SILENT);
        assertReceiverIsSilent(app);
    }

    @Test public void vibrateReceiverDoesNotStartAudioAndKeepsSilentNotification() throws Exception {
        audio.setRingerMode(AudioManager.RINGER_MODE_VIBRATE);
        assertReceiverIsSilent(app);
    }

    @Test public void zeroAlarmVolumeReceiverDoesNotStartAudio() throws Exception {
        audio.setStreamVolume(AudioManager.STREAM_ALARM, 0, 0);
        assertReceiverIsSilent(app);
    }

    @Test public void phoneCallReceiverDoesNotStartAudio() throws Exception {
        audio.setMode(AudioManager.MODE_IN_CALL);
        assertReceiverIsSilent(app);
    }

    @Test public void communicationCallReceiverDoesNotStartAudio() throws Exception {
        audio.setMode(AudioManager.MODE_IN_COMMUNICATION);
        assertReceiverIsSilent(app);
    }

    @Test public void unavailableAudioServiceKeepsSilentNotification() throws Exception {
        Context unavailableAudio = new ContextWrapper(app) {
            @Override public Object getSystemService(String name) {
                return Context.AUDIO_SERVICE.equals(name) ? null : super.getSystemService(name);
            }
        };
        assertReceiverIsSilent(unavailableAudio);
    }

    @Test public void silentDirectServiceDoesNotCreatePlayer() throws Exception {
        audio.setRingerMode(AudioManager.RINGER_MODE_SILENT);
        assertDirectServiceIsSilent();
    }

    @Test public void vibrateDirectServiceDoesNotCreatePlayer() throws Exception {
        audio.setRingerMode(AudioManager.RINGER_MODE_VIBRATE);
        assertDirectServiceIsSilent();
    }

    @Test public void zeroAlarmVolumeDirectServiceDoesNotCreatePlayer() throws Exception {
        audio.setStreamVolume(AudioManager.STREAM_ALARM, 0, 0);
        assertDirectServiceIsSilent();
    }

    @Test public void phoneCallDirectServiceDoesNotCreatePlayer() throws Exception {
        audio.setMode(AudioManager.MODE_IN_CALL);
        assertDirectServiceIsSilent();
    }

    @Test public void normalReceiverStartsOnePlayerWithoutChangingVolumes() throws Exception {
        int[] before = volumes();
        Intent intent = receive(app);
        assertNotNull(intent);
        assertEquals(SalaTimeAdhanService.class.getName(), intent.getComponent().getClassName());
        PowerManager.WakeLock handoff = ShadowPowerManager.getLatestWakeLock();
        assertNotNull(handoff);
        assertTrue(handoff.isHeld());
        start(intent);
        Shadows.shadowOf(Looper.getMainLooper()).idle();
        assertEquals(org.robolectric.shadows.ShadowLog.getLogsForTag("SalaTimeAlarms").toString(), 1, players.size());
        ShadowMediaPlayer player = Shadows.shadowOf(players.get(0));
        assertTrue(player.isReallyPlaying());
        assertEquals(AudioAttributes.USAGE_ALARM, player.getAudioAttributes().getUsage());
        assertFalse(handoff.isHeld());
        assertTrue(ShadowPowerManager.getLatestWakeLock().isHeld());
        assertNotNull(Shadows.shadowOf(audio).getLastAudioFocusRequest());
        assertArrayEquals(before, volumes());
        player.invokeCompletionListener();
        assertReleased(player);
        assertArrayEquals(before, volumes());
    }

    private void changeRingerMode(int mode) {
        audio.setRingerMode(mode);
        app.sendBroadcast(new Intent(AudioManager.RINGER_MODE_CHANGED_ACTION)
                .putExtra(AudioManager.EXTRA_RINGER_MODE, mode));
        Shadows.shadowOf(Looper.getMainLooper()).idle();
    }

    private void assertReleased(ShadowMediaPlayer player) {
        assertEquals(ShadowMediaPlayer.State.END, player.getState());
        assertFalse(player.isReallyPlaying());
        assertFalse(ShadowPowerManager.getLatestWakeLock().isHeld());
        if (Build.VERSION.SDK_INT >= 26) {
            assertNotNull(Shadows.shadowOf(audio).getLastAbandonedAudioFocusRequest());
        } else {
            assertNotNull(Shadows.shadowOf(audio).getLastAbandonedAudioFocusListener());
        }
        assertTrue(Shadows.shadowOf(controller.get()).isStoppedBySelf());
        assertSilentNotification();
    }

    private void assertModeChangeStopsPlayback(int mode, boolean preparing) throws Exception {
        int[] before = volumes();
        if (preparing) mediaPreparationDelay(5000);
        startDirectly();
        Shadows.shadowOf(Looper.getMainLooper()).idle();
        assertEquals(org.robolectric.shadows.ShadowLog.getLogsForTag("SalaTimeAlarms").toString(), 1, players.size());
        ShadowMediaPlayer player = Shadows.shadowOf(players.get(0));
        assertEquals(!preparing, player.isReallyPlaying());
        assertTrue(ShadowPowerManager.getLatestWakeLock().isHeld());
        changeRingerMode(mode);
        assertReleased(player);
        assertArrayEquals(before, volumes());

        // Returning to normal never replays an adhan already silenced by its user.
        changeRingerMode(AudioManager.RINGER_MODE_NORMAL);
        Shadows.shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(6));
        assertEquals(org.robolectric.shadows.ShadowLog.getLogsForTag("SalaTimeAlarms").toString(), 1, players.size());
        assertReleased(player);
        assertArrayEquals(before, volumes());
        assertNull(Shadows.shadowOf(app).getNextStartedService());
    }

    @Test public void silentDuringPreparationReleasesResourcesWithoutRestart() throws Exception {
        assertModeChangeStopsPlayback(AudioManager.RINGER_MODE_SILENT, true);
    }

    @Test public void vibrateDuringPreparationReleasesResourcesWithoutRestart() throws Exception {
        assertModeChangeStopsPlayback(AudioManager.RINGER_MODE_VIBRATE, true);
    }

    @Test public void silentDuringPlaybackReleasesResourcesWithoutRestart() throws Exception {
        assertModeChangeStopsPlayback(AudioManager.RINGER_MODE_SILENT, false);
    }

    @Test public void vibrateDuringPlaybackReleasesResourcesWithoutRestart() throws Exception {
        assertModeChangeStopsPlayback(AudioManager.RINGER_MODE_VIBRATE, false);
    }

    @Test public void mutedAfterReceiverBeforeServiceReleasesHandoffWithoutPlayer() throws Exception {
        Intent intent = receive(app);
        assertNotNull(intent);
        PowerManager.WakeLock handoff = ShadowPowerManager.getLatestWakeLock();
        assertTrue(handoff.isHeld());
        audio.setRingerMode(AudioManager.RINGER_MODE_SILENT);
        int[] before = volumes();
        start(intent);
        Shadows.shadowOf(Looper.getMainLooper()).idle();
        assertTrue(players.isEmpty());
        assertFalse(handoff.isHeld());
        assertTrue(Shadows.shadowOf(controller.get()).isStoppedBySelf());
        assertSilentNotification();
        assertArrayEquals(before, volumes());
    }

    @Test public void finalPreparedCheckStaysSilentEvenWithoutRingerBroadcast() throws Exception {
        // Complete before the periodic device check, so the asynchronous
        // preparation boundary itself must reject the now-muted device.
        mediaPreparationDelay(100);
        startDirectly();
        assertEquals(org.robolectric.shadows.ShadowLog.getLogsForTag("SalaTimeAlarms").toString(), 1, players.size());
        ShadowMediaPlayer player = Shadows.shadowOf(players.get(0));
        assertFalse(player.isReallyPlaying());
        audio.setRingerMode(AudioManager.RINGER_MODE_SILENT);
        int[] before = volumes();
        Shadows.shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(100));
        assertReleased(player);
        assertArrayEquals(before, volumes());
    }
}
