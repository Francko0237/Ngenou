import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// Service responsable de l'expédition des e-mails transactionnels Ngenou (Bienvenue, notifications).
class EmailService {
  static const String _smtpUsername = 'ngenou.support@gmail.com';
  static const String _smtpPassword = 'chtrvvaqvjjobhbe';
  static const String _senderName = 'Ngenou';

  static final SmtpServer _smtpServer = SmtpServer(
    'smtp.gmail.com',
    port: 587,
    ssl: false,
    allowInsecure: false,
    username: _smtpUsername,
    password: _smtpPassword,
  );

  /// Envoie un e-mail de bienvenue chaleureux et personnalisé à un nouvel utilisateur.
  /// Priorité : Edge Function Supabase (fiable sur mobile) → fallback SMTP local.
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

    final displayName = username.trim().isNotEmpty ? username.trim() : null;
    final subject = displayName != null
        ? 'Bienvenue sur Ngenou, $displayName ! 🎉'
        : 'Bienvenue sur Ngenou ! 🎉';

    final htmlBody = _buildWelcomeHtml(displayName: displayName);
    final textBody = displayName != null
        ? 'Bonjour $displayName,\n\nBienvenue dans l\'aventure Ngenou ! Votre compte est actif et votre espace d\'apprentissage est prêt sur l\'application Ngenou.\n\nBonne découverte et bon apprentissage !'
        : 'Bonjour et bienvenue parmi nous !\n\nVotre compte est actif et votre espace d\'apprentissage est prêt sur l\'application Ngenou.\n\nBonne découverte et bon apprentissage !';

    final message = Message()
      ..from = const Address(_smtpUsername, _senderName)
      ..recipients.add(cleanEmail)
      ..subject = subject
      ..text = textBody
      ..html = htmlBody;

    try {
      debugPrint('[EmailService] Envoi direct de l\'e-mail de bienvenue via SMTP à $cleanEmail...');
      final sendReport = await send(message, _smtpServer);
      debugPrint('[EmailService] ✅ E-mail envoyé avec succès via SMTP : $sendReport');
      return true;
    } catch (e) {
      debugPrint('[EmailService] ⚠️ Erreur lors de l\'envoi de l\'e-mail : $e');
      return false;
    }
  }

  static String _buildWelcomeHtml({String? displayName}) {
    final salutation = displayName != null && displayName.isNotEmpty
        ? 'Bonjour $displayName,'
        : 'Bonjour et bienvenue parmi nous,';

    return '''<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Bienvenue sur Ngenou</title>
</head>
<body style="margin: 0; padding: 0; background-color: #0B0F19; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #CBD5E1;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #0B0F19; padding: 40px 15px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" style="max-width: 520px; background-color: #111827; border-radius: 16px; border: 1px solid #1F2937; overflow: hidden; box-shadow: 0 10px 30px rgba(0, 0, 0, 0.4);">
          
          <!-- En-tête sobre : Logo direct sans card + Nom sobre -->
          <tr>
            <td style="padding: 28px 32px 20px 32px; border-bottom: 1px solid #1F2937;">
              <table role="presentation" cellspacing="0" cellpadding="0" border="0">
                <tr>
                  <td valign="middle" style="padding-right: 12px;">
                    <img src="https://cdn.jsdelivr.net/gh/Francko0237/Ngenou@main/assets/images/icon_email.png" alt="Ngenou" width="36" height="36" border="0" style="display: block; width: 36px; height: 36px; border: 0;" />
                  </td>
                  <td valign="middle">
                    <span style="font-size: 19px; font-weight: 700; color: #CBD5E1; letter-spacing: -0.3px;">Ngenou</span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Message de Bienvenue Chaleureux et Personnalisé (SANS aucun bouton) -->
          <tr>
            <td style="padding: 32px 32px 36px 32px;">
              <h1 style="margin: 0 0 16px 0; color: #F1F5F9; font-size: 20px; font-weight: 700; letter-spacing: -0.3px;">
                Bienvenue dans l'aventure Ngenou ! 🎉
              </h1>
              <p style="margin: 0 0 16px 0; color: #F1F5F9; font-size: 15px; line-height: 1.65; font-weight: 600;">
                $salutation
              </p>
              <p style="margin: 0 0 16px 0; color: #94A3B8; font-size: 14.5px; line-height: 1.65;">
                Nous sommes ravis de vous compter parmi nous ! Votre compte est actif et votre espace d'apprentissage est prêt sur votre application Ngenou.
              </p>
              <p style="margin: 0 0 24px 0; color: #94A3B8; font-size: 14.5px; line-height: 1.65;">
                Vous avez désormais accès à tous vos cours interactifs, à vos défis quotidiens et à votre tuteur intelligent pour vous accompagner à chaque étape de votre progression.
              </p>

              <!-- Bloc astuces -->
              <div style="background-color: #0F172A; border: 1px solid #1E293B; border-radius: 10px; padding: 16px 18px; margin-top: 20px;">
                <p style="margin: 0 0 6px 0; color: #38BDF8; font-size: 13px; font-weight: 600;">
                  💡 Pour bien démarrer dans l'app :
                </p>
                <p style="margin: 0; color: #94A3B8; font-size: 12.5px; line-height: 1.7;">
                  • Explorez vos leçons depuis l'onglet <strong>Cours</strong><br>
                  • Posez vos questions à tout moment à votre <strong>Tuteur IA</strong><br>
                  • Relevez votre premier <strong>Défi quotidien</strong> pour lancer votre série
                </p>
              </div>
            </td>
          </tr>

          <!-- Footer sobre -->
          <tr>
            <td style="padding: 20px 32px; background-color: #0B0F19; border-top: 1px solid #1F2937;">
              <p style="margin: 0; color: #64748B; font-size: 11.5px; line-height: 1.5;">
                © 2026 Ngenou. Tous droits réservés.<br>
                Une question ? Écrivez-nous à <a href="mailto:ngenou.support@gmail.com" style="color: #64748B; text-decoration: underline;">ngenou.support@gmail.com</a>.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>''';
  }
}
