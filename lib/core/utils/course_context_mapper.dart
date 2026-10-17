import 'package:flutter/material.dart';

/// Utilitaire pour mapper les contextes de cours vers des icônes et couleurs adaptées
class CourseContextMapper {
  /// Retourne l'icône appropriée selon le contexte du cours
  static IconData getIconForContext(String? contexte) {
    switch (contexte?.toLowerCase()) {
      case 'informatique':
        return Icons.computer_rounded;
      case 'code':
        return Icons.code_rounded;
      case 'droit':
        return Icons.gavel_rounded;
      case 'math':
      case 'mathematiques':
        return Icons.calculate_rounded;
      case 'science':
        return Icons.science_rounded;
      case 'histoire':
        return Icons.history_edu_rounded;
      case 'langue':
      case 'litterature':
        return Icons.translate_rounded;
      case 'economie':
      case 'finance':
        return Icons.trending_up_rounded;
      case 'art':
        return Icons.palette_rounded;
      case 'sante':
      case 'medecine':
        return Icons.local_hospital_rounded;
      case 'geographie':
        return Icons.public_rounded;
      case 'philosophie':
        return Icons.psychology_rounded;
      case 'physique':
        return Icons.bolt_rounded;
      case 'chimie':
        return Icons.science_rounded;
      case 'biologie':
        return Icons.eco_rounded;
      case 'musique':
        return Icons.music_note_rounded;
      case 'sport':
        return Icons.sports_rounded;
      case 'cuisine':
        return Icons.restaurant_rounded;
      case 'psychologie':
        return Icons.psychology_alt_rounded;
      default:
        return Icons.menu_book_rounded;
    }
  }

  /// Retourne la couleur thématique appropriée selon le contexte du cours
  static Color getColorForContext(String? contexte) {
    switch (contexte?.toLowerCase()) {
      case 'informatique':
        return const Color(0xFF3498DB); // Bleu tech
      case 'code':
        return const Color(0xFF2ECC71); // Vert code
      case 'droit':
        return const Color(0xFF8E44AD); // Violet justice
      case 'math':
      case 'mathematiques':
        return const Color(0xFFE67E22); // Orange math
      case 'science':
        return const Color(0xFF1ABC9C); // Turquoise science
      case 'histoire':
        return const Color(0xFFC0392B); // Rouge histoire
      case 'langue':
      case 'litterature':
        return const Color(0xFF9B59B6); // Violet langue
      case 'economie':
      case 'finance':
        return const Color(0xFF27AE60); // Vert finance
      case 'art':
        return const Color(0xFFE91E63); // Rose art
      case 'sante':
      case 'medecine':
        return const Color(0xFFFF5722); // Orange santé
      case 'geographie':
        return const Color(0xFF00BCD4); // Cyan géo
      case 'philosophie':
        return const Color(0xFF673AB7); // Deep purple philo
      case 'physique':
        return const Color(0xFF3F51B5); // Indigo physique
      case 'chimie':
        return const Color(0xFF00E676); // Vert chimie
      case 'biologie':
        return const Color(0xFF4CAF50); // Vert nature
      case 'musique':
        return const Color(0xFFFF9800); // Orange musique
      case 'sport':
        return const Color(0xFFFF5722); // Rouge sport
      case 'cuisine':
        return const Color(0xFFFF7043); // Corail cuisine
      case 'psychologie':
        return const Color(0xFF795548); // Marron psycho
      default:
        return const Color(0xFF607D8B); // Bleu gris par défaut
    }
  }

  /// Retourne le label d'affichage du contexte
  static String getLabelForContext(String? contexte) {
    switch (contexte?.toLowerCase()) {
      case 'informatique':
        return 'Informatique';
      case 'code':
        return 'Programmation';
      case 'droit':
        return 'Droit';
      case 'math':
      case 'mathematiques':
        return 'Mathématiques';
      case 'science':
        return 'Sciences';
      case 'histoire':
        return 'Histoire';
      case 'langue':
        return 'Langues';
      case 'litterature':
        return 'Littérature';
      case 'economie':
        return 'Économie';
      case 'finance':
        return 'Finance';
      case 'art':
        return 'Arts';
      case 'sante':
        return 'Santé';
      case 'medecine':
        return 'Médecine';
      case 'geographie':
        return 'Géographie';
      case 'philosophie':
        return 'Philosophie';
      case 'physique':
        return 'Physique';
      case 'chimie':
        return 'Chimie';
      case 'biologie':
        return 'Biologie';
      case 'musique':
        return 'Musique';
      case 'sport':
        return 'Sport';
      case 'cuisine':
        return 'Cuisine';
      case 'psychologie':
        return 'Psychologie';
      default:
        return 'Général';
    }
  }

  /// Retourne une liste de tous les contextes disponibles
  static List<String> getAllContexts() {
    return [
      'informatique',
      'code',
      'droit',
      'math',
      'science',
      'histoire',
      'langue',
      'economie',
      'art',
      'sante',
      'geographie',
      'philosophie',
      'physique',
      'chimie',
      'biologie',
      'musique',
      'sport',
      'cuisine',
      'psychologie',
    ];
  }

  /// Retourne le chemin de l'icône SVG adaptée pour le cours en fallback
  static String getSvgForCourse(String titre, [IconData? icon]) {
    final t = titre.toLowerCase();
    if (t.contains('code') ||
        t.contains('algo') ||
        t.contains('dev') ||
        t.contains('programmation') ||
        t.contains('python') ||
        t.contains('dart')) {
      return 'assets/icons/outline/code.svg';
    }
    if (t.contains('computer') ||
        t.contains('ordi') ||
        t.contains('systeme') ||
        t.contains('système') ||
        t.contains('reseau') ||
        t.contains('réseau') ||
        t.contains('informatique')) {
      return 'assets/icons/outline/code.svg';
    }
    if (t.contains('math') ||
        t.contains('calcul') ||
        t.contains('algebre') ||
        t.contains('algèbre') ||
        t.contains('geometrie') ||
        t.contains('géométrie')) {
      return 'assets/icons/outline/brain.svg';
    }
    if (t.contains('physique') ||
        t.contains('chimie') ||
        t.contains('science') ||
        t.contains('labo')) {
      return 'assets/icons/outline/flask.svg';
    }
    if (t.contains('bio') ||
        t.contains('plante') ||
        t.contains('agri') ||
        t.contains('agro') ||
        t.contains('elevage') ||
        t.contains('élevage') ||
        t.contains('ecologie') ||
        t.contains('écologie') ||
        t.contains('nature')) {
      return 'assets/icons/outline/leaf.svg';
    }
    if (t.contains('droit') || t.contains('loi') || t.contains('justice')) {
      return 'assets/icons/outline/scale.svg';
    }
    if (t.contains('sante') ||
        t.contains('santé') ||
        t.contains('medecine') ||
        t.contains('médecine')) {
      return 'assets/icons/outline/heart.svg';
    }
    if (t.contains('langue') ||
        t.contains('anglais') ||
        t.contains('francais') ||
        t.contains('français') ||
        t.contains('traduction')) {
      return 'assets/icons/outline/language.svg';
    }
    if (t.contains('histoire') ||
        t.contains('civilisation') ||
        t.contains('archeologie')) {
      return 'assets/icons/outline/history.svg';
    }
    if (t.contains('art') ||
        t.contains('dessin') ||
        t.contains('peinture') ||
        t.contains('design')) {
      return 'assets/icons/outline/palette.svg';
    }
    if (t.contains('musique') || t.contains('piano') || t.contains('guitare')) {
      return 'assets/icons/outline/music.svg';
    }
    if (t.contains('argent') ||
        t.contains('finance') ||
        t.contains('economie') ||
        t.contains('économie') ||
        t.contains('compta')) {
      return 'assets/icons/outline/coin.svg';
    }
    if (t.contains('geo') ||
        t.contains('géo') ||
        t.contains('terre') ||
        t.contains('monde')) {
      return 'assets/icons/outline/world.svg';
    }
    return 'assets/icons/outline/book.svg';
  }
}

