-- =====================================================================
-- Migration: 009_add_email_to_profiles.sql
-- Feature: Fix missing email column and auto-generate username from email
-- Date: 2025-11-30
-- Description:
--   1. Adds email column to profiles table
--   2. Creates trigger to sync email from auth.users on INSERT
--   3. Creates trigger to generate username from email (giovanni.grieco22)
-- =====================================================================

-- PART 1: Add email column
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS email TEXT;

-- PART 2: Populate email from auth.users for existing profiles
UPDATE profiles p
SET email = u.email
FROM auth.users u
WHERE p.user_id = u.id
  AND p.email IS NULL;

-- PART 3: Create trigger to sync email from auth.users
CREATE OR REPLACE FUNCTION sync_email_from_auth()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Always sync email from auth.users (overwrite any client-provided value)
  SELECT email INTO NEW.email
  FROM auth.users
  WHERE id = NEW.user_id;

  RETURN NEW;
END;
$$;

-- Drop old trigger if exists, create new one
DROP TRIGGER IF EXISTS trigger_sync_email ON profiles;
CREATE TRIGGER trigger_sync_email
  BEFORE INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION sync_email_from_auth();

-- PART 4: Create/replace username generation trigger
-- Generates username from email, keeping dots (giovanni.grieco22)
CREATE OR REPLACE FUNCTION set_username_on_signup()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  base_username TEXT;
  final_username TEXT;
  counter INT := 2;
BEGIN
  -- Generate username from email if not already set
  IF NEW.username IS NULL AND NEW.email IS NOT NULL THEN
    -- Extract part before @ and lowercase it
    base_username := LOWER(SPLIT_PART(NEW.email, '@', 1));

    -- Remove accents (Italian: è→e, à→a, ì→i, ò→o, ù→u)
    base_username := TRANSLATE(
      base_username,
      'èéêëàáâäìíîïòóôöùúûü',
      'eeeeaaaaiiiioooouuuu'
    );

    final_username := base_username;

    -- Handle collision by appending number
    WHILE EXISTS (SELECT 1 FROM profiles WHERE username = final_username) LOOP
      final_username := base_username || counter::TEXT;
      counter := counter + 1;
    END LOOP;

    NEW.username := final_username;
  END IF;

  RETURN NEW;
END;
$$;

-- Drop old trigger if exists, create new one
DROP TRIGGER IF EXISTS trigger_set_username ON profiles;
CREATE TRIGGER trigger_set_username
  BEFORE INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION set_username_on_signup();

-- PART 5: Create index on email
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);

-- PART 6: Update existing profiles that don't have username
UPDATE profiles p
SET username = LOWER(SPLIT_PART(p.email, '@', 1))
WHERE p.username IS NULL AND p.email IS NOT NULL;

-- =====================================================================
-- MIGRATION COMPLETE
-- =====================================================================
-- After running this migration:
-- - New profiles will auto-get email from auth.users
-- - Username will be auto-generated as: giovanni.grieco22 (keeping dots)
-- - Existing profiles without username will get one generated
-- =====================================================================
