/**
 * Edge Function Supabase : ai-proxy
 *
 * Rôle : Proxy sécurisé entre Flutter et l'API DeepSeek.
 *        La clé API DeepSeek est stockée dans les secrets Deno,
 *        jamais exposée côté client.
 *
 * Endpoint : POST /functions/v1/ai-proxy
 *
 * Payload attendu (JSON) :
 * {
 *   "messages":       Array<{role: string, content: string}>,
 *   "model":          string,   // ex: "deepseek-chat" ou "deepseek-reasoner"
 *   "max_tokens":     number,
 *   "temperature":    number,
 *   "response_format"?: { "type": "json_object" }  // optionnel
 * }
 *
 * Réponse (JSON) :
 * {
 *   "content":     string,   // texte de la réponse IA
 *   "total_tokens": number   // tokens consommés (pour le QuotaGuard Dart)
 * }
 *
 * En cas d'erreur :
 * {
 *   "error": string
 * }
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// ── Constantes ─────────────────────────────────────────────────────────────

const DEEPSEEK_API_URL = "https://api.deepseek.com/chat/completions";

// Modèles autorisés — liste blanche pour éviter les abus
const ALLOWED_MODELS = new Set([
  "deepseek-chat",      // Ngenou Flash
  "deepseek-reasoner",  // Ngenou Pro
]);

// ── Gestionnaire principal ──────────────────────────────────────────────────

serve(async (req: Request) => {
  // ── CORS preflight ────────────────────────────────────────────────────────
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders(),
    });
  }

  // ── Méthode autorisée ─────────────────────────────────────────────────────
  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  // ── Authentification Supabase ─────────────────────────────────────────────
  // On vérifie que la requête vient d'un utilisateur authentifié via le JWT
  // Supabase transmis dans le header Authorization.
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return errorResponse("Missing or invalid Authorization header", 401);
  }

  // ── Lecture et validation du payload ─────────────────────────────────────
  let payload: {
    messages: Array<{ role: string; content: string }>;
    model: string;
    max_tokens: number;
    temperature: number;
    response_format?: { type: string };
  };

  try {
    payload = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400);
  }

  const { messages, model, max_tokens, temperature, response_format } = payload;

  // Validations de base
  if (!Array.isArray(messages) || messages.length === 0) {
    return errorResponse("'messages' must be a non-empty array", 400);
  }
  if (!ALLOWED_MODELS.has(model)) {
    return errorResponse(
      `Model '${model}' is not allowed. Allowed: ${[...ALLOWED_MODELS].join(", ")}`,
      400,
    );
  }
  if (typeof max_tokens !== "number" || max_tokens <= 0 || max_tokens > 16384) {
    return errorResponse("'max_tokens' must be a positive number ≤ 16384", 400);
  }
  if (typeof temperature !== "number" || temperature < 0 || temperature > 2) {
    return errorResponse("'temperature' must be between 0 and 2", 400);
  }

  // ── Récupération de la clé API depuis les secrets Deno ───────────────────
  // La clé est injectée via : supabase secrets set DEEPSEEK_API_KEY=sk-xxxxx
  const apiKey = Deno.env.get("DEEPSEEK_API_KEY");
  if (!apiKey) {
    console.error("DEEPSEEK_API_KEY secret is not set");
    return errorResponse("Server configuration error", 500);
  }

  // ── Construction du payload DeepSeek ─────────────────────────────────────
  const deepseekBody: Record<string, unknown> = {
    model,
    messages,
    temperature,
    max_tokens,
    stream: false,
  };

  if (response_format) {
    deepseekBody["response_format"] = response_format;
  }

  // ── Appel à l'API DeepSeek ────────────────────────────────────────────────
  let deepseekResponse: Response;
  try {
    deepseekResponse = await fetch(DEEPSEEK_API_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Authorization": `Bearer ${apiKey}`,
      },
      body: JSON.stringify(deepseekBody),
    });
  } catch (err) {
    console.error("DeepSeek fetch failed:", err);
    return errorResponse("Failed to reach DeepSeek API", 502);
  }

  // ── Traitement de la réponse DeepSeek ─────────────────────────────────────
  if (!deepseekResponse.ok) {
    const errorText = await deepseekResponse.text();
    console.error(`DeepSeek error ${deepseekResponse.status}: ${errorText}`);
    return errorResponse(
      `DeepSeek API error (${deepseekResponse.status})`,
      502,
    );
  }

  const data = await deepseekResponse.json();
  const choices = data.choices as Array<{
    message: { content: string };
  }> | undefined;

  if (!choices || choices.length === 0) {
    return errorResponse("Empty response from DeepSeek", 502);
  }

  const content = choices[0].message.content?.trim() ?? "";
  const totalTokens = (data.usage?.total_tokens as number) ?? 0;

  // ── Réponse vers Flutter ──────────────────────────────────────────────────
  return new Response(
    JSON.stringify({ content, total_tokens: totalTokens }),
    {
      status: 200,
      headers: {
        ...corsHeaders(),
        "Content-Type": "application/json; charset=utf-8",
      },
    },
  );
});

// ── Helpers ─────────────────────────────────────────────────────────────────

function corsHeaders(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}

function errorResponse(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: {
      ...corsHeaders(),
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}
