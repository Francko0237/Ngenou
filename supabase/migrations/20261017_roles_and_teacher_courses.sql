-- ==============================================================================
-- MIGRATION NGENOU : GESTION DES RÔLES & COURS ENSEIGNANTS
-- Date: 2026-10-17
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. TABLE DES PROFILS UTILISATEURS (avec rôles et niveaux)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT,
    role TEXT NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'teacher', 'admin')),
    school_level TEXT CHECK (school_level IN ('primaire', 'college', 'lycee', 'superieur')),
    phone TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Index pour optimiser les requêtes
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_school_level ON public.profiles(school_level);

-- 3. TRIGGER : CRÉATION AUTOMATIQUE DU PROFIL LORS DE L'INSCRIPTION
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (
        id,
        username,
        role,
        school_level,
        phone,
        avatar_url
    ) VALUES (
        NEW.id,
        COALESCE(
            NEW.raw_user_meta_data->>'username',
            NEW.raw_user_meta_data->>'full_name',
            NEW.raw_user_meta_data->>'name',
            'Ami'
        ),
        COALESCE(NEW.raw_user_meta_data->>'role', 'student'),
        NEW.raw_user_meta_data->>'school_level',
        NEW.raw_user_meta_data->>'phone',
        NEW.raw_user_meta_data->>'avatar_url'
    )
    ON CONFLICT (id) DO UPDATE SET
        username = EXCLUDED.username,
        role = COALESCE(EXCLUDED.role, public.profiles.role),
        school_level = COALESCE(EXCLUDED.school_level, public.profiles.school_level),
        phone = COALESCE(EXCLUDED.phone, public.profiles.phone),
        updated_at = timezone('utc'::text, now());

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Déclencheur sur auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT OR UPDATE ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- Migration rétroactive des utilisateurs déjà existants
INSERT INTO public.profiles (id, username, role, phone)
SELECT 
    id,
    COALESCE(raw_user_meta_data->>'username', raw_user_meta_data->>'full_name', 'Ami'),
    COALESCE(raw_user_meta_data->>'role', 'student'),
    raw_user_meta_data->>'phone'
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- 4. TABLE DU CATALOGUE DES COURS PUBLIÉS PAR LES ENSEIGNANTS
CREATE TABLE IF NOT EXISTS public.teacher_courses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    teacher_name TEXT NOT NULL,
    matiere_id TEXT NOT NULL,
    titre TEXT NOT NULL,
    description TEXT,
    school_level TEXT NOT NULL CHECK (school_level IN ('primaire', 'college', 'lycee', 'superieur')),
    matiere_nom TEXT NOT NULL,
    icone TEXT NOT NULL DEFAULT 'book',
    couleur TEXT NOT NULL DEFAULT '#3498DB',
    duration_minutes INT NOT NULL DEFAULT 120,
    json_data JSONB NOT NULL,
    is_published BOOLEAN NOT NULL DEFAULT true,
    downloads_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Index pour recherche rapide par niveau et matière
CREATE INDEX IF NOT EXISTS idx_teacher_courses_school_level ON public.teacher_courses(school_level);
CREATE INDEX IF NOT EXISTS idx_teacher_courses_matiere_id ON public.teacher_courses(matiere_id);
CREATE INDEX IF NOT EXISTS idx_teacher_courses_teacher_id ON public.teacher_courses(teacher_id);
CREATE INDEX IF NOT EXISTS idx_teacher_courses_published ON public.teacher_courses(is_published);

-- 5. FONCTION RPC POUR INCRÉMENTER LE NOMBRE DE TÉLÉCHARGEMENTS
CREATE OR REPLACE FUNCTION public.increment_course_downloads(p_course_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE public.teacher_courses
    SET downloads_count = downloads_count + 1
    WHERE id = p_course_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. ROW LEVEL SECURITY (RLS)

-- Activer RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_courses ENABLE ROW LEVEL SECURITY;

-- Politiques pour 'profiles'
DROP POLICY IF EXISTS "Les profils sont visibles par les utilisateurs authentifiés" ON public.profiles;
CREATE POLICY "Les profils sont visibles par les utilisateurs authentifiés"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Un utilisateur peut modifier son propre profil" ON public.profiles;
CREATE POLICY "Un utilisateur peut modifier son propre profil"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Politiques pour 'teacher_courses'
DROP POLICY IF EXISTS "Tout le monde peut voir les cours publiés" ON public.teacher_courses;
CREATE POLICY "Tout le monde peut voir les cours publiés"
    ON public.teacher_courses FOR SELECT
    TO authenticated
    USING (is_published = true OR auth.uid() = teacher_id);

DROP POLICY IF EXISTS "Les enseignants peuvent insérer leurs cours" ON public.teacher_courses;
CREATE POLICY "Les enseignants peuvent insérer leurs cours"
    ON public.teacher_courses FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = teacher_id);

DROP POLICY IF EXISTS "Les enseignants peuvent modifier leurs cours" ON public.teacher_courses;
CREATE POLICY "Les enseignants peuvent modifier leurs cours"
    ON public.teacher_courses FOR UPDATE
    TO authenticated
    USING (auth.uid() = teacher_id)
    WITH CHECK (auth.uid() = teacher_id);

DROP POLICY IF EXISTS "Les enseignants peuvent supprimer leurs cours" ON public.teacher_courses;
CREATE POLICY "Les enseignants peuvent supprimer leurs cours"
    ON public.teacher_courses FOR DELETE
    TO authenticated
    USING (auth.uid() = teacher_id);
