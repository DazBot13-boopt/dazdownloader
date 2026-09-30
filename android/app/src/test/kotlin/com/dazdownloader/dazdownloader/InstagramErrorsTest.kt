package com.dazdownloader.dazdownloader

import org.junit.Assert.*
import org.junit.Test

class InstagramErrorsTest {
    @Test fun anonymousRateLimitIsNotMisreportedAsAPrivatePost() {
        assertEquals("instagram_limited", InstagramErrors.classify("login required: rate-limit reached").code)
        assertEquals("instagram_limited", InstagramErrors.classify("HTTP Error 429").code)
    }
    @Test fun classifiesLoginAndUnsupportedLinks() {
        assertEquals("instagram_login", InstagramErrors.classify("Redirected to login page").code)
        assertEquals("instagram_url", InstagramErrors.classify("Unsupported URL").code)
        assertEquals("instagram_no_video", InstagramErrors.classify("There is no video in this post").code)
    }
    @Test fun genericFailureDoesNotLeakStderrOrClaimUpdateWillFixIt() {
        val failure = InstagramErrors.classify("Unable to extract data https://private.test/?token=secret")
        assertEquals("instagram_extraction", failure.code)
        assertFalse(failure.message.contains("secret"))
    }
    @Test fun pinnedEngineOnlyReplacesOlderVersions() {
        assertTrue(EngineVersion.needsBundledVersion("2025.11.12"))
        assertFalse(EngineVersion.needsBundledVersion("2026.08.19"))
        assertFalse(EngineVersion.needsBundledVersion("2026.09.29.123456"))
        assertFalse(EngineVersion.valid("random output"))
    }
}
