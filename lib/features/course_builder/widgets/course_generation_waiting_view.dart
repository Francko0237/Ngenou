import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/models/deep_seek_model.dart';

/// Écran d'attente interactif, dynamique et animé pendant la génération d'un cours par l'IA.
/// Comprend une variation cyclique de 12 illustrations SVG avec messages contextuels,
/// un compteur de temps écoulé, un carrousel d'astuces pédagogiques et un bouton d'annulation.
class CourseGenerationWaitingView extends StatefulWidget {
  final bool isDark;
  final Color primary;
  final DeepSeekModel model;
  final String courseName;
  final VoidCallback onCancel;

  const CourseGenerationWaitingView({
    super.key,
    required this.isDark,
    required this.primary,
    required this.model,
    required this.courseName,
    required this.onCancel,
  });

  @override
  State<CourseGenerationWaitingView> createState() =>
      _CourseGenerationWaitingViewState();
}

class _StageInfo {
  final String svgAsset;
  final String title;
  final String subtitle;
  final Color accentColor;

  const _StageInfo({
    required this.svgAsset,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });
}

class _CourseGenerationWaitingViewState
    extends State<CourseGenerationWaitingView> with TickerProviderStateMixin {
  late final AnimationController _spinController;
  late final AnimationController _pulseController;
  Timer? _stageTimer;
  Timer? _elapsedTimer;
  int _currentStageIndex = 0;
  int _elapsedSeconds = 0;
  int _tipIndex = 0;

  static const List<_StageInfo> _stages = [
    _StageInfo(
      svgAsset: 'assets/icons/outline/bulb.svg',
      title: 'Exploration des concepts',
      subtitle:
          "Analyse du sujet, cadrage didactique et identification des fondamentaux à maîtriser...",
      accentColor: Color(0xFFF59E0B), // Ambre éclatant
    ),
    _StageInfo(
      svgAsset: 'assets/icons/outline/book.svg',
      title: 'Architecture pédagogique',
      subtitle:
          "Structuration méthodique des chapitres et découpage en modules progressifs...",
      accentColor: Color(0xFF3B82F6), // Bleu royal
    ),
    _StageInfo(
      svgAsset: 'assets/icons/outline/brain.svg',
      title: 'Adaptation cognitive',
      subtitle:
          "Calibrage précis du niveau de difficulté et du vocabulaire selon la classe cible...",
      accentColor: Color(0xFF8B5CF6), // Violet profond
    ),
    _StageInfo(
      svgAsset: 'assets/icons/outline/notes.svg',
      title: 'Rédaction des leçons',
      subtitle:
          "Formulation d'explications claires, de définitions rigoureuses et de synthèses digestes...",
      accentColor: Color(0xFF10B981), // Émeraude
    ),
    _StageInfo(
      svgAsset: 'assets/icons/outline/checklist.svg',
      title: 'Formulation des notions clés',
      subtitle:
          "Mise en relief ciblée des formules, règles essentielles et fiches mémo indispensables...",
      accentColor: Color(0xFF06B6D4), // Cyan
    ),
    _StageInfo(
      svgAsset: 'assets/icons/outline/puzzle.svg',
      title: 'Conception des exercices',
      subtitle:
          "Élaboration de QCM interactifs, d'exercices d'application et de défis stimulants...",
      accentColor: Color(0xFFEC4899), // Rose vif
    ),
    _StageInfo(
      svgAsset: 'assets/icons/outline/flask.svg',
      title: 'Cas pratiques & exemples',
      subtitle:
          "Enrichissement par des scénarios concrets reliant la théorie au monde réel...",
      accentColor: Color(0xFF14B8A6), // Turquoise
    ),
    _StageInfo(
      svgAsset: 'assets/icons/outline/code.svg',
      title: 'Enrichissement interactif',
      subtitle:
          "Intégration d'exemples pas-à-pas et d'outils interactifs d'apprentissage...",
      accentColor: Color(0xFF6366F1), // Indigo
    ),
    _StageInfo(
      svgAsset: 'assets/icons/outline/target.svg',
      title: 'Alignement des objectifs',
      subtitle:
          "Vérification de la parfaite adéquation avec le programme et les objectifs fixés...",
      accentColor: Color(0xFFF97316), // Orange vibrant
    ),
    _StageInfo(
      svgAsset: 'assets/icons/outline/school.svg',
      title: 'Relecture didactique',
      subtitle:
          "Harmonisation de la rigueur académique, de l'accessibilité et de la fluidité...",
      accentColor: Color(0xFF0284C7), // Bleu ciel profond
    ),
    _StageInfo(
      svgAsset: 'assets/icons/outline/star.svg',
      title: "Finitions d'excellence",
      subtitle:
          "Optimisation de l'ergonomie, des indices progressifs et des métadonnées du cours...",
      accentColor: Color(0xFFEAB308), // Or doré
    ),
    _StageInfo(
      svgAsset: 'assets/icons/outline/rocket.svg',
      title: 'Assemblage & finalisation',
      subtitle:
          "Compilation du package de cours complet, prêt pour une étude immédiate !",
      accentColor: Color(0xFFEF4444), // Corail éclatant
    ),
  ];

  static const List<String> _tips = [
    "💡 L'IA structure chaque cours en leçons courtes pour optimiser la mémorisation active.",
    "🧩 Les exercices intègrent des indices progressifs pour guider sans donner la solution brute.",
    "📱 Vos cours générés sont sauvegardés localement et restent consultables 100% hors-ligne.",
    "✏️ Vous pourrez modifier chaque texte, notion et exercice dans le Studio après la génération.",
    "🎯 L'algorithme adapte le niveau d'exigence et le ton en fonction de la classe sélectionnée.",
    "🚀 Vous pouvez générer autant de cours que souhaité pour explorer de nouveaux sujets.",
  ];

  @override
  void initState() {
    super.initState();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _stageTimer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      if (mounted) {
        setState(() {
          _currentStageIndex = (_currentStageIndex + 1) % _stages.length;
        });
      }
    });

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
          if (_elapsedSeconds % 7 == 0) {
            _tipIndex = (_tipIndex + 1) % _tips.length;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _spinController.dispose();
    _pulseController.dispose();
    _stageTimer?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  String _formatElapsed(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _previousStage() {
    setState(() {
      _currentStageIndex =
          (_currentStageIndex - 1 + _stages.length) % _stages.length;
    });
  }

  void _nextStage() {
    setState(() {
      _currentStageIndex = (_currentStageIndex + 1) % _stages.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stage = _stages[_currentStageIndex];
    final isPro = widget.model == DeepSeekModel.pro;
    final textMain = widget.isDark ? Colors.white : const Color(0xFF1E293B);
    final textMuted =
        widget.isDark ? Colors.grey[400] : const Color(0xFF64748B);
    final cardBg = widget.isDark ? const Color(0xFF1E1E26) : Colors.white;
    final borderColor =
        widget.isDark ? const Color(0xFF2C2C38) : const Color(0xFFE2E8F0);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ─── En-tête : Modèle, chrono et bouton annuler rapide ──────────
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Bouton d'annulation en haut à gauche
                          Tooltip(
                            message: 'Annuler la génération',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: widget.onCancel,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: widget.isDark
                                        ? Colors.white.withValues(alpha: 0.07)
                                        : Colors.black.withValues(alpha: 0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: widget.isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Badge du modèle IA utilisé
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isPro
                                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                                  : widget.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isPro
                                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.35)
                                    : widget.primary.withValues(alpha: 0.28),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPro
                                      ? Icons.diamond_rounded
                                      : Icons.bolt_rounded,
                                  size: 14,
                                  color: isPro
                                      ? const Color(0xFF8B5CF6)
                                      : widget.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isPro ? 'DeepSeek Pro' : 'DeepSeek Flash',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isPro
                                        ? const Color(0xFF8B5CF6)
                                        : widget.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Chronomètre écoulé
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: widget.isDark
                                  ? Colors.white.withValues(alpha: 0.07)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 13,
                                  color: widget.isDark
                                      ? Colors.white60
                                      : Colors.black54,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _formatElapsed(_elapsedSeconds),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                    color: widget.isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Nom du cours en cours de création
                      if (widget.courseName.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_stories_rounded,
                                size: 15,
                                color: widget.primary,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  widget.courseName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: textMain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ─── Centre : Animation SVG dynamique & interactive ──────────
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Zone d'illustration centrale avec anneau rotatif et halo pulsé
                      GestureDetector(
                        onHorizontalDragEnd: (details) {
                          if (details.primaryVelocity != null) {
                            if (details.primaryVelocity! < 0) {
                              _nextStage();
                            } else if (details.primaryVelocity! > 0) {
                              _previousStage();
                            }
                          }
                        },
                        onTap: _nextStage,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Halo rotatif externe
                            RotationTransition(
                              turns: _spinController,
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: SweepGradient(
                                    colors: [
                                      stage.accentColor.withValues(alpha: 0.05),
                                      stage.accentColor.withValues(alpha: 0.75),
                                      stage.accentColor.withValues(alpha: 0.05),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Carte intérieure avec respiration d'échelle et ombre portée lumineuse
                            ScaleTransition(
                              scale: Tween<double>(begin: 0.94, end: 1.05).animate(
                                CurvedAnimation(
                                  parent: _pulseController,
                                  curve: Curves.easeInOut,
                                ),
                              ),
                              child: Container(
                                width: 114,
                                height: 114,
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: stage.accentColor.withValues(alpha: 0.5),
                                    width: 2.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: stage.accentColor.withValues(
                                        alpha: widget.isDark ? 0.35 : 0.22,
                                      ),
                                      blurRadius: 28,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 400),
                                    transitionBuilder: (child, anim) {
                                      return FadeTransition(
                                        opacity: anim,
                                        child: ScaleTransition(
                                          scale: anim,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: SvgPicture.asset(
                                      stage.svgAsset,
                                      key: ValueKey<String>(stage.svgAsset),
                                      width: 48,
                                      height: 48,
                                      colorFilter: ColorFilter.mode(
                                        stage.accentColor,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Étape courante (ex : Étape 4 sur 12)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: stage.accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Étape ${_currentStageIndex + 1} / ${_stages.length}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: stage.accentColor,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Titre animé de l'étape
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        child: Text(
                          stage.title,
                          key: ValueKey<String>(stage.title),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: textMain,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Sous-titre / description didactique
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: Text(
                            stage.subtitle,
                            key: ValueKey<String>(stage.subtitle),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.4,
                              color: textMuted,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Indicateurs à bulles interactifs (12 points)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_stages.length, (idx) {
                          final isActive = idx == _currentStageIndex;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _currentStageIndex = idx);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 2.5),
                              width: isActive ? 22 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? stage.accentColor
                                    : (widget.isDark
                                        ? Colors.white24
                                        : Colors.black12),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ─── Pied de page : Astuce interactive + Bouton Annuler ─────────
                  Column(
                    children: [
                      // Carte interactive "Le saviez-vous ?"
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _tipIndex = (_tipIndex + 1) % _tips.length;
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor, width: 0.8),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(
                                    alpha: 0.12,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.lightbulb_outline_rounded,
                                  size: 16,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Text(
                                    _tips[_tipIndex],
                                    key: ValueKey<int>(_tipIndex),
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.35,
                                      color: textMuted,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.touch_app_outlined,
                                size: 14,
                                color: textMuted?.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Bouton Annuler la génération
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: widget.onCancel,
                          icon: const Icon(
                            Icons.stop_circle_outlined,
                            size: 19,
                            color: Colors.redAccent,
                          ),
                          label: const Text(
                            'Annuler la génération',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.redAccent.withValues(alpha: 0.45),
                              width: 1.2,
                            ),
                            backgroundColor:
                                Colors.redAccent.withValues(alpha: 0.08),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
