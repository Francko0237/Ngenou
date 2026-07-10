/// api_config.dart
///
/// ⚠️  La clé API DeepSeek ne doit PLUS être stockée ici.
///
/// Depuis la migration vers la Edge Function Supabase (ai-proxy),
/// la clé est stockée dans les secrets Deno côté serveur :
///
///   supabase secrets set DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxxxxx
///
/// Flutter n'a plus accès à cette clé — c'est intentionnel.
/// Ce fichier est conservé pour éviter de casser les imports existants.
class ApiConfig {
  ApiConfig._();
}
