package com.dazdownloader.dazdownloader

import org.json.JSONObject
import java.net.URI

class MediaFailure(val code: String, override val message: String) : Exception(message)

data class NativeFormat(
    val id: String,
    val extension: String,
    val height: Int?,
    val selector: String,
    val sizeBytes: Long?,
) {
    val mimeType: String get() = when (extension) {
        "mp3" -> "audio/mpeg"
        else -> "video/mp4"
    }

    fun toMap(): Map<String, Any?> = mapOf(
        "id" to id, "extension" to extension, "height" to height,
        "sizeBytes" to sizeBytes,
    )
}

data class MediaCatalog(
    val title: String,
    val author: String,
    val duration: Double?,
    val thumbnail: String?,
    val formats: List<NativeFormat>,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "title" to title, "author" to author, "duration" to duration,
        "thumbnail" to thumbnail, "formats" to formats.map { it.toMap() },
    )

    companion object {
        // WebM is not offered: WhatsApp, iPhones and many TVs or editors
        // refuse it, and MP4 covers the same videos.
        private val videoExtensions = setOf("mp4")
        private val formatId = Regex("[a-zA-Z0-9_.-]+")

        private const val INCOMPATIBLE = 0

        /** Android reads a JSON null as "null"; the JVM's org.json as "". */
        private fun text(stream: JSONObject, key: String): String =
            if (stream.isNull(key)) "" else stream.optString(key)

        /**
         * 2 for H.264, which every phone, WhatsApp and iPhone plays; 1 when the
         * extractor does not say (Facebook's and Instagram's ready-made files,
         * H.264 in practice); 0 for VP9, AV1 and HEVC.
         */
        private fun codecRank(vcodec: String): Int = when {
            vcodec.isEmpty() -> 1
            vcodec.startsWith("avc") || vcodec.startsWith("h264") -> 2
            else -> INCOMPATIBLE
        }

        /**
         * Keeps only the streams the extractor ranks highest for language.
         * yt-dlp reports 10 for an original YouTube track, -1 for a dub and a
         * lower value for an audio description. An extractor that reports
         * nothing leaves every candidate tied, so bitrate still decides.
         */
        private fun original(candidates: List<Stream>): List<Stream> {
            val best = candidates.maxOfOrNull { it.languagePreference } ?: return candidates
            return candidates.filter { it.languagePreference == best }
        }

        fun parse(json: String): MediaCatalog {
            val data = JSONObject(json)
            if (data.has("entries") || data.optString("_type") in setOf("playlist", "multi_video")) {
                throw MediaFailure("collection", "Ce lien contient plusieurs médias. Colle le lien d’une vidéo individuelle.")
            }
            if (data.optBoolean("is_live") || data.optString("live_status") in setOf("is_live", "is_upcoming")) {
                throw MediaFailure("live", "Les directs en cours ne sont pas pris en charge. Utilise le lien du replay terminé.")
            }
            if (data.optBoolean("has_drm")) {
                throw MediaFailure("drm", "Ce média est protégé et ne peut pas être téléchargé.")
            }
            val array = data.optJSONArray("formats")
            val raw = if (array == null) listOf(data) else
                (0 until array.length()).mapNotNull { array.optJSONObject(it) }
            val streams = raw.mapIndexedNotNull { index, stream ->
                val id = stream.optString("format_id", "best")
                if (!formatId.matches(id) || stream.optBoolean("has_drm")) return@mapIndexedNotNull null
                val extension = stream.optString("ext")
                val vcodec = text(stream, "vcodec")
                val acodec = text(stream, "acodec")
                val hasVideo = vcodec != "none" && extension in videoExtensions
                val hasAudio = acodec != "none" && (hasVideo || acodec.isNotEmpty() ||
                    extension in setOf("m4a", "mp3", "aac", "opus"))
                if (stream.optString("url").isBlank() || (!hasVideo && !hasAudio)) return@mapIndexedNotNull null
                val width = stream.optInt("width").takeIf { it > 0 }
                val height = stream.optInt("height").takeIf { it > 0 }
                Stream(id, extension,
                    // A vertical 1080×1920 video is "1080p", like on the
                    // platforms themselves, not "1920p".
                    if (width != null && height != null) minOf(width, height) else height,
                    hasVideo, hasAudio,
                    stream.optLong("filesize").takeIf { it > 0 }
                        ?: stream.optLong("filesize_approx").takeIf { it > 0 },
                    stream.optDouble("tbr", 0.0).takeIf { it.isFinite() } ?: 0.0,
                    stream.optInt("language_preference", 0),
                    codecRank(vcodec), index)
            }
            // YouTube ships dubbed tracks beside the original audio. Picking
            // the loudest bitrate would hand back a translation of a video the
            // user chose in its own language, so only the track the extractor
            // ranks highest for language is ever offered.
            val audio = original(streams.filter { it.hasAudio && !it.hasVideo })
            val muxed = original(streams.filter { it.hasVideo && it.hasAudio })
            val allVideo = muxed + streams.filter { it.hasVideo && !it.hasAudio }
            // VP9, AV1 and HEVC fail on WhatsApp, iPhones, many TVs and
            // editors, as WebM did. They are only offered when a video exists
            // in nothing else.
            val videoStreams = allVideo.filter { it.codecRank > INCOMPATIBLE }.ifEmpty { allVideo }
            val videoOptions = videoStreams.mapNotNull { video ->
                val companion = if (!video.hasAudio) audio.filter {
                    it.extension in setOf("m4a", "mp4", "aac")
                }.maxByOrNull { it.bitrate } else null
                // Never offer a silent video when the sound exists, either as a
                // separate track this container cannot take or inside another
                // file (Facebook ships silent VP9 streams beside its full ones).
                if (!video.hasAudio && companion == null && (audio.isNotEmpty() || muxed.isNotEmpty()))
                    return@mapNotNull null
                val size = if (companion == null) video.size else
                    if (video.size != null && companion.size != null) video.size + companion.size else null
                val option = NativeFormat(
                    "${video.extension}-${video.height ?: "original"}", video.extension,
                    video.height, video.id + (companion?.let { "+${it.id}" } ?: ""), size)
                option to video
            }.groupBy { it.first.id }.values.map { candidates ->
                // H.264 first, then the richest stream; yt-dlp lists formats
                // from worst to best, so the later one wins a tie.
                candidates.maxWith(compareBy<Pair<NativeFormat, Stream>>(
                    { it.second.codecRank }, { it.second.bitrate }, { it.second.index })).first
            }.sortedWith(compareByDescending<NativeFormat> { it.height ?: 0 }.thenBy { it.extension })

            val bestAudio = audio.maxByOrNull { it.bitrate }
                ?: original(streams.filter { it.hasAudio }).maxByOrNull { it.bitrate }
            val options = videoOptions + listOfNotNull(bestAudio?.let {
                NativeFormat("mp3-audio", "mp3", null, it.id, null)
            })
            if (options.isEmpty()) throw MediaFailure("no_formats",
                "Aucun format vidéo ou audio accessible. Le lien peut être privé, protégé ou expiré.")
            val duration = data.optDouble("duration").takeIf { it.isFinite() && it > 0 }
            val thumbnail = data.optString("thumbnail").takeIf {
                runCatching { URI(it).scheme == "https" }.getOrDefault(false)
            }
            return MediaCatalog(
                // yt-dlp already prefers the video's own primary-language
                // metadata, so no `lang` extractor argument is passed: the
                // title must stay in the language of the pasted link.
                data.optString("title").ifBlank { "Vidéo" },
                data.optString("uploader").ifBlank { data.optString("channel").ifBlank { "Auteur inconnu" } },
                duration, thumbnail, options,
            )
        }
    }

    private data class Stream(val id: String, val extension: String, val height: Int?,
        val hasVideo: Boolean, val hasAudio: Boolean, val size: Long?, val bitrate: Double,
        val languagePreference: Int = 0, val codecRank: Int = 0, val index: Int = 0)
}

object MediaUrls {
    private val domains = setOf("youtube.com", "tiktok.com", "instagram.com",
        "snapchat.com", "x.com", "twitter.com", "facebook.com", "fb.com",
        "pinterest.com", "pinterest.fr", "threads.net", "threads.com")
    private val shortDomains = setOf("youtu.be", "fb.watch", "www.tiktokv.com", "pin.it")

    /**
     * TikTok mints /photo/ links only for image carousels. Loady downloads
     * videos, so such a link is refused with its own reason instead of
     * reaching an engine that can only call it unsupported.
     */
    fun isTiktokPhotoPost(value: String): Boolean = runCatching {
        val uri = URI(value)
        val host = uri.host?.lowercase()?.trimEnd('.').orEmpty()
        (host == "tiktok.com" || host.endsWith(".tiktok.com")) &&
            uri.path.orEmpty().contains("/photo/")
    }.getOrDefault(false)

    fun validate(value: String): String {
        val uri = runCatching { URI(value) }.getOrNull()
        val host = uri?.host?.lowercase()?.trimEnd('.')
        if (uri == null || uri.scheme != "https" || uri.userInfo != null ||
            uri.port !in setOf(-1, 443) || host == null ||
            !(host in shortDomains || domains.any { host == it || host.endsWith(".$it") })) {
            throw MediaFailure("invalid_url", "Utilise le lien d’une vidéo d’une plateforme prise en charge.")
        }
        return uri.toString()
    }
}
