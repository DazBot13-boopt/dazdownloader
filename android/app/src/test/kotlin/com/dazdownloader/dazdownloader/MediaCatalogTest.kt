package com.dazdownloader.dazdownloader

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import java.io.File

class MediaCatalogTest {
    private fun stream(id: String, ext: String = "mp4", height: Int = 720,
        video: Boolean = true, audio: Boolean = true, size: Long? = null,
        bitrate: Int = 1000, drm: Boolean = false, language: Int? = null): JSONObject = JSONObject().apply {
        put("format_id", id)
        put("url", "https://cdn.example.com/$id")
        put("ext", ext)
        put("height", height)
        put("vcodec", if (video) "avc1" else "none")
        put("acodec", if (audio) "aac" else "none")
        put("tbr", bitrate)
        put("has_drm", drm)
        if (size != null) put("filesize", size)
        if (language != null) put("language_preference", language)
    }

    private fun metadata(vararg formats: JSONObject): String = JSONObject().apply {
        put("title", "Video")
        put("duration", 60)
        put("uploader", "Author")
        put("formats", JSONArray(formats.toList()))
    }.toString()

    @Test fun progressiveVideoOffersItsActualResolutionAndAudio() {
        val result = MediaCatalog.parse(metadata(stream("18", height = 360)))
        assertEquals(listOf("mp4-360", "mp3-audio"), result.formats.map { it.id })
        assertEquals("18", result.formats.first().selector)
        assertNull(result.formats.last().sizeBytes)
    }

    @Test fun dashVideoIsPairedWithCompatibleAudio() {
        val result = MediaCatalog.parse(metadata(
            stream("137", height = 1080, audio = false, size = 1000),
            stream("140", ext = "m4a", height = 0, video = false, size = 200)))
        assertEquals("137+140", result.formats.first().selector)
        assertEquals(1200L, result.formats.first().sizeBytes)
    }

    @Test fun webmKeepsWebmAudioAndSupports4k() {
        val result = MediaCatalog.parse(metadata(
            stream("313", ext = "webm", height = 2160, audio = false),
            stream("251", ext = "webm", height = 0, video = false)))
        assertEquals("313+251", result.formats.first().selector)
        assertEquals(2160, result.formats.first().height)
        assertNull(result.formats.first().sizeBytes)
    }

    @Test fun aDubbedTrackNeverReplacesTheOriginalAudio() {
        val result = MediaCatalog.parse(metadata(
            stream("137", height = 1080, audio = false, size = 1000),
            // The dub is the louder track, so bitrate alone would pick it.
            stream("140-dub", ext = "m4a", height = 0, video = false, size = 400,
                bitrate = 900, language = -1),
            stream("140-original", ext = "m4a", height = 0, video = false, size = 200,
                bitrate = 100, language = 10)))
        assertEquals("137+140-original", result.formats.first().selector)
        assertEquals(1200L, result.formats.first().sizeBytes)
        assertEquals("140-original", result.formats.last().selector)
    }

    @Test fun audioDescriptionIsNotMistakenForTheOriginalTrack() {
        val result = MediaCatalog.parse(metadata(
            stream("313", ext = "webm", height = 2160, audio = false),
            stream("251-described", ext = "webm", height = 0, video = false,
                bitrate = 2000, language = -10),
            stream("251-original", ext = "webm", height = 0, video = false,
                bitrate = 120, language = 10)))
        assertEquals("313+251-original", result.formats.first().selector)
    }

    @Test fun duplicateResolutionsSelectTheBestAvailableStream() {
        val result = MediaCatalog.parse(metadata(
            stream("low", bitrate = 100), stream("high", bitrate = 2000)))
        assertEquals(1, result.formats.count { it.id == "mp4-720" })
        assertEquals("high", result.formats.first().selector)
    }

    @Test fun genuinelySilentVideoDoesNotInventAnAudioOption() {
        val result = MediaCatalog.parse(metadata(stream("silent", audio = false)))
        assertEquals(listOf("mp4-720"), result.formats.map { it.id })
    }

    @Test fun incompatibleAudioDoesNotProduceAnAccidentallySilentVideo() {
        val result = MediaCatalog.parse(metadata(stream("video", audio = false),
            stream("audio", ext = "webm", video = false)))
        assertEquals(listOf("mp3-audio"), result.formats.map { it.id })
    }

    @Test fun drmFormatsAndSelectorInjectionAreNotOffered() {
        val result = MediaCatalog.parse(metadata(stream("safe"),
            stream("bad+best", height = 1080), stream("protected", height = 2160, drm = true)))
        assertEquals(listOf("mp4-720", "mp3-audio"), result.formats.map { it.id })
    }

    @Test fun emptyFormatListFailsInsteadOfInventingAnMp4() {
        val error = assertThrows(MediaFailure::class.java) { MediaCatalog.parse(metadata()) }
        assertEquals("no_formats", error.code)
    }

    @Test fun collectionsLiveAndDrmFailExplicitly() {
        for ((field, value, code) in listOf(
            Triple("_type", "playlist", "collection"),
            Triple("is_live", true, "live"),
            Triple("live_status", "is_upcoming", "live"),
            Triple("has_drm", true, "drm"))) {
            val json = JSONObject(metadata(stream("18"))).put(field, value).toString()
            assertEquals(code, assertThrows(MediaFailure::class.java) { MediaCatalog.parse(json) }.code)
        }
    }

    @Test fun finishedReplayIsAllowed() {
        val json = JSONObject(metadata(stream("18"))).put("live_status", "was_live").toString()
        assertTrue(MediaCatalog.parse(json).formats.isNotEmpty())
    }

    @Test fun onlyHttpsUrlsOfTheSixPlatformsAreAccepted() {
        for (url in listOf("https://youtu.be/abc", "https://m.youtube.com/watch?v=abc",
            "https://vm.tiktok.com/abc", "https://instagram.com/reel/abc",
            "https://snapchat.com/spotlight/abc", "https://x.com/a/status/1",
            "https://fb.watch/abc")) assertEquals(url, MediaUrls.validate(url))
        for (url in listOf("file:///tmp/a", "https://youtube.com.evil.example/a",
            "https://evilyoutube.com/a", "https://user:password@youtube.com/a",
            "https://youtube.com:9000/a", "http://youtube.com/a", "--exec=bad")) {
            assertThrows(MediaFailure::class.java) { MediaUrls.validate(url) }
        }
    }

    @Test fun cancellationCannotOverrideAnAlreadyPublishedFile() {
        val task = MediaTask("external-id;not-a-process-id")
        assertTrue(task.processId.matches(Regex("[0-9a-f-]+")))
        assertEquals(42, task.commit { 42 })
        assertFalse(task.cancel())
        task.checkActive()
    }

    @Test fun cancelledTaskCannotPublish() {
        val task = MediaTask("id")
        assertTrue(task.cancel())
        val error = assertThrows(MediaFailure::class.java) { task.commit { 42 } }
        assertEquals("cancelled", error.code)
    }

    @Test fun fileNamesCannotTraverseDirectories() {
        val title = MediaFiles.safeTitle("../../a\\b\u0000:*?\"<>|")
        assertFalse(title.contains('/'))
        assertFalse(title.contains('\\'))
        assertFalse(title.contains('\u0000'))
        assertFalse(title.startsWith('.'))
        assertEquals("video", MediaFiles.safeTitle("..."))
    }

    @Test fun mediaHeaderValidationRejectsHtmlAndEmptyDownloads() {
        val file = File.createTempFile("daz-media-test", ".tmp")
        try {
            file.writeText("<html>Access denied</html>")
            assertThrows(MediaFailure::class.java) { MediaFiles.validate(file, "mp4") }
            file.writeBytes(byteArrayOf(0, 0, 0, 24) + "ftypisom".toByteArray())
            MediaFiles.validate(file, "mp4")
            file.writeText("")
            assertThrows(MediaFailure::class.java) { MediaFiles.validate(file, "mp4") }
            file.writeBytes("ID3test".toByteArray())
            MediaFiles.validate(file, "mp3")
            file.writeBytes(byteArrayOf(0x1a, 0x45, 0xdf.toByte(), 0xa3.toByte()))
            MediaFiles.validate(file, "webm")
        } finally {
            file.delete()
        }
    }
}
