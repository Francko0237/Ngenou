import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/ai_config.dart';
import '../models/deep_seek_model.dart';
import '../services/quota_guard.dart';

// ── Note : api_config.dart n'est plus importé ────────────────────────────────
// La clé API DeepSeek est désormais stockée dans les secrets Deno de la
// Edge Function Supabase (ai-proxy). Flutter ne manipule plus jamais la clé.

/// Résultat d'une génération — inclut le contenu et le modèle effectivement utilisé.
class GenerationResult {
  final String content;
  final DeepSeekModel modelUsed;

  /// Message informatif si fallback Pro → Flash activé. null = normal.
  final String? fallbackMessage;

  const GenerationResult({
    required this.content,
    required this.modelUsed,
    this.fallbackMessage,
  });
}

class DeepSeekService {
  // ── Génération de cours ─────────────────────────────────────────────────

  /// Envoie un prompt à la Edge Function pour générer un cours complet.
  /// Lève [QuotaExceededException] si le quota Pro est bloqué (limite = 0).
  static Future<GenerationResult> generateCourse(
    String prompt, {
    DeepSeekModel model = DeepSeekModel.flash,
  }) async {
    final quota = await QuotaGuard.check(
      type: AiOperationType.course,
      requestedModel: model,
    );

    if (!quota.allowed) throw QuotaExceededException(quota.userMessage!);

    final effectiveModel = quota.effectiveModel;

    const baseSystemPrompt =
        'Tu es un expert en pédagogie et en conception de cours. '
        'Tu réponds UNIQUEMENT par un objet JSON brut, valide et sans blocs '
        'de code markdown (pas de ```json ... ```).';
    final systemContent = effectiveModel == DeepSeekModel.pro
        ? '$baseSystemPrompt\n\n'
              'MODE HAUTE QUALITÉ : Génère un contenu exhaustif, avec des '
              'explications détaillées, des exemples concrets et du code '
              'intégralement commenté ligne par ligne.'
        : baseSystemPrompt;

    final result = await _invoke(
      systemContent: systemContent,
      userPrompt: prompt,
      model: effectiveModel,
      maxTokens: AiConfig.maxOutputTokensCourseGeneration,
      temperature: effectiveModel == DeepSeekModel.pro ? 0.6 : 0.5,
      responseFormat: 'json_object',
    );

    await QuotaGuard.record(
      type: AiOperationType.course,
      model: effectiveModel,
    );

    return GenerationResult(
      content: result.content,
      modelUsed: effectiveModel,
      fallbackMessage: quota.userMessage,
    );
  }

  // ── Génération du programme d'un projet ────────────────────────────────

  /// Génère le programme (liste de matières) d'un projet.
  static Future<GenerationResult> generateProgram(
    String prompt, {
    DeepSeekModel model = DeepSeekModel.flash,
  }) async {
    final quota = await QuotaGuard.check(
      type: AiOperationType.project,
      requestedModel: model,
    );

    if (!quota.allowed) throw QuotaExceededException(quota.userMessage!);

    final effectiveModel = quota.effectiveModel;

    const baseSystemPrompt =
        'Tu es un expert en ingénierie pédagogique. '
        'Tu réponds UNIQUEMENT par un objet JSON brut et valide, '
        'sans blocs de code markdown.';
    final systemContent = effectiveModel == DeepSeekModel.pro
        ? '$baseSystemPrompt\n\n'
              'MODE HAUTE QUALITÉ : Génère un programme détaillé avec des '
              'descriptions riches et une progression pédagogique optimale.'
        : baseSystemPrompt;

    final result = await _invoke(
      systemContent: systemContent,
      userPrompt: prompt,
      model: effectiveModel,
      maxTokens: AiConfig.maxOutputTokensCourseGeneration,
      temperature: effectiveModel == DeepSeekModel.pro ? 0.6 : 0.7,
      responseFormat: 'json_object',
    );

    await QuotaGuard.record(
      type: AiOperationType.project,
      model: effectiveModel,
    );

    return GenerationResult(
      content: result.content,
      modelUsed: effectiveModel,
      fallbackMessage: quota.userMessage,
    );
  }

  // ── Génération des défis quotidiens ────────────────────────────────────

  /// Génère les défis QCM + algo du jour.
  static Future<GenerationResult> generateDailyChallenges(
    String prompt, {
    DeepSeekModel model = DeepSeekModel.flash,
  }) async {
    final quota = await QuotaGuard.check(
      type: AiOperationType.challenge,
      requestedModel: model,
    );

    if (!quota.allowed) throw QuotaExceededException(quota.userMessage!);

    final effectiveModel = quota.effectiveModel;

    const baseSystemPrompt =
        'Tu es un expert en ingénierie pédagogique et informatique. '
        'Tu réponds UNIQUEMENT par un objet JSON brut et valide, '
        'sans blocs de code markdown. '
        "Pour tout pseudocode algorithmique, utilise EXCLUSIVEMENT l'opérateur "
        '<- pour l\'affectation. Exemple : x <- 3. INTERDIT : x := 3.';
    final systemContent = effectiveModel == DeepSeekModel.pro
        ? '$baseSystemPrompt\n\n'
              'MODE HAUTE QUALITÉ : Génère des défis variés, progressifs, '
              'avec des explications pédagogiques claires.'
        : baseSystemPrompt;

    final result = await _invoke(
      systemContent: systemContent,
      userPrompt: prompt,
      model: effectiveModel,
      maxTokens: AiConfig.maxOutputTokensChallenges,
      temperature: effectiveModel == DeepSeekModel.pro ? 0.6 : 0.7,
      responseFormat: 'json_object',
    );

    await QuotaGuard.record(
      type: AiOperationType.challenge,
      model: effectiveModel,
    );

    return GenerationResult(
      content: result.content,
      modelUsed: effectiveModel,
      fallbackMessage: quota.userMessage,
    );
  }

  // ── Méthode d'invocation centrale (remplace http.post) ──────────────────

  /// Appelle la Edge Function Supabase `ai-proxy` au lieu de DeepSeek directement.
  /// La clé API reste dans les secrets Deno — Flutter ne la voit jamais.
  static Future<({String content, int totalTokens})> _invoke({
    required String systemContent,
    required String userPrompt,
    required DeepSeekModel model,
    required int maxTokens,
    required double temperature,
    String? responseFormat,
  }) async {
    final payload = <String, dynamic>{
      'messages': [
        {'role': 'system', 'content': systemContent},
        {'role': 'user', 'content': userPrompt},
      ],
      'model': model.apiId,
      'max_tokens': maxTokens,
      'temperature': temperature,
    };

    if (responseFormat != null) {
      payload['response_format'] = {'type': responseFormat};
    }

    final response = await Supabase.instance.client.functions.invoke(
      'ia-proxy',
      body: payload,
    );

    // FunctionsException est levée automatiquement par le SDK si status != 2xx
    final data = response.data as Map<String, dynamic>?;
    if (data == null) {
      throw Exception("Réponse vide de la Edge Function.");
    }

    // Erreur applicative renvoyée par la fonction (ex: quota serveur)
    final error = data['error'] as String?;
    if (error != null) {
      throw Exception('Erreur IA : $error');
    }

    final content = data['content'] as String? ?? '';
    final totalTokens = (data['total_tokens'] as num?)?.toInt() ?? 0;

    return (content: content, totalTokens: totalTokens);
  }
}
