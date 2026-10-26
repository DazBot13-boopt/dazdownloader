package com.dazdownloader.dazdownloader

import java.io.ByteArrayOutputStream
import java.io.File
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URI

/** Bounded, HTTPS-only public requests. No account cookies, proxy or third-party service. */
class PublicWebClient(private val task: MediaTask) {
    data class Page(val url: String, val html: String)

    fun page(url: String): Page {
        val connection = connect(url, ::allowedPageUrl, PAGE_ACCEPT)
        try {
            val output = ByteArrayOutputStream()
            read(connection, output, 4L * 1024 * 1024)
            return Page(connection.url.toString(), output.toString("UTF-8"))
        } finally { connection.disconnect() }
    }

    fun image(url: String, destination: File): Long {
        val connection = connect(url, ::allowedImageUrl, IMAGE_ACCEPT)
        try {
            if (connection.contentType?.substringBefore(';')?.lowercase() !in setOf(
                    "image/jpeg", "image/png", "image/webp", "application/octet-stream")) {
                throw MediaFailure("invalid_file", "TikTok a renvoyé autre chose qu’une photo.")
            }
            destination.outputStream().use { read(connection, it, 30L * 1024 * 1024) }
            return destination.length()
        } finally { connection.disconnect() }
    }

    private fun connect(initial: String, allowed: (String) -> Boolean, accept: String): HttpURLConnection {
        var url = initial
        repeat(6) {
            task.checkActive()
            if (!allowed(url)) throw MediaFailure("unsafe_redirect", "La plateforme a redirigé vers une adresse non autorisée.")
            val connection = URI(url).toURL().openConnection() as HttpURLConnection
            try {
                connection.instanceFollowRedirects = false
                connection.connectTimeout = 15_000
                connection.readTimeout = 15_000
                connection.setRequestProperty("User-Agent", USER_AGENT)
                connection.setRequestProperty("Accept", accept)
                connection.setRequestProperty("Accept-Language", "en-US,en;q=0.9")
                connection.setRequestProperty("Referer", "https://www.tiktok.com/")
                val code = connection.responseCode
                task.checkActive()
                if (code in setOf(301, 302, 303, 307, 308)) {
                    val location = connection.getHeaderField("Location")
                        ?: throw MediaFailure("network", "Redirection TikTok incomplète.")
                    url = URI(url).resolve(location).toString()
                    connection.disconnect()
                } else {
                    if (code != 200) throw MediaFailure("tiktok_http", "TikTok a refusé l’accès (HTTP $code). Le lien peut être expiré ou temporairement limité.")
                    return connection
                }
            } catch (error: Exception) {
                connection.disconnect()
                throw error
            }
        }
        throw MediaFailure("network", "Trop de redirections TikTok.")
    }

    private fun read(connection: HttpURLConnection, output: OutputStream, maxBytes: Long) {
        if (connection.contentLengthLong > maxBytes) throw MediaFailure("too_large", "Le fichier dépasse la limite de taille autorisée.")
        var total = 0L
        connection.inputStream.use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                task.checkActive()
                val count = input.read(buffer)
                if (count < 0) break
                total += count
                if (total > maxBytes) throw MediaFailure("too_large", "Le fichier dépasse la limite de taille autorisée.")
                output.write(buffer, 0, count)
            }
        }
        task.checkActive()
    }

    companion object {
        // TikTok only server-renders a post's data for desktop browsers. A
        // mobile user agent is answered with a lighter shell carrying no post
        // data, so every photo link fell through to yt-dlp — which has no
        // TikTok photo support and could only answer "Unsupported URL".
        const val USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
        // AVIF is deliberately left out: the saved file must stay one of the
        // three formats the album validator and MediaStore publication accept.
        private const val IMAGE_ACCEPT = "image/webp,image/jpeg,image/png,*/*;q=0.8"
        private const val PAGE_ACCEPT = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        private fun allowed(url: String, domains: Set<String>): Boolean = runCatching {
            val uri = URI(url)
            val host = uri.host.orEmpty().lowercase()
            uri.scheme == "https" && uri.userInfo == null && uri.port in setOf(-1, 443) &&
                domains.any { host == it || host.endsWith(".$it") }
        }.getOrDefault(false)
        fun allowedPageUrl(url: String) = allowed(url, setOf("tiktok.com", "tiktokv.com"))
        fun allowedImageUrl(url: String) = allowed(url, setOf("tiktokcdn.com", "tiktokcdn-eu.com", "tiktokcdn-us.com", "byteimg.com", "ibytedtos.com"))
    }
}
