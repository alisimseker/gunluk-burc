package com.alisimseker.gunluk_burc

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gunlukburc/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSign" -> {
                        val sign = call.argument<String>("sign")
                        val baseUrl = call.argument<String>("baseUrl")
                        if (sign != null && baseUrl != null) {
                            Store.save(this, sign, baseUrl)
                            DailyWorker.scheduleAll(this)
                            DailyWorker.runNow(this)
                        }
                        result.success(null)
                    }
                    "sync" -> {
                        if (Store.sign(this) != null) {
                            DailyWorker.scheduleAll(this)
                            DailyWorker.runNow(this)
                        }
                        result.success(null)
                    }
                    "notificationsEnabled" ->
                        result.success(NotificationManagerCompat.from(this).areNotificationsEnabled())
                    "requestNotificationPermission" -> requestPermission(result)
                    "openNotificationSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                        } catch (_: Exception) {
                        }
                        result.success(null)
                    }
                    "scheduleSkyEvents" -> {
                        @Suppress("UNCHECKED_CAST")
                        val list = (call.argument<List<Map<String, Any?>>>("events")) ?: emptyList()
                        SkyEventWorker.scheduleAll(this, list)
                        result.success(null)
                    }
                    "cancelSkyEvents" -> {
                        SkyEventWorker.cancelAll(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
            == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(NotificationManagerCompat.from(this).areNotificationsEnabled())
            return
        }
        pendingPermissionResult?.success(false)
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
            if (granted) DailyWorker.runNow(this)
        }
    }

    companion object {
        private const val REQ = 4711
    }
}
