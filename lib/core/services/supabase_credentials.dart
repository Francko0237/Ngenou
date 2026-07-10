import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseCredentials {
  // Remplacer par l'URL et la clé anonyme de votre projet Supabase
  static const String url = "https://boarzpbrrztqjfnuckxq.supabase.co";
  static const String anonKey = "sb_publishable_-705eJ--wBQYCGLFxgU1Vw_RMNgYM5K";

  static bool get isValid =>
      url.isNotEmpty &&
      url.startsWith("https://") &&
      !url.contains("YOUR_PROJECT_ID") &&
      anonKey.isNotEmpty &&
      anonKey != "YOUR_ANON_KEY";

  static Future<void> init() async {
    if (!isValid) {
      print("Supabase non configuré ou identifiants invalides.");
      return;
    }
    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
      print("Supabase initialisé avec succès.");
    } catch (e) {
      print("Erreur lors de l'initialisation de Supabase: $e");
    }
  }
}
