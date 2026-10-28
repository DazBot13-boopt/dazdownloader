package com.dazdownloader.dazdownloader

import android.content.Context
import android.os.Process

/**
 * A transfer only runs inside the process that started it. When the journal
 * still says "in progress" but that process is gone, Android killed the app
 * mid-download: the transfer is over and must be reported as interrupted.
 */
internal object TransferInterruption {
    private val activeStates = setOf("downloading", "processing", "saving", "retrying")
    const val MESSAGE = "Le téléchargement a été interrompu car Loady a été fermé. Relancez-le."

    fun isInterrupted(state: String?, startedInPid: Int, currentPid: Int): Boolean =
        state in activeStates && startedInPid != currentPid
}

/** Stores only public, user-visible transfer state for the next app launch. */
class TransferJournal(context: Context) {
    private val preferences = context.getSharedPreferences("long_download", Context.MODE_PRIVATE)

    fun start(taskId: String, url: String) = write(taskId, url, "downloading", null, null)
    fun update(taskId: String, state: String, message: String? = null) =
        write(taskId, preferences.getString(URL, null), state, message, null)
    fun finish(taskId: String, result: Map<String, Any>?) =
        write(taskId, preferences.getString(URL, null), "completed", null, result)
    fun fail(taskId: String, message: String) =
        write(taskId, preferences.getString(URL, null), "failed", message, null)
    fun cancelled(taskId: String) = write(taskId, preferences.getString(URL, null), "cancelled", null, null)

    fun snapshot(): Map<String, Any?>? {
        val id = preferences.getString(ID, null) ?: return null
        if (TransferInterruption.isInterrupted(
                preferences.getString(STATE, null), preferences.getInt(PID, -1), Process.myPid())) {
            fail(id, TransferInterruption.MESSAGE)
        }
        return mapOf(
            "taskId" to id,
            "url" to preferences.getString(URL, null),
            "state" to preferences.getString(STATE, "unknown"),
            "message" to preferences.getString(MESSAGE, null),
            "uri" to preferences.getString(URI, null),
            "name" to preferences.getString(NAME, null),
            "mimeType" to preferences.getString(MIME, null),
            "sizeBytes" to preferences.getLong(SIZE, 0L),
        )
    }

    private fun write(taskId: String, url: String?, state: String, message: String?, result: Map<String, Any>?) {
        preferences.edit()
            .putString(ID, taskId)
            .putString(URL, url)
            .putString(STATE, state)
            .putString(MESSAGE, message)
            .putInt(PID, Process.myPid())
            .apply {
                if (result == null) {
                    remove(URI)
                    remove(NAME)
                    remove(MIME)
                    remove(SIZE)
                    return@apply
                }
                putString(URI, result["uri"] as? String)
                putString(NAME, result["name"] as? String)
                putString(MIME, result["mimeType"] as? String)
                putLong(SIZE, result["sizeBytes"] as? Long ?: 0L)
            }
            .apply()
    }

    private companion object {
        const val ID = "id"
        const val URL = "url"
        const val STATE = "state"
        const val MESSAGE = "message"
        const val URI = "uri"
        const val NAME = "name"
        const val MIME = "mime"
        const val SIZE = "size"
        const val PID = "pid"
    }
}
