import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/providers/progression_provider.dart';
import '../../core/services/pdf_export_service.dart';
import '../../core/utils/course_context_mapper.dart';
import '../../modules/modules_registry.dart';
import '../../core/models/badge.dart';
import '../../core/models/score.dart';
import '../../core/services/badge_service.dart';

// ─── Constantes visuelles alignées avec le dashboard ────────────────────────

const _kBg = Color(0xFF121212);
const _kBgLight = Color(0xFFF7F8FA);
const _kSurface = Color(0xFF1E1E26);
const _kSurfaceLight = Colors.white;

// ─── Page principale ─────────────────────────────────────────────────────────

class ProgressionPage extends StatefulWidget {
  const ProgressionPage({super.key});

  @override
  State<ProgressionPage> createState() => _ProgressionPageState();
}

class _ProgressionPageState extends State<ProgressionPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProgressionProvider>().loadAllProgressions();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? _kBg : _kBgLight,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Bilan & Progression',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
          bottom: TabBar(
            labelColor: primary,
            unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
            indicatorColor: primary,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            tabs: const [
              Tab(
                icon: Icon(Icons.analytics_rounded, size: 18),
                text: 'Statistiques',
              ),
              Tab(
                icon: Icon(Icons.emoji_events_rounded, size: 18),
                text: 'Badges',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_CoursesProgressionView(), _BadgesTab()],
        ),
      ),
    );
  }
}

// ─── Onglet Statistiques ─────────────────────────────────────────────────────

class _CoursesProgressionView extends StatelessWidget {
  const _CoursesProgressionView();

  @override
  Widget build(BuildContext context) {
    final matieres = ModulesRegistry.matieres;
    if (matieres.isEmpty) {
      return const Center(child: Text('Aucune matière pour le moment'));
    }

    return DefaultTabController(
      length: matieres.length + 1,
      child: Column(
        children: [
          // Tabs horizontaux scrollables
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor:
                Theme.of(context).brightness == Brightness.dark
                ? Colors.white38
                : Colors.black38,
            indicatorColor: Theme.of(context).primaryColor,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: [
              const Tab(text: 'Vue globale'),
              ...matieres.map((m) => Tab(text: m.nom)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                const _GlobalView(),
                ...matieres.map((m) => _MatiereView(matiereId: m.id)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Vue globale ─────────────────────────────────────────────────────────────

class _GlobalView extends StatelessWidget {
  const _GlobalView();

  @override
  Widget build(BuildContext context) {
    final progProvider = context.watch<ProgressionProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    int totalNotions = 0;
    int completedNotions = 0;
    int inProgressNotions = 0;
    int totalExercises = 0;
    int successfulExercises = 0;
    int activeMatieres = 0;

    final matieres = ModulesRegistry.matieres;
    final List<Map<String, dynamic>> matiereProgressList = [];

    for (final m in matieres) {
      final globPct = progProvider.getProgressionGlobale(m.id);
      if (globPct > 0) activeMatieres++;
      final notions = ModulesRegistry.getNotions(m.id);
      final progs = progProvider.getProgressions(m.id);
      totalNotions += notions.length;
      int mCompleted = 0;
      for (final notion in notions) {
        try {
          final p = progs.firstWhere((e) => e.notionId == notion.id);
          if (p.statut == 'termine') {
            mCompleted++;
            completedNotions++;
          } else if (p.statut == 'en_cours') {
            inProgressNotions++;
          }
          totalExercises += p.nbExercicesTotal;
          successfulExercises += p.nbExercicesReussis;
        } catch (_) {}
      }
      matiereProgressList.add({
        'matiere': m,
        'percent': globPct,
        'completed': mCompleted,
        'total': notions.length,
      });
    }

    final overallPct = totalNotions > 0
        ? ((completedNotions + inProgressNotions * 0.5) / totalNotions * 100)
              .clamp(0.0, 100.0)
        : 0.0;
    final successRate = totalExercises > 0
        ? (successfulExercises / totalExercises * 100).toInt()
        : 0;

    return FutureBuilder<List<Score>>(
      future: progProvider.getAllRecentScores(15),
      builder: (context, snapshot) {
        final recentScores = snapshot.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero card ────────────────────────────────────────────────
              _HeroCard(
                percent: overallPct,
                label: 'Maîtrise générale',
                subLabel: '$completedNotions / $totalNotions notions terminées',
                isDark: isDark,
                primary: primary,
              ),
              const SizedBox(height: 14),

              // ── 3 KPI ────────────────────────────────────────────────────
              Row(
                children: [
                  _KpiTile(
                    icon: Icons.menu_book_rounded,
                    color: const Color(0xFF3498DB),
                    value: '$activeMatieres/${matieres.length}',
                    label: 'Matières actives',
                    isDark: isDark,
                  ),
                  const SizedBox(width: 10),
                  _KpiTile(
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF2ECC71),
                    value: '$successRate%',
                    label: 'Taux de réussite',
                    isDark: isDark,
                  ),
                  const SizedBox(width: 10),
                  _KpiTile(
                    icon: Icons.auto_graph_rounded,
                    color: const Color(0xFFE67E22),
                    value: totalExercises.toString(),
                    label: 'Exercices faits',
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Courbe de progression ────────────────────────────────────
              if (recentScores.isNotEmpty) ...[
                _SectionLabel(label: 'Courbe de progression', isDark: isDark),
                const SizedBox(height: 4),
                Text(
                  'Évolution des ${recentScores.length} derniers scores',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 12),
                _LineChartCard(
                  scores: recentScores,
                  isDark: isDark,
                  primary: primary,
                ),
                const SizedBox(height: 20),
              ],

              // ── Progression par matière ──────────────────────────────────
              _SectionLabel(label: 'Par matière', isDark: isDark),
              const SizedBox(height: 10),
              ...matiereProgressList.map(
                (item) => _MatiereProgressRow(
                  matiere: item['matiere'],
                  percent: item['percent'],
                  completed: item['completed'],
                  total: item['total'],
                  isDark: isDark,
                  primary: primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Vue détail par matière ───────────────────────────────────────────────────

class _MatiereView extends StatelessWidget {
  final String matiereId;
  const _MatiereView({required this.matiereId});

  @override
  Widget build(BuildContext context) {
    final progProvider = context.watch<ProgressionProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    final globPct = progProvider.getProgressionGlobale(matiereId);
    final notions = ModulesRegistry.getNotions(matiereId);
    final progs = progProvider.getProgressions(matiereId);

    int completedNotions = 0, inProgressNotions = 0;
    int totalExercises = 0, successfulExercises = 0;

    for (final notion in notions) {
      try {
        final p = progs.firstWhere((e) => e.notionId == notion.id);
        if (p.statut == 'termine') {
          completedNotions++;
        } else if (p.statut == 'en_cours') {
          inProgressNotions++;
        }
        totalExercises += p.nbExercicesTotal;
        successfulExercises += p.nbExercicesReussis;
      } catch (_) {}
    }

    final successRate = totalExercises > 0
        ? (successfulExercises / totalExercises * 100).toStringAsFixed(0)
        : '0';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero card
          _HeroCard(
            percent: globPct,
            label: 'Progression globale',
            subLabel: '$completedNotions/${notions.length} chapitres complétés',
            isDark: isDark,
            primary: primary,
            trailing: GestureDetector(
              onTap: () => _shareProgress(
                context,
                matiereId,
                globPct,
                completedNotions,
                notions.length,
                totalExercises,
                successRate,
              ),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.share_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 3 KPI
          Row(
            children: [
              _KpiTile(
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF2ECC71),
                value: completedNotions.toString(),
                label: 'Complétés',
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _KpiTile(
                icon: Icons.play_circle_rounded,
                color: primary,
                value: inProgressNotions.toString(),
                label: 'En cours',
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _KpiTile(
                icon: Icons.emoji_events_rounded,
                color: const Color(0xFFE67E22),
                value: '$successRate%',
                label: 'Taux réussite',
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Graphe donut
          _DonutCard(
            completed: completedNotions,
            inProgress: inProgressNotions,
            notStarted: notions.length - completedNotions - inProgressNotions,
            isDark: isDark,
            primary: primary,
          ),
          const SizedBox(height: 20),

          // Courbe de résultats
          _SubjectLineChartCard(
            matiereId: matiereId,
            isDark: isDark,
            primary: primary,
          ),
          const SizedBox(height: 20),

          // Liste des notions
          _SectionLabel(label: 'Détail par chapitre', isDark: isDark),
          const SizedBox(height: 10),
          ...notions.asMap().entries.map((entry) {
            final notion = entry.value;
            final prog = progs
                .where((p) => p.notionId == notion.id)
                .firstOrNull;
            return _NotionTile(
              notion: notion,
              prog: prog,
              index: entry.key + 1,
              isDark: isDark,
              primary: primary,
            );
          }),
          const SizedBox(height: 16),

          // Reset
          Center(
            child: TextButton.icon(
              onPressed: () => _confirmReset(context, progProvider),
              icon: const Icon(
                Icons.delete_forever_rounded,
                color: Colors.red,
                size: 18,
              ),
              label: const Text(
                'Réinitialiser ma progression',
                style: TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, ProgressionProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: isDark ? _kSurface : _kSurfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Réinitialiser ?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Toute votre progression dans cette matière sera perdue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              provider.resetProgression(matiereId);
              Navigator.pop(c);
            },
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareProgress(
    BuildContext context,
    String matiereId,
    double globPct,
    int completedNotions,
    int totalNotions,
    int totalExercises,
    String successRate,
  ) async {
    final matiere = ModulesRegistry.getMatiere(matiereId);
    await PdfExportService.shareProgressCard(
      matiereName: matiere?.nom ?? 'Matière inconnue',
      progressPercent: globPct,
      completedNotions: completedNotions,
      totalNotions: totalNotions,
      exercisesDone: totalExercises,
      successRate: successRate,
    );
  }
}

// ─── Onglet Badges ────────────────────────────────────────────────────────────

class _BadgesTab extends StatefulWidget {
  const _BadgesTab();

  @override
  State<_BadgesTab> createState() => _BadgesTabState();
}

class _BadgesTabState extends State<_BadgesTab> {
  String _selectedCategory = 'all';

  final Map<String, String> _categories = {
    'all': 'Tous',
    'streak': '🔥 Défis',
    'learning': '🎓 Cours',
    'algo': '💻 Code',
    'excellence': '⭐ Élite',
    'creative': '🎨 Création',
    'activity': '🌅 Activité',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    return FutureBuilder<List<AppBadge>>(
      future: BadgeService.instance.getAllBadgesWithLockState(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allBadges = snapshot.data ?? [];
        final unlockedCount = allBadges.where((b) => b.isUnlocked).length;
        final totalCount = allBadges.length;
        final unlockRatio = totalCount > 0 ? unlockedCount / totalCount : 0.0;

        final filteredBadges = _selectedCategory == 'all'
            ? allBadges
            : allBadges.where((b) => b.category == _selectedCategory).toList();

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Résumé badges ────────────────────────────────────────
                _BadgeSummaryCard(
                  unlockedCount: unlockedCount,
                  totalCount: totalCount,
                  unlockRatio: unlockRatio,
                  isDark: isDark,
                  primary: primary,
                ),
                const SizedBox(height: 16),

                // ── Filtre catégories ────────────────────────────────────
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.entries.map((entry) {
                      final isSelected = _selectedCategory == entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedCategory = entry.key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primary
                                  : (isDark
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : Colors.black.withValues(alpha: 0.04)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? primary
                                    : (isDark
                                          ? Colors.white.withValues(alpha: 0.1)
                                          : Colors.black.withValues(
                                              alpha: 0.08,
                                            )),
                              ),
                            ),
                            child: Text(
                              entry.value,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Grille de badges ────────────────────────────────────
                if (filteredBadges.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Aucun badge dans cette catégorie.',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 120,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: filteredBadges.length,
                    itemBuilder: (context, index) => _BadgeItem(
                      badge: filteredBadges[index],
                      isDark: isDark,
                      primary: primary,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Widgets réutilisables ────────────────────────────────────────────────────

/// Card hero avec progression circulaire et gradient
class _HeroCard extends StatelessWidget {
  final double percent;
  final String label;
  final String subLabel;
  final bool isDark;
  final Color primary;
  final Widget? trailing;

  const _HeroCard({
    required this.percent,
    required this.label,
    required this.subLabel,
    required this.isDark,
    required this.primary,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Anneau circulaire
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: percent / 100,
                  strokeWidth: 5,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: percent / 100,
                    minHeight: 5,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// Capsule KPI (icône + valeur + label)
class _KpiTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final bool isDark;

  const _KpiTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? _kSurface : _kSurfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 7),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF15151C),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne de progression d'une matière dans la vue globale
class _MatiereProgressRow extends StatelessWidget {
  final dynamic matiere;
  final double percent;
  final int completed;
  final int total;
  final bool isDark;
  final Color primary;

  const _MatiereProgressRow({
    required this.matiere,
    required this.percent,
    required this.completed,
    required this.total,
    required this.isDark,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? _kSurface : _kSurfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(matiere.icone, size: 14, color: primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  matiere.nom,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: isDark ? Colors.white : const Color(0xFF15151C),
                  ),
                ),
              ),
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: percent == 0
                      ? (isDark ? Colors.white38 : Colors.black38)
                      : primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 5,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(
                percent == 0 ? Colors.grey : primary,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '$completed sur $total notions terminées',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tile d'une notion dans la vue détail matière
class _NotionTile extends StatelessWidget {
  final dynamic notion;
  final dynamic prog;
  final int index;
  final bool isDark;
  final Color primary;

  const _NotionTile({
    required this.notion,
    required this.prog,
    required this.index,
    required this.isDark,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final statut = prog?.statut ?? 'non_commence';
    final reussis = prog?.nbExercicesReussis ?? 0;
    final total = prog?.nbExercicesTotal ?? 0;

    late IconData statusIcon;
    late Color statusColor;
    late String statusText;

    switch (statut) {
      case 'termine':
        statusIcon = Icons.check_circle_rounded;
        statusColor = const Color(0xFF2ECC71);
        statusText = 'Complété';
        break;
      case 'en_cours':
        statusIcon = Icons.play_circle_rounded;
        statusColor = primary;
        statusText = 'En cours';
        break;
      default:
        statusIcon = Icons.radio_button_unchecked_rounded;
        statusColor = isDark
            ? Colors.white24
            : Colors.black.withValues(alpha: 0.24);
        statusText = 'Non commencé';
    }

    final contexte = notion.contexte;
    final iconData = contexte != null
        ? CourseContextMapper.getIconForContext(contexte)
        : statusIcon;
    final iconColor = contexte != null
        ? CourseContextMapper.getColorForContext(contexte)
        : statusColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isDark ? _kSurface : _kSurfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notion.titre,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: isDark ? Colors.white : const Color(0xFF15151C),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  total > 0 ? '$reussis/$total exercices réussis' : statusText,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          Icon(statusIcon, color: statusColor, size: 18),
        ],
      ),
    );
  }
}

/// Card graphe en ligne (vue globale)
class _LineChartCard extends StatelessWidget {
  final List<Score> scores;
  final bool isDark;
  final Color primary;

  const _LineChartCard({
    required this.scores,
    required this.isDark,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(0, 16, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? _kSurface : _kSurfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: LineChart(_buildChartData(isDark, primary)),
    );
  }

  LineChartData _buildChartData(bool isDark, Color primary) {
    return LineChartData(
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (v) => FlLine(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i >= 0 &&
                  i < scores.length &&
                  i % (scores.length > 7 ? 3 : 1) == 0) {
                return Text(
                  '${i + 1}',
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 25,
            reservedSize: 36,
            getTitlesWidget: (v, _) => v > 100
                ? const SizedBox.shrink()
                : Text(
                    '${v.toInt()}%',
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: (scores.length - 1).toDouble(),
      minY: 0,
      maxY: 110,
      lineBarsData: [
        LineChartBarData(
          spots: scores
              .asMap()
              .entries
              .map((e) => FlSpot(e.key.toDouble(), e.value.pourcentage))
              .toList(),
          isCurved: true,
          preventCurveOverShooting: true,
          color: primary,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: primary.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }
}

/// Card graphe en ligne (vue matière)
class _SubjectLineChartCard extends StatelessWidget {
  final String matiereId;
  final bool isDark;
  final Color primary;

  const _SubjectLineChartCard({
    required this.matiereId,
    required this.isDark,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final scores = context.watch<ProgressionProvider>().getScores(matiereId);

    if (scores.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? _kSurface : _kSurfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.insights_rounded,
              size: 36,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            const SizedBox(height: 10),
            Text(
              'Aucun historique de scores',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF15151C),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Complétez des exercices pour voir votre évolution.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final display = scores.length > 10
        ? scores.sublist(scores.length - 10)
        : scores;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: 'Évolution des résultats', isDark: isDark),
        const SizedBox(height: 10),
        _LineChartCard(scores: display, isDark: isDark, primary: primary),
      ],
    );
  }
}

/// Card donut graphique
class _DonutCard extends StatelessWidget {
  final int completed, inProgress, notStarted;
  final bool isDark;
  final Color primary;

  const _DonutCard({
    required this.completed,
    required this.inProgress,
    required this.notStarted,
    required this.isDark,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final total = completed + inProgress + notStarted;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _kSurface : _kSurfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: 'Statut des chapitres', isDark: isDark),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 110,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 26,
                      startDegreeOffset: -90,
                      sections: [
                        if (completed > 0)
                          PieChartSectionData(
                            color: const Color(0xFF2ECC71),
                            value: completed.toDouble(),
                            title: '$completed',
                            radius: 16,
                            titleStyle: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        if (inProgress > 0)
                          PieChartSectionData(
                            color: primary,
                            value: inProgress.toDouble(),
                            title: '$inProgress',
                            radius: 16,
                            titleStyle: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        if (notStarted > 0)
                          PieChartSectionData(
                            color: isDark ? Colors.white24 : Colors.black12,
                            value: notStarted.toDouble(),
                            title: '$notStarted',
                            radius: 16,
                            titleStyle: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendDot(
                      label: 'Complétés',
                      color: const Color(0xFF2ECC71),
                      count: completed,
                      total: total,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _LegendDot(
                      label: 'En cours',
                      color: primary,
                      count: inProgress,
                      total: total,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _LegendDot(
                      label: 'Non commencés',
                      color: isDark ? Colors.white38 : Colors.black26,
                      count: notStarted,
                      total: total,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;
  final int count, total;
  final bool isDark;

  const _LegendDot({
    required this.label,
    required this.color,
    required this.count,
    required this.total,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label : $count ($pct%)',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Card résumé badges
class _BadgeSummaryCard extends StatelessWidget {
  final int unlockedCount, totalCount;
  final double unlockRatio;
  final bool isDark;
  final Color primary;

  const _BadgeSummaryCard({
    required this.unlockedCount,
    required this.totalCount,
    required this.unlockRatio,
    required this.isDark,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.15),
            primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.emoji_events_rounded, color: primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$unlockedCount / $totalCount badges débloqués',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF15151C),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: unlockRatio,
                    minHeight: 6,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation(primary),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${(unlockRatio * 100).toStringAsFixed(0)}% obtenus',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Item de badge dans la grille
class _BadgeItem extends StatelessWidget {
  final AppBadge badge;
  final bool isDark;
  final Color primary;

  const _BadgeItem({
    required this.badge,
    required this.isDark,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isDark ? _kSurface : _kSurfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: badge.isUnlocked
                ? primary.withValues(alpha: 0.35)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05)),
            width: badge.isUnlocked ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Opacity(
                opacity: badge.isUnlocked ? 1.0 : 0.4,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: badge.isUnlocked
                        ? primary.withValues(alpha: 0.1)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.04)),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      badge.icone,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                badge.nom,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: badge.isUnlocked
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: badge.isUnlocked
                      ? (isDark ? Colors.white : const Color(0xFF15151C))
                      : (isDark ? Colors.white38 : Colors.black38),
                ),
              ),
              if (!badge.isUnlocked) ...[
                const SizedBox(height: 2),
                Icon(
                  Icons.lock_rounded,
                  size: 10,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final dateStr = badge.unlockedAt != null
        ? '${badge.unlockedAt!.day.toString().padLeft(2, '0')}/'
              '${badge.unlockedAt!.month.toString().padLeft(2, '0')}/'
              '${badge.unlockedAt!.year}'
        : '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? _kSurface : _kSurfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 24),
            // Icône
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: badge.isUnlocked
                    ? primary.withValues(alpha: 0.12)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.05)),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(badge.icone, style: const TextStyle(fontSize: 44)),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              badge.nom,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF15151C),
              ),
            ),
            const SizedBox(height: 10),
            // Statut pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: badge.isUnlocked
                    ? const Color(0xFF2ECC71).withValues(alpha: 0.12)
                    : Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: badge.isUnlocked
                      ? const Color(0xFF2ECC71).withValues(alpha: 0.4)
                      : Colors.orange.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    badge.isUnlocked
                        ? Icons.check_circle_rounded
                        : Icons.lock_rounded,
                    size: 13,
                    color: badge.isUnlocked
                        ? const Color(0xFF2ECC71)
                        : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    badge.isUnlocked
                        ? 'Débloqué le $dateStr'
                        : 'Badge verrouillé',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: badge.isUnlocked
                          ? const Color(0xFF2ECC71)
                          : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              badge.conditionDesc,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              badge.description,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Fermer',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label de section en majuscules (style dashboard)
class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;

  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: isDark ? Colors.white38 : Colors.black38,
      ),
    );
  }
}
