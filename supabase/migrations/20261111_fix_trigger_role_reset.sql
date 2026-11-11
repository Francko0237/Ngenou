-- ==============================================================================
-- CORRECTIF CRITIQUE : Trigger handle_new_user écrasait le rôle admin
-- ==============================================================================
-- BUG: ON CONFLICT DO UPDATE avait:
--   role = COALESCE(EXCLUDED.role, public.profiles.role)
-- COALESCE(NEW.raw_user_meta_data->>'role', 'student') = toujours 'student' si pas défini
-- donc COALESCE('student', 'admin') = 'student' → rôle admin écrasé à chaque auth event
--
-- FIX: Ne mettre à jour le rôle que si raw_user_meta_data contient EXPLICITEMENT 'role'
-- ==============================================================================

-- Étape 1 : Remplacer la fonction trigger
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
        username     = COALESCE(EXCLUDED.username, public.profiles.username),
        -- ✅ CORRECTIF : préserve le rôle existant si non fourni dans les metadata
        role         = CASE
                           WHEN NEW.raw_user_meta_data->>'role' IS NOT NULL
                           THEN NEW.raw_user_meta_data->>'role'
                           ELSE public.profiles.role
                       END,
        school_level = COALESCE(EXCLUDED.school_level, public.profiles.school_level),
        phone        = COALESCE(EXCLUDED.phone, public.profiles.phone),
        updated_at   = timezone('utc'::text, now());

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Étape 2 : Recréer le trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT OR UPDATE ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- Étape 3 : Fonction RPC sécurisée pour promouvoir un admin depuis le SQL Editor
-- (bypasse la RLS, ne peut être appelé que par un admin Supabase)
CREATE OR REPLACE FUNCTION public.set_user_admin(target_user_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE public.profiles SET role = 'admin' WHERE id = target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
