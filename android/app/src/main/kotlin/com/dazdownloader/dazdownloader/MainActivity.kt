package com.dazdownloader.dazdownloader

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.content.Intent
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var mediaBridge: MediaBridge? = null
    private var pendingSharedText: String? = null
    private var shareSink: EventChannel.EventSink? = null

    override fun onCreate(state: android.os.Bundle?) {
        pendingSharedText = sharedText(intent)
        super.onCreate(state)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        mediaBridge = MediaBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dazdownloader/share")
            .setMethodCallHandler { call, result ->
                if (call.method == "pending") {
                    result.success(pendingSharedText)
                    pendingSharedText = null
                } else result.notImplemented()
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "dazdownloader/share/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    shareSink = events
                }

                override fun onCancel(arguments: Any?) {
                    shareSink = null
                }
            })
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        sharedText(intent)?.let { text ->
            pendingSharedText = text
            shareSink?.success(text)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        mediaBridge?.close()
        mediaBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (mediaBridge?.onPermissionResult(requestCode, grantResults) != true) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }

    private fun sharedText(intent: Intent?): String? =
        intent?.takeIf { it.action == Intent.ACTION_SEND }
            ?.getStringExtra(Intent.EXTRA_TEXT)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
}
