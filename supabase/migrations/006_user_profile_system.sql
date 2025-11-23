-- =====================================================================
-- Migration: 006_user_profile_system.sql
-- Feature: Sistema Profilo Utente (User Profile System)
-- Date: 2025-01-22
-- Description: Extends profiles table for complete user profile functionality
--              including avatar, bio, GDPR compliance, and username generation
-- =====================================================================

-- =====================================================================
-- PART 1: EXTEND PROFILES TABLE
-- =====================================================================
-- Add new columns to existing profiles table (created by Supabase Auth)

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS full_name TEXT,
  ADD COLUMN IF NOT EXISTS username TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS class TEXT CHECK (class ~ '^[1-5][A-Z]$|^[1-5][A-Z]c$' OR class = 'Altro' OR class IS NULL),
  ADD COLUMN IF NOT EXISTS bio TEXT CHECK (LENGTH(bio) <= 150),
  ADD COLUMN IF NOT EXISTS avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'moderator', 'admin')),
  ADD COLUMN IF NOT EXISTS profile_visible BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Add comment for documentation
COMMENT ON COLUMN profiles.class IS '38 classes: Scientifico A-E (1A-5A through 1E-5E), F partial (1F,3F,4F), Classico Ac-Bc (1Ac-5Ac, 1Bc-5Bc), or "Altro"';
COMMENT ON COLUMN profiles.bio IS 'User bio max 150 characters, auto-sanitized (no URLs, no HTML)';
COMMENT ON COLUMN profiles.deleted_at IS 'Soft delete timestamp. If not null, account in 30-day grace period before hard delete';

-- =====================================================================
-- PART 2: CREATE INDEXES FOR PERFORMANCE
-- =====================================================================

-- Fast username lookup (for username collision detection and @ mentions)
CREATE INDEX IF NOT EXISTS idx_profiles_username ON profiles(username);

-- Fast soft delete queries (for hard delete cron job)
CREATE INDEX IF NOT EXISTS idx_profiles_deleted_at ON profiles(deleted_at) WHERE deleted_at IS NOT NULL;

-- =====================================================================
-- PART 3: CREATE AVATARS STORAGE BUCKET
-- =====================================================================

-- Create public bucket for avatar images
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', TRUE)
ON CONFLICT (id) DO NOTHING;

-- =====================================================================
-- PART 4: USERNAME GENERATION FUNCTION
-- =====================================================================
-- Auto-generates unique username from email (nome.cognome format)
-- Handles accent removal and collision with incremental numbers

CREATE OR REPLACE FUNCTION generate_unique_username(email TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  base_username TEXT;
  final_username TEXT;
  counter INT := 2;
BEGIN
  -- Extract part before @ and sanitize
  base_username := LOWER(SPLIT_PART(email, '@', 1));

  -- Remove accents (Italian: è→e, à→a, ì→i, ò→o, ù→u)
  base_username := TRANSLATE(
    base_username,
    'èéêëàáâäìíîïòóôöùúûü',
    'eeeeaaaaiiiioooouuuu'
  );

  -- Remove non-alphanumeric except dots and hyphens
  base_username := REGEXP_REPLACE(base_username, '[^a-z0-9.-]', '', 'g');

  -- Replace multiple dots with single dot (giovanni..grieco → giovanni.grieco)
  base_username := REGEXP_REPLACE(base_username, '\.+', '.', 'g');

  -- Trim leading/trailing dots and hyphens
  base_username := TRIM(BOTH '.-' FROM base_username);

  -- Ensure minimum length of 3 characters
  IF LENGTH(base_username) < 3 THEN
    base_username := base_username || 'user';
  END IF;

  final_username := base_username;

  -- Check collision and append number if needed (marco.rossi → marco.rossi2 → marco.rossi3)
  WHILE EXISTS (SELECT 1 FROM profiles WHERE username = final_username) LOOP
    final_username := base_username || counter::TEXT;
    counter := counter + 1;
  END LOOP;

  RETURN final_username;
END;
$$;

COMMENT ON FUNCTION generate_unique_username IS 'Generates unique username from email. Format: nome.cognome. Handles accents and collisions.';

-- =====================================================================
-- PART 5: USERNAME GENERATION TRIGGER
-- =====================================================================
-- Auto-generates username on profile creation if null

CREATE OR REPLACE FUNCTION set_username_on_signup()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only generate username if it's null (first-time signup)
  IF NEW.username IS NULL THEN
    NEW.username := generate_unique_username(NEW.email);
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_set_username ON profiles;
CREATE TRIGGER trigger_set_username
  BEFORE INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION set_username_on_signup();

COMMENT ON FUNCTION set_username_on_signup IS 'Trigger function: auto-generates username on profile INSERT if null';

-- =====================================================================
-- PART 6: BIO SANITIZATION FUNCTION
-- =====================================================================
-- Removes URLs, HTML tags, and truncates to 150 characters

CREATE OR REPLACE FUNCTION sanitize_bio()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Only sanitize if bio is not null
  IF NEW.bio IS NOT NULL THEN
    -- Remove URLs (http/https/www)
    NEW.bio := REGEXP_REPLACE(NEW.bio, 'https?://\S+', '', 'g');
    NEW.bio := REGEXP_REPLACE(NEW.bio, 'www\.\S+', '', 'g');

    -- Remove HTML tags (XSS prevention)
    NEW.bio := REGEXP_REPLACE(NEW.bio, '<[^>]*>', '', 'g');

    -- Truncate to 150 characters
    IF LENGTH(NEW.bio) > 150 THEN
      NEW.bio := SUBSTRING(NEW.bio, 1, 150);
    END IF;

    -- Trim whitespace
    NEW.bio := TRIM(NEW.bio);
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_sanitize_bio ON profiles;
CREATE TRIGGER trigger_sanitize_bio
  BEFORE INSERT OR UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION sanitize_bio();

COMMENT ON FUNCTION sanitize_bio IS 'Trigger function: sanitizes bio field (removes URLs, HTML, truncates to 150 chars)';

-- =====================================================================
-- PART 7: PROFILE STATS FUNCTION
-- =====================================================================
-- Returns computed stats: events_created_count, participations_count

CREATE OR REPLACE FUNCTION get_profile_stats(user_id UUID)
RETURNS TABLE(
  events_created_count INTEGER,
  participations_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE((
      SELECT COUNT(*)::INTEGER
      FROM events
      WHERE creator_id = user_id AND status = 'approved'
    ), 0) AS events_created_count,

    COALESCE((
      SELECT COUNT(*)::INTEGER
      FROM participations
      WHERE participations.user_id = get_profile_stats.user_id
    ), 0) AS participations_count;
END;
$$;

COMMENT ON FUNCTION get_profile_stats IS 'Returns profile statistics: approved events created and total participations';

-- =====================================================================
-- PART 8: RLS POLICIES FOR PROFILES TABLE
-- =====================================================================
-- Row-Level Security policies for profile visibility and editing

-- Enable RLS (should already be enabled, but ensure it)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- =====================
-- SELECT Policies
-- =====================

-- Policy: Public profiles are viewable by everyone
-- Condition: profile_visible = TRUE AND deleted_at IS NULL
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;
CREATE POLICY "Public profiles are viewable by everyone"
  ON profiles
  FOR SELECT
  USING (profile_visible = TRUE AND deleted_at IS NULL);

-- Policy: Users can always view their own profile (even if hidden or soft-deleted)
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
CREATE POLICY "Users can view own profile"
  ON profiles
  FOR SELECT
  USING (auth.uid() = user_id);

-- =====================
-- UPDATE Policies
-- =====================

-- Policy: Users can only update their own profile
-- Restriction: Cannot modify username, email, or role (read-only fields)
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile"
  ON profiles
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Note: Username, email, role are protected by application logic (not exposed in edit UI)
-- Bio, full_name, class, avatar_url, profile_visible are editable fields

-- Policy: Users can soft-delete their own account (set deleted_at)
DROP POLICY IF EXISTS "Users can soft delete own account" ON profiles;
CREATE POLICY "Users can soft delete own account"
  ON profiles
  FOR UPDATE
  USING (auth.uid() = user_id AND deleted_at IS NULL)
  WITH CHECK (auth.uid() = user_id);

-- =====================================================================
-- PART 9: RLS POLICIES FOR STORAGE (AVATARS BUCKET)
-- =====================================================================
-- Storage bucket RLS for avatar upload, download, delete

-- =====================
-- INSERT Policy
-- =====================

-- Policy: Users can upload avatar to their own folder only
DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
CREATE POLICY "Users can upload own avatar"
  ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars' AND
    (storage.foldername(name))[1] = auth.uid()::TEXT
  );

-- =====================
-- UPDATE Policy
-- =====================

-- Policy: Users can update (overwrite) their own avatar
DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
CREATE POLICY "Users can update own avatar"
  ON storage.objects
  FOR UPDATE
  USING (
    bucket_id = 'avatars' AND
    (storage.foldername(name))[1] = auth.uid()::TEXT
  );

-- =====================
-- SELECT Policy
-- =====================

-- Policy: Avatars are publicly readable (for profile display and caching)
DROP POLICY IF EXISTS "Avatars are publicly accessible" ON storage.objects;
CREATE POLICY "Avatars are publicly accessible"
  ON storage.objects
  FOR SELECT
  USING (bucket_id = 'avatars');

-- =====================
-- DELETE Policy
-- =====================

-- Policy: Users can delete their own avatar
DROP POLICY IF EXISTS "Users can delete own avatar" ON storage.objects;
CREATE POLICY "Users can delete own avatar"
  ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'avatars' AND
    (storage.foldername(name))[1] = auth.uid()::TEXT
  );

-- =====================================================================
-- PART 10: MODERATOR STATS FUNCTION (User Story 5 - T086)
-- =====================================================================
-- Returns moderator statistics for Settings screen

CREATE OR REPLACE FUNCTION get_moderator_stats(moderator_user_id UUID)
RETURNS TABLE(
  reviews_count INTEGER,
  approval_rate INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  total_reviews INT;
  approved_reviews INT;
  rate INT;
BEGIN
  -- Count total reviews by this moderator
  -- (Assumes events table has reviewed_by and reviewed_at columns)
  SELECT COUNT(*)::INTEGER INTO total_reviews
  FROM events
  WHERE reviewed_by = moderator_user_id
    AND reviewed_at IS NOT NULL;

  -- Count approved reviews (status = 'approved')
  SELECT COUNT(*)::INTEGER INTO approved_reviews
  FROM events
  WHERE reviewed_by = moderator_user_id
    AND status = 'approved'
    AND reviewed_at IS NOT NULL;

  -- Calculate approval rate (0-100%)
  IF total_reviews > 0 THEN
    rate := ROUND((approved_reviews::DECIMAL / total_reviews::DECIMAL) * 100)::INTEGER;
  ELSE
    rate := 0;
  END IF;

  RETURN QUERY SELECT total_reviews, rate;
END;
$$;

COMMENT ON FUNCTION get_moderator_stats IS 'Returns moderator statistics: total reviews and approval rate for Settings screen (T086)';

-- =====================================================================
-- PART 11: HARD DELETE CRON JOB (GDPR Compliance)
-- =====================================================================
-- Auto-deletes accounts after 30-day grace period (GDPR Article 17)

-- Enable pg_cron extension (requires superuser privileges)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule hard delete job (runs daily at 3 AM UTC)
SELECT cron.schedule(
  'hard-delete-expired-accounts', -- Job name
  '0 3 * * *',                     -- Cron schedule (3 AM UTC daily)
  $$
  -- Hard delete profiles where deleted_at > 30 days ago
  DELETE FROM profiles
  WHERE deleted_at IS NOT NULL
    AND deleted_at < NOW() - INTERVAL '30 days';
  $$
);

COMMENT ON EXTENSION pg_cron IS 'GDPR compliance: Hard-deletes accounts after 30-day grace period (T069)';

-- NOTE: Avatar cleanup is handled by Supabase Storage lifecycle policies
-- Set bucket lifecycle rule: delete files in avatars/{user_id}/ when profile deleted
-- (Manual setup via Supabase Dashboard → Storage → avatars bucket → Lifecycle)

-- =====================================================================
-- MIGRATION COMPLETE
-- =====================================================================
-- Next steps:
-- 1. Apply migration: psql -h <host> -U postgres -d postgres -f 006_user_profile_system.sql
-- 2. Verify: SELECT * FROM profiles LIMIT 1; (check new columns)
-- 3. Test username generation: SELECT generate_unique_username('marco.rossi@galileimoro.edu.it');
-- 4. Test bio sanitization: INSERT INTO profiles (email, bio) VALUES ('test@galileimoro.edu.it', '<script>alert("xss")</script>Hello!');
-- 5. Test RLS policies: Set auth.uid() and query profiles table
-- 6. Verify cron job: SELECT * FROM cron.job WHERE jobname = 'hard-delete-expired-accounts';
-- =====================================================================
