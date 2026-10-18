import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../../core/models/score.dart';
import '../../core/providers/progression_provider.dart';
import '../../core/services/resultat_cache.dart';
import '../../modules/modules_registry.dart';

class ResultatPage extends StatefulWidget {
  final Score score;

  const ResultatPage({super.key, required this.score});

  @override
  State<ResultatPage> createState() => _ResultatPageState();
}

class _ResultatPageState extends State<ResultatPage> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    ResultatCache.lastScore = widget.score;
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    if (widget.score.pourcentage >= 80) {
      _confettiController.play();
    }

    // Actualiser immédiatement toutes les progressions locales sans attendre la sync distante
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProgressionProvider>().loadAllProgressions();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String mention;
    final Color mentionColor;
    if (widget.score.pourcentage >= 80) {
      mention = "Excellent !";
      mentionColor = Colors.green;
    } else if (widget.score.pourcentage >= 50) {
      mention = "Bien joué !";
      mentionColor = Colors.orange;
    } else {
      mention = "À revoir";
      mentionColor = Colors.red;
    }

    // Recherche de la leçon / notion suivante dans la matière
    final notions = ModulesRegistry.getNotions(widget.score.matiereId);
    final currentIndex = notions.indexWhere((n) => n.id == widget.score.notionId);
    final nextNotion = (currentIndex != -1 && currentIndex + 1 < notions.length)
        ? notions[currentIndex + 1]
        : null;

    final primary = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Résultats'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour au cours',
          onPressed: () => context.go('/cours/${widget.score.matiereId}'),
        ),
      ),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      mention,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: mentionColor,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: widget.score.pourcentage / 100),
                      duration: const Duration(seconds: 1),
                      builder: (context, value, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 150,
                              height: 150,
                              child: CircularProgressIndicator(
                                value: value,
                                strokeWidth: 12,
                                backgroundColor: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.08),
                                color: mentionColor,
                              ),
                            ),
                            Text(
                              "${widget.score.score}/${widget.score.total}",
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 40),

                    // ─── 1. Leçon suivante (si disponible) ──────────────────────
                    if (nextNotion != null) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: () => context.go('/cours/${widget.score.matiereId}/${nextNotion.id}'),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                          label: Text(
                            'Leçon suivante : ${nextNotion.titre}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ─── 2. Retour à la page du cours ──────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: () => context.go('/cours/${widget.score.matiereId}'),
                        icon: const Icon(Icons.menu_book_rounded, size: 20),
                        label: const Text(
                          'Retour à la liste des leçons',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ─── 3. Liens secondaires : Recommencer & Accueil ──────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () => context.pushReplacement(
                            '/exercice/${widget.score.matiereId}/${widget.score.notionId}/0',
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Recommencer'),
                        ),
                        const SizedBox(width: 20),
                        TextButton.icon(
                          onPressed: () => context.go('/'),
                          icon: const Icon(Icons.dashboard_rounded, size: 18),
                          label: const Text('Tableau de bord'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
