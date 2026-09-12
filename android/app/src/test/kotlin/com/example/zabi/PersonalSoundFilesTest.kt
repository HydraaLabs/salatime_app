package com.example.zabi

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.OutputStream
import java.io.File
import androidx.core.content.FileProvider
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class PersonalSoundFilesTest {
    @Test fun copiesWithoutChangingTheAudioAndUsesStableIdentity() {
        val output = ByteArrayOutputStream()
        val hash = PersonalSoundFiles.copyBounded(ByteArrayInputStream("abc".toByteArray()), output)
        assertEquals("abc", output.toString())
        assertEquals("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", hash)
    }
    @Test fun rejectsEmptyAndOversizedStreams() {
        val sink = object : OutputStream() { override fun write(value: Int) {} }
        for (size in listOf(0, PersonalSoundFiles.MAX_BYTES + 1)) {
            try {
                PersonalSoundFiles.copyBounded(ByteArrayInputStream(ByteArray(size)), sink)
                fail("Expected invalid audio size to be rejected")
            } catch (error: IllegalArgumentException) {
                assertEquals(if (size == 0) "sound_invalid" else "sound_too_large", error.message)
            }
        }
    }
    @Test fun onlyTheDedicatedPrivateProviderCanSupplyAudio() {
        val context = RuntimeEnvironment.getApplication()
        val key = "custom_" + "a".repeat(64) + ".mp3"
        val root = "content://${context.packageName}.personal-sounds"
        assertTrue(PersonalSoundFiles.isSoundUri(context, "$root/sounds/$key"))
        for (uri in listOf("content://foreign/sounds/$key", "$root/other/$key", "$root/sounds/../$key", "file:///sounds/$key", "$root/sounds/recording.mp3")) {
            assertFalse(uri, PersonalSoundFiles.isSoundUri(context, uri))
        }
    }

    @Test fun retainedAudioCanBeOpenedThroughItsOwnProvider() {
        val context = RuntimeEnvironment.getApplication()
        val dir = File(context.filesDir, "personal_sounds").apply { mkdirs() }
        val file = File(dir, "custom_${"b".repeat(64)}.mp3").apply { writeText("retained-audio") }
        try {
            val authority = "${context.packageName}.personal-sounds"
            val provider = context.packageManager.resolveContentProvider(authority, 0)!!
            val imageProvider = context.packageManager.resolveContentProvider("${context.packageName}.fileprovider", 0)!!
            assertNotEquals(imageProvider.name, provider.name)
            val uri = FileProvider.getUriForFile(context, authority, file)
            val restored = context.contentResolver.openInputStream(uri)!!.use { it.readBytes().decodeToString() }
            assertEquals("retained-audio", restored)
        } finally { file.delete() }
    }
}
