/**
 * Edge Function Supabase : send-welcome-email
 * Envoi d'e-mails de bienvenue personnalisés via Gmail SMTP (nodemailer).
 * Exécuté côté serveur Supabase (fiable, sans blocage opérateur mobile, sans restriction de domaine).
 */

import nodemailer from "npm:nodemailer@6.9.16";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const GMAIL_USER = "ngenou.support@gmail.com";
const GMAIL_PASS = Deno.env.get("GMAIL_APP_PASSWORD") || "chtrvvaqvjjobhbe";

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
    const { toEmail, username } = await req.json();

    if (!toEmail || !toEmail.includes("@")) {
      return new Response(JSON.stringify({ error: "Email invalide" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Ignorer les emails virtuels (utilisateurs inscrits par téléphone)
    if (toEmail.endsWith("@ngenou.internal") || toEmail.endsWith("@ngenou.app")) {
      return new Response(JSON.stringify({ sent: false, reason: "virtual_email" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const displayName = username?.trim() || null;
    const subject = displayName
      ? `Bienvenue sur Ngenou, ${displayName} ! 🎉`
      : "Bienvenue sur Ngenou ! 🎉";

    const htmlContent = buildWelcomeHtml(displayName);
    const textContent = displayName
      ? `Bonjour ${displayName},\n\nBienvenue dans l'aventure Ngenou ! Votre compte est actif.\n\nBonne découverte !\nL'équipe Ngenou`
      : `Bienvenue dans l'aventure Ngenou !\n\nVotre compte est actif. Bonne découverte !\nL'équipe Ngenou`;

    const info = await transporter.sendMail({
      from: '"Ngenou" <ngenou.support@gmail.com>',
      to: toEmail,
      subject,
      html: htmlContent,
      text: textContent,
    });

    console.log(`[send-welcome-email] ✅ Email envoyé avec succès à ${toEmail}, id: ${info.messageId}`);
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
