import 'package:flutter/material.dart';

/// Détecte si une ligne représente une opération mathématique ou une équation à mettre en valeur
bool isMathOperationLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return false;

  // Ligne qui commence par Exemple / Calcul / Étape avec du contenu mathématique
  final cleaned = trimmed
      .replaceAll(
        RegExp(r'^(Exemple|Calcul|Opération|Étape\s*\d*)\s*:\s*', caseSensitive: false),
        '',
      )
      .trim();

  // Équation avec signe égal et opérateurs / fractions
  if (cleaned.contains('=') &&
      (cleaned.contains('/') ||
          cleaned.contains('+') ||
          cleaned.contains('×') ||
          cleaned.contains('*') ||
          cleaned.contains('-') ||
          cleaned.contains('÷'))) {
    return true;
  }

  // Expression mathématique autonome de fractions : ex "1/2 + 3/4"
  if (RegExp(
    r'^\s*([0-9a-zA-Z\(\)]+)\s*\/\s*([0-9a-zA-Z\(\)]+)\s*([+\-×*÷\/=]\s*([0-9a-zA-Z\(\)]+)(\s*\/\s*([0-9a-zA-Z\(\)]+))?\s*)+$',
  ).hasMatch(cleaned)) {
    return true;
  }

  return false;
}

/// Widget affichant une fraction propre verticalement (Numérateur / Dénominateur)
class VerticalFractionWidget extends StatelessWidget {
  final String numerator;
  final String denominator;
  final Color? color;
  final bool isDark;
  final double fontSize;

  const VerticalFractionWidget({
    super.key,
    required this.numerator,
    required this.denominator,
    this.color,
    this.isDark = false,
    this.fontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? (isDark ? Colors.white : const Color(0xFF2C3E50));
    final numStr = numerator.trim();
    final denStr = denominator.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 14),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  numStr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: effectiveColor,
                    height: 1.1,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                height: 1.6,
                color: effectiveColor.withValues(alpha: 0.85),
              ),
              Center(
                child: Text(
                  denStr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: effectiveColor,
                    height: 1.1,
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

/// Petit badge pour intégrer une fraction dans une ligne de texte ordinaire
class InlineFractionBadge extends StatelessWidget {
  final String numerator;
  final String denominator;
  final Color accent;
  final bool isDark;

  const InlineFractionBadge({
    super.key,
    required this.numerator,
    required this.denominator,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 0.8,
        ),
      ),
      child: VerticalFractionWidget(
        numerator: numerator,
        denominator: denominator,
        color: accent,
        isDark: isDark,
        fontSize: 12,
      ),
    );
  }
}

/// Carte dédiée pour détacher visuellement les calculs, opérations et exemples
class MathOperationCard extends StatelessWidget {
  final String line;
  final Color accent;
  final bool isDark;

  const MathOperationCard({
    super.key,
    required this.line,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    String? prefix;
    var mathPart = line.trim();

    final prefixMatch = RegExp(
      r'^(Exemple|Calcul|Opération|Étape\s*\d*)\s*:\s*',
      caseSensitive: false,
    ).firstMatch(line.trim());

    if (prefixMatch != null) {
      prefix = prefixMatch.group(0)?.replaceAll(':', '').trim();
      mathPart = line.trim().substring(prefixMatch.end).trim();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : const Color(0xFFF6F8FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barre supérieure avec badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.16 : 0.08),
                border: Border(
                  bottom: BorderSide(
                    color: accent.withValues(alpha: isDark ? 0.2 : 0.12),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.functions_rounded,
                    size: 15,
                    color: accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    prefix ?? 'Opération / Calcul',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),

            // Contenu mathématique rendu avec défilement horizontal si nécessaire
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: _buildMathElements(mathPart),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMathElements(String text) {
    final widgets = <Widget>[];

    // Découper par égalité '=' pour séparer les étapes de calcul si présentes
    final parts = text.split('=');

    for (int p = 0; p < parts.length; p++) {
      final part = parts[p].trim();
      if (p > 0) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '=',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
        );
      }

      // Analyser les termes et fractions dans la partie
      final tokens = _tokenizeMath(part);
      for (final t in tokens) {
        if (t.isFraction) {
          widgets.add(
            VerticalFractionWidget(
              numerator: t.numerator ?? '',
              denominator: t.denominator ?? '',
              color: isDark ? Colors.white : const Color(0xFF2C3E50),
              isDark: isDark,
              fontSize: 15,
            ),
          );
        } else if (t.isOperator) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                t.raw,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
          );
        } else {
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                t.raw,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[200] : const Color(0xFF2C3E50),
                ),
              ),
            ),
          );
        }
      }
    }

    return widgets;
  }

  List<_MathToken> _tokenizeMath(String segment) {
    final tokens = <_MathToken>[];
    // Pattern pour fractions : e.g. "1/2" ou "(3 * 2)/(5 * 7)"
    final fracRegex = RegExp(r'([0-9a-zA-Z\(\)\*\+\-]+)\s*\/\s*([0-9a-zA-Z\(\)\*\+\-]+)');
    var lastEnd = 0;

    for (final match in fracRegex.allMatches(segment)) {
      if (match.start > lastEnd) {
        final between = segment.substring(lastEnd, match.start);
        _addTextTokens(between, tokens);
      }

      tokens.add(_MathToken(
        raw: match.group(0)!,
        isFraction: true,
        numerator: match.group(1),
        denominator: match.group(2),
      ));

      lastEnd = match.end;
    }

    if (lastEnd < segment.length) {
      _addTextTokens(segment.substring(lastEnd), tokens);
    }

    return tokens;
  }

  void _addTextTokens(String text, List<_MathToken> tokens) {
    final clean = text.trim();
    if (clean.isEmpty) return;

    // Découper sur les opérateurs mathématiques tout en les gardant
    final parts = clean.split(RegExp(r'(?<=[+\-×*÷])|(?=[+\-×*÷])'));
    for (final p in parts) {
      final t = p.trim();
      if (t.isEmpty) continue;
      if (['+', '-', '×', '*', '÷'].contains(t)) {
        tokens.add(_MathToken(raw: t == '*' ? '×' : t, isOperator: true));
      } else {
        tokens.add(_MathToken(raw: t));
      }
    }
  }
}

class _MathToken {
  final String raw;
  final bool isFraction;
  final bool isOperator;
  final String? numerator;
  final String? denominator;

  _MathToken({
    required this.raw,
    this.isFraction = false,
    this.isOperator = false,
    this.numerator,
    this.denominator,
  });
}
