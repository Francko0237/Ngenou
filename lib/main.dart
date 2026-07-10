import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:audio_session/audio_session.dart';
import 'dart:io';

import 'app.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/progression_provider.dart';
import 'core/providers/custom_courses_provider.dart';
import 'core/providers/projets_provider.dart';
import 'core/providers/schedule_provider.dart';
import 'core/services/schedule_notification_service.dart';
import 'core/services/home_widget_service.dart';
import 'core/database/database_helper.dart';
import 'core/providers/defis_provider.dart';

import 'core/services/supabase_credentials.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseCredentials.init();

  // Initialise le service de widgets natifs (bureau Android/iOS)
  await HomeWidgetService.instance.init();

  // Démarrer la synchronisation périodique (toutes les 2 minutes quand connecté)
  // + première sync rapide 30s après le démarrage
  SyncService.instance.startPeriodicSync(intervalMinutes: 2);

  // Init des notifications avec timeout de sécurité — ne bloque jamais le démarrage
  try {
    await ScheduleNotificationService.init().timeout(
      const Duration(seconds: 8),
    );
  } catch (e) {
    debugPrint('ScheduleNotificationService.init error (non-fatal): $e');
  }

  if (Platform.isAndroid) {
    try {
      await ScheduleNotificationService.ensureAllAndroidPermissions().timeout(
        const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('ensureAllAndroidPermissions error (non-fatal): $e');
    }
    // Replanifie les alarmes après init — en arrière-plan pour ne pas bloquer
    Future.microtask(() async {
      try {
        final db = DatabaseHelper.instance;
        final pending = await db.getAllPendingTasks();
        await ScheduleNotificationService.rescheduleAll(pending);
      } catch (e) {
        debugPrint('rescheduleAll error (non-fatal): $e');
      }
    });
  }

  // Configure audio session for alarm playback (required for audioplayers)
  // Usage.alarm ensures Android does not duck or block the sound even in DND mode.
  if (Platform.isAndroid || Platform.isIOS) {
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          usage: AndroidAudioUsage.alarm,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: false,
      ),
    );
  }

  // Desktop configuration for sql and focus mode window size
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 800),
      center: true,
      title: "Ngenou",
    );

    // Set native window icon
    if (Platform.isLinux || Platform.isWindows) {
      await windowManager.setIcon('assets/images/logo.png');
    }

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ProgressionProvider()),
        ChangeNotifierProvider(create: (_) => CustomCoursesProvider()),
        ChangeNotifierProvider(create: (_) => ProjetsProvider()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
        ChangeNotifierProvider(create: (_) => DefisProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider.value(value: SyncService.instance),
      ],
      child: const NgenouApp(),
    ),
  );
}
