import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuration et initialisation sécurisée de Supabase
/// Les clés sont injectées au build via --dart-define
class SupabaseConfig {
  SupabaseConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Vérifie si les variables d'environnement sont correctement renseignées
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static SupabaseClient get client => Supabase.instance.client;

  /// Initialise Supabase si les variables sont présentes
  static Future<void> initialize() async {
    if (!isConfigured) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ SUPABASE_URL ou SUPABASE_ANON_KEY non définis via --dart-define. '
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
    } catch (e) {
      debugPrint('Erreur lors de l\'initialisation de Supabase : $e');
    }
  }
}
