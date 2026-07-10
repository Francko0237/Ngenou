import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/defis_provider.dart';
import '../../../core/models/daily_challenge.dart';

/// Onglet historique des sessions de défis quotidiens.
/// Affiche chaque session passée avec score, date, progression,
/// et un bloc "Évolution" pour visualiser la tendance.
class DefisHistoryTab extends StatefulWidget {
  const DefisHistoryTab({super.key});

  @override
  State<DefisHistoryTab> createState() => _DefisHistoryTabState();
}

class _DefisHistoryTabState extends State<DefisHistoryTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DefisProvider>().loadHistoryAndStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    return Consumer<DefisProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final history = provider.history;

        if (history.isEmpty) {
          return _buildEmptyState(isDark);
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Bloc statistiques globales
            _buildStatsCard(provider.statsSummary, isDark, primary),
            const SizedBox(height: 20),

            // Bloc évolution (graphique barre)
            _buildEvolutionCard(history, isDark, primary),
            const SizedBox(height: 20),

            // Liste des sessions
            Text(
              'Sessions passées',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            ...history.map((session) => _buildSessionCard(session, isDark, primary)),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  // ── État vide ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 72,
              color: isDark ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 20),
            Text(
              'Aucun historique pour l\'instant',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complétez votre premier défi du jour\npour voir votre historique et progression ici.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bloc stats ──────────────────────────────────────────────────────────

  Widget _buildStatsCard(String summary, bool isDark, Color primary) {
    // Parsing du summary pour extraire les chiffres
    // Format: 'Défis: X/Y complétés. Taux réussite: Z%. Derniers scores: [a/b/c/d/e/5].'
    int completed = 0, total = 0;
    double successRate = 0;

    try {
      final defisMatch = RegExp(r'(\d+)/(\d+) complétés').firstMatch(summary);
      if (defisMatch != null) {
        completed = int.parse(defisMatch.group(1)!);
        total = int.parse(defisMatch.group(2)!);
      }
      final rateMatch = RegExp(r'Taux réussite: (\d+)%').firstMatch(summary);
      if (rateMatch != null) successRate = double.parse(rateMatch.group(1)!);
    } catch (_) {}

    Color rateColor = successRate >= 80
        ? Colors.green
        : successRate >= 60
            ? Colors.orange
            : Colors.red.shade400;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A2A3A), const Color(0xFF1A3A5A)]
              : [const Color(0xFF3498DB), const Color(0xFF1A6FA8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3498DB).withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Statistiques globales',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem(
                '$completed/$total',
                'Sessions\ncomplétées',
                Icons.check_circle_rounded,
                Colors.white,
              ),
              Container(width: 1, height: 50, color: Colors.white24),
              _statItem(
                '${successRate.toStringAsFixed(0)}%',
                'Taux de\nréussite',
                Icons.trending_up_rounded,
                rateColor == Colors.green
                    ? Colors.greenAccent
                    : rateColor == Colors.orange
                        ? Colors.orange[200]!
                        : Colors.red[200]!,
              ),
              Container(width: 1, height: 50, color: Colors.white24),
              _statItem(
                '$total',
                'Sessions\ntotales',
                Icons.calendar_today_rounded,
                Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, IconData icon, Color valueColor) {
    return Column(
      children: [
        Icon(icon, color: valueColor, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: valueColor,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.75),
            height: 1.3,
          ),
        ),
      ],
    );
  }

  // ── Bloc évolution ──────────────────────────────────────────────────────

  Widget _buildEvolutionCard(
    List<DailyChallengeSession> history,
    bool isDark,
    Color primary,
  ) {
    // Prendre les 7 dernières sessions
    final recent = history.take(7).toList().reversed.toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, color: primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Évolution (7 derniers jours)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: recent.map((session) {
                final percent = session.total > 0
                    ? session.score / session.total
                    : 0.0;
                final date = _formatDateShort(session.date);
                Color barColor = percent >= 0.8
                    ? Colors.green
                    : percent >= 0.6
                        ? Colors.orange
                        : Colors.red.shade400;
                if (!session.completed) barColor = Colors.grey;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          session.completed
                              ? '${(percent * 100).toInt()}%'
                              : '…',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: barColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOut,
                          width: double.infinity,
                          height: session.completed
                              ? (percent * 70).clamp(6, 70)
                              : 6,
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: 9,
                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Carte session ───────────────────────────────────────────────────────

  Widget _buildSessionCard(DailyChallengeSession session, bool isDark, Color primary) {
    final score = session.score;
    final total = session.total;
    final percent = total > 0 ? (score / total * 100).toInt() : 0;

    Color resultColor;
    IconData resultIcon;
    if (!session.completed) {
      resultColor = Colors.grey;
      resultIcon = Icons.hourglass_empty_rounded;
    } else if (percent >= 80) {
      resultColor = Colors.green;
      resultIcon = Icons.emoji_events_rounded;
    } else if (percent >= 60) {
      resultColor = Colors.orange;
      resultIcon = Icons.thumb_up_rounded;
    } else {
      resultColor = Colors.red.shade400;
      resultIcon = Icons.sentiment_dissatisfied_rounded;
    }

    final hasAlgo = session.inclutAlgo;
    final qcmCount = session.challenges.where((c) => c.type == 'qcm').length;
    final algoCount = session.challenges.where((c) => c.type == 'algo').length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: session.completed
              ? resultColor.withValues(alpha: 0.3)
              : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showSessionDetail(session, isDark, primary),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icône résultat
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: resultColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(resultIcon, color: resultColor, size: 24),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateFull(session.date),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _typeTag(
                          '$qcmCount QCM',
                          const Color(0xFF3498DB),
                          isDark,
                        ),
                        if (hasAlgo) ...[
                          const SizedBox(width: 6),
                          _typeTag(
                            '$algoCount Algo',
                            Colors.orange,
                            isDark,
                          ),
                        ],
                        if (!session.completed) ...[
                          const SizedBox(width: 6),
                          _typeTag('Incomplet', Colors.grey, isDark),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Score
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$score/$total',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: resultColor,
                    ),
                  ),
                  Text(
                    session.completed ? '$percent%' : '—',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeTag(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ── Détail session ──────────────────────────────────────────────────────

  void _showSessionDetail(
    DailyChallengeSession session,
    bool isDark,
    Color primary,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Icon(Icons.event_rounded, color: primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _formatDateFull(session.date),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${session.score}/${session.total}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  itemCount: session.challenges.length,
                  itemBuilder: (context, i) {
                    final c = session.challenges[i];
                    final isCorrect = c.type == 'qcm'
                        ? c.userAnswerIndex == c.bonneReponseIndex
                        : c.isSolved;
                    final answered = c.type == 'qcm'
                        ? c.userAnswerIndex != null
                        : c.isSolved;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF252525) : const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: !answered
                              ? (isDark ? Colors.grey[800]! : Colors.grey[200]!)
                              : isCorrect
                                  ? Colors.green.withValues(alpha: 0.3)
                                  : Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            !answered
                                ? Icons.radio_button_unchecked
                                : isCorrect
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                            color: !answered
                                ? Colors.grey
                                : isCorrect
                                    ? Colors.green
                                    : Colors.red.shade400,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      c.type.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: c.type == 'algo'
                                            ? Colors.orange
                                            : const Color(0xFF3498DB),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '· ${c.matiereNom}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  c.question,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (c.type == 'qcm' && c.userAnswerIndex != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Votre réponse : ${c.options.length > c.userAnswerIndex! ? c.options[c.userAnswerIndex!] : "?"}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isCorrect ? Colors.green : Colors.red.shade400,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers date ─────────────────────────────────────────────────────────

  String _formatDateShort(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jui', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
      return '${d.day} ${months[d.month - 1]}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDateFull(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      const months = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
      const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      return '${days[d.weekday - 1]}. ${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
