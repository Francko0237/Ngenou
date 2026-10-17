import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/ngenou_extension.dart';

class ExtensionValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const ExtensionValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  bool get hasWarnings => warnings.isNotEmpty;
  String get summary => isValid
      ? 'Extension conforme aux spécifications Ngenou.'
      : 'Non-conforme (${errors.length} erreur${errors.length > 1 ? 's' : ''}).';
}

/// Validateur autonome pour certifier qu'une extension respecte le standard Ngenou
class ExtensionValidator {
  static const List<String> supportedTypes = [
    'script_engine',
    'math_tool',
    'interactive_ui',
    'web_microapp',
    'quiz_module',
  ];

  static const List<String> allowedLevels = [
    'primaire',
    'secondaire',
    'superieur',
  ];

  static final RegExp _idRegex = RegExp(r'^[a-z0-9_]{3,32}$');
  static final RegExp _semverRegex = RegExp(r'^\d+\.\d+\.\d+');

  /// Valide le schéma et les métadonnées déclaratives
  static ExtensionValidationResult validate(NgenouExtension ext) {
    final List<String> errors = [];
    final List<String> warnings = [];

    // 1. Identifiant
    if (ext.id.trim().isEmpty) {
      errors.add("L'identifiant 'id' est manquant.");
    } else if (!_idRegex.hasMatch(ext.id)) {
      errors.add(
        "L'identifiant '${ext.id}' est invalide (doit contenir 3 à 32 caractères minuscules, chiffres ou tirets bas).",
      );
    }

    // 2. Nom
    if (ext.nom.trim().isEmpty) {
      errors.add("Le nom 'nom' de l'extension est obligatoire.");
    } else if (ext.nom.length < 3) {
      warnings.add("Le nom est très court (< 3 caractères).");
    }

    // 3. Auteur
    if (ext.auteur.trim().isEmpty) {
      errors.add("L'auteur 'auteur' doit être renseigné.");
    }

    // 4. Version
    if (ext.version.trim().isEmpty) {
      errors.add("Le champ 'version' est obligatoire.");
    } else if (!_semverRegex.hasMatch(ext.version)) {
      warnings.add(
        "La version '${ext.version}' ne respecte pas le format sémantique (ex: 1.0.0).",
      );
    }

    // 5. Type
    if (!supportedTypes.contains(ext.type)) {
      warnings.add(
        "Le type '${ext.type}' n'est pas standardisé (types officiels : ${supportedTypes.join(', ')}).",
      );
    }

    // 6. Niveaux scolaires
    if (ext.niveaux.isEmpty) {
      warnings.add("Aucun niveau scolaire ('niveaux') n'est spécifié.");
    } else {
      for (final lvl in ext.niveaux) {
        if (!allowedLevels.contains(lvl.toLowerCase())) {
          warnings.add("Niveau inconnu : '$lvl'.");
        }
      }
    }

    return ExtensionValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Valide l'intégrité des fichiers physiques une fois l'extension installée
  static Future<ExtensionValidationResult> validateInstalledFiles(
    Directory directory,
    NgenouExtension ext,
  ) async {
    final metaResult = validate(ext);
    final List<String> errors = List.from(metaResult.errors);
    final List<String> warnings = List.from(metaResult.warnings);

    if (!await directory.exists()) {
      errors.add("Le dossier d'installation de l'extension est introuvable.");
      return ExtensionValidationResult(
        isValid: false,
        errors: errors,
        warnings: warnings,
      );
    }

    // Vérifier les fichiers déclarés
    for (final fileName in ext.files) {
      final file = File(p.join(directory.path, fileName));
      if (!await file.exists()) {
        errors.add("Fichier requis manquant : '$fileName'.");
      }
    }

    // Vérifier l'entrypoint si présent
    if (ext.entrypoint != null && ext.entrypoint!.isNotEmpty) {
      final entryFile = File(p.join(directory.path, ext.entrypoint!));
      if (!await entryFile.exists()) {
        errors.add(
          "Le point d'entrée déclaré '${ext.entrypoint}' est introuvable.",
        );
      }
    }

    return ExtensionValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
}
