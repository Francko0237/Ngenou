import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/custom_course_package.dart';
import '../../core/models/lecon.dart';
import '../../core/models/notion.dart';
import '../../core/providers/custom_courses_provider.dart';
import '../../core/utils/lesson_content_parser.dart';
import '../../core/utils/lesson_block_mapper.dart';
import '../cours/widgets/lesson_section_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────
class CourseStudioPage extends StatefulWidget {
  final String matiereId;
  final String? teacherCourseId;

  const CourseStudioPage({
    super.key,
    required this.matiereId,
    this.teacherCourseId,
  });

  @override
  State<CourseStudioPage> createState() => _CourseStudioPageState();
}

class _CourseStudioPageState extends State<CourseStudioPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late CustomCoursePackage _pkg;
  late List<Notion> _notions;
  late List<Lecon> _lecons;
  bool _isSaving = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadPackage();
  }

  void _loadPackage() {
    final provider = context.read<CustomCoursesProvider>();
    final module = provider.modules
        .where((m) => m.matiere.id == widget.matiereId)
        .firstOrNull;
    if (module == null) return;
    final raw = jsonDecode(jsonEncode(module.package.toJson()));
    _pkg = CustomCoursePackage.fromJson(raw as Map<String, dynamic>);
    _notions = List.from(_pkg.notions);
    _lecons = List.from(_pkg.lecons);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _markDirty() => setState(() => _isDirty = true);

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final updated = CustomCoursePackage(
      schemaVersionValue: _pkg.schemaVersionValue,
      meta: _pkg.meta,
      matiere: _pkg.matiere,
      notions: _notions,
      lecons: _lecons,
      exercices: _pkg.exercices,
    );
    final provider = context.read<CustomCoursesProvider>();
    final err = await provider.saveEditedPackage(
      updated,
      teacherCourseId: widget.teacherCourseId,
    );
    if (mounted) {
      setState(() {
        _isSaving = false;
        if (err == null) _isDirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(err == null ? '✅ Cours sauvegardé avec succès !' : '❌ $err'),
          backgroundColor:
              err == null ? const Color(0xFF2ECC71) : Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF4F6FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_note_rounded, size: 16, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    'Studio',
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _pkg.matiere.nom,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (_isDirty)
            _isSaving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Sauvegarder'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2ECC71),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt_rounded), text: 'Structure'),
            Tab(icon: Icon(Icons.visibility_rounded), text: 'Contenu'),
          ],
          labelColor: accent,
          unselectedLabelColor: Colors.grey,
          indicatorColor: accent,
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _StructureTab(
            notions: _notions,
            lecons: _lecons,
            isDark: isDark,
            accent: accent,
            onChanged: () {
              setState(() {});
              _markDirty();
            },
          ),
          _WysiwygContentTab(
            notions: _notions,
            lecons: _lecons,
            isDark: isDark,
            accent: accent,
            onLeconUpdated: (idx, updated) {
              setState(() => _lecons[idx] = updated);
              _markDirty();
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 – Structure (chapitres & leçons)
// ─────────────────────────────────────────────────────────────────────────────
class _StructureTab extends StatefulWidget {
  final List<Notion> notions;
  final List<Lecon> lecons;
  final bool isDark;
  final Color accent;
  final VoidCallback onChanged;

  const _StructureTab({
    required this.notions,
    required this.lecons,
    required this.isDark,
    required this.accent,
    required this.onChanged,
  });

  @override
  State<_StructureTab> createState() => _StructureTabState();
}

class _StructureTabState extends State<_StructureTab> {
  void _renameNotion(int idx) {
    final ctrl = TextEditingController(text: widget.notions[idx].titre);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renommer le chapitre'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Titre du chapitre',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final n = widget.notions[idx];
              widget.notions[idx] = Notion(
                id: n.id,
                matiereId: n.matiereId,
                titre: ctrl.text.trim().isEmpty ? n.titre : ctrl.text.trim(),
                niveau: n.niveau,
                description: n.description,
                section: n.section,
                contexte: n.contexte,
              );
              widget.onChanged();
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _renameLecon(int idx) {
    final ctrl = TextEditingController(text: widget.lecons[idx].titre);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renommer la leçon'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Titre de la leçon',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final l = widget.lecons[idx];
              widget.lecons[idx] = Lecon(
                id: l.id,
                notionId: l.notionId,
                titre: ctrl.text.trim().isEmpty ? l.titre : ctrl.text.trim(),
                contenu: l.contenu,
                explicationDetaillee: l.explicationDetaillee,
              );
              widget.onChanged();
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (int ni = 0; ni < widget.notions.length; ni++) ...[
          _ChapterRow(
            notion: widget.notions[ni],
            isDark: widget.isDark,
            accent: widget.accent,
            onRename: () => _renameNotion(ni),
            onMoveUp: ni > 0
                ? () {
                    final tmp = widget.notions[ni];
                    widget.notions[ni] = widget.notions[ni - 1];
                    widget.notions[ni - 1] = tmp;
                    widget.onChanged();
                    setState(() {});
                  }
                : null,
            onMoveDown: ni < widget.notions.length - 1
                ? () {
                    final tmp = widget.notions[ni];
                    widget.notions[ni] = widget.notions[ni + 1];
                    widget.notions[ni + 1] = tmp;
                    widget.onChanged();
                    setState(() {});
                  }
                : null,
          ),
          const SizedBox(height: 8),
          ...() {
            final chapterLecons = widget.lecons
                .where((l) => l.notionId == widget.notions[ni].id)
                .toList();
            final widgets = <Widget>[];
            for (final l in chapterLecons) {
              final globalIdx = widget.lecons.indexOf(l);
              widgets.add(
                Padding(
                  padding: const EdgeInsets.only(left: 20, bottom: 6),
                  child: _LessonRow(
                    lecon: l,
                    isDark: widget.isDark,
                    accent: widget.accent,
                    onRename: () => _renameLecon(globalIdx),
                    onMoveUp: globalIdx > 0
                        ? () {
                            final tmp = widget.lecons[globalIdx];
                            widget.lecons[globalIdx] =
                                widget.lecons[globalIdx - 1];
                            widget.lecons[globalIdx - 1] = tmp;
                            widget.onChanged();
                            setState(() {});
                          }
                        : null,
                    onMoveDown: globalIdx < widget.lecons.length - 1
                        ? () {
                            final tmp = widget.lecons[globalIdx];
                            widget.lecons[globalIdx] =
                                widget.lecons[globalIdx + 1];
                            widget.lecons[globalIdx + 1] = tmp;
                            widget.onChanged();
                            setState(() {});
                          }
                        : null,
                  ),
                ),
              );
            }
            return widgets;
          }(),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ChapterRow extends StatelessWidget {
  final Notion notion;
  final bool isDark;
  final Color accent;
  final VoidCallback onRename;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _ChapterRow({
    required this.notion,
    required this.isDark,
    required this.accent,
    required this.onRename,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: Icon(Icons.folder_rounded, color: accent),
        title: Text(notion.titre,
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onMoveUp != null)
              IconButton(
                icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                tooltip: 'Monter',
                onPressed: onMoveUp,
              ),
            if (onMoveDown != null)
              IconButton(
                icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                tooltip: 'Descendre',
                onPressed: onMoveDown,
              ),
            IconButton(
              icon: Icon(Icons.edit_rounded, color: accent, size: 18),
              tooltip: 'Renommer',
              onPressed: onRename,
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  final Lecon lecon;
  final bool isDark;
  final Color accent;
  final VoidCallback onRename;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _LessonRow({
    required this.lecon,
    required this.isDark,
    required this.accent,
    required this.onRename,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.article_rounded, color: accent, size: 20),
        title: Text(lecon.titre,
            style:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onMoveUp != null)
              IconButton(
                icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                tooltip: 'Monter',
                onPressed: onMoveUp,
              ),
            if (onMoveDown != null)
              IconButton(
                icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                tooltip: 'Descendre',
                onPressed: onMoveDown,
              ),
            IconButton(
              icon: Icon(Icons.edit_rounded, color: accent, size: 16),
              tooltip: 'Renommer',
              onPressed: onRename,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 – WYSIWYG Content Editor
// L'utilisateur voit le rendu final et double-clique pour éditer une section
// ─────────────────────────────────────────────────────────────────────────────
class _WysiwygContentTab extends StatefulWidget {
  final List<Notion> notions;
  final List<Lecon> lecons;
  final bool isDark;
  final Color accent;
  final void Function(int leconIdx, Lecon updated) onLeconUpdated;

  const _WysiwygContentTab({
    required this.notions,
    required this.lecons,
    required this.isDark,
    required this.accent,
    required this.onLeconUpdated,
  });

  @override
  State<_WysiwygContentTab> createState() => _WysiwygContentTabState();
}

class _WysiwygContentTabState extends State<_WysiwygContentTab> {
  int _selectedLeconIdx = 0;

  // Per-lecon mutable sections list (rebuilt when lecon changes)
  late List<_EditableSection> _sections;

  @override
  void initState() {
    super.initState();
    _rebuildSections();
  }

  void _rebuildSections() {
    if (widget.lecons.isEmpty) {
      _sections = [];
      return;
    }
    final lecon = widget.lecons[_selectedLeconIdx];
    final parsed = LessonContentParser.parse(lecon.contenu,
        fallbackTitle: lecon.titre);
    _sections = parsed
        .map((s) => _EditableSection(
              title: s.title,
              bodyText: s.bodyText,
              reveals: s.reveals,
              blockType: s.blockType,
            ))
        .toList();
  }

  void _selectLecon(int idx) {
    setState(() {
      _selectedLeconIdx = idx;
      _rebuildSections();
    });
  }

  /// Reconstruit le contenu Markdown depuis les sections éditées
  String _buildContenu() {
    final buf = StringBuffer();
    for (final s in _sections) {
      buf.writeln('# ${s.title}');
      if (s.bodyText.isNotEmpty) {
        buf.writeln(s.bodyText);
      }
      for (final r in s.reveals) {
        buf.writeln('> ? ${r.title}');
        for (final line in r.content.split('\n')) {
          buf.writeln('> $line');
        }
      }
    }
    return buf.toString().trim();
  }

  void _commitEdits() {
    final l = widget.lecons[_selectedLeconIdx];
    final newContenu = _buildContenu();
    if (newContenu != l.contenu) {
      final updated = Lecon(
        id: l.id,
        notionId: l.notionId,
        titre: l.titre,
        contenu: newContenu,
        explicationDetaillee: l.explicationDetaillee,
      );
      widget.onLeconUpdated(_selectedLeconIdx, updated);
    }
  }

  void _editSection(int sectionIdx) async {
    final section = _sections[sectionIdx];
    final result = await showModalBottomSheet<_EditableSection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SectionEditorSheet(
        section: section,
        isDark: widget.isDark,
        accent: widget.accent,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _sections[sectionIdx] = result;
      });
      _commitEdits();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lecons.isEmpty) {
      return const Center(child: Text('Aucune leçon disponible.'));
    }

    return Column(
      children: [
        // Lesson picker chips
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: widget.lecons.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final selected = i == _selectedLeconIdx;
              return GestureDetector(
                onTap: () => _selectLecon(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? widget.accent
                        : (widget.isDark
                            ? const Color(0xFF1E1E2A)
                            : Colors.white),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? widget.accent
                          : widget.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    widget.lecons[i].titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : (widget.isDark
                              ? Colors.white70
                              : Colors.black87),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Hint banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 14),
          color: widget.accent.withValues(alpha: widget.isDark ? 0.12 : 0.07),
          child: Row(
            children: [
              Icon(Icons.touch_app_rounded,
                  size: 15, color: widget.accent),
              const SizedBox(width: 6),
              Text(
                'Double-cliquez sur une section pour la modifier',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // WYSIWYG rendered sections
        Expanded(
          child: _sections.isEmpty
              ? const Center(child: Text('Aucun contenu trouvé.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _sections.length,
                  itemBuilder: (ctx, i) {
                    final s = _sections[i];
                    // Reconstruct a LessonSection for rendering
                    final rendered = LessonSection(
                      title: s.title,
                      blockType: s.blockType,
                      bodyLines: s.bodyText.split('\n'),
                      reveals: s.reveals,
                    );
                    return _EditableWrapper(
                      isDark: widget.isDark,
                      accent: widget.accent,
                      onDoubleTap: () => _editSection(i),
                      child: LessonSectionCard(
                        section: rendered,
                        isActive: true,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wrapper qui détecte le double-tap et affiche un indicateur d'édition
// ─────────────────────────────────────────────────────────────────────────────
class _EditableWrapper extends StatefulWidget {
  final Widget child;
  final bool isDark;
  final Color accent;
  final VoidCallback onDoubleTap;

  const _EditableWrapper({
    required this.child,
    required this.isDark,
    required this.accent,
    required this.onDoubleTap,
  });

  @override
  State<_EditableWrapper> createState() => _EditableWrapperState();
}

class _EditableWrapperState extends State<_EditableWrapper> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onDoubleTap: widget.onDoubleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered
                  ? widget.accent.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              widget.child,
              // Edit hint on hover
              if (_hovered)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_rounded,
                            size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        const Text(
                          'Double-clic pour modifier',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Mutable section data
// ─────────────────────────────────────────────────────────────────────────────
class _EditableSection {
  String title;
  String bodyText;
  final List<RevealBlock> reveals;
  final LessonBlockType blockType;

  _EditableSection({
    required this.title,
    required this.bodyText,
    required this.reveals,
    required this.blockType,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet éditeur d'une section
// ─────────────────────────────────────────────────────────────────────────────
class _SectionEditorSheet extends StatefulWidget {
  final _EditableSection section;
  final bool isDark;
  final Color accent;

  const _SectionEditorSheet({
    required this.section,
    required this.isDark,
    required this.accent,
  });

  @override
  State<_SectionEditorSheet> createState() => _SectionEditorSheetState();
}

class _SectionEditorSheetState extends State<_SectionEditorSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _bodyCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.section.title);
    _bodyCtrl = TextEditingController(text: widget.section.bodyText);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _insertSnippet(String snippet) {
    final sel = _bodyCtrl.selection;
    final text = _bodyCtrl.text;
    final start = sel.start < 0 ? text.length : sel.start;
    final end = sel.end < 0 ? text.length : sel.end;
    _bodyCtrl.value = TextEditingValue(
      text: text.replaceRange(start, end, snippet),
      selection: TextSelection.collapsed(offset: start + snippet.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sheetHeight = mq.size.height * 0.85;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1C1C28) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.edit_note_rounded, color: widget.accent),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Modifier la section',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Annuler',
                      style: TextStyle(color: Colors.grey.shade500)),
                ),
                const SizedBox(width: 6),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      _EditableSection(
                        title: _titleCtrl.text.trim().isNotEmpty
                            ? _titleCtrl.text.trim()
                            : widget.section.title,
                        bodyText: _bodyCtrl.text,
                        reveals: widget.section.reveals,
                        blockType: widget.section.blockType,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Appliquer',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Title field
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              controller: _titleCtrl,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'Titre de la section',
                prefixIcon: Icon(Icons.title_rounded, color: widget.accent),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.accent, width: 2),
                ),
              ),
            ),
          ),

          // Quick-insert toolbar
          Container(
            color: widget.isDark
                ? const Color(0xFF1A1A28)
                : Colors.blueGrey.shade50,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  _ToolBtn(
                    label: 'Exemple',
                    icon: Icons.lightbulb_outline_rounded,
                    onTap: () =>
                        _insertSnippet('\nExemple : Votre exemple ici\n'),
                    color: const Color(0xFFF39C12),
                  ),
                  _ToolBtn(
                    label: 'Calcul',
                    icon: Icons.calculate_outlined,
                    onTap: () =>
                        _insertSnippet('\nCalcul : a + b = c\n'),
                    color: const Color(0xFF9B59B6),
                  ),
                  _ToolBtn(
                    label: '> Note',
                    icon: Icons.format_quote_rounded,
                    onTap: () =>
                        _insertSnippet('\n> Remarque importante\n'),
                    color: const Color(0xFF2ECC71),
                  ),
                  _ToolBtn(
                    label: 'Q&R',
                    icon: Icons.quiz_outlined,
                    onTap: () => _insertSnippet(
                        '\n> ? Question | Réponse\n'),
                    color: const Color(0xFF3498DB),
                  ),
                  _ToolBtn(
                    label: 'Code',
                    icon: Icons.code_rounded,
                    onTap: () =>
                        _insertSnippet('\n```\nVotre code ici\n```\n'),
                    color: const Color(0xFF1ABC9C),
                  ),
                  _ToolBtn(
                    label: '• Liste',
                    icon: Icons.format_list_bulleted_rounded,
                    onTap: () =>
                        _insertSnippet('\n- Élément\n'),
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          // Body text editor
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: mq.viewInsets.bottom + 12,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? const Color(0xFF16161E)
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: TextField(
                    controller: _bodyCtrl,
                    maxLines: null,
                    expands: true,
                    autofocus: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.7,
                      color: widget.isDark
                          ? Colors.grey[200]
                          : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Contenu de la section…',
                      hintStyle: TextStyle(
                        color: widget.isDark
                            ? Colors.grey[600]
                            : Colors.grey[400],
                      ),
                      contentPadding: const EdgeInsets.all(14),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toolbar button
// ─────────────────────────────────────────────────────────────────────────────
class _ToolBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _ToolBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
