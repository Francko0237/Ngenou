import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';
import '../database/database_helper.dart';
import '../models/study_task.dart';
import 'file_provider_helper.dart';

typedef TaskAlarmCallback = void Function(StudyTask task, String action);

class ScheduleNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static TaskAlarmCallback? onAlarmAction;
  static bool _initialized = false;
  static bool? _exactAlarmsGranted;
  static final Set<String> _acknowledgedTaskIds = {};
  static final Map<String, DateTime> _lastImmediateShown = {};
  static DateTime? _suppressDueCheckUntil;
  static String? _lastHandledPayload;
  static DateTime? _lastHandledAt;

  // Version globale du canal — incrémenter ici force Android à créer un canal
  // avec un nouvel ID, ce qui contourne son cache de paramètres.
  static const int _channelVersion = 3;
  static const String _channelBase = 'ngenou_alarm_v$_channelVersion';

  static Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Europe/Paris'));
      } catch (_) {
        tz.setLocalLocation(tz.local);
      }
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const linux = LinuxInitializationSettings(defaultActionName: 'Ouvrir');
    const initSettings = InitializationSettings(android: android, linux: linux);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundResponse,
    );

    if (Platform.isAndroid) {
      await _ensureChannelsClean();
    }

    _initialized = true;
  }

  /// Supprime tous les anciens canaux (versions précédentes) et crée le canal
  /// courant si nécessaire. Appelé une seule fois à l'init.
  static Future<void> _ensureChannelsClean() async {
    final androidPlugin = _androidPlugin;
    if (androidPlugin == null) return;

    final soundName = await _getActiveSound();
    final channelId = _buildChannelId(soundName);

    final existing = await androidPlugin.getNotificationChannels() ?? [];

    // Supprimer tous les canaux Ngenou qui ne correspondent PAS au canal actuel
    for (final ch in existing) {
      if (ch.id.startsWith('ngenou') && ch.id != channelId) {
        await androidPlugin.deleteNotificationChannel(ch.id);
        debugPrint('Deleted old channel: ${ch.id}');
      }
    }

    // Créer le canal actuel s'il n'existe pas encore
    final alreadyExists = existing.any((ch) => ch.id == channelId);
    if (!alreadyExists) {
      await _createChannel(androidPlugin, channelId, soundName);
      debugPrint('Created channel: $channelId');
    }
  }

  /// Construit l'ID de canal pour un son donné.
  static String _buildChannelId(String soundName) {
    if (soundName == 'alarm_classic' || soundName == 'system') {
      return '${_channelBase}_classic';
    }
    if (soundName == 'alarm_digital') return '${_channelBase}_digital';
    if (soundName == 'alarm_gentle') return '${_channelBase}_gentle';
    // Son custom : hash du chemin
    return '${_channelBase}_custom_${soundName.hashCode.abs()}';
  }

  /// Crée un canal Android avec tous les paramètres corrects.
  static Future<void> _createChannel(
    AndroidFlutterLocalNotificationsPlugin plugin,
    String channelId,
    String soundName,
  ) async {
    AndroidNotificationSound? notifSound;

    if (soundName != 'system') {
      if (soundName.startsWith('content://')) {
        notifSound = UriAndroidNotificationSound(soundName);
      } else if (soundName.startsWith('/') || soundName.startsWith('file://')) {
        final filePath = soundName.startsWith('file://')
            ? Uri.parse(soundName).toFilePath()
            : soundName;
        final contentUri = await FileProviderHelper.getContentUri(filePath);
        if (contentUri != null) {
          notifSound = UriAndroidNotificationSound(contentUri);
        } else {
          // FileProvider a échoué → son de secours depuis res/raw
          notifSound = const RawResourceAndroidNotificationSound(
            'alarm_classic',
          );
        }
      } else {
        // Ressource compilée dans res/raw (alarm_classic, alarm_digital, etc.)
        final resName = soundName.replaceAll(RegExp(r'\.wav$'), '');
        notifSound = RawResourceAndroidNotificationSound(resName);
      }
    }
    // soundName == 'system' → notifSound reste null → son par défaut du système

    await plugin.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        'Alarmes Ngenou',
        description: 'Alarmes de révision — Ngenou',
        importance: Importance.max,
        playSound: true,
        sound: notifSound,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 400, 200, 600, 200, 1000]),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableLights: true,
        ledColor: const Color(0xFF4A90D9),
      ),
    );
  }

  /// Appelé quand l'utilisateur change de son — force un nouveau canal.
  static Future<void> onSoundChanged(String newSoundName) async {
    if (!Platform.isAndroid) return;
    if (!_initialized) await init();
    await _ensureChannelsClean();
  }

  /// Notifications + alarmes exactes + plein écran (Android).
  /// Conditionné par la version Android — ne demande que ce qui existe sur l'API cible.
  static Future<void> ensureAllAndroidPermissions() async {
    if (!Platform.isAndroid) return;
    if (!_initialized) await init();
    final androidPlugin = _androidPlugin;
    if (androidPlugin == null) return;

    // POST_NOTIFICATIONS : n'existe que sur Android 13+ (API 33).
    final sdkInt = await _getAndroidSdkInt();
    if (sdkInt >= 33) {
      final alreadyGranted =
          await androidPlugin.areNotificationsEnabled() ?? false;
      if (!alreadyGranted) {
        await androidPlugin.requestNotificationsPermission();
      }
    }

    // SCHEDULE_EXACT_ALARM : n'existe que sur Android 12+ (API 31).
    if (sdkInt >= 31) {
      await ensureExactAlarmsPermission();
    } else {
      _exactAlarmsGranted = true;
    }

    // USE_FULL_SCREEN_INTENT en mode "demander" : API 34+ seulement.
    if (sdkInt >= 34) {
      await androidPlugin.requestFullScreenIntentPermission();
    }

    // Note : l'exemption batterie est gérée par l'onboarding BrandSetupPage
    // au premier lancement. On ne la demande pas ici pour éviter un double
    // appel conflictuel avec le MethodChannel quand Android suspend l'Activity.
  }

  /// Demande l'exemption d'optimisation batterie (Doze mode).
  /// Retourne true si déjà exemptée ou après demande.
  static Future<bool> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await const MethodChannel(
        'com.ngenou.app/sdk_version',
      ).invokeMethod<bool>('requestBatteryOptimizationExemption');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Vérifie si l'app est déjà exemptée de l'optimisation batterie.
  static Future<bool> isBatteryOptimizationExempted() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await const MethodChannel(
        'com.ngenou.app/sdk_version',
      ).invokeMethod<bool>('isBatteryOptimizationExempted');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Vérifie si les notifications sont activées pour l'app.
  /// Sur Android < 13, toujours true (pas de permission runtime).
  static Future<bool> areNotificationsEnabled() async {
    if (!Platform.isAndroid) return true;
    try {
      final sdkInt = await _getAndroidSdkInt();
      if (sdkInt < 33) return true; // Android < 13 : toujours accordé
      final enabled = await _androidPlugin?.areNotificationsEnabled() ?? true;
      return enabled;
    } catch (_) {
      return true;
    }
  }

  /// Ouvre les réglages battery optimization de l'app directement.
  static Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await const MethodChannel(
        'com.ngenou.app/sdk_version',
      ).invokeMethod<void>('openBatteryOptimizationSettings');
    } catch (_) {}
  }

  /// Récupère le SDK Android via MethodChannel natif.
  static Future<int> _getAndroidSdkInt() async {
    try {
      final result = await const MethodChannel(
        'com.ngenou.app/sdk_version',
      ).invokeMethod<int>('getSdkInt');
      return result ?? 26;
    } catch (_) {
      // Fallback conservateur : on suppose Android 8 (API 26).
      return 26;
    }
  }

  static bool isTaskAcknowledged(String taskId) =>
      _acknowledgedTaskIds.contains(taskId);

  static void acknowledgeTask(String taskId) {
    _acknowledgedTaskIds.add(taskId);
    _suppressDueCheckUntil = DateTime.now().add(const Duration(minutes: 2));
  }

  static void clearTaskAcknowledgement(String taskId) {
    _acknowledgedTaskIds.remove(taskId);
    _lastImmediateShown.remove(taskId);
  }

  /// Marque une tâche comme "dialog en cours" pour éviter les doublons
  /// quand l'app est au premier plan.
  static void markImmediateShown(String taskId) {
    _lastImmediateShown[taskId] = DateTime.now();
    _suppressDueCheckUntil = DateTime.now().add(const Duration(minutes: 2));
  }

  static bool shouldSuppressDueChecks() =>
      _suppressDueCheckUntil != null &&
      DateTime.now().isBefore(_suppressDueCheckUntil!);

  static Future<void> dismissTaskNotifications(String taskId) async {
    if (!_initialized) await init();
    await _plugin.cancel(_notifIdForTask(taskId));
    await _plugin.cancel(_notifIdForTask('${taskId}_now'));
  }

  /// À appeler au démarrage si l'app a été ouverte via une notification.
  static Future<void> handleLaunchNotification() async {
    if (!_initialized) await init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return;
    final response = details!.notificationResponse;
    if (response != null) _onResponse(response);
  }

  static AndroidFlutterLocalNotificationsPlugin? get _androidPlugin => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Android 12+ : ouvre les réglages « Alarmes et rappels » si nécessaire.
  static Future<bool> ensureExactAlarmsPermission() async {
    if (!Platform.isAndroid) return true;
    if (!_initialized) await init();
    final granted = await _androidPlugin?.requestExactAlarmsPermission();
    _exactAlarmsGranted = granted ?? false;
    return _exactAlarmsGranted!;
  }

  static bool get exactAlarmsGranted => _exactAlarmsGranted ?? false;

  @pragma('vm:entry-point')
  static void _onBackgroundResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) return;

    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final task = StudyTask.fromMap(map);
      final action = response.actionId;

      WidgetsFlutterBinding.ensureInitialized();
      await init();

      final db = DatabaseHelper.instance;

      if (action == 'snooze') {
        await dismissTaskNotifications(task.id);
        await cancelTask(task.id);

        final snoozed = task.copyWith(
          scheduledAt: DateTime.now().add(const Duration(minutes: 5)),
          status: TaskStatus.snoozed,
        );

        await db.updateTask(snoozed);
        await scheduleTask(snoozed);
      } else if (action == 'dismiss') {
        await dismissTaskNotifications(task.id);
        await cancelTask(task.id);

        final cancelled = task.copyWith(status: TaskStatus.cancelled);
        await db.updateTask(cancelled);
      }
    } catch (e, st) {
      debugPrint('Error handling background notification response: $e\n$st');
    }
  }

  static void _onResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    final now = DateTime.now();
    if (_lastHandledPayload == payload &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < const Duration(seconds: 4)) {
      return;
    }
    _lastHandledPayload = payload;
    _lastHandledAt = now;

    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final task = StudyTask.fromMap(map);
      final action = response.actionId ?? 'open';

      // On dismiss la notif immédiatement
      dismissTaskNotifications(task.id);

      // acknowledgeTask seulement pour les actions définitives (pas 'open')
      // Pour 'open', c'est _handleAlarmNotification qui gère l'acknowledgement
      // après que l'utilisateur ait interagi avec le dialog.
      if (action != 'open') {
        acknowledgeTask(task.id);
      }

      onAlarmAction?.call(task, action);
    } catch (e) {
      debugPrint('Notification payload error: $e');
    }
  }

  static int _notifIdForTask(String taskId) =>
      taskId.hashCode.abs() % 2147483647;

  static Future<String> _getActiveSound() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('alarmSound') ?? 'alarm_classic';
  }

  // _cleanChannelId et ensureChannelForSound sont remplacés par _buildChannelId
  // et _createChannel ci-dessus. Cette méthode est gardée pour compatibilité.
  static Future<void> ensureChannelForSound(String soundName) async {
    if (!Platform.isAndroid) return;
    if (!_initialized) await init();
    final androidPlugin = _androidPlugin;
    if (androidPlugin == null) return;
    final channelId = _buildChannelId(soundName);
    final existing = await androidPlugin.getNotificationChannels() ?? [];
    if (!existing.any((ch) => ch.id == channelId)) {
      await _createChannel(androidPlugin, channelId, soundName);
    }
  }

  static Future<AndroidNotificationDetails> _androidAlarmDetails() async {
    final soundName = await _getActiveSound();
    final channelId = _buildChannelId(soundName);

    // S'assurer que le canal existe
    final androidPlugin = _androidPlugin;
    if (androidPlugin != null) {
      final existing = await androidPlugin.getNotificationChannels() ?? [];
      if (!existing.any((ch) => ch.id == channelId)) {
        await _createChannel(androidPlugin, channelId, soundName);
      }
    }

    // Le son dans AndroidNotificationDetails doit correspondre exactement
    // à celui du canal — sinon Android utilise le son du canal et ignore celui-ci.
    AndroidNotificationSound? notifSound;
    if (soundName != 'system') {
      if (soundName.startsWith('content://')) {
        notifSound = UriAndroidNotificationSound(soundName);
      } else if (soundName.startsWith('/') || soundName.startsWith('file://')) {
        final filePath = soundName.startsWith('file://')
            ? Uri.parse(soundName).toFilePath()
            : soundName;
        final contentUri = await FileProviderHelper.getContentUri(filePath);
        notifSound = contentUri != null
            ? UriAndroidNotificationSound(contentUri)
            : const RawResourceAndroidNotificationSound('alarm_classic');
      } else {
        final resName = soundName.replaceAll(RegExp(r'\.wav$'), '');
        notifSound = RawResourceAndroidNotificationSound(resName);
      }
    }

    return AndroidNotificationDetails(
      channelId,
      'Alarmes Ngenou',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      playSound: true,
      sound: notifSound,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 400, 200, 600, 200, 1000]),
      additionalFlags: Int32List.fromList(<int>[4]), // FLAG_INSISTENT
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      color: const Color(0xFF4A90D9),
      actions: const [
        AndroidNotificationAction(
          'revise',
          'Aller réviser',
          showsUserInterface: true,
        ),
        AndroidNotificationAction('snooze', '+5 min'),
        AndroidNotificationAction('dismiss', 'Annuler'),
      ],
    );
  }

  static Future<void> scheduleTask(StudyTask task) async {
    if (!_initialized) await init();
    if (!task.isPending || !task.triggersAlarm) return;
    if (task.scheduledAt.isBefore(DateTime.now())) return;

    clearTaskAcknowledgement(task.id);
    final notifId = _notifIdForTask(task.id);
    final payload = jsonEncode(task.toMap());

    final androidDetails = await _androidAlarmDetails();

    const linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.critical,
    );

    await _zonedScheduleWithFallback(
      notifId: notifId,
      title: 'Heure de réviser !',
      body: '${task.matiereNom} — ${task.durationMinutes} min',
      scheduledDate: tz.TZDateTime.from(task.scheduledAt, tz.local),
      details: NotificationDetails(
        android: androidDetails,
        linux: linuxDetails,
      ),
      payload: payload,
    );
  }

  static Future<void> _zonedScheduleWithFallback({
    required int notifId,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails details,
    required String payload,
  }) async {
    final sdkInt = await _getAndroidSdkInt();
    if (sdkInt < 31) {
      _exactAlarmsGranted = true;
    }

    final preferExact = _exactAlarmsGranted != false;
    if (preferExact) {
      for (final mode in [
        AndroidScheduleMode.alarmClock,
        AndroidScheduleMode.exactAllowWhileIdle,
      ]) {
        try {
          await _plugin.zonedSchedule(
            notifId,
            title,
            body,
            scheduledDate,
            details,
            androidScheduleMode: mode,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: payload,
          );
          _exactAlarmsGranted = true;
          debugPrint('Alarm scheduled with $mode at $scheduledDate');
          return;
        } on PlatformException catch (e) {
          if (e.code != 'exact_alarms_not_permitted') rethrow;
          _exactAlarmsGranted = false;
          debugPrint('Exact alarms not permitted, falling back to inexact.');
          break;
        }
      }
    }

    await _plugin.zonedSchedule(
      notifId,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
    debugPrint('Alarm scheduled (inexact) at $scheduledDate');
  }

  static Future<void> cancelTask(String taskId) async {
    await _plugin.cancel(_notifIdForTask(taskId));
  }

  static Future<void> rescheduleAll(List<StudyTask> tasks) async {
    if (!_initialized) await init();

    // Tenter d'annuler toutes les notifications — si ça crash (prefs corrompues),
    // on continue quand même pour replanifier les nouvelles
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('rescheduleAll cancelAll error (continuing): $e');
    }

    // Pré-créer le canal une seule fois avant la boucle
    if (Platform.isAndroid) {
      final soundName = await _getActiveSound();
      await ensureChannelForSound(soundName);
    }

    for (final t in tasks) {
      if (t.isPending &&
          t.triggersAlarm &&
          t.scheduledAt.isAfter(DateTime.now())) {
        try {
          await scheduleTask(t);
        } catch (e, st) {
          debugPrint('Failed to schedule task ${t.id}: $e\n$st');
        }
      }
    }
    debugPrint('rescheduleAll done — ${tasks.length} tasks processed');
  }

  static Future<void> showImmediateAlarm(StudyTask task) async {
    if (!_initialized) await init();
    if (isTaskAcknowledged(task.id)) return;

    final last = _lastImmediateShown[task.id];
    if (last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 2)) {
      return;
    }
    _lastImmediateShown[task.id] = DateTime.now();

    final notifId = _notifIdForTask('${task.id}_now');
    final payload = jsonEncode(task.toMap());
    final androidDetails = await _androidAlarmDetails();

    await _plugin.show(
      notifId,
      'Heure de réviser !',
      '${task.matiereNom} — ${task.durationMinutes} sec',
      NotificationDetails(
        android: androidDetails,
        linux: const LinuxNotificationDetails(
          urgency: LinuxNotificationUrgency.critical,
        ),
      ),
      payload: payload,
    );
  }
}
