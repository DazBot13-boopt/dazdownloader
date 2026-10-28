package com.dazdownloader.dazdownloader

import org.junit.Assert.*
import org.junit.Test

class TransferInterruptionTest {
    @Test fun activeTransferFromAnotherProcessIsInterrupted() {
        for (state in listOf("downloading", "processing", "saving", "retrying")) {
            assertTrue(state, TransferInterruption.isInterrupted(state, startedInPid = 100, currentPid = 200))
        }
    }

    @Test fun activeTransferInThisProcessIsStillRunning() {
        assertFalse(TransferInterruption.isInterrupted("downloading", startedInPid = 100, currentPid = 100))
    }

    @Test fun finishedTransfersAreNeverInterrupted() {
        for (state in listOf("completed", "failed", "cancelled", null)) {
            assertFalse(TransferInterruption.isInterrupted(state, startedInPid = 100, currentPid = 200))
        }
    }
}
