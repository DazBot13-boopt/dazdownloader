package com.dazdownloader.dazdownloader

import org.junit.Assert.*
import org.junit.Test
import java.io.IOException

class MediaBatchTest {
    private class Pending(val failPublish: Boolean = false, val failRollback: Boolean = false) : PendingMedia {
        var published = false
        var removed = false
        override val result = mapOf<String, Any>("uri" to "content://test/file")
        override fun publish() { if (failPublish) throw IOException("full"); published = true }
        override fun rollback() { if (failRollback) throw IOException("blocked"); removed = true; published = false }
    }

    @Test fun allFilesCommitTogetherAndLateCancellationCannotEraseSuccess() {
        val task = MediaTask("batch")
        val first = Pending(); val second = Pending()
        val files = MediaBatch.save(task, listOf({ first }, { second }))
        assertEquals(2, files.size)
        assertTrue(first.published && second.published)
        assertFalse(task.cancel())
    }
    @Test fun failureWhileStagingRollsBackEarlierFiles() {
        val first = Pending()
        assertThrows(IOException::class.java) {
            MediaBatch.save(MediaTask("batch"), listOf({ first }, { throw IOException("full") }))
        }
        assertTrue(first.removed)
        assertFalse(first.published)
    }
    @Test fun failurePublishingSecondFileRollsBackBothFiles() {
        val first = Pending(); val second = Pending(failPublish = true)
        assertThrows(IOException::class.java) { MediaBatch.save(MediaTask("batch"), listOf({ first }, { second })) }
        assertTrue(first.removed && second.removed)
        assertFalse(first.published)
    }
    @Test fun cancellationBeforePublicationRollsBackAllFiles() {
        val task = MediaTask("batch"); val first = Pending(); val second = Pending()
        assertEquals("cancelled", assertThrows(MediaFailure::class.java) {
            MediaBatch.save(task, listOf({ first }, { task.cancel(); second }))
        }.code)
        assertTrue(first.removed && second.removed)
        assertFalse(first.published)
    }
    @Test fun rollbackFailureIsNotSilentlyReportedAsCancellation() {
        val first = Pending(failRollback = true)
        assertEquals("storage_partial", assertThrows(MediaFailure::class.java) {
            MediaBatch.save(MediaTask("batch"), listOf({ first }, { throw IOException("full") }))
        }.code)
    }
}
