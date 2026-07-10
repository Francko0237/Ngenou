import 'package:flutter/material.dart';
import '../../../algo_interpreter/syntax_highlighter.dart';
import '../../../core/utils/lesson_block_mapper.dart';
import '../../../core/utils/lesson_content_parser.dart';
import 'context_svg_icon.dart';
import 'lesson_reveal_tile.dart';

class LessonSectionCard extends StatefulWidget {
  final LessonSection section;
  final String? contexte;
  final bool isActive;

  const LessonSectionCard({
    super.key,
    required this.section,
    this.contexte,
    this.isActive = true,
  });

  @override
  State<LessonSectionCard> createState() => _LessonSectionCardState();
}

class _LessonSectionCardState extends State<LessonSectionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutQuart));

    if (widget.isActive) _entryController.forward();
  }

  @override
  void didUpdateWidget(LessonSectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _entryController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = LessonBlockMapper.styleFor(widget.section.title);
    final accent = LessonBlockMapper.colorFor(widget.contexte, widget.section.blockType);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final hPad = w > 800 ? w * 0.12 : 24.0;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.15 : 0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.2),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ContextSvgIcon(
                        assetPath: style.svgAsset,
                        color: accent,
                        size: 56,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: isDark ? 0.2 : 0.12),
                          accent.withValues(alpha: isDark ? 0.05 : 0.03),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border(left: BorderSide(color: accent, width: 4)),
                    ),
                    child: Text(
                      widget.section.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  ..._buildBodyWidgets(widget.section.bodyLines, isDark, accent),
                  if (widget.section.reveals.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    ...widget.section.reveals.map(
                      (r) => LessonRevealTile(
                        title: r.title,
                        content: r.content,
                        accent: accent,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildBodyWidgets(List<String> lines, bool isDark, Color accent) {
    final widgets = <Widget>[];
    var inCodeBlock = false;
    var codeContent = '';

    for (final line in lines) {
      if (line.trim().startsWith('```')) {
        if (!inCodeBlock) {
          inCodeBlock = true;
          codeContent = '';
        } else {
          inCodeBlock = false;
          widgets.add(_codeBlock(codeContent.trimRight()));
        }
        continue;
      }

      if (inCodeBlock) {
        codeContent += '$line\n';
        continue;
      }

      if (line.startsWith('> ') && !line.startsWith('> ?')) {
        widgets.add(_quoteBlock(line.substring(2), isDark, accent));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(_listItem(line.substring(2), isDark, accent));
      } else if (line.trim().isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _parseInline(line, isDark),
          ),
        );
      } else {
        widgets.add(const SizedBox(height: 8));
      }
    }

    return widgets;
  }

  Widget _codeBlock(String code) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: RichText(
            text: AlgoSyntaxController(text: code).buildTextSpan(
              context: context,
              withComposing: false,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _quoteBlock(String text, bool isDark, Color accent) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: _parseInline(text, isDark),
    );
  }

  Widget _listItem(String text, bool isDark, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Icon(Icons.circle, size: 6, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(child: _parseInline(text, isDark)),
        ],
      ),
    );
  }

  Widget _parseInline(String text, bool isDark) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.*?)\*\*|\*(.*?)\*|`(.*?)`');
    var lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[800],
            fontSize: 16,
            height: 1.65,
          ),
        ));
      }
      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: match.group(1),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            height: 1.65,
          ),
        ));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(
          text: match.group(2),
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[800],
            fontSize: 16,
            fontStyle: FontStyle.italic,
            height: 1.65,
          ),
        ));
      } else if (match.group(3) != null) {
        spans.add(TextSpan(
          text: ' ${match.group(3)} ',
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ));
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(
          color: isDark ? Colors.grey[300] : Colors.grey[800],
          fontSize: 16,
          height: 1.65,
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }
}
