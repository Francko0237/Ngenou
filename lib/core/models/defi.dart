class DefiTest {
  final List<String> inputs;
  final String expectedOutput;

  DefiTest({required this.inputs, required this.expectedOutput});
}

class Defi {
  final String id;
  final String matiereId;
  final String titre;
  final String description;
  final String codeInitial;
  final List<DefiTest> tests;

  Defi({
    required this.id,
    required this.matiereId,
    required this.titre,
    required this.description,
    required this.codeInitial,
    required this.tests,
  });
}
