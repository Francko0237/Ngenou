enum TypeExercice { qcm, qro, editeur }

class Exercice {
  final String id;
  final String notionId;
  final TypeExercice type;
  final String question;
  final List<String> options; 
  final int bonneReponseIndex;
  final String? explication;
  final String? codeSnippet;
  final String? codeInitial;
  /// Réponse attendue pour les exercices QRO.
  final String? reponseAttendue;

  Exercice({
    required this.id,
    required this.notionId,
    this.type = TypeExercice.qcm,
    required this.question,
    this.explication,
    List<String>? choixQcm,
    List<String>? options,
    int? bonneReponseIndex,
    this.codeSnippet,
    this.codeInitial,
    this.reponseAttendue,
  }) : options = options ?? choixQcm ?? [],
       bonneReponseIndex = bonneReponseIndex ?? 
           (choixQcm != null && reponseAttendue != null ? choixQcm.indexOf(reponseAttendue) : 0);
}
