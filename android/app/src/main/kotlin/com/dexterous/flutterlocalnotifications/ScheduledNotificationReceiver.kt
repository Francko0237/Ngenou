package com.dexterous.flutterlocalnotifications

import android.app.Notification
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.annotation.Keep
import androidx.core.app.NotificationManagerCompat
import com.dexterous.flutterlocalnotifications.models.NotificationDetails
import com.dexterous.flutterlocalnotifications.utils.StringUtils
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

/**
 * Custom wrapper shadowing the original ScheduledNotificationReceiver from flutter_local_notifications.
 *
 * This implementation runs first when an alarm fires, checking if the SharedPreferences contain
 * corrupted data (from older package versions) and clearing it if needed to prevent background crashes.
 * It then executes the same logic as the original receiver under a safe try-catch wrapper.
 */
@Keep
class ScheduledNotificationReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ScheduledNotifReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        // Clean up corrupt SharedPreferences before the plugin code reads them
        try {
            val prefs = context.getSharedPreferences(
                "scheduled_notifications",
                Context.MODE_PRIVATE
            )
            val json = prefs.getString("scheduled_notifications", null)
            if (json != null && isCorrupted(json)) {
                Log.w(TAG, "Corrupt scheduled notifications found in cache. Clearing it.")
                prefs.edit().clear().apply()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking/clearing shared preferences: ${e.message}")
        }

        // Delegate to original logic with a safe try-catch
        try {
            val notificationDetailsJson = intent.getStringExtra(FlutterLocalNotificationsPlugin.NOTIFICATION_DETAILS)
            if (StringUtils.isNullOrEmpty(notificationDetailsJson)) {
                val notificationId = intent.getIntExtra("notification_id", 0)
                val notification: Notification? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra("notification", Notification::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra("notification")
                }

                if (notification == null) {
                    FlutterLocalNotificationsPlugin.removeNotificationFromCache(context, notificationId)
                    Log.e(TAG, "Failed to parse a notification from Intent. ID: $notificationId")
                    return
                }

                notification.`when` = System.currentTimeMillis()
                val notificationManager = NotificationManagerCompat.from(context)
                notificationManager.notify(notificationId, notification)
                val repeat = intent.getBooleanExtra("repeat", false)
                if (!repeat) {
                    FlutterLocalNotificationsPlugin.removeNotificationFromCache(context, notificationId)
                }
            } else {
                val gson = FlutterLocalNotificationsPlugin.buildGson()
                val type = object : TypeToken<NotificationDetails>() {}.type
                val notificationDetails = gson.fromJson<NotificationDetails>(notificationDetailsJson, type)

                FlutterLocalNotificationsPlugin.showNotification(context, notificationDetails)
                FlutterLocalNotificationsPlugin.scheduleNextNotification(context, notificationDetails)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in ScheduledNotificationReceiver: ${e.message}", e)
            // Fallback: clear preferences to avoid subsequent loops/crashes
            try {
                context.getSharedPreferences("scheduled_notifications", Context.MODE_PRIVATE)
                    .edit().clear().apply()
            } catch (ex: Exception) {
                // ignore
            }
        }
    }

    private fun isCorrupted(json: String): Boolean {
        return try {
            json.trim().isEmpty() || json == "null" || json == "[]"
        } catch (e: Exception) {
            false
        }
    }
}
