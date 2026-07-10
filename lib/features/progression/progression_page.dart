import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/providers/progression_provider.dart';
import '../../core/services/pdf_export_service.dart';
import '../../core/utils/course_context_mapper.dart';
import '../../modules/modules_registry.dart';

class ProgressionPage extends StatelessWidget {
  const ProgressionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: ModulesRegistry.matieres.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tableau de bord'),
          bottom: TabBar(
            isScrollable: true,
            tabs: ModulesRegistry.matieres
                .map((m) => Tab(text: m.nom))
                .toList(),
          ),
        ),
        body: TabBarView(
          children: ModulesRegistry.matieres
              .map((m) => _ProgressionTab(matiereId: m.id))
              .toList(),
        ),
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
            const Text(
              "Activité par chapitre",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Exercices réussis par chapitre",
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 5,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 &&
                              value.toInt() < notions.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                "C${value.toInt() + 1}",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }
                          return const Text("");
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(notions.length, (i) {
                    final notion = notions[i];
                    int reussis = 0;
                    String statut = 'non_commence';
                    try {
                      if (progs.isNotEmpty) {
                        final p = progs.firstWhere(
                          (e) => e.notionId == notion.id,
                        );
                        reussis = p.nbExercicesReussis;
                        statut = p.statut;
                      }
                    } catch (e) {}

                    Color barColor;
                    if (statut == 'termine') {
                      barColor = Colors.green;
                    } else if (statut == 'en_cours') {
                      barColor = Theme.of(context).primaryColor;
                    } else {
                      barColor = isDark ? Colors.grey[700]! : Colors.grey[400]!;
                    }

                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: reussis.toDouble().clamp(0, 5),
                          color: barColor,
                          width: 14,
                          borderRadius: BorderRadius.circular(6),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: 5,
                            color:
                                (isDark ? Colors.grey[800] : Colors.grey[300])!
                                    .withOpacity(0.3),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
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
}
