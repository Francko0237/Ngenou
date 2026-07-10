import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/duration_utils.dart';

/// Modèle représentant un projet d'étude regroupant plusieurs cours/matières.
class Projet {
  /// ID réservé pour le projet système "Mes cours" (cours sans projet).
  static const String libraryId = 'project_library';

  final String id;
  final String nom;
  final String? description;
  final String? objectif;
  final String couleur; // couleur hex, ex: '#6C63FF'
  final String icone;   // clé dans [iconPalette]
  final List<String> matiereIds; // IDs ordonnés des cours rattachés
  final bool isSystem; // true pour le projet Bibliothèque
  final DateTime dateCreation;

  const Projet({
    required this.id,
    required this.nom,
    this.description,
    this.objectif,
    required this.couleur,
    required this.icone,
    required this.matiereIds,
    this.isSystem = false,
    required this.dateCreation,
  });

  Projet copyWith({
    String? nom,
    String? description,
    String? objectif,
    String? couleur,
    String? icone,
    List<String>? matiereIds,
  }) {
    return Projet(
      id: id,
      nom: nom ?? this.nom,
      description: description ?? this.description,
      objectif: objectif ?? this.objectif,
      couleur: couleur ?? this.couleur,
      icone: icone ?? this.icone,
      matiereIds: matiereIds ?? List.from(this.matiereIds),
      isSystem: isSystem,
      dateCreation: dateCreation,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nom': nom,
        'description': description,
        'objectif': objectif,
        'couleur': couleur,
        'icone': icone,
        'matiere_ids': jsonEncode(matiereIds),
        'is_system': isSystem ? 1 : 0,
        'date_creation': dateCreation.toIso8601String(),
      };

  factory Projet.fromMap(Map<String, dynamic> map) {
    final raw = map['matiere_ids'] as String? ?? '[]';
    final ids =
        (jsonDecode(raw) as List<dynamic>).map((e) => e.toString()).toList();
    return Projet(
      id: map['id'] as String,
      nom: map['nom'] as String,
      description: map['description'] as String?,
      objectif: map['objectif'] as String?,
      couleur: map['couleur'] as String,
      icone: map['icone'] as String,
      matiereIds: ids,
      isSystem: (map['is_system'] as int? ?? 0) == 1,
      dateCreation: DateTime.parse(map['date_creation'] as String),
    );
  }

  // ─── Icônes ─────────────────────────────────────────────────────────────────

  static IconData iconFromKey(String? key) {
    switch (key) {
      case 'rocket':
        return Icons.rocket_launch_rounded;
      case 'brain':
        return Icons.psychology_rounded;
      case 'target':
        return Icons.gps_fixed_rounded;
      case 'network':
        return Icons.hub_rounded;
      case 'lab':
        return Icons.biotech_rounded;
      case 'chart':
        return Icons.insights_rounded;
      case 'globe':
        return Icons.public_rounded;
      case 'shield':
        return Icons.security_rounded;
      case 'build':
        return Icons.construction_rounded;
      case 'library':
        return Icons.local_library_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'code':
        return Icons.code_rounded;
      case 'art':
        return Icons.palette_rounded;
      case 'music':
        return Icons.music_note_rounded;
      case 'health':
        return Icons.health_and_safety_rounded;
      case 'finance':
        return Icons.trending_up_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'spark':
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  static String iconToKey(IconData icon) {
    if (icon == Icons.rocket_launch_rounded) return 'rocket';
    if (icon == Icons.psychology_rounded) return 'brain';
    if (icon == Icons.gps_fixed_rounded) return 'target';
    if (icon == Icons.hub_rounded) return 'network';
    if (icon == Icons.biotech_rounded) return 'lab';
    if (icon == Icons.insights_rounded) return 'chart';
    if (icon == Icons.public_rounded) return 'globe';
    if (icon == Icons.security_rounded) return 'shield';
    if (icon == Icons.construction_rounded) return 'build';
    if (icon == Icons.local_library_rounded) return 'library';
    if (icon == Icons.school_rounded) return 'school';
    if (icon == Icons.code_rounded) return 'code';
    if (icon == Icons.palette_rounded) return 'art';
    if (icon == Icons.music_note_rounded) return 'music';
    if (icon == Icons.health_and_safety_rounded) return 'health';
    if (icon == Icons.trending_up_rounded) return 'finance';
    if (icon == Icons.star_rounded) return 'star';
    return 'spark';
  }

  static String iconLabel(String key) {
    const labels = {
      'rocket': 'Lancement',
      'brain': 'Intelligence',
      'target': 'Objectif',
      'network': 'Réseaux',
      'lab': 'Sciences',
      'chart': 'Données',
      'globe': 'Monde',
      'shield': 'Sécurité',
      'build': 'Ingénierie',
      'library': 'Bibliothèque',
      'school': 'École',
      'code': 'Code',
      'art': 'Art',
      'music': 'Musique',
      'health': 'Santé',
      'finance': 'Finance',
      'star': 'Favori',
      'spark': 'Général',
    };
    return labels[key] ?? 'Général';
  }

  // ─── Couleurs ───────────────────────────────────────────────────────────────

  static Color colorFromHex(String hex) {
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }

  static String colorToHex(Color c) =>
      '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  // ─── Palettes de design ──────────────────────────────────────────────────────

  /// Palette de couleurs proposées pour les projets.
  static const List<String> colorPalette = [
    '#6C63FF',
    '#3498DB',
    '#2ECC71',
    '#E74C3C',
    '#F39C12',
    '#9B59B6',
    '#1ABC9C',
    '#E91E63',
    '#FF5722',
    '#607D8B',
    '#00BCD4',
    '#8BC34A',
    '#FF9800',
    '#795548',
    '#FF4081',
  ];

  /// Clés des icônes disponibles pour les projets.
  static const List<String> iconPalette = [
    'rocket',
    'brain',
    'target',
    'network',
    'lab',
    'chart',
    'globe',
    'shield',
    'build',
    'library',
    'spark',
    'school',
    'code',
    'art',
    'music',
    'health',
    'finance',
    'star',
  ];
}

/// Un sujet/matière dans un programme généré par l'IA pour un projet.
class ProgramSubject {
  String nom;
  String description;
  int ordre;
  int durationMinutes;

  ProgramSubject({
    required this.nom,
    required this.description,
    required this.ordre,
    this.durationMinutes = 120,
  });

  factory ProgramSubject.fromJson(Map<String, dynamic> json) => ProgramSubject(
        nom: json['nom'] as String? ?? '',
        description: json['description'] as String? ?? '',
        ordre: json['ordre'] as int? ?? 0,
        durationMinutes: DurationUtils.parse(json['tempsMinutes'] ?? json['durationMinutes']),
      );

  Map<String, dynamic> toJson() => {
        'nom': nom,
        'description': description,
        'ordre': ordre,
        'durationMinutes': durationMinutes,
      };
}
