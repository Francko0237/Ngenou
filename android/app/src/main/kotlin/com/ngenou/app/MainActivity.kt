package com.ngenou.app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import androidx.core.content.FileProvider
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    private val FILE_CHANNEL = "com.ngenou.app/file_provider"
    private val SDK_CHANNEL = "com.ngenou.app/sdk_version"
    private val WIDGET_CHANNEL = "com.ngenou.app/widget"
    private val WIDGET_EVENTS_CHANNEL = "com.ngenou.app/widget_events"

    // Action transmise par les widgets (stockée jusqu'à ce que Flutter soit prêt au démarrage)
    private var pendingWidgetAction: String? = null
    // Sink pour pousser des actions en temps réel quand l'app est déjà ouverte
    private var widgetEventSink: EventChannel.EventSink? = null

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleWidgetIntent(intent, fromNewIntent = true)
    }

    private fun handleWidgetIntent(intent: Intent?, fromNewIntent: Boolean = false) {
        val action = when (intent?.action) {
            "OPEN_TASKS" -> "open_tasks"
            "ADD_TASK"   -> "add_task"
            "OPEN_DEFIS" -> "open_defis"
            else         -> return
        }
        if (fromNewIntent && widgetEventSink != null) {
            // App déjà lancée : pousser l'action en temps réel
            widgetEventSink?.success(action)
        } else {
            // Démarrage à froid : stocker pour que Flutter la lise via getInitialAction
            pendingWidgetAction = action
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // EventChannel : actions en temps réel quand l'app est déjà ouverte
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_EVENTS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    widgetEventSink = sink
                }
                override fun onCancel(args: Any?) {
                    widgetEventSink = null
                }
            })

        // MethodChannel : action au démarrage à froid
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialAction" -> {
                        result.success(pendingWidgetAction)
                        pendingWidgetAction = null
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getUriForFile") {
                    val filePath = call.arguments as? String
                    if (filePath != null) {
                        try {
                            val file = File(filePath)
                            val uri = FileProvider.getUriForFile(
                                this,
                                "${packageName}.fileprovider",
                                file
                            )
                            result.success(uri.toString())
                        } catch (e: Exception) {
                            result.error("URI_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "File path is null", null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SDK_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDeviceBrand" -> {
                        result.success(Build.MANUFACTURER.lowercase())
                    }
                    "getSdkInt" -> {
                        result.success(Build.VERSION.SDK_INT)
                    }
                    "triggerVibration" -> {
                        result.success(null)
                        val durationMs = (call.arguments as? Int) ?: 1000
                        vibrate(durationMs.toLong())
                    }
                    "isBatteryOptimizationExempted" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        val exempted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            pm.isIgnoringBatteryOptimizations(packageName)
                        } else {
                            true
                        }
                        result.success(exempted)
                    }
                    "requestBatteryOptimizationExemption" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val pm = getSystemService(POWER_SERVICE) as PowerManager
                            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                                result.success(false)
                                try {
                                    val intent = Intent(
                                        Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                        Uri.parse("package:$packageName")
                                    )
                                    startActivity(intent)
                                } catch (e: Exception) {
                                    try {
                                        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                                        startActivity(intent)
                                    } catch (_: Exception) {}
                                }
                            } else {
                                result.success(true)
                            }
                        } else {
                            result.success(true)
                        }
                    }
                    "openBatteryOptimizationSettings" -> {
                        result.success(null)
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                val intent = Intent(
                                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:$packageName")
                                )
                                startActivity(intent)
                            }
                        } catch (e: Exception) {
                            try {
                                val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                                startActivity(intent)
                            } catch (_: Exception) {}
                        }
                    }
                    "openAppSettings" -> {
                        result.success(null)
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName"))
                            startActivity(intent)
                        } catch (_: Exception) {}
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun vibrate(durationMs: Long) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Android 12+ : VibratorManager
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                val vibrator = vm.defaultVibrator
                val pattern = longArrayOf(0, 300, 150, 500, 150, 800, 150, 500)
                val effect = VibrationEffect.createWaveform(pattern, -1)
                vibrator.vibrate(effect)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // Android 8-11 : Vibrator avec VibrationEffect
                @Suppress("DEPRECATION")
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                val pattern = longArrayOf(0, 300, 150, 500, 150, 800, 150, 500)
                val effect = VibrationEffect.createWaveform(pattern, -1)
                vibrator.vibrate(effect)
            } else {
                // Android < 8 : API dépréciée mais fonctionnelle
                @Suppress("DEPRECATION")
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                val pattern = longArrayOf(0, 300, 150, 500, 150, 800, 150, 500)
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern, -1)
            }
        } catch (e: Exception) {
            // Vibration non disponible sur cet appareil — ignorer silencieusement
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Nettoie les SharedPreferences de flutter_local_notifications si elles
        // contiennent des données au format corrompu (mélange v17/v18).
        // On efface inconditionnellement — les alarmes seront replanifiées
        // par rescheduleAll() au démarrage de Flutter.
        try {
            val fln = applicationContext.getSharedPreferences(
                "scheduled_notifications", Context.MODE_PRIVATE
            )
            val json = fln.getString("scheduled_notifications", null)
            // Effacer si le JSON existe et est dans un format potentiellement corrompu
            if (json != null && json.isNotEmpty() && json != "[]") {
                // Vérification simple : un JSON v18 valide contient "scheduleMode"
                // Un JSON v17 valide contient "repeatInterval" ou "matchDateTimeComponents"
                // Un JSON corrompu ne contient ni l'un ni l'autre correctement
                val hasV18Field = json.contains("\"scheduleMode\"")
                val hasV17Field = json.contains("\"repeatInterval\"") || 
                                  json.contains("\"scheduledNotificationRepeatFrequency\"")
                // Si c'est du v18 pur ou corrompu → effacer pour repartir propre
                if (!hasV17Field || hasV18Field) {
                    fln.edit().clear().apply()
                }
            }
        } catch (_: Exception) {}

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        installSplashScreen()
        super.onCreate(savedInstanceState)
        // Capture l'intent initial (déclenchement depuis un widget)
        handleWidgetIntent(intent)
    }
}
