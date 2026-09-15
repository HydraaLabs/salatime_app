package com.dexterous.flutterlocalnotifications;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.PowerManager;
import android.util.Log;
import android.view.KeyEvent;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import org.json.JSONObject;

/** Plays the chosen adhan once, independently of notification sound truncation.
 * No Flutter engine or permanent background service is required. */
public class SalaTimeAdhanService extends Service {
    static final String STOP = "net.salatime.app.STOP_ADHAN";
    private static final long MAX_PLAYBACK_MS = 8 * 60 * 1000L;
    private static final long CONTROL_CHECK_MS = 250;
    private static final int[] CONTROL_STREAMS = {
            AudioManager.STREAM_ALARM, AudioManager.STREAM_MUSIC,
            AudioManager.STREAM_RING, AudioManager.STREAM_NOTIFICATION
    };
    // MainActivity and Service callbacks both run on the application's main thread.
    private static SalaTimeAdhanService activeService;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final int[] initialVolumes = new int[CONTROL_STREAMS.length];
    private MediaPlayer player;
    private AudioManager audio;
    private AudioFocusRequest focus;
    private PowerManager.WakeLock wakeLock;
    private NotificationDetails details;
    private JSONObject payload;
    private boolean controlsRegistered;
    private boolean finished;
    private final BroadcastReceiver deviceStateReceiver = new BroadcastReceiver() {
        @Override public void onReceive(Context context, Intent intent) {
            if (finished) return;
            String action = intent.getAction();
            if (AudioManager.RINGER_MODE_CHANGED_ACTION.equals(action)) {
                if (isDeviceMuted(context)) finishPlayback("audio_muted");
            } else if (Intent.ACTION_SCREEN_OFF.equals(action) || Intent.ACTION_SCREEN_ON.equals(action)) {
                // Android does not dispatch the Power key to apps. Treat a new
                // sleep/wake transition as dismissal, including while locked.
                finishPlayback("audio_stopped");
            }
        }
    };
    private final Runnable checkDeviceControls = new Runnable() {
        @Override public void run() {
            if (activeService != SalaTimeAdhanService.this || finished) return;
            if (isDeviceMuted(SalaTimeAdhanService.this)) {
                finishPlayback("audio_muted");
                return;
            }
            for (int i = 0; i < CONTROL_STREAMS.length; i++) {
                if (audio.getStreamVolume(CONTROL_STREAMS[i]) != initialVolumes[i]) {
                    finishPlayback("audio_stopped");
                    return;
                }
            }
            handler.postDelayed(this, CONTROL_CHECK_MS);
        }
    };
    private final AudioManager.OnAudioFocusChangeListener focusListener = change -> {
        if (change == AudioManager.AUDIOFOCUS_LOSS || change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT) {
            finishPlayback("audio_interrupted");
        }
    };

    @Override public IBinder onBind(Intent intent) { return null; }

    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        try {
            return startPlayback(intent);
        } finally {
            // startPlayback either owns a playback wake lock or has stopped.
            SalaTimeAlarmWakeLock.complete(intent);
        }
    }

    private int startPlayback(Intent intent) {
        if (intent == null) { stopSelf(); return START_NOT_STICKY; }
        if (STOP.equals(intent.getAction())) {
            finishPlayback("audio_stopped");
            return START_NOT_STICKY;
        }
        releasePlayback();
        finished = false;
        details = null;
        payload = null;
        try {
            JSONObject row = new JSONObject(intent.getStringExtra("notification"));
            payload = SalaTimePrayerAlarms.prayer(row);
            if (payload == null) { stopSelf(); return START_NOT_STICKY; }
            details = FlutterLocalNotificationsPlugin.buildGson().fromJson(row.toString(), NotificationDetails.class);
            details.when = payload.getLong("at");
            details.showWhen = true;
            Notification base = FlutterLocalNotificationsPlugin.createNotification(this, details);
            PendingIntent stop = PendingIntent.getService(this, details.id,
                    new Intent(this, SalaTimeAdhanService.class).setAction(STOP),
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
            Notification notification = SalaTimeAdhanNotification.decorate(this, details, base)
                    .setSilent(true).setOngoing(true).setAutoCancel(false)
                    .setCategory(NotificationCompat.CATEGORY_ALARM)
                    .addAction(0, payload.optString("stopLabel", "Stop"), stop).build();
            startForeground(details.id, notification);
            SalaTimeAdhanNotificationReceiver.onPosted(this, details);

            // Re-check after service startup; Android can also delay this step.
            long startedAt = System.currentTimeMillis();
            if (!"on_time".equals(SalaTimePrayerAlarms.deliveryPolicy(payload, startedAt))) {
                SalaTimePrayerAlarms.record(this, payload, startedAt, "late_silent");
                finishPlayback("late_silent");
                return START_NOT_STICKY;
            }
            audio = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
            Uri sound = playableSound(this, details);
            if (sound == null || isDeviceMuted(this)) {
                finishPlayback("audio_muted");
                return START_NOT_STICKY;
            }
            IntentFilter controls = new IntentFilter(AudioManager.RINGER_MODE_CHANGED_ACTION);
            controls.addAction(Intent.ACTION_SCREEN_OFF);
            controls.addAction(Intent.ACTION_SCREEN_ON);
            if (Build.VERSION.SDK_INT >= 33) {
                registerReceiver(deviceStateReceiver, controls, Context.RECEIVER_NOT_EXPORTED);
            } else {
                // All three actions are protected system broadcasts. Older
                // Android versions need no application signature permission.
                registerReceiver(deviceStateReceiver, controls);
            }
            controlsRegistered = true;
            AudioAttributes attributes = new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build();
            int granted;
            if (Build.VERSION.SDK_INT >= 26) {
                focus = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                        .setAudioAttributes(attributes).setOnAudioFocusChangeListener(focusListener, handler).build();
                granted = audio.requestAudioFocus(focus);
            } else {
                granted = audio.requestAudioFocus(focusListener, AudioManager.STREAM_ALARM,
                        AudioManager.AUDIOFOCUS_GAIN_TRANSIENT);
            }
            if (granted != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                finishPlayback("audio_interrupted");
                return START_NOT_STICKY;
            }
            activeService = this;
            for (int i = 0; i < CONTROL_STREAMS.length; i++) {
                initialVolumes[i] = audio.getStreamVolume(CONTROL_STREAMS[i]);
            }
            // Public APIs only; no global key listener, hidden volume broadcast
            // or persistent background monitor. Cleanup cancels this immediately.
            handler.postDelayed(checkDeviceControls, CONTROL_CHECK_MS);
            PowerManager power = (PowerManager) getSystemService(Context.POWER_SERVICE);
            wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "SalaTime:Adhan");
            wakeLock.acquire(MAX_PLAYBACK_MS);
            MediaPlayer next = new MediaPlayer();
            player = next;
            next.setAudioAttributes(attributes);
            next.setDataSource(this, sound);
            next.setLooping(false);
            next.setOnPreparedListener(prepared -> {
                if (player != prepared) return;
                try {
                    if (!"on_time".equals(SalaTimePrayerAlarms.deliveryPolicy(payload, System.currentTimeMillis()))) {
                        SalaTimePrayerAlarms.record(this, payload, System.currentTimeMillis(), "late_silent");
                        finishPlayback("late_silent");
                        return;
                    }
                    // Preparation is asynchronous: a user may mute the phone
                    // between the alarm delivery and the first audio sample.
                    if (isDeviceMuted(this)) {
                        finishPlayback("audio_muted");
                        return;
                    }
                    prepared.start();
                    SalaTimePrayerAlarms.record(this, payload, System.currentTimeMillis(), "audio_started");
                } catch (RuntimeException error) { finishPlayback("audio_error"); }
            });
            next.setOnCompletionListener(completed -> {
                if (player == completed) finishPlayback("audio_completed");
            });
            next.setOnErrorListener((failed, what, extra) -> {
                if (player == failed) finishPlayback("audio_error");
                return true;
            });
            handler.postDelayed(() -> finishPlayback("audio_timeout"), MAX_PLAYBACK_MS);
            next.prepareAsync();
        } catch (Exception error) {
            Log.e("SalaTimeAlarms", "Adhan playback failed", error);
            finishPlayback("audio_error");
        }
        return START_NOT_STICKY;
    }

    static boolean isDeviceMuted(Context context) {
        AudioManager audio = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        return audio == null || audio.getRingerMode() != AudioManager.RINGER_MODE_NORMAL
                || audio.getStreamVolume(AudioManager.STREAM_ALARM) == 0
                || audio.getMode() != AudioManager.MODE_NORMAL;
    }

    public static boolean stopFromVolumeKey(int keyCode) {
        if (keyCode != KeyEvent.KEYCODE_VOLUME_UP && keyCode != KeyEvent.KEYCODE_VOLUME_DOWN
                && keyCode != KeyEvent.KEYCODE_VOLUME_MUTE) return false;
        SalaTimeAdhanService service = activeService;
        if (service == null || service.finished) return false;
        service.finishPlayback("audio_stopped");
        return true;
    }

    static Uri playableSound(Context context, NotificationDetails details) {
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()
                || !Boolean.TRUE.equals(details.playSound)) return null;
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationChannel channel = ((NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE))
                    .getNotificationChannel(details.channelId);
            // Respect channels muted or disabled by the user, including custom sounds.
            if (channel != null) {
                if (channel.getImportance() < NotificationManager.IMPORTANCE_DEFAULT) return null;
                return channel.getSound();
            }
        }
        if (com.example.zabi.PersonalSoundFiles.isSoundUri(context, details.sound)) return Uri.parse(details.sound);
        return com.example.zabi.BundledNotificationSounds.contains(details.sound) && !"silent".equals(details.sound)
                ? Uri.parse("android.resource://" + context.getPackageName() + "/raw/" + details.sound) : null;
    }

    private void finishPlayback(String outcome) {
        if (finished) return;
        finished = true;
        if (payload != null) {
            // Keep the delivery/start timestamp: playback duration is not an alarm delay.
            getSharedPreferences(SalaTimePrayerAlarms.DELIVERY_STORE, 0).edit().putString("outcome", outcome).apply();
        }
        releasePlayback();
        stopForeground(STOP_FOREGROUND_REMOVE);
        if (details != null) {
            try { SalaTimePrayerAlarmReceiver.showSilent(this, details); }
            catch (RuntimeException ignored) { /* Notifications may have been disabled. */ }
        }
        stopSelf();
    }

    private void releasePlayback() {
        if (activeService == this) activeService = null;
        handler.removeCallbacksAndMessages(null);
        if (controlsRegistered) {
            controlsRegistered = false;
            unregisterReceiver(deviceStateReceiver);
        }
        if (player != null) {
            MediaPlayer old = player;
            player = null;
            old.release();
        }
        if (audio != null) {
            if (Build.VERSION.SDK_INT >= 26 && focus != null) audio.abandonAudioFocusRequest(focus);
            else audio.abandonAudioFocus(focusListener);
        }
        audio = null;
        focus = null;
        if (wakeLock != null && wakeLock.isHeld()) wakeLock.release();
        wakeLock = null;
    }

    @Override public void onDestroy() {
        finished = true;
        releasePlayback();
        super.onDestroy();
    }
}
