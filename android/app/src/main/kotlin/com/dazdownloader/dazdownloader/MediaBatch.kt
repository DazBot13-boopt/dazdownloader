package com.dazdownloader.dazdownloader

interface PendingMedia {
    val result: Map<String, Any>
    fun publish()
    fun rollback()
}

/** A single cancellation/commit boundary for all files; no partial-success response. */
object MediaBatch {
    fun save(task: MediaTask, stages: List<() -> PendingMedia>): List<Map<String, Any>> {
        require(stages.isNotEmpty())
        val pending = mutableListOf<PendingMedia>()
        try {
            for (stage in stages) {
                task.checkActive()
                pending += stage()
            }
            return task.commit {
                pending.forEach { it.publish() }
                pending.map { it.result }
            }
        } catch (error: Exception) {
            var rollbackFailed = false
            pending.asReversed().forEach {
                try { it.rollback() } catch (_: Exception) { rollbackFailed = true }
            }
            if (rollbackFailed) throw MediaFailure("storage_partial",
                "L’enregistrement a échoué et certains fichiers n’ont pas pu être retirés. Vérifiez Downloads/Loady avant de réessayer.")
                .apply { initCause(error) }
            throw error
        }
    }
}
