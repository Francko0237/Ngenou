import 'dart:convert';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/daily_challenge.dart';
import '../models/deep_seek_model.dart';
import '../services/deep_seek_service.dart';
import '../utils/error_formatter.dart';
import '../../modules/modules_registry.dart';
import '../services/home_widget_service.dart';

class DefisProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  DailyChallengeSession? _todaySession;
  List<DailyChallengeSession> _history = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _statsSummary = 'Aucun défi quotidien relevé pour le moment.';

  DailyChallengeSession? get todaySession => _todaySession;
  List<DailyChallengeSession> get history => _history;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get statsSummary => _statsSummary;

  /// Charge la session du jour et l'historique complet.
  Future<void> loadTodaySession() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      _todaySession = await _db.getDailyChallengeSessionForDate(todayStr);
      await loadHistoryAndStats();
    } catch (e) {
      _errorMessage = "Erreur lors du chargement : ${formatUserError(e)}";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charge l'historique et recalcule le résumé statistique ultra-compact.
  Future<void> loadHistoryAndStats() async {
    _history = await _db.getAllDailyChallengeSessions();
    _statsSummary = await _db.getDailyChallengesStatsSummary();
  }

  /// Génère une nouvelle session de défis pour aujourd'hui.
  Future<void> generateTodaySession({
    required bool inclutAlgo,
    DeepSeekModel model = DeepSeekModel.flash,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final matieres = ModulesRegistry.matieres;
      if (matieres.isEmpty) {
        throw Exception("Aucune matière disponible pour générer des défis.");
      }

      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      final matieresStr = matieres
          .map((m) => "- ID: '${m.id}', Nom: '${m.nom}'")
          .join('\n');

      final prompt =
          '''
Génère une série de défis quotidiens d'apprentissage pour la date $dateStr.
Les matières actives de l'utilisateur sont :
$matieresStr

CONSIGNES DE GÉNÉRATION :
1. Génère entre 4 et 6 questions de type QCM réparties équitablement sur les matières.
2. ${inclutAlgo ? 'Génère exactement 1 exercice d\'algorithme en pseudocode français (type: "algo").' : 'Ne génère aucun exercice d\'algorithme (uniquement des QCM).'}
3. Le format de sortie doit être un objet JSON valide avec une clé "challenges".
4. Retourne UNIQUEMENT le JSON brut, sans bloc markdown.

RÈGLES ABSOLUES POUR L'EXERCICE ALGORITHME :
- Utilise UNIQUEMENT l'opérateur <- (flèche gauche) pour l'affectation. JAMAIS := ni = pour affecter.
- Exemple correct : x <- 3    Exemple INTERDIT : x := 3    Exemple INTERDIT : x = 3
- Le pseudocode doit suivre cette syntaxe : Algorithme, Var, Debut, Fin, Lire, Ecrire, Si/Alors/Sinon/FinSi, Pour/FinPour, Tant que/FinTantQue.
- L'énoncé (explication) doit être très clair, simple, avec des exemples concrets d'entrée et de sortie.
- L'exercice doit être faisable par un débutant en 5 minutes maximum.

STRUCTURE QCM (type: "qcm") :
{
  "id": "defi_qcm_1",
  "type": "qcm",
  "matiereId": "ID_de_la_matière",
  "matiereNom": "Nom_de_la_matière",
  "question": "Énoncé de la question ?",
  "options": ["Option A", "Option B", "Option C", "Option D"],
  "bonneReponseIndex": 0,
  "explication": "Explication pédagogique claire de la bonne réponse."
}

STRUCTURE ALGORITHME (type: "algo") :
{
  "id": "defi_algo_1",
  "type": "algo",
  "matiereId": "algo",
  "matiereNom": "Algorithmique",
  "question": "Titre court (ex: Calcul de la moyenne)",
  "explication": "Énoncé clair en 3 parties :\\n1. CE QUE LE PROGRAMME DOIT FAIRE (1 phrase simple)\\n2. ENTRÉES : décris chaque variable lue (ex: Lire n — un entier positif)\\n3. SORTIE : ce qu'Ecrire doit afficher (ex: Ecrire la somme)\\n\\nEXEMPLE :\\nEntrée : n = 3, valeurs = 10, 20, 30\\nSortie attendue : 60",
  "codeInitial": "Algorithme NomDuDéfi;\\nVar\\n   \\nDebut\\n   \\nFin",
  "codeSolution": "Algorithme NomDuDéfi;\\nVar\\n   n, i, somme : Entier;\\nDebut\\n   somme <- 0;\\n   Lire(n);\\n   Pour i <- 1 a n Faire\\n      Lire(valeur);\\n      somme <- somme + valeur;\\n   FinPour;\\n   Ecrire(somme);\\nFin",
  "algoTests": [
    {
      "inputs": ["3", "10", "20", "30"],
      "expectedOutput": "60"
    }
  ]
}

RÈGLE CRITIQUE pour codeInitial :
- codeInitial doit être un SQUELETTE VIDE : Algorithme + Var avec les noms des variables déclarées + Debut + Fin.
- NE METS PAS la logique dans codeInitial. C'est juste le point de départ que l'utilisateur verra.
- codeSolution est la solution complète et correcte que tu génères. Elle utilise <- pour l'affectation.
- Exemple INTERDIT dans codeInitial : mettre "somme <- 0" ou toute logique de résolution.
- Exemple CORRECT pour codeInitial : "Algorithme Somme;\\nVar\\n   n, i, somme : Entier;\\nDebut\\n   \\nFin"
''';

      final generationResult = await DeepSeekService.generateDailyChallenges(
        prompt,
        model: model,
      );
      // Le fallback message est ignoré ici (pas de BuildContext dans le provider)
      // — l'UI peut le lire depuis generationResult.fallbackMessage si besoin.
      final cleanJsonStr = _cleanJsonString(generationResult.content);
      final decoded = jsonDecode(cleanJsonStr) as Map<String, dynamic>;

      if (!decoded.containsKey('challenges')) {
        throw Exception(
          "Le JSON retourné ne contient pas la clé 'challenges'.",
        );
      }

      final List<dynamic> list = decoded['challenges'];
      final challenges = list.map((c) => DailyChallenge.fromJson(c)).toList();

      if (challenges.isEmpty) {
        throw Exception("Aucun défi généré par l'IA.");
      }

      _todaySession = DailyChallengeSession(
        date: dateStr,
        score: 0,
        total: challenges.length,
        inclutAlgo: inclutAlgo,
        challenges: challenges,
        completed: false,
      );

      await _db.insertDailyChallengeSession(_todaySession!);
      await loadHistoryAndStats();

      // Update widgets
      try {
        final tasks = await _db.getTasksForDate(DateTime.now());
        await HomeWidgetService.instance.updateTasksWidget(tasks);
      } catch (e) {
        debugPrint('Error updating widgets in generateTodaySession: $e');
      }
    } catch (e) {
      _errorMessage = formatUserError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Répond à un QCM.
  Future<void> answerQcm(int challengeIndex, int optionIndex) async {
    final session = _todaySession;
    if (session == null || challengeIndex >= session.challenges.length) return;

    final challenge = session.challenges[challengeIndex];
    if (challenge.type != 'qcm' || challenge.userAnswerIndex != null) return;

    challenge.userAnswerIndex = optionIndex;
    await _recalculateAndSaveSession();
  }

  /// Valide un défi d'algorithmique.
  Future<void> markAlgoSolved(int challengeIndex) async {
    final session = _todaySession;
    if (session == null || challengeIndex >= session.challenges.length) return;

    final challenge = session.challenges[challengeIndex];
    if (challenge.type != 'algo' || challenge.isSolved) return;

    challenge.isSolved = true;
    challenge.isFailed = false; // Réussir efface l'échec s'il y en avait un
    await _recalculateAndSaveSession();
  }

  /// Marque un défi d'algorithmique comme échoué (soumis et incorrect).
  Future<void> markAlgoFailed(int challengeIndex) async {
    final session = _todaySession;
    if (session == null || challengeIndex >= session.challenges.length) return;

    final challenge = session.challenges[challengeIndex];
    if (challenge.type != 'algo' || challenge.isSolved || challenge.isFailed) {
      return;
    }

    challenge.isFailed = true;
    await _recalculateAndSaveSession();
  }

  /// Recalcule le score et l'état de complétion, puis sauvegarde en base.
  Future<void> _recalculateAndSaveSession() async {
    final session = _todaySession;
    if (session == null) return;

    int newScore = 0;
    bool allCompleted = true;

    for (final c in session.challenges) {
      if (c.type == 'qcm') {
        if (c.userAnswerIndex == null) {
          allCompleted = false;
        } else if (c.userAnswerIndex == c.bonneReponseIndex) {
          newScore++;
        }
      } else if (c.type == 'algo') {
        if (!c.isSolved && !c.isFailed) {
          allCompleted = false;
        } else if (c.isSolved) {
          newScore++;
        }
      }
    }

    _todaySession = session.copyWith(score: newScore, completed: allCompleted);

    await _db.updateDailyChallengeSession(_todaySession!);
    await loadHistoryAndStats();

    // Update widgets
    try {
      final tasks = await _db.getTasksForDate(DateTime.now());
      await HomeWidgetService.instance.updateTasksWidget(tasks);
    } catch (e) {
      debugPrint('Error updating widgets in _recalculateAndSaveSession: $e');
    }

    notifyListeners();
  }

  /// Nettoie les balises markdown ```json et autres résidus du texte retourné par l'IA.
  String _cleanJsonString(String raw) {
    var s = raw.trim();
    if (s.startsWith('```')) {
      s = s.substring(3);
      if (s.startsWith('json')) {
        s = s.substring(4);
      }
    }
    if (s.endsWith('```')) {
      s = s.substring(0, s.length - 3);
    }
    return s.trim();
  }

  /// Réinitialise l'erreur.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
