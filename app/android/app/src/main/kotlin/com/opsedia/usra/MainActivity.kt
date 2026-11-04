package com.opsedia.usra

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// A FragmentActivity so the app lock can show the system biometric prompt
// (local_auth).
class MainActivity : FlutterFragmentActivity() {
    /// Screenshots blocked by the app: the "Block screenshots" setting or a
    /// sensitive screen such as the recovery key (lib/core/screen_privacy.dart).
    private var secure = false

    /// The app lock is on: the cover stays after resume until Dart has
    /// drawn the lock (or decided there's none) and calls "uncover".
    private var coverUntilReady = false

    /// The launch screen over the app while it's in the background.
    private var cover: View? = null
    private var resumed = false
    private val handler = Handler(Looper.getMainLooper())
    private val uncoverFallback = Runnable { removeCover() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Health records must not show in the recent-apps switcher. Android
        // 13+ shows a blank card; older versions snapshot the window once
        // it's hidden, by which time the cover from onPause is drawn.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
    }

    override fun onPause() {
        // Not in split screen, where the app stays visible while paused.
        val needed = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || coverUntilReady
        if (needed && !isInMultiWindowMode) addCover()
        resumed = false
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        resumed = true
        if (!coverUntilReady) {
            removeCover()
        } else if (cover != null) {
            // Never stuck: Dart normally uncovers within a frame or two.
            handler.removeCallbacks(uncoverFallback)
            handler.postDelayed(uncoverFallback, UNCOVER_FALLBACK_MS)
        }
    }

    private fun addCover() {
        if (cover != null) return
        val view = View(this).apply {
            background = getDrawable(R.drawable.launch_background)
            isClickable = true
        }
        addContentView(
            view,
            ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
        )
        cover = view
    }

    private fun removeCover() {
        handler.removeCallbacks(uncoverFallback)
        cover?.let { (it.parent as? ViewGroup)?.removeView(it) }
        cover = null
    }

    private fun applySecure() {
        if (secure) {
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
        // The app lock measures time away with this: it counts while the
        // phone sleeps and can't be changed in the phone's settings.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "usra/clock")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "elapsedRealtime" -> result.success(SystemClock.elapsedRealtime())
                    else -> result.notImplemented()
                }
            }
        // FLAG_SECURE (no screenshots or screen recording) and the
        // background cover; see lib/core/screen_privacy.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "usra/screen_privacy")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        secure = call.arguments as? Boolean ?: false
                        applySecure()
                        result.success(null)
                    }
                    "coverUntilReady" -> {
                        coverUntilReady = call.arguments as? Boolean ?: false
                        if (!coverUntilReady && resumed) removeCover()
                        result.success(null)
                    }
                    "uncover" -> {
                        if (resumed) removeCover()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        const val UNCOVER_FALLBACK_MS = 3000L
    }
}
