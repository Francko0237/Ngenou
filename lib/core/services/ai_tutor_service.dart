import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/ai_config.dart';
import '../models/deep_seek_model.dart';
import '../services/quota_guard.dart';
import 'auth_service.dart';

// ── Note : api_config.dart et http ne sont plus importés ────────────────────
// L'appel réseau passe désormais par la Edge Function Supabase (ai-proxy).
// La clé API DeepSeek est dans les secrets Deno, pas dans le binaire Flutter.

/// Message dans la conversation tuteur IA.
class TutorMessage {
  final String role; // 'user' ou 'assistant'
  final String content;
  final DateTime timestamp;

  const TutorMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  Map<String, String> toApiMap() => {'role': role, 'content': content};
}

/// Résultat de l'appel au tuteur IA.
class TutorResponse {
  final String content;
  final DeepSeekModel modelUsed;

  /// Message informatif à afficher si fallback activé. null = pas de fallback.
  final String? fallbackMessage;

  const TutorResponse({
    required this.content,
    required this.modelUsed,
    this.fallbackMessage,
  });
}

/// Contexte de la leçon envoyé à l'IA pour des réponses pertinentes.
class LessonContext {
  final String matiereNom;
  final String notionNom;
  final String sectionTitre;
  final String sectionContenu;

  const LessonContext({
    required this.matiereNom,
    required this.notionNom,
    required this.sectionTitre,
    required this.sectionContenu,
  });

  /// ──────────────────────────────────────────────────────────────────────────
  /// BLOC 1 : System Prompt STATIQUE
  ///
  /// Ce bloc ne doit JAMAIS contenir de données dynamiques (username, date,
  /// stats). Il est identique d'un message à l'autre ce qui permet à DeepSeek
  /// de le servir depuis son cache de préfixe (~10 % du coût normal).
  /// ──────────────────────────────────────────────────────────────────────────
  String toStaticSystemPrompt() {
    const languageRule =
        'LANGUAGE RULE (ABSOLUTE PRIORITY — NEVER IGNORE THIS):\n'
        "Always detect the language of the user's LAST message and reply in "
        'that EXACT same language — no exceptions, no override.\n'
        '• User writes in English → you reply in English.\n'
        '• User writes in French  → you reply in French.\n'
        '• User switches language mid-conversation → you switch immediately.\n'
        'Do NOT reply in any language other than the one the user just used.\n\n';

    if (sectionTitre == 'Assistant Global Ngenou') {
      return '$languageRule'
          'Tu es Ngenou, un assistant pédagogique bienveillant.\n\n'
          'CONTENU DE RÉFÉRENCE (figé) :\n'
          '$sectionContenu';
    }

    return '$languageRule'
        'Tu es un tuteur pédagogique expert et bienveillant intégré dans '
        "l'application d'apprentissage Ngenou.\n\n"
        "CONTEXTE DE LA LEÇON (figé pour cette session) :\n"
        '- Matière : $matiereNom\n'
        '- Notion : $notionNom\n'
        '- Section : "$sectionTitre"\n'
        '- Contenu :\n'
        '---\n'
        '$sectionContenu\n'
        '---\n\n'
        'RÈGLES PÉDAGOGIQUES :\n'
        '1. Réponds aux questions liées à cette section ET aux questions connexes.\n'
        '2. Sois pédagogique, clair et encourageant.\n'
        "3. Si l'apprenant est bloqué, reformule avec un exemple différent.\n"
        '4. Utilise des analogies simples pour les concepts difficiles.\n'
        '5. Sois concis sauf si une explication longue est nécessaire.';
  }

  String toStaticSystemPromptWithPro() {
    return '${toStaticSystemPrompt()}\n\n'
        'MODE HAUTE QUALITÉ : Réponds de façon exhaustive, avec exemples '
        'concrets, analogies et étapes numérotées. Chaque ligne de code '
        'doit être commentée.';
  }
}

/// ============================================================
/// AiTutorService — Chat tuteur sécurisé via Edge Function
///
/// ARCHITECTURE DES 4 BLOCS (ordre strict pour le Prompt Cache) :
///  Bloc 1 — System prompt STATIQUE  → hash stable → cache DeepSeek
///  Bloc 2 — Historique (sliding window) → coût contrôlé
///  Bloc 3 — Contexte dynamique (username) → injecté sans casser le cache
///  Bloc 4 — Message utilisateur
/// ============================================================
class AiTutorService {
  /// Envoie une question à l'IA via la Edge Function Supabase `ai-proxy`.
  static Future<TutorResponse> ask({
    required LessonContext context,
    required List<TutorMessage> history,
    DeepSeekModel model = DeepSeekModel.flash,
  }) async {
    // ── Vérification du quota Pro ─────────────────────────────────────────
    final quota = await QuotaGuard.check(
      type: AiOperationType.chat,
      requestedModel: model,
    );

    if (!quota.allowed) {
      throw QuotaExceededException(quota.userMessage!);
    }

    final effectiveModel = quota.effectiveModel;

    // ── Paramètres selon le modèle effectif ──────────────────────────────
    final windowSize = effectiveModel == DeepSeekModel.pro
        ? AiConfig.slidingWindowPro
        : AiConfig.slidingWindowFlash;

    final maxTokens = effectiveModel == DeepSeekModel.pro
        ? AiConfig.maxOutputTokensChatPro
        : AiConfig.maxOutputTokensChatFlash;

    // ── Username frais pour le Bloc 3 ─────────────────────────────────────
    final username = await AuthService.getUsername();

    // ── BLOC 1 : System prompt statique ──────────────────────────────────
    final staticPrompt = effectiveModel == DeepSeekModel.pro
        ? context.toStaticSystemPromptWithPro()
        : context.toStaticSystemPrompt();

    // ── BLOC 2 : Sliding window ───────────────────────────────────────────
    final lastIsUser = history.isNotEmpty && history.last.role == 'user';
    final historyWithoutLast = lastIsUser
        ? history.sublist(0, history.length - 1)
        : history;
    final lastUserMessage = lastIsUser ? history.last : null;

    final windowedHistory = historyWithoutLast.length > windowSize
        ? historyWithoutLast.sublist(historyWithoutLast.length - windowSize)
        : historyWithoutLast;

    // ── Construction du tableau messages ─────────────────────────────────
    final messages = <Map<String, String>>[
      // Bloc 1 — Statique
      {'role': 'system', 'content': staticPrompt},
      // Bloc 2 — Historique filtré
      ...windowedHistory.map((m) => m.toApiMap()),
      // Bloc 3 — Contexte dynamique (après le cache, avant la question)
      if (lastUserMessage != null)
        {
          'role': 'system',
          'content':
              'CONTEXT FRAIS — Apprenant : "$username". '
              'RAPPEL LANGUE : réponds dans la même langue que le prochain message.',
        },
      // Bloc 4 — Question utilisateur
      if (lastUserMessage != null) lastUserMessage.toApiMap(),
    ];

    // ── Appel via la Edge Function (plus de clé API dans Flutter) ────────
    final payload = <String, dynamic>{
      'messages': messages,
      'model': effectiveModel.apiId,
      'max_tokens': maxTokens,
      'temperature': effectiveModel == DeepSeekModel.pro ? 0.7 : 0.6,
    };

    final response = await Supabase.instance.client.functions.invoke(
      'ia-proxy',
      body: payload,
    );

    final data = response.data as Map<String, dynamic>?;
    if (data == null) throw Exception("Réponse vide de la Edge Function.");

    final error = data['error'] as String?;
    if (error != null) throw Exception('Erreur IA : $error');

    final replyContent = (data['content'] as String? ?? '').trim();
    final totalTokens =
        (data['total_tokens'] as num?)?.toInt() ?? (replyContent.length ~/ 4);

    // ── Enregistrement quota ──────────────────────────────────────────────
    await QuotaGuard.record(
      type: AiOperationType.chat,
      model: effectiveModel,
      tokensUsed: totalTokens,
    );

    return TutorResponse(
      content: replyContent,
      modelUsed: effectiveModel,
      fallbackMessage: quota.userMessage,
    );
  }
}
