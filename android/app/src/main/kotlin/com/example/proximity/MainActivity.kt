package com.example.proximity

import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.proximity/alarm_wake"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "wakeUpScreen" -> {
                        wakeUpScreen()
                        result.success(true)
                    }
                    "clearWakeFlags" -> {
                        clearWakeFlags()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Wakes the screen and shows the activity over the lock screen.
     * This is the same mechanism Android's default Clock app uses.
     */
    private fun wakeUpScreen() {
        // Turn the screen on via PowerManager wake lock.
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = pm.newWakeLock(
            PowerManager.FULL_WAKE_LOCK
                or PowerManager.ACQUIRE_CAUSES_WAKEUP
                or PowerManager.ON_AFTER_RELEASE,
            "proximity:alarm_wake_lock"
        )
        wakeLock.acquire(30_000L) // 30 seconds max, auto-releases

        // Set window flags to show over lock screen and keep screen on.
        runOnUiThread {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
                // Dismiss the keyguard so the user doesn't need to unlock.
                val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                km.requestDismissKeyguard(this, null)
            } else {
                @Suppress("DEPRECATION")
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                        or WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                        or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                        or WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                )
            }
        }
    }

    /**
     * Clears the wake/lock-screen flags after the alarm is dismissed,
     * restoring normal lock-screen behavior.
     */
    private fun clearWakeFlags() {
        runOnUiThread {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(false)
                setTurnScreenOn(false)
            } else {
                @Suppress("DEPRECATION")
                window.clearFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                        or WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                        or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                        or WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                )
            }
        }
    }
}
