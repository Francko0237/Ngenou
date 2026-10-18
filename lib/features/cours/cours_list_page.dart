import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/notion.dart';
import '../../core/models/lecon.dart';
import '../../core/models/progression.dart';
import '../../core/providers/progression_provider.dart';
import '../../core/services/pdf_export_service.dart';
import '../../core/utils/course_context_mapper.dart';
import '../../core/utils/error_formatter.dart';
import '../../core/widgets/extension_download_dialog.dart';
import '../../modules/modules_registry.dart';

class CoursListPage extends StatelessWidget {
  final String matiereId;

  const CoursListPage({super.key, required this.matiereId});

  @override
  Widget build(BuildContext context) {
    final matiere = ModulesRegistry.getMatiere(matiereId);
    if (matiere == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erreur')),
        body: const Center(child: Text('Cours introuvable')),
      );
    }
    final notions = ModulesRegistry.getNotions(matiereId);
    final progProvider = context.watch<ProgressionProvider>();
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
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
          // Bouton de partage (partager le cours en PDF)
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Partager le cours',
            onPressed: () =>
                _exportCourseToPdf(context, matiereId, share: true),
          ),
          // Bouton de téléchargement du PDF
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Télécharger le PDF',
            onPressed: () =>
                _exportCourseToPdf(context, matiereId, share: false),
          ),
        ],
      ),
      floatingActionButton: ModulesRegistry.hasTerminal(matiereId)
          ? FloatingActionButton.extended(
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
              icon: const Icon(Icons.code),
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
                final progs = progProvider.getProgressions(matiereId);
                if (progs.isNotEmpty) {
                  prog = progs.firstWhere((p) => p.notionId == notion.id);
                }
              } catch (e) {}

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
              Color statusIconColor = Colors.grey;
              bool isUnlocked = false;

              if (prog?.statut == 'termine') {
                statusIcon = Icons.star_rounded;
                statusBoxColor = Colors.amber.withValues(alpha: 0.2);
                statusIconColor = Colors.amber;
                isUnlocked = true;
              } else if (prog?.statut == 'en_cours') {
                statusIcon = Icons.play_arrow_rounded;
                statusBoxColor = Theme.of(
                  context,
                ).primaryColor.withValues(alpha: 0.2);
                statusIconColor = Theme.of(context).primaryColor;
                isUnlocked = true;
              } else if (index == 0 ||
                  _isPreviousTermine(
                    notions,
                    index,
                    progProvider.getProgressions(matiereId),
                  )) {
                statusIcon = Icons.play_arrow_rounded;
                statusBoxColor = Theme.of(
                  context,
                ).primaryColor.withValues(alpha: 0.1);
                statusIconColor = Theme.of(context).primaryColor;
                isUnlocked = true;
              }

              int pct = prog != null && prog.nbExercicesTotal > 0
                  ? ((prog.nbExercicesReussis /
                                    ModulesRegistry.getExercicesByNotion(
                                      matiereId,
                                      notion.id,
                                    ).length.toDouble())
                                .clamp(0, 1) *
                            100)
                        .toInt()
                  : 0;

              final card = Opacity(
                opacity: isUnlocked ? 1.0 : 0.6,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E26) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.05),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.25 : 0.04,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        if (isUnlocked) {
                          context.push('/cours/$matiereId/${notion.id}');
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
                                notion.contexte != null
                                    ? CourseContextMapper.getIconForContext(
                                        notion.contexte,
                                      )
                                    : statusIcon,
                                color: notion.contexte != null
                                    ? CourseContextMapper.getColorForContext(
                                        notion.contexte,
                                      )
                                    : statusIconColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notion.titre,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF15151C),
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
                                      const Spacer(),
                                      if (isUnlocked && pct > 0)
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
                                                color: pct == 100
                                                    ? Colors.amber
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
                                                color: pct == 100
                                                    ? Colors.amber
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
    } catch (e) {
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
