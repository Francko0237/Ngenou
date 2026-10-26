import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/progression_provider.dart';
import '../../../modules/modules_registry.dart';

const String _kPrefDismissed = 'ngenou_first_steps_dismissed_v1';
const String _kPrefChatTested = 'ngenou_first_steps_chat_visited';
const String _kPrefProgViewed = 'ngenou_first_steps_progression_visited';

// Clés de secours pour compatibilité
const String _kLegacyChatKey = 'ngenou_first_step_chat_tested_v1';
const String _kLegacyProgKey = 'ngenou_first_step_prog_viewed_v1';

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
    if (key == _kPrefChatTested) {
      await prefs.setBool(_kLegacyChatKey, true);
    } else if (key == _kPrefProgViewed) {
      await prefs.setBool(_kLegacyProgKey, true);
    }
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
        _chatTested = (prefs.getBool(_kPrefChatTested) ?? false) ||
            (prefs.getBool(_kLegacyChatKey) ?? false);
        _progViewed = (prefs.getBool(_kPrefProgViewed) ?? false) ||
            (prefs.getBool(_kLegacyProgKey) ?? false);
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
    await prefs.setBool(_kLegacyChatKey, true);
    if (mounted) {
      setState(() => _chatTested = true);
    }
  }

  Future<void> _markProgViewed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefProgViewed, true);
    await prefs.setBool(_kLegacyProgKey, true);
    if (mounted) {
      setState(() => _progViewed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _isDismissed) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    // Détection fiable du 1er cours : parcourt toutes les matières enregistrées
    final progProvider = context.watch<ProgressionProvider>();
    bool courseOpened = progProvider.progressionGlobale > 0;
    if (!courseOpened) {
      for (final matiere in ModulesRegistry.matieres) {
        final pList = progProvider.getProgressions(matiere.id);
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1B26) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: allDone
              ? const Color(0xFF2ECC71).withValues(alpha: 0.45)
              : primary.withValues(alpha: isDark ? 0.25 : 0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (allDone ? const Color(0xFF2ECC71) : primary)
                .withValues(alpha: isDark ? 0.15 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête : Badge + Titre + Bouton fermer ───────────────────────
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (allDone ? const Color(0xFF2ECC71) : primary)
                      .withValues(alpha: isDark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (allDone ? const Color(0xFF2ECC71) : primary)
                        .withValues(alpha: 0.25),
                  ),
                ),
                child: Center(
                  child: Icon(
                    allDone ? Icons.celebration_rounded : Icons.rocket_launch_rounded,
                    color: allDone ? const Color(0xFF2ECC71) : primary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      allDone
                          ? 'Missions accomplies ! 🎉'
                          : 'Vos premiers pas avec Ngenou',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: isDark ? Colors.white : const Color(0xFF14141E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      allDone
                          ? 'Vous avez toutes les clés en main pour réussir.'
                          : '$completedCount sur 3 étapes complétées',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: allDone
                            ? const Color(0xFF2ECC71)
                            : (isDark ? Colors.white60 : Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: 'Masquer la checklist',
                child: InkWell(
                  onTap: _dismiss,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: isDark ? Colors.white60 : Colors.black45,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Barre de progression fluide ──────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressRatio,
              minHeight: 6,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(
                allDone ? const Color(0xFF2ECC71) : primary,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Étape 1 : Choisir un 1er cours ──────────────────────────────
          _StepTile(
            isDone: courseOpened,
            icon: Icons.auto_stories_rounded,
            title: '1. Découvrir votre premier cours',
            subtitle: 'Ouvrez une matière et commencez votre première leçon.',
            actionLabel: 'Explorer',
            isDark: isDark,
            primary: primary,
            onAction: () {
              if (widget.onExploreCourses != null) {
                widget.onExploreCourses!();
              }
            },
          ),
          const SizedBox(height: 8),

          // ── Étape 2 : Essayer Ngenou IA ──────────────────────────────────
          _StepTile(
            isDone: _chatTested,
            icon: Icons.psychology_rounded,
            title: '2. Poser une question à Ngenou IA',
            subtitle: 'Découvrez comment votre assistant répond à vos doutes.',
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

          // ── Étape 3 : Découvrir Bilan & Progression ──────────────────────
          _StepTile(
            isDone: _progViewed,
            icon: Icons.insights_rounded,
            title: '3. Consulter votre Bilan & Progression',
            subtitle: 'Visualisez vos statistiques détaillées et vos badges.',
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
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _dismiss,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text(
                  'Compris ! Passer au tableau de bord',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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

class _StepTile extends StatelessWidget {
  final bool isDone;
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final bool isDark;
  final Color primary;
  final VoidCallback onAction;

  const _StepTile({
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isDone
            ? (isDark ? const Color(0xFF14241B) : const Color(0xFFF0FDF4))
            : (isDark ? const Color(0xFF15151F) : const Color(0xFFF9FAFB)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone
              ? const Color(0xFF2ECC71).withValues(alpha: 0.35)
              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Statut : check vert ou icône étape
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDone
                  ? const Color(0xFF2ECC71)
                  : primary.withValues(alpha: isDark ? 0.16 : 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDone ? Icons.check_rounded : icon,
              size: 16,
              color: isDone ? Colors.white : primary,
            ),
          ),
          const SizedBox(width: 12),

          // Titre et sous-titre
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
                        : (isDark ? Colors.white : const Color(0xFF14141E)),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
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
            const SizedBox(width: 8),
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: isDark ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
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
