-- ==============================================================================
-- NGENOU - MIGRATION SUPABASE COMPLÈTE
-- Tables: app_releases, release_features, admin_users
-- Storage: release-media, apks
-- Politiques RLS (Row Level Security) strictes
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. TABLE DES ADMINISTRATEURS
-- Contient les identifiants d'utilisateurs autorisés à administrer les versions
CREATE TABLE IF NOT EXISTS public.admin_users (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.admin_users IS 'Utilisateurs ayant les droits administrateurs sur Ngenou Web';

-- 3. TABLE DES VERSIONS DE L'APPLICATION (app_releases)
CREATE TABLE IF NOT EXISTS public.app_releases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version_name TEXT NOT NULL,                  -- Ex: "1.2.0"
    version_code INT NOT NULL UNIQUE,            -- Ex: 12 (sert à comparer les versions)
    title TEXT NOT NULL,                         -- Ex: "Mise à jour majeure : Ngenou Assets"
    notes TEXT NOT NULL,                         -- Description globale / changelog
    apk_url TEXT,                                -- URL de téléchargement du fichier APK
    force_update BOOLEAN NOT NULL DEFAULT FALSE, -- Si true, l'application mobile bloque jusqu'à màj
    is_published BOOLEAN NOT NULL DEFAULT FALSE, -- Si true, visible sur le site et renvoyé à l'app
    published_at TIMESTAMPTZ,                    -- Date effective de publication
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_releases_version_code ON public.app_releases(version_code DESC);
CREATE INDEX IF NOT EXISTS idx_app_releases_is_published ON public.app_releases(is_published, published_at DESC);

COMMENT ON TABLE public.app_releases IS 'Versions publiées ou en brouillon de Ngenou Mobile';

-- 4. TABLE DES FONCTIONNALITÉS PAR VERSION (release_features)
CREATE TABLE IF NOT EXISTS public.release_features (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_id UUID NOT NULL REFERENCES public.app_releases(id) ON DELETE CASCADE,
    title TEXT NOT NULL,                         -- Ex: "Nouveau mode hors-ligne"
    body TEXT NOT NULL,                          -- Détail explicatif
    image_url TEXT,                              -- Image d'illustration hébergée dans release-media
    sort_order INT NOT NULL DEFAULT 0,           -- Ordre d'affichage
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_release_features_release ON public.release_features(release_id, sort_order ASC);

COMMENT ON TABLE public.release_features IS 'Blocs de fonctionnalités et captures pour chaque mise à jour';

-- ==============================================================================
-- 5. ROW LEVEL SECURITY (RLS)
-- ==============================================================================

-- Activer RLS sur toutes les tables
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_releases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.release_features ENABLE ROW LEVEL SECURITY;

-- Helper function pour tester si l'utilisateur courant est admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.admin_users
        WHERE user_id = auth.uid()
    );
$$;

-- RLS: admin_users
-- L'admin connecté peut vérifier s'il est admin
CREATE POLICY "admin_users_select_self"
ON public.admin_users
FOR SELECT
TO authenticated
USING (user_id = auth.uid() OR public.is_admin());

-- Seul un admin existant (ou service_role) peut modifier les admins
CREATE POLICY "admin_users_all_admin"
ON public.admin_users
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- RLS: app_releases
-- Tout le monde (anon + authenticated) peut lire les versions publiées
CREATE POLICY "public_read_published_releases"
ON public.app_releases
FOR SELECT
TO anon, authenticated
USING (is_published = true);

-- Les admins ont tous les droits sur app_releases
CREATE POLICY "admin_all_releases"
ON public.app_releases
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- RLS: release_features
-- Tout le monde peut lire les features associées aux releases publiées
CREATE POLICY "public_read_published_features"
ON public.release_features
FOR SELECT
TO anon, authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.app_releases r
        WHERE r.id = release_features.release_id
          AND r.is_published = true
    )
);

-- Les admins ont tous les droits sur release_features
CREATE POLICY "admin_all_features"
ON public.release_features
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- ==============================================================================
-- 6. CONFIGURATION DU STORAGE
-- ==============================================================================

-- Création des buckets publics
INSERT INTO storage.buckets (id, name, public)
VALUES ('release-media', 'release-media', true)
ON CONFLICT (id) DO UPDATE SET public = true;

INSERT INTO storage.buckets (id, name, public)
VALUES ('apks', 'apks', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Politiques de lecture publique sur les buckets
DROP POLICY IF EXISTS "Public read release-media" ON storage.objects;
CREATE POLICY "Public read release-media"
ON storage.objects FOR SELECT
TO anon, authenticated
USING (bucket_id = 'release-media');

DROP POLICY IF EXISTS "Public read apks" ON storage.objects;
CREATE POLICY "Public read apks"
ON storage.objects FOR SELECT
TO anon, authenticated
USING (bucket_id = 'apks');

-- Politiques d'écriture réservées aux administrateurs
DROP POLICY IF EXISTS "Admin write release-media" ON storage.objects;
CREATE POLICY "Admin write release-media"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'release-media' AND public.is_admin());

DROP POLICY IF EXISTS "Admin update release-media" ON storage.objects;
CREATE POLICY "Admin update release-media"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'release-media' AND public.is_admin());

DROP POLICY IF EXISTS "Admin delete release-media" ON storage.objects;
CREATE POLICY "Admin delete release-media"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'release-media' AND public.is_admin());

DROP POLICY IF EXISTS "Admin write apks" ON storage.objects;
CREATE POLICY "Admin write apks"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'apks' AND public.is_admin());

DROP POLICY IF EXISTS "Admin update apks" ON storage.objects;
CREATE POLICY "Admin update apks"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'apks' AND public.is_admin());

DROP POLICY IF EXISTS "Admin delete apks" ON storage.objects;
CREATE POLICY "Admin delete apks"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'apks' AND public.is_admin());

-- ==============================================================================
-- 7. EXEMPLE DE JEU DE DONNÉES INITIAL (Optionnel - Démo)
-- ==============================================================================
INSERT INTO public.app_releases (
    version_name,
    version_code,
    title,
    notes,
    apk_url,
    force_update,
    is_published,
    published_at
) VALUES (
    '1.1.0',
    11,
    'Lancement officiel de Ngenou avec Ngenou Assets & Mode Hors-Ligne',
    'Cette version inaugure le nouveau catalogue d’extensions Ngenou Assets, les défis quotidiens avec système de série et le tuteur IA avec dictée vocale.',
    'https://ngenou.top/Ngenou.apk',
    false,
    true,
    NOW() - INTERVAL '2 days'
) ON CONFLICT (version_code) DO NOTHING;

-- Récupérer l'id de la release insérée pour insérer ses fonctionnalités
DO $$
DECLARE
    rel_id UUID;
BEGIN
    SELECT id INTO rel_id FROM public.app_releases WHERE version_code = 11 LIMIT 1;
    IF rel_id IS NOT NULL THEN
        INSERT INTO public.release_features (release_id, title, body, sort_order)
        VALUES
        (rel_id, 'Tuteur IA conversationnel socratique', 'Posez vos questions par écrit ou par dictée vocale. Le tuteur décompose les étapes et vous aide à comprendre par vous-même.', 1),
        (rel_id, 'Mode hors-ligne intégral', 'Vos fiches de révision, vos tâches et votre planning hebdomadaire restent 100% accessibles même sans réseau.', 2),
        (rel_id, 'Ngenou Assets', 'Installez uniquement les modules complémentaires utiles à votre classe (primaire, secondaire ou supérieur).', 3),
        (rel_id, 'Emploi du temps & Rappels', 'Export PDF en 1 clic et alarmes configurables pour ne rater aucune session de travail.', 4)
        ON CONFLICT DO NOTHING;
    END IF;
END $$;
