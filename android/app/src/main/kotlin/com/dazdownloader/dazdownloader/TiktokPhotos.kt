package com.dazdownloader.dazdownloader

import org.json.JSONObject
import java.net.URI

data class PhotoSource(val urls: List<String>)
data class PhotoAlbum(val id: String, val pageUrl: String, val title: String,
    val author: String, val images: List<PhotoSource>) {
    fun catalog() = MediaCatalog(title, author, null, null,
        listOf(NativeFormat("photos-all", "photos", null, "", null)), this)
}

/** Parses only the requested post, never its cover image or recommended posts. */
object TiktokPhotos {
    const val MAX_IMAGES = 100
    private val post = Regex("^/@[^/]+/(?:photo|video)/(\\d+)/?$")
    private val script = Regex("<script\\b[^>]*\\bid=[\"']__UNIVERSAL_DATA_FOR_REHYDRATION__[\"'][^>]*>(.*?)</script>",
        setOf(RegexOption.DOT_MATCHES_ALL, RegexOption.IGNORE_CASE))
    private val canonicalMeta = Regex(
        "<(?:link|meta)\\b[^>]*?(?:rel=[\"']canonical[\"']|property=[\"']og:url[\"'])[^>]*?(?:href|content)=[\"']([^\"']+)[\"']",
        setOf(RegexOption.IGNORE_CASE))
    private val canonicalMetaReversed = Regex(
        "<(?:link|meta)\\b[^>]*?(?:href|content)=[\"']([^\"']+)[\"'][^>]*?(?:rel=[\"']canonical[\"']|property=[\"']og:url[\"'])",
        setOf(RegexOption.IGNORE_CASE))

    fun isTiktok(url: String): Boolean = runCatching {
        val host = URI(url).host.orEmpty().lowercase()
        host == "tiktok.com" || host.endsWith(".tiktok.com") || host == "www.tiktokv.com"
    }.getOrDefault(false)

    fun postId(url: String): String? = post.matchEntire(URI(url).path.orEmpty())?.groupValues?.get(1)

    fun pageUrl(url: String): String {
        val uri = URI(url)
        post.matchEntire(uri.path.orEmpty()) ?: return url
        return URI("https", "www.tiktok.com", uri.path.replace("/photo/", "/video/"), null, null).toString()
    }

    /**
     * Try to recover the canonical `/@user/photo|video/<id>` URL from a short
     * link page that only did a JS-side redirect (e.g. `tiktok.com/t/<slug>`).
     * Returns null if nothing credible is found.
     */
    fun canonical(html: String): String? {
        val candidates = (canonicalMeta.findAll(html) + canonicalMetaReversed.findAll(html))
            .map { it.groupValues[1].trim() }
            .filter { it.isNotEmpty() }
        return candidates.firstNotNullOfOrNull { href ->
            val absolute = runCatching { URI("https://www.tiktok.com/").resolve(href).toString() }.getOrNull()
            absolute?.takeIf {
                runCatching { postId(it) }.getOrNull() != null && PublicWebClient.allowedPageUrl(it)
            }
        }
    }

    fun parse(html: String, pageUrl: String): PhotoAlbum? {
        val id = postId(pageUrl) ?: throw MediaFailure("unsupported_url", "Collez le lien d’une publication TikTok individuelle.")
        val json = script.find(html)?.groupValues?.get(1)
            ?: throw MediaFailure("tiktok_access", "TikTok n’a pas fourni la publication publique. Vérifiez le lien dans un navigateur sans connexion à un compte, puis réessayez.")
        val detail = JSONObject(json).optJSONObject("__DEFAULT_SCOPE__")?.optJSONObject("webapp.video-detail")
        val item = detail?.optJSONObject("itemInfo")?.optJSONObject("itemStruct")
        if (detail == null || detail.optInt("statusCode", -1) != 0 || item == null || item.optString("id") != id ||
            item.optBoolean("privateItem") || item.optBoolean("isProhibited") || item.optBoolean("takeDown")) {
            throw MediaFailure("tiktok_access", "Cette publication TikTok n’est pas accessible publiquement ou a été supprimée.")
        }
        val imagePost = item.optJSONObject("imagePost") ?: return null // A real video, not an album.
        val images = imagePost.optJSONArray("images")
            ?: throw MediaFailure("no_photos", "TikTok n’a fourni aucune photo pour cette publication.")
        if (images.length() !in 1..MAX_IMAGES) throw MediaFailure("no_photos", "Le nombre de photos de cette publication n’est pas pris en charge (1 à $MAX_IMAGES).")
        val sources = (0 until images.length()).map { index ->
            val urls = images.optJSONObject(index)?.optJSONObject("imageURL")?.optJSONArray("urlList")
            val valid = (0 until (urls?.length() ?: 0)).mapNotNull { i ->
                urls?.optString(i)?.takeIf { PublicWebClient.allowedImageUrl(it) }
            }.distinct().take(3)
            if (valid.isEmpty()) throw MediaFailure("no_photos", "La photo ${index + 1} n’est pas accessible. Aucun carrousel incomplet ne sera enregistré.")
            PhotoSource(valid)
        }
        return PhotoAlbum(id, pageUrl, item.optString("desc").ifBlank { "TikTok $id" },
            item.optJSONObject("author")?.optString("uniqueId").orEmpty().ifBlank { "Auteur inconnu" }, sources)
    }
}
