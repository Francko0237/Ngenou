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
import '../../core/widgets/connection_status_indicator.dart';
import 'tabs/cours_tab.dart';
import 'tabs/quotidien_tab.dart';
import 'tabs/explorer_tab.dart';

class AccueilPage extends StatefulWidget {
  const AccueilPage({super.key});

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class _AccueilPageState extends State<AccueilPage> {
  int _navIndex = 0; // 0 = Cours, 1 = Quotidien, 2 = Explorer
  int _selectedSubTab = 0; // 0 = Mes cours, 1 = Projets dans l'onglet Cours
  String _username = 'Ami';
  String _userRole = 'student';
  bool _wasSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    SyncService.instance.addListener(_onSyncChanged);

    AuthService.authStateChanges.listen((_) {
      if (mounted) _loadUsername();
    });

    _wasSyncing = SyncService.instance.isSyncing;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (SyncService.instance.isSyncing) return;
      _refreshAllDataQuietly();
    });
  }

  @override
  void dispose() {
    SyncService.instance.removeListener(_onSyncChanged);
    super.dispose();
  }

  void _onSyncChanged() {
    final isSyncing = SyncService.instance.isSyncing;
    if (_wasSyncing && !isSyncing && mounted) {
      _refreshAllDataQuietly();
    }
    _wasSyncing = isSyncing;
  }

  Future<void> _refreshAllDataQuietly() async {
    if (!mounted) return;
    try {
      // On charge séquentiellement plutôt qu'en Future.wait parallèle.
      // Chaque provider notifie une seule fois en fin de load — en parallèle
      // ils se terminent à des instants différents et déclenchent une rafale
      // de notifyListeners qui cause des scintillements.
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
    // Ne rebuilder que si les valeurs ont vraiment changé
    if (mounted && (name != _username || role != _userRole)) {
      setState(() {
        _username = name;
        _userRole = role;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
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
          const ConnectionStatusIndicator(),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Thème clair / sombre',
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 20,
            ),
            onPressed: () => themeProvider.toggleTheme(
              isDark ? ThemeMode.light : ThemeMode.dark,
            ),
          ),
          IconButton(
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
            onRefresh: () {
              _refreshAllDataQuietly();
            },
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
              selectedIcon: Icon(Icons.auto_stories_rounded, size: 22, color: primary),
              label: 'Cours',
            ),
            NavigationDestination(
              icon: const Icon(Icons.calendar_today_outlined, size: 22),
              selectedIcon: Icon(Icons.calendar_month_rounded, size: 22, color: primary),
              label: 'Quotidien',
            ),
            NavigationDestination(
              icon: const Icon(Icons.explore_outlined, size: 22),
              selectedIcon: Icon(Icons.explore_rounded, size: 22, color: primary),
              label: 'Explorer',
            ),
          ],
        ),
      ),
    );
  }
}
