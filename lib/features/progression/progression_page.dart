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

class ProgressionPage extends StatelessWidget {
  const ProgressionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tableau de bord'),
          bottom: TabBar(
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: isDark ? Colors.grey[500] : Colors.grey[600],
            indicatorColor: Theme.of(context).primaryColor,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(icon: Icon(Icons.analytics_rounded), text: 'Statistiques'),
              Tab(
                icon: Icon(Icons.emoji_events_rounded),
                text: 'Badges & Récompenses',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_CoursesProgressionView(), _BadgesGridTab()],
        ),
      ),
    );
  }
}

class _CoursesProgressionView extends StatelessWidget {
  const _CoursesProgressionView();

  @override
  Widget build(BuildContext context) {
    if (ModulesRegistry.matieres.isEmpty) {
      return const Center(child: Text("Aucune matière pour le moment"));
    }
    return DefaultTabController(
      length: ModulesRegistry.matieres.length + 1,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: [
              const Tab(text: "Vue d'ensemble"),
              ...ModulesRegistry.matieres.map((m) => Tab(text: m.nom)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                const _GlobalSynthesisView(),
                ...ModulesRegistry.matieres
                    .map((m) => _ProgressionTab(matiereId: m.id))
                    .toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressionTab extends StatelessWidget {
  final String matiereId;

  const _ProgressionTab({required this.matiereId});

  @override
  Widget build(BuildContext context) {
    final progProvider = context.watch<ProgressionProvider>();
    final globPct = progProvider.getProgressionGlobale(matiereId);
    final notions = ModulesRegistry.getNotions(matiereId);
    final progs = progProvider.getProgressions(matiereId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate detailed stats
    int completedNotions = 0;
    int inProgressNotions = 0;
    int totalExercises = 0;
    int successfulExercises = 0;

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
      } catch (e) {
        // Notion not started
      }
    }

    final int notStartedNotions =
        notions.length - completedNotions - inProgressNotions;

    final successRate = totalExercises > 0
        ? (successfulExercises / totalExercises * 100).toStringAsFixed(0)
        : '0';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main progress card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Progression globale",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${globPct.toStringAsFixed(0)}%",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "$completedNotions/${notions.length} chapitres complétés",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.share,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Stats grid
          Row(
            children: [
              _buildStatCard(
                context,
                icon: Icons.check_circle,
                label: "Complétés",
                value: completedNotions.toString(),
                color: Colors.green,
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                context,
                icon: Icons.play_circle,
                label: "En cours",
                value: inProgressNotions.toString(),
                color: Colors.orange,
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                context,
                icon: Icons.analytics_outlined,
                label: "Taux de réussite",
                value: "$successRate%",
                color: Colors.blue,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Chart section
          if (notions.isNotEmpty) ...[
            _buildDonutChart(
              context,
              completedNotions,
              inProgressNotions,
              notStartedNotions,
              isDark,
            ),
            const SizedBox(height: 16),
            _buildSubjectLineChart(
              context,
              progProvider.getScores(matiereId),
              isDark,
            ),
          ],

          // Notions list
          const SizedBox(height: 24),
          const Text(
            "Détail par chapitre",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...notions.asMap().entries.map((entry) {
            final i = entry.key;
            final notion = entry.value;
            final prog = progs
                .where((p) => p.notionId == notion.id)
                .firstOrNull;
            return _buildNotionProgressTile(
              context,
              notion,
              prog,
              i + 1,
              isDark,
            );
          }),

          const SizedBox(height: 32),
          Center(
            child: TextButton.icon(
              onPressed: () => _confirmReset(context, progProvider),
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              label: const Text(
                "Réinitialiser ma progression",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: color.withOpacity(isDark ? 0.15 : 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotionProgressTile(
    BuildContext context,
    dynamic notion,
    dynamic prog,
    int index,
    bool isDark,
  ) {
    final statut = prog?.statut ?? 'non_commence';
    final reussis = prog?.nbExercicesReussis ?? 0;
    final total = prog?.nbExercicesTotal ?? 0;

    IconData statusIcon;
    Color statusColor;
    String statusText;

    switch (statut) {
      case 'termine':
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        statusText = 'Complété';
        break;
      case 'en_cours':
        statusIcon = Icons.play_circle;
        statusColor = Theme.of(context).primaryColor;
        statusText = 'En cours';
        break;
      default:
        statusIcon = Icons.lock_outline;
        statusColor = isDark ? Colors.grey[600]! : Colors.grey[400]!;
        statusText = 'Non commencé';
    }

    final contexte = notion.contexte;
    final iconData = contexte != null
        ? CourseContextMapper.getIconForContext(contexte)
        : statusIcon;
    final iconColor = contexte != null
        ? CourseContextMapper.getColorForContext(contexte)
        : statusColor;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(iconData, color: iconColor, size: 22),
        ),
        title: Text(
          notion.titre,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          total > 0 ? '$reussis/$total exercices réussis' : statusText,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        trailing: Icon(statusIcon, color: statusColor, size: 20),
      ),
    );
  }

  void _confirmReset(BuildContext context, ProgressionProvider provider) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Attention"),
        content: const Text(
          "Toute votre progression dans cette matière sera perdue. Êtes-vous sûr ?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () {
              provider.resetProgression(matiereId);
              Navigator.pop(c);
            },
            child: const Text("Oui", style: TextStyle(color: Colors.red)),
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

  Widget _buildDonutChart(
    BuildContext context,
    int completed,
    int enCours,
    int nonCommence,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final total = completed + enCours + nonCommence;
    if (total == 0) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Statut des Chapitres",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ClipRect(
                    child: SizedBox(
                      height: 120,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: 28,
                          startDegreeOffset: -90,
                          sections: [
                            if (completed > 0)
                              PieChartSectionData(
                                color: Colors.green,
                                value: completed.toDouble(),
                                title: '$completed',
                                radius: 16,
                                titleStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            if (enCours > 0)
                              PieChartSectionData(
                                color: theme.primaryColor,
                                value: enCours.toDouble(),
                                title: '$enCours',
                                radius: 16,
                                titleStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            if (nonCommence > 0)
                              PieChartSectionData(
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey[300]!,
                                value: nonCommence.toDouble(),
                                title: '$nonCommence',
                                radius: 16,
                                titleStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem(
                        "Complétés",
                        Colors.green,
                        completed,
                        total,
                      ),
                      const SizedBox(height: 8),
                      _buildLegendItem(
                        "En cours",
                        theme.primaryColor,
                        enCours,
                        total,
                      ),
                      const SizedBox(height: 8),
                      _buildLegendItem(
                        "Non commencés",
                        isDark ? Colors.grey[600]! : Colors.grey[400]!,
                        nonCommence,
                        total,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int count, int total) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "$label : $count ($pct%)",
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectLineChart(
    BuildContext context,
    List<Score> scores,
    bool isDark,
  ) {
    if (scores.isEmpty) {
      return Card(
        elevation: 0,
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(Icons.insights_rounded, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                "Aucun historique de score",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text(
                "Complétez des exercices pour voir votre évolution !",
                style: TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final displayScores = scores.length > 10
        ? scores.sublist(scores.length - 10)
        : scores;

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Évolution des Résultats",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              "Pourcentage de réussite par tentative",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    clipData: const FlClipData.all(),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: false,
                          reservedSize: 8,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx >= 0 && idx < displayScores.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  "T${idx + 1}",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                                ),
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
                          getTitlesWidget: (value, meta) {
                            if (value > 100) return const SizedBox.shrink();
                            return Text(
                              "${value.toInt()}%",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: (displayScores.length - 1).toDouble(),
                    minY: 0,
                    maxY: 110,
                    lineBarsData: [
                      LineChartBarData(
                        spots: displayScores.asMap().entries.map((entry) {
                          return FlSpot(
                            entry.key.toDouble(),
                            entry.value.pourcentage,
                          );
                        }).toList(),
                        isCurved: true,
                        preventCurveOverShooting: true,
                        color: theme.primaryColor,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: theme.primaryColor.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgesGridTab extends StatefulWidget {
  const _BadgesGridTab();

  @override
  State<_BadgesGridTab> createState() => _BadgesGridTabState();
}

class _BadgesGridTabState extends State<_BadgesGridTab> {
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FutureBuilder<List<AppBadge>>(
      future: BadgeService.instance.getAllBadgesWithLockState(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final allBadges = snapshot.data ?? [];
        final unlockedCount = allBadges.where((b) => b.isUnlocked).length;
        final totalCount = allBadges.length;
        final unlockRatio = totalCount > 0 ? unlockedCount / totalCount : 0.0;

        final filteredBadges = _selectedCategory == 'all'
            ? allBadges
            : allBadges.where((b) => b.category == _selectedCategory).toList();

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1E2A3A), const Color(0xFF1A3A5A)]
                            : [
                                theme.primaryColor.withOpacity(0.05),
                                theme.primaryColor.withOpacity(0.12),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.emoji_events_rounded,
                                color: theme.primaryColor,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Succès & Récompenses',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$unlockedCount sur $totalCount badges débloqués',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.grey[300]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: unlockRatio,
                            minHeight: 8,
                            backgroundColor: isDark
                                ? Colors.grey[800]
                                : Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progression',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                            Text(
                              '${(unlockRatio * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.entries.map((entry) {
                      final isSelected = _selectedCategory == entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(entry.value),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedCategory = entry.key;
                              });
                            }
                          },
                          selectedColor: theme.primaryColor.withOpacity(0.2),
                          checkmarkColor: theme.primaryColor,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? theme.primaryColor
                                : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                filteredBadges.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text(
                            'Aucun badge dans cette catégorie.',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 130,
                              childAspectRatio: 0.82,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        itemCount: filteredBadges.length,
                        itemBuilder: (context, index) {
                          final badge = filteredBadges[index];
                          return _buildBadgeItem(context, badge, isDark, theme);
                        },
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadgeItem(
    BuildContext context,
    AppBadge badge,
    bool isDark,
    ThemeData theme,
  ) {
    return GestureDetector(
      onTap: () => _showBadgeDetailSheet(context, badge, isDark, theme),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: badge.isUnlocked
                ? theme.primaryColor.withOpacity(0.3)
                : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
            width: badge.isUnlocked ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.1 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Opacity(
                      opacity: badge.isUnlocked ? 1.0 : 0.45,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: badge.isUnlocked
                              ? theme.primaryColor.withOpacity(0.1)
                              : (isDark ? Colors.grey[800] : Colors.grey[100]),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badge.icone,
                          style: const TextStyle(fontSize: 30),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      badge.nom,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: badge.isUnlocked
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: badge.isUnlocked
                            ? (isDark ? Colors.white : Colors.black87)
                            : (isDark ? Colors.grey[500] : Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
              if (!badge.isUnlocked)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    Icons.lock_rounded,
                    size: 14,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBadgeDetailSheet(
    BuildContext context,
    AppBadge badge,
    bool isDark,
    ThemeData theme,
  ) {
    final String dateStr = badge.unlockedAt != null
        ? "${badge.unlockedAt!.day.toString().padLeft(2, '0')}/${badge.unlockedAt!.month.toString().padLeft(2, '0')}/${badge.unlockedAt!.year}"
        : "";

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: badge.isUnlocked
                      ? theme.primaryColor.withOpacity(0.1)
                      : (isDark ? Colors.grey[800] : Colors.grey[100]),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(badge.icone, style: const TextStyle(fontSize: 44)),
              ),
              const SizedBox(height: 16),
              Text(
                badge.nom,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badge.isUnlocked
                      ? Colors.green.withOpacity(0.12)
                      : Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: badge.isUnlocked
                        ? Colors.green.withOpacity(0.4)
                        : Colors.orange.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      badge.isUnlocked
                          ? Icons.check_circle_rounded
                          : Icons.lock_rounded,
                      size: 14,
                      color: badge.isUnlocked ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      badge.isUnlocked
                          ? 'Débloqué le $dateStr'
                          : 'Badge Verrouillé',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: badge.isUnlocked ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Objectif : ${badge.conditionDesc}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                badge.description,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[300] : Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Fermer',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GlobalSynthesisView extends StatelessWidget {
  const _GlobalSynthesisView();

  @override
  Widget build(BuildContext context) {
    final progProvider = context.watch<ProgressionProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    // Calculate global stats across all matieres
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
        } catch (e) {}
      }

      matiereProgressList.add({
        'matiere': m,
        'percent': globPct,
        'completed': mCompleted,
        'total': notions.length,
      });
    }

    final overallSuccessRate = totalExercises > 0
        ? (successfulExercises / totalExercises * 100).toInt()
        : 0;

    final overallProgress = totalNotions > 0
        ? ((completedNotions + inProgressNotions * 0.5) / totalNotions * 100)
              .clamp(0.0, 100.0)
        : 0.0;

    return FutureBuilder<List<Score>>(
      future: progProvider.getAllRecentScores(15),
      builder: (context, snapshot) {
        final recentScores = snapshot.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Global Score overview card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        theme.primaryColor,
                        theme.primaryColor.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Maîtrise Générale",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${overallProgress.toStringAsFixed(0)}%",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "$completedNotions / $totalNotions notions",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: overallProgress / 100,
                            minHeight: 8,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // KPI stats row
              Row(
                children: [
                  _buildKpiCard(
                    context,
                    title: "Matières actives",
                    value: "$activeMatieres/${matieres.length}",
                    icon: Icons.book_rounded,
                    color: Colors.orange,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  _buildKpiCard(
                    context,
                    title: "Taux Réussite",
                    value: "$overallSuccessRate%",
                    icon: Icons.assignment_turned_in_rounded,
                    color: Colors.green,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  _buildKpiCard(
                    context,
                    title: "Ex. Réalisés",
                    value: totalExercises.toString(),
                    icon: Icons.auto_graph_rounded,
                    color: Colors.blue,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recent progress Chart
              if (recentScores.isNotEmpty) ...[
                const Text(
                  "Courbe de Progression",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  "Évolution de tes derniers scores d'exercices",
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 240,
                  padding: const EdgeInsets.only(right: 16, top: 24, bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: LineChart(
                      LineChartData(
                        clipData: const FlClipData.all(),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: false,
                              reservedSize: 8,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 24,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 &&
                                    index < recentScores.length &&
                                    index % (recentScores.length > 5 ? 2 : 1) == 0) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      "${index + 1}",
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 10,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 20,
                              reservedSize: 38,
                              getTitlesWidget: (value, meta) {
                                if (value > 100) return const SizedBox.shrink();
                                return Text(
                                  "${value.toInt()}%",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: (recentScores.length - 1).toDouble(),
                        minY: 0,
                        maxY: 110,
                        lineBarsData: [
                          LineChartBarData(
                            spots: recentScores.asMap().entries.map((entry) {
                              return FlSpot(
                                entry.key.toDouble(),
                                entry.value.pourcentage,
                              );
                            }).toList(),
                            isCurved: true,
                            preventCurveOverShooting: true,
                            color: theme.primaryColor,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: theme.primaryColor.withOpacity(0.15),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Matiere progress breakdown
              const Text(
                "Progression par matière",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...matiereProgressList.map((item) {
                final m = item['matiere'];
                final double percent = item['percent'];
                final int completed = item['completed'];
                final int total = item['total'];
                final color = theme.primaryColor;

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              m.nom,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              "${percent.toStringAsFixed(0)}%",
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: percent / 100,
                            minHeight: 6,
                            backgroundColor: isDark
                                ? Colors.grey[800]
                                : Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "$completed sur $total notions terminées",
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(isDark ? 0.2 : 0.15),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 9,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
