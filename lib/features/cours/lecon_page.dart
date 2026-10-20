import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/models/lecon.dart';
import '../../core/models/notion.dart';
import '../../core/providers/custom_courses_provider.dart';
import '../../core/providers/progression_provider.dart';
import '../../core/services/ai_tutor_service.dart';
import '../../core/utils/lesson_content_parser.dart';
import '../../modules/modules_registry.dart';
import '../../core/widgets/extension_download_dialog.dart';
import '../course_builder/course_studio_page.dart';
import 'widgets/ai_tutor_chat_sheet.dart';
import 'widgets/lesson_section_card.dart';

class LeconPage extends StatefulWidget {
  final String matiereId;
  final String notionId;
  final bool openChat;

  const LeconPage({
    super.key,
    required this.matiereId,
    required this.notionId,
    this.openChat = false,
  });

  @override
  State<LeconPage> createState() => _LeconPageState();
}

class _LeconPageState extends State<LeconPage> {
  late List<Lecon> lecons;
  late List<List<LessonSection>> sectionsPerLesson;
  late String? notionContexte;

  int _lessonIndex = 0;
  int _sectionIndex = 0;
  final PageController _sectionController = PageController();

  @override
  void initState() {
    super.initState();
    lecons = ModulesRegistry.getLeconsByNotion(widget.matiereId, widget.notionId);
    final notions = ModulesRegistry.getNotions(widget.matiereId);
    notionContexte = widget.matiereId == 'algo'
        ? 'code'
        : notions
            .where((n) => n.id == widget.notionId)
            .map((n) => n.contexte)
            .firstOrNull;

    sectionsPerLesson = lecons
        .map((l) => LessonContentParser.parse(l.contenu, fallbackTitle: l.titre))
        .toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProgressionProvider>().markNotionInProgress(
          widget.matiereId,
          widget.notionId,
        );
      }
      if (widget.openChat) {
        _openAiTutor();
      }
    });
  }

  @override
  void dispose() {
    _sectionController.dispose();
    super.dispose();
  }

  List<LessonSection> get _currentSections => sectionsPerLesson[_lessonIndex];
  Lecon get _currentLecon => lecons[_lessonIndex];
  bool get _isLastSection => _sectionIndex >= _currentSections.length - 1;
  bool get _isLastLesson => _lessonIndex >= lecons.length - 1;
  bool get _isFirstSection => _sectionIndex == 0;
  bool get _isFirstLesson => _lessonIndex == 0;

  int get _totalConcepts =>
      sectionsPerLesson.fold(0, (sum, s) => sum + s.length);

  int get _currentConceptOffset {
    var offset = 0;
    for (var i = 0; i < _lessonIndex; i++) {
      offset += sectionsPerLesson[i].length;
    }
    return offset + _sectionIndex + 1;
  }

  void _goToSection(int index, {bool animate = true}) {
    final clamped = index.clamp(0, _currentSections.length - 1);
    setState(() => _sectionIndex = clamped);
    if (_sectionController.hasClients) {
      if (animate) {
        _sectionController.animateToPage(
          clamped,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      } else {
        _sectionController.jumpToPage(clamped);
      }
    }
  }

  void _goToLesson(int lessonIndex, {int? sectionIndex}) {
    setState(() {
      _lessonIndex = lessonIndex.clamp(0, lecons.length - 1);
      _sectionIndex = sectionIndex ?? 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sectionController.hasClients) {
        _sectionController.jumpToPage(_sectionIndex);
      }
    });
  }

  void _showExplicationDialog(Lecon lecon, VoidCallback onPass) {
    if (lecon.explicationDetaillee == null) {
      onPass();
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lightbulb_outline, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Besoin d'aller plus loin ?",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          "Un concept te semble un peu flou ? Veux-tu une explication plus concrète avec un exemple de la vie courante ?",
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onPass();
            },
            child: Text(
              "J'ai déjà compris",
              style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _showDetailleeContent(lecon.explicationDetaillee!, onPass);
            },
            child: const Text(
              "Oui, explique-moi !",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailleeContent(String explication, VoidCallback onPass) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: Theme.of(context).primaryColor, size: 32),
                const SizedBox(width: 12),
                const Text(
                  "Explication simplifiée",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  explication,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  onPass();
                },
                child: const Text(
                  "Génial, j'ai compris ! Continuer",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handlePrevious() {
    if (!_isFirstSection) {
      _goToSection(_sectionIndex - 1);
    } else if (!_isFirstLesson) {
      final prevLesson = _lessonIndex - 1;
      final lastSection = sectionsPerLesson[prevLesson].length - 1;
      _goToLesson(prevLesson, sectionIndex: lastSection);
    }
  }

  void _handleNext() {
    Future<void> advance() async {
      if (!_isLastSection) {
        _goToSection(_sectionIndex + 1);
      } else if (!_isLastLesson) {
        _goToLesson(_lessonIndex + 1);
      } else {
        // Fin de toutes les leçons de la notion :
        // Marquer la notion comme complétée (100% sans forcer les exercices)
        if (context.mounted) {
          await context.read<ProgressionProvider>().markNotionCompleted(
            widget.matiereId,
            widget.notionId,
          );
        }
        if (context.mounted) _showNotionCompletionSheet();
      }
    }

    if (_isLastSection) {
      _showExplicationDialog(_currentLecon, () => advance());
    } else {
      advance();
    }
  }

  void _showNotionCompletionSheet() {
    final notions = ModulesRegistry.getNotions(widget.matiereId);
    final currentIndex = notions.indexWhere((n) => n.id == widget.notionId);
    final Notion? nextNotion =
        (currentIndex >= 0 && currentIndex < notions.length - 1)
            ? notions[currentIndex + 1]
            : null;
    final exercices = ModulesRegistry.getExercicesByNotion(widget.matiereId, widget.notionId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: EdgeInsets.fromLTRB(
          28,
          16,
          28,
          MediaQuery.of(context).padding.bottom + 28,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Trophy icon
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade300, Colors.amber.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.35),
                    blurRadius: 20,
                    spreadRadius: 4,
                  )
                ],
              ),
              child: const Icon(Icons.star_rounded, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 18),
            Text(
              'Leçon terminée ! 🎉',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              exercices.isNotEmpty
                  ? 'Tu as parcouru tous les concepts !\nPrêt à tester tes connaissances ?'
                  : (nextNotion != null
                      ? 'Tu as maîtrisé cette notion.\nPrêt pour la suite ?'
                      : 'Tu as terminé toutes les notions\nde ce cours. Bravo !'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            // ── 1. Bouton Exercices (si existants) ──────────────────────
            if (exercices.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.quiz_rounded),
                  label: Text(
                    'S\'entraîner avec les exercices (${exercices.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    context.pushReplacement('/exercice/${widget.matiereId}/${widget.notionId}/0');
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
            // ── 2. Bouton Leçon suivante (si existante) ─────────────────
            if (nextNotion != null) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    'Leçon suivante : ${nextNotion.titre}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    context.pushReplacement('/cours/${widget.matiereId}/${nextNotion.id}');
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
            // ── 3. Bouton Retour au cours ──────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                icon: Icon(
                  Icons.menu_book_rounded,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
                label: Text(
                  'Retour à la liste des leçons',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  context.go('/cours/${widget.matiereId}');
                },
              ),
            ),
            const SizedBox(height: 8),
            // ── 4. Revoir la leçon ────────────────────────────────────
            TextButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Revoir cette leçon depuis le début'),
              onPressed: () {
                Navigator.pop(sheetCtx);
                _goToLesson(0, sectionIndex: 0);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openStudio() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourseStudioPage(
          matiereId: widget.matiereId,
        ),
        fullscreenDialog: true,
      ),
    ).then((_) {
      // Reload lesson list after possible edits
      if (mounted) {
        setState(() {
          lecons = ModulesRegistry.getLeconsByNotion(
              widget.matiereId, widget.notionId);
          sectionsPerLesson = lecons
              .map((l) => LessonContentParser.parse(l.contenu,
                  fallbackTitle: l.titre))
              .toList();
        });
      }
    });
  }

  void _openAiTutor() {
    // Récupère le nom de la matière et de la notion pour le contexte
    final matieres = ModulesRegistry.matieres;
    final matiere = matieres.where((m) => m.id == widget.matiereId).firstOrNull;
    final notions = ModulesRegistry.getNotions(widget.matiereId);
    final notion = notions.where((n) => n.id == widget.notionId).firstOrNull;

    final currentSection = _currentSections.isNotEmpty
        ? _currentSections[_sectionIndex]
        : null;

    final lessonCtx = LessonContext(
      matiereNom: matiere?.nom ?? widget.matiereId,
      notionNom: notion?.titre ?? widget.notionId,
      sectionTitre: currentSection?.title ?? _currentLecon.titre,
      sectionContenu: currentSection?.bodyText ?? _currentLecon.contenu,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (_) => AiTutorChatSheet(
        lessonContext: lessonCtx,
        historyKey: '${widget.matiereId}_${widget.notionId}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (lecons.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erreur')),
        body: const Center(child: Text('Aucune leçon trouvée')),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final combinedProgress = (_currentConceptOffset) / _totalConcepts;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour au cours',
          onPressed: () => context.go('/cours/${widget.matiereId}'),
        ),
        title: Row(
          children: [
            // Anneau circulaire moderne avec pourcentage
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    value: combinedProgress.clamp(0.0, 1.0),
                    strokeWidth: 3.5,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                    color: primary,
                  ),
                ),
                Text(
                  '${(combinedProgress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentLecon.titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    lecons.length > 1
                        ? 'Leçon ${_lessonIndex + 1}/${lecons.length} · Concept ${_sectionIndex + 1}/${_currentSections.length}'
                        : 'Concept ${_sectionIndex + 1} sur ${_currentSections.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // ── Studio crayon (cours personnalisé uniquement) ─────────────
          if (context.read<CustomCoursesProvider>().isCustomMatiere(widget.matiereId))
            IconButton(
              icon: const Icon(Icons.edit_note_rounded),
              tooltip: 'Ouvrir dans le Studio',
              onPressed: _openStudio,
            ),
          // ── Bulle tuteur IA ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: _openAiTutor,
              child: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3498DB).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(-1, 2),
                    ),
                    BoxShadow(
                      color: const Color(0xFFF1C40F).withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(1, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/file_00000000a65471f48ca3e95692844cfe.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          if (widget.matiereId == 'algo')
            IconButton(
              icon: const Icon(Icons.code),
              tooltip: 'Ouvrir le terminal',
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
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Barre de progression interactive par étapes ─────────────
          if (_currentSections.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sélecteur de leçons (si la notion contient plusieurs leçons)
                      if (lecons.length > 1) ...[
                        Row(
                          children: [
                            for (var l = 0; l < lecons.length; l++) ...[
                              if (l > 0) const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _goToLesson(l),
                                  borderRadius: BorderRadius.circular(10),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    decoration: BoxDecoration(
                                      color: l == _lessonIndex
                                          ? primary.withValues(alpha: isDark ? 0.25 : 0.12)
                                          : (isDark ? Colors.grey[850] : Colors.grey[100]),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: l == _lessonIndex ? primary : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (l < _lessonIndex) ...[
                                            Icon(Icons.check_circle_rounded, size: 14, color: primary),
                                            const SizedBox(width: 4),
                                          ],
                                          Text(
                                            'Leçon ${l + 1}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: l == _lessonIndex ? FontWeight.bold : FontWeight.w500,
                                              color: l == _lessonIndex
                                                  ? primary
                                                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Capsules interactives des concepts
                      Row(
                        children: [
                          for (var i = 0; i < _currentSections.length; i++) ...[
                            if (i > 0) const SizedBox(width: 6),
                            Expanded(
                              flex: i == _sectionIndex ? 3 : 1,
                              child: InkWell(
                                onTap: () => _goToSection(i),
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: i < _sectionIndex
                                        ? primary.withValues(alpha: isDark ? 0.35 : 0.18)
                                        : (i == _sectionIndex
                                            ? primary
                                            : (isDark ? Colors.grey[800] : Colors.grey[200])),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: i == _sectionIndex
                                        ? [
                                            BoxShadow(
                                              color: primary.withValues(alpha: 0.35),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (i < _sectionIndex)
                                        Icon(
                                          Icons.check_rounded,
                                          size: 14,
                                          color: isDark ? Colors.white : primary,
                                        )
                                      else if (i == _sectionIndex) ...[
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'Concept ${i + 1}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ] else
                                        Text(
                                          '${i + 1}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

          // PageView vertical pour lire les concepts
          Expanded(
            child: PageView.builder(
              key: ValueKey('lesson_$_lessonIndex'),
              controller: _sectionController,
              scrollDirection: Axis.vertical,
              physics: const PageScrollPhysics(),
              onPageChanged: (index) => setState(() => _sectionIndex = index),
              itemCount: _currentSections.length,
              itemBuilder: (context, index) {
                return LessonSectionCard(
                  key: ValueKey('${_lessonIndex}_$index'),
                  section: _currentSections[index],
                  contexte: notionContexte,
                  isActive: index == _sectionIndex,
                );
              },
            ),
          ),
          if (_currentSections.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Center(
                child: Text(
                  'Glisse vers le haut ou le bas pour naviguer',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[600] : Colors.grey[500],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom > 0 ? 8 : 0),
        child: Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 14,
            bottom: 14 + MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!_isFirstSection || !_isFirstLesson)
                TextButton.icon(
                  onPressed: _handlePrevious,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Précédent'),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                )
              else
                const SizedBox.shrink(),
              ElevatedButton.icon(
                onPressed: _handleNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                label: Text(
                  !_isLastSection
                      ? 'Concept suivant'
                      : (_isLastLesson ? 'Terminer la leçon 🎉' : 'Leçon suivante'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                icon: Icon(
                  _isLastSection && _isLastLesson
                      ? Icons.check_circle_outline_rounded
                      : Icons.arrow_forward_rounded,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
