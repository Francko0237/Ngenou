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
  /// Tente de réparer les erreurs JSON les plus courantes produites par les LLMs :
  /// - Texte ou markdown avant/après le JSON
  /// - Retours à la ligne réels à l'intérieur des valeurs de chaîne
  static String _repairJson(String raw) {
    // Étape 1 : Extraire le JSON pur en trouvant la première { et la dernière }
    // On utilise une correspondance de braces pour trouver l'objet JSON complet.
    final firstBrace = raw.indexOf('{');
    final lastBrace = raw.lastIndexOf('}');
    if (firstBrace == -1 || lastBrace == -1 || lastBrace <= firstBrace) {
      // Pas de JSON détectable, on retourne brut (le parser échouera proprement)
      return raw;
    }
    String candidate = raw.substring(firstBrace, lastBrace + 1);

    // Étape 2 : Corriger les retours à la ligne et tabulations réels
    // à l'intérieur des valeurs de chaînes JSON
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
      if (inString && c == '\n') { buf.write(r'\n'); continue; }
      if (inString && c == '\r') { buf.write(r'\r'); continue; }
      if (inString && c == '\t') { buf.write(r'\t'); continue; }
      buf.write(c);
    }
    return buf.toString();
  }

  static CourseValidationResult validate(String rawJson) {
    final errors = <String>[];

    Map<String, dynamic> root;
    try {
      final repaired = _repairJson(rawJson);
      final decoded = jsonDecode(repaired);
      if (decoded is! Map<String, dynamic>) {
        return CourseValidationResult(
          isValid: false,
          errors: ['Le cours doit commencer par { et finir par }.'],
        );
      }
      root = decoded;
    } catch (e) {
      return CourseValidationResult(
        isValid: false,
        errors: ['Format de cours invalide : ${e.toString()}'],
      );
    }

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
