import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../algo_interpreter/file_storage.dart';

/// Stockage persistant sur le disque local de l'appareil (format JSON Lines).
/// Tous les fichiers sont isolés dans `<Documents>/ngenou_files/`.
class LocalFileStorage implements FileStorage {
  LocalFileStorage({Directory? overrideDirectory})
      : _overrideDirectory = overrideDirectory;

  final Directory? _overrideDirectory;

  /// Retourne (et crée si besoin) le répertoire dédié aux fichiers algorithmiques.
  Future<Directory> getBaseDirectory() async {
    if (_overrideDirectory != null) {
      if (!await _overrideDirectory.exists()) {
        await _overrideDirectory.create(recursive: true);
      }
      return _overrideDirectory;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'ngenou_files'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Sécurise le nom de fichier pour empêcher toute sortie du dossier dédié.
  Future<File> resolveFile(String fileName) async {
    final sanitized = p.basename(fileName.trim());
    if (sanitized.isEmpty || sanitized == '.' || sanitized == '..') {
      throw const FormatException('Nom de fichier invalide');
    }
    final dir = await getBaseDirectory();
    return File(p.join(dir.path, sanitized));
  }

  @override
  Future<bool> exists(String fileName) async {
    final file = await resolveFile(fileName);
    return file.exists();
  }

  @override
  Future<List<String>> readLines(String fileName) async {
    final file = await resolveFile(fileName);
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    if (content.isEmpty) return [];
    return content
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();
  }

  @override
  Future<void> writeLines(String fileName, List<String> lines) async {
    final file = await resolveFile(fileName);
    final nonEmpty = lines.where((l) => l.trim().isNotEmpty).toList();
    final content = nonEmpty.isEmpty ? '' : '${nonEmpty.join('\n')}\n';
    await file.writeAsString(content, flush: true);
  }

  @override
  Future<void> appendLine(String fileName, String line) async {
    final file = await resolveFile(fileName);
    if (line.trim().isEmpty) return;
    await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
  }
}
