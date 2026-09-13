package com.example.zabi

import android.view.KeyEvent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AdhanVolumeKeyDispatcherTest {
    @Test fun eachVolumeButtonStopsAnActiveAdhanWithoutNeedingAVolumeChange() {
        for (key in listOf(KeyEvent.KEYCODE_VOLUME_UP, KeyEvent.KEYCODE_VOLUME_DOWN, KeyEvent.KEYCODE_VOLUME_MUTE)) {
            val stopped = mutableListOf<Int>()
            val dispatcher = AdhanVolumeKeyDispatcher { stopped.add(it); true }
            // There is no stream-volume comparison: this works at max/min too.
            assertTrue(dispatcher.dispatch(KeyEvent.ACTION_DOWN, key))
            assertEquals(listOf(key), stopped)
            assertTrue(dispatcher.dispatch(KeyEvent.ACTION_UP, key))
        }
    }

    @Test fun repeatsAndMatchingReleaseStayConsumedAfterPlaybackHasStopped() {
        var active = true
        var calls = 0
        val dispatcher = AdhanVolumeKeyDispatcher {
            calls++
            active.also { active = false }
        }
        val key = KeyEvent.KEYCODE_VOLUME_DOWN
        assertTrue(dispatcher.dispatch(KeyEvent.ACTION_DOWN, key))
        assertFalse(active)
        assertTrue(dispatcher.dispatch(KeyEvent.ACTION_DOWN, key, repeatCount = 1))
        assertTrue(dispatcher.dispatch(KeyEvent.ACTION_DOWN, key, repeatCount = 8))
        assertTrue(dispatcher.dispatch(KeyEvent.ACTION_UP, key))
        assertEquals(1, calls)
        assertFalse(dispatcher.dispatch(KeyEvent.ACTION_UP, key))
        // The following complete press belongs to normal system volume again.
        assertFalse(dispatcher.dispatch(KeyEvent.ACTION_DOWN, key))
        assertFalse(dispatcher.dispatch(KeyEvent.ACTION_UP, key))
        assertEquals(2, calls)
    }

    @Test fun noAdhanLeavesOtherMediaAndSystemVolumeUntouched() {
        val dispatcher = AdhanVolumeKeyDispatcher { false }
        for (key in listOf(KeyEvent.KEYCODE_VOLUME_UP, KeyEvent.KEYCODE_VOLUME_DOWN, KeyEvent.KEYCODE_VOLUME_MUTE)) {
            assertFalse(dispatcher.dispatch(KeyEvent.ACTION_DOWN, key))
            assertFalse(dispatcher.dispatch(KeyEvent.ACTION_DOWN, key, repeatCount = 1))
            assertFalse(dispatcher.dispatch(KeyEvent.ACTION_UP, key))
        }
    }

    @Test fun otherKeysNeverAskTheAdhanServiceToStop() {
        var calls = 0
        val dispatcher = AdhanVolumeKeyDispatcher { calls++; true }
        for (key in listOf(KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_POWER, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, KeyEvent.KEYCODE_A)) {
            assertFalse(dispatcher.dispatch(KeyEvent.ACTION_DOWN, key))
            assertFalse(dispatcher.dispatch(KeyEvent.ACTION_UP, key))
        }
        assertEquals(0, calls)
    }

    @Test fun aReleaseForAnotherKeyDoesNotConsumeTheWrongSequence() {
        val dispatcher = AdhanVolumeKeyDispatcher { true }
        assertTrue(dispatcher.dispatch(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_VOLUME_DOWN))
        assertFalse(dispatcher.dispatch(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_VOLUME_UP))
        assertTrue(dispatcher.dispatch(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_VOLUME_DOWN))
    }

    @Test fun aFreshPressAfterALostReleaseIsNotCapturedWhenTheAdhanHasStopped() {
        var active = true
        val dispatcher = AdhanVolumeKeyDispatcher { active.also { active = false } }
        val key = KeyEvent.KEYCODE_VOLUME_UP
        assertTrue(dispatcher.dispatch(KeyEvent.ACTION_DOWN, key))
        // Focus changed and the old ACTION_UP was not delivered to this window.
        assertFalse(dispatcher.dispatch(KeyEvent.ACTION_DOWN, key, repeatCount = 0))
        assertFalse(dispatcher.dispatch(KeyEvent.ACTION_UP, key))
    }

    @Test fun anAlreadyHeldButtonCanStopAnAdhanThatStartsDuringThePress() {
        var active = false
        val dispatcher = AdhanVolumeKeyDispatcher { active.also { active = false } }
        val key = KeyEvent.KEYCODE_VOLUME_DOWN
        assertFalse(dispatcher.dispatch(KeyEvent.ACTION_DOWN, key))
        active = true
        assertTrue(dispatcher.dispatch(KeyEvent.ACTION_DOWN, key, repeatCount = 1))
        assertTrue(dispatcher.dispatch(KeyEvent.ACTION_UP, key))
    }
}
