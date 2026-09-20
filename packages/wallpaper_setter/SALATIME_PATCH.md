# SalaTime Android memory patch

Vendored from the MIT-licensed `wallpaper_setter` 1.0.1 package, retaining the
upstream license, Dart interface and iOS implementation.

The Android wallpaper decoder first reads image dimensions without allocating
pixels. It then sets `BitmapFactory.Options.inSampleSize` for the display and
wallpaper manager's requested size, with a maximum of 4,194,304 ARGB pixels
(16 MiB). Decoded bitmaps are recycled after the system copies them. Invalid
images return the existing `DECODE_FAILED` result.

Native regression coverage lives in the host application's
`WallpaperBitmapDecoderTest`. Do not edit the shared pub cache.
