import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  static const _key = 'tutorial_done_v1';

  /// Retourne true si le tutoriel n'a jamais été complété
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_key) ?? false);
  }

  /// Marque le tutoriel comme complété
  static Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  /// Réinitialise pour revoir le tuto (appelé depuis le bouton !)
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
