package com.dazdownloader.dazdownloader

import android.content.Context
import android.graphics.BitmapFactory
import java.io.File

class PhotoDownloader(private val context: Context) {
    fun download(album: PhotoAlbum, directory: File, task: MediaTask,
        progress: (String, Double?) -> Unit): Map<String, Any> {
        val client = PublicWebClient(task)
        var total = 0L
        val files = album.images.mapIndexed { index, photo ->
            task.checkActive()
            val file = File(directory, "photo-$index.part")
            var validated: DownloadStore.Input? = null
            var failure: Exception? = null
            for (url in photo.urls) {
                task.checkActive()
                try {
                    client.image(url, file)
                    val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                    BitmapFactory.decodeFile(file.absolutePath, options)
                    val extension = when (options.outMimeType) {
                        "image/jpeg" -> "jpg"
                        "image/png" -> "png"
                        "image/webp" -> "webp"
                        else -> throw MediaFailure("invalid_file", "La photo ${index + 1} n’est pas une image prise en charge.")
                    }
                    if (options.outWidth <= 0 || options.outHeight <= 0 ||
                        options.outWidth.toLong() * options.outHeight > 100_000_000) {
                        throw MediaFailure("invalid_file", "La photo ${index + 1} n’est pas lisible.")
                    }
                    MediaFiles.validate(file, extension)
                    validated = DownloadStore.Input(file, extension, options.outMimeType)
                    break
                } catch (error: Exception) {
                    task.checkActive()
                    failure = error
                }
            }
            val result = validated ?: throw (failure ?: MediaFailure("no_photos", "Photo inaccessible."))
            total += file.length()
            if (total > 300L * 1024 * 1024) throw MediaFailure("too_large", "Le carrousel dépasse la limite de 300 Mo.")
            progress("downloading", 100.0 * (index + 1) / album.images.size)
            result
        }
        task.checkActive()
        progress("saving", null)
        val saved = DownloadStore(context).saveAll(files, album.title, task)
        return saved.first() + mapOf("name" to album.title, "sizeBytes" to total, "files" to saved)
    }
}
