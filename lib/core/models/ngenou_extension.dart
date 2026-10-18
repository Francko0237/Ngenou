import 'package:flutter/material.dart';

class NgenouExtension {
  final String id;
  final String nom;
  final String description;
  final String version;
  final String taille;
  final String auteur;
  final String iconeKey;
  final String couleurHex;
  final String categorie;
  final List<String> niveaux;
  final String downloadUrl;
  final List<String> files;
  final bool isInstalled;
  final String type; // 'script_engine', 'math_tool', 'web_microapp', 'interactive_ui'
  final String? entrypoint;
  final Map<String, dynamic> config;
  final String? aiPrompt;

  NgenouExtension({
    required this.id,
    required this.nom,
    required this.description,
    required this.version,
    required this.taille,
    required this.auteur,
    required this.iconeKey,
    required this.couleurHex,
    required this.categorie,
    required this.niveaux,
    required this.downloadUrl,
    this.files = const [],
    this.isInstalled = false,
    this.type = 'interactive_ui',
    this.entrypoint,
    this.config = const {},
    this.aiPrompt,
  });

  IconData get icon {
    switch (iconeKey.toLowerCase()) {
      case 'code':
        return Icons.code_rounded;
      case 'calculator':
        return Icons.calculate_rounded;
      case 'flask':
      case 'science':
        return Icons.science_rounded;
      case 'language':
        return Icons.translate_rounded;
      case 'history':
        return Icons.history_edu_rounded;
      case 'palette':
        return Icons.palette_rounded;
      case 'music':
        return Icons.music_note_rounded;
      case 'world':
        return Icons.public_rounded;
      default:
        return Icons.extension_rounded;
    }
  }

  Color get color {
    try {
      var hex = couleurHex.replaceFirst('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFF6C63FF);
    }
  }

  factory NgenouExtension.fromJson(Map<String, dynamic> json, {bool isInstalled = false}) {
    return NgenouExtension(
      id: json['id'] as String? ?? '',
      nom: json['nom'] as String? ?? 'Extension',
      description: json['description'] as String? ?? '',
      version: json['version'] as String? ?? '1.0.0',
      taille: json['taille'] as String? ?? '50 Ko',
      auteur: json['auteur'] as String? ?? 'Ngenou',
      iconeKey: json['icone'] as String? ?? 'extension',
      couleurHex: json['couleur'] as String? ?? '#6C63FF',
      categorie: json['categorie'] as String? ?? 'Général',
      niveaux: (json['niveaux'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      downloadUrl: json['download_url'] as String? ?? '',
      files: (json['files'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isInstalled: isInstalled,
      type: json['type'] as String? ?? 'interactive_ui',
      entrypoint: json['entrypoint'] as String?,
      config: (json['config'] as Map<String, dynamic>?) ?? const {},
      aiPrompt: json['ai_prompt'] as String? ?? json['aiPrompt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nom': nom,
        'description': description,
        'version': version,
        'taille': taille,
        'auteur': auteur,
        'icone': iconeKey,
        'couleur': couleurHex,
        'categorie': categorie,
        'niveaux': niveaux,
        'download_url': downloadUrl,
        'files': files,
        'type': type,
        'entrypoint': entrypoint,
        'config': config,
        'ai_prompt': aiPrompt,
      };

  NgenouExtension copyWith({
    bool? isInstalled,
    String? version,
    String? type,
    String? entrypoint,
    Map<String, dynamic>? config,
    String? aiPrompt,
  }) {
    return NgenouExtension(
      id: id,
      nom: nom,
      description: description,
      version: version ?? this.version,
      taille: taille,
      auteur: auteur,
      iconeKey: iconeKey,
      couleurHex: couleurHex,
      categorie: categorie,
      niveaux: niveaux,
      downloadUrl: downloadUrl,
      files: files,
      isInstalled: isInstalled ?? this.isInstalled,
      type: type ?? this.type,
      entrypoint: entrypoint ?? this.entrypoint,
      config: config ?? this.config,
      aiPrompt: aiPrompt ?? this.aiPrompt,
    );
  }
}
