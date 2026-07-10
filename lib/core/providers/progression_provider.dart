import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/progression.dart';
import '../../modules/modules_registry.dart';

class ProgressionProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  final Map<String, double> _progressionGlobaleParMatiere = {};
  final Map<String, List<Progression>> _progressionsParMatiere = {};

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

  Future<void> loadAllProgressions() async {
    for (var matiere in ModulesRegistry.matieres) {
      await loadProgression(matiere.id, notify: false);
    }
    notifyListeners();
  }

  Future<void> loadProgression(String matiereId, {bool notify = true}) async {
    final list = await _dbHelper.getProgressionsByMatiere(matiereId);
    _progressionsParMatiere[matiereId] = list;

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
    await loadProgression(matiereId);
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
}
