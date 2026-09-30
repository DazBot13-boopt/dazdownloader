package com.dazdownloader.dazdownloader

import android.content.Context
import android.util.AtomicFile
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import java.io.File
import java.security.MessageDigest

object EngineVersion {
    const val PINNED = "2026.08.19"
    const val SHA256 = "1fa6733c37ea6fb51c99ad8fe785e7b7e5f3246c9b980230329d4fb72ed8d4d6"
    private val pattern = Regex("^\\d{4}\\.\\d{2}\\.\\d{2}(?:[.0-9a-zA-Z_-]*)$")
    fun valid(value: String) = pattern.matches(value)
    fun needsBundledVersion(value: String) = valid(value) && value.take(10) < PINNED
}

class EngineRuntime(private val context: Context) {
    var version: String? = null
        private set

    fun ensure(task: MediaTask) {
        YoutubeDL.init(context)
        if (version != null) return
        val current = readVersion(task)
        if (EngineVersion.needsBundledVersion(current)) {
            val bytes = context.resources.openRawResource(R.raw.daz_ytdlp).use { it.readBytes() }
            val hash = MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
            if (hash != EngineVersion.SHA256) throw MediaFailure("engine_integrity", "Le moteur intégré est endommagé. Réinstallez l’APK.")
            task.checkActive()
            val destination = File(File(File(context.noBackupFilesDir, YoutubeDL.baseName), YoutubeDL.ytdlpDirName), YoutubeDL.ytdlpBin)
            val atomic = AtomicFile(destination)
            val output = atomic.startWrite()
            try {
                output.write(bytes)
                task.checkActive()
                atomic.finishWrite(output)
            } catch (error: Exception) {
                atomic.failWrite(output)
                throw error
            }
        }
        version = readVersion(task)
    }

    fun update(task: MediaTask): String {
        YoutubeDL.updateYoutubeDL(context, YoutubeDL.UpdateChannel.STABLE)
        task.checkActive()
        // Check the executable, not the updater's cached version preferences.
        version = null
        ensure(task)
        return version!!
    }

    private fun readVersion(task: MediaTask): String {
        val request = YoutubeDLRequest(emptyList()).apply {
            addOption("--ignore-config")
            addOption("--version")
        }
        val actual = YoutubeDL.execute(request, task.processId, false, null).out.trim()
        task.checkActive()
        if (!EngineVersion.valid(actual)) throw MediaFailure("engine_version", "Impossible de vérifier la version réelle du moteur.")
        return actual
    }
}
