-- ==============================================================================
-- MIGRATION NGENOU : AJOUT CLASSE ET PHOTO DE COUVERTURE POUR LES COURS
-- Date: 2026-10-17
-- ==============================================================================

ALTER TABLE public.teacher_courses 
ADD COLUMN IF NOT EXISTS classe TEXT;

ALTER TABLE public.teacher_courses 
ADD COLUMN IF NOT EXISTS cover_image_url TEXT;
