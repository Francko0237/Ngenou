class Progression {
  final int? id;
  final String matiereId;
  final String notionId;
  final String statut; // 'non_commence', 'en_cours', 'termine'
  final int nbExercicesReussis;
  final int nbExercicesTotal;
  final double progressionLecture; // Entre 0.0 et 1.0 (ex: 0.25 pour 25%)
  final int lastSectionIndex;
  final int lastLessonIndex;
  final DateTime? derniereActivite;

  Progression({
    this.id,
    required this.matiereId,
    required this.notionId,
    required this.statut,
    this.nbExercicesReussis = 0,
    this.nbExercicesTotal = 0,
    this.progressionLecture = 0.0,
    this.lastSectionIndex = 0,
    this.lastLessonIndex = 0,
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
      'progression_lecture': progressionLecture,
      'last_section_index': lastSectionIndex,
      'last_lesson_index': lastLessonIndex,
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
      progressionLecture: (map['progression_lecture'] as num?)?.toDouble() ??
          (map['statut'] == 'termine' ? 1.0 : 0.0),
      lastSectionIndex: (map['last_section_index'] as num?)?.toInt() ?? 0,
      lastLessonIndex: (map['last_lesson_index'] as num?)?.toInt() ?? 0,
      derniereActivite: map['derniere_activite'] != null
          ? DateTime.parse(map['derniere_activite'])
          : null,
    );
  }
}
