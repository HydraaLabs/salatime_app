package com.dexterous.flutterlocalnotifications;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

/** Advances the three-day native window using the persisted offline reserve. */
public final class SalaTimePrayerWindowReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        try {
            SalaTimePrayerAlarms.maintainWindow(context, System.currentTimeMillis());
        } catch (Exception error) {
            Log.e("SalaTimeAlarms", "Could not renew the prayer alarm window", error);
        }
    }
}
