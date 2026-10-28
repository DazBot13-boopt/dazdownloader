package com.dazdownloader.dazdownloader

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.content.ActivityNotFoundException
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.provider.MediaStore
import androidx.documentfile.provider.DocumentFile
import android.util.Log
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

// Resolve the real versionName from PackageManager so the diagnostic
// surface stays in sync with every release instead of a hardcoded value.
private val Activity.installedVersionName: String
    get() = try {
        packageManager.getPackageInfo(packageName, 0).versionName ?: "inconnue"
    } catch (_: PackageManager.NameNotFoundException) {
        "inconnue"
    }

class MediaBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val methods = MethodChannel(messenger, "dazdownloader/media")
    private val events = EventChannel(messenger, "dazdownloader/media/progress")
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val watchdog = Executors.newSingleThreadScheduledExecutor()
    private val runtime = EngineRuntime(activity.applicationContext)
    private val journal = TransferJournal(activity.applicationContext)
    private val catalogs = linkedMapOf<String, MediaCatalog>() // Worker thread only.
    private val savedUris = ConcurrentHashMap<String, String>()
    private var pendingLocationResult: MethodChannel.Result? = null
    private var sink: EventChannel.EventSink? = null
    @Volatile private var active: MediaTask? = null
    @Volatile private var activeOperation: String? = null
    @Volatile private var closed = false
    private var permissionRequest: Pair<MethodCall, MethodChannel.Result>? = null

    init {
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
    override fun onCancel(arguments: Any?) { sink = null }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
        when (call.method) {
            "cancel" -> {
                val id = call.argument<String>("taskId")
                val pending = permissionRequest
                if (pending != null && pending.first.argument<String>("taskId") == id) {
                    permissionRequest = null
                    pending.second.error("cancelled", "Téléchargement annulé.", null)
                    result.success(true)
                } else result.success(active?.takeIf { it.id == id }?.cancel() ?: false)
            }
            "open" -> open(call, result)
            "history" -> result.success(history())
            "deleteHistoryItem" -> result.success(deleteHistoryItem(call.argument<String>("uri") ?: ""))
            "deleteAllHistory" -> result.success(deleteAllHistory())
            "getDownloadLocation" -> result.success(downloadLocation())
            "chooseDownloadLocation" -> {
                if (activeOperation == "download") result.error("busy", "Attendez la fin du téléchargement pour changer de dossier.", null)
                else chooseDownloadLocation(result)
            }
            "resetDownloadLocation" -> {
                if (activeOperation == "download") {
                    result.error("busy", "Attendez la fin du téléchargement pour changer de dossier.", null)
                    return
                }
                activity.getSharedPreferences(LOCATION_PREFS, Activity.MODE_PRIVATE)
                    .edit().remove(LOCATION_URI).apply()
                result.success(downloadLocation())
            }
            "transferStatus" -> result.success(journal.snapshot())
            "resolve", "download", "update" -> {
                if (active != null || permissionRequest != null) {
                    result.error("busy", "Une opération est déjà en cours. Attendez ou annulez-la.", null)
                    return
                }
                if (call.method == "download" && Build.VERSION.SDK_INT <= 28 &&
                    activity.getSharedPreferences(LOCATION_PREFS, Activity.MODE_PRIVATE).getString(LOCATION_URI, null) == null &&
                    activity.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                    permissionRequest = call to result
                    activity.requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), STORAGE_PERMISSION)
                } else launch(call, result)
            }
            else -> result.notImplemented()
        }
        } catch (error: Exception) {
            result.error("native_error", error.message ?: "Opération impossible.", null)
        }
    }

    fun onPermissionResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != STORAGE_PERMISSION) return false
        val pending = permissionRequest ?: return true
        permissionRequest = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            launch(pending.first, pending.second)
        } else pending.second.error("permission_denied",
            "L’autorisation de stockage est nécessaire pour enregistrer dans Downloads sur cet appareil.", null)
        return true
    }

    private fun launch(call: MethodCall, result: MethodChannel.Result) {
        val taskId = call.argument<String>("taskId")
        if (taskId.isNullOrBlank() || taskId.length > 128) {
            result.error("invalid_request", "Identifiant de téléchargement invalide.", null)
            return
        }
        val task = MediaTask(taskId)
        active = task
        activeOperation = call.method
        if (call.method == "download") {
            journal.start(task.id, requiredUrl(call))
            DownloadNotificationService.start(activity, task.id)
        }
        worker.execute {
            val cancellation = watchdog.scheduleWithFixedDelay({
                if (task.cancelled.get()) runCatching { YoutubeDL.destroyProcessById(task.processId) }
            }, 0, 150, TimeUnit.MILLISECONDS)
            val deadline = if (call.method == "resolve") watchdog.schedule({
                task.timedOut.set(true)
                task.cancel()
            }, 120, TimeUnit.SECONDS) else null
            var value: Any? = null
            var failure: MediaFailure? = null
            try {
                value = NativeRuntimeGuard.run {
                    task.checkActive()
                    when (call.method) {
                        "resolve" -> resolve(requiredUrl(call), task)
                        "download" -> download(requiredUrl(call),
                            call.argument<String>("formatId") ?: "", task)
                        else -> {
                            runtime.ensure(task)
                            val version = runtime.update(task)
                            task.checkActive()
                            catalogs.clear()
                            mapOf("engineVersion" to version)
                        }
                    }
                }
            } catch (error: Exception) {
                if (error is MediaFailure && error.code == "engine_initialization") {
                    // Local crash diagnostics only, not uploaded or sent to Flutter.
                    Log.e("DazDownloader", "Native runtime initialization failed", error.cause)
                }
                failure = friendlyError(error, task, call.argument<String>("url"))
            } finally {
                cancellation.cancel(false)
                deadline?.cancel(false)
                main.post {
                    if (active === task) {
                        active = null
                        activeOperation = null
                    }
                    if (!closed) {
                        val error = failure
                        if (error == null) result.success(value)
                        else result.error(error.code, error.message, mapOf(
                            "engineVersion" to (runtime.version ?: "non démarré"),
                            "androidApi" to Build.VERSION.SDK_INT,
                            "appVersion" to activity.installedVersionName,
                            "operation" to call.method))
                    }
                }
                if (closed) watchdog.shutdown()
                if (call.method == "download") {
                    if (failure == null) {
                        @Suppress("UNCHECKED_CAST")
                        journal.finish(task.id, value as? Map<String, Any>)
                        DownloadNotificationService.complete(activity, "Téléchargement terminé")
                    } else {
                        if (failure?.code == "cancelled") journal.cancelled(task.id)
                        else journal.fail(task.id, failure?.message ?: "Téléchargement impossible")
                        DownloadNotificationService.failed(activity, failure?.message ?: "Téléchargement impossible")
                    }
                }
            }
        }
    }

    private fun history(): List<Map<String, Any?>> {
        val selectedTree = activity.getSharedPreferences(LOCATION_PREFS, Activity.MODE_PRIVATE)
            .getString(LOCATION_URI, null)
        if (selectedTree != null) {
            val tree = DocumentFile.fromTreeUri(activity, Uri.parse(selectedTree))
                ?: return emptyList()
            return tree.listFiles().filter { file ->
                file.isFile && file.name?.matches(LOADY_FILE_NAME) == true
            }.map { file ->
                mapOf(
                    "uri" to file.uri.toString(),
                    "name" to (file.name ?: "Téléchargement"),
                    "mimeType" to (file.type ?: mimeFor(file.name.orEmpty())),
                    "sizeBytes" to file.length(),
                    "dateAdded" to file.lastModified(),
                )
            }.sortedByDescending { it["dateAdded"] as Long }
        }
        val resolver = activity.contentResolver
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Downloads.EXTERNAL_CONTENT_URI
        } else {
            MediaStore.Files.getContentUri("external")
        }
        val projection = arrayOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.MIME_TYPE,
            MediaStore.MediaColumns.SIZE,
            MediaStore.MediaColumns.DATE_ADDED,
        )
        val selection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            "${MediaStore.MediaColumns.RELATIVE_PATH} = ?"
        } else {
            "${MediaStore.MediaColumns.DATA} LIKE ?"
        }
        val argument = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            "${Environment.DIRECTORY_DOWNLOADS}/Loady/"
        } else {
            "${Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)}/Loady/%"
        }
        val result = mutableListOf<Map<String, Any?>>()
        resolver.query(collection, projection, selection, arrayOf(argument),
            "${MediaStore.MediaColumns.DATE_ADDED} DESC")?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
            val nameColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)
            val mimeColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.MIME_TYPE)
            val sizeColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)
            val dateColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_ADDED)
            while (cursor.moveToNext()) {
                val id = cursor.getLong(idColumn)
                result += mapOf(
                    "uri" to ContentUris.withAppendedId(collection, id).toString(),
                    "name" to cursor.getString(nameColumn),
                    "mimeType" to cursor.getString(mimeColumn),
                    "sizeBytes" to cursor.getLong(sizeColumn),
                    "dateAdded" to cursor.getLong(dateColumn) * 1000,
                )
            }
        }
        return result
    }

    private fun deleteHistoryItem(rawUri: String): Boolean {
        val uri = android.net.Uri.parse(rawUri)
        val resolver = activity.contentResolver
        val selectedTree = activity.getSharedPreferences(LOCATION_PREFS, Activity.MODE_PRIVATE)
            .getString(LOCATION_URI, null)
        if (selectedTree != null) {
            val tree = DocumentFile.fromTreeUri(activity, Uri.parse(selectedTree))
                ?: return false
            val child = tree.listFiles().firstOrNull {
                it.uri == uri && it.name?.matches(LOADY_FILE_NAME) == true
            } ?: return false
            return child.delete()
        }
        val isDownloads = uri.authority == "media" &&
            (uri.path?.startsWith("/external/downloads/") == true ||
             uri.path?.startsWith("/external/file/") == true)
        if (!isDownloads) throw MediaFailure("storage", "Ce fichier ne peut pas être supprimé depuis Loady.")

        val projection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            arrayOf(MediaStore.MediaColumns.RELATIVE_PATH)
        } else arrayOf(MediaStore.MediaColumns.DATA)
        val isOwned = resolver.query(uri, projection, null, null, null)?.use { cursor ->
            if (!cursor.moveToFirst()) false
            else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                cursor.getString(0)?.trimEnd('/') == "${Environment.DIRECTORY_DOWNLOADS}/Loady"
            } else {
                val root = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "Loady")
                val path = cursor.getString(0)?.let(::File)?.canonicalFile
                path != null && path.parentFile?.canonicalFile == root.canonicalFile
            }
        } ?: false
        if (!isOwned) return false
        return resolver.delete(uri, null, null) == 1
    }

    private fun deleteAllHistory(): Int {
        val uris = history().mapNotNull { it["uri"] as? String }
        return uris.count { deleteHistoryItem(it) }
    }

    private fun mimeFor(name: String): String = when (name.substringAfterLast('.', "").lowercase()) {
        "mp4" -> "video/mp4"
        "webm" -> "video/webm"
        "mp3" -> "audio/mpeg"
        else -> "application/octet-stream"
    }

    private fun downloadLocation(): Map<String, String> {
        val saved = activity.getSharedPreferences(LOCATION_PREFS, Activity.MODE_PRIVATE)
            .getString(LOCATION_URI, null)
        if (saved != null) {
            val folder = DocumentFile.fromTreeUri(activity, Uri.parse(saved))
            if (folder != null && folder.canWrite()) {
                return mapOf("uri" to saved, "name" to (folder.name ?: "Dossier choisi"))
            }
            activity.getSharedPreferences(LOCATION_PREFS, Activity.MODE_PRIVATE)
                .edit().remove(LOCATION_URI).apply()
        }
        return mapOf("uri" to "", "name" to "Downloads/Loady")
    }

    private fun chooseDownloadLocation(result: MethodChannel.Result) {
        if (pendingLocationResult != null) {
            result.error("busy", "Le sélecteur de dossier est déjà ouvert.", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        try {
            pendingLocationResult = result
            activity.startActivityForResult(intent, PICK_DOWNLOAD_LOCATION)
        } catch (error: ActivityNotFoundException) {
            pendingLocationResult = null
            result.error("picker_unavailable", "Impossible d’ouvrir le sélecteur de dossier.", null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_DOWNLOAD_LOCATION) return false
        val result = pendingLocationResult ?: return true
        pendingLocationResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return true
        }
        val uri = data.data!!
        val flags = data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        try {
            if ((flags and Intent.FLAG_GRANT_WRITE_URI_PERMISSION) == 0) {
                result.error("location_permission", "Le dossier choisi n’autorise pas l’écriture.", null)
                return true
            }
            activity.contentResolver.takePersistableUriPermission(uri, flags)
            activity.getSharedPreferences(LOCATION_PREFS, Activity.MODE_PRIVATE)
                .edit().putString(LOCATION_URI, uri.toString()).apply()
            result.success(downloadLocation())
        } catch (error: SecurityException) {
            result.error("location_permission", "Loady n’a pas pu conserver l’accès à ce dossier.", null)
        }
        return true
    }

    private fun requiredUrl(call: MethodCall): String =
        MediaUrls.validate(call.argument<String>("url") ?: "")

    private fun request(url: String): YoutubeDLRequest = YoutubeDLRequest(url).apply {
        addOption("--ignore-config")
        addOption("--no-playlist")
        // Bound collection extraction, then explicitly reject collection metadata.
        addOption("--playlist-items", "1")
        addOption("--socket-timeout", 20)
        addOption("--retries", 2)
        addOption("--fragment-retries", 2)
        addOption("--abort-on-unavailable-fragments")
        addOption("--no-colors")
        addCommands(listOf("--"))
    }

    private fun resolve(url: String, task: MediaTask): Map<String, Any?> {
        // Loady downloads videos. TikTok mints /photo/ links only for image
        // carousels, and yt-dlp can answer nothing but "Unsupported URL" for
        // them, which tells the user nothing about why.
        if (MediaUrls.isTiktokPhotoPost(url)) throw MediaFailure("tiktok_photo_post",
            "Cette publication TikTok est un carrousel de photos. Loady télécharge les vidéos.")
        runtime.ensure(task)
        val request = request(url).apply {
            addOption("--dump-single-json")
            addOption("--skip-download")
        }
        val response = YoutubeDL.execute(request, task.processId, false, null)
        task.checkActive()
        val catalog = MediaCatalog.parse(response.out)
        cache(url, catalog)
        return catalog.toMap() + mapOf("engineVersion" to runtime.version)
    }

    private fun cache(url: String, catalog: MediaCatalog) {
        if (catalogs.size >= 8) catalogs.remove(catalogs.keys.first())
        catalogs[url] = catalog
    }

    private fun download(url: String, formatId: String, task: MediaTask): Map<String, Any> {
        val catalog = catalogs[url] ?: throw MediaFailure("preview_expired",
            "L’aperçu a expiré. Analysez à nouveau le lien.")
        val format = catalog.formats.singleOrNull { it.id == formatId }
            ?: throw MediaFailure("invalid_format", "Ce format n’est pas disponible. Analysez à nouveau le lien.")
        // Keep partial fragments outside the disposable cache. yt-dlp can resume
        // them after a transient network failure while the foreground service
        // keeps the process alive in the background.
        val root = File(activity.filesDir, "media-downloads")
        if (!root.isDirectory && !root.mkdirs()) throw MediaFailure("storage", "Impossible de créer le fichier temporaire.")
        val directory = File(root, task.id.replace(Regex("[^a-zA-Z0-9._-]"), "_"))
        if (!directory.isDirectory && !directory.mkdirs()) throw MediaFailure("storage", "Impossible de préparer le téléchargement.")
        format.sizeBytes?.let { expected ->
            val available = StatFs(directory.absolutePath).availableBytes
            // Leave room for the temporary fragments and MediaStore publication.
            if (available < expected + 20L * 1024 * 1024) {
                throw MediaFailure("storage_full", "L’espace disponible est insuffisant pour ce téléchargement.")
            }
        }
        var failure: Exception? = null
        try {
            task.checkActive()
            runtime.ensure(task)
            FFmpeg.init(activity.applicationContext)
            val request = request(url).apply {
                addOption("--no-simulate")
                addOption("--newline")
                addOption("--no-mtime")
                addOption("--no-overwrites")
                addOption("--continue")
                addOption("--part")
                addOption("--match-filter", "!is_live")
                addOption("-f", format.selector)
                addOption("-o", File(directory, "media.%(ext)s").absolutePath)
                if (format.extension == "mp3") {
                    addOption("--extract-audio")
                    addOption("--audio-format", "mp3")
                    addOption("--audio-quality", "0")
                } else {
                    addOption("--merge-output-format", format.extension)
                    addOption("--remux-video", format.extension)
                }
            }
            emit(task, "downloading")
            var completed = false
            var lastError: Exception? = null
            for (attempt in 0 until MAX_NETWORK_ATTEMPTS) {
                try {
                    YoutubeDL.execute(request, task.processId, false) { percent, eta, line ->
                        val processing = line.startsWith("[Merger]") || line.startsWith("[ExtractAudio]") ||
                            line.startsWith("[VideoRemuxer]") || line.startsWith("[Fixup")
                        emit(task, if (processing) "processing" else "downloading",
                            if (!processing && percent.isFinite() && percent >= 0) percent.toDouble().coerceIn(0.0, 100.0) else null,
                            eta.takeIf { it > 0 })
                    }
                    completed = true
                    break
                } catch (error: Exception) {
                    lastError = error
                    if (!isNetworkFailure(error) || attempt == MAX_NETWORK_ATTEMPTS - 1) break
                    DownloadNotificationService.update(
                        activity,
                        task.id,
                        "Réseau interrompu · nouvelle tentative ${attempt + 1}/$MAX_NETWORK_ATTEMPTS…",
                        null,
                    )
                    journal.update(task.id, "retrying", "Coupure réseau : reprise automatique en cours.")
                    Thread.sleep(RETRY_DELAY_MILLIS * (attempt + 1))
                    task.checkActive()
                }
            }
            if (!completed) throw (lastError ?: MediaFailure("network", "Le téléchargement n’a pas pu reprendre."))
            task.checkActive()
            emit(task, "saving")
            val saved = DownloadStore(activity.applicationContext).save(
                File(directory, "media.${format.extension}"), catalog.title, format, task)
            savedUris[saved.getValue("uri") as String] = format.mimeType
            return saved
        } catch (error: Exception) {
            failure = error
            throw error
        } finally {
            // Keep fragments only after a network failure. They are scoped to this
            // generated task id, never to a user-chosen path.
            if (failure == null || task.cancelled.get() || !isNetworkFailure(failure!!)) {
                directory.deleteRecursively()
            }
        }
    }

    private fun emit(task: MediaTask, phase: String, percent: Double? = null, eta: Long? = null) {
        journal.update(task.id, phase)
        DownloadNotificationService.update(activity, task.id, when (phase) {
            "processing" -> "Traitement du média…"
            "saving" -> "Enregistrement du fichier…"
            else -> "Téléchargement en cours…"
        }, percent)
        main.post {
            if (!closed && active === task && !task.cancelled.get()) sink?.success(mapOf(
                "taskId" to task.id, "phase" to phase, "percent" to percent, "etaSeconds" to eta))
        }
    }

    private fun open(call: MethodCall, result: MethodChannel.Result) {
        val value = call.argument<String>("uri")
        val mime = value?.let { savedUris[it] } ?: call.argument<String>("mimeType")
        if (value == null || mime == null) {
            result.error("unknown_file", "Ce fichier n’est plus disponible.", null)
            return
        }
        try {
            val uri = Uri.parse(value)
            activity.contentResolver.openFileDescriptor(uri, "r")?.use { }
                ?: throw MediaFailure("missing_file", "Le fichier a été déplacé ou supprimé.")
            activity.startActivity(Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            })
            result.success(null)
        } catch (_: ActivityNotFoundException) {
            result.error("no_player", "Installez un lecteur compatible pour ouvrir ce format.", null)
        } catch (_: Exception) {
            result.error("missing_file", "Impossible d’ouvrir le fichier. Vérifiez qu’il existe dans Downloads.", null)
        }
    }

    private fun friendlyError(error: Exception, task: MediaTask, url: String?): MediaFailure {
        if (error is MediaFailure && error.code == "storage_partial") return error
        if (task.timedOut.get()) return MediaFailure("timeout", "L’analyse a pris trop de temps. Réessayez.")
        if (task.cancelled.get() || error is YoutubeDL.CanceledException || error is InterruptedException)
            return MediaFailure("cancelled", "Téléchargement annulé.")
        if (error is MediaFailure) return error
        val message = error.message.orEmpty().lowercase()
        val host = runCatching { java.net.URI(url.orEmpty()).host }.getOrNull().orEmpty()
        if (host == "instagram.com" || host.endsWith(".instagram.com")) return InstagramErrors.classify(message)
        return when {
            "no space left" in message || "enospc" in message -> MediaFailure("storage_full", "Le stockage est plein. Libérez de l’espace et réessayez.")
            error is SecurityException -> MediaFailure("permission_denied", "Android a refusé l’accès au stockage.")
            listOf("private", "sign in", "login", "log in", "cookies", "authentication").any { it in message } ->
                MediaFailure("unavailable", "Ce contenu nécessite une connexion ou n’est pas accessible publiquement.")
            "unsupported url" in message -> MediaFailure("unsupported_url", "Ce type de lien n’est pas pris en charge. Utilisez le lien direct de la publication vidéo.")
            "requested format" in message -> MediaFailure("format_expired", "Le format a changé. Analysez à nouveau le lien.")
            "drm" in message -> MediaFailure("drm", "Ce média est protégé et ne peut pas être téléchargé.")
            listOf("timed out", "unable to download", "network", "resolve", "http error").any { it in message } ->
                MediaFailure("network", "La plateforme ou le réseau a refusé la requête. Réessayez plus tard ou redémarrez le moteur.")
            else -> MediaFailure("engine_error", "Le moteur n’a pas pu traiter ce lien. Redémarrez le moteur et réessayez.")
        }
    }

    fun close() {
        closed = true
        // A foreground download belongs to Android, not to the Flutter view. It
        // must survive activity/engine disposal when the user leaves the app.
        if (activeOperation == "download" && active != null) {
            methods.setMethodCallHandler(null)
            events.setStreamHandler(null)
            sink = null
            return
        }
        active?.cancel()
        permissionRequest?.second?.error("cancelled", "Opération interrompue.", null)
        permissionRequest = null
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        sink = null
        worker.shutdownNow()
        if (active == null) watchdog.shutdown()
    }

    private fun isNetworkFailure(error: Exception): Boolean {
        if (error is MediaFailure && error.code == "network") return true
        val message = error.message.orEmpty().lowercase()
        return listOf("timed out", "timeout", "unable to download", "network", "resolve", "http error", "connection reset").any { it in message }
    }

    companion object {
        private const val STORAGE_PERMISSION = 4201
        private const val PICK_DOWNLOAD_LOCATION = 4202
        private const val LOCATION_PREFS = "download_location"
        private const val LOCATION_URI = "tree_uri"
        private val LOADY_FILE_NAME = Regex(".+-[0-9a-fA-F]{8}\\.(?:mp4|webm|mp3)")
        private const val MAX_NETWORK_ATTEMPTS = 3
        private const val RETRY_DELAY_MILLIS = 5_000L
    }
}
