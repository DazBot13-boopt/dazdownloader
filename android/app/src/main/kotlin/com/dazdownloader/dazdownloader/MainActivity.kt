package com.dazdownloader.dazdownloader

import android.Manifest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var mediaBridge: MediaBridge? = null
    private var pendingSharedText: String? = null
    private var shareSink: EventChannel.EventSink? = null
    private var pendingTransferOpen = false
    private var transferNavigationSink: EventChannel.EventSink? = null

    override fun onCreate(state: android.os.Bundle?) {
        pendingSharedText = sharedText(intent)
        pendingTransferOpen = intent?.getBooleanExtra(EXTRA_OPEN_TRANSFER, false) == true
        super.onCreate(state)
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_PERMISSION)
        }
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dazdownloader/transfer_navigation")
            .setMethodCallHandler { call, result ->
                if (call.method == "pending") {
                    result.success(pendingTransferOpen)
                    pendingTransferOpen = false
                } else result.notImplemented()
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "dazdownloader/transfer_navigation/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    transferNavigationSink = events
                }
                override fun onCancel(arguments: Any?) {
                    transferNavigationSink = null
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
        if (intent.getBooleanExtra(EXTRA_OPEN_TRANSFER, false)) {
            if (transferNavigationSink != null) {
                transferNavigationSink?.success(true)
                pendingTransferOpen = false
            } else pendingTransferOpen = true
        }
    }

    @Deprecated("Deprecated in Android API")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (mediaBridge?.onActivityResult(requestCode, resultCode, data) != true) {
            super.onActivityResult(requestCode, resultCode, data)
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

    companion object {
        private const val NOTIFICATION_PERMISSION = 4301
        private const val EXTRA_OPEN_TRANSFER = "open_transfer"
    }
}
