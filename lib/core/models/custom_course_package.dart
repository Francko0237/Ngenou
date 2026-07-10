import 'package:flutter/material.dart';
import 'matiere.dart';
import 'notion.dart';
import 'lecon.dart';
import 'exercice.dart';
import '../utils/duration_utils.dart';

/// Enveloppe JSON importée / stockée pour un cours personnalisé.
class CustomCoursePackage {
  static const String schemaVersion = '1.0';

  final String schemaVersionValue;
  final CourseMeta meta;
  final Matiere matiere;
  final List<Notion> notions;
  final List<Lecon> lecons;
  final List<Exercice> exercices;

  CustomCoursePackage({
    required this.schemaVersionValue,
    required this.meta,
    required this.matiere,
    required this.notions,
    required this.lecons,
    required this.exercices,
  });

  bool get hasTerminal => meta.hasTerminal;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersionValue,
    'meta': meta.toJson(),
    'matiere': _matiereToJson(matiere),
    'notions': notions.map(_notionToJson).toList(),
    'lecons': lecons.map(_leconToJson).toList(),
    'exercices': exercices.map(_exerciceToJson).toList(),
  };

  factory CustomCoursePackage.fromJson(Map<String, dynamic> json) {
    final matiereMap = json['matiere'] as Map<String, dynamic>;
    final matiereId = matiereMap['id'] as String;

    return CustomCoursePackage(
      schemaVersionValue: json['schemaVersion'] as String? ?? schemaVersion,
      meta: CourseMeta.fromJson(json['meta'] as Map<String, dynamic>? ?? {}),
      matiere: Matiere(
        id: matiereId,
        nom: matiereMap['nom'] as String,
        description: matiereMap['description'] as String? ?? '',
        icone: iconFromKey(matiereMap['icone'] as String?),
        couleur: colorFromHex(matiereMap['couleur'] as String?),
        isAvailable: true,
        durationMinutes: DurationUtils.parse(matiereMap['durationMinutes'] ?? matiereMap['tempsMinutes']),
        sections:
            (json['notions'] as List<dynamic>?)
                ?.map((n) => (n as Map<String, dynamic>)['section'] as String?)
                .whereType<String>()
                .toSet()
                .toList() ??
            [],
      ),
      notions: (json['notions'] as List<dynamic>)
          .map((n) => _notionFromJson(n as Map<String, dynamic>, matiereId))
          .toList(),
      lecons: (json['lecons'] as List<dynamic>)
          .map((l) => _leconFromJson(l as Map<String, dynamic>))
          .toList(),
      exercices: (json['exercices'] as List<dynamic>)
          .map((e) => _exerciceFromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static Map<String, dynamic> _matiereToJson(Matiere m) => {
    'id': m.id,
    'nom': m.nom,
    'description': m.description,
    'icone': iconToKey(m.icone),
    'couleur': colorToHex(m.couleur),
    'durationMinutes': m.durationMinutes,
  };

  static Map<String, dynamic> _notionToJson(Notion n) => {
    'id': n.id,
    'titre': n.titre,
    'niveau': _niveauToString(n.niveau),
    'description': n.description,
    if (n.section != null) 'section': n.section,
    if (n.contexte != null) 'contexte': n.contexte,
  };

  static Map<String, dynamic> _leconToJson(Lecon l) => {
    'id': l.id,
    'notionId': l.notionId,
    'titre': l.titre,
    'contenu': l.contenu,
    if (l.explicationDetaillee != null)
      'explicationDetaillee': l.explicationDetaillee,
  };

  static Map<String, dynamic> _exerciceToJson(Exercice e) => {
    'id': e.id,
    'notionId': e.notionId,
    'type': _typeToString(e.type),
    'question': e.question,
    'options': e.options,
    'bonneReponseIndex': e.bonneReponseIndex,
    if (e.explication != null) 'explication': e.explication,
    if (e.codeInitial != null) 'codeInitial': e.codeInitial,
    if (e.codeSnippet != null) 'codeSnippet': e.codeSnippet,
    if (e.reponseAttendue != null) 'reponseAttendue': e.reponseAttendue,
  };

  static Notion _notionFromJson(Map<String, dynamic> n, String matiereId) {
    return Notion(
      id: n['id'] as String,
      matiereId: matiereId,
      titre: n['titre'] as String,
      niveau: _niveauFromString(n['niveau'] as String),
      description: n['description'] as String? ?? '',
      section: n['section'] as String?,
      contexte: n['contexte'] as String?,
    );
  }

  static Lecon _leconFromJson(Map<String, dynamic> l) {
    return Lecon(
      id: l['id'] as String,
      notionId: l['notionId'] as String,
      titre: l['titre'] as String,
      contenu: l['contenu'] as String,
      explicationDetaillee: l['explicationDetaillee'] as String?,
    );
  }

  static Exercice _exerciceFromJson(Map<String, dynamic> e) {
    final type = _typeFromString(e['type'] as String);
    final options =
        (e['options'] as List<dynamic>?)?.map((o) => o.toString()).toList() ??
        [];
    return Exercice(
      id: e['id'] as String,
      notionId: e['notionId'] as String,
      type: type,
      question: e['question'] as String,
      options: options,
      bonneReponseIndex: e['bonneReponseIndex'] as int?,
      explication: e['explication'] as String?,
      codeInitial: e['codeInitial'] as String?,
      codeSnippet: e['codeSnippet'] as String?,
      reponseAttendue: e['reponseAttendue'] as String?,
    );
  }

  static String _niveauToString(NiveauNotion n) {
    switch (n) {
      case NiveauNotion.debutant:
        return 'debutant';
      case NiveauNotion.intermediaire:
        return 'intermediaire';
      case NiveauNotion.avance:
        return 'avance';
    }
  }

  static NiveauNotion _niveauFromString(String s) {
    switch (s) {
      case 'intermediaire':
        return NiveauNotion.intermediaire;
      case 'avance':
        return NiveauNotion.avance;
      default:
        return NiveauNotion.debutant;
    }
  }

  static String _typeToString(TypeExercice t) {
    switch (t) {
      case TypeExercice.qro:
        return 'qro';
      case TypeExercice.editeur:
        return 'editeur';
      case TypeExercice.qcm:
        return 'qcm';
    }
  }

  static TypeExercice _typeFromString(String s) {
    switch (s) {
      case 'qro':
        return TypeExercice.qro;
      case 'editeur':
        return TypeExercice.editeur;
      default:
        return TypeExercice.qcm;
    }
  }

  static IconData iconFromKey(String? key) {
    switch (key) {
      case 'code':
        return Icons.code_rounded;
      case 'computer':
        return Icons.computer_rounded;
      case 'science':
        return Icons.science_rounded;
      case 'history':
        return Icons.history_edu_rounded;
      case 'language':
        return Icons.translate_rounded;
      case 'math':
        return Icons.calculate_rounded;
      case 'law':
      case 'justice':
        return Icons.gavel_rounded;
      case 'eco':
      case 'nature':
      case 'agriculture':
        return Icons.eco_rounded;
      case 'food':
      case 'cooking':
      case 'nutrition':
        return Icons.restaurant_rounded;
      case 'sewing':
      case 'fashion':
      case 'couture':
        return Icons.content_cut_rounded;
      case 'sport':
      case 'fitness':
        return Icons.fitness_center_rounded;
      case 'finance':
      case 'economy':
        return Icons.trending_up_rounded;
      case 'art':
      case 'music':
        return Icons.palette_rounded;
      case 'geography':
        return Icons.public_rounded;
      case 'philosophy':
        return Icons.psychology_rounded;
      default:
        return Icons.menu_book_rounded;
    }
  }

  static String iconToKey(IconData icon) {
    if (icon == Icons.code_rounded) return 'code';
    if (icon == Icons.computer_rounded) return 'computer';
    if (icon == Icons.science_rounded) return 'science';
    if (icon == Icons.history_edu_rounded) return 'history';
    if (icon == Icons.translate_rounded) return 'language';
    if (icon == Icons.calculate_rounded) return 'math';
    if (icon == Icons.gavel_rounded) return 'law';
    if (icon == Icons.eco_rounded) return 'eco';
    if (icon == Icons.restaurant_rounded) return 'food';
    if (icon == Icons.content_cut_rounded) return 'sewing';
    if (icon == Icons.fitness_center_rounded) return 'sport';
    if (icon == Icons.trending_up_rounded) return 'finance';
    if (icon == Icons.palette_rounded) return 'art';
    if (icon == Icons.public_rounded) return 'geography';
    if (icon == Icons.psychology_rounded) return 'philosophy';
    return 'book';
  }

  static Color colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF3498DB);
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }

  static String colorToHex(Color c) =>
      '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}

class CourseMeta {
  final String objectif;
  final String langue;
  final bool hasTerminal;
  final bool hadDocuments;

  CourseMeta({
    required this.objectif,
    required this.langue,
    this.hasTerminal = false,
    this.hadDocuments = false,
  });

  Map<String, dynamic> toJson() => {
    'objectif': objectif,
    'langue': langue,
    'hasTerminal': hasTerminal,
    'hadDocuments': hadDocuments,
  };

  factory CourseMeta.fromJson(Map<String, dynamic> json) => CourseMeta(
    objectif: json['objectif'] as String? ?? 'comprehension',
    langue: json['langue'] as String? ?? 'fr',
    hasTerminal: json['hasTerminal'] as bool? ?? false,
    hadDocuments: json['hadDocuments'] as bool? ?? false,
  );
}

/// Données saisies dans l'assistant avant génération du prompt.
class CourseWizardInput {
  final String nom;
  final String description;
  final String objectif;
  final String langue;
  final bool hasDocuments;
  final String documentsText;
  final String niveau;
  final List<String> chapitres;
  final bool enableTerminal;
  final String matiereId;
  final int? durationMinutes;

  CourseWizardInput({
    required this.nom,
    required this.description,
    required this.objectif,
    required this.langue,
    required this.hasDocuments,
    required this.documentsText,
    required this.niveau,
    required this.chapitres,
    required this.enableTerminal,
    required this.matiereId,
    this.durationMinutes,
  });
}
