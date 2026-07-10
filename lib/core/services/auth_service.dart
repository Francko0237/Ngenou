import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;
  static const String _localUsernameKey = 'local_username';
  static const String _localPhoneKey = 'local_phone';

  // Domaine interne utilisé pour transformer un numéro de téléphone en email
  // virtuel afin d'éviter d'avoir besoin du fournisseur SMS de Supabase.
  static const String _phoneDomain = 'ngenou.app';

  /// Flux de changement d'état d'authentification
  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  /// Utilisateur actuel
  static User? get currentUser => _client.auth.currentUser;

  /// Vérifie si l'utilisateur est connecté
  static bool get isAuthenticated => currentUser != null;

  /// Convertit un numéro de téléphone en adresse email virtuelle interne.
  /// Ex: "+237670619582" → "tel_237670619582@ngenou.app"
  static String _phoneToVirtualEmail(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return 'tel_$digits@$_phoneDomain';
  }

  /// Récupère le nom d'utilisateur.
  /// Priorité : 1) username des métadonnées Supabase (source de vérité)
  ///            2) username en cache local (SharedPreferences)
  ///            3) prénom Google (fallback)
  ///            4) fallback 'Ami'
  static Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();

    // Si l'utilisateur est connecté, la source de vérité est Supabase
    if (isAuthenticated && currentUser?.userMetadata != null) {
      final meta = currentUser!.userMetadata!;

      // Auth téléphone/email : clé 'username' définie à l'inscription
      final username = meta['username'] as String?;
      if (username != null && username.trim().isNotEmpty) {
        await prefs.setString(_localUsernameKey, username.trim());
        return username.trim();
      }

      // Auth Google : utiliser le prénom
      final fullName = (meta['full_name'] ?? meta['name']) as String?;
      if (fullName != null && fullName.trim().isNotEmpty) {
        final firstName = fullName.trim().split(' ').first;
        await prefs.setString(_localUsernameKey, firstName);
        return firstName;
      }
    }

    // Fallback : cache local (offline ou utilisateur non connecté)
    final localUsername = prefs.getString(_localUsernameKey);
    if (localUsername != null && localUsername.trim().isNotEmpty) {
      return localUsername.trim();
    }

    return 'Ami';
  }

  /// Récupère le numéro de téléphone sauvegardé localement (si auth par téléphone)
  static Future<String?> getSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_localPhoneKey);
  }

  /// Met à jour le nom d'utilisateur localement et sur Supabase si connecté
  static Future<void> updateUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localUsernameKey, username);

    if (isAuthenticated) {
      await _client.auth.updateUser(
        UserAttributes(data: {'username': username}),
      );
    }
  }

  // ─── TÉLÉPHONE + MOT DE PASSE ────────────────────────────────────────────
  // Supabase Phone Provider nécessite un SMS OTP.
  // On contourne en stockant le numéro dans les métadonnées et en utilisant
  // une adresse email virtuelle interne pour l'authentification.

  /// Inscription avec Téléphone + Mot de passe (sans OTP)
  static Future<AuthResponse> signUpWithPhone({
    required String phone,
    required String password,
    required String username,
  }) async {
    final virtualEmail = _phoneToVirtualEmail(phone);

    final response = await _client.auth.signUp(
      email: virtualEmail,
      password: password,
      data: {'username': username, 'phone': phone, 'auth_method': 'phone'},
    );

    // Sauvegarder localement
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localUsernameKey, username);
    await prefs.setString(_localPhoneKey, phone);

    return response;
  }

  /// Connexion avec Téléphone + Mot de passe (sans OTP)
  static Future<AuthResponse> signInWithPhone({
    required String phone,
    required String password,
  }) async {
    final virtualEmail = _phoneToVirtualEmail(phone);

    final response = await _client.auth.signInWithPassword(
      email: virtualEmail,
      password: password,
    );

    // Si connecté, stocker le username et le téléphone de Supabase en local
    final prefs = await SharedPreferences.getInstance();
    if (response.user?.userMetadata != null) {
      final remoteUsername =
          response.user!.userMetadata!['username'] as String?;
      if (remoteUsername != null) {
        await prefs.setString(_localUsernameKey, remoteUsername);
      }
    }
    await prefs.setString(_localPhoneKey, phone);

    return response;
  }

  // ─── EMAIL + MOT DE PASSE ────────────────────────────────────────────────

  /// Inscription avec Email + Mot de passe
  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username, 'auth_method': 'email'},
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localUsernameKey, username);

    return response;
  }

  /// Connexion avec Email + Mot de passe
  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    // Récupérer le username depuis Supabase
    if (response.user?.userMetadata != null) {
      final remoteUsername =
          response.user!.userMetadata!['username'] as String?;
      if (remoteUsername != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_localUsernameKey, remoteUsername);
      }
    }

    return response;
  }

  // ─── GOOGLE ──────────────────────────────────────────────────────────────
  // Utilise le flux natif `google_sign_in` v7 + `signInWithIdToken` pour éviter
  // le redirect vers le navigateur. Le sélecteur de compte Google s'affiche
  // directement dans l'app, et le token ID est échangé avec Supabase.
  //
  // IMPORTANT : _googleServerClientId doit être le Client ID de type
  // "Web application" créé dans Google Cloud Console — c'est celui
  // visible dans Supabase > Authentication > Providers > Google > Client IDs.

  static const String _googleServerClientId =
      '285628608077-ds4a8oeveus9k00g9q55cgnubgtsvdmq.apps.googleusercontent.com';

  static bool _googleSignInInitialized = false;

  /// Connexion avec Google via le sélecteur de compte natif (sans navigateur)
  static Future<bool> signInWithGoogle() async {
    try {
      print("=== GOOGLE SIGN-IN START ===");

      // Initialiser une seule fois
      if (!_googleSignInInitialized) {
        print(
          "=== Initializing GoogleSignIn with serverClientId: $_googleServerClientId ===",
        );
        await GoogleSignIn.instance.initialize(
          serverClientId: _googleServerClientId,
        );
        _googleSignInInitialized = true;
        print("=== GoogleSignIn initialized OK ===");
      }

      // Déconnecter l'éventuel compte précédent pour forcer le sélecteur
      print("=== Signing out previous session... ===");
      await GoogleSignIn.instance.signOut();
      print("=== SignOut OK, calling authenticate... ===");

      // Déclencher l'authentification interactive
      final googleUser = await GoogleSignIn.instance.authenticate();
      print("=== Authenticated as: ${googleUser.email} ===");

      final idToken = googleUser.authentication.idToken;
      print("=== idToken is ${idToken == null ? 'NULL ❌' : 'present ✓'} ===");

      if (idToken == null) {
        throw Exception('Google ID token introuvable.');
      }

      print("=== Calling Supabase signInWithIdToken... ===");
      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      print("=== Supabase signInWithIdToken OK ===");

      // Résoudre le nom à afficher après connexion Google.
      // Priorité stricte :
      //   1. username personnalisé stocké dans les métadonnées Supabase (via updateUsername)
      //   2. nom déjà enregistré localement (nom changé dans les paramètres)
      //   3. prénom Google (fallback uniquement si rien n'est défini)
      final prefs = await SharedPreferences.getInstance();
      final meta = _client.auth.currentUser?.userMetadata;
      if (meta != null) {
        // 1. Priorité : username personnalisé dans les métadonnées Supabase
        final customUsername = meta['username'] as String?;
        if (customUsername != null && customUsername.trim().isNotEmpty) {
          await prefs.setString(_localUsernameKey, customUsername.trim());
        } else {
          // 2. Ne pas écraser si un nom local existe déjà
          final existingLocal = prefs.getString(_localUsernameKey);
          if (existingLocal == null || existingLocal.trim().isEmpty) {
            // 3. Fallback : prénom Google uniquement si rien n'est défini
            final fullName = (meta['full_name'] ?? meta['name']) as String?;
            if (fullName != null && fullName.trim().isNotEmpty) {
              final firstName = fullName.trim().split(' ').first;
              await prefs.setString(_localUsernameKey, firstName);
            }
          }
        }
      }

      return true;
    } on GoogleSignInException catch (e) {
      print(
        "=== GoogleSignInException: code=${e.code} description=${e.description} ===",
      );
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return false; // L'utilisateur a vraiment annulé
      }
      throw Exception("Google Sign-In échoué (${e.code}): ${e.description}");
    } catch (e, stack) {
      print("=== Google Sign-In CATCH: $e ===");
      print("=== StackTrace: $stack ===");
      rethrow;
    }
  }

  // ─── DÉCONNEXION ─────────────────────────────────────────────────────────

  /// Déconnexion et purge des données locales
  static Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint("Erreur de déconnexion distante: $e");
    } finally {
      // Purger toujours les données locales pour éviter les mélanges de comptes
      await DatabaseHelper.instance.clearLocalData();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localPhoneKey);
      // Supprimer le username local pour qu'un autre utilisateur
      // ne voie pas le nom du compte précédent
      await prefs.remove(_localUsernameKey);
    }
  }
}
