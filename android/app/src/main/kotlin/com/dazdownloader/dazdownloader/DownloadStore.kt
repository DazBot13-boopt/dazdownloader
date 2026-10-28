package com.dazdownloader.dazdownloader

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import androidx.documentfile.provider.DocumentFile
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
    data class Input(val file: File, val extension: String, val mime: String)

    fun save(file: File, title: String, format: NativeFormat, task: MediaTask): Map<String, Any> {
        val input = Input(file, format.extension, format.mimeType)
        MediaFiles.validate(input.file, input.extension)
        // One file per transfer. MediaBatch still owns the commit/rollback
        // boundary, so a cancellation never leaves a half-published file.
        return MediaBatch.save(task, listOf {
            val name = "${MediaFiles.safeTitle(title)}-${task.processId.take(8)}.${input.extension}"
            val selectedTree = context.getSharedPreferences("download_location", Context.MODE_PRIVATE)
                .getString("tree_uri", null)
            if (selectedTree != null) {
                stageSelectedTree(input.file, name, input.mime, task, selectedTree)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                stageMediaStore(input.file, name, input.mime, task)
            } else stageLegacy(input.file, name, input.mime, task, 0)
        }).single()
    }

    private fun stageSelectedTree(file: File, name: String, mime: String, task: MediaTask, rawTreeUri: String): PendingMedia {
        val tree = DocumentFile.fromTreeUri(context, android.net.Uri.parse(rawTreeUri))
            ?: throw MediaFailure("storage", "Le dossier choisi n’est plus accessible. Choisissez un autre dossier.")
        if (!tree.canWrite()) throw MediaFailure("storage", "Le dossier choisi n’est plus accessible en écriture.")
        val partial = tree.createFile(mime, "$name.partial")
            ?: throw MediaFailure("storage", "Impossible de créer le fichier dans le dossier choisi.")
        try {
            context.contentResolver.openOutputStream(partial.uri)?.use { output ->
                file.inputStream().use { copy(it, output, task) }
            } ?: throw MediaFailure("storage", "Impossible d’écrire dans le dossier choisi.")
            return object : PendingMedia {
                private var finalDocument = partial
                override val result: Map<String, Any>
                    get() = mapOf("uri" to finalDocument.uri.toString(), "name" to name, "mimeType" to mime, "sizeBytes" to file.length())
                override fun publish() {
                    if (!partial.renameTo(name)) throw MediaFailure("storage", "Impossible de finaliser le fichier téléchargé.")
                    finalDocument = tree.findFile(name) ?: partial
                }
                override fun rollback() {
                    if (finalDocument.exists() && !finalDocument.delete()) throw java.io.IOException("Cannot remove staged document")
                }
            }
        } catch (error: Exception) {
            runCatching { partial.delete() }
            throw error
        }
    }

    @android.annotation.TargetApi(Build.VERSION_CODES.Q)
    private fun stageMediaStore(file: File, name: String, mime: String, task: MediaTask): PendingMedia {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, name)
            put(MediaStore.Downloads.MIME_TYPE, mime)
            put(MediaStore.Downloads.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/Loady")
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw MediaFailure("storage", "Impossible de créer le fichier dans Downloads.")
        try {
            resolver.openOutputStream(uri)?.use { output ->
                file.inputStream().use { copy(it, output, task) }
            } ?: throw MediaFailure("storage", "Impossible d’écrire dans Downloads.")
            return object : PendingMedia {
                override val result = mapOf("uri" to uri.toString(), "name" to name, "mimeType" to mime, "sizeBytes" to file.length())
                override fun publish() {
                    val published = resolver.update(uri, ContentValues().apply {
                        put(MediaStore.Downloads.IS_PENDING, 0)
                    }, null, null)
                    if (published != 1) throw MediaFailure("storage", "L’enregistrement du fichier a échoué.")
                }
                override fun rollback() { resolver.delete(uri, null, null) }
            }
        } catch (error: Exception) {
            // This URI was created by this operation, never an existing file.
            runCatching { resolver.delete(uri, null, null) }
            throw error
        }
    }

    @Suppress("DEPRECATION")
    private fun stageLegacy(file: File, name: String, mime: String, task: MediaTask, index: Int): PendingMedia {
        val directory = File(Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS), "Loady")
        if (!directory.isDirectory && !directory.mkdirs()) {
            throw MediaFailure("storage", "Impossible de créer le dossier Downloads/Loady.")
        }
        val destination = File(directory, name)
        val partial = File(directory, ".${task.processId}-$index.partial")
        if (!partial.createNewFile()) throw MediaFailure("storage", "Un fichier temporaire existe déjà.")
        try {
            partial.outputStream().use { output -> file.inputStream().use { copy(it, output, task) } }
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.downloads", destination)
            return object : PendingMedia {
                private var published = false
                override val result = mapOf("uri" to uri.toString(), "name" to name, "mimeType" to mime, "sizeBytes" to file.length())
                override fun publish() {
                    if (destination.exists() || !partial.renameTo(destination)) {
                        throw MediaFailure("storage", "Impossible de finaliser le fichier téléchargé.")
                    }
                    published = true
                }
                override fun rollback() {
                    if (partial.exists() && !partial.delete()) throw java.io.IOException("Cannot remove partial")
                    if (published && destination.exists() && !destination.delete()) throw java.io.IOException("Cannot remove new file")
                }
            }
        } catch (error: Exception) {
            partial.delete()
            throw error
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
