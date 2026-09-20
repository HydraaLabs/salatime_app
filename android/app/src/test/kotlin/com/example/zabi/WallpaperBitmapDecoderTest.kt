package com.example.zabi

import android.app.Application
import android.graphics.Bitmap
import com.iamporag.wallpaper_setter.WallpaperBitmapDecoder
import java.io.File
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class WallpaperBitmapDecoderTest {
    @get:Rule val temporary = TemporaryFolder()

    @Test fun samplesLargePhotoForTheDestinationWithoutUpscaling() {
        assertEquals(4, WallpaperBitmapDecoder.sampleSize(6000, 4000, 1500, 1000))
        assertEquals(1, WallpaperBitmapDecoder.sampleSize(320, 200, 1080, 2400))
    }

    @Test fun capsAllocationEvenForHugeOrExtremeAspectRatioImages() {
        for ((width, height) in listOf(12000 to 12000, Int.MAX_VALUE to Int.MAX_VALUE,
            65536 to 128, 128 to 65536)) {
            val sample = WallpaperBitmapDecoder.sampleSize(width, height, width, height)
            assertTrue(sample > 0 && sample and (sample - 1) == 0)
            val pixels = ((width.toLong() + sample - 1) / sample) *
                ((height.toLong() + sample - 1) / sample)
            assertTrue(pixels <= WallpaperBitmapDecoder.MAX_PIXELS)
        }
    }

    @Test fun decodesARealImageAtReducedResolution() {
        val file = temporary.newFile("wallpaper.png")
        val original = Bitmap.createBitmap(1000, 800, Bitmap.Config.ARGB_8888)
        file.outputStream().use { original.compress(Bitmap.CompressFormat.PNG, 100, it) }
        original.recycle()
        val decoded = WallpaperBitmapDecoder.decode(file.path, 200, 160)!!
        try {
            assertEquals(250, decoded.width)
            assertEquals(200, decoded.height)
            assertTrue(decoded.allocationByteCount <= 250 * 200 * 4)
        } finally { decoded.recycle() }
    }

    @Test fun invalidImageDoesNotAllocateABitmap() {
        val file = temporary.newFile("broken.png")
        file.writeText("not an image")
        assertNull(WallpaperBitmapDecoder.decode(file.path, 1080, 2400))
        assertNull(WallpaperBitmapDecoder.decode(File(temporary.root, "missing").path, 1080, 2400))
    }
}
