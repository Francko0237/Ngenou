import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/progression_provider.dart';

const String _kPrefDismissed = 'ngenou_first_steps_dismissed_v1';
const String _kPrefChatTested = 'ngenou_first_step_chat_tested_v1';
const String _kPrefProgViewed = 'ngenou_first_step_prog_viewed_v1';

class FirstStepsChecklistCard extends StatefulWidget {
  final VoidCallback? onExploreCourses;

  const FirstStepsChecklistCard({
    super.key,
    this.onExploreCourses,
  });

  /// Méthode statique pour marquer une étape comme faite depuis n'importe où
  static Future<void> markStepDone(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
  }

  static const String keyChat = _kPrefChatTested;
  static const String keyProg = _kPrefProgViewed;

  @override
  State<FirstStepsChecklistCard> createState() => _FirstStepsChecklistCardState();
}

class _FirstStepsChecklistCardState extends State<FirstStepsChecklistCard> {
  bool _isDismissed = false;
  bool _chatTested = false;
  bool _progViewed = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isDismissed = prefs.getBool(_kPrefDismissed) ?? false;
        _chatTested = prefs.getBool(_kPrefChatTested) ?? false;
        _progViewed = prefs.getBool(_kPrefProgViewed) ?? false;
        _loaded = true;
      });
    }
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefDismissed, true);
    if (mounted) {
      setState(() => _isDismissed = true);
    }
  }

  Future<void> _markChatTested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefChatTested, true);
    if (mounted) {
      setState(() => _chatTested = true);
    }
  }

  Future<void> _markProgViewed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefProgViewed, true);
    if (mounted) {
      setState(() => _progViewed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _isDismissed) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    // Détection automatique du 1er cours : si une notion est en_cours ou terminée
    final progProvider = context.watch<ProgressionProvider>();
    bool courseOpened = progProvider.progressionGlobale > 0;
    if (!courseOpened) {
      for (final pList in [progProvider.progressionsByMatiere]) {
        if (pList.any((p) => p.statut == 'en_cours' || p.statut == 'termine')) {
          courseOpened = true;
          break;
        }
      }
    }

    final int completedCount = (courseOpened ? 1 : 0) +
        (_chatTested ? 1 : 0) +
        (_progViewed ? 1 : 0);
    final double progressRatio = completedCount / 3.0;
    final bool allDone = completedCount == 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1B26) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: allDone
              ? const Color(0xFF2ECC71).withValues(alpha: 0.5)
              : primary.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (allDone ? const Color(0xFF2ECC71) : primary)
                .withValues(alpha: isDark ? 0.15 : 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : Titre + Progression + Bouton fermer
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (allDone ? const Color(0xFF2ECC71) : primary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  allDone ? Icons.celebration_rounded : Icons.rocket_launch_rounded,
                  color: allDone ? const Color(0xFF2ECC71) : primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      allDone
                          ? 'Missions terminées ! 🎉'
                          : 'Vos premiers pas avec Ngenou',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      allDone
                          ? 'Tu es prêt pour réussir ton apprentissage.'
                          : '$completedCount sur 3 étapes complétées',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: allDone
                            ? const Color(0xFF2ECC71)
                            : (isDark ? Colors.white60 : Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: isDark ? Colors.white38 : Colors.black38,
                tooltip: 'Masquer la checklist',
                onPressed: _dismiss,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Barre de progression
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressRatio,
              minHeight: 6,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              color: allDone ? const Color(0xFF2ECC71) : primary,
            ),
          ),
          const SizedBox(height: 14),

          // ── Étape 1 : Découvrir un premier cours ─────────────────────────
          _StepItem(
            isDone: courseOpened,
            icon: Icons.auto_stories_rounded,
            title: '1. Choisir ton 1er cours',
            subtitle: 'Ouvre une matière et lis ta première notion à ton rythme.',
            actionLabel: 'Commencer',
            isDark: isDark,
            primary: primary,
            onAction: () {
              if (widget.onExploreCourses != null) {
                widget.onExploreCourses!();
              }
            },
          ),
          const SizedBox(height: 8),

          // ── Étape 2 : Discuter avec Ngenou IA ────────────────────────────
          _StepItem(
            isDone: _chatTested,
            icon: Icons.chat_bubble_outline_rounded,
            title: '2. Découvrir ton Tuteur Ngenou',
            subtitle: 'Pose une question pour voir comment il t\'aide en temps réel.',
            actionLabel: 'Discuter',
            isDark: isDark,
            primary: primary,
            onAction: () async {
              await _markChatTested();
              if (context.mounted) {
                context.push('/ngenou-chat');
              }
            },
          ),
          const SizedBox(height: 8),

          // ── Étape 3 : Bilan & Progression ────────────────────────────────
          _StepItem(
            isDone: _progViewed,
            icon: Icons.insights_rounded,
            title: '3. Consulter ton Bilan & Progression',
            subtitle: 'Visualise tes statistiques, tes badges et ton planning.',
            actionLabel: 'Voir le bilan',
            isDark: isDark,
            primary: primary,
            onAction: () async {
              await _markProgViewed();
              if (context.mounted) {
                context.push('/progression');
              }
            },
          ),

          if (allDone) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _dismiss,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Compris ! Passer au tableau de bord'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final bool isDone;
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final bool isDark;
  final Color primary;
  final VoidCallback onAction;

  const _StepItem({
    required this.isDone,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.isDark,
    required this.primary,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDone
            ? (isDark ? const Color(0xFF14241B) : const Color(0xFFF0FDF4))
            : (isDark ? const Color(0xFF15151F) : const Color(0xFFF9FAFB)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone
              ? const Color(0xFF2ECC71).withValues(alpha: 0.35)
              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          // Statut : check vert ou icône étape
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isDone
                  ? const Color(0xFF2ECC71)
                  : primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDone ? Icons.check_rounded : icon,
              size: 15,
              color: isDone ? Colors.white : primary,
            ),
          ),
          const SizedBox(width: 10),

          // Textes
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone
                        ? (isDark ? Colors.white54 : Colors.black45)
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Bouton d'action
          if (!isDone) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  actionLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
