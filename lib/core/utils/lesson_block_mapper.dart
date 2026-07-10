import 'package:flutter/material.dart';
import 'course_context_mapper.dart';

enum LessonBlockType {
  introduction,
  definition,
  exemple,
  attention,
  concept,
  resume,
  code,
  question,
  info,
}

class LessonBlockStyle {
  final LessonBlockType type;
  final String svgAsset;
  final String label;

  const LessonBlockStyle({
    required this.type,
    required this.svgAsset,
    required this.label,
  });
}

/// Détecte le type de bloc depuis le titre de section et mappe vers un SVG.
/// Aucune métadonnée côté JSON — économie de tokens IA.
class LessonBlockMapper {
  static const _basePath = 'assets/icons/outline';

  static const _styles = <LessonBlockType, LessonBlockStyle>{
    LessonBlockType.introduction: LessonBlockStyle(
      type: LessonBlockType.introduction,
      svgAsset: '$_basePath/book.svg',
      label: 'Introduction',
    ),
    LessonBlockType.definition: LessonBlockStyle(
      type: LessonBlockType.definition,
      svgAsset: '$_basePath/bulb.svg',
      label: 'Définition',
    ),
    LessonBlockType.exemple: LessonBlockStyle(
      type: LessonBlockType.exemple,
      svgAsset: '$_basePath/flask.svg',
      label: 'Exemple',
    ),
    LessonBlockType.attention: LessonBlockStyle(
      type: LessonBlockType.attention,
      svgAsset: '$_basePath/alert-triangle.svg',
      label: 'Attention',
    ),
    LessonBlockType.concept: LessonBlockStyle(
      type: LessonBlockType.concept,
      svgAsset: '$_basePath/brain.svg',
      label: 'Concept',
    ),
    LessonBlockType.resume: LessonBlockStyle(
      type: LessonBlockType.resume,
      svgAsset: '$_basePath/checklist.svg',
      label: 'À retenir',
    ),
    LessonBlockType.code: LessonBlockStyle(
      type: LessonBlockType.code,
      svgAsset: '$_basePath/code.svg',
      label: 'Code',
    ),
    LessonBlockType.question: LessonBlockStyle(
      type: LessonBlockType.question,
      svgAsset: '$_basePath/puzzle.svg',
      label: 'Question',
    ),
    LessonBlockType.info: LessonBlockStyle(
      type: LessonBlockType.info,
      svgAsset: '$_basePath/info-circle.svg',
      label: 'Info',
    ),
  };

  static LessonBlockType detectType(String title) {
    final t = title.toLowerCase();

    if (_matches(t, [
      'définition',
      'definition',
      'qu\'est-ce',
      'quest-ce',
      'formelle',
      'formel',
    ])) {
      return LessonBlockType.definition;
    }
    if (_matches(t, [
      'exemple',
      'illustration',
      'analogie',
      'cas pratique',
      'application',
      'démonstration',
      'demonstration',
    ])) {
      return LessonBlockType.exemple;
    }
    if (_matches(t, [
      'attention',
      'danger',
      'erreur',
      'piège',
      'piege',
      'warning',
      'prudence',
    ])) {
      return LessonBlockType.attention;
    }
    if (_matches(t, [
      'résumé',
      'resume',
      'retenir',
      'conclusion',
      'synthèse',
      'synthese',
      'fin',
      'rappel',
    ])) {
      return LessonBlockType.resume;
    }
    if (_matches(t, [
      'syntaxe',
      'code',
      'variable',
      'boucle',
      'fonction',
      'algorithme',
      'structure',
      'entrée',
      'entree',
      'sortie',
    ])) {
      return LessonBlockType.code;
    }
    if (_matches(t, [
      'exercice',
      'défi',
      'defi',
      'question',
      'entrainement',
      'entraînement',
    ])) {
      return LessonBlockType.question;
    }
    if (_matches(t, ['concept', 'notion', 'principe', 'idée', 'idee', 'propriété'])) {
      return LessonBlockType.concept;
    }
    if (_matches(t, ['introduction', 'présentation', 'presentation', 'aperçu'])) {
      return LessonBlockType.introduction;
    }
    return LessonBlockType.info;
  }

  static LessonBlockStyle styleFor(String title) =>
      _styles[detectType(title)] ?? _styles[LessonBlockType.info]!;

  /// Couleur du bloc : teinte contexte + nuance selon le type.
  static Color colorFor(String? contexte, LessonBlockType type) {
    final base = CourseContextMapper.getColorForContext(contexte);
    return switch (type) {
      LessonBlockType.attention => Color.lerp(base, Colors.orange, 0.45)!,
      LessonBlockType.exemple => Color.lerp(base, Colors.teal, 0.25)!,
      LessonBlockType.definition => Color.lerp(base, Colors.amber, 0.2)!,
      LessonBlockType.resume => Color.lerp(base, Colors.indigo, 0.15)!,
      LessonBlockType.code => Color.lerp(base, const Color(0xFF2ECC71), 0.3)!,
      _ => base,
    };
  }

  static bool _matches(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));
}
