package com.opsedia.usra

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    /// Screenshots blocked by the app: the "Block screenshots" setting or a
    /// sensitive screen such as the recovery key (lib/core/screen_privacy.dart).
    private var secure = false
    private var resumed = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Health records must not show in the recent-apps switcher.
        // Android 13+ shows a blank card instead; older versions get
        // FLAG_SECURE while the app is in the background (onPause).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
    }

    override fun onPause() {
        resumed = false
        applySecure()
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        resumed = true
        applySecure()
    }

    private fun applySecure() {
        val hidden = !resumed && Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU
        if (secure || hidden) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Battery optimisation can stop medicine reminders on some phones;
        // the Medicines tab explains it and opens the setting.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "usra/battery")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringOptimizations" -> {
                        val power = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(power.isIgnoringBatteryOptimizations(packageName))
                    }
                    "openSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("unavailable", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        // FLAG_SECURE: no screenshots or screen recording.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "usra/screen_privacy")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        secure = call.arguments as? Boolean ?: false
                        runOnUiThread { applySecure() }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
