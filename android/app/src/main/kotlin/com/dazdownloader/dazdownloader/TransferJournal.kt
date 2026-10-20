package com.dazdownloader.dazdownloader

import android.content.Context
import java.util.UUID

/** Stores only public, user-visible transfer state for the next app launch. */
class TransferJournal(context: Context) {
    private val preferences = context.getSharedPreferences("long_download", Context.MODE_PRIVATE)

    fun start(taskId: String, url: String) = write(taskId, url, "downloading", null, null, null, null)
    fun update(taskId: String, state: String, message: String? = null, percent: Double? = null, eta: Long? = null) =
        write(taskId, preferences.getString(URL, null), state, message, percent, eta, null)
    fun finish(taskId: String, result: Map<String, Any>?) =
        write(taskId, preferences.getString(URL, null), "completed", null, null, null, result)
    fun fail(taskId: String, message: String) =
        write(taskId, preferences.getString(URL, null), "failed", message, null, null, null)
    fun cancelled(taskId: String) = write(taskId, preferences.getString(URL, null), "cancelled", null, null, null, null)

    /** A live transfer cannot outlive the Android process that owns its worker. */
    fun reconcileProcess(): Boolean {
        val state = preferences.getString(STATE, null) ?: return false
        val owner = preferences.getString(OWNER_INSTANCE, null)
        if (state !in ACTIVE_STATES || owner == PROCESS_INSTANCE_ID) return false
        write(
            preferences.getString(ID, null) ?: return false,
            preferences.getString(URL, null),
            "interrupted",
            "Le téléchargement a été interrompu lorsque Loady a été fermé par Android. Relancez-le depuis l’accueil.",
            null, null, null,
        )
        return true
    }

    fun snapshot(): Map<String, Any?>? {
        val id = preferences.getString(ID, null) ?: return null
        return mapOf(
            "taskId" to id,
            "url" to preferences.getString(URL, null),
            "state" to preferences.getString(STATE, "unknown"),
            "message" to preferences.getString(MESSAGE, null),
            "percent" to if (preferences.contains(PERCENT)) preferences.getFloat(PERCENT, 0f).toDouble() else null,
            "etaSeconds" to if (preferences.contains(ETA)) preferences.getLong(ETA, 0L) else null,
            "uri" to preferences.getString(URI, null),
            "name" to preferences.getString(NAME, null),
            "mimeType" to preferences.getString(MIME, null),
            "sizeBytes" to preferences.getLong(SIZE, 0L),
        )
    }

    private fun write(taskId: String, url: String?, state: String, message: String?, percent: Double?, eta: Long?, result: Map<String, Any>?) {
        preferences.edit()
            .putString(ID, taskId)
            .putString(URL, url)
            .putString(STATE, state)
            .putString(MESSAGE, message)
            .putString(OWNER_INSTANCE, PROCESS_INSTANCE_ID)
            .putLong(UPDATED_AT, System.currentTimeMillis())
            .apply {
                if (percent != null && percent.isFinite()) putFloat(PERCENT, percent.toFloat()) else remove(PERCENT)
                if (eta != null) putLong(ETA, eta) else remove(ETA)
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
        const val PERCENT = "percent"
        const val ETA = "eta"
        const val OWNER_INSTANCE = "owner_instance"
        const val UPDATED_AT = "updated_at"
        val ACTIVE_STATES = setOf("downloading", "processing", "saving", "retrying")
        val PROCESS_INSTANCE_ID: String = UUID.randomUUID().toString()
    }
}
