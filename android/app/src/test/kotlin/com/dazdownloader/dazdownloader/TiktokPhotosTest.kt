package com.dazdownloader.dazdownloader

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class TiktokPhotosTest {
    private val url = "https://www.tiktok.com/@author/video/123456"
    private fun image(id: Int) = JSONObject().put("imageURL", JSONObject().put("urlList",
        JSONArray(listOf("https://p16-common-sign.tiktokcdn-eu.com/photo$id.jpeg?signature=test"))))
    private fun item() = JSONObject().put("id", "123456").put("desc", "A carousel")
        .put("author", JSONObject().put("uniqueId", "author"))
        .put("imagePost", JSONObject().put("images", JSONArray(listOf(image(1), image(2)))))
    private fun html(item: JSONObject = item(), status: Int = 0): String {
        val data = JSONObject().put("__DEFAULT_SCOPE__", JSONObject().put("webapp.video-detail",
            JSONObject().put("statusCode", status).put("itemInfo", JSONObject().put("itemStruct", item))))
        return "<script type='application/json' id='__UNIVERSAL_DATA_FOR_REHYDRATION__'>$data</script>"
    }

    @Test fun albumContainsAllPhotosInOrderAndNoFakeVideoFormats() {
        val album = TiktokPhotos.parse(html(), url)!!
        assertEquals(2, album.images.size)
        assertTrue(album.images[0].urls.single().contains("photo1.jpeg"))
        assertTrue(album.images[1].urls.single().contains("photo2.jpeg"))
        assertEquals("author", album.author)
        assertEquals(listOf("photos"), album.catalog().formats.map { it.extension })
        assertEquals(2, album.catalog().toMap()["photoCount"])
        assertFalse(album.catalog().toMap().toString().contains("signature"))
    }

    @Test fun videoIsNotMistakenForAnAlbumOrCoverPhoto() {
        val video = item().apply {
            remove("imagePost")
            put("video", JSONObject().put("cover", "https://p16.tiktokcdn.com/cover.jpg"))
        }
        assertNull(TiktokPhotos.parse(html(video), url))
    }

    @Test fun missingOrPrivateOrMismatchedPostsFail() {
        for (bad in listOf(item().put("id", "other"), item().put("privateItem", true), item().put("takeDown", true))) {
            assertEquals("tiktok_access", assertThrows(MediaFailure::class.java) { TiktokPhotos.parse(html(bad), url) }.code)
        }
        assertThrows(MediaFailure::class.java) { TiktokPhotos.parse(html(status = 10204), url) }
        assertThrows(MediaFailure::class.java) { TiktokPhotos.parse("<html>login</html>", url) }
    }

    @Test fun rejectsPartialAlbumInsteadOfDroppingAnUnavailablePhoto() {
        val broken = item().put("imagePost", JSONObject().put("images", JSONArray(listOf(image(1), JSONObject()))))
        assertEquals("no_photos", assertThrows(MediaFailure::class.java) { TiktokPhotos.parse(html(broken), url) }.code)
    }

    @Test fun rejectsEmptyOrOversizedAlbums() {
        for (count in listOf(0, 101)) {
            val bad = item().put("imagePost", JSONObject().put("images", JSONArray((0 until count).map(::image))))
            assertThrows(MediaFailure::class.java) { TiktokPhotos.parse(html(bad), url) }
        }
    }

    @Test fun usesVideoPageForPhotoHydrationWithoutTrackingQuery() {
        assertEquals(url, TiktokPhotos.pageUrl("https://www.tiktok.com/@author/photo/123456?foo=1"))
        assertEquals("123456", TiktokPhotos.postId(url))
        assertNull(TiktokPhotos.postId("https://www.tiktok.com/@author"))
    }

    @Test fun canonicalRecoversTheFullPostUrlFromShortLinkLandingPages() {
        // og:url with a full canonical URL — recovered as-is.
        val ogHtml = """<meta property="og:url" content="https://www.tiktok.com/@someone/photo/7123456789"/>"""
        assertEquals("https://www.tiktok.com/@someone/photo/7123456789", TiktokPhotos.canonical(ogHtml))

        // link rel=canonical with a relative URL — resolved against www.tiktok.com.
        val linkHtml = """<link rel="canonical" href="/@someone/video/7123456789"/>"""
        assertEquals("https://www.tiktok.com/@someone/video/7123456789", TiktokPhotos.canonical(linkHtml))

        // Attributes written in the reverse order (href before rel).
        val reversed = """<link href="https://www.tiktok.com/@u/photo/42" rel="canonical"/>"""
        assertEquals("https://www.tiktok.com/@u/photo/42", TiktokPhotos.canonical(reversed))
    }

    @Test fun canonicalIgnoresUnrelatedOrUnsafeTargets() {
        // Points at a non-post URL — rejected because postId does not match.
        val homepage = """<link rel="canonical" href="https://www.tiktok.com/foryou"/>"""
        assertNull(TiktokPhotos.canonical(homepage))

        // Points to a lookalike domain — rejected by allowedPageUrl.
        val evil = """<meta property="og:url" content="https://evil.example.com/@u/photo/1"/>"""
        assertNull(TiktokPhotos.canonical(evil))

        // No canonical tag at all.
        assertNull(TiktokPhotos.canonical("<html><body>Hello</body></html>"))
    }

    @Test fun theTiktokPageIsRequestedAsADesktopBrowser() {
        // TikTok server-renders post data for desktop clients only. A mobile
        // user agent returns a shell with no data, which is what sent photo
        // links to yt-dlp and surfaced "Unsupported URL" to the user.
        assertFalse(PublicWebClient.USER_AGENT.contains("Mobile"))
        assertFalse(PublicWebClient.USER_AGENT.contains("Android"))
        assertTrue(PublicWebClient.USER_AGENT.contains("Windows NT"))
    }

    @Test fun cdnValidationRejectsCredentialsLocalHostsAndDomainLookalikes() {
        for (url in listOf("http://p16.tiktokcdn.com/a", "https://tiktokcdn.com.evil.test/a",
            "https://eviltiktokcdn.com/a", "https://user:pw@p16.tiktokcdn.com/a",
            "https://127.0.0.1/a", "https://p16.tiktokcdn.com:123/a", "file:///tmp/photo")) {
            assertFalse(url, PublicWebClient.allowedImageUrl(url))
        }
        assertTrue(PublicWebClient.allowedImageUrl("https://p16.tiktokcdn.com/a?signature=abc"))
        assertFalse(PublicWebClient.allowedPageUrl("https://evil.tiktok.com.example/a"))
    }
}
