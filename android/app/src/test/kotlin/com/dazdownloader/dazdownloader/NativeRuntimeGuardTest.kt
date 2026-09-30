package com.dazdownloader.dazdownloader

import org.junit.Assert.*
import org.junit.Test

class NativeRuntimeGuardTest {
    @Test fun successfulOperationReturnsItsValue() {
        assertEquals(42, NativeRuntimeGuard.run { 42 })
    }

    @Test fun initializerFailureBecomesAUserVisibleError() {
        val original = ExceptionInInitializerError(IllegalStateException("ZIP constructor removed"))
        val failure = assertThrows(MediaFailure::class.java) {
            NativeRuntimeGuard.run<Any> { throw original }
        }
        assertEquals("engine_initialization", failure.code)
        assertSame(original, failure.cause)
        assertTrue(failure.message.contains("ExceptionInInitializerError"))
        assertFalse(failure.message.contains("ZIP constructor removed"))
    }

    @Test fun failedClassCanBeReportedOnASubsequentAttempt() {
        val original = NoClassDefFoundError("Could not initialize class")
        val failure = assertThrows(MediaFailure::class.java) {
            NativeRuntimeGuard.run<Any> { throw original }
        }
        assertSame(original, failure.cause)
        assertTrue(failure.message.contains("NoClassDefFoundError"))
    }

    @Test fun ordinaryErrorsKeepTheirExistingHandling() {
        val original = MediaFailure("network", "Network failure")
        val failure = assertThrows(MediaFailure::class.java) {
            NativeRuntimeGuard.run<Any> { throw original }
        }
        assertSame(original, failure)
    }

    @Test fun fatalVmErrorsAreNotSwallowed() {
        val original = OutOfMemoryError("Synthetic test error; no allocation")
        val failure = assertThrows(OutOfMemoryError::class.java) {
            NativeRuntimeGuard.run<Any> { throw original }
        }
        assertSame(original, failure)
    }
}
