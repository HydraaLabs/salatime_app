package com.iamporag.wallpaper_setter

import android.graphics.Bitmap
import android.graphics.BitmapFactory

/** Decode for the destination display, with a 16 MiB ARGB pixel budget. */
object WallpaperBitmapDecoder {
    const val MAX_PIXELS = 4L * 1024 * 1024

    fun sampleSize(width: Int, height: Int, targetWidth: Int, targetHeight: Int): Int {
        require(width > 0 && height > 0)
        var sample = 1
        val requestedWidth = targetWidth.coerceAtLeast(1)
        val requestedHeight = targetHeight.coerceAtLeast(1)
        while (sample <= Int.MAX_VALUE / 2 &&
            width / (sample * 2) >= requestedWidth &&
            height / (sample * 2) >= requestedHeight) {
            sample *= 2
        }
        // Round up and use Longs: malformed/very large dimensions must not
        // overflow and accidentally bypass the allocation limit.
        while (((width.toLong() + sample - 1) / sample) *
            ((height.toLong() + sample - 1) / sample) > MAX_PIXELS) {
            sample *= 2
        }
        return sample
    }

    fun decode(path: String, targetWidth: Int, targetHeight: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        val options = BitmapFactory.Options().apply {
            inSampleSize = sampleSize(bounds.outWidth, bounds.outHeight, targetWidth, targetHeight)
            inPreferredConfig = Bitmap.Config.ARGB_8888
            inScaled = false
        }
        return BitmapFactory.decodeFile(path, options)
    }
}
