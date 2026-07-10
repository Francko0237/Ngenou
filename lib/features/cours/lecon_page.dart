import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/lecon.dart';
import '../../core/services/ai_tutor_service.dart';
import '../../core/utils/lesson_content_parser.dart';
import '../../modules/modules_registry.dart';
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

    if (widget.openChat) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openAiTutor();
      });
    }
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
    void advance() {
      if (!_isLastSection) {
        _goToSection(_sectionIndex + 1);
      } else if (!_isLastLesson) {
        _goToLesson(_lessonIndex + 1);
      } else {
        context.pushReplacement('/exercice/${widget.matiereId}/${widget.notionId}/0');
      }
    }

    if (_isLastSection) {
      _showExplicationDialog(_currentLecon, advance);
    } else {
      advance();
    }
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
    final lessonProgress = (_lessonIndex + 1) / lecons.length;
    final sectionProgress = (_sectionIndex + 1) / _currentSections.length;
    final combinedProgress = (_currentConceptOffset) / _totalConcepts;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Leçon ${_lessonIndex + 1}/${lecons.length} · Concept ${_sectionIndex + 1}/${_currentSections.length}',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
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
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: combinedProgress,
                minHeight: 4,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
        actions: [
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
                      color: const Color(0xFF3498DB).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(-1, 2),
                    ),
                    BoxShadow(
                      color: const Color(0xFFF1C40F).withOpacity(0.2),
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
              onPressed: () => context.push('/terminal'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: lessonProgress,
                      minHeight: 3,
                      backgroundColor: isDark ? Colors.grey[850] : Colors.grey[200],
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: sectionProgress,
                      minHeight: 3,
                      backgroundColor: isDark ? Colors.grey[850] : Colors.grey[200],
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
              child: Text(
                'Glisse vers le haut ou le bas pour naviguer',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[600] : Colors.grey[500],
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
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
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
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                label: Text(
                  !_isLastSection
                      ? 'Concept suivant'
                      : (_isLastLesson ? 'Passer aux exercices' : 'Leçon suivante'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
