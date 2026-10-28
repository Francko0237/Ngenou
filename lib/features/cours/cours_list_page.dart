import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/notion.dart';
import '../../core/models/lecon.dart';
import '../../core/models/progression.dart';
import '../../core/providers/progression_provider.dart';
import '../../core/services/pdf_export_service.dart';
import '../../core/services/tutorial_service.dart';
import '../../core/utils/course_context_mapper.dart';
import '../../core/utils/error_formatter.dart';
import '../../core/widgets/extension_download_dialog.dart';
import '../../core/widgets/tutorial_overlay.dart';
import '../../modules/modules_registry.dart';

class CoursListPage extends StatefulWidget {
  final String matiereId;

  const CoursListPage({super.key, required this.matiereId});

  @override
  State<CoursListPage> createState() => _CoursListPageState();
}

class _CoursListPageState extends State<CoursListPage> {
  final GlobalKey _keyFirstChapter = GlobalKey();
  final GlobalKey _keySharePdf = GlobalKey();
  final GlobalKey _keyPdfExport = GlobalKey();
  final GlobalKey _keyTerminalFab = GlobalKey();
  final GlobalKey _keyTutorialBtn = GlobalKey();

  bool _showTutorial = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final should = await TutorialService.shouldShow('course_chapters');
      if (should && mounted) {
        setState(() => _showTutorial = true);
      }
    });
  }

  void _startTutorial() {
    TutorialService.reset('course_chapters').then((_) {
      if (mounted) setState(() => _showTutorial = true);
    });
  }

  List<TutorialStep> _buildTutorialSteps(bool hasTerminal) {
    return [
      TutorialStep(
        targetKey: _keyFirstChapter,
        category: 'PARCOURS DU COURS',
        icon: Icons.auto_stories_rounded,
        title: 'Vos chapitres pas à pas',
        description:
            'Chaque notion est découpée en chapitres progressifs. Terminez chaque leçon pour débloquer la suite de votre parcours en toute sérénité.',
        highlights: ['Progression guidée', 'Déblocage pas à pas'],
        spotShape: SpotShape.roundedRect,
        spotRadius: 16,
        padding: const EdgeInsets.all(4),
      ),
      TutorialStep(
        targetKey: _keySharePdf,
        targetKey2: _keyPdfExport,
        category: 'SUPPORTS DE RÉVISION',
        icon: Icons.picture_as_pdf_rounded,
        title: 'Partage & Téléchargement PDF',
        description:
            'Partagez ou téléchargez tout le cours sous forme de PDF soigné pour réviser hors-ligne, sur papier ou sur votre tablette.',
        highlights: ['Partager & Télécharger', 'Disponible hors-ligne'],
        spotShape: SpotShape.roundedRect,
        spotRadius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      if (hasTerminal)
        TutorialStep(
          targetKey: _keyTerminalFab,
          category: 'PRATIQUE & CODE',
          icon: Icons.code_rounded,
          title: 'Terminal interactif',
          description:
              'Lancez le terminal algorithmique pour tester et exécuter vos algorithmes directement dans l’application.',
          highlights: ['Interpréteur en direct', 'Pratique immédiate'],
          spotShape: SpotShape.roundedRect,
          spotRadius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        ),
      TutorialStep(
        targetKey: _keyTutorialBtn,
        category: 'AIDE RAPIDE',
        icon: Icons.lightbulb_rounded,
        title: 'Besoin d’un rappel ?',
        description:
            'Touchez cette ampoule à tout moment pour revoir les explications et vous orienter dans vos cours.',
        highlights: ['Accessible 24h/24', 'Relecture du guide'],
        spotShape: SpotShape.circle,
        spotRadius: 22,
        padding: const EdgeInsets.all(4),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final matiere = ModulesRegistry.getMatiere(widget.matiereId);
    if (matiere == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erreur')),
        body: const Center(child: Text('Cours introuvable')),
      );
    }
    final notions = ModulesRegistry.getNotions(widget.matiereId);
    final progProvider = context.watch<ProgressionProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasTerminal = ModulesRegistry.hasTerminal(widget.matiereId);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF121212)
              : const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: Text(
              matiere.nom,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            leading: context.canPop()
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go('/'),
                  ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            actions: [
              // Bouton ampoule réutilisable pour revoir le tutoriel
              TutorialLightbulbButton(
                buttonKey: _keyTutorialBtn,
                tooltip: 'Guide du cours',
                onTap: _startTutorial,
              ),
              // Bouton de partage (partager le cours en PDF)
              IconButton(
                key: _keySharePdf,
                icon: const Icon(Icons.share_rounded, size: 20),
                tooltip: 'Partager le cours',
                onPressed: () =>
                    _exportCourseToPdf(context, widget.matiereId, share: true),
              ),
              // Bouton de téléchargement du PDF
              IconButton(
                key: _keyPdfExport,
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                tooltip: 'Télécharger le PDF',
                onPressed: () =>
                    _exportCourseToPdf(context, widget.matiereId, share: false),
              ),
              const SizedBox(width: 4),
            ],
          ),
          floatingActionButton: hasTerminal
              ? FloatingActionButton.extended(
                  key: _keyTerminalFab,
                  onPressed: () async {
                    final ready = await promptExtensionDownload(
                      context,
                      'algo_interpreter',
                      featureName: 'Terminal Algorithmique',
                    );
                    if (ready && context.mounted) {
                      context.push('/terminal');
                    }
                  },
                  icon: const Icon(Icons.code_rounded),
                  label: const Text(
                    'Terminal',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 4,
                )
              : null,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final hPad = w > 1200
                  ? w * 0.12
                  : w > 800
                  ? w * 0.07
                  : 20.0;

              return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 14),
                physics: const BouncingScrollPhysics(),
                itemCount: notions.length,
                itemBuilder: (context, index) {
                  final notion = notions[index];
                  final isFirst = index == 0;

                  // Affichage du header de section si la section change
                  Widget? sectionHeader;
                  if (notion.section != null) {
                    bool isFirstOfSection =
                        index == 0 || notions[index - 1].section != notion.section;
                    if (isFirstOfSection) {
                      sectionHeader = Padding(
                        padding: const EdgeInsets.only(
                          top: 16,
                          bottom: 8,
                          left: 2,
                        ),
                        child: Text(
                          notion.section!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).primaryColor,
                            letterSpacing: 0.9,
                          ),
                        ),
                      );
                    }
                  }

                  Progression? prog;
                  try {
                    final progs = progProvider.getProgressions(widget.matiereId);
                    if (progs.isNotEmpty) {
                      prog = progs.firstWhere((p) => p.notionId == notion.id);
                    }
                  } catch (_) {}

                  String niveauLabel = notion.niveau == NiveauNotion.debutant
                      ? 'Débutant'
                      : (notion.niveau == NiveauNotion.intermediaire
                            ? 'Intermédiaire'
                            : 'Avancé');
                  Color niveauColor = notion.niveau == NiveauNotion.debutant
                      ? Colors.green
                      : (notion.niveau == NiveauNotion.intermediaire
                            ? Colors.orange
                            : Colors.redAccent);

                  IconData statusIcon = Icons.lock_outline;
                  Color statusBoxColor = isDark
                      ? Colors.grey[800]!
                      : Colors.grey[300]!;
                  bool isUnlocked = false;

                  if (prog?.statut == 'termine') {
                    statusIcon = Icons.star_rounded;
                    statusBoxColor = Colors.amber.withValues(alpha: 0.2);
                    isUnlocked = true;
                  } else if (prog?.statut == 'en_cours') {
                    statusIcon = Icons.play_arrow_rounded;
                    statusBoxColor = Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.2);
                    isUnlocked = true;
                  } else if (index == 0 ||
                      _isPreviousTermine(
                        notions,
                        index,
                        progProvider.getProgressions(widget.matiereId),
                      )) {
                    statusIcon = Icons.play_arrow_rounded;
                    statusBoxColor = Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1);
                    isUnlocked = true;
                  }

                  final isTermine = prog?.statut == 'termine';
                  final isEnCours = prog?.statut == 'en_cours';

                  int pct = 0;
                  if (prog != null && prog.nbExercicesTotal > 0) {
                    final exList = ModulesRegistry.getExercicesByNotion(
                      widget.matiereId,
                      notion.id,
                    );
                    final totalEx = exList.isNotEmpty ? exList.length.toDouble() : 1.0;
                    pct = ((prog.nbExercicesReussis / totalEx).clamp(0, 1) * 100).toInt();
                  } else if (isTermine) {
                    pct = 100;
                  } else if (isEnCours) {
                    pct = 50;
                  }

                  final card = Opacity(
                    opacity: isUnlocked ? 1.0 : 0.6,
                    child: Container(
                      key: isFirst ? _keyFirstChapter : null,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E26) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isEnCours
                              ? Theme.of(context).primaryColor.withValues(alpha: 0.85)
                              : (isTermine
                                  ? const Color(0xFF2ECC71).withValues(alpha: 0.45)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.black.withValues(alpha: 0.05))),
                          width: isEnCours ? 1.6 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isEnCours
                                ? Theme.of(context)
                                    .primaryColor
                                    .withValues(alpha: isDark ? 0.22 : 0.12)
                                : Colors.black.withValues(
                                    alpha: isDark ? 0.25 : 0.04,
                                  ),
                            blurRadius: isEnCours ? 12 : 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            if (isUnlocked) {
                              await context.push('/cours/${widget.matiereId}/${notion.id}');
                              // Rafraîchir immédiatement le statut au retour
                              if (context.mounted) {
                                context
                                    .read<ProgressionProvider>()
                                    .loadProgression(widget.matiereId);
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Terminez la leçon précédente d'abord.",
                                  ),
                                ),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: notion.contexte != null
                                        ? CourseContextMapper.getColorForContext(
                                            notion.contexte,
                                          ).withValues(
                                            alpha: isUnlocked ? 0.13 : 0.07,
                                          )
                                        : statusBoxColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: notion.contexte != null && isUnlocked
                                        ? Border.all(
                                            color:
                                                CourseContextMapper.getColorForContext(
                                                  notion.contexte,
                                                ).withValues(alpha: 0.25),
                                            width: 1,
                                          )
                                        : null,
                                  ),
                                  child: Icon(
                                    statusIcon,
                                    color: notion.contexte != null
                                        ? CourseContextMapper.getColorForContext(
                                            notion.contexte,
                                          )
                                        : (isUnlocked
                                            ? Theme.of(context).primaryColor
                                            : Colors.grey),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        notion.titre,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14.5,
                                          color: isUnlocked
                                              ? (isDark
                                                  ? Colors.white
                                                  : Colors.black87)
                                              : (isDark
                                                  ? Colors.white38
                                                  : Colors.black38),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        notion.description,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black45,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: niveauColor.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius: BorderRadius.circular(
                                                6,
                                              ),
                                            ),
                                            child: Text(
                                              niveauLabel,
                                              style: TextStyle(
                                                color: niveauColor,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          if (isTermine) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF2ECC71)
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.check_circle_rounded,
                                                    size: 11,
                                                    color: Color(0xFF2ECC71),
                                                  ),
                                                  SizedBox(width: 3),
                                                  Text(
                                                    'Terminé',
                                                    style: TextStyle(
                                                      color: Color(0xFF2ECC71),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ] else if (isEnCours) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .primaryColor
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.play_circle_filled_rounded,
                                                    size: 11,
                                                    color: Theme.of(context)
                                                        .primaryColor,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    'En cours',
                                                    style: TextStyle(
                                                      color: Theme.of(context)
                                                          .primaryColor,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          const Spacer(),
                                          if (isUnlocked && (isTermine || isEnCours || pct > 0))
                                            Row(
                                              children: [
                                                SizedBox(
                                                  width: 13,
                                                  height: 13,
                                                  child: CircularProgressIndicator(
                                                    value: pct / 100,
                                                    strokeWidth: 2,
                                                    backgroundColor: isDark
                                                        ? Colors.white
                                                            .withValues(alpha: 0.1)
                                                        : Colors.black
                                                            .withValues(alpha: 0.08),
                                                    color: isTermine
                                                        ? const Color(0xFF2ECC71)
                                                        : Theme.of(
                                                            context,
                                                          ).primaryColor,
                                                  ),
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  '$pct%',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isTermine
                                                        ? const Color(0xFF2ECC71)
                                                        : Theme.of(
                                                            context,
                                                          ).primaryColor,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            )
                                          else if (!isUnlocked)
                                            Icon(
                                              Icons.lock_outline_rounded,
                                              size: 14,
                                              color: isDark
                                                  ? Colors.white30
                                                  : Colors.black26,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: isUnlocked
                                      ? Theme.of(context).primaryColor
                                      : (isDark
                                            ? Colors.white24
                                            : Colors.black.withValues(alpha: 0.24)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );

                  if (sectionHeader != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [sectionHeader, card],
                    );
                  }
                  return card;
                },
              );
            },
          ),
        ),
        if (_showTutorial)
          TutorialOverlay(
            tutorialId: 'course_chapters',
            steps: _buildTutorialSteps(hasTerminal),
            onDone: () => setState(() => _showTutorial = false),
          ),
      ],
    );
  }

  bool _isPreviousTermine(
    List<Notion> notions,
    int currentIndex,
    List<Progression> progs,
  ) {
    if (currentIndex == 0) return true;
    final prevId = notions[currentIndex - 1].id;
    try {
      if (progs.isEmpty) return false;
      final p = progs.firstWhere((element) => element.notionId == prevId);
      return p.statut == 'termine';
    } catch (_) {
      return false;
    }
  }

  Future<void> _exportCourseToPdf(
    BuildContext context,
    String matiereId, {
    required bool share,
  }) async {
    final matiere = ModulesRegistry.getMatiere(matiereId);
    if (matiere == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cours introuvable')));
      }
      return;
    }
    final notions = ModulesRegistry.getNotions(matiereId);

    // Récupérer toutes les leçons pour ces notions
    final List<Lecon> lecons = [];
    for (final notion in notions) {
      lecons.addAll(ModulesRegistry.getLeconsByNotion(matiereId, notion.id));
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final savedPath = await PdfExportService.exportCourseToPdf(
        matiere: matiere,
        notions: notions,
        lecons: lecons,
        share: share,
      );
      if (context.mounted) {
        Navigator.pop(context);

        String message = share
            ? 'Partage lancé avec succès !'
            : 'PDF enregistré avec succès !';
        if (!share && savedPath != null) {
          final name = savedPath.split('/').last;
          message = 'Téléchargé : $name';
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(formatUserError(e))));
      }
    }
  }
}
