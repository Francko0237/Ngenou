import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/defis_provider.dart';
import '../../core/models/daily_challenge.dart';
import '../../core/models/deep_seek_model.dart';
import 'widgets/qcm_solve_widget.dart';
import 'widgets/defis_history_tab.dart';
import 'daily_defi_algo_solve_page.dart';

class DailyDefisPage extends StatefulWidget {
  const DailyDefisPage({super.key});

  @override
  State<DailyDefisPage> createState() => _DailyDefisPageState();
}

class _DailyDefisPageState extends State<DailyDefisPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _inclutAlgo = true;
  DeepSeekModel _selectedModel = DeepSeekModel.flash;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DefisProvider>().loadTodaySession();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF2C3E50), const Color(0xFF3498DB)]
                      : [const Color(0xFF3498DB), const Color(0xFF2980B9)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Défis quotidiens',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          _buildModelSelector(isDark, primary),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: primary,
          unselectedLabelColor: isDark ? Colors.grey[500] : Colors.grey[600],
          indicatorColor: primary,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: "Aujourd'hui"),
            Tab(text: 'Historique'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildTodayTab(isDark, primary), const DefisHistoryTab()],
      ),
    );
  }

  // ── Onglet aujourd'hui ───────────────────────────────────────────────────

  Widget _buildTodayTab(bool isDark, Color primary) {
    return Consumer<DefisProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return _buildLoadingScreen(isDark, primary);
        }
        if (provider.errorMessage != null) {
          return _buildErrorScreen(
            provider.errorMessage!,
            isDark,
            primary,
            provider,
          );
        }
        final session = provider.todaySession;
        if (session == null) {
          return _buildLandingScreen(isDark, primary, provider);
        }
        return _buildCardsScreen(session, isDark, primary, provider);
      },
    );
  }

  // ── Chargement ───────────────────────────────────────────────────────────

  Widget _buildLoadingScreen(bool isDark, Color primary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF2C3E50), const Color(0xFF3498DB)]
                    : [const Color(0xFF3498DB), const Color(0xFF2980B9)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "L'IA génère vos défis…",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Basé sur vos matières, personnalisé pour vous',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          CircularProgressIndicator(color: primary),
        ],
      ),
    );
  }

  // ── Erreur ───────────────────────────────────────────────────────────────

  Widget _buildErrorScreen(
    String error,
    bool isDark,
    Color primary,
    DefisProvider provider,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Erreur de génération',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              onPressed: () {
                provider.clearError();
                provider.generateTodaySession(
                  inclutAlgo: _inclutAlgo,
                  model: _selectedModel,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Landing / Génération ─────────────────────────────────────────────────

  Widget _buildLandingScreen(
    bool isDark,
    Color primary,
    DefisProvider provider,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1A2A3A), const Color(0xFF1A3A5A)]
                    : [const Color(0xFF3498DB), const Color(0xFF1A6FA8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3498DB).withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    size: 52,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Défi du jour',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "L'IA génère une série de 5 défis\npersonnalisés selon vos matières",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          // Info cards
          Row(
            children: [
              _infoCard(Icons.quiz_rounded, '4–5 QCM', 'Par matière', isDark),
              _infoCard(
                Icons.terminal_rounded,
                '1 Algo',
                'Code terminal',
                isDark,
              ),
              _infoCard(
                Icons.touch_app_rounded,
                'Libre',
                'Choisissez l\'ordre',
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 28),
          // Toggle algo
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.terminal_rounded, color: primary, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      "Exercice d'algorithmique",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Switch.adaptive(
                      value: _inclutAlgo,
                      onChanged: (v) => setState(() => _inclutAlgo = v),
                      activeColor: primary,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _inclutAlgo
                      ? '✅ 1 exercice de code terminal inclus (par défaut)'
                      : "⭕ Uniquement des QCM pour aujourd'hui",
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome_rounded, size: 20),
              label: const Text(
                'Générer mes défis du jour',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 4,
                shadowColor: primary.withValues(alpha: 0.4),
              ),
              onPressed: () => provider.generateTodaySession(
                inclutAlgo: _inclutAlgo,
                model: _selectedModel,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Sélecteur de modèle (AppBar) ────────────────────────────────────────

  Widget _buildModelSelector(bool isDark, Color primary) {
    final isPro = _selectedModel == DeepSeekModel.pro;
    return GestureDetector(
      onTap: () => _showModelPicker(isDark, primary),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isPro
              ? const Color(0xFF6C3FE8).withValues(alpha: 0.15)
              : (isDark
                    ? Colors.grey[800]!.withValues(alpha: 0.8)
                    : Colors.grey[200]!),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPro
                ? const Color(0xFF6C3FE8).withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPro ? Icons.auto_awesome : Icons.bolt_rounded,
              size: 14,
              color: isPro
                  ? const Color(0xFF6C3FE8)
                  : (isDark ? Colors.grey[300] : Colors.grey[700]),
            ),
            const SizedBox(width: 4),
            Text(
              _selectedModel.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isPro
                    ? const Color(0xFF6C3FE8)
                    : (isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.expand_more_rounded,
              size: 14,
              color: isPro
                  ? const Color(0xFF6C3FE8)
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  void _showModelPicker(bool isDark, Color primary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ModelPickerSheet(
        currentModel: _selectedModel,
        isDark: isDark,
        onSelected: (m) => setState(() => _selectedModel = m),
      ),
    );
  }

  Widget _infoCard(IconData icon, String title, String subtitle, bool isDark) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF3498DB), size: 26),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Écran des 5 cartes ───────────────────────────────────────────────────

  Widget _buildCardsScreen(
    DailyChallengeSession session,
    bool isDark,
    Color primary,
    DefisProvider provider,
  ) {
    final challenges = session.challenges;
    final score = session.score;
    final total = session.total;
    final done = challenges
        .where((c) => c.type == 'qcm' ? c.userAnswerIndex != null : c.isSolved)
        .length;

    return Column(
      children: [
        // ── En-tête score + progression ──
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$done / $total défis réalisés',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primary, primary.withValues(alpha: 0.7)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$score / $total',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: total > 0 ? done / total : 0,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(primary),
                  minHeight: 6,
                ),
              ),
              if (session.completed) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Session complétée ! Score final : $score/$total',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Liste des 5 cartes ──
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: challenges.length,
            itemBuilder: (context, i) {
              return _buildDefiCard(
                challenges[i],
                i,
                isDark,
                primary,
                provider,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDefiCard(
    DailyChallenge challenge,
    int index,
    bool isDark,
    Color primary,
    DefisProvider provider,
  ) {
    final isAlgo = challenge.type == 'algo';
    final answered = isAlgo
        ? (challenge.isSolved || challenge.isFailed)
        : challenge.userAnswerIndex != null;
    final isCorrect = isAlgo
        ? challenge.isSolved
        : (challenge.userAnswerIndex == challenge.bonneReponseIndex);

    // Couleur et icône selon statut
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    if (!answered) {
      statusColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
      statusIcon = Icons.play_circle_outline_rounded;
      statusLabel = 'À faire';
    } else if (isCorrect) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_rounded;
      statusLabel = 'Réussi';
    } else {
      statusColor = Colors.red.shade400;
      statusIcon = Icons.cancel_rounded;
      statusLabel = 'Incorrect';
    }

    Color typeColor = isAlgo ? Colors.orange : const Color(0xFF3498DB);

    return GestureDetector(
      onTap: () => _openDefi(challenge, index, isDark, primary, provider),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: answered
                ? statusColor.withValues(alpha: 0.5)
                : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
            width: answered ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              // Numéro du défi
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: typeColor,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Contenu
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(
                          isAlgo ? Icons.terminal_rounded : Icons.quiz_rounded,
                          color: typeColor,
                          size: 14,
                        ),
                        Text(
                          isAlgo ? 'Algorithme' : 'QCM',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: typeColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF3498DB,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            challenge.matiereNom,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF3498DB),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      challenge.question,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Statut
              Column(
                children: [
                  Icon(statusIcon, color: statusColor, size: 26),
                  const SizedBox(height: 2),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
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

  // ── Ouverture d'un défi ──────────────────────────────────────────────────

  void _openDefi(
    DailyChallenge challenge,
    int index,
    bool isDark,
    Color primary,
    DefisProvider provider,
  ) {
    if (challenge.type == 'algo') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DailyDefiAlgoSolvePage(
            challenge: challenge,
            challengeIndex: index,
            onSolved: () => provider.markAlgoSolved(index),
            onFailed: () => provider.markAlgoFailed(index),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.97,
        minChildSize: 0.5,
        builder: (ctx2, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF9FAFB),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Défi ${index + 1} · QCM',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Contenu du défi
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: QcmSolveWidget(
                    key: ValueKey('qcm_$index'),
                    challenge: challenge,
                    challengeIndex: index,
                    onAnswer: (optIdx) {
                      provider.answerQcm(index, optIdx);
                    },
                    onNext: () => Navigator.pop(ctx),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom-sheet de sélection du modèle Ngenou — réutilisé dans plusieurs pages.
class _ModelPickerSheet extends StatelessWidget {
  final DeepSeekModel currentModel;
  final bool isDark;
  final ValueChanged<DeepSeekModel> onSelected;

  const _ModelPickerSheet({
    required this.currentModel,
    required this.isDark,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Modèle d\'IA',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choisissez le modèle pour la génération',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          _modelTile(
            context,
            model: DeepSeekModel.flash,
            icon: Icons.bolt_rounded,
            iconColor: const Color(0xFF3498DB),
            bgColor: const Color(0xFF3498DB).withValues(alpha: 0.1),
          ),
          const SizedBox(height: 10),
          _modelTile(
            context,
            model: DeepSeekModel.pro,
            icon: Icons.auto_awesome,
            iconColor: const Color(0xFF6C3FE8),
            bgColor: const Color(0xFF6C3FE8).withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }

  Widget _modelTile(
    BuildContext context, {
    required DeepSeekModel model,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    final selected = currentModel == model;
    return GestureDetector(
      onTap: () {
        onSelected(model);
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? bgColor
              : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? iconColor.withValues(alpha: 0.6)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ngenou ${model.label}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    model.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: iconColor, size: 22),
          ],
        ),
      ),
    );
  }
}
