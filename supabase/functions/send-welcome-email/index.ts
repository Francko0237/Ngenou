/**
 * Edge Function Supabase : send-email (send-welcome-email)
 * Envoi d'e-mails transactionnels Ngenou (Bienvenue, OTP Reset, Confirmation) via Gmail SMTP (nodemailer).
 * Exécuté de manière 100% sécurisée côté serveur Supabase avec les secrets d'environnement.
 */

import nodemailer from "npm:nodemailer@6.9.16";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const GMAIL_USER = "ngenou.support@gmail.com";
const GMAIL_PASS = Deno.env.get("GMAIL_APP_PASSWORD");

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: GMAIL_USER,
    pass: GMAIL_PASS,
  },
});

function buildWelcomeHtml(displayName: string | null): string {
  const salutation = displayName
    ? `Bonjour ${displayName},`
    : "Bonjour et bienvenue parmi nous,";

  return `<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Bienvenue sur Ngenou</title>
</head>
<body style="margin:0;padding:0;background:#0B0F19;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#CBD5E1;">
  <table width="100%" cellspacing="0" cellpadding="0" style="background:#0B0F19;padding:40px 15px;">
    <tr><td align="center">
      <table width="100%" style="max-width:520px;background:#111827;border-radius:16px;border:1px solid #1F2937;overflow:hidden;box-shadow:0 10px 30px rgba(0,0,0,0.4);">
        <tr><td style="padding:28px 32px 20px;border-bottom:1px solid #1F2937;">
          <table cellspacing="0" cellpadding="0" border="0"><tr>
            <td style="padding-right:12px;">
              <img src="https://cdn.jsdelivr.net/gh/Francko0237/Ngenou@main/assets/images/icon_email.png" alt="Ngenou" width="36" height="36" style="display:block;width:36px;height:36px;"/>
            </td>
            <td><span style="font-size:19px;font-weight:700;color:#CBD5E1;">Ngenou</span></td>
          </tr></table>
        </td></tr>
        <tr><td style="padding:32px;">
          <h1 style="margin:0 0 16px;color:#F1F5F9;font-size:20px;font-weight:700;">Bienvenue dans l'aventure Ngenou ! 🎉</h1>
          <p style="margin:0 0 14px;color:#F1F5F9;font-size:15px;font-weight:600;">${salutation}</p>
          <p style="margin:0 0 14px;color:#94A3B8;font-size:14.5px;line-height:1.65;">
            Nous sommes ravis de vous compter parmi nous ! Votre compte est actif et votre espace d'apprentissage vous attend sur l'application Ngenou.
          </p>
          <p style="margin:0 0 20px;color:#94A3B8;font-size:14.5px;line-height:1.65;">
            Accédez à vos cours interactifs, vos défis quotidiens et votre tuteur IA pour progresser à votre rythme.
          </p>
          <div style="background:#0F172A;border:1px solid #1E293B;border-radius:10px;padding:16px 18px;">
            <p style="margin:0 0 6px;color:#38BDF8;font-size:13px;font-weight:600;">💡 Pour bien démarrer dans l'app :</p>
            <p style="margin:0;color:#94A3B8;font-size:12.5px;line-height:1.7;">
              • Explorez vos leçons depuis l'onglet <strong>Cours</strong><br>
              • Posez vos questions à votre <strong>Tuteur IA</strong><br>
              • Relevez votre premier <strong>Défi quotidien</strong> pour lancer votre série
            </p>
          </div>
        </td></tr>
        <tr><td style="padding:20px 32px;background:#0B0F19;border-top:1px solid #1F2937;">
          <p style="margin:0;color:#64748B;font-size:11.5px;line-height:1.5;">
            © 2026 Ngenou. Tous droits réservés.<br>
            Contact : <a href="mailto:ngenou.support@gmail.com" style="color:#64748B;">ngenou.support@gmail.com</a>
          </p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

function buildResetOtpHtml(code: string): string {
  return `<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Code de réinitialisation - Ngenou</title>
</head>
<body style="margin: 0; padding: 0; background-color: #0B0F19; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #CBD5E1;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #0B0F19; padding: 40px 15px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" style="max-width: 520px; background-color: #111827; border-radius: 16px; border: 1px solid #1F2937; overflow: hidden; box-shadow: 0 10px 30px rgba(0, 0, 0, 0.4);">
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
          <tr>
            <td style="padding: 32px 32px 36px 32px;">
              <h1 style="margin: 0 0 16px 0; color: #F1F5F9; font-size: 20px; font-weight: 700; letter-spacing: -0.3px;">
                Réinitialisation de mot de passe 🔑
              </h1>
              <p style="margin: 0 0 16px 0; color: #94A3B8; font-size: 14.5px; line-height: 1.65;">
                Bonjour,<br><br>
                Vous avez demandé la réinitialisation de votre mot de passe pour votre compte <strong style="color: #E2E8F0;">Ngenou</strong>.
              </p>
              <p style="margin: 0 0 16px 0; color: #94A3B8; font-size: 14.5px; line-height: 1.65;">
                Voici votre code de sécurité à saisir dans l'application :
              </p>
              <div style="background-color: #0F172A; border: 2px dashed #38BDF8; border-radius: 12px; padding: 20px 16px; text-align: center; margin: 24px 0;">
                <span style="font-family: 'Courier New', Courier, monospace; font-size: 34px; font-weight: 700; letter-spacing: 10px; color: #38BDF8; display: inline-block;">
                  ${code}
                </span>
              </div>
              <p style="margin: 0 0 24px 0; color: #94A3B8; font-size: 13.5px; line-height: 1.6; text-align: center;">
                Copiez ce code et collez-le dans l'application Ngenou pour choisir votre nouveau mot de passe.
              </p>
              <div style="background-color: #0F172A; border-left: 3px solid #38BDF8; padding: 12px 14px; border-radius: 6px; margin-top: 20px;">
                <p style="margin: 0; color: #94A3B8; font-size: 12px; line-height: 1.6;">
                  🔒 <strong>Sécurité :</strong> Ce code expire dans 15 minutes. Si vous n'êtes pas à l'origine de cette demande, vous pouvez ignorer cet e-mail en toute tranquillité.
                </p>
              </div>
            </td>
          </tr>
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
</html>`;
}

function buildResetSuccessHtml(): string {
  return `<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Mot de passe modifié - Ngenou</title>
</head>
<body style="margin: 0; padding: 0; background-color: #0B0F19; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #CBD5E1;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #0B0F19; padding: 40px 15px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" style="max-width: 520px; background-color: #111827; border-radius: 16px; border: 1px solid #1F2937; overflow: hidden; box-shadow: 0 10px 30px rgba(0, 0, 0, 0.4);">
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
          <tr>
            <td style="padding: 32px 32px 36px 32px;">
              <h1 style="margin: 0 0 16px 0; color: #F1F5F9; font-size: 20px; font-weight: 700; letter-spacing: -0.3px;">
                Mot de passe réinitialisé avec succès ✅
              </h1>
              <p style="margin: 0 0 16px 0; color: #94A3B8; font-size: 14.5px; line-height: 1.65;">
                Bonjour,<br><br>
                Nous vous confirmons que le mot de passe de votre compte <strong style="color: #E2E8F0;">Ngenou</strong> vient d'être modifié avec succès.
              </p>
              <p style="margin: 0 0 20px 0; color: #94A3B8; font-size: 14.5px; line-height: 1.65;">
                Vous pouvez dès à présent vous connecter à l'application avec vos nouveaux identifiants.
              </p>
              <div style="background-color: #0F172A; border-left: 3px solid #10B981; padding: 14px 16px; border-radius: 8px; margin-top: 24px;">
                <p style="margin: 0 0 6px 0; color: #34D399; font-size: 13px; font-weight: 600;">
                  🔒 Vous n'êtes pas à l'origine de cette action ?
                </p>
                <p style="margin: 0; color: #94A3B8; font-size: 12px; line-height: 1.6;">
                  Si vous n'avez pas demandé cette réinitialisation, veuillez sécuriser votre compte et nous contacter sans attendre à <a href="mailto:ngenou.support@gmail.com" style="color: #38BDF8; text-decoration: underline;">ngenou.support@gmail.com</a>.
                </p>
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding: 20px 32px; background-color: #0B0F19; border-top: 1px solid #1F2937;">
              <p style="margin: 0; color: #64748B; font-size: 11.5px; line-height: 1.5;">
                © 2026 Ngenou. Tous droits réservés.<br>
                Contact : <a href="mailto:ngenou.support@gmail.com" style="color: #64748B; text-decoration: underline;">ngenou.support@gmail.com</a>
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const body = await req.json();
    const type = body.type || "welcome"; // "welcome" | "reset_otp" | "reset_success"
    const toEmail = body.toEmail?.trim();

    if (!toEmail || !toEmail.includes("@")) {
      return new Response(JSON.stringify({ error: "Email invalide" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Ignorer les emails virtuels (mode téléphone)
    if (toEmail.endsWith("@ngenou.internal") || toEmail.endsWith("@ngenou.app")) {
      return new Response(JSON.stringify({ sent: false, reason: "virtual_email" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let subject = "";
    let htmlContent = "";
    let textContent = "";

    if (type === "reset_otp") {
      const code = String(body.code || "").trim();
      subject = `Votre code de réinitialisation Ngenou : ${code} 🔑`;
      htmlContent = buildResetOtpHtml(code);
      textContent = `Bonjour,\n\nVous avez demandé la réinitialisation de votre mot de passe Ngenou.\n\nVotre code de sécurité est : ${code}\n\nSaisissez ce code dans l'application pour choisir votre nouveau mot de passe. Ce code expire dans 15 minutes.\n\nL'équipe Ngenou`;
    } else if (type === "reset_success") {
      subject = "Confirmation : Votre mot de passe Ngenou a été modifié ✅";
      htmlContent = buildResetSuccessHtml();
      textContent = `Bonjour,\n\nVotre mot de passe Ngenou a été réinitialisé avec succès.\n\nVous pouvez désormais vous connecter à votre compte avec votre nouveau mot de passe.\n\nSi vous n'êtes pas à l'origine de cette action, veuillez contacter le support immédiatement à ngenou.support@gmail.com.\n\nL'équipe Ngenou`;
    } else {
      // Type welcome
      const displayName = body.username?.trim() || null;
      subject = displayName
        ? `Bienvenue sur Ngenou, ${displayName} ! 🎉`
        : "Bienvenue sur Ngenou ! 🎉";
      htmlContent = buildWelcomeHtml(displayName);
      textContent = displayName
        ? `Bonjour ${displayName},\n\nBienvenue dans l'aventure Ngenou ! Votre compte est actif.\n\nBonne découverte !\nL'équipe Ngenou`
        : `Bienvenue dans l'aventure Ngenou !\n\nVotre compte est actif. Bonne découverte !\nL'équipe Ngenou`;
    }

    const info = await transporter.sendMail({
      from: '"Ngenou" <ngenou.support@gmail.com>',
      to: toEmail,
      subject,
      html: htmlContent,
      text: textContent,
    });

    console.log(`[send-welcome-email] ✅ Email [${type}] envoyé avec succès à ${toEmail}, id: ${info.messageId}`);
    return new Response(JSON.stringify({ sent: true, id: info.messageId }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (error) {
    console.error("[send-welcome-email] ❌ Erreur:", error);
    return new Response(
      JSON.stringify({ sent: false, error: String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
