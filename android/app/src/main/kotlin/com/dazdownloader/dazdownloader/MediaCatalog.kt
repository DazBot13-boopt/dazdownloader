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
        "webm" -> "video/webm"
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
    val photos: PhotoAlbum? = null,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "title" to title, "author" to author, "duration" to duration,
        "thumbnail" to thumbnail, "formats" to formats.map { it.toMap() },
        "photoCount" to (photos?.images?.size ?: 0),
    )

    companion object {
        private val videoExtensions = setOf("mp4", "webm")
        private val formatId = Regex("[a-zA-Z0-9_.-]+")

        fun parse(json: String): MediaCatalog {
            val data = JSONObject(json)
            if (data.has("entries") || data.optString("_type") in setOf("playlist", "multi_video")) {
                throw MediaFailure("collection", "Ce lien contient plusieurs médias. Collez le lien d’une vidéo individuelle.")
            }
            if (data.optBoolean("is_live") || data.optString("live_status") in setOf("is_live", "is_upcoming")) {
                throw MediaFailure("live", "Les directs en cours ne sont pas pris en charge. Utilisez le lien du replay terminé.")
            }
            if (data.optBoolean("has_drm")) {
                throw MediaFailure("drm", "Ce média est protégé et ne peut pas être téléchargé.")
            }
            val array = data.optJSONArray("formats")
            val raw = if (array == null) listOf(data) else
                (0 until array.length()).mapNotNull { array.optJSONObject(it) }
            val streams = raw.mapNotNull { stream ->
                val id = stream.optString("format_id", "best")
                if (!formatId.matches(id) || stream.optBoolean("has_drm")) return@mapNotNull null
                val extension = stream.optString("ext")
                val vcodec = stream.optString("vcodec")
                val acodec = stream.optString("acodec")
                val hasVideo = vcodec != "none" && extension in videoExtensions
                val hasAudio = acodec != "none" && (hasVideo || acodec.isNotEmpty() ||
                    extension in setOf("m4a", "mp3", "aac", "opus"))
                if (stream.optString("url").isBlank() || (!hasVideo && !hasAudio)) return@mapNotNull null
                Stream(id, extension, stream.optInt("height").takeIf { it > 0 },
                    hasVideo, hasAudio,
                    stream.optLong("filesize").takeIf { it > 0 }
                        ?: stream.optLong("filesize_approx").takeIf { it > 0 },
                    stream.optDouble("tbr", 0.0).takeIf { it.isFinite() } ?: 0.0)
            }
            val audio = streams.filter { it.hasAudio && !it.hasVideo }
            val videoOptions = streams.filter { it.hasVideo }.mapNotNull { video ->
                val companion = if (!video.hasAudio) audio.filter {
                    if (video.extension == "mp4") it.extension in setOf("m4a", "mp4", "aac")
                    else it.extension in setOf("webm", "opus")
                }.maxByOrNull { it.bitrate } else null
                // Do not offer an accidentally silent video when audio exists
                // but cannot be merged into this container without transcoding.
                if (!video.hasAudio && companion == null && audio.isNotEmpty()) return@mapNotNull null
                val size = if (companion == null) video.size else
                    if (video.size != null && companion.size != null) video.size + companion.size else null
                val option = NativeFormat(
                    "${video.extension}-${video.height ?: "original"}", video.extension,
                    video.height, video.id + (companion?.let { "+${it.id}" } ?: ""), size)
                option to video.bitrate
            }.groupBy { it.first.id }.values.map { candidates ->
                candidates.maxBy { it.second }.first
            }.sortedWith(compareByDescending<NativeFormat> { it.height ?: 0 }.thenBy { it.extension })

            val bestAudio = audio.maxByOrNull { it.bitrate }
                ?: streams.filter { it.hasAudio }.maxByOrNull { it.bitrate }
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
                data.optString("title").ifBlank { "Vidéo" },
                data.optString("uploader").ifBlank { data.optString("channel").ifBlank { "Auteur inconnu" } },
                duration, thumbnail, options,
            )
        }
    }

    private data class Stream(val id: String, val extension: String, val height: Int?,
        val hasVideo: Boolean, val hasAudio: Boolean, val size: Long?, val bitrate: Double)
}

object MediaUrls {
    private val domains = setOf("youtube.com", "tiktok.com", "instagram.com",
        "snapchat.com", "x.com", "twitter.com", "facebook.com", "fb.com")
    private val shortDomains = setOf("youtu.be", "fb.watch", "www.tiktokv.com")

    fun validate(value: String): String {
        val uri = runCatching { URI(value) }.getOrNull()
        val host = uri?.host?.lowercase()?.trimEnd('.')
        if (uri == null || uri.scheme != "https" || uri.userInfo != null ||
            uri.port !in setOf(-1, 443) || host == null ||
            !(host in shortDomains || domains.any { host == it || host.endsWith(".$it") })) {
            throw MediaFailure("invalid_url", "Utilisez un lien HTTPS d’une plateforme prise en charge.")
        }
        return uri.toString()
    }
}
