import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'email_service.dart';
import 'supabase_credentials.dart';

class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;
  static const String _localUsernameKey = 'local_username';
  static const String _localPhoneKey = 'local_phone';
  static const String _localRoleKey = 'local_user_role';
  static const String _localLevelKey = 'local_school_level';

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
  /// Récupère le rôle de l'utilisateur (student, teacher, admin).
  static Future<String> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (isAuthenticated && currentUser?.userMetadata != null) {
      final role = currentUser!.userMetadata!['role'] as String?;
      if (role != null && role.isNotEmpty) {
        await prefs.setString(_localRoleKey, role);
        return role;
      }
    }
    return prefs.getString(_localRoleKey) ?? 'student';
  }

  /// Récupère le niveau scolaire de l'élève (primaire, secondaire, superieur).
  static Future<String?> getSchoolLevel() async {
    final prefs = await SharedPreferences.getInstance();
    if (isAuthenticated && currentUser?.userMetadata != null) {
      final level = currentUser!.userMetadata!['school_level'] as String?;
      if (level != null && level.isNotEmpty) {
        final normalized = (level == 'college' || level == 'lycee')
            ? 'secondaire'
            : level;
        await prefs.setString(_localLevelKey, normalized);
        return normalized;
      }
    }
    final local = prefs.getString(_localLevelKey);
    if (local == 'college' || local == 'lycee') {
      await prefs.setString(_localLevelKey, 'secondaire');
      return 'secondaire';
    }
    return local;
  }

  /// Met à jour le rôle localement et sur Supabase
  static Future<void> updateUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localRoleKey, role);
    if (isAuthenticated) {
      await _client.auth.updateUser(
        UserAttributes(data: {'role': role}),
      );
    }
  }

  /// Met à jour le niveau scolaire localement et sur Supabase
  static Future<void> updateSchoolLevel(String schoolLevel) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localLevelKey, schoolLevel);
    if (isAuthenticated) {
      try {
        await _client.auth.updateUser(
          UserAttributes(data: {'school_level': schoolLevel}),
        );
      } on AuthException catch (e) {
        if (schoolLevel == 'secondaire' &&
            e.message.contains('profiles_school_level_check')) {
          // Fallback rétrocompatible si la base Supabase n'a pas encore exécuté la migration
          await _client.auth.updateUser(
            UserAttributes(data: {'school_level': 'college'}),
          );
        } else {
          rethrow;
        }
      }
    }
  }

  static Future<void> updateUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localUsernameKey, username);

    if (isAuthenticated) {
      await _client.auth.updateUser(
        UserAttributes(data: {'username': username}),
      );
    }
  }

  /// Récupère l'identifiant de contact (téléphone ou email)
  static Future<String?> getContactIdentifier() async {
    final phone = await getSavedPhone();
    if (phone != null && phone.trim().isNotEmpty) return phone.trim();
    if (isAuthenticated && currentUser?.email != null) {
      final email = currentUser!.email!;
      if (!email.endsWith('@ngenou.internal')) return email;
    }
    final metaPhone = currentUser?.userMetadata?['phone'] as String?;
    if (metaPhone != null && metaPhone.trim().isNotEmpty) return metaPhone.trim();
    return null;
  }

  /// Met à jour le contact (téléphone ou email dans les métadonnées)
  static Future<void> updateContact(String contact) async {
    final trimmed = contact.trim();
    final isPhone = RegExp(r'^\+?[0-9\s\-]{6,}$').hasMatch(trimmed);
    final prefs = await SharedPreferences.getInstance();
    if (isPhone) {
      await prefs.setString(_localPhoneKey, trimmed);
    }
    if (isAuthenticated) {
      await _client.auth.updateUser(
        UserAttributes(data: isPhone ? {'phone': trimmed} : {'contact_email': trimmed}),
      );
    }
  }

  /// Alias pour updateUserRole
  static Future<void> updateRole(String role) => updateUserRole(role);


  // ─── TÉLÉPHONE + MOT DE PASSE ────────────────────────────────────────────
  // Supabase Phone Provider nécessite un SMS OTP.
  // On contourne en stockant le numéro dans les métadonnées et en utilisant
  // une adresse email virtuelle interne pour l'authentification.

  /// Inscription avec Téléphone + Mot de passe (sans OTP)
  static Future<AuthResponse> signUpWithPhone({
    required String phone,
    required String password,
    required String username,
    String role = 'student',
    String? schoolLevel,
  }) async {
    final virtualEmail = _phoneToVirtualEmail(phone);

    AuthResponse response;
    try {
      response = await _client.auth.signUp(
        email: virtualEmail,
        password: password,
        data: {
          'username': username,
          'phone': phone,
          'role': role,
          if (schoolLevel != null) 'school_level': schoolLevel,
          'auth_method': 'phone',
        },
      );
    } on AuthException catch (e) {
      if (schoolLevel == 'secondaire' &&
          e.message.contains('profiles_school_level_check')) {
        // Fallback si la table Supabase n'a pas encore exécuté la migration 'secondaire'
        response = await _client.auth.signUp(
          email: virtualEmail,
          password: password,
          data: {
            'username': username,
            'phone': phone,
            'role': role,
            'school_level': 'college',
            'auth_method': 'phone',
          },
        );
      } else {
        rethrow;
      }
    }

    // Sauvegarder localement
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localUsernameKey, username);
    await prefs.setString(_localPhoneKey, phone);
    await prefs.setString(_localRoleKey, role);
    if (schoolLevel != null) {
      await prefs.setString(_localLevelKey, schoolLevel);
    }

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

    // Si connecté, stocker le username, le rôle et le niveau en local
    final prefs = await SharedPreferences.getInstance();
    if (response.user?.userMetadata != null) {
      final meta = response.user!.userMetadata!;
      final remoteUsername = meta['username'] as String?;
      if (remoteUsername != null) {
        await prefs.setString(_localUsernameKey, remoteUsername);
      }
      final remoteRole = meta['role'] as String?;
      if (remoteRole != null) {
        await prefs.setString(_localRoleKey, remoteRole);
      }
      final remoteLevel = meta['school_level'] as String?;
      if (remoteLevel != null) {
        final normalized = (remoteLevel == 'college' || remoteLevel == 'lycee')
            ? 'secondaire'
            : remoteLevel;
        await prefs.setString(_localLevelKey, normalized);
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
    String role = 'student',
    String? schoolLevel,
  }) async {
    AuthResponse response;
    try {
      response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'role': role,
          if (schoolLevel != null) 'school_level': schoolLevel,
          'auth_method': 'email',
        },
      );
    } on AuthException catch (e) {
      if (schoolLevel == 'secondaire' &&
          e.message.contains('profiles_school_level_check')) {
        // Fallback si la table Supabase n'a pas encore exécuté la migration 'secondaire'
        response = await _client.auth.signUp(
          email: email,
          password: password,
          data: {
            'username': username,
            'role': role,
            'school_level': 'college',
            'auth_method': 'email',
          },
        );
      } else {
        rethrow;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localUsernameKey, username);
    await prefs.setString(_localRoleKey, role);
    if (schoolLevel != null) {
      await prefs.setString(_localLevelKey, schoolLevel);
    }

    // ── Auto-connexion immédiate ──────────────────────────────────────────────
    // Si Supabase demande une confirmation d'email (session == null mais user != null),
    // on connecte l'utilisateur directement sans bloquer sur la confirmation.
    // C'est l'approche correcte pour une application mobile.
    if (response.session == null && response.user != null) {
      debugPrint('[AuthService] Pas de session après signup → tentative de connexion directe...');
      try {
        final signInResponse = await _client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (signInResponse.session != null) {
          debugPrint('[AuthService] ✅ Connexion directe réussie après inscription.');
          response = signInResponse;
        }
      } on AuthException catch (signInErr) {
        // Si email_not_confirmed, l'utilisateur devra confirmer — on retourne quand même
        // la réponse signup originale pour que l'UI puisse afficher un message adapté.
        debugPrint('[AuthService] Connexion directe échouée : ${signInErr.message}');
      }
    }

    // Envoi de l'e-mail de bienvenue personnalisé (direct Gmail SMTP)
    if (response.user != null) {
      await prefs.setBool('welcome_email_sent_${response.user!.id}', true);
    }
    EmailService.sendWelcomeEmail(
      toEmail: email,
      username: username,
    ).then((sent) {
      debugPrint('[AuthService] ✅ E-mail de bienvenue envoyé : $sent');
    }).catchError((Object e) {
      debugPrint('[AuthService] ⚠️ Erreur e-mail de bienvenue : $e');
    });

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

    // Récupérer le username, rôle et niveau depuis Supabase
    if (response.user?.userMetadata != null) {
      final meta = response.user!.userMetadata!;
      final prefs = await SharedPreferences.getInstance();
      final remoteUsername = meta['username'] as String?;
      if (remoteUsername != null) {
        await prefs.setString(_localUsernameKey, remoteUsername);
      }
      final remoteRole = meta['role'] as String?;
      if (remoteRole != null) {
        await prefs.setString(_localRoleKey, remoteRole);
      }
      final remoteLevel = meta['school_level'] as String?;
      if (remoteLevel != null) {
        final normalized = (remoteLevel == 'college' || remoteLevel == 'lycee')
            ? 'secondaire'
            : remoteLevel;
        await prefs.setString(_localLevelKey, normalized);
      }
    }

    return response;
  }

  /// Vérifie si une adresse e-mail existe dans la base de données
  static Future<bool> checkEmailExists(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) return false;
    try {
      final res = await _client.rpc(
        'check_email_exists',
        params: {'email_to_check': cleanEmail},
      );
      if (res is bool) return res;
      return false;
    } catch (e) {
      debugPrint('[AuthService] Erreur checkEmailExists: $e');
      // En cas d'erreur de connexion RPC, on autorise la tentative
      return true;
    }
  }

  /// Envoie un e-mail avec le code de sécurité pour réinitialiser le mot de passe
  static Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  /// Vérifie le code de récupération (OTP) envoyé par e-mail
  static Future<AuthResponse> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanToken = token.trim();
    return await _client.auth.verifyOTP(
      email: cleanEmail,
      token: cleanToken,
      type: OtpType.recovery,
    );
  }

  /// Met à jour le mot de passe de l'utilisateur (après réinitialisation ou dans les paramètres)
  static Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  /// Renvoie un e-mail de confirmation d'inscription
  static Future<void> resendVerificationEmail(String email) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
    );
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

  /// Connexion avec Google (supporte Mobile via sélecteur natif et Desktop Linux/Windows via navigateur)
  static Future<bool> signInWithGoogle() async {
    try {
      debugPrint('=== GOOGLE SIGN-IN START ===');

      // Sur Linux / Windows Desktop, le plugin natif google_sign_in n'existe pas.
      // On utilise le flux OAuth standard Supabase avec le navigateur par défaut.
      if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
        debugPrint('=== Exécution du flux OAuth Google Desktop (Linux/Windows) ===');
        return await _signInWithGoogleDesktop();
      }

      // Initialiser une seule fois (Android, iOS, macOS, Web)
      if (!_googleSignInInitialized) {
        debugPrint(
          '=== Initializing GoogleSignIn with serverClientId: $_googleServerClientId ===',
        );
        await GoogleSignIn.instance.initialize(
          serverClientId: _googleServerClientId,
        );
        _googleSignInInitialized = true;
        debugPrint('=== GoogleSignIn initialized OK ===');
      }

      // Déconnecter l'éventuel compte précédent pour forcer le sélecteur
      debugPrint('=== Signing out previous session... ===');
      await GoogleSignIn.instance.signOut();
      debugPrint('=== SignOut OK, calling authenticate... ===');

      // Déclencher l'authentification interactive
      final googleUser = await GoogleSignIn.instance.authenticate();
      debugPrint('=== Authenticated as: ${googleUser.email} ===');

      final idToken = googleUser.authentication.idToken;
      debugPrint("=== idToken is ${idToken == null ? 'NULL ❌' : 'present ✓'} ===");

      if (idToken == null) {
        throw Exception('Google ID token introuvable.');
      }

      debugPrint('=== Calling Supabase signInWithIdToken... ===');
      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      debugPrint('=== Supabase signInWithIdToken OK ===');

      await _resolvePostSignInMetadata();

      return true;
    } on GoogleSignInException catch (e) {
      debugPrint(
        '=== GoogleSignInException: code=${e.code} description=${e.description} ===',
      );
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return false; // L'utilisateur a vraiment annulé
      }
      throw Exception("Google Sign-In échoué (${e.code}): ${e.description}");
    } catch (e, stack) {
      debugPrint('=== Google Sign-In CATCH: $e ===');
      debugPrint('=== StackTrace: $stack ===');
      rethrow;
    }
  }

  /// Connexion avec Google sous Linux / Windows (Desktop) via navigateur et serveur loopback local
  static Future<bool> _signInWithGoogleDesktop() async {
    HttpServer? server;
    try {
      try {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 3000);
      } catch (_) {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      }
      final port = server.port;
      // On pointe le redirect_to vers /callback afin que Supabase y envoie
      // le code PKCE directement en query params (évite le fragment hash JS).
      final redirectUrl = 'http://localhost:$port/callback';

      final authUri = Uri.parse(
        '${SupabaseCredentials.url}/auth/v1/authorize?provider=google&redirect_to=${Uri.encodeComponent(redirectUrl)}',
      );

      final launched = await launchUrl(authUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception('Impossible d\'ouvrir le navigateur web pour l\'authentification Google.');
      }

      final completer = Completer<bool>();

      final subscription = server.listen((HttpRequest request) async {
        final uri = request.uri;

        // Si c'est une requête pour /callback (redirection depuis le hash JS)
        // on traite le code ici sans renvoyer de page HTML
        final isCallback = uri.path == '/callback';

        if (!isCallback) {
          // Page initiale : extraire le fragment hash côté JS et rediriger vers /callback
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.html
            ..write('''<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <title>Connexion Ngenou</title>
</head>
<body style="background:#0B0F19;color:#CBD5E1;font-family:sans-serif;text-align:center;padding:60px 20px;">
  <h2 style="color:#38BDF8;">Connexion à Ngenou réussie ! 🎉</h2>
  <p>Votre compte est connecté. Vous pouvez retourner sur l'application.</p>
  <script>
    // Supabase peut renvoyer les tokens dans le fragment (#) ou en query params (?)
    var hash = window.location.hash;
    var search = window.location.search;
    if (hash && hash.length > 1) {
      // Rediriger vers /callback en convertissant le fragment en query params
      window.location.replace('/callback' + '?' + hash.substring(1));
    } else if (search && search.length > 1) {
      // Déjà en query params, rediriger vers /callback
      window.location.replace('/callback' + search);
    } else {
      // Aucun token trouvé, fermer dans 3 secondes
      setTimeout(function(){ window.close(); }, 3000);
    }
  </script>
</body>
</html>''');
          await request.response.close();
          return; // Ne pas traiter comme un callback
        }

        // Page /callback : répondre immédiatement et traiter les tokens
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..write('''<!DOCTYPE html>
<html lang="fr">
<head><meta charset="utf-8"><title>Ngenou</title></head>
<body style="background:#0B0F19;color:#CBD5E1;font-family:sans-serif;text-align:center;padding:60px 20px;">
  <h2 style="color:#38BDF8;">✅ Authentification réussie</h2>
  <p>Retournez sur l'application Ngenou.</p>
  <script>setTimeout(function(){ window.close(); }, 2000);</script>
</body>
</html>''');
        await request.response.close();

        final code = uri.queryParameters['code'];
        final refreshToken = uri.queryParameters['refresh_token'];

        if (code != null && code.isNotEmpty) {
          try {
            await _client.auth.exchangeCodeForSession(code);
            await _resolvePostSignInMetadata();
            if (!completer.isCompleted) completer.complete(true);
          } catch (e) {
            debugPrint('[AuthService] Erreur exchangeCodeForSession: $e');
            if (!completer.isCompleted) completer.completeError(e);
          }
        } else if (refreshToken != null && refreshToken.isNotEmpty) {
          try {
            await _client.auth.setSession(refreshToken);
            await _resolvePostSignInMetadata();
            if (!completer.isCompleted) completer.complete(true);
          } catch (e) {
            debugPrint('[AuthService] Erreur setSession(refreshToken): $e');
            if (!completer.isCompleted) completer.completeError(e);
          }
        } else if (uri.queryParameters.containsKey('access_token')) {
          try {
            await _client.auth.getSessionFromUrl(uri);
            await _resolvePostSignInMetadata();
            if (!completer.isCompleted) completer.complete(true);
          } catch (e) {
            debugPrint('[AuthService] Erreur getSessionFromUrl: $e');
            if (!completer.isCompleted) completer.completeError(e);
          }
        }
      });

      final result = await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          subscription.cancel();
          return false;
        },
      );
      await subscription.cancel();
      return result;
    } finally {
      await server?.close(force: true);
    }
  }

  /// Résout et enregistre les métadonnées (nom, rôle, niveau) après connexion
  static Future<void> _resolvePostSignInMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    final meta = _client.auth.currentUser?.userMetadata;
    if (meta != null) {
      final customUsername = meta['username'] as String?;
      if (customUsername != null && customUsername.trim().isNotEmpty) {
        await prefs.setString(_localUsernameKey, customUsername.trim());
      } else {
        final existingLocal = prefs.getString(_localUsernameKey);
        if (existingLocal == null || existingLocal.trim().isEmpty) {
          final fullName = (meta['full_name'] ?? meta['name']) as String?;
          if (fullName != null && fullName.trim().isNotEmpty) {
            final firstName = fullName.trim().split(' ').first;
            await prefs.setString(_localUsernameKey, firstName);
          }
        }
      }
      final customRole = meta['role'] as String?;
      if (customRole != null && customRole.isNotEmpty) {
        await prefs.setString(_localRoleKey, customRole);
      }
      final customLevel = meta['school_level'] as String?;
      if (customLevel != null && customLevel.isNotEmpty) {
        await prefs.setString(_localLevelKey, customLevel);
      }
    }

    // Envoi de l'e-mail de bienvenue lors de la première connexion (ex: Google / OAuth)
    final user = _client.auth.currentUser;
    if (user != null && user.email != null && user.email!.contains('@')) {
      final email = user.email!.trim();
      final welcomeKey = 'welcome_email_sent_${user.id}';
      final alreadySent = prefs.getBool(welcomeKey) ?? false;
      if (!alreadySent &&
          !email.endsWith('@ngenou.internal') &&
          !email.endsWith('@ngenou.app')) {
        await prefs.setBool(welcomeKey, true);
        final displayName = prefs.getString(_localUsernameKey) ?? 'Ami';
        EmailService.sendWelcomeEmail(
          toEmail: email,
          username: displayName,
        ).then((sent) {
          debugPrint('[AuthService] ✅ E-mail de bienvenue (Google/OAuth) envoyé : $sent');
        }).catchError((Object e) {
          debugPrint('[AuthService] ⚠️ Erreur e-mail de bienvenue (Google/OAuth) : $e');
        });
      }
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
      await prefs.remove(_localRoleKey);
      await prefs.remove(_localLevelKey);
      final syncKeys = prefs.getKeys().where((k) => k.startsWith('ngenou_initial_sync_done_')).toList();
      for (final k in syncKeys) {
        await prefs.remove(k);
      }
    }
  }

  // ─── SUPPRESSION DU COMPTE (STORE COMPLIANCE) ──────────────────────────

  /// Supprime définitivement le compte et toutes les données associées.
  /// Obligatoire pour Google Play et Apple App Store (Guideline 5.1.1(v)).
  static Future<void> deleteAccount() async {
    final user = currentUser;
    if (user != null) {
      final userId = user.id;
      // 1. Suppression des données sur les tables distantes Supabase
      final tables = [
        'tchat_ia_messages',
        'defis_quotidiens_sessions',
        'taches_revision',
        'emplois_du_temps',
        'projets',
        'cours_personnalises',
        'codes_sauvegardes',
        'progression',
        'scores',
        'badges',
        'profiles',
      ];
      for (final table in tables) {
        try {
          await _client.from(table).delete().eq('user_id', userId);
        } catch (e) {
          debugPrint('Suppression distante table $table (continuing): $e');
        }
      }

      // Tenter une procédure stockée RPC si configurée côté Supabase
      try {
        await _client.rpc('delete_user_account');
      } catch (e) {
        debugPrint('Appel rpc delete_user_account (continuing): $e');
      }
    }

    // 2. Déconnexion Google OAuth si initialisé
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}

    // 3. Déconnexion de la session Supabase
    try {
      await _client.auth.signOut();
    } catch (_) {}

    // 4. Purge intégrale de la base de données SQLite locale
    await DatabaseHelper.instance.clearLocalData();

    // 5. Nettoyage de toutes les préférences locales
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localPhoneKey);
    await prefs.remove(_localUsernameKey);
    await prefs.remove(_localRoleKey);
    await prefs.remove(_localLevelKey);
    final allKeys = prefs.getKeys().toList();
    for (final k in allKeys) {
      if (k.startsWith('ngenou_') || k.startsWith('local_')) {
        await prefs.remove(k);
      }
    }
  }
}

