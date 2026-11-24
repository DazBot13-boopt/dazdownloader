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

    /** A format as yt-dlp reports it; a null codec or size is a JSON null. */
    private fun raw(id: String, vcodec: String?, acodec: String?, width: Int? = null,
        height: Int? = null, bitrate: Double? = null, ext: String = "mp4"): JSONObject = JSONObject().apply {
        put("format_id", id)
        put("url", "https://cdn.example.com/$id")
        put("ext", ext)
        put("vcodec", vcodec ?: JSONObject.NULL)
        put("acodec", acodec ?: JSONObject.NULL)
        put("width", width ?: JSONObject.NULL)
        put("height", height ?: JSONObject.NULL)
        put("tbr", bitrate ?: JSONObject.NULL)
    }

    @Test fun facebookReelNeverOffersItsSilentStreams() {
        // Facebook reel 1195289147628387: two complete files without a size,
        // and VP9 video-only streams with no audio track anywhere.
        val result = MediaCatalog.parse(metadata(
            raw("sd", null, null), raw("hd", null, null),
            raw("1417507216490308v", "vp09.00.21.08", "none", 360, 636, 235.5),
            raw("1417507223156974v", "vp09.00.30.08", "none", 480, 848, 522.4)))
        assertEquals(listOf("mp4-original", "mp3-audio"), result.formats.map { it.id })
        assertEquals("hd", result.formats.first().selector)
    }

    @Test fun pinterestTrustsTheH264StreamsOverMislabelledOnes() {
        // Pinterest pin 1084663891475263837: V_EXP claims 640×1138 but is a
        // 540×960 file; the HLS variants are H.264 with audio.
        val result = MediaCatalog.parse(metadata(
            raw("V_HLSV3_MOBILE-485", "avc1.4d4020", "mp4a.40.5", 240, 424, 485.8),
            raw("V_HLSV3_MOBILE-736", "avc1.4d4020", "mp4a.40.5", 360, 640, 736.7),
            raw("V_HLSV3_MOBILE-1004", "avc1.4d4020", "mp4a.40.5", 480, 852, 1004.0),
            raw("V_EXP3", null, null, 640, 1138), raw("V_EXP7", null, null, 640, 1138),
            raw("V_HLSV3_MOBILE-1374", "avc1.4d4020", "mp4a.40.5", 640, 1136, 1374.2)))
        assertEquals(listOf("mp4-640", "mp4-480", "mp4-360", "mp4-240", "mp3-audio"),
            result.formats.map { it.id })
        assertEquals("V_HLSV3_MOBILE-1374", result.formats.first().selector)
    }

    @Test fun instagramPrefersItsReadyMadeFileOverVp9() {
        // Instagram reel Dfraerag-Ty: VP9-only DASH video and ready-made
        // files whose codec and size are not reported.
        val result = MediaCatalog.parse(metadata(
            raw("dash-a", "none", "mp4a.40.5", bitrate = 61.3, ext = "m4a"),
            raw("1", null, null), raw("2", null, null), raw("3", null, null),
            raw("dash-v540", "vp09.00.30.08", "none", 540, 960, 117.5),
            raw("dash-v1080", "vp09.00.40.08", "none", 1080, 1920, 1392.8)))
        assertEquals(listOf("mp4-original", "mp3-audio"), result.formats.map { it.id })
        assertEquals("3", result.formats.first().selector)
    }

    @Test fun aVerticalVideoIsNamedAfterItsShortSide() {
        val result = MediaCatalog.parse(metadata(
            raw("v", "avc1.64001f", "mp4a.40.2", 1080, 1920, 2000.0)))
        assertEquals("mp4-1080", result.formats.first().id)
        assertEquals(1080, result.formats.first().height)
    }

    @Test fun h264WinsOverVp9AndHevcAtTheSameResolution() {
        val result = MediaCatalog.parse(metadata(
            raw("hevc", "hvc1.1.6.L120", "mp4a.40.2", 1080, 1920, 3000.0),
            raw("vp9", "vp09.00.40.08", "mp4a.40.2", 1080, 1920, 2500.0),
            raw("h264", "avc1.64001f", "mp4a.40.2", 1080, 1920, 1500.0)))
        assertEquals(listOf("mp4-1080", "mp3-audio"), result.formats.map { it.id })
        assertEquals("h264", result.formats.first().selector)
    }

    @Test fun resolutionsOnlyInVp9OrAv1AreDroppedWhenH264Exists() {
        val result = MediaCatalog.parse(metadata(
            raw("401", "av01.0.12M.08", "none", 3840, 2160, 9000.0),
            raw("137", "avc1.640028", "none", 1920, 1080, 4000.0),
            raw("140", "none", "mp4a.40.2", bitrate = 128.0, ext = "m4a")))
        assertEquals(listOf("mp4-1080", "mp3-audio"), result.formats.map { it.id })
    }

    @Test fun vp9IsStillOfferedWhenItIsTheOnlyVideo() {
        val result = MediaCatalog.parse(metadata(
            raw("vp9", "vp09.00.40.08", "none", 1080, 1920, 1000.0),
            raw("aac", "none", "mp4a.40.2", bitrate = 128.0, ext = "m4a")))
        assertEquals(listOf("mp4-1080", "mp3-audio"), result.formats.map { it.id })
        assertEquals("vp9+aac", result.formats.first().selector)
    }

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

    @Test fun webmIsNeverOffered() {
        val result = MediaCatalog.parse(metadata(
            stream("313", ext = "webm", height = 2160, audio = false),
            stream("137", height = 1080, audio = false, size = 1000),
            stream("251", ext = "webm", height = 0, video = false),
            stream("140", ext = "m4a", height = 0, video = false, size = 200)))
        assertEquals(listOf("mp4-1080", "mp3-audio"), result.formats.map { it.id })
        assertEquals("137+140", result.formats.first().selector)
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
            stream("137", height = 1080, audio = false),
            stream("140-described", ext = "m4a", height = 0, video = false,
                bitrate = 2000, language = -10),
            stream("140-original", ext = "m4a", height = 0, video = false,
                bitrate = 120, language = 10)))
        assertEquals("137+140-original", result.formats.first().selector)
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

    @Test fun tiktokPhotoLinksAreRefusedBeforeTheEngineStarts() {
        // Loady downloads videos. TikTok mints /photo/ only for carousels, and
        // yt-dlp answers nothing but "Unsupported URL" for them.
        for (url in listOf("https://www.tiktok.com/@a/photo/123",
            "https://tiktok.com/@a/photo/123?lang=fr",
            "https://m.tiktok.com/@a/photo/123")) {
            assertTrue(url, MediaUrls.isTiktokPhotoPost(url))
        }
        for (url in listOf("https://www.tiktok.com/@a/video/123",
            "https://vm.tiktok.com/abc", "https://www.youtube.com/watch?v=photo",
            "https://photo.example.com/@a/photo/1", "not a url")) {
            assertFalse(url, MediaUrls.isTiktokPhotoPost(url))
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
