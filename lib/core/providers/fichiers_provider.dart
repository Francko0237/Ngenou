import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../algo_interpreter/file_storage.dart';
import '../services/local_file_storage.dart';

/// Métadonnées d'un fichier algorithmique.
class AlgoFileInfo {
  final String name;
  final int sizeBytes;
  final int recordCount;
  final DateTime lastModified;

  const AlgoFileInfo({
    required this.name,
    required this.sizeBytes,
    required this.recordCount,
    required this.lastModified,
  });
}

/// Représente une ligne (enregistrement) lue depuis un fichier JSON Lines.
class AlgoFileRecord {
  final Map<String, dynamic> fields;
  final bool isScalar;

  const AlgoFileRecord({required this.fields, this.isScalar = false});
}

/// Provider gérant la liste et le contenu des fichiers algorithmiques créés
/// par l'interpréteur Ngenou. Encapsule [LocalFileStorage] pour l'UI.
class FichiersProvider extends ChangeNotifier {
  final LocalFileStorage _storage = LocalFileStorage();

  List<AlgoFileInfo> _files = [];
  List<AlgoFileInfo> get files => List.unmodifiable(_files);

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  FileEvent? _liveEvent;
  FileEvent? get liveEvent => _liveEvent;

  void updateLiveEvent(FileEvent? event) {
    _liveEvent = event;
    notifyListeners();
  }

  // ── Chargement ────────────────────────────────────────────────────────────

  Future<void> loadFiles() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final dir = await _storage.getBaseDirectory();
      final entities = dir.listSync();
      final infos = <AlgoFileInfo>[];
      for (final e in entities) {
        if (e is File) {
          final stat = await e.stat();
          final fileName = e.uri.pathSegments.last;
          final lines = await _storage.readLines(fileName);
          infos.add(AlgoFileInfo(
            name: fileName,
            sizeBytes: stat.size,
            recordCount: lines.length,
            lastModified: stat.modified,
          ));
        }
      }
      infos.sort((a, b) => b.lastModified.compareTo(a.lastModified));
      _files = infos;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  // ── CRUD fichiers ─────────────────────────────────────────────────────────

  /// Crée un fichier vide (si le nom n'existe pas déjà).
  Future<String?> createFile(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Le nom ne peut pas être vide.';
    if (_files.any((f) => f.name == trimmed)) {
      return 'Un fichier « $trimmed » existe déjà.';
    }
    try {
      await _storage.writeLines(trimmed, []);
      await loadFiles();
      return null;
    } catch (e) {
      return 'Impossible de créer le fichier : $e';
    }
  }

  /// Renomme un fichier (copie + suppression de l'ancien).
  Future<String?> renameFile(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return 'Le nouveau nom ne peut pas être vide.';
    if (_files.any((f) => f.name == trimmed)) {
      return 'Un fichier « $trimmed » existe déjà.';
    }
    try {
      final lines = await _storage.readLines(oldName);
      await _storage.writeLines(trimmed, lines);
      await _deletePhysical(oldName);
      await loadFiles();
      return null;
    } catch (e) {
      return 'Impossible de renommer : $e';
    }
  }

  /// Supprime définitivement un fichier.
  Future<String?> deleteFile(String name) async {
    try {
      await _deletePhysical(name);
      await loadFiles();
      return null;
    } catch (e) {
      return 'Impossible de supprimer : $e';
    }
  }

  Future<void> _deletePhysical(String name) async {
    final file = await _storage.resolveFile(name);
    if (await file.exists()) await file.delete();
  }

  // ── Lecture / écriture des enregistrements ────────────────────────────────

  /// Retourne la liste des enregistrements (objets JSON ou scalaires) du fichier.
  Future<List<AlgoFileRecord>> readRecords(String fileName) async {
    final lines = await _storage.readLines(fileName);
    final records = <AlgoFileRecord>[];
    for (final line in lines) {
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map<String, dynamic>) {
          records.add(AlgoFileRecord(fields: decoded));
        } else if (decoded is Map) {
          records.add(AlgoFileRecord(
            fields: decoded.map((k, v) => MapEntry(k.toString(), v)),
          ));
        } else {
          records.add(AlgoFileRecord(
            fields: {'valeur': decoded},
            isScalar: true,
          ));
        }
      } catch (_) {
        records.add(AlgoFileRecord(
          fields: {'valeur': line},
          isScalar: true,
        ));
      }
    }
    return records;
  }

  String _encodeRecord(Map<String, dynamic> fields, bool isScalar) {
    if (isScalar && fields.containsKey('valeur') && fields.length == 1) {
      return jsonEncode(fields['valeur']);
    }
    return jsonEncode(fields);
  }

  /// Remplace l'enregistrement à l'index donné (0-based).
  Future<String?> updateRecord(
    String fileName,
    int index,
    Map<String, dynamic> newFields, {
    bool isScalar = false,
  }) async {
    try {
      final lines = await _storage.readLines(fileName);
      if (index < 0 || index >= lines.length) {
        return 'Index $index hors limites.';
      }
      lines[index] = _encodeRecord(newFields, isScalar);
      await _storage.writeLines(fileName, lines);
      await loadFiles();
      return null;
    } catch (e) {
      return 'Impossible de mettre à jour : $e';
    }
  }

  /// Ajoute un enregistrement à la fin du fichier.
  Future<String?> appendRecord(
    String fileName,
    Map<String, dynamic> fields, {
    bool isScalar = false,
  }) async {
    try {
      await _storage.appendLine(fileName, _encodeRecord(fields, isScalar));
      await loadFiles();
      return null;
    } catch (e) {
      return 'Impossible d\'ajouter : $e';
    }
  }

  /// Supprime un enregistrement à l'index donné (0-based).
  Future<String?> deleteRecord(String fileName, int index) async {
    try {
      final lines = await _storage.readLines(fileName);
      if (index < 0 || index >= lines.length) {
        return 'Index $index hors limites.';
      }
      lines.removeAt(index);
      await _storage.writeLines(fileName, lines);
      await loadFiles();
      return null;
    } catch (e) {
      return 'Impossible de supprimer l\'enregistrement : $e';
    }
  }

  // ── Import / Export ───────────────────────────────────────────────────────

  /// Importe un fichier externe (copie vers ngenou_files/).
  Future<String?> importFile(String sourcePath) async {
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return 'Fichier source introuvable.';
      final name = src.uri.pathSegments.last;
      final dest = await _storage.resolveFile(name);
      await src.copy(dest.path);
      await loadFiles();
      return null;
    } catch (e) {
      return 'Import impossible : $e';
    }
  }

  /// Retourne le chemin absolu du fichier (pour l'export / partage).
  Future<String?> getFilePath(String fileName) async {
    final file = await _storage.resolveFile(fileName);
    if (!await file.exists()) return null;
    return file.path;
  }
}
