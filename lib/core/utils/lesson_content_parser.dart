import 'lesson_block_mapper.dart';

class RevealBlock {
  final String title;
  final String content;

  const RevealBlock({required this.title, required this.content});
}

class LessonSection {
  final String title;
  final LessonBlockType blockType;
  final List<String> bodyLines;
  final List<RevealBlock> reveals;

  const LessonSection({
    required this.title,
    required this.blockType,
    required this.bodyLines,
    this.reveals = const [],
  });

  String get bodyText => bodyLines.join('\n');
}

/// Découpe le markdown d'une leçon en sections (un concept = une « page » scroll).
class LessonContentParser {
  static List<LessonSection> parse(String rawContent, {String? fallbackTitle}) {
    final lines = rawContent.split('\n');
    final sections = <LessonSection>[];
    final headingRe = RegExp(r'^(#{1,3})\s+(.*)$');

    String? currentTitle;
    LessonBlockType? currentType;
    final bodyLines = <String>[];
    final reveals = <RevealBlock>[];

    String? revealTitle;
    final revealLines = <String>[];

    void flushReveal() {
      if (revealTitle != null && revealLines.isNotEmpty) {
        reveals.add(
          RevealBlock(
            title: revealTitle!,
            content: revealLines.join('\n').trim(),
          ),
        );
      }
      revealTitle = null;
      revealLines.clear();
    }

    void flushSection() {
      flushReveal();
      if (currentTitle != null || bodyLines.isNotEmpty) {
        final title = currentTitle ?? fallbackTitle ?? 'Introduction';
        sections.add(
          LessonSection(
            title: title,
            blockType: currentType ?? LessonBlockMapper.detectType(title),
            bodyLines: List.from(bodyLines),
            reveals: List.from(reveals),
          ),
        );
      }
      bodyLines.clear();
      reveals.clear();
      currentTitle = null;
      currentType = null;
    }

    for (final line in lines) {
      final heading = headingRe.firstMatch(line.trim());
      if (heading != null) {
        flushSection();
        currentTitle = heading.group(2)!.trim();
        currentType = LessonBlockMapper.detectType(currentTitle!);
        continue;
      }

      if (line.startsWith('> ?')) {
        flushReveal();
        revealTitle = line.substring(3).trim();
        if (revealTitle!.isEmpty) revealTitle = 'En savoir plus';
        continue;
      }

      if (revealTitle != null && line.startsWith('> ')) {
        revealLines.add(line.substring(2));
        continue;
      }

      if (revealTitle != null) {
        flushReveal();
      }

      bodyLines.add(line);
    }

    flushSection();

    if (sections.isEmpty) {
      sections.add(
        LessonSection(
          title: fallbackTitle ?? 'Introduction',
          blockType: LessonBlockType.introduction,
          bodyLines: lines,
        ),
      );
    }

    return sections;
  }
}
