import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service responsable de l'expédition sécurisée des e-mails transactionnels Ngenou
/// (Bienvenue, code de réinitialisation OTP, confirmation de modification).
///
/// Tous les e-mails sont traités par la Edge Function Supabase côté serveur (`send-welcome-email`).
/// Aucun mot de passe SMTP n'est exposé côté client.
class EmailService {
  EmailService._();

  /// Envoie un e-mail de bienvenue personnalisé à un nouvel utilisateur.
  static Future<bool> sendWelcomeEmail({
    required String toEmail,
    required String username,
  }) async {
    final cleanEmail = toEmail.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) return false;

    // Ne pas envoyer aux faux e-mails virtuels du mode téléphone
    if (cleanEmail.endsWith('@ngenou.internal') ||
        cleanEmail.endsWith('@ngenou.app')) {
      return false;
    }

    try {
      debugPrint('[EmailService] Envoi e-mail de bienvenue via Supabase Edge Function à $cleanEmail...');
      final response = await Supabase.instance.client.functions.invoke(
        'send-welcome-email',
        body: {
          'type': 'welcome',
          'toEmail': cleanEmail,
          'username': username.trim().isNotEmpty ? username.trim() : null,
        },
      );

      final data = response.data;
      final success = data is Map && (data['sent'] == true);
      debugPrint('[EmailService] Résultat Edge Function bienvenue : sent=$success');
      return success;
    } catch (e) {
      debugPrint('[EmailService] ⚠️ Erreur lors de l\'envoi de l\'e-mail de bienvenue : $e');
      return false;
    }
  }

  /// Envoie un e-mail avec le code de sécurité à 6 chiffres pour réinitialiser le mot de passe.
  static Future<bool> sendPasswordResetOtp({
    required String toEmail,
    required String code,
  }) async {
    final cleanEmail = toEmail.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) return false;

    try {
      debugPrint('[EmailService] Envoi code OTP $code via Supabase Edge Function à $cleanEmail...');
      final response = await Supabase.instance.client.functions.invoke(
        'send-welcome-email',
        body: {
          'type': 'reset_otp',
          'toEmail': cleanEmail,
          'code': code.trim(),
        },
      );

      final data = response.data;
      final success = data is Map && (data['sent'] == true);
      debugPrint('[EmailService] Résultat Edge Function reset OTP : sent=$success');
      return success;
    } catch (e) {
      debugPrint('[EmailService] ⚠️ Erreur lors de l\'envoi du code OTP : $e');
      return false;
    }
  }

  /// Envoie un e-mail de confirmation après le succès de la réinitialisation du mot de passe.
  static Future<bool> sendPasswordResetSuccessEmail({
    required String toEmail,
  }) async {
    final cleanEmail = toEmail.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) return false;

    try {
      debugPrint('[EmailService] Envoi confirmation de réinitialisation via Supabase Edge Function à $cleanEmail...');
      final response = await Supabase.instance.client.functions.invoke(
        'send-welcome-email',
        body: {
          'type': 'reset_success',
          'toEmail': cleanEmail,
        },
      );

      final data = response.data;
      final success = data is Map && (data['sent'] == true);
      debugPrint('[EmailService] Résultat Edge Function confirmation reset : sent=$success');
      return success;
    } catch (e) {
      debugPrint('[EmailService] ⚠️ Erreur lors de l\'envoi de la confirmation : $e');
      return false;
    }
  }
}

