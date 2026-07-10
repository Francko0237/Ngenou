class Lecon {
  final String id;
  final String notionId;
  final String titre;
  final String contenu;
  final String? explicationDetaillee;

  Lecon({
    required this.id,
    required this.notionId,
    required this.titre,
    required this.contenu,
    this.explicationDetaillee,
  });
}
