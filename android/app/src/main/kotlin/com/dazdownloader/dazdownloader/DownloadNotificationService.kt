package com.dazdownloader.dazdownloader

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class DownloadNotificationService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannel()
        when (intent?.action) {
            ACTION_START -> startForeground(NOTIFICATION_ID, notification("Téléchargement en cours…", null, false))
            ACTION_UPDATE -> {
                val percent = intent.getIntExtra(EXTRA_PERCENT, -1)
                NotificationManagerCompat.from(this).notify(
                    NOTIFICATION_ID,
                    notification(intent.getStringExtra(EXTRA_TEXT) ?: "Téléchargement en cours…", percent, true),
                )
            }
            ACTION_COMPLETE, ACTION_FAILED -> {
                val text = intent.getStringExtra(EXTRA_TEXT) ?: "Téléchargement terminé"
                stopForeground(STOP_FOREGROUND_REMOVE)
                // Someone looking at Loady already sees the outcome on screen.
                if (intent.getBooleanExtra(EXTRA_NOTIFY, true)) {
                    val file = intent.getStringExtra(EXTRA_URI)?.let { uri ->
                        intent.getStringExtra(EXTRA_MIME)?.let { mime -> openFile(uri, mime) }
                    }
                    NotificationManagerCompat.from(this).notify(DONE_NOTIFICATION_ID,
                        notification(text, null, false, true, file))
                }
                stopSelf()
            }
        }
        // The transfer itself runs in MediaBridge, not here. If Android kills
        // the process, a restarted service would only show "Téléchargement en
        // cours…" for a download that no longer exists. TransferJournal reports
        // the interruption on the next launch instead.
        return START_NOT_STICKY
    }

    private fun notification(
        text: String,
        percent: Int?,
        ongoing: Boolean,
        autoCancel: Boolean = false,
        file: PendingIntent? = null,
    ): Notification {
        val open = file ?: PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(com.dazdownloader.dazdownloader.R.drawable.ic_launcher)
            .setContentTitle("Loady")
            .setContentText(text)
            .setContentIntent(open)
            .setOngoing(ongoing)
            .setAutoCancel(autoCancel)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
        if (percent != null && percent >= 0) builder.setProgress(100, percent.coerceIn(0, 100), false)
        if (file != null) builder.addAction(0, "Ouvrir", file)
        return builder.build()
    }

    /** Opens the saved video or audio in the user's player. */
    private fun openFile(uri: String, mime: String): PendingIntent = PendingIntent.getActivity(
        this, 1,
        Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(Uri.parse(uri), mime)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        },
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Téléchargements", NotificationManager.IMPORTANCE_LOW)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    companion object {
        private const val CHANNEL_ID = "downloads"
        private const val NOTIFICATION_ID = 4100
        private const val DONE_NOTIFICATION_ID = 4101
        private const val ACTION_START = "start"
        private const val ACTION_UPDATE = "update"
        private const val ACTION_COMPLETE = "complete"
        private const val ACTION_FAILED = "failed"
        private const val EXTRA_TEXT = "text"
        private const val EXTRA_PERCENT = "percent"
        private const val EXTRA_URI = "uri"
        private const val EXTRA_MIME = "mime"
        private const val EXTRA_NOTIFY = "notify"

        fun start(context: Context, taskId: String) {
            val intent = base(context, ACTION_START, taskId)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else context.startService(intent)
        }

        fun update(context: Context, taskId: String, text: String, percent: Double?) {
            val intent = base(context, ACTION_UPDATE, taskId).putExtra(EXTRA_TEXT, text)
            if (percent != null && percent.isFinite()) intent.putExtra(EXTRA_PERCENT, percent.toInt())
            context.startService(intent)
        }

        fun complete(context: Context, text: String, uri: String?, mime: String?, notify: Boolean) {
            context.startService(base(context, ACTION_COMPLETE, text)
                .putExtra(EXTRA_URI, uri)
                .putExtra(EXTRA_MIME, mime)
                .putExtra(EXTRA_NOTIFY, notify))
        }

        fun failed(context: Context, text: String) = send(context, ACTION_FAILED, text)

        private fun send(context: Context, action: String, text: String) {
            context.startService(base(context, action, text).putExtra(EXTRA_TEXT, text))
        }

        private fun base(context: Context, action: String, value: String) =
            Intent(context, DownloadNotificationService::class.java).setAction(action)
                .putExtra(EXTRA_TEXT, value)
    }
}
