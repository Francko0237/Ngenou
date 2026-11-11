import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuration et initialisation sécurisée de Supabase
/// Les clés peuvent être injectées via --dart-define ou utiliser les clés par défaut du projet
class SupabaseConfig {
  SupabaseConfig._();

  static const String _defaultUrl = 'https://boarzpbrrztqjfnuckxq.supabase.co';
  static const String _defaultAnonKey =
      'sb_publishable_-705eJ--wBQYCGLFxgU1Vw_RMNgYM5K';

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _defaultUrl,
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: _defaultAnonKey,
  );

  /// Vérifie si les variables d'environnement sont correctement renseignées
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static SupabaseClient get client => Supabase.instance.client;

  /// Initialise Supabase
  static Future<void> initialize() async {
    if (!isConfigured) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ SUPABASE_URL ou SUPABASE_ANON_KEY non définis. '
          'L\'application utilisera le mode hors-ligne / démonstration.',
        );
      }
      return;
    }

    try {
      // ignore: deprecated_member_use
      await Supabase.initialize(
        url: supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: supabaseAnonKey,
        debug: kDebugMode,
      );
      if (kDebugMode) {
        debugPrint('✅ Supabase connecté avec succès ($supabaseUrl)');
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'initialisation de Supabase : $e');
    }
  }
}
