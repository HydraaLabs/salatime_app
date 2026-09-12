package com.example.zabi

import android.app.AlarmManager
import android.app.Application
import android.app.NotificationManager
import android.os.Build
import android.service.notification.Condition
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.shadows.ShadowNotificationManager

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [29, 33], manifest = Config.NONE, application = Application::class,
    shadows = [AutomaticSilenceTest.RecordingNotificationManager::class])
class AutomaticSilenceTest {
    @Implements(NotificationManager::class)
    class RecordingNotificationManager : ShadowNotificationManager() {
        val states = mutableListOf<Pair<String, Int>>()
        @Implementation(minSdk = 29)
        protected fun setAutomaticZenRuleState(id: String, condition: Condition) {
            states.add(id to condition.state)
        }
    }

    private lateinit var app: Application
    private lateinit var n: NotificationManager
    private lateinit var alarms: AlarmManager
    private lateinit var shadow: RecordingNotificationManager
    private val at = java.time.Instant.parse("2026-09-11T12:00:00Z").toEpochMilli()

    @Before fun setup() {
        app = RuntimeEnvironment.getApplication()
        app.getSharedPreferences(AutomaticSilence.PREFS, 0).edit().clear().apply()
        app.getSharedPreferences("salatime_prayer_widget", 0).edit().clear().putString("timeZone", "UTC").apply()
        n = app.getSystemService(NotificationManager::class.java)
        alarms = app.getSystemService(AlarmManager::class.java)
        shadow = Shadows.shadowOf(n) as RecordingNotificationManager
        shadow.setNotificationPolicyAccessGranted(true)
        if (Build.VERSION.SDK_INT >= 31) org.robolectric.shadows.ShadowAlarmManager.setCanScheduleExactAlarms(true)
    }

    private fun schedule(vararg rows: Pair<Int, Long>) {
        val json = JSONArray()
        for ((id, epoch) in rows) json.put(JSONObject().put("prayerId", id).put("at", epoch))
        app.getSharedPreferences("salatime_prayer_widget", 0).edit().putString("prayers", json.toString()).apply()
    }

    private fun enable() = AutomaticSilence.configure(app,
        mapOf("enabled" to true, "delay" to 5, "duration" to 20))

    @Test fun offByDefaultAndDeniedAccessNeverCreatesARule() {
        assertEquals(false, AutomaticSilence.status(app)["enabled"])
        AutomaticSilence.refresh(app, at)
        assertTrue(n.automaticZenRules.isEmpty())
        shadow.setNotificationPolicyAccessGranted(false)
        assertThrows(IllegalStateException::class.java) { enable() }
        assertEquals(false, AutomaticSilence.status(app)["enabled"])
        assertTrue(shadow.states.isEmpty())
    }

    @Test fun activeWindowHasAnEndAlarmAndNeverWritesGlobalDndOrVolume() {
        n.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
        schedule(2 to at)
        enable()
        shadow.states.clear()
        AutomaticSilence.refresh(app, at + 5 * 60000)
        assertEquals(Condition.STATE_TRUE, shadow.states.last().second)
        assertEquals(1, Shadows.shadowOf(alarms).scheduledAlarms.size)
        assertEquals(at + 25 * 60000, Shadows.shadowOf(alarms).peekNextScheduledAlarm()!!.triggerAtTime)
        AutomaticSilence.refresh(app, at + 25 * 60000)
        assertEquals(Condition.STATE_FALSE, shadow.states.last().second)
        assertEquals(NotificationManager.INTERRUPTION_FILTER_PRIORITY, n.currentInterruptionFilter)
        assertTrue(Shadows.shadowOf(alarms).scheduledAlarms.isEmpty())
    }

    @Test fun resumeDoesNotClearManualSnoozeInsideTheSamePrayer() {
        schedule(2 to at)
        enable()
        AutomaticSilence.refresh(app, at + 6 * 60000)
        shadow.states.clear()
        // Android handles a user's snooze. SalaTime must not send a FALSE/TRUE cycle while still inside this period.
        AutomaticSilence.refresh(app, at + 7 * 60000)
        AutomaticSilence.refresh(app, at + 9 * 60000)
        assertTrue(shadow.states.isEmpty())
        AutomaticSilence.refresh(app, at + 25 * 60000)
        assertEquals(listOf(Condition.STATE_FALSE), shadow.states.map { it.second })
    }

    @Test fun disablingReleasesOnlyOurRuleAndCancelsPendingBoundary() {
        schedule(2 to System.currentTimeMillis())
        enable()
        AutomaticSilence.refresh(app, System.currentTimeMillis() + 6 * 60000)
        n.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
        AutomaticSilence.configure(app, mapOf("enabled" to false))
        assertEquals(Condition.STATE_FALSE, shadow.states.last().second)
        assertEquals(NotificationManager.INTERRUPTION_FILTER_NONE, n.currentInterruptionFilter)
        assertTrue(Shadows.shadowOf(alarms).scheduledAlarms.isEmpty())
    }

    @Test fun systemDisabledOrDeletedRuleIsNeverRecreatedOnResume() {
        schedule(2 to at)
        enable()
        val id = n.automaticZenRules.keys.single()
        val rule = n.getAutomaticZenRule(id)
        rule.isEnabled = false
        n.updateAutomaticZenRule(id, rule)
        AutomaticSilence.refresh(app, at + 10 * 60000)
        assertEquals(false, AutomaticSilence.status(app)["enabled"])
        assertFalse(n.getAutomaticZenRule(id).isEnabled)
        n.removeAutomaticZenRule(id)
        AutomaticSilence.refresh(app, at + 11 * 60000)
        assertTrue(n.automaticZenRules.isEmpty())
    }

    @Test fun fridayDurationUsesPrayerCityZoneAndOnlySelectedDhuhr() {
        schedule(1 to at, 2 to at, 3 to at)
        AutomaticSilence.configure(app, mapOf("prayers" to listOf(2), "delay" to 10,
            "duration" to 20, "fridayOverride" to true, "fridayDuration" to 60))
        assertEquals(listOf(AutomaticSilence.Window(at + 10 * 60000, at + 70 * 60000)), AutomaticSilence.windows(app))
        app.getSharedPreferences("salatime_prayer_widget", 0).edit().putString("timeZone", "Pacific/Kiritimati").apply()
        // UTC Friday noon is already Saturday in this city.
        assertEquals(listOf(AutomaticSilence.Window(at + 10 * 60000, at + 30 * 60000)), AutomaticSilence.windows(app))
    }

    @Test fun overlapsAndMidnightDoNotMomentarilyRestoreSound() {
        val windows = AutomaticSilence.mergeWindows(listOf(
            AutomaticSilence.Window(at, at + 30 * 60000),
            AutomaticSilence.Window(at + 20 * 60000, at + 50 * 60000),
            AutomaticSilence.Window(at + 50 * 60000, at + 70 * 60000)))
        assertEquals(listOf(AutomaticSilence.Window(at, at + 70 * 60000)), windows)
        assertEquals(at + 70 * 60000, AutomaticSilence.nextBoundary(windows, at + 25 * 60000))
        assertNull(AutomaticSilence.nextBoundary(windows, at + 70 * 60000))
    }

    @Test fun newPrayerAfterAMissedEndResetsOnlyTheExpiredSnooze() {
        schedule(2 to at, 3 to at + 3 * 3600000)
        enable()
        AutomaticSilence.refresh(app, at + 6 * 60000)
        shadow.states.clear()
        // Simulate the phone sleeping through the previous end and waking in the next prayer.
        AutomaticSilence.refresh(app, at + 3 * 3600000 + 6 * 60000)
        assertEquals(listOf(Condition.STATE_FALSE, Condition.STATE_TRUE), shadow.states.map { it.second })
        assertEquals(at + 3 * 3600000 + 25 * 60000, Shadows.shadowOf(alarms).peekNextScheduledAlarm()!!.triggerAtTime)
    }

    @Test fun rebootRestoresCurrentConditionAndEndBoundary() {
        schedule(2 to at)
        enable()
        AutomaticSilence.refresh(app, at + 6 * 60000)
        shadow.states.clear()
        AutomaticSilence.refresh(app, at + 7 * 60000, restore = true)
        assertEquals(Condition.STATE_TRUE, shadow.states.single().second)
        assertEquals(at + 25 * 60000, Shadows.shadowOf(alarms).peekNextScheduledAlarm()!!.triggerAtTime)
        AutomaticSilence.refresh(app, at + 30 * 60000, restore = true)
        assertEquals(Condition.STATE_FALSE, shadow.states.last().second)
    }

    @Test @Config(sdk = [33]) fun lossOfExactAccessReleasesOurRule() {
        schedule(2 to at)
        enable()
        AutomaticSilence.refresh(app, at + 6 * 60000)
        org.robolectric.shadows.ShadowAlarmManager.setCanScheduleExactAlarms(false)
        AutomaticSilence.refresh(app, at + 7 * 60000)
        assertEquals(Condition.STATE_FALSE, shadow.states.last().second)
        assertTrue(Shadows.shadowOf(alarms).scheduledAlarms.isEmpty())
        assertThrows(IllegalStateException::class.java) { enable() }
    }

    @Test @Config(sdk = [28]) fun olderAndroidStaysUsableWithoutThisOptionalFeature() {
        assertEquals(false, AutomaticSilence.status(app)["supported"])
        AutomaticSilence.refresh(app)
        assertThrows(IllegalStateException::class.java) { enable() }
    }
}
