import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseCredentials {
  // Remplacer par l'URL et la clé anonyme de votre projet Supabase
  static const String url = "https://qfthojymggrpdxfhhzii.supabase.co";
  static const String anonKey = "sb_publishable_eJiqM3WJki2ABQkvqxyq7A_daq6gfsB";

  static bool get isValid =>
      url.isNotEmpty &&
      url.startsWith("https://") &&
      !url.contains("YOUR_PROJECT_ID") &&
      anonKey.isNotEmpty &&
      anonKey != "YOUR_ANON_KEY";

  static Future<void> init() async {
    if (!isValid) {
      debugPrint('⚠️ Supabase non configuré ou identifiants invalides.');
      return;
    }
    try {
      await Supabase.initialize(
        url: url,
        // ignore: deprecated_member_use
        anonKey: anonKey,
      );
      debugPrint('✅ Supabase initialisé avec succès.');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'initialisation de Supabase: $e');
    }
  }
}
