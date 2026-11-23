package com.dazdownloader.dazdownloader

import android.app.Activity
import android.content.ActivityNotFoundException
import android.graphics.Bitmap
import androidx.core.graphics.drawable.toBitmap
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * Opens a platform's app by its package name rather than through its website
 * address: app links only claim some paths (X and Snapchat skip the home page)
 * and, with a Lite edition installed, Android may hand the link to either one.
 * Every package asked about must be listed in the manifest's <queries>.
 */
class AppLauncher(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    init {
        MethodChannel(messenger, "dazdownloader/apps").setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "installed" -> result.success(installed(call.argument<List<String>>("packages").orEmpty()))
            "launch" -> result.success(launch(call.argument<String>("package")))
            else -> result.notImplemented()
        }
    }

    /** The packages that can be launched, in the order asked, with their name and icon. */
    private fun installed(packages: List<String>): List<Map<String, Any?>> {
        val manager = activity.packageManager
        return packages.mapNotNull { name ->
            if (manager.getLaunchIntentForPackage(name) == null) return@mapNotNull null
            val info = runCatching { manager.getApplicationInfo(name, 0) }.getOrNull()
                ?: return@mapNotNull null
            mapOf(
                "package" to name,
                "label" to manager.getApplicationLabel(info).toString(),
                "icon" to runCatching { iconPng(manager.getApplicationIcon(info)) }.getOrNull(),
            )
        }
    }

    private fun iconPng(icon: android.graphics.drawable.Drawable): ByteArray {
        val size = (48 * activity.resources.displayMetrics.density).toInt().coerceAtLeast(48)
        return ByteArrayOutputStream().use { out ->
            icon.toBitmap(size, size).compress(Bitmap.CompressFormat.PNG, 100, out)
            out.toByteArray()
        }
    }

    private fun launch(name: String?): Boolean {
        val intent = name?.let { activity.packageManager.getLaunchIntentForPackage(it) } ?: return false
        return try {
            activity.startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }
}
