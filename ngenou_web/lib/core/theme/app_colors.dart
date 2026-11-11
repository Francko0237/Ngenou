import 'package:flutter/material.dart';

/// Palette de couleurs officielle de Ngenou Web
class AppColors {
  AppColors._();

  // Couleurs principales définies dans le cahier des charges
  static const Color background = Color(0xFF060B1A);
  static const Color card = Color(0xFF0F1A33);
  static const Color cardBorder = Color(0xFF1E2E52);
  static const Color cardHover = Color(0xFF152345);

  static const Color cyan = Color(0xFF3CC8E8);
  static const Color gold = Color(0xFFF0B93A);
  static const Color text = Color(0xFFF3EEE2);
  static const Color textMuted = Color(0xFF9BA8C4);

  // Couleurs d'état
  static const Color error = Color(0xFFFF5C5C);
  static const Color success = Color(0xFF2DD4BF);
  static const Color warning = Color(0xFFF59E0B);

  // Dégradé emblématique bleu -> or (réservé aux mots et actions clés)
  static const LinearGradient brandGradient = LinearGradient(
    colors: [cyan, gold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGlowCyan = LinearGradient(
    colors: [Color(0x333CC8E8), Colors.transparent],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGlowGold = LinearGradient(
    colors: [Color(0x33F0B93A), Colors.transparent],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
