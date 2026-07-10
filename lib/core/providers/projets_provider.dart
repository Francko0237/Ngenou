import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/projet.dart';
import '../providers/progression_provider.dart';

/// Provider gérant la liste des projets et leurs progressions agrégées.
class ProjetsProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Projet> _projets = [];
  bool _loaded = false;

  List<Projet> get projets => List.unmodifiable(_projets);
  bool get isLoaded => _loaded;

  /// Projet système "Mes cours" — contient les cours sans projet.
  Projet get mesCours => Projet(
        id: Projet.libraryId,
        nom: 'Mes cours',
        description: 'Cours hors projet',
        couleur: '#6C63FF',
        icone: 'library',
        matiereIds: const [],
        isSystem: true,
        dateCreation: DateTime(2000),
      );

  // ─── Chargement ──────────────────────────────────────────────────────────────

  Future<void> loadProjets() async {
    final loaded = await _db.getAllProjets();
    _projets = loaded;
    _loaded = true;
    notifyListeners();
  }

  // ─── Progression ─────────────────────────────────────────────────────────────

  /// Calcule la progression d'un projet = moyenne des progressions de ses cours.
  double getProgressionProjet(
    Projet projet,
    ProgressionProvider progProvider,
  ) {
    if (projet.matiereIds.isEmpty) return 0.0;
    double total = 0.0;
    for (final id in projet.matiereIds) {
      total += progProvider.getProgressionGlobale(id);
    }
    return total / projet.matiereIds.length;
  }

  /// IDs des matières custom qui n'appartiennent à aucun projet.
  Set<String> getMatiereIdsHorsProjet(List<String> allCustomMatiereIds) {
    final inProject = _projets.expand((p) => p.matiereIds).toSet();
    return allCustomMatiereIds
        .where((id) => !inProject.contains(id))
        .toSet();
  }

  /// Projets auxquels un cours (matiereId) appartient.
  List<Projet> getProjetsForMatiere(String matiereId) {
    return _projets.where((p) => p.matiereIds.contains(matiereId)).toList();
  }

  // ─── CRUD ────────────────────────────────────────────────────────────────────

  Future<void> createProjet(Projet projet) async {
    await _db.insertProjet(projet);
    _projets.add(projet);
    notifyListeners();
  }

  Future<void> updateProjet(Projet projet) async {
    await _db.updateProjet(projet);
    final idx = _projets.indexWhere((p) => p.id == projet.id);
    if (idx >= 0) _projets[idx] = projet;
    notifyListeners();
  }

  Future<void> deleteProjet(String projetId) async {
    await _db.deleteProjet(projetId);
    _projets.removeWhere((p) => p.id == projetId);
    notifyListeners();
  }

  // ─── Gestion des cours dans un projet ────────────────────────────────────────

  Future<void> addMatiereToProjet(String projetId, String matiereId) async {
    await _db.addMatiereToProjet(projetId, matiereId);
    final idx = _projets.indexWhere((p) => p.id == projetId);
    if (idx >= 0) {
      final p = _projets[idx];
      if (!p.matiereIds.contains(matiereId)) {
        _projets[idx] = p.copyWith(
          matiereIds: [...p.matiereIds, matiereId],
        );
      }
    }
    notifyListeners();
  }

  Future<void> removeMatiereFromProjet(
      String projetId, String matiereId) async {
    await _db.removeMatiereFromProjet(projetId, matiereId);
    final idx = _projets.indexWhere((p) => p.id == projetId);
    if (idx >= 0) {
      final p = _projets[idx];
      _projets[idx] = p.copyWith(
        matiereIds: p.matiereIds.where((id) => id != matiereId).toList(),
      );
    }
    notifyListeners();
  }

  /// Transfère un cours d'un projet source vers un projet cible.
  Future<void> transfererMatiere(
    String fromProjetId,
    String toProjetId,
    String matiereId,
  ) async {
    await removeMatiereFromProjet(fromProjetId, matiereId);
    await addMatiereToProjet(toProjetId, matiereId);
  }

  /// Ajoute un cours à plusieurs projets simultanément.
  Future<void> addMatiereToMultipleProjets(
    List<String> projetIds,
    String matiereId,
  ) async {
    for (final id in projetIds) {
      await addMatiereToProjet(id, matiereId);
    }
  }

  Projet? getProjetById(String id) {
    try {
      return _projets.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
