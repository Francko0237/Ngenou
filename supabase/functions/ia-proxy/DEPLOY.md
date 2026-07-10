# Déploiement de la Edge Function `ai-proxy`

## Prérequis

Installe le CLI Supabase si ce n'est pas déjà fait :
```bash
brew install supabase/tap/supabase       # macOS
# ou
npm install -g supabase                  # npm
# ou
curl -fsSL https://supabase.com/install.sh | sh  # Linux
```

## Étapes

### 1. Lier le projet au CLI
```bash
# Depuis la racine du projet Flutter/Ngenou
supabase login
supabase link --project-ref <TON_PROJECT_REF>
```
> Ton `project-ref` se trouve dans Supabase Dashboard → Settings → General → Reference ID

---

### 2. Stocker la clé API DeepSeek en secret Deno
```bash
supabase secrets set DEEPSEEK_API_KEY=<TA_CLE_DEEPSEEK_ICI>
```
> ⚠️  Ne commit JAMAIS cette commande dans git. Le secret est chiffré côté Supabase.

Vérifier que le secret est bien enregistré :
```bash
supabase secrets list
```

---

### 3. Déployer la Edge Function
```bash
supabase functions deploy ai-proxy --no-verify-jwt
```

> `--no-verify-jwt` est retiré si tu veux forcer l'authentification Supabase côté Edge Function (recommandé en production — la fonction vérifie déjà le header Authorization manuellement).

---

### 4. Vérifier le déploiement
```bash
# Test rapide avec curl (remplace <PROJECT_REF> et <ANON_KEY>)
curl -X POST \
  https://<PROJECT_REF>.supabase.co/functions/v1/ai-proxy \
  -H "Authorization: Bearer <ANON_KEY>" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Dis bonjour en une phrase."}],
    "model": "deepseek-chat",
    "max_tokens": 100,
    "temperature": 0.5
  }'
```

Réponse attendue :
```json
{
  "content": "Bonjour ! Comment puis-je vous aider ?",
  "total_tokens": 42
}
```

---

### 5. Migration SQL — Ajouter la colonne quota dans `profiles`

Si la colonne `ai_pro_quota` n'existe pas encore dans ta table `profiles`, exécute cette migration dans Supabase Dashboard → SQL Editor :

```sql
-- Ajouter la colonne JSONB pour les quotas Pro IA
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS ai_pro_quota JSONB DEFAULT NULL;

-- Index pour accélérer les lectures de quota
CREATE INDEX IF NOT EXISTS idx_profiles_ai_pro_quota
  ON profiles USING gin (ai_pro_quota);
```

---

## Mise à jour de la fonction

```bash
# À chaque modification de index.ts
supabase functions deploy ai-proxy
```

## Logs en temps réel

```bash
supabase functions logs ai-proxy --tail
```
