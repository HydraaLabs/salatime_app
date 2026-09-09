package com.hemanthraj.fluttercompass.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class MathUtilsTest {
    @Test
    fun `non-finite sensor headings are ignored`() {
        assertNull(MathUtils.finiteAzimuthOrNull(Float.NaN))
        assertNull(MathUtils.finiteAzimuthOrNull(Float.POSITIVE_INFINITY))
        assertNull(MathUtils.finiteAzimuthOrNull(Float.NEGATIVE_INFINITY))
    }

    @Test
    fun `finite sensor headings still produce a normalized azimuth`() {
        val azimuth = MathUtils.finiteAzimuthOrNull(361f)

        assertTrue(azimuth != null)
        assertEquals(1f, azimuth!!.degrees, 0f)
    }
}
