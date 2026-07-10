import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/ai_config.dart';
import '../models/deep_seek_model.dart';

/// Exception levée quand le quota Pro est bloqué (limite = 0 ou désactivé).
/// Contient le message à afficher à l'utilisateur dans le chat ou l'UI.
class QuotaExceededException implements Exception {
  final String message;
  const QuotaExceededException(this.message);

  @override
  String toString() => message;
}

/// Type d'opération IA — permet au guard de savoir quel quota vérifier.
enum AiOperationType { chat, course, project, challenge }

/// Résultat retourné par le QuotaGuard.
class QuotaCheckResult {
  /// true = opération autorisée avec le modèle [effectiveModel].
  final bool allowed;

  /// Modèle à utiliser effectivement (peut être Flash si fallback activé).
  final DeepSeekModel effectiveModel;

  /// Message à afficher à l'utilisateur si [allowed] est false ou si fallback.
  /// null = pas de message (opération normale).
  final String? userMessage;

  const QuotaCheckResult({
    required this.allowed,
    required this.effectiveModel,
    this.userMessage,
  });

  /// Shortcut : opération autorisée sans changement de modèle.
  factory QuotaCheckResult.ok(DeepSeekModel model) =>
      QuotaCheckResult(allowed: true, effectiveModel: model);

  /// Shortcut : fallback vers Flash avec message informatif.
  factory QuotaCheckResult.fallback(String message) => QuotaCheckResult(
    allowed: true,
    effectiveModel: DeepSeekModel.flash,
    userMessage: message,
  );

  /// Shortcut : opération bloquée (quota global dépassé, cas extrême).
  factory QuotaCheckResult.blocked(String message) => QuotaCheckResult(
    allowed: false,
    effectiveModel: DeepSeekModel.flash,
    userMessage: message,
  );
}

/// ============================================================
/// QuotaGuard — Gestion des quotas Flash (illimité) vs Pro (limité)
///
/// STRATÉGIE :
///  • Flash → toujours autorisé, aucun compteur.
///  • Pro   → vérifie le cache local (SharedPreferences) en premier,
///            puis Supabase pour la vérification croisée multi-appareils.
///  • Si un quota Pro est atteint → fallback silencieux vers Flash
///    (l'utilisateur peut continuer mais sur le modèle standard).
///  • Remise à zéro automatique à minuit (comparaison de date ISO).
/// ============================================================
class QuotaGuard {
  QuotaGuard._();

  static final SupabaseClient _supabase = Supabase.instance.client;

  // ── API publique ─────────────────────────────────────────────────────────

  /// Vérifie si l'opération [type] est autorisée pour le [requestedModel].
  /// Retourne toujours un [QuotaCheckResult] — jamais d'exception.
  static Future<QuotaCheckResult> check({
    required AiOperationType type,
    required DeepSeekModel requestedModel,
  }) async {
    // Flash est illimité — aucune vérification nécessaire.
    if (requestedModel == DeepSeekModel.flash) {
      return QuotaCheckResult.ok(DeepSeekModel.flash);
    }

    // Pro : vérifier le quota local (rapide) puis Supabase (fiable).
    try {
      await _resetIfNewDay();
      final localCount = await _getLocalCount(type);
      final limit = _limitFor(type);

      // ── Limite = 0 : fonctionnalité Pro désactivée, blocage total ──────
      // Quand limit = 0, aucun appel n'est autorisé en Pro.
      // L'utilisateur voit un message clair et aucune requête API n'est faite.
      if (limit == 0) {
        return QuotaCheckResult.blocked(_blockedMessage(type));
      }

      // ── Quota atteint : fallback Flash (appel autorisé mais en Flash) ──
      if (localCount >= limit) {
        return QuotaCheckResult.fallback(_fallbackMessage(type, limit));
      }

      // Vérification Supabase si l'utilisateur est connecté (multi-appareils)
      if (_isAuthenticated()) {
        final serverCount = await _getServerCount(type);
        if (serverCount >= limit) {
          await _setLocalCount(type, serverCount);
          return QuotaCheckResult.fallback(_fallbackMessage(type, limit));
        }
      }

      return QuotaCheckResult.ok(DeepSeekModel.pro);
    } catch (_) {
      // En cas d'erreur réseau ou autre → on laisse passer en Pro
      // pour ne pas bloquer l'utilisateur sur une erreur technique.
      return QuotaCheckResult.ok(DeepSeekModel.pro);
    }
  }

  /// Enregistre la consommation après un appel réussi.
  /// [tokensUsed] : uniquement pour les opérations de type [AiOperationType.chat].
  static Future<void> record({
    required AiOperationType type,
    required DeepSeekModel model,
    int tokensUsed = 0,
  }) async {
    // Flash : aucun enregistrement nécessaire.
    if (model == DeepSeekModel.flash) return;

    try {
      await _resetIfNewDay();

      if (type == AiOperationType.chat) {
        // Pour le chat, on incrémente le compteur de tokens.
        final current = await _getLocalCount(type);
        final newVal = current + tokensUsed;
        await _setLocalCount(type, newVal);
        if (_isAuthenticated()) {
          await _incrementServerCount(type, delta: tokensUsed);
        }
      } else {
        // Pour cours / projet / défis, on incrémente de 1.
        final current = await _getLocalCount(type);
        await _setLocalCount(type, current + 1);
        if (_isAuthenticated()) {
          await _incrementServerCount(type, delta: 1);
        }
      }
    } catch (_) {
      // Erreur silencieuse — ne pas bloquer l'utilisateur.
    }
  }

  // ── Remise à zéro automatique ────────────────────────────────────────────

  static Future<void> _resetIfNewDay() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayStr();
    final stored = prefs.getString(AiConfig.prefQuotaResetDate);
    if (stored != today) {
      // Nouveau jour → remettre tous les compteurs à zéro
      await prefs.setInt(AiConfig.prefChatTokens, 0);
      await prefs.setInt(AiConfig.prefCoursesCount, 0);
      await prefs.setInt(AiConfig.prefProjectsCount, 0);
      await prefs.setInt(AiConfig.prefChallengesCount, 0);
      await prefs.setString(AiConfig.prefQuotaResetDate, today);
    }
  }

  // ── Helpers locaux (SharedPreferences) ───────────────────────────────────

  static Future<int> _getLocalCount(AiOperationType type) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefKeyFor(type)) ?? 0;
  }

  static Future<void> _setLocalCount(AiOperationType type, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyFor(type), value);
  }

  static String _prefKeyFor(AiOperationType type) {
    switch (type) {
      case AiOperationType.chat:
        return AiConfig.prefChatTokens;
      case AiOperationType.course:
        return AiConfig.prefCoursesCount;
      case AiOperationType.project:
        return AiConfig.prefProjectsCount;
      case AiOperationType.challenge:
        return AiConfig.prefChallengesCount;
    }
  }

  // ── Helpers Supabase ─────────────────────────────────────────────────────

  static bool _isAuthenticated() =>
      Supabase.instance.client.auth.currentUser != null;

  static String _userId() => Supabase.instance.client.auth.currentUser!.id;

  /// Récupère le compteur pour [type] depuis Supabase (colonne JSONB).
  static Future<int> _getServerCount(AiOperationType type) async {
    final data = await _supabase
        .from('users')
        .select(AiConfig.supabaseQuotaColumn)
        .eq('id', _userId())
        .maybeSingle();

    if (data == null) return 0;
    final quota = data[AiConfig.supabaseQuotaColumn] as Map<String, dynamic>?;
    if (quota == null) return 0;

    // Vérifier si la date serveur correspond à aujourd'hui
    final serverDate = quota['date'] as String?;
    if (serverDate != _todayStr()) return 0; // Nouveau jour côté serveur

    return (quota[_serverKeyFor(type)] as num?)?.toInt() ?? 0;
  }

  /// Incrémente le compteur [type] dans Supabase de [delta].
  static Future<void> _incrementServerCount(
    AiOperationType type, {
    required int delta,
  }) async {
    // Lire d'abord la valeur actuelle depuis 'users'
    final data = await _supabase
        .from('users')
        .select(AiConfig.supabaseQuotaColumn)
        .eq('id', _userId())
        .maybeSingle();

    final today = _todayStr();
    Map<String, dynamic> quota = {'date': today};

    if (data != null) {
      final existing =
          data[AiConfig.supabaseQuotaColumn] as Map<String, dynamic>?;
      if (existing != null && existing['date'] == today) {
        quota = Map<String, dynamic>.from(existing);
      }
    }

    final key = _serverKeyFor(type);
    quota[key] = ((quota[key] as num?)?.toInt() ?? 0) + delta;
    quota['date'] = today;

    await _supabase.from('users').upsert({
      'id': _userId(),
      AiConfig.supabaseQuotaColumn: quota,
    });
  }

  static String _serverKeyFor(AiOperationType type) {
    switch (type) {
      case AiOperationType.chat:
        return 'chat_tokens';
      case AiOperationType.course:
        return 'courses';
      case AiOperationType.project:
        return 'projects';
      case AiOperationType.challenge:
        return 'challenges';
    }
  }

  // ── Helpers divers ───────────────────────────────────────────────────────

  static int _limitFor(AiOperationType type) {
    switch (type) {
      case AiOperationType.chat:
        return AiConfig.maxProChatTokensPerDay;
      case AiOperationType.course:
        return AiConfig.maxProCoursesPerDay;
      case AiOperationType.project:
        return AiConfig.maxProProjectsPerDay;
      case AiOperationType.challenge:
        return AiConfig.maxProChallengesPerDay;
    }
  }

  static String _fallbackMessage(AiOperationType type, int limit) {
    switch (type) {
      case AiOperationType.chat:
        return 'Quota journalier Ngenou Pro atteint ($limit tokens). '
            'Basculement automatique sur Ngenou Flash pour continuer.';
      case AiOperationType.course:
        return 'Limite journalière de $limit générations de cours en mode Pro atteinte. '
            'Le cours sera généré avec Ngenou Flash.';
      case AiOperationType.project:
        return 'Limite journalière de $limit projets en mode Pro atteinte. '
            'Le projet sera généré avec Ngenou Flash.';
      case AiOperationType.challenge:
        return 'Limite journalière de $limit défis en mode Pro atteinte. '
            'Les défis seront générés avec Ngenou Flash.';
    }
  }

  /// Message de blocage complet (limite = 0 → Pro désactivé côté config).
  static String _blockedMessage(AiOperationType type) {
    switch (type) {
      case AiOperationType.chat:
        return '⚠️ Le mode Ngenou Pro n\'est pas disponible pour le chat en ce moment. '
            'Passe en mode Flash pour continuer à discuter.';
      case AiOperationType.course:
        return '⚠️ La génération de cours en mode Ngenou Pro n\'est pas disponible aujourd\'hui. '
            'Passe en mode Flash pour générer ce cours.';
      case AiOperationType.project:
        return '⚠️ La génération de projets en mode Ngenou Pro n\'est pas disponible aujourd\'hui. '
            'Passe en mode Flash pour créer ce projet.';
      case AiOperationType.challenge:
        return '⚠️ La génération de défis en mode Ngenou Pro n\'est pas disponible aujourd\'hui. '
            'Passe en mode Flash pour générer tes défis.';
    }
  }

  static String _todayStr() =>
      DateTime.now().toIso8601String().substring(0, 10);
}
