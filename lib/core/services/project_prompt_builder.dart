import '../models/custom_course_package.dart';
import 'course_prompt_builder.dart';

/// Construit les prompts IA pour la fonctionnalité Projets.
class ProjectPromptBuilder {
  /// Génère le prompt pour que l'IA produise le programme d'un projet
  /// (liste de matières ordonnées + icône et couleur suggérées).
  static String buildProgramPrompt({
    required String nom,
    String? objectif,
    String langue = 'fr',
  }) {
    final isFr = langue == 'fr';
    final objBlock = (objectif ?? '').trim().isEmpty
        ? (isFr
              ? 'Pas d\'objectif précisé : détermine un programme cohérent à partir du nom du projet.'
              : 'No objective specified: determine a coherent program from the project name.')
        : (isFr ? 'Objectif : $objectif' : 'Objective: $objectif');

    if (isFr) {
      return '''# RÔLE
Tu es un expert en ingénierie pédagogique. Tu dois produire UNIQUEMENT un objet JSON valide (pas de markdown, pas de texte autour).

# MISSION
Génère le programme d'études pour le projet : "$nom".
$objBlock

# CONSIGNES
1. Propose entre 3 et 8 matières/cours qui forment un programme complet et progressif.
2. Chaque matière doit avoir un nom clair et une description courte (1-2 phrases).
3. Ordonne les matières du plus fondamental au plus avancé.
4. Choisis une icône parmi : rocket, brain, target, network, lab, chart, globe, shield, build, library, spark, school, code, art, music, health, finance, star
5. Choisis une couleur hexadécimale qui correspond à la thématique du projet.
6. Pour chaque matière, estime le temps moyen d'étude nécessaire en minutes (champ "tempsMinutes", entier, typiquement entre 60 et 300 selon la complexité).

# FORMAT JSON OBLIGATOIRE
{
  "icone": "network",
  "couleur": "#3498DB",
  "matieres": [
    { "nom": "Nom de la matière", "description": "Description courte.", "ordre": 1, "tempsMinutes": 90 },
    { "nom": "...", "description": "...", "ordre": 2, "tempsMinutes": 120 }
  ]
}

Génère maintenant le programme JSON pour le projet "$nom".''';
    }

    return '''# ROLE
You are an expert in educational engineering writing EXCLUSIVELY IN ENGLISH. All generated content — subject names, descriptions — MUST be in English regardless of the project name or description language.

# MISSION
Generate the study program for the project: "$nom".
$objBlock

# RULES
1. Propose between 3 and 8 subjects that form a complete and progressive program.
2. Each subject must have a clear name and a short description (1-2 sentences).
3. Order subjects from most foundational to most advanced.
4. Choose an icon from: rocket, brain, target, network, lab, chart, globe, shield, build, library, spark, school, code, art, music, health, finance, star
5. Choose a hexadecimal color that matches the project theme.
6. For each subject, estimate the average study time needed in minutes (field "tempsMinutes", integer, typically between 60 and 300 depending on complexity).
7. ⚠️ ALL subject names and descriptions MUST be written in ENGLISH.

# REQUIRED JSON FORMAT
{
  "icone": "network",
  "couleur": "#3498DB",
  "matieres": [
    { "nom": "Subject name", "description": "Short description.", "ordre": 1, "tempsMinutes": 90 },
    { "nom": "...", "description": "...", "ordre": 2, "tempsMinutes": 120 }
  ]
}

Generate the JSON program for the project "$nom" now. ALL content in ENGLISH.''';
  }

  /// Génère le prompt complet pour créer un cours à partir d'un sujet de projet.
  /// Réutilise [CoursePromptBuilder.build] avec les paramètres du sujet.
  static String buildCourseFromSubjectPrompt({
    required String sujetNom,
    required String sujetDescription,
    String? projetObjectif,
    String? projetNom,
    required String matiereId,
    String langue = 'fr',
    bool enableTerminal = false,
    int? durationMinutes,
  }) {
    final input = CourseWizardInput(
      nom: sujetNom,
      description: sujetDescription.isNotEmpty
          ? sujetDescription
          : (projetNom != null
                ? 'Cours faisant partie du projet "$projetNom"'
                : ''),
      objectif: 'comprehension',
      langue: langue,
      hasDocuments: false,
      documentsText: '',
      niveau: '', // auto → progression débutant → avancé
      chapitres: [],
      enableTerminal: enableTerminal,
      matiereId: matiereId,
      durationMinutes: durationMinutes,
    );
    return CoursePromptBuilder.build(input);
  }
}
