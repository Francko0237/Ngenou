/// Modes d'ouverture d'un fichier dans l'interpréteur Ngenou.
enum FileOpenMode { lecture, ecriture, ajout }

/// Types d'événements émis pendant l'exécution d'opérations sur les fichiers.
enum FileEventType { open, read, write, seek, close, eof }

/// Événement envoyé en temps réel à l'interface lors d'une opération fichier.
class FileEvent {
  final int channel;
  final String fileName;
  final FileOpenMode mode;
  final FileEventType type;
  final int linePosition; // 1-based (1 = première ligne)
  final int totalLines;
  final bool isEof;
  final dynamic record;
  final int algoLine;

  const FileEvent({
    required this.channel,
    required this.fileName,
    required this.mode,
    required this.type,
    required this.linePosition,
    required this.totalLines,
    required this.isEof,
    this.record,
    this.algoLine = 0,
  });
}

/// Interface d'abstraction pour le stockage physique des fichiers (JSON Lines).
/// Permet d'isoler l'accès disque pour les tests unitaires ([InMemoryFileStorage])
/// et l'exécution réelle sur appareil ([LocalFileStorage]).
abstract class FileStorage {
  Future<bool> exists(String fileName);
  Future<List<String>> readLines(String fileName);
  Future<void> writeLines(String fileName, List<String> lines);
  Future<void> appendLine(String fileName, String line);
}

/// Implémentation en mémoire pour les tests unitaires et les environnements sans disque.
class InMemoryFileStorage implements FileStorage {
  final Map<String, List<String>> _files = {};

  Map<String, List<String>> get files => _files;

  @override
  Future<bool> exists(String fileName) async {
    return _files.containsKey(fileName);
  }

  @override
  Future<List<String>> readLines(String fileName) async {
    final lines = _files[fileName];
    if (lines == null) return [];
    return List<String>.from(lines);
  }

  @override
  Future<void> writeLines(String fileName, List<String> lines) async {
    _files[fileName] = List<String>.from(lines);
  }

  @override
  Future<void> appendLine(String fileName, String line) async {
    _files.putIfAbsent(fileName, () => []);
    _files[fileName]!.add(line);
  }
}
