class Progression {
  final int? id;
  final String matiereId;
  final String notionId;
  final String statut; // 'non_commence', 'en_cours', 'termine'
  final int nbExercicesReussis;
  final int nbExercicesTotal;
  final DateTime? derniereActivite;

  Progression({
    this.id,
    required this.matiereId,
    required this.notionId,
    required this.statut,
    this.nbExercicesReussis = 0,
    this.nbExercicesTotal = 0,
    this.derniereActivite,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'matiere_id': matiereId,
      'notion_id': notionId,
      'statut': statut,
      'nb_exercices_reussis': nbExercicesReussis,
      'nb_exercices_total': nbExercicesTotal,
      'derniere_activite': derniereActivite?.toIso8601String(),
    };
  }

  factory Progression.fromMap(Map<String, dynamic> map) {
    return Progression(
      id: map['id'],
      matiereId: map['matiere_id'],
      notionId: map['notion_id'],
      statut: map['statut'],
      nbExercicesReussis: map['nb_exercices_reussis'] ?? 0,
      nbExercicesTotal: map['nb_exercices_total'] ?? 0,
      derniereActivite: map['derniere_activite'] != null ? DateTime.parse(map['derniere_activite']) : null,
    );
  }
}
