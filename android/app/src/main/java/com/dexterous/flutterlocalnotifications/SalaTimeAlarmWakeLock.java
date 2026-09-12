package com.dexterous.flutterlocalnotifications;

import android.content.Context;
import android.content.ComponentName;
import android.content.Intent;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.PowerManager;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/** Keeps the CPU awake between AlarmManager's receiver and our playback service.
 * AlarmManager releases its own lock when onReceive returns. The player must
 * acquire its playback lock before this short startup lock is released.
 * https://developer.android.com/reference/android/app/AlarmManager
 */
final class SalaTimeAlarmWakeLock {
    private static final String EXTRA_TOKEN = "net.salatime.app.ADHAN_STARTUP_TOKEN";
    private static final long STARTUP_TIMEOUT_MS = 60_000L;
    private static final Handler handler = new Handler(Looper.getMainLooper());
    private static final Map<String, Startup> active = new HashMap<>();

    private SalaTimeAlarmWakeLock() {}

    static void start(Context context, Intent service) {
        String token = acquire(context);
        service.putExtra(EXTRA_TOKEN, token);
        try {
            ComponentName started = Build.VERSION.SDK_INT >= 26
                    ? context.startForegroundService(service) : context.startService(service);
            if (started == null) {
                throw new IllegalStateException("Adhan service could not be started");
            }
        } catch (RuntimeException error) {
            release(token);
            throw error;
        }
    }

    static void complete(Intent service) {
        if (service != null) release(service.getStringExtra(EXTRA_TOKEN));
    }

    private static synchronized String acquire(Context context) {
        // A delayed intent from a dead process must not release a fresh start's lock.
        final String token = UUID.randomUUID().toString();
        PowerManager power = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
        PowerManager.WakeLock lock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "SalaTime:AdhanStart");
        lock.setReferenceCounted(false);
        lock.acquire(STARTUP_TIMEOUT_MS);
        Startup startup = new Startup(lock, () -> release(token));
        active.put(token, startup);
        // The OS timeout bounds CPU use even if our process dies; the handler
        // also removes bookkeeping if a service never acknowledges startup.
        if (!handler.postDelayed(startup.timeout, STARTUP_TIMEOUT_MS)) {
            release(token);
            throw new IllegalStateException("Adhan startup timeout could not be registered");
        }
        return token;
    }

    private static synchronized void release(String token) {
        Startup startup = active.get(token);
        if (startup == null) return; // Already completed, expired, or from a prior process.
        active.remove(token);
        handler.removeCallbacks(startup.timeout);
        if (startup.lock.isHeld()) startup.lock.release();
    }

    private static final class Startup {
        final PowerManager.WakeLock lock;
        final Runnable timeout;

        Startup(PowerManager.WakeLock lock, Runnable timeout) {
            this.lock = lock;
            this.timeout = timeout;
        }
    }
}
