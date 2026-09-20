package com.iamporag.wallpaper_setter

import android.app.WallpaperManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class WallpaperSetterPlugin: FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.iamporag/wallpaper")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setWallpaper" -> {
                val path = call.argument<String>("path")
                val target = call.argument<String>("target")

                if (path == null) {
                    result.error("INVALID_PATH", "Path is null", null)
                    return
                }

                try {
                    val wallpaperManager = WallpaperManager.getInstance(context)
                    val flag = when (target) {
                        "lock" -> WallpaperManager.FLAG_LOCK
                        "both" -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
                        else -> WallpaperManager.FLAG_SYSTEM
                    }

                    val display = context.resources.displayMetrics
                    val bitmap = WallpaperBitmapDecoder.decode(
                        path,
                        maxOf(display.widthPixels, wallpaperManager.desiredMinimumWidth),
                        maxOf(display.heightPixels, wallpaperManager.desiredMinimumHeight)
                    )
                    ?: return result.error("DECODE_FAILED", "Bitmap decode failed", null)
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            wallpaperManager.setBitmap(bitmap, null, true, flag)
                        } else {
                            wallpaperManager.setBitmap(bitmap)
                        }
                    } finally {
                        bitmap.recycle()
                    }

                    result.success(true)
                } catch (e: IOException) {
                    result.error("UNAVAILABLE", "Failed to set wallpaper: ${e.message}", null)
                }
            }

            "useAsImage" -> {
                val path = call.argument<String>("path")
                if (path != null) {
                    try {
                        val imageFile = File(path)
                        val uri = FileProvider.getUriForFile(
                            context,
                            context.packageName + ".fileprovider",
                            imageFile
                        )

                        val intent = Intent(Intent.ACTION_ATTACH_DATA).apply {
                            setDataAndType(uri, "image/*")
                            putExtra("mimeType", "image/*")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }

                        val chooser = Intent.createChooser(intent, "Use image as")
                        chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(chooser)

                        result.success(true)
                    } catch (e: Exception) {
                        result.error("USE_AS_FAILED", "Unable to launch use-as intent: ${e.message}", null)
                    }
                } else {
                    result.error("INVALID_PATH", "Image path is null", null)
                }
            }

            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
