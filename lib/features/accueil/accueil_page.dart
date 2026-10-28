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

  // ── Clés globales pour le tutoriel Dashboard (onglet Cours) ─────────────
  final _keyTutorialBtn = GlobalKey();
  final _keyCourseToggle = GlobalKey();
  final _keyFab = GlobalKey();
  final _keyBottomBar = GlobalKey();
  final _keySettings = GlobalKey();
  final _keyThemeToggle = GlobalKey();

  // ── Clés pour le tutoriel Quotidien (onglet index 1) ─────────────────────
  final _keyDefiHero = GlobalKey();
  final _keyTachesSection = GlobalKey();
  final _keyPlanningSection = GlobalKey();

  // ── Clés pour le tutoriel Explorer (onglet index 2) ────────────────────
  final _keyCatalogue = GlobalKey();
  final _keyCreateur = GlobalKey();
  final _keyExtensions = GlobalKey();
  final _keyProgression = GlobalKey();

  bool _showTutorial = false;
  bool _showQuotidienTutorial = false;
  bool _showExplorerTutorial = false;

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
      // Démarrer le bon tuto selon l'onglet actif
      await _checkCurrentTabTutorial();
    });
  }

  Future<void> _checkCurrentTabTutorial() async {
    if (_navIndex == 0) {
      final should = await TutorialService.shouldShow();
      if (should && mounted) setState(() => _showTutorial = true);
    } else if (_navIndex == 1) {
      final should = await TutorialService.shouldShow('quotidien_tab');
      if (should && mounted) setState(() => _showQuotidienTutorial = true);
    } else if (_navIndex == 2) {
      final should = await TutorialService.shouldShow('explorer_tab');
      if (should && mounted) setState(() => _showExplorerTutorial = true);
    }
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

  /// Bouton ampoule — relance le tutoriel de l'onglet actif
  void _startTutorial() {
    switch (_navIndex) {
      case 0:
        TutorialService.reset('dashboard').then((_) {
          if (mounted) setState(() => _showTutorial = true);
        });
      case 1:
        TutorialService.reset('quotidien_tab').then((_) {
          if (mounted) setState(() => _showQuotidienTutorial = true);
        });
      case 2:
        TutorialService.reset('explorer_tab').then((_) {
          if (mounted) setState(() => _showExplorerTutorial = true);
        });
    }
  }

  // ── Gestion du changement d'onglet avec déclenchement du bon tutoriel ────
  Future<void> _onTabChanged(int idx) async {
    setState(() => _navIndex = idx);
    if (idx == 1) {
      final should = await TutorialService.shouldShow('quotidien_tab');
      if (should && mounted) setState(() => _showQuotidienTutorial = true);
    } else if (idx == 2) {
      final should = await TutorialService.shouldShow('explorer_tab');
      if (should && mounted) setState(() => _showExplorerTutorial = true);
    }
  }

  List<TutorialStep> _buildSteps() => [
    TutorialStep(
      targetKey: _keyCourseToggle,
      category: 'APPRENTISSAGE',
      icon: Icons.auto_stories_rounded,
      title: 'Explorez vos matières',
      description:
          'Retrouvez tous vos cours interactifs par matière, vos leçons synthétisées et vos exercices. Basculez en un clic vers vos projets.',
      highlights: ['Maths, Algorithme, Ordinateurs...', 'Mode hors-ligne disponible'],
      spotShape: SpotShape.roundedRect,
      spotRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    TutorialStep(
      targetKey: _keyFab,
      category: 'INTELLIGENCE ARTIFICIELLE',
      icon: Icons.psychology_rounded,
      title: 'Votre Tuteur Ngenou IA',
      description:
          'Une question sur une notion ou un exercice ? Votre tuteur personnel est disponible 24h/24 pour vous guider et vous expliquer pas à pas.',
      highlights: ['Explications sur mesure', 'Assistance continue'],
      spotShape: SpotShape.roundedRect,
      spotRadius: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    TutorialStep(
      targetKey: _keyBottomBar,
      customTargetBuilder: (screen) {
        final box = _keyBottomBar.currentContext?.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize && box.attached) {
          final pos = box.localToGlobal(Offset.zero);
          return Rect.fromLTWH(
            pos.dx + box.size.width * 0.33,
            pos.dy + 4,
            box.size.width * 0.65,
            box.size.height - 8,
          );
        }
        return Rect.fromLTWH(
          screen.width * 0.33,
          screen.height - 76,
          screen.width * 0.65,
          64,
        );
      },
      category: 'PRATIQUE QUOTIDIENNE',
      icon: Icons.local_fire_department_rounded,
      title: 'Quotidien & Explorer',
      description:
          'Entraînez-vous chaque jour avec des défis rapides générés par l\'IA pour consolider vos acquis, et découvrez les cours partagés par la communauté.',
      highlights: ['Défis quotidiens', 'Partages communautaires'],
      spotShape: SpotShape.roundedRect,
      spotRadius: 16,
    ),
    TutorialStep(
      targetKey: _keyThemeToggle,
      targetKey2: _keySettings,
      category: 'PERSONNALISATION',
      icon: Icons.palette_outlined,
      title: 'Thème & Réglages',
      description:
          'Basculez à tout moment entre le mode clair et le mode sombre, et gérez votre profil ou vos données d\'apprentissage dans les paramètres.',
      highlights: ['Mode clair / sombre', 'Profil & synchronisation'],
      spotShape: SpotShape.roundedRect,
      spotRadius: 14,
      padding: const EdgeInsets.all(6),
    ),
    TutorialStep(
      targetKey: _keyTutorialBtn,
      category: 'AIDE RAPIDE',
      icon: Icons.lightbulb_outline_rounded,
      title: 'Guide toujours disponible',
      description:
          'Ce bouton ampoule vous permet de revoir ce guide à tout moment. Vous avez toutes les clés en main pour réussir avec Ngenou !',
      highlights: ['Toujours à portée de main', 'Bonne rentrée ! 🎉'],
      spotShape: SpotShape.roundedRect,
      spotRadius: 12,
      padding: const EdgeInsets.all(4),
    ),
  ];

  List<TutorialStep> _buildQuotidienSteps() => [
    TutorialStep(
      targetKey: _keyDefiHero,
      spotShape: SpotShape.roundedRect,
      spotRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      category: 'DÉFI DU JOUR',
      icon: Icons.local_fire_department_rounded,
      title: 'Ton défi du jour',
      description:
          "Chaque jour, l'IA génère une série de défis personnalisés. Appuie sur cette carte pour lancer ta session et gagner des XP.",
      highlights: ['+20 XP par session', 'QCM + algo', 'Nouveau chaque jour'],
    ),
    TutorialStep(
      targetKey: _keyTachesSection,
      spotShape: SpotShape.roundedRect,
      spotRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      category: 'TÂCHES',
      icon: Icons.checklist_rounded,
      title: "Tâches d'aujourd'hui",
      description:
          "Retrouve ici un aperçu de tes tâches du jour. Appuie sur \u00ab\u00a0Tout voir\u00a0\u00bb pour les gérer en détail ou ajouter une nouvelle tâche.",
      highlights: ['Ajouter une tâche', 'Voir toutes les tâches'],
    ),
    TutorialStep(
      targetKey: _keyPlanningSection,
      spotShape: SpotShape.roundedRect,
      spotRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      category: 'PLANNING',
      icon: Icons.calendar_month_rounded,
      title: 'Emploi du temps IA',
      description:
          "Gère tes créneaux de révision et ton emploi du temps. L'IA peut générer un planning adapté à tes matières et à ta disponibilité.",
      highlights: ['Planning hebdomadaire', 'Rappels automatiques'],
    ),
  ];

  List<TutorialStep> _buildExplorerSteps() => [
    TutorialStep(
      targetKey: _keyCatalogue,
      spotShape: SpotShape.roundedRect,
      spotRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      category: 'CATALOGUE',
      icon: Icons.public_rounded,
      title: 'Cours publics & partagés',
      description:
          'Parcourez les cours créés par les professeurs certifiés et la communauté. Inscrivez-vous et apprenez à votre rythme.',
      highlights: ['Professeurs certifiés', 'Cours communautaires', 'Inscription libre'],
    ),
    TutorialStep(
      targetKey: _keyCreateur,
      spotShape: SpotShape.roundedRect,
      spotRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      category: 'STUDIO IA',
      icon: Icons.auto_awesome_rounded,
      title: 'Crée ton propre cours',
      description:
          "L'IA génère pour toi un programme complet de leçons, cours et quiz sur mesure. Partage-le ensuite avec d'autres élèves ou gardez-le privé.",
      highlights: ['Génération IA complète', 'Leçons + Quiz + Cours', 'Partage optionnel'],
    ),
    TutorialStep(
      targetKey: _keyExtensions,
      spotShape: SpotShape.roundedRect,
      spotRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      category: 'OUTILS INTERACTIFS',
      icon: Icons.extension_rounded,
      title: 'Boîte à outils & Extensions',
      description:
          'Accède à des outils visuels interactifs : visualiseur de fractions, tableau de conversions des unités, droite graduée des nombres relatifs...',
      highlights: ['Fractions', 'Conversions', 'Nombres relatifs'],
    ),
    TutorialStep(
      targetKey: _keyProgression,
      spotShape: SpotShape.roundedRect,
      spotRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      category: 'PROGRESSION',
      icon: Icons.insights_rounded,
      title: 'Ton bilan d\'apprentissage',
      description:
          'Consulte tes courbes de progression, tes scores récents et les badges débloqués. Identifie tes points forts et axes d\'amélioration.',
      highlights: ['Courbes de progression', 'Scores récents', 'Badges débloqués'],
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
              TutorialLightbulbButton(
                buttonKey: _keyTutorialBtn,
                tooltip: 'Guide de bienvenue',
                onTap: _startTutorial,
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
                username: _username,
                userRole: _userRole,
                selectedSubTab: _selectedSubTab,
                onSubTabChanged: (val) => setState(() => _selectedSubTab = val),
                onRefresh: _refreshAllDataQuietly,
                toggleKey: _keyCourseToggle,
              ),
              QuotidienTab(
                defiHeroKey: _keyDefiHero,
                tachesSectionKey: _keyTachesSection,
                planningSectionKey: _keyPlanningSection,
              ),
              ExplorerTab(
                catalogueKey: _keyCatalogue,
                createurKey: _keyCreateur,
                extensionsKey: _keyExtensions,
                progressionKey: _keyProgression,
              ),
            ],
          ),
          bottomNavigationBar: Container(
            key: _keyBottomBar,
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
              onDestinationSelected: _onTabChanged,
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
                  icon: const Icon(Icons.calendar_today_outlined, size: 22),
                  selectedIcon: Icon(
                    Icons.calendar_month_rounded,
                    size: 22,
                    color: primary,
                  ),
                  label: 'Quotidien',
                ),
                NavigationDestination(
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

        // ── Overlay tutoriel Dashboard (onglet Cours) ────────────────────
        if (_showTutorial && _navIndex == 0)
          TutorialOverlay(
            tutorialId: 'dashboard',
            steps: _buildSteps(),
            onDone: () => setState(() => _showTutorial = false),
          ),

        // ── Overlay tutoriel Quotidien ────────────────────────────────────
        if (_showQuotidienTutorial && _navIndex == 1)
          TutorialOverlay(
            tutorialId: 'quotidien_tab',
            steps: _buildQuotidienSteps(),
            onDone: () => setState(() => _showQuotidienTutorial = false),
          ),

        // ── Overlay tutoriel Explorer ────────────────────────────────────
        if (_showExplorerTutorial && _navIndex == 2)
          TutorialOverlay(
            tutorialId: 'explorer_tab',
            steps: _buildExplorerSteps(),
            onDone: () => setState(() => _showExplorerTutorial = false),
          ),
      ],
    );
  }
}
