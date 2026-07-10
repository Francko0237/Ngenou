/// ============================================================
/// AiConfig — Configuration centralisée de tous les paramètres IA
///
/// TOUTES les limites et constantes sont ici.
/// Modifier une valeur ici l'applique partout dans l'app.
/// ============================================================
class AiConfig {
  AiConfig._(); // non instanciable

  // ── Sliding Window (historique envoyé à l'API) ───────────────────────────
  /// Nombre max de messages (user + assistant) envoyés à l'API en mode Flash.
  /// 6 = 3 questions + 3 réponses → ~3 000–5 000 tokens d'historique max.
  static const int slidingWindowFlash = 6;

  /// Nombre max de messages envoyés en mode Pro.
  /// 12 = 6 questions + 6 réponses → ~8 000–12 000 tokens d'historique max.
  static const int slidingWindowPro = 12;

  // ── Max tokens par réponse ───────────────────────────────────────────────
  /// Plafond de tokens de sortie pour le chat tuteur en mode Flash.
  static const int maxOutputTokensChatFlash = 2048;

  /// Plafond de tokens de sortie pour le chat tuteur en mode Pro.
  static const int maxOutputTokensChatPro = 4096;

  /// Plafond de tokens de sortie pour la génération de cours (Flash & Pro).
  /// Gardé à 8192 car les cours nécessitent une sortie longue.
  static const int maxOutputTokensCourseGeneration = 8192;

  /// Plafond de tokens de sortie pour la génération des défis.
  static const int maxOutputTokensChallenges = 4096;

  // ── Quotas journaliers MODE PRO ──────────────────────────────────────────
  // Flash est TOTALEMENT ILLIMITÉ — ces quotas ne s'appliquent qu'au mode Pro.

  /// Tokens de chat consommables par jour en mode Pro avant fallback vers Flash.
  /// Estimation : ~20 sessions de 10 échanges à ~2 500 tokens/échange.
  static const int maxProChatTokensPerDay = 50000;

  /// Nombre max de générations de cours par jour en mode Pro.
  static const int maxProCoursesPerDay = 3;

  /// Nombre max de générations de projets par jour en mode Pro.
  /// Un projet = 1 programme + N cours → très coûteux en tokens.
  static const int maxProProjectsPerDay = 2;

  /// Nombre max de générations de défis par jour en mode Pro.
  static const int maxProChallengesPerDay = 5;

  // ── Clés SharedPreferences pour le cache local des quotas ───────────────
  static const String _prefPrefix = 'ai_quota_pro_';
  static const String prefChatTokens = '${_prefPrefix}chat_tokens';
  static const String prefCoursesCount = '${_prefPrefix}courses_count';
  static const String prefProjectsCount = '${_prefPrefix}projects_count';
  static const String prefChallengesCount = '${_prefPrefix}challenges_count';

  /// Clé stockant la date (YYYY-MM-DD) de la dernière remise à zéro des quotas.
  static const String prefQuotaResetDate = '${_prefPrefix}reset_date';

  // ── Colonne Supabase (table profiles) ───────────────────────────────────
  /// Colonne JSONB dans profiles qui stocke les compteurs Pro côté serveur.
  /// Structure : { "date": "2025-01-01", "chat_tokens": 0,
  ///               "courses": 0, "projects": 0, "challenges": 0 }
  static const String supabaseQuotaColumn = 'ai_pro_quota';
}
