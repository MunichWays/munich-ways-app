package com.munichways.munich_ways

import android.content.Intent
import android.net.Uri
import java.io.ByteArrayOutputStream
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var routeChannel: MethodChannel? = null
    private var routeClientReady = false
    private var pendingRoute: Any? = null

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receiveRoute(intent)
    }

    private fun receiveRoute(intent: Intent?) {
        val uri: Uri? = when (intent?.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                else @Suppress("DEPRECATION") (intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri)
            else -> null
        }
        if (uri == null || uri.scheme !in listOf("content", "file")) return
        Thread {
            val value: Any = try {
                contentResolver.openInputStream(uri).use { input ->
                    require(input != null)
                    val output = ByteArrayOutputStream()
                    val buffer = ByteArray(8192)
                    var count = input.read(buffer)
                    while (count >= 0) {
                        require(output.size() + count <= 4 * 1024 * 1024)
                        output.write(buffer, 0, count)
                        count = input.read(buffer)
                    }
                    output.toByteArray()
                }
            } catch (_: Exception) { "GPX could not be opened (maximum 4 MB)" }
            runOnUiThread {
                if (routeClientReady) routeChannel?.invokeMethod("gpx", value)
                else pendingRoute = value
            }
        }.start()
    }

    private var notificationPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        routeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.munichways/route_transfer")
        routeChannel?.setMethodCallHandler { call, result ->
            if (call.method == "initialGpx") {
                routeClientReady = true
                result.success(pendingRoute)
                pendingRoute = null
            } else result.notImplemented()
        }
        receiveRoute(intent)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATION_PERMISSION_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isGranted" -> result.success(isNotificationPermissionGranted())
                "request" -> requestNotificationPermission(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun isNotificationPermissionGranted(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (isNotificationPermissionGranted()) {
            result.success(true)
            return
        }
        if (notificationPermissionResult != null) {
            result.success(false)
            return
        }
        notificationPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST) return
        notificationPermissionResult?.success(
            grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        )
        notificationPermissionResult = null
    }

    companion object {
        private const val NOTIFICATION_PERMISSION_CHANNEL =
            "com.munichways.app/notification_permission"
        private const val NOTIFICATION_PERMISSION_REQUEST = 4102
    }
}
