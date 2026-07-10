import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/schedule_provider.dart';
import 'core/providers/custom_courses_provider.dart';
import 'core/providers/projets_provider.dart';
import 'core/models/study_task.dart';
import 'core/services/schedule_notification_service.dart';
import 'core/services/widget_intent_service.dart';
import 'core/theme/app_theme.dart';
import 'core/models/score.dart';
import 'modules/modules_registry.dart';

import 'features/accueil/accueil_page.dart';
import 'features/accueil/ai_global_chat_page.dart';
import 'features/cours/cours_list_page.dart';
import 'features/cours/lecon_page.dart';
import 'features/exercice/exercice_page.dart';
import 'features/exercice/resultat_page.dart';
import 'features/terminal/terminal_page.dart';
import 'features/progression/progression_page.dart';
import 'features/parametres/parametres_page.dart';
import 'features/defis/daily_defis_page.dart';
import 'features/course_builder/course_builder_wizard_page.dart';
import 'features/course_builder/course_import_page.dart';
import 'features/planning/planning_page.dart';
import 'features/planning/widgets/task_alarm_dialog.dart';
import 'features/tasks/tasks_hub_page.dart';
import 'features/splash/splash_screen.dart';
import 'features/splash/brand_setup_page.dart';
import 'features/auth/login_page.dart';
import 'core/services/auth_service.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Listenable qui notifie GoRouter à chaque changement d'état Supabase Auth
/// (connexion, déconnexion, callback OAuth…).
class _SupabaseAuthNotifier extends ChangeNotifier {
  _SupabaseAuthNotifier() {
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }
}

final _authNotifier = _SupabaseAuthNotifier();

final GoRouter _router = GoRouter(
  navigatorKey: rootNavigatorKey,
  refreshListenable: _authNotifier,
  redirect: (context, state) {
    final isLoggedIn = AuthService.isAuthenticated;
    final isOnLogin = state.matchedLocation == '/login';

    // Pas connecté et pas déjà sur /login → rediriger vers /login
    if (!isLoggedIn && !isOnLogin) return '/login';

    // Connecté et sur /login → rediriger vers l'accueil
    if (isLoggedIn && isOnLogin) return '/';

    return null; // pas de redirection
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(path: '/', builder: (context, state) => const AccueilPage()),
    GoRoute(
      path: '/ngenou-chat',
      builder: (context, state) => const AiGlobalChatPage(),
    ),
    GoRoute(
      path: '/cours/:matiereId',
      builder: (context, state) =>
          CoursListPage(matiereId: state.pathParameters['matiereId']!),
    ),
    GoRoute(
      path: '/cours/:matiereId/:notionId',
      builder: (context, state) {
        final openChat = state.uri.queryParameters['openChat'] == 'true';
        return LeconPage(
          matiereId: state.pathParameters['matiereId']!,
          notionId: state.pathParameters['notionId']!,
          openChat: openChat,
        );
      },
    ),
    GoRoute(
      path: '/exercice/:matiereId/:notionId/:index',
      builder: (context, state) {
        return ExercicePage(
          matiereId: state.pathParameters['matiereId']!,
          notionId: state.pathParameters['notionId']!,
          index: int.parse(state.pathParameters['index']!),
          currentScore:
              int.tryParse(state.uri.queryParameters['score'] ?? '0') ?? 0,
        );
      },
    ),
    GoRoute(
      path: '/resultat',
      builder: (context, state) {
        return ResultatPage(score: state.extra as Score);
      },
    ),
    GoRoute(
      path: '/terminal',
      builder: (context, state) => const TerminalPage(),
    ),
    GoRoute(
      path: '/progression',
      builder: (context, state) => const ProgressionPage(),
    ),
    GoRoute(
      path: '/parametres',
      builder: (context, state) => const ParametresPage(),
    ),
    GoRoute(
      path: '/defis',
      builder: (context, state) => const DailyDefisPage(),
    ),
    GoRoute(
      path: '/planning',
      builder: (context, state) => const PlanningPage(),
    ),
    GoRoute(
      path: '/taches',
      builder: (context, state) {
        final openAdd = state.extra == 'add';
        return TasksHubPage(openAddOnStart: openAdd);
      },
    ),
    GoRoute(
      path: '/course-builder',
      builder: (context, state) => const CourseBuilderWizardPage(),
    ),
    GoRoute(
      path: '/course-import',
      builder: (context, state) => const CourseImportPage(),
    ),
  ],
);

/// Navigue vers le cours correspondant à la tâche.
/// Si le matiereId n'est pas un module connu (tâche manuelle, ID invalide, etc.)
/// on affiche un dialog de sélection de cours.
Future<void> _navigateToTaskCourse(BuildContext context, StudyTask task) async {
  // S'assurer que les cours custom sont chargés avant de vérifier
  final customProvider = context.read<CustomCoursesProvider>();
  if (!customProvider.isLoaded) {
    await customProvider.loadCustomCourses();
  }
  if (!context.mounted) return;

  final matiereId = task.matiereId;
  const noCoursIds = {'manual', 'life_rhythm', ''};

  final hasModule =
      !noCoursIds.contains(matiereId) &&
      ModulesRegistry.getNotions(matiereId).isNotEmpty;

  if (hasModule) {
    context.push('/cours/$matiereId');
    return;
  }

  // Pas de cours direct : proposer un sélecteur
  final allMatieres = ModulesRegistry.matieres;
  if (allMatieres.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Aucun cours disponible. Importez un cours d\'abord.'),
        duration: Duration(seconds: 3),
      ),
    );
    return;
  }

  // Dialog de sélection du cours à réviser
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Choisir un cours à réviser'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: allMatieres.length,
          itemBuilder: (_, i) {
            final m = allMatieres[i];
            return ListTile(
              leading: const Icon(Icons.menu_book_rounded),
              title: Text(m.nom),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/cours/${m.id}');
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
      ],
    ),
  );
}

Future<void> _handleAlarmNotification(
  BuildContext context,
  StudyTask task,
  String action,
) async {
  await ScheduleNotificationService.dismissTaskNotifications(task.id);

  final customProvider = context.read<CustomCoursesProvider>();
  if (!customProvider.isLoaded) {
    await customProvider.loadCustomCourses();
  }

  final provider = context.read<ScheduleProvider>();

  if (action == 'dismiss' || action == 'cancel' || action == 'manage') {
    ScheduleNotificationService.acknowledgeTask(task.id);
    return;
  }
  if (action == 'snooze') {
    ScheduleNotificationService.clearTaskAcknowledgement(task.id);
    await provider.snoozeTask(task.id);
    return;
  }
  if (action == 'revise') {
    ScheduleNotificationService.acknowledgeTask(task.id);
    await provider.completeTask(task.id);
    if (!context.mounted) return;
    await _navigateToTaskCourse(context, task);
    return;
  }

  // action == 'open' : l'utilisateur a tapé sur la notification principale
  // → on affiche le dialog et on attend sa réponse
  if (!context.mounted) return;
  final choice = await showTaskAlarmDialog(context, task);

  // L'utilisateur a interagi — on acknowledge maintenant
  ScheduleNotificationService.acknowledgeTask(task.id);
  await ScheduleNotificationService.dismissTaskNotifications(task.id);

  if (!context.mounted || choice == null) return;

  switch (choice) {
    case 'revise':
      await provider.completeTask(task.id);
      await _navigateToTaskCourse(context, task);
    case 'snooze':
      ScheduleNotificationService.clearTaskAcknowledgement(task.id);
      await provider.snoozeTask(task.id);
    case 'dismiss':
      break;
  }
}

void setupScheduleAlarms() {
  ScheduleNotificationService.onAlarmAction = (task, action) async {
    // Attendre que le Navigator soit disponible (max 3 secondes)
    BuildContext? navContext;
    for (int i = 0; i < 30; i++) {
      navContext = rootNavigatorKey.currentContext;
      if (navContext != null) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (navContext == null) return;
    await _handleAlarmNotification(navContext, task, action);
  };
}

class NgenouApp extends StatefulWidget {
  const NgenouApp({super.key});

  @override
  State<NgenouApp> createState() => _NgenouAppState();
}

class _NgenouAppState extends State<NgenouApp> with WidgetsBindingObserver {
  StreamSubscription<String>? _widgetActionSub;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      setupScheduleAlarms();
      if (mounted) {
        await context.read<CustomCoursesProvider>().loadCustomCourses();
        await context.read<ProjetsProvider>().loadProjets();
      }
      if (mounted) {
        await context.read<ScheduleProvider>().load();
        await context.read<ScheduleProvider>().checkDueTasks();
      }

      // handleLaunchNotification APRÈS que tout est chargé et que le
      // Navigator est disponible.
      await Future.delayed(const Duration(milliseconds: 200));
      try {
        await ScheduleNotificationService.handleLaunchNotification();
      } catch (e) {
        debugPrint('handleLaunchNotification error (non-fatal): $e');
      }

      // Vérifier si l'app a été ouverte depuis un widget du bureau (démarrage à froid)
      await Future.delayed(const Duration(milliseconds: 100));
      _handleWidgetIntent();

      // Écouter les actions widget en temps réel (app déjà ouverte)
      _widgetActionSub = WidgetIntentService.instance.onAction.listen((action) {
        _navigateForWidgetAction(action);
      });
    });
  }

  Future<void> _handleWidgetIntent() async {
    try {
      final action = await WidgetIntentService.instance.getInitialAction();
      if (action == null) return;
      _navigateForWidgetAction(action);
    } catch (e) {
      debugPrint('_handleWidgetIntent error (non-fatal): $e');
    }
  }

  void _navigateForWidgetAction(String action) {
    if (!mounted) return;
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    if (action == 'open_tasks' || action == 'add_task') {
      ctx.push('/taches', extra: action == 'add_task' ? 'add' : null);
    } else if (action == 'open_defis') {
      ctx.push('/defis');
    }
  }

  @override
  void dispose() {
    _widgetActionSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<ScheduleProvider>().checkDueTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashOverlay(child: _NgenouAppShell());
  }
}

class _NgenouAppShell extends StatefulWidget {
  const _NgenouAppShell();

  @override
  State<_NgenouAppShell> createState() => _NgenouAppShellState();
}

class _NgenouAppShellState extends State<_NgenouAppShell> {
  // Démarre à true pour couvrir l'accueil dès le premier frame.
  // Passe à false seulement si toutes les permissions sont accordées.
  bool _showBrandSetup = true;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _checkBrandSetup();

    // Re-vérifier les permissions après chaque connexion.
    // Utile quand l'utilisateur se connecte depuis la LoginPage —
    // la BrandSetupPage peut avoir été ignorée au démarrage.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) {
        _checkBrandSetup();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _checkBrandSetup() async {
    final show = await shouldShowBrandSetup();
    if (mounted) setState(() => _showBrandSetup = show);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp.router(
      title: 'Ngenou',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: _router,
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();

        return Stack(
          children: [
            content,
            if (_showBrandSetup)
              Directionality(
                textDirection: TextDirection.ltr,
                child: BrandSetupPage(
                  onDone: () => setState(() => _showBrandSetup = false),
                ),
              ),
          ],
        );
      },
    );
  }
}
