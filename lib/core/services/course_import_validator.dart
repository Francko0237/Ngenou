import 'dart:convert';
import '../models/custom_course_package.dart';

class CourseValidationResult {
  final bool isValid;
  final List<String> errors;
  final CustomCoursePackage? package;

  CourseValidationResult({
    required this.isValid,
    required this.errors,
    this.package,
  });
}

class CourseImportValidator {
  /// Supprime les commentaires JavaScript // ou /* */ situés hors des chaînes JSON
  static String _removeComments(String text) {
    final buf = StringBuffer();
    bool inString = false;
    bool escaped = false;

    for (int i = 0; i < text.length; i++) {
      final c = text[i];
      if (escaped) {
        buf.write(c);
        escaped = false;
        continue;
      }
      if (c == '\\') {
        buf.write(c);
        if (inString) escaped = true;
        continue;
      }
      if (c == '"') {
        inString = !inString;
        buf.write(c);
        continue;
      }

      if (!inString && c == '/' && i + 1 < text.length) {
        final next = text[i + 1];
        if (next == '/') {
          int j = i + 2;
          while (j < text.length && text[j] != '\n') {
            j++;
          }
          i = j - 1;
          continue;
        } else if (next == '*') {
          int j = i + 2;
          while (j + 1 < text.length && !(text[j] == '*' && text[j + 1] == '/')) {
            j++;
          }
          i = j + 1;
          continue;
        }
      }

      buf.write(c);
    }
    return buf.toString();
  }

  /// Ferme automatiquement les chaînes, crochets ou accolades manquants si le LLM a été tronqué
  static String _autoCloseJson(String text) {
    int openBraces = 0;
    int openBrackets = 0;
    bool inString = false;
    bool escaped = false;

    for (int i = 0; i < text.length; i++) {
      final c = text[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (c == '\\') {
        if (inString) escaped = true;
        continue;
      }
      if (c == '"') {
        inString = !inString;
        continue;
      }
      if (!inString) {
        if (c == '{') openBraces++;
        if (c == '}') if (openBraces > 0) openBraces--;
        if (c == '[') openBrackets++;
        if (c == ']') if (openBrackets > 0) openBrackets--;
      }
    }

    if (!inString && openBraces == 0 && openBrackets == 0) {
      return text;
    }

    String result = text;
    if (inString) {
      result += '"';
    }
    result = result.replaceAll(RegExp(r',\s*$'), '');
    while (openBrackets > 0) {
      result += ']';
      openBrackets--;
    }
    while (openBraces > 0) {
      result += '}';
      openBraces--;
    }
    return result;
  }

  /// Tente de réparer les erreurs JSON les plus courantes produites par les LLMs :
  /// - Blocs Markdown ```json
  /// - Texte avant / après
  /// - Commentaires hors chaînes
  /// - Virgules traînantes et guillemets orphelins avant accolades / crochets (ex: ," }, ,""}, , })
  /// - Retours à la ligne et tabulations réels dans les chaînes
  /// - Troncature du JSON
  static String _repairJson(String raw) {
    String clean = raw.trim();
    if (clean.startsWith('```')) {
      final firstLineEnd = clean.indexOf('\n');
      if (firstLineEnd != -1) {
        clean = clean.substring(firstLineEnd).trim();
      }
      if (clean.endsWith('```')) {
        clean = clean.substring(0, clean.length - 3).trim();
      }
    }

    // Étape 1 : Extraire le JSON pur
    final firstBrace = clean.indexOf('{');
    final lastBrace = clean.lastIndexOf('}');
    if (firstBrace == -1) {
      return clean;
    }
    String candidate = (lastBrace != -1 && lastBrace > firstBrace)
        ? clean.substring(firstBrace, lastBrace + 1)
        : clean.substring(firstBrace);

    // Étape 2 : Supprimer les commentaires
    candidate = _removeComments(candidate);

    // Étape 3 : Supprimer les virgules traînantes et guillemets orphelins préliminaires
    // (ex: [1, 2, ], {"a": 1, }, {"a": "val", "}, {"a": "val", ""})
    candidate = candidate.replaceAllMapped(
      RegExp(r',\s*"{0,2}\s*([\]}])'),
      (m) => m[1]!,
    );
    candidate = candidate.replaceAll(RegExp(r',\s*,'), ',');

    // Étape 4 : Corriger les retours à la ligne et tabulations réels à l'intérieur des chaînes
    final buf = StringBuffer();
    bool inString = false;
    bool escaped = false;
    for (int i = 0; i < candidate.length; i++) {
      final c = candidate[i];
      if (escaped) {
        buf.write(c);
        escaped = false;
        continue;
      }
      if (c == '\\') {
        escaped = true;
        buf.write(c);
        continue;
      }
      if (c == '"') {
        inString = !inString;
        buf.write(c);
        continue;
      }
      if (inString && c == '\n') {
        buf.write(r'\n');
        continue;
      }
      if (inString && c == '\r') {
        buf.write(r'\r');
        continue;
      }
      if (inString && c == '\t') {
        buf.write(r'\t');
        continue;
      }
      buf.write(c);
    }

    String result = buf.toString();

    // Étape 5 : Nettoyage final des virgules orphelines et guillemets orphelins avant fermeture
    result = result.replaceAllMapped(
      RegExp(r',\s*"{0,2}\s*([\]}])'),
      (m) => m[1]!,
    );
    result = result.replaceAll(RegExp(r',\s*,'), ',');

    // Étape 6 : Fermeture automatique si tronqué
    result = _autoCloseJson(result);

    return result;
  }

  /// Tente de corriger une erreur de syntaxe localisée signalée par [FormatException]
  static Map<String, dynamic>? _tryFixAtOffset(String text, FormatException e) {
    final offset = e.offset;
    if (offset == null || offset < 0 || offset > text.length) return null;

    final start = (offset - 40).clamp(0, text.length);
    final end = (offset + 40).clamp(0, text.length);
    final window = text.substring(start, end);

    // Motif ," } ou ,""} ou , } ou "" dans la fenêtre
    if (window.contains(RegExp(r',\s*"{1,2}\s*([\]}])'))) {
      final fixedWindow = window.replaceAllMapped(
        RegExp(r',\s*"{1,2}\s*([\]}])'),
        (m) => m[1]!,
      );
      final candidate = text.substring(0, start) + fixedWindow + text.substring(end);
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    // Guillemet double interne non échappé à l'offset
    if (offset < text.length && text[offset] == '"') {
      final candidate = text.substring(0, offset) + r'\"' + text.substring(offset + 1);
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    return null;
  }

  /// Répare automatiquement les incohérences de structure fréquentes des LLMs :
  /// - Notions orphelines (sans leçons et sans exercices) générées à la fin du cours : supprimées.
  /// - Notions ayant des leçons mais aucun exercice : génère automatiquement des QCM pertinents.
  /// - Notions ayant des exercices mais aucune leçon : génère une leçon de synthèse.
  /// - Exercices avec options insuffisantes ou bonneReponseIndex invalide : réparés.
  static void _healCourseStructure(Map<String, dynamic> root) {
    final rawNotions = root['notions'];
    if (rawNotions is! List || rawNotions.isEmpty) return;

    final notions = List<Map<String, dynamic>>.from(
      rawNotions.whereType<Map<String, dynamic>>(),
    );

    final rawLecons = root['lecons'];
    final lecons = rawLecons is List
        ? List<Map<String, dynamic>>.from(
            rawLecons.whereType<Map<String, dynamic>>(),
          )
        : <Map<String, dynamic>>[];

    final rawExercices = root['exercices'];
    final exercices = rawExercices is List
        ? List<Map<String, dynamic>>.from(
            rawExercices.whereType<Map<String, dynamic>>(),
          )
        : <Map<String, dynamic>>[];

    // 1. Éliminer les notions orphelines (aucune leçon ET aucun exercice) s'il reste d'autres notions valides
    if (notions.length > 1) {
      notions.removeWhere((n) {
        final nid = n['id'] as String?;
        if (nid == null) return false;
        final hasLec = lecons.any((l) => l['notionId'] == nid);
        final hasExo = exercices.any((e) => e['notionId'] == nid);
        return !hasLec && !hasExo;
      });
    }

    // 2. Combler les notions incomplètes
    for (final n in notions) {
      final nid = n['id'] as String?;
      if (nid == null) continue;

      final notionLessons = lecons.where((l) => l['notionId'] == nid).toList();
      final hasExo = exercices.any((e) => e['notionId'] == nid);
      final hasLec = notionLessons.isNotEmpty;

      // Notion avec leçons mais SANS exercice : créer des QCMs de validation
      if (!hasExo) {
        final notionTitle = (n['titre'] as String?)?.trim() ?? 'ce chapitre';
        final firstLessonTitle = (notionLessons.isNotEmpty
                ? notionLessons.first['titre'] as String?
                : null)
            ?.trim() ?? notionTitle;

        exercices.add({
          'id': 'auto_${nid}_exo_1',
          'notionId': nid,
          'type': 'qcm',
          'question': 'Quel est le concept clé à retenir sur "$notionTitle" ?',
          'options': [
            'Comprendre et appliquer les bases de $notionTitle',
            'Ignorer les notions fondamentales',
            'Sauter la mise en pratique des règles',
          ],
          'bonneReponseIndex': 0,
          'explication':
              'Ce chapitre permet de valider et maîtriser les compétences clés sur "$notionTitle".',
        });

        exercices.add({
          'id': 'auto_${nid}_exo_2',
          'notionId': nid,
          'type': 'qcm',
          'question': 'Concernant "$firstLessonTitle", quelle est la méthode recommandée ?',
          'options': [
            'Suivre attentivement les explications et tester les exemples',
            'Ne pas lire les détails de la leçon',
            'Répondre au hasard sans analyse',
          ],
          'bonneReponseIndex': 0,
          'explication':
              'La pratique et la lecture appliquée permettent de réussir les exercices de "$notionTitle".',
        });
      }

      // Notion avec exercices mais SANS leçon : créer une leçon introductive
      if (!hasLec) {
        final notionTitle = (n['titre'] as String?)?.trim() ?? 'ce chapitre';
        lecons.add({
          'id': 'auto_${nid}_lec_1',
          'notionId': nid,
          'titre': 'Introduction : $notionTitle',
          'contenu':
              '### Définition\nCe chapitre explore les notions essentielles de $notionTitle.\n\n### À retenir\nPratiquez avec les exercices pour consolider votre compréhension.',
          'explicationDetaillee':
              'Ce chapitre aborde $notionTitle de manière progressive et pratique pour assurer une compréhension claire.',
        });
      }
    }

    // 3. Normaliser les exercices existants
    for (var i = 0; i < exercices.length; i++) {
      final e = exercices[i];
      final type = e['type'] as String?;
      if (type != 'qcm' && type != 'editeur') {
        e['type'] = 'qcm';
      }
      if (e['type'] == 'qcm') {
        final opts = e['options'];
        if (opts is! List || opts.length < 2) {
          e['options'] = ['Vrai / Exact', 'Faux / Erroné'];
        }
        final idx = e['bonneReponseIndex'];
        final optList = e['options'] as List;
        if (idx is! int || idx < 0 || idx >= optList.length) {
          e['bonneReponseIndex'] = 0;
        }
      }
    }

    root['notions'] = notions;
    root['lecons'] = lecons;
    root['exercices'] = exercices;
  }

  static CourseValidationResult validate(String rawJson) {
    final errors = <String>[];

    Map<String, dynamic> root;
    try {
      final repaired = _repairJson(rawJson);
      try {
        final decoded = jsonDecode(repaired);
        if (decoded is! Map<String, dynamic>) {
          return CourseValidationResult(
            isValid: false,
            errors: ['Le cours doit commencer par { et finir par }.'],
          );
        }
        root = decoded;
      } on FormatException catch (fe) {
        final recovered = _tryFixAtOffset(repaired, fe);
        if (recovered != null) {
          root = recovered;
        } else {
          rethrow;
        }
      }
    } catch (e) {
      return CourseValidationResult(
        isValid: false,
        errors: ['Format de cours invalide : ${e.toString()}'],
      );
    }

    // Auto-guérison de la structure pour combler les notions sans exercices ou sans leçons
    _healCourseStructure(root);

    final version = root['schemaVersion'] as String?;
    if (version == null || version.isEmpty) {
      errors.add(
        'Champ obligatoire manquant : schemaVersion (utilisez "1.0").',
      );
    } else if (version != CustomCoursePackage.schemaVersion) {
      errors.add(
        'schemaVersion "$version" non supportée. Version attendue : ${CustomCoursePackage.schemaVersion}.',
      );
    }

    final matiere = root['matiere'];
    if (matiere is! Map<String, dynamic>) {
      errors.add('Champ obligatoire manquant ou invalide : matiere.');
    } else {
      _requireString(matiere, 'id', errors, prefix: 'matiere');
      _requireString(matiere, 'nom', errors, prefix: 'matiere');
      final id = matiere['id'] as String?;
      if (id != null && !id.startsWith('custom_')) {
        errors.add(
          'matiere.id doit commencer par "custom_" (ex: custom_physique_01).',
        );
      }
    }

    final notions = root['notions'];
    if (notions is! List || notions.isEmpty) {
      errors.add('Le tableau "notions" doit contenir au moins 1 chapitre.');
    }

    final lecons = root['lecons'] is List ? root['lecons'] as List<dynamic> : null;
    if (lecons == null || lecons.isEmpty) {
      errors.add('Le tableau "lecons" doit contenir au moins 1 leçon.');
    }

    final exercices = root['exercices'] is List ? root['exercices'] as List<dynamic> : null;
    if (exercices == null || exercices.isEmpty) {
      errors.add('Le tableau "exercices" doit contenir au moins 1 exercice.');
    }

    if (errors.isNotEmpty) {
      return CourseValidationResult(isValid: false, errors: errors);
    }

    final notionIds = <String>{};
    for (var i = 0; i < (notions as List).length; i++) {
      final n = notions[i];
      if (n is! Map<String, dynamic>) {
        errors.add('notions[$i] : objet invalide.');
        continue;
      }
      _requireString(n, 'id', errors, prefix: 'notions[$i]');
      _requireString(n, 'titre', errors, prefix: 'notions[$i]');
      final niveau = n['niveau'] as String?;
      if (niveau == null ||
          !['debutant', 'intermediaire', 'avance'].contains(niveau)) {
        errors.add(
          'notions[$i].niveau : doit être "debutant", "intermediaire" ou "avance".',
        );
      }
      final nid = n['id'] as String?;
      if (nid != null) {
        if (notionIds.contains(nid)) errors.add('ID de notion dupliqué : $nid');
        notionIds.add(nid);
      }
    }

    final leconIds = <String>{};
    for (var i = 0; i < (lecons ?? []).length; i++) {
      final l = lecons![i];
      if (l is! Map<String, dynamic>) {
        errors.add('lecons[$i] : objet invalide.');
        continue;
      }
      _requireString(l, 'id', errors, prefix: 'lecons[$i]');
      _requireString(l, 'notionId', errors, prefix: 'lecons[$i]');
      _requireString(l, 'titre', errors, prefix: 'lecons[$i]');
      _requireString(l, 'contenu', errors, prefix: 'lecons[$i]');
      final lid = l['id'] as String?;
      if (lid != null) {
        if (leconIds.contains(lid)) errors.add('ID de leçon dupliqué : $lid');
        leconIds.add(lid);
      }
      final nid = l['notionId'] as String?;
      if (nid != null && !notionIds.contains(nid)) {
        errors.add('lecons[$i] : notionId "$nid" introuvable dans notions.');
      }
    }

    final metaMap = root['meta'];
    final hasTerminal =
        metaMap is Map<String, dynamic> &&
        (metaMap['hasTerminal'] as bool? ?? false);

    for (var i = 0; i < (exercices ?? []).length; i++) {
      final e = exercices![i];
      if (e is! Map<String, dynamic>) {
        errors.add('exercices[$i] : objet invalide.');
        continue;
      }
      _requireString(e, 'id', errors, prefix: 'exercices[$i]');
      _requireString(e, 'notionId', errors, prefix: 'exercices[$i]');
      _requireString(e, 'question', errors, prefix: 'exercices[$i]');
      final type = e['type'] as String?;
      if (type == null || !['qcm', 'editeur'].contains(type)) {
        errors.add(
          'exercices[$i].type : doit être "qcm" ou "editeur" (QRO non supporté).',
        );
        continue;
      }
      if (type == 'editeur' && !hasTerminal) {
        errors.add(
          'exercices[$i] : type "editeur" interdit (meta.hasTerminal doit être true).',
        );
      }
      final nid = e['notionId'] as String?;
      if (nid != null && !notionIds.contains(nid)) {
        errors.add('exercices[$i] : notionId "$nid" introuvable dans notions.');
      }
      if (type == 'qcm') {
        final opts = e['options'];
        if (opts is! List || opts.length < 2) {
          errors.add('exercices[$i] : QCM requiert au moins 2 options.');
        }
        final idx = e['bonneReponseIndex'];
        if (idx is! int) {
          errors.add('exercices[$i] : bonneReponseIndex obligatoire pour QCM.');
        } else if (opts is List && (idx < 0 || idx >= opts.length)) {
          errors.add('exercices[$i] : bonneReponseIndex hors limites.');
        }
      }
      if (type == 'editeur') {
        if ((e['codeInitial'] as String?)?.isEmpty ?? true) {
          errors.add('exercices[$i] : codeInitial recommandé pour editeur.');
        }
      }
    }

    for (final nid in notionIds) {
      final hasLecon = (lecons ?? []).any(
        (l) => l is Map && l['notionId'] == nid,
      );
      if (!hasLecon) {
        errors.add('La notion "$nid" n\'a aucune leçon associée.');
      }
      final hasExo = (exercices ?? []).any(
        (e) => e is Map && e['notionId'] == nid,
      );
      if (!hasExo) {
        errors.add('La notion "$nid" n\'a aucun exercice associé.');
      }
    }

    if (errors.isNotEmpty) {
      return CourseValidationResult(isValid: false, errors: errors);
    }

    try {
      final package = CustomCoursePackage.fromJson(root);
      return CourseValidationResult(
        isValid: true,
        errors: [],
        package: package,
      );
    } catch (e) {
      return CourseValidationResult(
        isValid: false,
        errors: ['Erreur de conversion : ${e.toString()}'],
      );
    }
  }

  static void _requireString(
    Map<String, dynamic> map,
    String key,
    List<String> errors, {
    required String prefix,
  }) {
    final v = map[key];
    if (v is! String || v.trim().isEmpty) {
      errors.add('$prefix.$key : chaîne non vide obligatoire.');
    }
  }
}
