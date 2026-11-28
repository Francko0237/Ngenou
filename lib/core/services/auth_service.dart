import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
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
      return true;
    }
  }

  /// Génère un code à 6 chiffres et l'envoie directement à l'utilisateur par e-mail
  static Future<bool> requestPasswordReset(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) return false;

    final res = await _client.rpc(
      'request_password_reset_code',
      params: {'target_email': cleanEmail},
    );

    if (res is Map && res['exists'] == true) {
      final code = res['code'] as String?;
      if (code != null && code.isNotEmpty) {
        return await EmailService.sendPasswordResetOtp(
          toEmail: cleanEmail,
          code: code,
        );
      }
    }
    return false;
  }

  /// Vérifie le code de sécurité à 6 chiffres entré dans l'appli
  static Future<bool> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanCode = code.trim();
    try {
      final res = await _client.rpc(
        'verify_password_reset_code',
        params: {'target_email': cleanEmail, 'code_to_check': cleanCode},
      );
      if (res is Map && res['valid'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[AuthService] Erreur verifyPasswordResetCode: $e');
      return false;
    }
  }

  /// Met à jour le mot de passe via le code vérifié et connecte l'utilisateur
  static Future<bool> completePasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanCode = code.trim();

    final res = await _client.rpc(
      'complete_password_reset',
      params: {
        'target_email': cleanEmail,
        'code_to_check': cleanCode,
        'new_password': newPassword,
      },
    );

    if (res is Map && res['success'] == true) {
      // Envoyer l'e-mail de confirmation de sécurité attestant le succès
      EmailService.sendPasswordResetSuccessEmail(toEmail: cleanEmail).then((sent) {
        debugPrint('[AuthService] ✅ Confirmation post-reset envoyée : $sent');
      }).catchError((Object e) {
        debugPrint('[AuthService] ⚠️ Erreur confirmation post-reset : $e');
      });

      try {
        await signInWithEmail(email: cleanEmail, password: newPassword);
      } catch (e) {
        debugPrint('[AuthService] Auto-connexion post reset: $e');
      }
      return true;
    }
    return false;
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
      final redirectUrl = 'http://localhost:$port/callback';

      // Génération de l'URL d'authentification avec PKCE automatique via le SDK Supabase
      String authUrl;
      try {
        final oAuthRes = await _client.auth.getOAuthSignInUrl(
          provider: OAuthProvider.google,
          redirectTo: redirectUrl,
        );
        authUrl = oAuthRes.url;
      } catch (e) {
        debugPrint('[AuthService] Fallback URL OAuth: $e');
        authUrl =
            '${SupabaseCredentials.url}/auth/v1/authorize?provider=google&redirect_to=${Uri.encodeComponent(redirectUrl)}';
      }

      final launched = await launchUrl(
        Uri.parse(authUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception(
          'Impossible d\'ouvrir le navigateur web pour l\'authentification Google.',
        );
      }

      final completer = Completer<bool>();

      server.listen((HttpRequest request) async {
        final uri = request.uri;
        final path = uri.path;

        // Répondre aux requêtes preflight OPTIONS
        if (request.method == 'OPTIONS') {
          request.response
            ..statusCode = HttpStatus.noContent
            ..headers.set('Access-Control-Allow-Origin', '*')
            ..headers.set('Access-Control-Allow-Methods', 'POST, GET, OPTIONS')
            ..headers.set('Access-Control-Allow-Headers', '*');
          await request.response.close();
          return;
        }

        // 1. Réception directe des tokens via le script JavaScript de la page de callback (si fragment hash #)
        if (path == '/token-exchange') {
          request.response.headers.set('Access-Control-Allow-Origin', '*');
          try {
            String content = '';
            if (request.method == 'POST') {
              content = await utf8.decoder.bind(request).join();
            } else {
              content = uri.queryParameters['payload'] ?? '';
            }

            final data = content.isNotEmpty
                ? jsonDecode(content) as Map<String, dynamic>
                : uri.queryParameters;

            if (data.containsKey('error')) {
              request.response
                ..statusCode = HttpStatus.ok
                ..headers.contentType = ContentType.json
                ..write(jsonEncode({'success': false}));
              await request.response.close();

              if (!completer.isCompleted) completer.complete(false);
              return;
            }

            final refreshToken = data['refresh_token'] as String?;
            final code = data['code'] as String?;

            if (code != null && code.isNotEmpty) {
              await _client.auth.exchangeCodeForSession(code);
            } else if (refreshToken != null && refreshToken.isNotEmpty) {
              await _client.auth.setSession(refreshToken);
            } else {
              final rawHash = data['hash'] as String? ?? '';
              final dummyUri = Uri.parse('http://localhost?$rawHash');
              await _client.auth.getSessionFromUrl(dummyUri);
            }

            await _resolvePostSignInMetadata();

            if (!kIsWeb &&
                (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
              try {
                await windowManager.show();
                await windowManager.focus();
              } catch (_) {}
            }

            request.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({'success': true}));
            await request.response.close();

            if (!completer.isCompleted) completer.complete(true);
          } catch (e) {
            debugPrint('[AuthService] Erreur /token-exchange: $e');
            request.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({'success': false, 'error': e.toString()}));
            await request.response.close();

            if (!completer.isCompleted) completer.complete(false);
          }
          return;
        }

        // 2. Traitement du retour callback du navigateur
        if (path == '/callback' || path == '/') {
          final query = uri.queryParameters;
          final error = query['error'];
          final code = query['code'];

          // Cas A : Erreur ou annulation signalée par Google / Supabase
          if (error != null && error.isNotEmpty) {
            request.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.html
              ..write(_buildConfirmationHtml(
                status: 'error',
                message: 'L\'authentification a été annulée ou refusée.',
              ));
            await request.response.close();

            if (!completer.isCompleted) completer.complete(false);
            return;
          }

          // Cas B : Code d'autorisation PKCE présent en query parameters
          if (code != null && code.isNotEmpty) {
            bool success = false;
            try {
              await _client.auth.exchangeCodeForSession(code);
              await _resolvePostSignInMetadata();
              success = true;

              if (!kIsWeb &&
                  (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
                try {
                  await windowManager.show();
                  await windowManager.focus();
                } catch (_) {}
              }
            } catch (e) {
              debugPrint('[AuthService] Erreur exchangeCodeForSession: $e');
            }

            request.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.html
              ..write(_buildConfirmationHtml(
                status: success ? 'success' : 'error',
                message: success
                    ? 'Votre compte Google est connecté à Ngenou.'
                    : 'Impossible de valider la session. Veuillez réessayer.',
              ));
            await request.response.close();

            if (!completer.isCompleted) completer.complete(success);
            return;
          }

          // Cas C : Ni code ni erreur dans l'URL GET (tokens renvoyés dans le fragment # côté client)
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.html
            ..write(_buildConfirmationHtml(status: 'processing'));
          await request.response.close();
          return;
        }

        // Requêtes secondaires (favicon, etc.)
        request.response
          ..statusCode = HttpStatus.notFound
          ..close();
      });

      final result = await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          return false;
        },
      );
      return result;
    } finally {
      // Laisser un court délai de 2 secondes avant d'arrêter le serveur HTTP
      // pour que le navigateur ait le temps de recevoir complètement la réponse finale
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          await server?.close(force: true);
        } catch (_) {}
      });
    }
  }

  /// Génère une page HTML moderne, élégante et professionnelle pour la confirmation dans le navigateur.
  static String _buildConfirmationHtml({
    required String status, // 'success' | 'error' | 'processing'
    String? message,
  }) {
    const logoUrl =
        'https://qfthojymggrpdxfhhzii.supabase.co/storage/v1/object/public/app-assets/logo.png';

    final isSuccess = status == 'success';
    final isError = status == 'error';

    final title = isSuccess
        ? 'Authentification réussie !'
        : isError
            ? 'Connexion interrompue'
            : 'Finalisation de la connexion...';

    final desc = message ??
        (isSuccess
            ? 'Votre compte Google a été vérifié avec succès. Vous pouvez désormais retourner dans votre application Ngenou.'
            : isError
                ? 'L\'authentification Google a été interrompue ou n\'a pas pu aboutir. Aucune modification n\'a été apportée à votre compte.'
                : 'Vérification sécurisée de vos identifiants en cours, veuillez patienter un instant...');

    return '''<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$title - Ngenou</title>
  <style>
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }
    body {
      background: radial-gradient(circle at 50% 15%, #111A2E 0%, #070A11 100%);
      color: #E2E8F0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 32px 20px;
    }
    .card {
      background: linear-gradient(160deg, rgba(19, 27, 46, 0.92) 0%, rgba(10, 14, 25, 0.96) 100%);
      backdrop-filter: blur(24px);
      -webkit-backdrop-filter: blur(24px);
      border: 1px solid rgba(56, 189, 248, 0.15);
      border-radius: 36px;
      width: 100%;
      max-width: 520px;
      padding: 48px 36px;
      text-align: center;
      box-shadow: 0 30px 70px -15px rgba(0, 0, 0, 0.8), 0 0 40px rgba(56, 189, 248, 0.08);
      animation: fadeIn 0.45s cubic-bezier(0.16, 1, 0.3, 1);
      position: relative;
      overflow: hidden;
    }
    .card::before {
      content: '';
      position: absolute;
      top: -100px;
      left: 50%;
      transform: translateX(-50%);
      width: 300px;
      height: 200px;
      background: radial-gradient(ellipse at center, rgba(56, 189, 248, 0.22) 0%, rgba(56, 189, 248, 0) 70%);
      pointer-events: none;
    }
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(20px) scale(0.98); }
      to { opacity: 1; transform: translateY(0) scale(1); }
    }
    .logo-container {
      margin-bottom: 30px;
      display: inline-block;
      position: relative;
    }
    /* Logo bien grand et glorieux (5x plus grand) */
    .logo-img {
      width: 210px;
      height: 210px;
      max-width: 80vw;
      border-radius: 34px;
      object-fit: cover;
      filter: drop-shadow(0 15px 35px rgba(56, 189, 248, 0.35));
      border: 2px solid rgba(255, 255, 255, 0.16);
      transition: transform 0.3s ease;
    }
    .logo-img:hover {
      transform: scale(1.03);
    }
    .icon-badge {
      width: 60px;
      height: 60px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 0 auto 20px auto;
    }
    .icon-badge.success {
      background: rgba(16, 185, 129, 0.18);
      border: 1.5px solid rgba(16, 185, 129, 0.4);
      color: #10B981;
      box-shadow: 0 0 25px rgba(16, 185, 129, 0.25);
    }
    .icon-badge.error {
      background: rgba(244, 63, 94, 0.18);
      border: 1.5px solid rgba(244, 63, 94, 0.4);
      color: #F43F5E;
      box-shadow: 0 0 25px rgba(244, 63, 94, 0.25);
    }
    .icon-badge.processing {
      background: rgba(56, 189, 248, 0.18);
      border: 1.5px solid rgba(56, 189, 248, 0.4);
      color: #38BDF8;
      box-shadow: 0 0 25px rgba(56, 189, 248, 0.25);
    }
    .icon-svg {
      width: 30px;
      height: 30px;
    }
    .spinner {
      border: 3.5px solid rgba(56, 189, 248, 0.2);
      border-top-color: #38BDF8;
      border-radius: 50%;
      width: 30px;
      height: 30px;
      animation: spin 0.8s linear infinite;
    }
    @keyframes spin {
      to { transform: rotate(360deg); }
    }
    h1 {
      font-size: 26px;
      font-weight: 800;
      color: #F8FAFC;
      letter-spacing: -0.03em;
      margin-bottom: 14px;
      background: linear-gradient(135deg, #FFFFFF 40%, #7DD3FC 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    p {
      color: #94A3B8;
      font-size: 15.5px;
      line-height: 1.65;
      margin-bottom: 32px;
      padding: 0 10px;
    }
    .btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      width: 100%;
      padding: 15px 24px;
      font-size: 15.5px;
      font-weight: 700;
      border-radius: 16px;
      text-decoration: none;
      cursor: pointer;
      transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
      border: none;
      outline: none;
    }
    .btn-primary {
      background: linear-gradient(135deg, #38BDF8 0%, #0284C7 100%);
      color: #040814;
      box-shadow: 0 8px 24px -4px rgba(56, 189, 248, 0.5);
    }
    .btn-primary:hover {
      background: linear-gradient(135deg, #7DD3FC 0%, #0369A1 100%);
      transform: translateY(-2px);
      box-shadow: 0 12px 30px -4px rgba(56, 189, 248, 0.65);
    }
    .btn-secondary {
      background: rgba(255, 255, 255, 0.08);
      color: #CBD5E1;
      border: 1px solid rgba(255, 255, 255, 0.14);
    }
    .btn-secondary:hover {
      background: rgba(255, 255, 255, 0.14);
      color: #FFFFFF;
      transform: translateY(-1px);
    }
    .subtext {
      margin-top: 22px;
      font-size: 13px;
      color: #64748B;
      line-height: 1.4;
    }
  </style>
</head>
<body>
  <div class="card" id="card">
    <div class="logo-container">
      <img src="$logoUrl" alt="Ngenou Logo" class="logo-img" onerror="this.style.display='none'" />
    </div>

    <div id="status-icon">
      ${isSuccess ? '''
      <div class="icon-badge success">
        <svg class="icon-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round">
          <polyline points="20 6 9 17 4 12"></polyline>
        </svg>
      </div>''' : isError ? '''
      <div class="icon-badge error">
        <svg class="icon-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="10"></circle>
          <line x1="15" y1="9" x2="9" y2="15"></line>
          <line x1="9" y1="9" x2="15" y2="15"></line>
        </svg>
      </div>''' : '''
      <div class="icon-badge processing">
        <div class="spinner"></div>
      </div>'''}
    </div>

    <h1 id="title">$title</h1>
    <p id="desc">$desc</p>

    <div id="action-area">
      ${isSuccess ? '''
      <button class="btn btn-primary" onclick="window.close()">🚀 Revenir sur Ngenou</button>
      <div class="subtext">Cette fenêtre va se fermer ou peut être fermée.</div>
      ''' : isError ? '''
      <button class="btn btn-secondary" onclick="window.close()">Fermer cette fenêtre</button>
      <div class="subtext">Retournez sur Ngenou pour réessayer la connexion.</div>
      ''' : '''
      <div class="subtext">Connexion à votre espace d'apprentissage Ngenou...</div>
      '''}
    </div>
  </div>

  <script>
    (function() {
      var currentStatus = '$status';

      // Si le serveur a DÉJÀ validé avec succès ou échec, ne rien envoyer de plus
      if (currentStatus === 'success') {
        setTimeout(function() {
          try { window.close(); } catch(e) {}
        }, 4000);
        return;
      }
      if (currentStatus === 'error') {
        return;
      }

      // Si et seulement si status === 'processing', lire le hash fragment et l'envoyer au serveur
      var hash = window.location.hash;
      var search = window.location.search;

      if (!hash && !search) return;

      var params = {};
      function parseQuery(str) {
        if (!str) return;
        if (str.startsWith('#') || str.startsWith('?')) str = str.substring(1);
        str.split('&').forEach(function(pair) {
          var parts = pair.split('=');
          if (parts.length === 2) {
            params[decodeURIComponent(parts[0])] = decodeURIComponent(parts[1].replace(/\\+/g, ' '));
          }
        });
      }

      parseQuery(search);
      parseQuery(hash);

      // Si des tokens sont présents dans le fragment #, transmettre au serveur local
      if (params.access_token || params.refresh_token || params.code || params.error) {
        fetch('/token-exchange', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(params)
        })
        .then(function(res) { return res.json(); })
        .then(function(data) {
          if (data && data.success) {
            renderSuccess();
          } else {
            renderError(data.error || 'Impossible de finaliser la connexion.');
          }
        })
        .catch(function(err) {
          renderError('Erreur de transmission vers l\\'application Ngenou.');
        });
      }

      function renderSuccess() {
        document.getElementById('status-icon').innerHTML = '<div class="icon-badge success"><svg class="icon-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg></div>';
        document.getElementById('title').textContent = 'Authentification réussie !';
        document.getElementById('desc').textContent = 'Votre compte Google a été connecté à Ngenou. Vous pouvez retourner dans votre application.';
        document.getElementById('action-area').innerHTML = '<button class="btn btn-primary" onclick="window.close()">🚀 Revenir sur Ngenou</button><div class="subtext">Cette fenêtre peut être fermée.</div>';
        setTimeout(function() {
          try { window.close(); } catch(e) {}
        }, 3500);
      }

      function renderError(msg) {
        document.getElementById('status-icon').innerHTML = '<div class="icon-badge error"><svg class="icon-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg></div>';
        document.getElementById('title').textContent = 'Connexion interrompue';
        document.getElementById('desc').textContent = msg || 'L\\'authentification a échoué.';
        document.getElementById('action-area').innerHTML = '<button class="btn btn-secondary" onclick="window.close()">Fermer cette fenêtre</button><div class="subtext">Vous pouvez réessayer la connexion depuis Ngenou.</div>';
      }
    })();
  </script>
</body>
</html>''';
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

