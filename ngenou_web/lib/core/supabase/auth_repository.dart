import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

/// Repository gérant l'authentification et la vérification des droits administrateur
class AuthRepository {
  final SupabaseClient? _client;

  AuthRepository([SupabaseClient? client])
      : _client = client ?? (SupabaseConfig.isConfigured ? SupabaseConfig.client : null);

  /// Session courante
  Session? get currentSession => _client?.auth.currentSession;

  /// Utilisateur courant
  User? get currentUser => _client?.auth.currentUser;

  /// Stream des changements d'authentification
  Stream<AuthState> get authStateChanges =>
      _client?.auth.onAuthStateChange ?? const Stream.empty();

  /// Connexion email / mot de passe
  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase n\'est pas configuré avec des clés valides.');
    }

    return await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Vérifie si l'utilisateur actuellement connecté est répertorié dans admin_users
  Future<bool> verifyIsAdmin() async {
    final client = _client;
    if (client == null) return false;

    final user = client.auth.currentUser;
    if (user == null) return false;

    try {
      final res = await client
          .from('admin_users')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();

      return res != null;
    } catch (e) {
      debugPrint('Erreur lors de la vérification admin: $e');
      return false;
    }
  }

  /// Déconnexion
  Future<void> signOut() async {
    final client = _client;
    if (client == null) return;
    await client.auth.signOut();
  }
}
