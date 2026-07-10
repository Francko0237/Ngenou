import 'package:flutter/material.dart';

/// Rendu Markdown léger pour les messages IA.
/// Gère : titres (#, ##, ###), gras (**), italique (*),
/// code inline (`), listes (-, *, •), séparateurs (---).
class AiMarkdownText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool selectable;

  const AiMarkdownText({
    super.key,
    required this.text,
    this.style,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    final defaultStyle =
        style ??
        TextStyle(
          color: isDark ? Colors.grey[200] : Colors.grey[800],
          fontSize: 15,
          height: 1.55,
        );

    // Séparer le texte en lignes pour gérer les structures block
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Tableau Markdown (| col 1 | col 2 |)
      if (line.trim().startsWith('|') && line.trim().endsWith('|')) {
        final tableLines = <String>[];
        while (i < lines.length &&
            lines[i].trim().startsWith('|') &&
            lines[i].trim().endsWith('|')) {
          tableLines.add(lines[i]);
          i++;
        }
        i--; // Se replacer sur la dernière ligne du tableau
        widgets.add(
          _buildTable(tableLines, defaultStyle, primary, isDark, selectable),
        );
        continue;
      }

      // Séparateur ---
      if (RegExp(r'^---+$').hasMatch(line.trim())) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Divider(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              thickness: 1,
            ),
          ),
        );
        continue;
      }

      // Titres # ## ### (avec ou sans contenu — robuste pendant le typewriter)
      final headingMatch = RegExp(r'^(#{1,3})\s*(.*)$').firstMatch(line);
      if (headingMatch != null && line.trimLeft().startsWith('#')) {
        final level = headingMatch.group(1)!.length;
        final content = headingMatch.group(2)!.trim();
        final fontSize = level == 1
            ? 19.0
            : level == 2
            ? 17.0
            : 15.5;
        // Si le contenu est vide (typewriter en cours), afficher juste l'espace
        if (content.isEmpty) {
          widgets.add(const SizedBox(height: 4));
          continue;
        }
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: level == 1 ? 10 : 6, bottom: 2),
            child: _buildInlineText(
              content,
              defaultStyle.copyWith(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
              primary,
              isDark,
              selectable,
            ),
          ),
        );
        continue;
      }

      // Listes - * •
      final listMatch = RegExp(r'^(\s*)([-*•])\s+(.+)$').firstMatch(line);
      if (listMatch != null) {
        final indent = listMatch.group(1)!.length;
        final content = listMatch.group(3)!;
        widgets.add(
          Padding(
            padding: EdgeInsets.only(left: 8.0 + indent * 4, top: 2, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5, right: 8),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildInlineText(
                    content,
                    defaultStyle,
                    primary,
                    isDark,
                    selectable,
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Ligne vide
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 4));
        continue;
      }

      // Ligne normale avec inline markdown
      widgets.add(
        _buildInlineText(line, defaultStyle, primary, isDark, selectable),
      );
    }

    if (selectable) {
      return SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: widgets,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  /// Rendu inline : **gras**, *italique*, `code`
  static Widget _buildInlineText(
    String text,
    TextStyle defaultStyle,
    Color primary,
    bool isDark,
    bool selectable,
  ) {
    final normalized = text.replaceAll('***', '**');
    final pattern = RegExp(r'\*\*(.*?)\*\*|\*(.*?)\*|`(.*?)`', dotAll: true);
    final spans = <TextSpan>[];
    var lastEnd = 0;

    for (final match in pattern.allMatches(normalized)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: normalized.substring(lastEnd, match.start),
            style: defaultStyle,
          ),
        );
      }
      if (match.group(1) != null) {
        spans.add(
          TextSpan(
            text: match.group(1),
            style: defaultStyle.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        );
      } else if (match.group(2) != null) {
        spans.add(
          TextSpan(
            text: match.group(2),
            style: defaultStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (match.group(3) != null) {
        spans.add(
          TextSpan(
            text: ' ${match.group(3)} ',
            style: TextStyle(
              color: primary,
              backgroundColor: primary.withValues(alpha: 0.08),
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              fontSize: defaultStyle.fontSize != null
                  ? defaultStyle.fontSize! - 1
                  : 14,
            ),
          ),
        );
      }
      lastEnd = match.end;
    }

    if (lastEnd < normalized.length) {
      spans.add(
        TextSpan(text: normalized.substring(lastEnd), style: defaultStyle),
      );
    }

    final richText = TextSpan(children: spans);
    // Toujours Text.rich — la sélection est gérée par SelectionArea au niveau parent
    return Text.rich(richText);
  }

  /// Extrait les cellules d'une ligne de tableau Markdown.
  static List<String> _parseTableRow(String row) {
    final cells = row.split('|');
    if (cells.length > 2) {
      return cells.sublist(1, cells.length - 1).map((c) => c.trim()).toList();
    }
    return [];
  }

  /// Détermine si une ligne de tableau est un séparateur d'en-tête (ex: |---|---|).
  static bool _isSeparatorRow(String row) {
    final cells = _parseTableRow(row);
    if (cells.isEmpty) return false;
    return cells.every((cell) => RegExp(r'^:?-+:?$').hasMatch(cell));
  }

  /// Détermine l'alignement des colonnes depuis le séparateur d'en-tête.
  static List<TextAlign> _parseAlignments(String separatorRow) {
    final cells = _parseTableRow(separatorRow);
    return cells.map((cell) {
      if (cell.startsWith(':') && cell.endsWith(':')) {
        return TextAlign.center;
      } else if (cell.endsWith(':')) {
        return TextAlign.right;
      } else {
        return TextAlign.left;
      }
    }).toList();
  }

  /// Rendu premium du tableau avec scrolling horizontal et design épuré.
  static Widget _buildTable(
    List<String> tableLines,
    TextStyle defaultStyle,
    Color primary,
    bool isDark,
    bool selectable,
  ) {
    if (tableLines.isEmpty) return const SizedBox.shrink();

    // Extraction de l'en-tête
    final headerCells = _parseTableRow(tableLines[0]);
    if (headerCells.isEmpty) return const SizedBox.shrink();

    List<TextAlign> alignments = List.filled(
      headerCells.length,
      TextAlign.left,
    );
    int dataStartIndex = 1;

    // Détection d'un séparateur d'en-tête
    if (tableLines.length > 1 && _isSeparatorRow(tableLines[1])) {
      alignments = _parseAlignments(tableLines[1]);
      dataStartIndex = 2;
    }

    // Sécurité de longueur d'alignement
    while (alignments.length < headerCells.length) {
      alignments.add(TextAlign.left);
    }

    final tableRows = <TableRow>[];

    // En-tête du tableau
    tableRows.add(
      TableRow(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF262626) : Colors.grey[100],
        ),
        children: headerCells.asMap().entries.map((entry) {
          final index = entry.key;
          final cellText = entry.value;
          final align = alignments[index];
          return TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Align(
                alignment: align == TextAlign.center
                    ? Alignment.center
                    : align == TextAlign.right
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: _buildInlineText(
                  cellText,
                  defaultStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  primary,
                  isDark,
                  selectable,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );

    // Lignes de données
    for (int i = dataStartIndex; i < tableLines.length; i++) {
      final rowCells = _parseTableRow(tableLines[i]);
      final paddedCells = List<String>.from(rowCells);
      while (paddedCells.length < headerCells.length) {
        paddedCells.add('');
      }
      if (paddedCells.length > headerCells.length) {
        paddedCells.removeRange(headerCells.length, paddedCells.length);
      }

      final isEven = (i - dataStartIndex) % 2 == 0;
      tableRows.add(
        TableRow(
          decoration: BoxDecoration(
            color: isEven
                ? Colors.transparent
                : (isDark ? Colors.white.withOpacity(0.02) : Colors.grey[50]!),
          ),
          children: paddedCells.asMap().entries.map((entry) {
            final index = entry.key;
            final cellText = entry.value;
            final align = alignments[index];
            return TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Align(
                  alignment: align == TextAlign.center
                      ? Alignment.center
                      : align == TextAlign.right
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: _buildInlineText(
                    cellText,
                    defaultStyle,
                    primary,
                    isDark,
                    selectable,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder(
              horizontalInside: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                width: 0.5,
              ),
              verticalInside: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                width: 0.5,
              ),
            ),
            children: tableRows,
          ),
        ),
      ),
    );
  }
}
