class Score {
  final int? id;
  final String matiereId;
  final String notionId;
  final String exerciceId;
  final int score;
  final int total;
  final double pourcentage;
  final DateTime dateTentative;
  final int tentativeNum;

  Score({
    this.id,
    required this.matiereId,
    required this.notionId,
    required this.exerciceId,
    required this.score,
    required this.total,
    required this.pourcentage,
    required this.dateTentative,
    required this.tentativeNum,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'matiere_id': matiereId,
      'notion_id': notionId,
      'exercice_id': exerciceId,
      'score': score,
      'total': total,
      'pourcentage': pourcentage,
      'date_tentative': dateTentative.toIso8601String(),
      'tentative_num': tentativeNum,
    };
  }

  factory Score.fromMap(Map<String, dynamic> map) {
    return Score(
      id: map['id'],
      matiereId: map['matiere_id'],
      notionId: map['notion_id'],
      exerciceId: map['exercice_id'],
      score: map['score'],
      total: map['total'],
      pourcentage: map['pourcentage'],
      dateTentative: DateTime.parse(map['date_tentative']),
      tentativeNum: map['tentative_num'],
    );
  }
}
