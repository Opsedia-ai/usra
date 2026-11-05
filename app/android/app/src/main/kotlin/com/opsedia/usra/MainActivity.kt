package com.opsedia.usra

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

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

    /// A secret (the recovery key) copied by the app: when it's due to be
    /// cleared (elapsedRealtime) and the clip's timestamp, to tell whether
    /// it's still ours. See lib/core/security/sensitive_clipboard.dart.
    private var clipboardClearAt: Long? = null
    private var copiedStamp: Long? = null
    private val clipboardClear = Runnable { clearCopiedIfOurs() }

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

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        // Android 10+ only lets the focused app read the clipboard: a clear
        // that fell due in the background happens now.
        if (hasFocus) clearCopiedIfOurs()
    }

    private fun clipboard() = getSystemService(CLIPBOARD_SERVICE) as ClipboardManager

    /// Copies [text] marked sensitive: Android 13+ hides it in the "copied"
    /// preview and keyboards leave it out of their clipboard history.
    private fun copySensitive(text: String) {
        val clip = ClipData.newPlainText(SENSITIVE_CLIP_LABEL, text)
        clip.description.extras = PersistableBundle().apply {
            // ClipDescription.EXTRA_IS_SENSITIVE on 13+; the same key is
            // read by some keyboards on older versions.
            putBoolean("android.content.extra.IS_SENSITIVE", true)
        }
        val manager = clipboard()
        manager.setPrimaryClip(clip)
        copiedStamp = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.primaryClipDescription?.timestamp
        } else {
            null
        }
        clipboardClearAt = SystemClock.elapsedRealtime() + CLIPBOARD_LIFETIME_MS
        handler.removeCallbacks(clipboardClear)
        handler.postDelayed(clipboardClear, CLIPBOARD_LIFETIME_MS)
    }

    /// Clears the clipboard once the secret's time is up, unless something
    /// else was copied since. Waits for focus when it can't look.
    private fun clearCopiedIfOurs() {
        val due = clipboardClearAt ?: return
        val left = due - SystemClock.elapsedRealtime()
        if (left > 0) {
            handler.removeCallbacks(clipboardClear)
            handler.postDelayed(clipboardClear, left)
            return
        }
        if (!hasWindowFocus()) return
        clipboardClearAt = null
        val manager = clipboard()
        val description = manager.primaryClipDescription ?: return
        val stamp = copiedStamp
        val sameClip = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && stamp != null) {
            description.timestamp == stamp
        } else {
            true
        }
        if (description.label?.toString() != SENSITIVE_CLIP_LABEL || !sameClip) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            manager.clearPrimaryClip()
        } else {
            manager.setPrimaryClip(ClipData.newPlainText("", ""))
        }
    }

    /// Signs of a rooted phone, checked here only and never sent anywhere.
    /// Heuristics, not proof: Usra only warns (lib/core/security/device_integrity.dart).
    private fun rootSigns(): List<String> {
        val signs = mutableListOf<String>()
        if (Build.TAGS?.contains("test-keys") == true) signs.add("test-keys")
        val su = listOf(
            "/system/bin/su", "/system/xbin/su", "/sbin/su", "/su/bin/su",
            "/system/su", "/system/sbin/su", "/vendor/bin/su", "/data/local/su",
            "/data/local/bin/su", "/data/local/xbin/su", "/cache/su", "/dev/su",
            "/system/bin/.ext/.su", "/system/usr/we-need-root/su-backup",
            "/system/app/Superuser.apk", "/system/app/SuperSU.apk",
        )
        val path = System.getenv("PATH")?.split(":").orEmpty().map { "$it/su" }
        if ((su + path).any { safeExists(it) }) signs.add("su")
        val magisk = listOf(
            "/sbin/.magisk", "/cache/.disable_magisk", "/dev/.magisk.unblock",
            "/cache/magisk.log", "/data/adb/magisk", "/debug_ramdisk/magisk",
        )
        if (magisk.any { safeExists(it) }) signs.add("magisk")
        return signs
    }

    private fun safeExists(path: String): Boolean = try {
        File(path).exists()
    } catch (e: SecurityException) {
        false
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
        // The recovery key, copied sensitive and cleared after a minute.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "usra/clipboard")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "copySensitive" -> {
                        val text = call.arguments as? String
                        if (text == null) {
                            result.error("bad_args", null, null)
                        } else {
                            copySensitive(text)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        // Rooted phone warning (shown once, never blocks).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "usra/integrity")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "signs" -> result.success(rootSigns())
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
        const val CLIPBOARD_LIFETIME_MS = 60_000L
        const val SENSITIVE_CLIP_LABEL = "Usra recovery key"
    }
}
