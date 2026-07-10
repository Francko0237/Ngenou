/// Traduit une exception technique en message lisible pour l'utilisateur.
/// Catégorise les erreurs par type (réseau, API, timeout, etc.)
/// pour afficher un message clair au lieu du détail technique.
String formatUserError(Object error) {
  final raw = error.toString().toLowerCase();

  // ── Connexion / réseau ──────────────────────────────────────────────────
  if (raw.contains('socketexception') ||
      raw.contains('failed host lookup') ||
      raw.contains('network is unreachable') ||
      raw.contains('connection refused') ||
      raw.contains('connection reset') ||
      raw.contains('no route to host') ||
      raw.contains('network error') ||
      raw.contains('no internet') ||
      raw.contains('errno = 101') || // ENETUNREACH
      raw.contains('errno = 111')) {
    // ECONNREFUSED
    return 'Impossible d\'accéder au service. Vérifiez votre connexion internet puis réessayez.';
  }

  // ── Timeout ─────────────────────────────────────────────────────────────
  if (raw.contains('timeout') ||
      raw.contains('timed out') ||
      raw.contains('timeoutexception')) {
    return 'La connexion a pris trop de temps. Vérifiez votre connexion et réessayez.';
  }

  // ── Edge Function Supabase ──────────────────────────────────────────────
  if (raw.contains('functionsexception') ||
      raw.contains('functions') && raw.contains('invoke') ||
      raw.contains('edge function') ||
      raw.contains('non-2xx status code') ||
      raw.contains('failed to send')) {
    return 'Le service IA est temporairement inaccessible. Vérifiez votre connexion et réessayez.';
  }

  // ── Supabase générique ──────────────────────────────────────────────────
  if (raw.contains('postgrestexception') ||
      raw.contains('supabase') && raw.contains('error')) {
    return 'Erreur de communication avec le serveur. Réessayez.';
  }

  // ── Clé API manquante ────────────────────────────────────────────────────
  if (raw.contains('clé api') ||
      raw.contains('api key') ||
      raw.contains('non configurée') ||
      raw.contains('dart-define')) {
    return 'Le service IA n\'est pas configuré. Contactez le support.';
  }

  // ── Erreur API (code HTTP) ───────────────────────────────────────────────
  if (raw.contains('erreur api 401') ||
      raw.contains('status code 401') ||
      raw.contains('unauthorized')) {
    return 'Accès refusé au service IA. Contactez le support.';
  }

  if (raw.contains('erreur api 429') ||
      raw.contains('status code 429') ||
      raw.contains('rate limit') ||
      raw.contains('too many requests')) {
    return 'Trop de requêtes envoyées. Attendez quelques secondes puis réessayez.';
  }

  if (raw.contains('erreur api 5') ||
      raw.contains('status code 5') ||
      raw.contains('server error') ||
      raw.contains('internal server')) {
    return 'Le service est temporairement indisponible. Réessayez dans quelques instants.';
  }

  // ── Réponse vide ────────────────────────────────────────────────────────
  if (raw.contains('réponse vide') ||
      raw.contains('empty response') ||
      raw.contains('choices.isempty')) {
    return 'Le service n\'a pas pu générer une réponse. Réessayez.';
  }

  // ── JSON invalide ────────────────────────────────────────────────────────
  if (raw.contains('jsondecodeerror') ||
      raw.contains('formatexception') ||
      raw.contains('invalid json') ||
      raw.contains('unexpected character')) {
    return 'La réponse reçue est invalide. Réessayez — si le problème persiste, contactez le support.';
  }

  // ── Alarmes exactes ──────────────────────────────────────────────────────
  if (raw.contains('exact_alarms_not_permitted')) {
    return 'Autorisez les alarmes exactes : Paramètres → Applications → Ngenou → Alarmes et rappels.';
  }

  // ── Pas de matières ─────────────────────────────────────────────────────
  if (raw.contains('aucune matière') || raw.contains('no module')) {
    return 'Aucun cours trouvé. Ajoutez d\'abord un cours ou un projet pour générer des défis.';
  }

  // ── Erreur générique lisible (déjà formatée par le dev) ─────────────────
  // Si le message commence par une majuscule et ne contient pas de stack trace
  // ni de noms de classes Java/Dart, on l'affiche tel quel.
  final cleaned = error
      .toString()
      .replaceAll('Exception: ', '')
      .replaceAll('Error: ', '')
      .trim();

  if (cleaned.length < 120 &&
      !cleaned.contains('at ') &&
      !cleaned.contains('.dart:') &&
      !cleaned.contains('package:')) {
    return cleaned;
  }

  // ── Fallback générique ──────────────────────────────────────────────────
  return 'Une erreur inattendue s\'est produite. Réessayez ou redémarrez l\'application.';
}
