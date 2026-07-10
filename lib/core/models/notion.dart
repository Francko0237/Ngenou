enum NiveauNotion { debutant, intermediaire, avance }

class Notion {
  final String id;
  final String matiereId;
  final String titre;
  final NiveauNotion niveau;
  final String description;
  final String? section;

  /// Contexte du cours pour l'affichage d'icônes/images adaptées
  /// Ex: "informatique", "code", "droit", "math", "science", "histoire", etc.
  final String? contexte;

  Notion({
    required this.id,
    required this.matiereId,
    required this.titre,
    required this.niveau,
    required this.description,
    this.section,
    this.contexte,
  });
}
