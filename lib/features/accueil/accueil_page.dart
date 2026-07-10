import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/progression_provider.dart';
import '../../core/providers/custom_courses_provider.dart';
import '../../core/providers/projets_provider.dart';
import '../../core/providers/schedule_provider.dart';
import '../../core/models/projet.dart';
import '../../modules/modules_registry.dart';
import '../../core/providers/defis_provider.dart';
import '../course_builder/manage_custom_course_page.dart';
import '../projets/widgets/projet_card.dart';
import '../projets/widgets/projet_context_menu.dart';
import '../projets/create_project_wizard_page.dart';
import '../projets/projet_detail_page.dart';
import '../../core/widgets/connection_status_indicator.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/sync_service.dart';

class AccueilPage extends StatefulWidget {
  const AccueilPage({super.key});

  @override
  _AccueilPageState createState() => _AccueilPageState();
}

class _AccueilPageState extends State<AccueilPage> {
  int _selectedTab = 0; // 0 = Mes cours, 1 = Projets
  String _username = 'Ami';
  bool _wasSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    SyncService.instance.addListener(_onSyncChanged);
    // Recharger le username à chaque changement d'état d'auth
    // (connexion d'un nouvel utilisateur, déconnexion, etc.)
    AuthService.authStateChanges.listen((_) {
      if (mounted) _loadUsername();
    });
    // Initialiser _wasSyncing avec l'état courant au moment du montage
    _wasSyncing = SyncService.instance.isSyncing;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Si une sync est déjà en cours (auth téléphone/email),
      // attendre qu'elle se termine avant de charger depuis SQLite
      if (SyncService.instance.isSyncing) {
        // _onSyncChanged s'en chargera quand isSyncing → false
        return;
      }
      await context.read<CustomCoursesProvider>().loadCustomCourses();
      await context.read<ProjetsProvider>().loadProjets();
      await context.read<ScheduleProvider>().load();
      if (mounted) {
        context.read<ProgressionProvider>().loadAllProgressions();
        context.read<DefisProvider>().loadTodaySession();
      }
    });
  }

  @override
  void dispose() {
    SyncService.instance.removeListener(_onSyncChanged);
    super.dispose();
  }

  void _onSyncChanged() {
    final isSyncing = SyncService.instance.isSyncing;
    // Quand la sync passe de true → false : recharger tout
    if (_wasSyncing && !isSyncing && mounted) {
      _loadUsername();
      context.read<CustomCoursesProvider>().loadCustomCourses().then((_) {
        if (!mounted) return;
        context.read<ProjetsProvider>().loadProjets();
        context.read<ScheduleProvider>().load().then((_) {
          if (mounted) {
            // Replanifier les alarmes des tâches arrivées via sync
            context.read<ScheduleProvider>().rescheduleAllTasks();
          }
        });
        context.read<ProgressionProvider>().loadAllProgressions();
        context.read<DefisProvider>().loadTodaySession();
      });
    }
    _wasSyncing = isSyncing;
  }

  Future<void> _loadUsername() async {
    final name = await AuthService.getUsername();
    if (mounted) {
      setState(() {
        _username = name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final progProvider = context.watch<ProgressionProvider>();
    final projetsProvider = context.watch<ProjetsProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    context.watch<CustomCoursesProvider>();
    context.watch<SyncService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF5F7FA),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3498DB).withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(-2, 4),
              ),
              BoxShadow(
                color: const Color(0xFFF1C40F).withOpacity(0.25),
                blurRadius: 14,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/ngenou-chat'),
            backgroundColor: isDark ? const Color(0xFF161622) : Colors.white,
            elevation: 0,
            highlightElevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              side: BorderSide(
                color: isDark
                    ? const Color(0xFF2E2E3A)
                    : const Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/launcher_icon.png',
                  height: 60,
                  width: 60,
                ),

                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF3498DB), Color(0xFFF1C40F)],
                  ).createShader(bounds),
                  child: const Text(
                    'Ngenou',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ), // Container
      ), // Padding
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 60, width: 60),
            const SizedBox(width: 11),
            const Text(
              'Ngenou',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          const ConnectionStatusIndicator(),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
            onPressed: () => themeProvider.toggleTheme(
              isDark ? ThemeMode.light : ThemeMode.dark,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => context.push('/progression'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () =>
                context.push('/parametres').then((_) => _loadUsername()),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final hPad = w > 1200
              ? w * 0.08
              : w > 700
              ? w * 0.05
              : 20.0;
          final cols = w > 1100
              ? 4
              : w > 700
              ? 3
              : 2;
          final ratio = w > 900 ? 1.05 : 0.85;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Titre + Toggle ───────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour $_username !',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "On révise quoi aujourd'hui ?",
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sélecteur d'onglets avec pastille glissante
                    Center(
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 500),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final indicatorWidth = constraints.maxWidth / 2;
                            return Stack(
                              children: [
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutCubic,
                                  left: _selectedTab == 0 ? 0 : indicatorWidth,
                                  top: 0,
                                  bottom: 0,
                                  width: indicatorWidth,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF2C2C2C)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _HomeTabButton(
                                        label: 'Mes cours',
                                        icon: Icons.menu_book_rounded,
                                        selected: _selectedTab == 0,
                                        primary: primary,
                                        isDark: isDark,
                                        onTap: () =>
                                            setState(() => _selectedTab = 0),
                                      ),
                                    ),
                                    Expanded(
                                      child: _HomeTabButton(
                                        label: 'Projets',
                                        icon: Icons.folder_special_rounded,
                                        selected: _selectedTab == 1,
                                        primary: primary,
                                        isDark: isDark,
                                        onTap: () =>
                                            setState(() => _selectedTab = 1),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Contenu tabulé ───────────────────────────────────────────
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: _selectedTab == 0
                      ? _buildMesCours(
                          context,
                          isDark,
                          hPad,
                          cols,
                          ratio,
                          progProvider,
                          scheduleProvider,
                        )
                      : _buildProjets(
                          context,
                          isDark,
                          hPad,
                          projetsProvider,
                          progProvider,
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── TAB 0 : MES COURS ─────────────────────────────────────────────────────

  Widget _buildMesCours(
    BuildContext context,
    bool isDark,
    double hPad,
    int cols,
    double ratio,
    ProgressionProvider progProvider,
    ScheduleProvider scheduleProvider,
  ) {
    final customProvider = context.read<CustomCoursesProvider>();
    final projetsProvider = context.read<ProjetsProvider>();

    // Cours hors-projet = custom courses dont l'ID n'est dans aucun projet
    final allCustomIds = customProvider.modules
        .map((m) => m.matiere.id)
        .toList();
    final inProjectIds = projetsProvider.projets
        .expand((p) => p.matiereIds)
        .toSet();
    final horsProjetIds = allCustomIds
        .where((id) => !inProjectIds.contains(id))
        .toSet();

    // Matières affichées = natives + custom hors-projet
    final matieres = ModulesRegistry.matieres.where((m) {
      if (!m.id.startsWith('custom_')) return true; // natives
      return horsProjetIds.contains(m.id);
    }).toList();

    return SingleChildScrollView(
      key: const ValueKey('mes_cours'),
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDefisCard(context, isDark),
          const SizedBox(height: 14),
          _buildTachesCard(context, isDark, scheduleProvider),
          const SizedBox(height: 14),
          _buildPlanningCard(context, isDark, scheduleProvider),
          const SizedBox(height: 14),
          _buildCreateCourseCard(context, isDark),
          const SizedBox(height: 28),
          Text(
            'Matières',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: ratio,
            ),
            itemCount: matieres.length,
            itemBuilder: (context, index) {
              final matiere = matieres[index];
              final prog = progProvider.getProgressionGlobale(matiere.id);
              final isCustom = ModulesRegistry.isCustomMatiere(matiere.id);
              return _buildMatiereCard(
                context,
                matiere.nom,
                matiere.icone,
                matiere.isAvailable,
                prog,
                isCustom: isCustom,
                matiereId: matiere.id,
                onTap: () => context.push('/cours/${matiere.id}'),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── TAB 1 : PROJETS ───────────────────────────────────────────────────────

  Widget _buildProjets(
    BuildContext context,
    bool isDark,
    double hPad,
    ProjetsProvider projetsProvider,
    ProgressionProvider progProvider,
  ) {
    final projets = projetsProvider.projets;

    return SingleChildScrollView(
      key: const ValueKey('projets'),
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bouton créer un projet
          _buildCreateProjectCard(context, isDark),
          const SizedBox(height: 24),
          Text(
            'Mes projets',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          if (projets.isEmpty)
            _buildEmptyProjetState(isDark)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: projets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (_, i) {
                final projet = projets[i];
                final progression = projetsProvider.getProgressionProjet(
                  projet,
                  progProvider,
                );
                return ProjetCard(
                  projet: projet,
                  progression: progression,
                  onTap: () => _openProjet(context, projet),
                  onLongPress: projet.isSystem
                      ? null
                      : () => showProjetContextMenu(
                          context,
                          projet: projet,
                          onRefresh: () => setState(() {}),
                        ),
                );
              },
            ),
          const SizedBox(height: 500),
        ],
      ),
    );
  }

  void _openProjet(BuildContext context, Projet projet) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProjetDetailPage(projetId: projet.id)),
    );
  }

  // ─── CARTES CTA ────────────────────────────────────────────────────────────

  Widget _buildCreateProjectCard(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () async {
        final projetId = await Navigator.push<String?>(
          context,
          MaterialPageRoute(builder: (_) => const CreateProjectWizardPage()),
        );
        if (projetId != null && mounted) {
          final projet = context.read<ProjetsProvider>().getProjetById(
            projetId,
          );
          if (projet != null && mounted) {
            _openProjet(context, projet);
          }
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF3D9EFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.create_new_folder_rounded,
                size: 30,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nouveau projet',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'L\'IA génère un programme complet de cours',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateCourseCard(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () => context.push('/course-builder'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_circle_outline_rounded,
                size: 30,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Créer un cours',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Assistant → génération IA → import cours',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefisCard(BuildContext context, bool isDark) {
    final defisProvider = context.watch<DefisProvider>();
    final session = defisProvider.todaySession;
    final hasSession = session != null;
    final isComplete = hasSession && session.completed;
    final score = hasSession ? session.score : 0;
    final total = hasSession ? session.total : 0;

    String subtitle;
    if (defisProvider.isLoading) {
      subtitle = 'Chargement…';
    } else if (!hasSession) {
      subtitle = 'Générez votre série de 5 défis IA du jour';
    } else if (isComplete) {
      subtitle = 'Complété · Score : $score/$total 🏆';
    } else {
      subtitle = 'En cours · $score/$total réussis — continuez !';
    }

    return GestureDetector(
      onTap: () => context.push('/defis'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF2C3E50), const Color(0xFF3498DB)]
                : [const Color(0xFF3498DB), const Color(0xFF2980B9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF3498DB,
              ).withValues(alpha: isDark ? 0.2 : 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                if (isComplete)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                if (hasSession && !isComplete)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber[700],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$score/$total',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Défis quotidiens',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  if (hasSession && !isComplete) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total > 0 ? score / total : 0,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTachesCard(
    BuildContext context,
    bool isDark,
    ScheduleProvider scheduleProvider,
  ) {
    final todayCount = scheduleProvider.todayStudyTaskCount;
    return GestureDetector(
      onTap: () => context.push('/taches'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1A237E), const Color(0xFF283593)]
                : [const Color(0xFF1A237E), const Color(0xFF3949AB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF1A237E,
              ).withValues(alpha: isDark ? 0.2 : 0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.task_alt_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                if (todayCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B6B),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFFF6B6B,
                            ).withValues(alpha: 0.5),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$todayCount',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mes tâches',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    todayCount > 0
                        ? '$todayCount tâche${todayCount > 1 ? 's' : ''} aujourd\'hui · historique'
                        : 'Tâches du jour, ajout manuel et historique',
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanningCard(
    BuildContext context,
    bool isDark,
    ScheduleProvider scheduleProvider,
  ) {
    final count = scheduleProvider.schedules.length;
    return GestureDetector(
      onTap: () => context.push('/planning'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF4A148C), const Color(0xFF7B1FA2)]
                : [const Color(0xFF8E24AA), const Color(0xFF6A1B9A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF8E24AA,
              ).withValues(alpha: isDark ? 0.2 : 0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Emploi du temps',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    count > 0
                        ? '$count planning${count > 1 ? 's' : ''} · clic sur le titre pour le détail'
                        : 'Créez un planning IA personnalisé',
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyProjetState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.folder_special_rounded,
            size: 56,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun projet pour l\'instant',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Créez votre premier projet et laissez l\'IA générer un programme complet.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMatiereCard(
    BuildContext context,
    String titre,
    IconData icon,
    bool isAvailable,
    double progression, {
    required VoidCallback onTap,
    bool isCustom = false,
    String? matiereId,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Opacity(
      opacity: isAvailable ? 1.0 : 0.6,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: isAvailable ? onTap : null,
            onLongPress: isCustom && matiereId != null
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ManageCustomCoursePage(matiereId: matiereId),
                    ),
                  )
                : null,
            child: Stack(
              children: [
                if (isCustom)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Perso',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.15)
                              : Colors.grey.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 34,
                          color: isAvailable
                              ? Theme.of(context).primaryColor
                              : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        titre,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      if (isAvailable && progression > 0) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progression / 100,
                            minHeight: 5,
                            backgroundColor: isDark
                                ? Colors.grey[800]
                                : Colors.grey[200],
                            color: progression == 100
                                ? Colors.amber
                                : Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${progression.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: progression == 100
                                ? Colors.amber
                                : Theme.of(context).primaryColor,
                          ),
                        ),
                      ] else if (isAvailable) ...[
                        Text(
                          'Commencer',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isAvailable)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Bientôt',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color primary;
  final bool isDark;
  final VoidCallback onTap;

  const _HomeTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.primary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = isDark ? Colors.white54 : Colors.black54;
    final activeText = isDark ? Colors.white : Colors.black87;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: primary.withOpacity(0.08),
        highlightColor: primary.withOpacity(0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? primary : inactive),
              const SizedBox(width: 8),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: selected ? activeText : inactive,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
