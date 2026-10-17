-- ==============================================================================
-- MIGRATION : Fusionner collège + lycée → secondaire
-- Date: 2026-10-17
-- ==============================================================================

-- 1. Mettre à jour les données existantes
UPDATE public.profiles SET school_level = 'secondaire' WHERE school_level IN ('college', 'lycee');
UPDATE public.teacher_courses SET school_level = 'secondaire' WHERE school_level IN ('college', 'lycee');

-- 2. Supprimer les anciennes contraintes CHECK et les remplacer
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_school_level_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_school_level_check
    CHECK (school_level IN ('primaire', 'secondaire', 'superieur'));

ALTER TABLE public.teacher_courses DROP CONSTRAINT IF EXISTS teacher_courses_school_level_check;
ALTER TABLE public.teacher_courses ADD CONSTRAINT teacher_courses_school_level_check
    CHECK (school_level IN ('primaire', 'secondaire', 'superieur'));
