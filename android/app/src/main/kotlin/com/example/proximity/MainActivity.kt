package com.example.proximity

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.proximity/alarm_wake"
    private val ALARM_NOTIFICATION_CHANNEL = "proximity_alarm"
    private val ALARM_NOTIFICATION_ID = 701
    private val ALARM_ACTION = "com.example.proximity.SHOW_ALARM"
    private var pendingAlarm: HashMap<String, Any?>? = null
    private var alarmChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleAlarmIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAlarmIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        alarmChannel = channel
        channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "wakeUpScreen" -> {
                        wakeUpScreen()
                        result.success(true)
                    }
                    "clearWakeFlags" -> {
                        clearWakeFlags()
                        result.success(true)
                    }
                    "triggerAlarm" -> {
                        val details = hashMapOf<String, Any?>()
                        (call.arguments as? Map<*, *>)?.forEach { (key, value) ->
                            if (key is String) details[key] = value
                        }
                        pendingAlarm = details
                        postAlarmNotification(details)
                        wakeUpScreen()
                        result.success(true)
                    }
                    "consumePendingAlarm" -> {
                        result.success(pendingAlarm)
                    }
                    "clearAlarm" -> {
                        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                            .cancel(ALARM_NOTIFICATION_ID)
                        pendingAlarm = null
                        clearWakeFlags()
                        result.success(true)
                    }
                    "canUseFullScreenIntent" -> {
                        val allowed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                                .canUseFullScreenIntent()
                        } else {
                            true
                        }
                        result.success(allowed)
                    }
                    "requestFullScreenIntentAccess" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                            startActivity(Intent(
                                Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                                Uri.parse("package:$packageName"),
                            ))
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // If Android launched this activity from a full-screen alarm intent,
        // the Flutter UI can now read the exact persisted payload.
    }

    private fun handleAlarmIntent(intent: Intent?) {
        if (intent?.action != ALARM_ACTION) return
        val details = hashMapOf<String, Any?>(
            "id" to intent.getStringExtra("id"),
            "destinationName" to intent.getStringExtra("destinationName"),
            "distance" to intent.getStringExtra("distance"),
            "eta" to intent.getStringExtra("eta"),
        )
        pendingAlarm = details
        wakeUpScreen()
        // Existing Flutter engines receive this immediately; a cold launch is
        // recovered through consumePendingAlarm once HomeScreen is mounted.
        alarmChannel?.invokeMethod("alarmTriggered", details)
    }

    private fun postAlarmNotification(details: Map<String, Any?>) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createAlarmChannel(manager)

        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            action = ALARM_ACTION
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("id", details["id"]?.toString())
            putExtra("destinationName", details["destinationName"]?.toString())
            putExtra("distance", details["distance"]?.toString())
            putExtra("eta", details["eta"]?.toString())
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            ALARM_NOTIFICATION_ID,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val destination = details["destinationName"]?.toString() ?: "your destination"
        val content = "You are near $destination. Complete your snooze method."
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, ALARM_NOTIFICATION_CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        builder
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("Proximity alarm")
            .setContentText(content)
            .setCategory(Notification.CATEGORY_ALARM)
            .setPriority(Notification.PRIORITY_MAX)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(pendingIntent)
            .setFullScreenIntent(pendingIntent, true)
        manager.notify(ALARM_NOTIFICATION_ID, builder.build())
    }

    private fun createAlarmChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .build()
        val channel = NotificationChannel(
            ALARM_NOTIFICATION_CHANNEL,
            "Proximity alarms",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Alerts when you are near an active destination."
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM), audioAttributes)
            enableVibration(true)
        }
        manager.createNotificationChannel(channel)
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

        // Show over the lock screen and keep the alarm display awake. A secure
        // keyguard is intentionally not dismissed: normal consumer apps cannot
        // and should not bypass a user's device security.
        runOnUiThread {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
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
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
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
