import '../models/custom_course_package.dart';

class CoursePromptBuilder {
  static String build(CourseWizardInput input) {
    final isFr = input.langue == 'fr';
    final objectifBlock = _objectifInstructions(input.objectif, isFr);
    final terminalNote = input.enableTerminal
        ? (isFr
              ? '- Autoriser des exercices type "editeur" (pseudo-code algorithmique avec codeInitial).'
              : '- Allow "editeur" exercises (algorithmic pseudo-code with codeInitial).')
        : (isFr
              ? '- INTERDIT : type "editeur". Utiliser uniquement des QCM ("qcm").'
              : '- FORBIDDEN: "editeur" type. Use only "qcm".');

    final durationInstruction = input.durationMinutes != null
        ? (isFr
              ? '- Utilise EXACTEMENT la valeur ${input.durationMinutes} pour le champ "matiere.durationMinutes".'
              : '- Use EXACTLY the value ${input.durationMinutes} for the "matiere.durationMinutes" field.')
        : (isFr
              ? '- Estime la durée moyenne nécessaire pour étudier ce cours complet en minutes (champ "matiere.durationMinutes", sous forme d\'un entier, typiquement entre 60 et 300 selon la complexité et le nombre de chapitres).'
              : '- Estimate the average duration required to study this complete course in minutes (field "matiere.durationMinutes", as an integer, typically between 60 and 300 depending on complexity and number of chapters).');

    final chapitresBlock = input.chapitres.isEmpty
        ? (isFr
              ? 'Aucun chapitre précisé : propose un plan de chapitres cohérent à partir du titre, de la description et du niveau du cours.'
              : 'No chapters specified: propose a coherent chapter plan from the course title, description and level.')
        : (isFr
              ? 'Utilise EXACTEMENT ces chapitres (notions), dans cet ordre :\n${input.chapitres.map((c) => '- $c').join('\n')}'
              : 'Use EXACTLY these chapters (notions), in this order:\n${input.chapitres.map((c) => '- $c').join('\n')}');

    final niveauBlock = input.niveau.trim().isEmpty
        ? (isFr
              ? 'Niveau non précisé (Auto) : Les notions doivent suivre une progression pédagogique linéaire et croissante en difficulté. Configure la ou les premières notions au niveau "debutant", puis les suivantes au niveau "intermediaire", et les dernières notions au niveau "avance" afin de suivre la progression de l\'apprenant.'
              : 'Level not specified (Auto): The notions must follow a linear and increasing pedagogical progression in difficulty. Set the first notion(s) to "debutant" (beginner) level, then the middle notion(s) to "intermediaire" (intermediate), and the final notion(s) to "avance" (advanced) to match the learner\'s progression.')
        : (isFr
              ? 'Niveau cible du cours : "${input.niveau}". Applique ce niveau à toutes les notions (notion.niveau), sauf si une progression interne justifie une montée en difficulté.'
              : 'Target course level: "${input.niveau}". Apply this level to all notions (notion.niveau), unless internal progression justifies increasing difficulty.');

    final docsBlock = input.hasDocuments
        ? (isFr
              ? '''### Documents de référence (Numérisation OCR)
    ATTENTION : Ce document a été extrait par un outil de numérisation (OCR) et peut contenir des erreurs de lecture, des mots mal orthographiés, ou une mise en forme imparfaite. 
    Fais preuve de tolérance, corrige implicitement le sens des phrases erronées et extrais-en les concepts clés pour construire le cours.
    ----------------
    ${input.documentsText.isEmpty ? '(aucun extrait collé — structure à partir du titre et de la description)' : input.documentsText}
    ----------------'''
              : '''### Reference documents (OCR Scan)
    WARNING: This document was extracted via OCR and may contain reading errors, misspelled words, or imperfect formatting.
    Be tolerant, implicitly correct the meaning of erroneous sentences, and extract the key concepts to build the course.
    ----------------
    ${input.documentsText.isEmpty ? '(no excerpt pasted — structure from title and description)' : input.documentsText}
    ----------------''')
        : (isFr
              ? '''### Pas de documents fournis
    Base-toi sur le titre, la description et l'objectif pédagogique du cours.'''
              : '''### No documents provided
    Rely on the course title, description and learning goal.''');

    if (isFr) {
      return '''# RÔLE
Tu es un auteur pédagogique expert. Tu dois produire UNIQUEMENT un fichier JSON valide pour l'application Ngenou (import direct, sans texte autour).

# CONSIGNES ABSOLUES
1. Réponds avec UN SEUL objet JSON brut. Pas de markdown, pas de ```json, pas de commentaire avant/après.
2. Respecte EXACTEMENT le schéma et les noms de champs ci-dessous (casse sensible).
3. Tous les id doivent être uniques (snake_case ou camelCase cohérent).
4. matiere.id DOIT commencer par "custom_" : utilise "${input.matiereId}".
5. Chaque notion doit avoir au moins 2 leçons et au moins 3 exercices.
6. $terminalNote
7. $durationInstruction
8. Langue du contenu (titres, leçons, questions) : français.
9. CRITIQUE — ÉCHAPPEMENT JSON : toutes les valeurs de chaînes JSON sont entre guillemets doubles. Par conséquent, tout guillemet double DANS une valeur DOIT être échappé avec un antislash : \\" et jamais ". Les sauts de ligne dans les valeurs doivent aussi être écrits \\n et non pas une vraie nouvelle ligne. Si tu mets un guillemet non échappé dans une valeur, le JSON est invalide et l'application plantera.

# OBJECTIF PÉDAGOGIQUE
$objectifBlock

# INFORMATIONS DU COURS
- Nom : ${input.nom}
- Description : ${input.description}

$docsBlock

# NIVEAU DU COURS
$niveauBlock

# STRUCTURE DES CHAPITRES
$chapitresBlock

# SCHÉMA JSON OBLIGATOIRE (schemaVersion "1.0")
{
  "schemaVersion": "1.0",
  "meta": {
    "objectif": "${input.objectif}",
    "langue": "fr",
    "hasTerminal": ${input.enableTerminal},
    "hadDocuments": ${input.hasDocuments}
  },
  "matiere": {
    "id": "${input.matiereId}",
    "nom": "${_escape(input.nom)}",
    "description": "${_escape(input.description)}",
    "icone": "book",
    "couleur": "#3498DB",
    "durationMinutes": ${input.durationMinutes ?? 120}
  },
  "notions": [
    {
      "id": "n1",
      "titre": "Titre du chapitre",
      "niveau": "debutant",
      "description": "Résumé court",
      "section": "Optionnel — regroupement",
      "contexte": "informatique|code|droit|math|science|histoire|langue|economie|art|sante|geographie|philosophie|physique|chimie|biologie"
    }
  ],
  "lecons": [
    {
      "id": "l1",
      "notionId": "n1",
      "titre": "Titre leçon",
      "contenu": "### Définition\\nTexte court.\\n\\n### Exemple\\nIllustration concrète.",
      "explicationDetaillee": "OBLIGATOIRE — Analogie concrète très détaillée de la vie quotidienne pour illustrer le concept de la leçon de manière extrêmement simple et accessible pour un débutant complet qui part de zéro. Ne pas faire court."
    }
  ],
  "exercices": [
    {
      "id": "e1",
      "notionId": "n1",
      "type": "qcm",
      "question": "Question ?",
      "options": ["A", "B", "C", "D"],
      "bonneReponseIndex": 0,
      "explication": "Pourquoi cette réponse"
    }
  ]
}

# TYPES D'EXERCICES (UNIQUEMENT)
- "qcm" : options (min 2, max 4), bonneReponseIndex (entier 0-based), explication
- "editeur" : UNIQUEMENT si hasTerminal=true — codeInitial (pseudo-code Algo), explication

# IMPORTANT : PAS DE QRO
Ne JAMAIS créer d'exercices de type "qro" (question à réponse ouverte). L'application ne peut pas vérifier automatiquement les réponses textuelles libres. Utilise UNIQUEMENT des QCM pour toutes les questions.

# ICÔNES DE COURS (matiere.icone) (TRÈS IMPORTANT)
Choisis et remplace la valeur par défaut "book" du champ "matiere.icone" par l'une des clés suivantes selon la thématique du cours :
- "code" : programmation, développement, algorithmes
- "computer" : informatique, systèmes, réseaux
- "science" : sciences, médecine, chimie, physique
- "history" : histoire, archéologie
- "language" : langues, littérature, traduction
- "math" : mathématiques, statistiques, calculs
- "law" : droit, justice, lois
- "eco" : écologie, agriculture, nature, biologie, animaux
- "food" : cuisine, nutrition, nourriture, alimentation
- "sewing" : couture, mode, stylisme, vêtements
- "sport" : sport, fitness, danse
- "finance" : économie, finance, commerce, gestion
- "art" : musique, dessin, peinture, design
- "geography" : géographie, géologie
- "philosophy" : philosophie, psychologie
- "book" : par défaut (si aucun autre ne convient)

# NIVEAUX notion.niveau
"debutant" | "intermediaire" | "avance"

# CONTEXTE notion.contexte (IMPORTANT)
Chaque notion DOIT avoir un champ "contexte" qui indique le domaine principal pour l'affichage d'icônes adaptées.
Choisis UN SEUL contexte parmi : "informatique", "code", "droit", "math", "science", "histoire", "langue", "economie", "art", "sante", "geographie", "philosophie", "physique", "chimie", "biologie"
- "informatique" : cours sur les ordinateurs, réseaux, systèmes
- "code" : programmation, développement, algorithmes
- "droit" : lois, juridique, justice
- "math" : mathématiques, calcul
- "science" : sciences générales
- "histoire" : histoire, civilisations
- "langue" : littérature, grammaire, langues étrangères
- "economie" : économie, finance, gestion
- "art" : arts plastiques, musique, culture artistique
- "sante" : médecine, santé, biologie humaine
- "geographie" : géographie, géopolitique
- "philosophie" : philosophie, pensée critique
- "physique" : physique, mécanique, électricité
- "chimie" : chimie, réactions, molécules
- "biologie" : biologie, nature, écosystèmes

# FORMAT DU CONTENU (lecons[].contenu) — AFFICHAGE INTERACTIF DANS L'APPLICATION
L'app découpe chaque leçon en sections scrollables (1 concept = 1 écran). Structure OBLIGATOIRE avec des titres ### :
- ### Définition / ### Concept / ### Qu'est-ce que... (introduire une notion)
- ### Exemple / ### Illustration / ### Cas pratique (exemples concrets)
- ### Attention / ### Erreur fréquente / ### Piège (mises en garde)
- ### À retenir / ### Résumé / ### Conclusion (synthèse)
- ### Syntaxe / ### Code (si pertinent)

## Règles de rédaction du contenu pour l'APP :
- Chaque leçon : 2 à 4 sections ### minimum.
- CHAQUE concept introduit doit être expliqué en plain texte, phrase par phrase, de manière progressive. Ne jamais supposer que le lecteur sait déjà quoi que ce soit.
- CHAQUE exemple de code (dans une section ### Code, ### Syntaxe ou ### Exemple) doit avoir CHAQUE ligne commentée avec `// explication de cette ligne` directement dans le bloc de code. Si le pseudo-code ou le langage ne supporte pas //, utilise le signe de commentaire adéquat ou ajoute une ligne de texte juste en-dessous de chaque ligne de code qui explique ce qu'elle fait.
- 5 à 8 lignes d'explication par section ###.
- Info bonus (tap pour révéler) : utiliser "> ? Titre court" puis lignes "> contenu..." pour des anecdotes ou approfondissements.
- NE PAS ajouter de champs icône/couleur dans le JSON.
- Exemple de contenu CORRECT :
  "### Concept\\nUne **variable**, c'est comme une boîte étiquetée. Tu mets dedans un nombre, une lettre ou un mot. Quand tu veux retrouver ce que tu as mis dans la boîte, tu appelles la boîte par son nom.\\nEn pseudo-code, on crée une variable comme ceci :\\n\\n### Code\\n```\\nVar age : Entier  // On déclare une variable appelée 'age' qui contiendra un nombre entier\\nage ← 25         // On place la valeur 25 dans la variable 'age'\\nEcrire(age)      // On affiche le contenu de la variable 'age' à l'écran\\n```\\nLigne 1 : On réserve un espace mémoire nommé 'age'. C'est comme écrire un nom sur une boîte vide.\\nLigne 2 : On met 25 dans cette boîte.\\nLigne 3 : On demande à l'ordinateur d'afficher ce qui est dans la boîte."

# FORMAT DE L'EXPLICATION DÉTAILLÉE (lecons[].explicationDetaillee) — VERSION PDF COMPLÈTE
Ce champ est OBLIGATOIRE pour toutes les leçons. C'est la version enrichie pour le PDF imprimé, conçue pour être lue de manière autonome par quelqu'un qui apprend seul de zéro.

Doit contenir :
1. Une **analogie de la vie quotidienne** en 3 à 5 phrases : expliquer le concept avec quelque chose de très concret et familier (ménage, cuisine, transport, etc.).
2. Un **décryptage ligne par ligne** de chaque exemple de code présent dans `contenu` : reprendre chaque ligne du code et décrire en détail ce qu'elle fait, pourquoi on l'écrit, et ce qui se passerait si on la changeait.
3. Les **pièges courants** pour un débutant sur ce concept : quelles erreurs font 90% des apprenants et comment les éviter.
4. Un **conseil de mémorisation** : une phrase ou astuce pour ancrer le concept durablement.

6 à 10 phrases. Ne pas faire court. Ce champ doit être l'équivalent d'une page de cours complète.

# VÉRIFICATION FINALE (avant de répondre)
- JSON parseable
- Tous les notionId des lecons/exercices existent dans notions
- Aucun champ inventé hors schéma
- Chaque exemple de code a TOUTES ses lignes commentées dans `contenu`
- Chaque `explicationDetaillee` contient analogie + décryptage code + pièges + conseil
- Contenu adapté à l'objectif : $objectifBlock

Génère maintenant le JSON complet du cours.''';
    }

    return '''# ROLE
You are an expert educational author writing EXCLUSIVELY IN ENGLISH. Every single word of content you generate — titles, lesson text, exercise questions, explanations, section headings — MUST be written in English. This is a strict requirement that overrides all other considerations including the language of the course name or description provided.

# ABSOLUTE RULES
1. Reply with ONE raw JSON object only. No markdown, no ```json, no comments before/after.
2. Follow EXACTLY the schema and field names below (case-sensitive).
3. All ids must be unique.
4. matiere.id MUST start with "custom_": use "${input.matiereId}".
5. Each notion needs at least 2 lessons and at least 3 exercises.
6. $terminalNote
7. $durationInstruction
8. ⚠️ LANGUAGE: ALL content (titles, lesson text, questions, explanations, section headings) MUST be written in ENGLISH. Even if the course name or description is in French, write all generated content in English.
9. CRITICAL — JSON ESCAPING: all JSON string values are delimited by double quotes. Therefore any double quote INSIDE a value MUST be escaped with a backslash: \\" and never ". Newlines inside values must also be written \\n and never as a real newline. An unescaped double quote inside a value makes the JSON invalid and the app will crash.

# LEARNING GOAL
$objectifBlock

# COURSE INFO
- Name: ${input.nom}
- Description: ${input.description}

$docsBlock

# COURSE LEVEL
$niveauBlock

# CHAPTER STRUCTURE
$chapitresBlock

# REQUIRED JSON SCHEMA (schemaVersion "1.0")
{
  "schemaVersion": "1.0",
  "meta": {
    "objectif": "${input.objectif}",
    "langue": "en",
    "hasTerminal": ${input.enableTerminal},
    "hadDocuments": ${input.hasDocuments}
  },
  "matiere": {
    "id": "${input.matiereId}",
    "nom": "${_escape(input.nom)}",
    "description": "${_escape(input.description)}",
    "icone": "book",
    "couleur": "#3498DB",
    "durationMinutes": ${input.durationMinutes ?? 120}
  },
  "notions": [
    {
      "id": "n1",
      "titre": "Chapter title",
      "niveau": "debutant",
      "description": "Short summary",
      "section": "Optional — grouping",
      "contexte": "informatique|code|droit|math|science|histoire|langue|economie|art|sante|geographie|philosophie|physique|chimie|biologie"
    }
  ],
  "lecons": [
    {
      "id": "l1",
      "notionId": "n1",
      "titre": "Lesson title",
      "contenu": "### Definition\\nShort text.\\n\\n### Example\\nConcrete illustration.",
      "explicationDetaillee": "MANDATORY — Detailed real-life analogy explaining the concept in an extremely simple and accessible way for a complete beginner starting from zero. Do not make it short."
    }
  ],
  "exercices": [
    {
      "id": "e1",
      "notionId": "n1",
      "type": "qcm",
      "question": "Question?",
      "options": ["A", "B", "C", "D"],
      "bonneReponseIndex": 0,
      "explication": "Why this answer"
    }
  ]
}

# EXERCISE TYPES (ONLY)
- "qcm": options (min 2, max 4), bonneReponseIndex (0-based int), explication
- "editeur": ONLY if hasTerminal=true — codeInitial (algorithmic pseudo-code), explication

# NO QRO
NEVER create exercises of type "qro". The app cannot automatically check free-text answers. Use ONLY "qcm" for all questions.
# COURSE ICON (matiere.icone) (VERY IMPORTANT)
Choose and replace the default "book" value of the "matiere.icone" field with one of these keys according to the course theme:
- "code": coding, programming, algorithms
- "computer": IT, computer networks, systems
- "science": sciences, medicine, physics, chemistry
- "history": history, civilizations
- "language": languages, translation, literature
- "math": math, algebra, geometry
- "law": law, justice, legal
- "eco": ecology, agriculture, nature, biology, animals
- "food": cooking, nutrition, food
- "sewing": sewing, fashion, tailoring
- "sport": sports, fitness, dance
- "finance": economy, finance, business
- "art": music, arts, painting, design
- "geography": geography, geology
- "philosophy": philosophy, psychology
- "book": default/other

# CONTEXT notion.contexte (IMPORTANT)
Each notion MUST have a "contexte" field indicating the main domain for displaying appropriate icons.
Choose ONE context from: "informatique", "code", "droit", "math", "science", "histoire", "langue", "economie", "art", "sante", "geographie", "philosophie", "physique", "chimie", "biologie"
- "informatique": computers, networks, systems
- "code": programming, development, algorithms
- "droit": laws, legal, justice
- "math": mathematics, calculus
- "science": general science
- "histoire": history, civilizations
- "langue": literature, grammar, foreign languages
- "economie": economics, finance, management
- "art": visual arts, music, artistic culture
- "sante": medicine, health, human biology
- "geographie": geography, geopolitics
- "philosophie": philosophy, critical thinking
- "physique": physics, mechanics, electricity
- "chimie": chemistry, reactions, molecules
- "biologie": biology, nature, ecosystems

# LESSON CONTENT FORMAT (lecons[].contenu) — INTERACTIVE IN-APP DISPLAY
The app splits each lesson into scrollable sections (1 concept = 1 screen). MANDATORY structure with ### headings:
- ### Definition / ### Concept / ### What is... (introduce a notion)
- ### Example / ### Illustration / ### Case study (concrete examples)
- ### Warning / ### Common mistake / ### Pitfall (cautions)
- ### Key points / ### Summary / ### Conclusion (synthesis)
- ### Syntax / ### Code (if relevant)

## Writing rules for the APP content:
- Each lesson: 2-4 ### sections minimum.
- EVERY concept introduced must be explained sentence by sentence, progressively. Never assume the reader knows anything.
- EVERY code example (in a ### Code, ### Syntax or ### Example section) must have EVERY line commented with `// explanation of this line` directly inside the code block. If the language does not support //, use the appropriate comment syntax or add an explanatory line of text directly below each code line.
- 5 to 8 lines of explanation per ### section.
- Bonus info (tap to reveal): use "> ? Short title" then "> content..." lines for anecdotes or deep dives.
- Do NOT add icon/color fields in JSON.

# DETAILED EXPLANATION FORMAT (lecons[].explicationDetaillee) — FULL PDF VERSION
This field is MANDATORY for all lessons. It is the enriched version for the printed PDF, designed to be read standalone by someone learning from zero.

Must contain:
1. A **real-life analogy** in 3-5 sentences: explain the concept using something very concrete and familiar (household, cooking, transport, etc.).
2. A **line-by-line breakdown** of every code example from `contenu`: restate each line and describe in detail what it does, why we write it, and what would happen if we changed it.
3. **Common beginner pitfalls** for this concept: which mistakes 90% of learners make and how to avoid them.
4. A **memorization tip**: a phrase or trick to anchor the concept durably.

6 to 10 sentences. Do not make it short. This field should be the equivalent of one full page of a textbook.

Generate the complete course JSON now. REMEMBER: ALL text content must be in ENGLISH.''';
  }

  static String _objectifInstructions(String objectif, bool isFr) {
    switch (objectif) {
      case 'revision':
        return isFr
            ? 'RÉVISION : leçons courtes, fiches synthèse, beaucoup de QCM de rappel, peu de digressions.'
            : 'REVISION: short lessons, summary sheets, many recall QCM, few digressions.';
      case 'culture':
        return isFr
            ? 'CULTURE : leçons enrichissantes, anecdotes, liens interdisciplinaires, exercices plus légers.'
            : 'CULTURE: enriching lessons, anecdotes, cross-links, lighter exercises.';
      default:
        return isFr
            ? 'COMPRÉHENSION TERRAIN : progression du simple au complexe, exemples concrets, exercices gradués.'
            : 'GROUND-UP UNDERSTANDING: simple to complex, concrete examples, graded exercises.';
    }
  }

  static String _escape(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\n', '\\n');
}
