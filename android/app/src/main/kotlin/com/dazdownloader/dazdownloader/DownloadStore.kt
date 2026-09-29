package com.dazdownloader.dazdownloader

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import java.io.File
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean

class MediaTask(val id: String) {
    // Never pass a caller-supplied ID to the library's process cancellation.
    val processId: String = UUID.randomUUID().toString()
    val cancelled = AtomicBoolean(false)
    val timedOut = AtomicBoolean(false)
    private var committed = false

    @Synchronized
    fun cancel(): Boolean {
        if (committed) return false
        cancelled.set(true)
        return true
    }

    fun checkActive() {
        if (timedOut.get()) throw MediaFailure("timeout", "L’analyse a pris trop de temps. Vérifiez votre connexion et réessayez.")
        if (cancelled.get()) throw MediaFailure("cancelled", "Téléchargement annulé.")
    }

    @Synchronized
    fun <T> commit(action: () -> T): T {
        checkActive()
        return action().also { committed = true }
    }
}

object MediaFiles {
    fun safeTitle(title: String): String = title
        .replace(Regex("[\\p{Cntrl}/\\\\:*?\"<>|]"), "_")
        .trim().trim('.').take(80).ifBlank { "video" }

    fun validate(file: File, extension: String) {
        if (!file.isFile || file.length() < 4) throw MediaFailure("invalid_file",
            "Le moteur n’a pas produit de fichier lisible.")
        val header = ByteArray(12)
        val count = file.inputStream().use { it.read(header) }
        val valid = when (extension) {
            "mp4" -> count >= 8 && String(header, 4, 4, Charsets.US_ASCII) == "ftyp"
            "webm" -> header.take(4).map { it.toInt() and 255 } == listOf(0x1a, 0x45, 0xdf, 0xa3)
            "mp3" -> String(header, 0, 3, Charsets.US_ASCII) == "ID3" ||
                ((header[0].toInt() and 255) == 255 && (header[1].toInt() and 0xe0) == 0xe0)
            else -> false
        }
        if (!valid) throw MediaFailure("invalid_file",
            "Le fichier reçu ne correspond pas au format demandé.")
    }
}

class DownloadStore(private val context: Context) {
    fun save(file: File, title: String, format: NativeFormat, task: MediaTask): Map<String, Any> {
        MediaFiles.validate(file, format.extension)
        task.checkActive()
        val name = "${MediaFiles.safeTitle(title)}-${task.processId.take(8)}.${format.extension}"
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveMediaStore(file, name, format.mimeType, task)
        } else {
            saveLegacy(file, name, format.mimeType, task)
        }
    }

    @android.annotation.TargetApi(Build.VERSION_CODES.Q)
    private fun saveMediaStore(file: File, name: String, mime: String, task: MediaTask): Map<String, Any> {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, name)
            put(MediaStore.Downloads.MIME_TYPE, mime)
            put(MediaStore.Downloads.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/DAZDOWNLOADER")
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw MediaFailure("storage", "Impossible de créer le fichier dans Downloads.")
        try {
            resolver.openOutputStream(uri)?.use { output ->
                file.inputStream().use { copy(it, output, task) }
            } ?: throw MediaFailure("storage", "Impossible d’écrire dans Downloads.")
            return task.commit {
                val published = resolver.update(uri, ContentValues().apply {
                    put(MediaStore.Downloads.IS_PENDING, 0)
                }, null, null)
                if (published != 1) throw MediaFailure("storage", "L’enregistrement du fichier a échoué.")
                mapOf("uri" to uri.toString(), "name" to name, "mimeType" to mime, "sizeBytes" to file.length())
            }
        } catch (error: Exception) {
            // This URI was created by this operation, never an existing file.
            runCatching { resolver.delete(uri, null, null) }
            throw error
        }
    }

    @Suppress("DEPRECATION")
    private fun saveLegacy(file: File, name: String, mime: String, task: MediaTask): Map<String, Any> {
        val directory = File(Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS), "DAZDOWNLOADER")
        if (!directory.isDirectory && !directory.mkdirs()) {
            throw MediaFailure("storage", "Impossible de créer le dossier Downloads/DAZDOWNLOADER.")
        }
        val destination = File(directory, name)
        val partial = File(directory, ".${task.processId}.partial")
        if (!partial.createNewFile()) throw MediaFailure("storage", "Un fichier temporaire existe déjà.")
        try {
            partial.outputStream().use { output -> file.inputStream().use { copy(it, output, task) } }
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.downloads", destination)
            return task.commit {
                if (destination.exists() || !partial.renameTo(destination)) {
                    throw MediaFailure("storage", "Impossible de finaliser le fichier téléchargé.")
                }
                mapOf("uri" to uri.toString(), "name" to name, "mimeType" to mime, "sizeBytes" to destination.length())
            }
        } finally {
            partial.delete()
        }
    }

    private fun copy(input: InputStream, output: OutputStream, task: MediaTask) {
        val buffer = ByteArray(64 * 1024)
        while (true) {
            task.checkActive()
            val count = input.read(buffer)
            if (count < 0) break
            output.write(buffer, 0, count)
        }
        output.flush()
        task.checkActive()
    }
}
