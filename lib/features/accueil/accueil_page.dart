import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/providers/custom_courses_provider.dart';
import '../../core/providers/defis_provider.dart';
import '../../core/providers/progression_provider.dart';
import '../../core/providers/projets_provider.dart';
import '../../core/providers/schedule_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/teacher_courses_service.dart';
import '../../core/services/tutorial_service.dart';
import '../../core/widgets/tutorial_overlay.dart';
import 'tabs/cours_tab.dart';
import 'tabs/quotidien_tab.dart';
import 'tabs/explorer_tab.dart';

class AccueilPage extends StatefulWidget {
  const AccueilPage({super.key});

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class _AccueilPageState extends State<AccueilPage> {
  int _navIndex = 0;
  int _selectedSubTab = 0;
  String _username = 'Ami';
  String _userRole = 'student';
  bool _wasSyncing = false;

  // ── Clés globales pour le tutoriel ──────────────────────────────────────
  final _keyTutorialBtn = GlobalKey();
  final _keyMesCours = GlobalKey();
  final _keyFab = GlobalKey();
  final _keyNavQuotidien = GlobalKey();
  final _keyNavExplorer = GlobalKey();
  final _keySettings = GlobalKey();
  final _keyThemeToggle = GlobalKey();

  bool _showTutorial = false;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    SyncService.instance.addListener(_onSyncChanged);
    AuthService.authStateChanges.listen((_) {
      if (mounted) _loadUsername();
    });
    _wasSyncing = SyncService.instance.isSyncing;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (SyncService.instance.isSyncing) return;
      _refreshAllDataQuietly();
      // Démarrer le tuto si première ouverture
      final should = await TutorialService.shouldShow();
      if (should && mounted) setState(() => _showTutorial = true);
    });
  }

  @override
  void dispose() {
    SyncService.instance.removeListener(_onSyncChanged);
    super.dispose();
  }

  void _onSyncChanged() {
    final isSyncing = SyncService.instance.isSyncing;
    if (_wasSyncing && !isSyncing && mounted) _refreshAllDataQuietly();
    _wasSyncing = isSyncing;
  }

  Future<void> _refreshAllDataQuietly() async {
    if (!mounted) return;
    try {
      await _loadUsername();
      if (!mounted) return;
      await TeacherCoursesService.syncPublicCourseIds();
      if (!mounted) return;
      await context.read<CustomCoursesProvider>().loadCustomCourses();
      if (!mounted) return;
      await context.read<ProjetsProvider>().loadProjets();
      if (!mounted) return;
      await context.read<ScheduleProvider>().load();
      if (mounted) context.read<ScheduleProvider>().rescheduleAllTasks();
      if (!mounted) return;
      await context.read<ProgressionProvider>().loadAllProgressions();
      if (!mounted) return;
      await context.read<DefisProvider>().loadTodaySession();
    } catch (e) {
      debugPrint('Erreur refreshAllDataQuietly : $e');
    }
  }

  Future<void> _loadUsername() async {
    final name = await AuthService.getUsername();
    final role = await AuthService.getUserRole();
    if (mounted && (name != _username || role != _userRole)) {
      setState(() {
        _username = name;
        _userRole = role;
      });
    }
  }

  void _startTutorial() {
    TutorialService.reset().then((_) {
      if (mounted) setState(() => _showTutorial = true);
    });
  }

  List<TutorialStep> _buildSteps() => [
    TutorialStep(
      targetKey: _keyTutorialBtn,
      title: 'Guide interactif',
      description:
          'Ce bouton vous permet de revoir ce guide à tout moment.\n'
          'Appuyez dessus quand vous voulez retrouver vos repères dans l\'app.',
      spotRadius: 22,
      spotShape: SpotShape.circle,
    ),
    TutorialStep(
      targetKey: _keyMesCours,
      title: 'Mes cours',
      description:
          'Retrouvez tous vos cours ici.\n'
          'Sélectionnez une matière pour accéder aux chapitres, leçons et exercices.',
      spotRadius: 130,
      spotShape: SpotShape.circle,
    ),
    TutorialStep(
      targetKey: _keyFab,
      title: 'Ngenou IA',
      description:
          'Votre assistant personnel IA, disponible à tout moment.\n'
          'Posez des questions, obtenez des explications ou discutez de n\'importe quel sujet de cours.',
      spotRadius: 28,
      spotShape: SpotShape.roundedRect,
    ),
    TutorialStep(
      targetKey: _keyNavQuotidien,
      targetKey2: _keyNavExplorer,
      title: 'Quotidien & Explorer',
      description:
          'Quotidien : vos défis du jour générés par l\'IA.\n'
          'Explorer : découvrez des cours publics partagés par la communauté.',
      spotRadius: 28,
      spotShape: SpotShape.circle,
    ),
    TutorialStep(
      targetKey: _keySettings,
      title: 'Paramètres',
      description:
          'Gérez vos informations personnelles et personnalisez\n'
          'certains comportements de l\'application.',
      spotRadius: 22,
      spotShape: SpotShape.circle,
    ),
    TutorialStep(
      targetKey: _keyThemeToggle,
      title: 'Thème clair / sombre',
      description:
          'Basculez entre le mode clair et le mode sombre\n'
          'selon vos préférences ou les conditions d\'éclairage.',
      spotRadius: 22,
      spotShape: SpotShape.circle,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF121216)
              : const Color(0xFFF7F8FA),
          appBar: AppBar(
            title: Row(
              children: [
                Image.asset('assets/images/logo.png', height: 42, width: 42),
                const SizedBox(width: 10),
                const Text(
                  'Ngenou',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            actions: [
              // ── Bouton ! guide (remplace le point connexion) ───────────
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: GestureDetector(
                  key: _keyTutorialBtn,
                  onTap: _startTutorial,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.45)
                            : Colors.black.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.black.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // ── Toggle thème ───────────────────────────────────────────
              IconButton(
                key: _keyThemeToggle,
                tooltip: 'Thème clair / sombre',
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  size: 20,
                ),
                onPressed: () => themeProvider.toggleTheme(
                  isDark ? ThemeMode.light : ThemeMode.dark,
                ),
              ),
              // ── Paramètres ─────────────────────────────────────────────
              IconButton(
                key: _keySettings,
                tooltip: 'Paramètres du compte',
                icon: const Icon(Icons.settings_rounded, size: 20),
                onPressed: () =>
                    context.push('/parametres').then((_) => _loadUsername()),
              ),
              const SizedBox(width: 6),
            ],
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: FloatingActionButton.extended(
            key: _keyFab,
            heroTag: 'ngenou_ai_fab',
            onPressed: () => context.push('/ngenou-chat'),
            backgroundColor: isDark ? const Color(0xFF1E1E28) : Colors.white,
            elevation: 3,
            highlightElevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(
                color: isDark ? Colors.white12 : Colors.black12,
                width: 1,
              ),
            ),
            icon: Image.asset(
              'assets/images/launcher_icon.png',
              height: 28,
              width: 28,
            ),
            label: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF3498DB), Color(0xFFF1C40F)],
              ).createShader(bounds),
              child: const Text(
                'Ngenou IA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          body: IndexedStack(
            index: _navIndex,
            children: [
              CoursTab(
                key: _keyMesCours,
                username: _username,
                userRole: _userRole,
                selectedSubTab: _selectedSubTab,
                onSubTabChanged: (val) => setState(() => _selectedSubTab = val),
                onRefresh: _refreshAllDataQuietly,
              ),
              const QuotidienTab(),
              const ExplorerTab(),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16161E) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: NavigationBar(
              selectedIndex: _navIndex,
              onDestinationSelected: (idx) => setState(() => _navIndex = idx),
              elevation: 0,
              backgroundColor: Colors.transparent,
              indicatorColor: primary.withValues(alpha: isDark ? 0.25 : 0.12),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.auto_stories_outlined, size: 22),
                  selectedIcon: Icon(
                    Icons.auto_stories_rounded,
                    size: 22,
                    color: primary,
                  ),
                  label: 'Cours',
                ),
                NavigationDestination(
                  key: _keyNavQuotidien,
                  icon: const Icon(Icons.calendar_today_outlined, size: 22),
                  selectedIcon: Icon(
                    Icons.calendar_month_rounded,
                    size: 22,
                    color: primary,
                  ),
                  label: 'Quotidien',
                ),
                NavigationDestination(
                  key: _keyNavExplorer,
                  icon: const Icon(Icons.explore_outlined, size: 22),
                  selectedIcon: Icon(
                    Icons.explore_rounded,
                    size: 22,
                    color: primary,
                  ),
                  label: 'Explorer',
                ),
              ],
            ),
          ),
        ),

        // ── Overlay tutoriel ─────────────────────────────────────────────
        if (_showTutorial)
          TutorialOverlay(
            steps: _buildSteps(),
            onDone: () => setState(() => _showTutorial = false),
          ),
      ],
    );
  }
}
