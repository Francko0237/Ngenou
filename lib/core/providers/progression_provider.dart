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
    double currentWeight = 0.0;

    for (final notion in notions) {
      try {
        final p = list.firstWhere((e) => e.notionId == notion.id);
        if (p.statut == 'termine') {
          completedNotions++;
          currentWeight += 1.0;
        } else if (p.statut == 'en_cours') {
          inProgressNotions++;
          // Progression réelle de lecture (entre 0.0 et 1.0, ex: 0.25 pour 1/4)
          final lectureP = p.progressionLecture > 0.0 ? p.progressionLecture : 0.25;
          currentWeight += lectureP;
        }
      } catch (e) {
        // Notion not started
      }
    }

    // Calcul de la progression globale basé sur les poids réels :
    // - Notion terminée = 100% (1.0)
    // - Notion en cours = pourcentage réel de concepts lus (ex: 25%, 50%, 75%)
    // - Notion non commencée = 0%
    double totalWeight = notions.length.toDouble();
    double prog = totalWeight > 0 ? (currentWeight / totalWeight) * 100.0 : 0.0;

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
      progressionLecture: current?.progressionLecture ?? (statut == 'termine' ? 1.0 : 0.0),
      lastSectionIndex: current?.lastSectionIndex ?? 0,
      lastLessonIndex: current?.lastLessonIndex ?? 0,
      derniereActivite: DateTime.now(),
    );

    await _dbHelper.upsertProgression(newProgression);
    await loadProgression(matiereId, notify: true);
  }

  /// Met à jour la progression réelle de lecture au fur et à mesure que l'apprenant avance dans la leçon.
  Future<void> updateReadingProgress({
    required String matiereId,
    required String notionId,
    required double progress, // 0.0 à 1.0
    int sectionIndex = 0,
    int lessonIndex = 0,
  }) async {
    final list = await _dbHelper.getProgressionsByMatiere(matiereId);
    final current = list.where((p) => p.notionId == notionId).firstOrNull;

    // Si déjà marquée comme terminée (100%), on garde 'termine'
    if (current != null && current.statut == 'termine') return;

    final clampedProgress = progress.clamp(0.0, 1.0);
    final prevProgress = current?.progressionLecture ?? 0.0;
    final bestProgress = clampedProgress > prevProgress ? clampedProgress : prevProgress;

    final newProg = Progression(
      id: current?.id,
      matiereId: matiereId,
      notionId: notionId,
      statut: bestProgress >= 1.0 ? 'termine' : 'en_cours',
      nbExercicesReussis: current?.nbExercicesReussis ?? 0,
      nbExercicesTotal: current?.nbExercicesTotal ?? 0,
      progressionLecture: bestProgress,
      lastSectionIndex: sectionIndex,
      lastLessonIndex: lessonIndex,
      derniereActivite: DateTime.now(),
    );

    await _dbHelper.upsertProgression(newProg);
    await loadProgression(matiereId, notify: true);
  }

  /// Marque une notion comme 'en_cours' dès que l'utilisateur commence à lire la leçon,
  /// sans forcer un faux 50% arbitraire.
  Future<void> markNotionInProgress(
    String matiereId,
    String notionId, {
    double initialProgress = 0.0,
    int sectionIndex = 0,
    int lessonIndex = 0,
  }) async {
    final list = await _dbHelper.getProgressionsByMatiere(matiereId);
    final current = list.where((p) => p.notionId == notionId).firstOrNull;

    // Si déjà terminée, on ne la rétrograde jamais
    if (current != null && current.statut == 'termine') return;

    final prevProg = current?.progressionLecture ?? 0.0;
    final bestProgress = initialProgress > prevProg ? initialProgress : prevProg;

    final newProg = Progression(
      id: current?.id,
      matiereId: matiereId,
      notionId: notionId,
      statut: 'en_cours',
      nbExercicesReussis: current?.nbExercicesReussis ?? 0,
      nbExercicesTotal: current?.nbExercicesTotal ?? 0,
      progressionLecture: bestProgress,
      lastSectionIndex: current?.lastSectionIndex ?? sectionIndex,
      lastLessonIndex: current?.lastLessonIndex ?? lessonIndex,
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
      progressionLecture: 1.0,
      lastSectionIndex: current?.lastSectionIndex ?? 0,
      lastLessonIndex: current?.lastLessonIndex ?? 0,
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
