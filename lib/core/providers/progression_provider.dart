import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/progression.dart';
import '../models/score.dart';
import '../../modules/modules_registry.dart';

class ProgressionProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  final Map<String, double> _progressionGlobaleParMatiere = {};
  final Map<String, List<Progression>> _progressionsParMatiere = {};
  final Map<String, List<Score>> _scoresParMatiere = {};

  // Pour rétrocompatibilité pendant la transition
  double get progressionGlobale =>
      _progressionGlobaleParMatiere.values.isNotEmpty
      ? _progressionGlobaleParMatiere.values.first
      : 0.0;
  List<Progression> get progressionsByMatiere =>
      _progressionsParMatiere.values.isNotEmpty
      ? _progressionsParMatiere.values.first
      : [];

  double getProgressionGlobale(String matiereId) =>
      _progressionGlobaleParMatiere[matiereId] ?? 0.0;
  List<Progression> getProgressions(String matiereId) =>
      _progressionsParMatiere[matiereId] ?? [];
  List<Score> getScores(String matiereId) => _scoresParMatiere[matiereId] ?? [];

  Future<List<Score>> getAllRecentScores(int limit) async {
    return await _dbHelper.getAllRecentScores(limit);
  }

  Future<void> loadAllProgressions() async {
    for (var matiere in ModulesRegistry.matieres) {
      await loadProgression(matiere.id, notify: false);
    }
    notifyListeners();
  }

  Future<void> loadProgression(String matiereId, {bool notify = true}) async {
    final list = await _dbHelper.getProgressionsByMatiere(matiereId);
    _progressionsParMatiere[matiereId] = list;

    final scores = await _dbHelper.getScoresByMatiere(matiereId);
    _scoresParMatiere[matiereId] = scores;

    // Calculate progression based on completed notions vs total notions
    final notions = ModulesRegistry.getNotions(matiereId);
    if (notions.isEmpty) {
      _progressionGlobaleParMatiere[matiereId] = 0.0;
      if (notify) notifyListeners();
      return;
    }

    int completedNotions = 0;
    int inProgressNotions = 0;

    for (final notion in notions) {
      try {
        final p = list.firstWhere((e) => e.notionId == notion.id);
        if (p.statut == 'termine') {
          completedNotions++;
        } else if (p.statut == 'en_cours') {
          inProgressNotions++;
        }
      } catch (e) {
        // Notion not started
      }
    }

    // Progression calculation:
    // - Completed notions = 100% of their weight
    // - In-progress notions = 50% of their weight
    // - Not started = 0%
    double totalWeight = notions.length.toDouble();
    double currentWeight = completedNotions + (inProgressNotions * 0.5);
    double prog = (currentWeight / totalWeight) * 100.0;

    _progressionGlobaleParMatiere[matiereId] = prog.clamp(0.0, 100.0);

    if (notify) notifyListeners();
  }

  Future<void> saveTestResult(
    String matiereId,
    String notionId,
    bool isSuccess,
  ) async {
    Progression? current;
    try {
      final list = await _dbHelper.getProgressionsByMatiere(matiereId);
      current = list.firstWhere((p) => p.notionId == notionId);
    } catch (e) {
      // Not found
    }

    final int reussis =
        (current?.nbExercicesReussis ?? 0) + (isSuccess ? 1 : 0);
    final int total = (current?.nbExercicesTotal ?? 0) + 1;

    // Determine status based on exercise performance
    // - termine: at least 3 exercises AND success rate >= 60%
    // - en_cours: at least 1 exercise but not yet completed
    // - non_commence: no exercises done
    final double successRate = total > 0 ? reussis / total : 0.0;
    final String statut;
    if (total >= 3 && successRate >= 0.6) {
      statut = 'termine';
    } else if (total > 0) {
      statut = 'en_cours';
    } else {
      statut = 'non_commence';
    }

    final newProgression = Progression(
      id: current?.id,
      matiereId: matiereId,
      notionId: notionId,
      statut: statut,
      nbExercicesReussis: reussis,
      nbExercicesTotal: total,
      derniereActivite: DateTime.now(),
    );

    await _dbHelper.upsertProgression(newProgression);
    await loadProgression(matiereId, notify: true);
    // Les badges sont déclenchés uniquement depuis exercice_page.dart
    // après navigation vers /resultat — pas ici pour éviter les doublons.
  }

  /// Marque une notion comme 'en_cours' dès que l'utilisateur commence à lire la leçon,
  /// sauf si elle est déjà 'termine'.
  Future<void> markNotionInProgress(String matiereId, String notionId) async {
    final list = await _dbHelper.getProgressionsByMatiere(matiereId);
    final current = list.where((p) => p.notionId == notionId).firstOrNull;

    // Si déjà terminée, on ne la rétrograde jamais
    if (current != null && current.statut == 'termine') return;

    // Si déjà en cours, pas besoin de réécrire
    if (current != null && current.statut == 'en_cours') return;

    final newProg = Progression(
      id: current?.id,
      matiereId: matiereId,
      notionId: notionId,
      statut: 'en_cours',
      nbExercicesReussis: current?.nbExercicesReussis ?? 0,
      nbExercicesTotal: current?.nbExercicesTotal ?? 0,
      derniereActivite: DateTime.now(),
    );

    await _dbHelper.upsertProgression(newProg);
    await loadProgression(matiereId, notify: true);
  }

  /// Marque une notion comme 'termine' (100%) dès que la lecture de toutes les leçons est achevée,
  /// sans obliger à faire les exercices qui sont facultatifs.
  Future<void> markNotionCompleted(String matiereId, String notionId) async {
    Progression? current;
    try {
      final list = await _dbHelper.getProgressionsByMatiere(matiereId);
      current = list.where((p) => p.notionId == notionId).firstOrNull;
    } catch (_) {}

    final newProg = Progression(
      id: current?.id,
      matiereId: matiereId,
      notionId: notionId,
      statut: 'termine',
      nbExercicesReussis: current?.nbExercicesReussis ?? 0,
      nbExercicesTotal: current?.nbExercicesTotal ?? 0,
      derniereActivite: DateTime.now(),
    );

    await _dbHelper.upsertProgression(newProg);
    await loadProgression(matiereId, notify: true);
  }

  /// Marque la complétion d'une série d'exercices pour une notion,
  /// met à jour immédiatement le statut et notifie tous les écouteurs locaux (dashboard & cours).
  Future<void> completeNotionSeries({
    required String matiereId,
    required String notionId,
    required int score,
    required int total,
  }) async {
    Progression? current;
    try {
      final list = await _dbHelper.getProgressionsByMatiere(matiereId);
      current = list.where((p) => p.notionId == notionId).firstOrNull;
    } catch (e) {
      // Not found
    }

    final double successRate = total > 0 ? score / total : 1.0;
    // La notion reste terminée si elle l'était déjà (par lecture) ou si réussite >= 50%
    final bool isCompleted =
        (current?.statut == 'termine') || (successRate >= 0.5);

    final newProgression = Progression(
      id: current?.id,
      matiereId: matiereId,
      notionId: notionId,
      statut: isCompleted ? 'termine' : 'en_cours',
      nbExercicesReussis: score,
      nbExercicesTotal: total,
      derniereActivite: DateTime.now(),
    );

    await _dbHelper.upsertProgression(newProgression);
    await loadProgression(matiereId, notify: true);
  }

  Future<void> resetProgression(String matiereId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'progression',
      where: 'matiere_id = ?',
      whereArgs: [matiereId],
    );
    await loadProgression(matiereId);
  }

  /// Retourne la dernière notion marquée 'en_cours' pour proposer une reprise immédiate
  Map<String, dynamic>? getMostRecentInProgressNotion() {
    Progression? mostRecent;
    String? mostRecentMatiereId;

    for (final entry in _progressionsParMatiere.entries) {
      for (final p in entry.value) {
        if (p.statut == 'en_cours') {
          if (mostRecent == null ||
              (p.derniereActivite != null &&
                  (mostRecent.derniereActivite == null ||
                      p.derniereActivite!.isAfter(mostRecent.derniereActivite!)))) {
            mostRecent = p;
            mostRecentMatiereId = entry.key;
          }
        }
      }
    }

    if (mostRecent != null && mostRecentMatiereId != null) {
      final notions = ModulesRegistry.getNotions(mostRecentMatiereId);
      final notion =
          notions.where((n) => n.id == mostRecent!.notionId).firstOrNull;
      final matiere = ModulesRegistry.getMatiere(mostRecentMatiereId);
      if (notion != null && matiere != null) {
        return {
          'progression': mostRecent,
          'matiere': matiere,
          'notion': notion,
        };
      }
    }
    return null;
  }
}
