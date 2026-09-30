package com.dazdownloader.dazdownloader

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
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
    private val catalogs = linkedMapOf<String, MediaCatalog>() // Worker thread only.
    private val savedUris = ConcurrentHashMap<String, String>()
    private var sink: EventChannel.EventSink? = null
    @Volatile private var active: MediaTask? = null
    @Volatile private var closed = false
    private var permissionRequest: Pair<MethodCall, MethodChannel.Result>? = null

    init {
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
    override fun onCancel(arguments: Any?) { sink = null }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
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
            "resolve", "download", "update" -> {
                if (active != null || permissionRequest != null) {
                    result.error("busy", "Une opération est déjà en cours. Attendez ou annulez-la.", null)
                    return
                }
                if (call.method == "download" && Build.VERSION.SDK_INT <= 28 &&
                    activity.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                    permissionRequest = call to result
                    activity.requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), STORAGE_PERMISSION)
                } else launch(call, result)
            }
            else -> result.notImplemented()
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
                    if (active === task) active = null
                    if (!closed) {
                        val error = failure
                        if (error == null) result.success(value)
                        else result.error(error.code, error.message, mapOf(
                            "engineVersion" to (runtime.version ?: "non démarré"),
                            "androidApi" to Build.VERSION.SDK_INT,
                            "appVersion" to "1.1.0",
                            "operation" to call.method))
                    }
                }
                if (closed) watchdog.shutdown()
            }
        }
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
        var source = url
        if (TiktokPhotos.isTiktok(source)) {
            val client = PublicWebClient(task)
            val direct = TiktokPhotos.postId(source) != null
            try {
                var page = client.page(TiktokPhotos.pageUrl(source))
                if (TiktokPhotos.postId(page.url) != null && page.url != TiktokPhotos.pageUrl(page.url)) {
                    page = client.page(TiktokPhotos.pageUrl(page.url))
                }
                source = TiktokPhotos.pageUrl(page.url)
                val album = TiktokPhotos.parse(page.html, source)
                if (album != null) {
                    val catalog = album.catalog()
                    cache(url, catalog)
                    return catalog.toMap()
                }
            } catch (error: Exception) {
                task.checkActive()
                // Do not regress existing video extraction if the public page is blocked.
                // An explicit photo URL must never silently turn into a soundtrack/video.
                if ("/photo/" in url || "/photo/" in source) throw error
                if (!direct) source = url
            }
        }
        runtime.ensure(task)
        val request = request(source).apply {
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
        val root = File(activity.cacheDir, "media-downloads")
        if (!root.isDirectory && !root.mkdirs()) throw MediaFailure("storage", "Impossible de créer le fichier temporaire.")
        val directory = File(root, task.processId)
        if (!directory.mkdir()) throw MediaFailure("storage", "Impossible de préparer le téléchargement.")
        try {
            task.checkActive()
            if (catalog.photos != null) {
                val result = PhotoDownloader(activity.applicationContext).download(catalog.photos, directory, task) { phase, percent ->
                    emit(task, phase, percent)
                }
                @Suppress("UNCHECKED_CAST")
                (result["files"] as List<Map<String, Any>>).forEach {
                    savedUris[it["uri"] as String] = it["mimeType"] as String
                }
                return result
            }
            runtime.ensure(task)
            FFmpeg.init(activity.applicationContext)
            val request = request(url).apply {
                addOption("--no-simulate")
                addOption("--newline")
                addOption("--no-mtime")
                addOption("--no-overwrites")
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
            YoutubeDL.execute(request, task.processId, false) { percent, eta, line ->
                val processing = line.startsWith("[Merger]") || line.startsWith("[ExtractAudio]") ||
                    line.startsWith("[VideoRemuxer]") || line.startsWith("[Fixup")
                emit(task, if (processing) "processing" else "downloading",
                    if (!processing && percent.isFinite() && percent >= 0) percent.toDouble().coerceIn(0.0, 100.0) else null,
                    eta.takeIf { it > 0 })
            }
            task.checkActive()
            emit(task, "saving")
            val saved = DownloadStore(activity.applicationContext).save(
                File(directory, "media.${format.extension}"), catalog.title, format, task)
            savedUris[saved.getValue("uri") as String] = format.mimeType
            return saved
        } finally {
            // Only this operation's UUID directory, never a user-chosen path.
            directory.deleteRecursively()
        }
    }

    private fun emit(task: MediaTask, phase: String, percent: Double? = null, eta: Long? = null) {
        main.post {
            if (!closed && active === task && !task.cancelled.get()) sink?.success(mapOf(
                "taskId" to task.id, "phase" to phase, "percent" to percent, "etaSeconds" to eta))
        }
    }

    private fun open(call: MethodCall, result: MethodChannel.Result) {
        val value = call.argument<String>("uri")
        val mime = value?.let { savedUris[it] }
        if (value == null || mime == null) {
            result.error("unknown_file", "Ce fichier n’est plus disponible dans cette session.", null)
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
                MediaFailure("network", "La plateforme ou le réseau a refusé la requête. Réessayez plus tard ou mettez à jour le moteur.")
            else -> MediaFailure("engine_error", "Le moteur n’a pas pu traiter ce lien. Réessayez ou mettez à jour le moteur.")
        }
    }

    fun close() {
        closed = true
        active?.cancel()
        permissionRequest?.second?.error("cancelled", "Opération interrompue.", null)
        permissionRequest = null
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        sink = null
        worker.shutdownNow()
        if (active == null) watchdog.shutdown()
    }

    companion object { private const val STORAGE_PERMISSION = 4201 }
}
