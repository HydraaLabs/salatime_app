package com.example.zabi

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import java.io.File
import java.io.InputStream
import java.io.OutputStream
import java.security.MessageDigest

/** Only audio explicitly selected by the user is copied into this private directory. */
object PersonalSoundFiles {
    const val MAX_BYTES = 20 * 1024 * 1024
    private val extensions = mapOf("audio/mpeg" to "mp3", "audio/mp4" to "m4a", "audio/aac" to "aac",
        "audio/ogg" to "ogg", "application/ogg" to "ogg", "audio/flac" to "flac", "audio/x-flac" to "flac",
        "audio/wav" to "wav", "audio/x-wav" to "wav", "audio/3gpp" to "3gp")

    internal fun copyBounded(input: InputStream, output: OutputStream): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val buffer = ByteArray(32768)
        var total = 0
        while (true) {
            val count = input.read(buffer)
            if (count < 0) break
            total += count
            require(total <= MAX_BYTES) { "sound_too_large" }
            output.write(buffer, 0, count)
            digest.update(buffer, 0, count)
        }
        require(total > 0) { "sound_invalid" }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    @JvmStatic fun isSoundUri(context: Context, value: String?): Boolean {
        if (value == null) return false
        val uri = Uri.parse(value)
        return uri.scheme == "content" && uri.authority == "${context.packageName}.personal-sounds" &&
            uri.pathSegments.size == 2 && uri.pathSegments[0] == "sounds" &&
            Regex("custom_[a-f0-9]{64}\\.(mp3|m4a|aac|ogg|flac|wav|3gp)").matches(uri.pathSegments[1])
    }

    fun importSound(context: Context, source: Uri): Map<String, String> {
        require(source.scheme == "content") { "sound_invalid" }
        val dir = File(context.filesDir, "personal_sounds").apply { mkdirs() }
        val temporary = File.createTempFile("import-", ".tmp", dir)
        try {
            val digest = context.contentResolver.openInputStream(source)!!.use { input ->
                temporary.outputStream().use { output -> copyBounded(input, output) }
            }
            val retriever = MediaMetadataRetriever()
            val mime: String?
            try {
                retriever.setDataSource(temporary.absolutePath)
                val duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0
                require(duration in 1..480000) { "sound_duration_invalid" }
                require(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO) == "yes") { "sound_invalid" }
                mime = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE)
            } finally { retriever.release() }
            val extension = extensions[mime] ?: throw IllegalArgumentException("sound_invalid")
            val id = "custom_$digest"
            val file = File(dir, "$id.$extension")
            if (!file.exists()) {
                require((dir.listFiles()?.count { it.name.startsWith("custom_") } ?: 0) < 30) { "sound_library_full" }
                check(temporary.renameTo(file)) { "sound_import_failed" }
            }
            val name = runCatching {
                context.contentResolver.query(source, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
                    if (it.moveToFirst()) it.getString(0) else null
                }
            }.getOrNull()?.replace(Regex("[\\p{Cntrl}]"), " ")?.take(100)?.ifBlank { null } ?: "Audio"
            return mapOf("key" to id, "name" to name, "path" to FileProvider.getUriForFile(context,
                "${context.packageName}.personal-sounds", file).toString())
        } finally { temporary.delete() }
    }
}
