-- ==============================================================================
-- MIGRATION NGENOU — SITE WEB ADMIN + QUOTA IA
-- Date: 2026-11-11
-- 
-- Ce script fait 3 choses :
--   1. Ajoute la colonne `ai_pro_quota` dans `profiles` (quota IA journalier)
--   2. Crée les tables `app_releases` et `release_features` (site vitrine)
--   3. Configure toutes les RLS policies nécessaires
--
-- À EXÉCUTER dans l'éditeur SQL de Supabase (interface web → SQL Editor)
-- ==============================================================================

-- ──────────────────────────────────────────────────────────────────────────────
-- 1. COLONNE QUOTA IA DANS profiles
-- (remplace l'ancienne tentative d'écriture dans une table 'users' inexistante)
-- Structure JSONB : { "date": "2025-01-01", "chat_tokens": 0, "courses": 0,
--                    "projects": 0, "challenges": 0 }
-- ──────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS ai_pro_quota JSONB DEFAULT '{}'::jsonb;

-- Index GIN pour requêtes JSONB efficaces
CREATE INDEX IF NOT EXISTS idx_profiles_ai_pro_quota
  ON public.profiles USING GIN (ai_pro_quota);

-- ──────────────────────────────────────────────────────────────────────────────
-- 2. TABLE APP_RELEASES (versions publiées de l'app mobile)
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.app_releases (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  version_code    INT         NOT NULL UNIQUE,
  version_name    TEXT        NOT NULL,
  title           TEXT        NOT NULL,
  notes           TEXT        NOT NULL DEFAULT '',
  apk_url         TEXT,
  force_update    BOOLEAN     NOT NULL DEFAULT false,
  is_published    BOOLEAN     NOT NULL DEFAULT false,
  published_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_app_releases_published
  ON public.app_releases (is_published, version_code DESC);

-- ──────────────────────────────────────────────────────────────────────────────
-- 3. TABLE RELEASE_FEATURES (liste des nouveautés par version)
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.release_features (
  id          UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  release_id  UUID    NOT NULL REFERENCES public.app_releases(id) ON DELETE CASCADE,
  icon        TEXT    NOT NULL DEFAULT 'star',
  title       TEXT    NOT NULL,
  description TEXT    NOT NULL DEFAULT '',
  sort_order  INT     NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_release_features_release_id
  ON public.release_features (release_id, sort_order ASC);

-- ──────────────────────────────────────────────────────────────────────────────
-- 4. TRIGGER : mise à jour automatique de updated_at
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc', now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_app_releases_updated_at ON public.app_releases;
CREATE TRIGGER trg_app_releases_updated_at
  BEFORE UPDATE ON public.app_releases
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ──────────────────────────────────────────────────────────────────────────────
-- 5. ROW LEVEL SECURITY
-- ──────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.app_releases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.release_features ENABLE ROW LEVEL SECURITY;

-- Helper is_admin() basée sur profiles.role (aucune table admin_users séparée)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- app_releases : lecture publique des releases publiées
DROP POLICY IF EXISTS "Lecture publique des releases publiées" ON public.app_releases;
CREATE POLICY "Lecture publique des releases publiées"
  ON public.app_releases FOR SELECT
  TO anon, authenticated
  USING (is_published = true);

DROP POLICY IF EXISTS "Admin voit toutes les releases" ON public.app_releases;
CREATE POLICY "Admin voit toutes les releases"
  ON public.app_releases FOR SELECT
  TO authenticated
  USING (public.is_admin());

DROP POLICY IF EXISTS "Admin peut insérer une release" ON public.app_releases;
CREATE POLICY "Admin peut insérer une release"
  ON public.app_releases FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admin peut modifier une release" ON public.app_releases;
CREATE POLICY "Admin peut modifier une release"
  ON public.app_releases FOR UPDATE
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admin peut supprimer une release" ON public.app_releases;
CREATE POLICY "Admin peut supprimer une release"
  ON public.app_releases FOR DELETE
  TO authenticated
  USING (public.is_admin());

-- release_features : lecture publique si la release associée est publiée
DROP POLICY IF EXISTS "Lecture publique des features publiées" ON public.release_features;
CREATE POLICY "Lecture publique des features publiées"
  ON public.release_features FOR SELECT
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.app_releases ar
      WHERE ar.id = release_id AND ar.is_published = true
    )
  );

DROP POLICY IF EXISTS "Admin voit toutes les features" ON public.release_features;
CREATE POLICY "Admin voit toutes les features"
  ON public.release_features FOR SELECT
  TO authenticated
  USING (public.is_admin());

DROP POLICY IF EXISTS "Admin peut insérer une feature" ON public.release_features;
CREATE POLICY "Admin peut insérer une feature"
  ON public.release_features FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admin peut modifier une feature" ON public.release_features;
CREATE POLICY "Admin peut modifier une feature"
  ON public.release_features FOR UPDATE
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admin peut supprimer une feature" ON public.release_features;
CREATE POLICY "Admin peut supprimer une feature"
  ON public.release_features FOR DELETE
  TO authenticated
  USING (public.is_admin());

-- ──────────────────────────────────────────────────────────────────────────────
-- 6. PROMOUVOIR UN COMPTE EN ADMIN
-- Remplace <USER_UUID> par l'UUID de ton compte dans Supabase Auth Dashboard
-- (Authentication → Users → copier l'UUID)
-- ──────────────────────────────────────────────────────────────────────────────
-- UPDATE public.profiles SET role = 'admin' WHERE id = '<USER_UUID>';
