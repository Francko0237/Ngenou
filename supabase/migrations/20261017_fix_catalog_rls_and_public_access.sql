-- ==============================================================================
-- MIGRATION NGENOU : PERMETTRE L'ACCÈS PUBLIC AU CATALOGUE DES COURS (ANON & AUTH)
-- Date: 2026-10-17
-- ==============================================================================

-- 1. Permettre à TOUT LE MONDE (utilisateurs connectés ET anonymes) de lire les cours publiés
DROP POLICY IF EXISTS "Tout le monde peut voir les cours publiés" ON public.teacher_courses;

CREATE POLICY "Tout le monde peut voir les cours publiés"
    ON public.teacher_courses FOR SELECT
    TO anon, authenticated
    USING (is_published = true OR (auth.uid() IS NOT NULL AND auth.uid() = teacher_id));

-- 2. Permettre à tout le monde d'incrémenter le compteur de téléchargements
GRANT EXECUTE ON FUNCTION public.increment_course_downloads(UUID) TO anon, authenticated;
