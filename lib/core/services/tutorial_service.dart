import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  static const _dashboardKey = 'tutorial_done_dashboard_v1';
  static const _legacyKey = 'tutorial_done_v1';

  static String _formatKey([String? tutorialId]) =>
      tutorialId != null ? 'tutorial_done_${tutorialId}_v1' : _dashboardKey;

  /// Retourne true si le tutoriel n'a jamais été complété pour ce module / écran
  static Future<bool> shouldShow([String? tutorialId]) async {
    final prefs = await SharedPreferences.getInstance();
    if (tutorialId == null && (prefs.getBool(_legacyKey) ?? false)) {
      return false;
    }
    final key = _formatKey(tutorialId);
    return !(prefs.getBool(key) ?? false);
  }

  /// Marque le tutoriel comme complété
  static Future<void> markDone([String? tutorialId]) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _formatKey(tutorialId);
    await prefs.setBool(key, true);
    if (tutorialId == null) {
      await prefs.setBool(_legacyKey, true);
    }
  }

  /// Réinitialise pour revoir le tuto
  static Future<void> reset([String? tutorialId]) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _formatKey(tutorialId);
    await prefs.remove(key);
    if (tutorialId == null) {
      await prefs.remove(_legacyKey);
    }
  }

  /// Réinitialise tous les tutoriels de l'application
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('tutorial_done_')).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
