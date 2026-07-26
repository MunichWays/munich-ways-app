package com.munichways.munich_ways

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var notificationPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATION_PERMISSION_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method != "request") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
            ) {
                result.success(true)
                return@setMethodCallHandler
            }
            if (notificationPermissionResult != null) {
                result.success(false)
                return@setMethodCallHandler
            }
            notificationPermissionResult = result
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST
            )
        }
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
