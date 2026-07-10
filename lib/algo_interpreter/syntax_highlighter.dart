import 'package:flutter/material.dart';

class AlgoSyntaxController extends TextEditingController {
  AlgoSyntaxController({super.text});

  static final RegExp _pattern = RegExp(
    r'(//.*|/\*[\s\S]*?\*/)|' // Comments group 1
    r'("[^"]*"|\x27[^\x27]*\x27)|' // Strings group 2
    r'\b(algorithme|var|variables|const|début|debut|fin|si|alors|sinon|finsi|tant que|faire|fintantque|pour|de|à|a|finpour|répéter|repeter|jusqu\u0027à|jusqu\u0027a|fonction|procédure|procedure|retourner|et|ou|non|mod|div)\b|' // Keywords group 3
    r'\b(entier|réel|reel|chaîne|chaine|caractère|caractere|booléen|booleen|tableau|de)\b|' // Types group 4
    r'\b(vrai|faux)\b|' // Booleans group 5
    r'\b\d+(?:\.\d+)?\b', // Numbers group 6
    caseSensitive: false,
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (text.isEmpty) {
      return TextSpan(style: style);
    }

    final List<InlineSpan> spans = [];
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final TextStyle baseStyle = style ?? const TextStyle();
    final TextStyle commentStyle = baseStyle.copyWith(color: Colors.grey, fontStyle: FontStyle.italic);
    final TextStyle stringStyle = baseStyle.copyWith(color: isDark ? Colors.orange[300] : Colors.orange[800]);
    final TextStyle keywordStyle = baseStyle.copyWith(color: isDark ? Colors.purpleAccent : Colors.purple, fontWeight: FontWeight.bold);
    final TextStyle typeStyle = baseStyle.copyWith(color: isDark ? Colors.greenAccent : Colors.green[700]);
    final TextStyle boolStyle = baseStyle.copyWith(color: isDark ? Colors.cyanAccent : Colors.teal[700]);
    final TextStyle numStyle = baseStyle.copyWith(color: isDark ? Colors.blueAccent : Colors.blue[800]);

    text.splitMapJoin(
      _pattern,
      onMatch: (Match match) {
        final String m = match[0]!;
        TextStyle matchStyle;

        if (match.group(1) != null) {
          matchStyle = commentStyle;
        } else if (match.group(2) != null) {
          matchStyle = stringStyle;
        } else if (match.group(3) != null) {
          matchStyle = keywordStyle;
        } else if (match.group(4) != null) {
          matchStyle = typeStyle;
        } else if (match.group(5) != null) {
          matchStyle = boolStyle;
        } else {
          matchStyle = numStyle;
        }
        spans.add(TextSpan(text: m, style: matchStyle));
        return '';
      },
      onNonMatch: (String nonMatch) {
        spans.add(TextSpan(text: nonMatch, style: style));
        return '';
      },
    );

    return TextSpan(style: style, children: spans);
  }
}
