-- =====================================================================
-- Migration: 20250207160000_allow_username_update.sql
-- Purpose: Allow users to update their username with validation
-- Date: 2025-02-07
-- =====================================================================
--
-- Changes:
-- 1. Add CHECK constraint for username format validation
-- 2. Create trigger to validate username on UPDATE
-- 3. Update RPC function to exclude current user when checking availability
-- =====================================================================

-- =====================================================================
-- STEP 1: Add CHECK constraint for username format
-- =====================================================================
-- Rules:
-- - Length: 3-30 characters
-- - Allowed chars: a-z, 0-9, ., _ (lowercase only)
-- - Cannot start/end with . or _
-- - No consecutive .. or __

-- First, normalize existing usernames to lowercase (if any uppercase exist)
UPDATE profiles
SET username = LOWER(username)
WHERE username IS NOT NULL AND username != LOWER(username);

-- Fix usernames that start or end with . or _
UPDATE profiles
SET username = REGEXP_REPLACE(
  REGEXP_REPLACE(username, '^[._]+', ''),
  '[._]+$', ''
)
WHERE username IS NOT NULL
  AND (username ~ '^[._]' OR username ~ '[._]$');

-- Fix consecutive dots or underscores
UPDATE profiles
SET username = REGEXP_REPLACE(
  REGEXP_REPLACE(username, '\.\.+', '.', 'g'),
  '__+', '_', 'g'
)
WHERE username IS NOT NULL
  AND (username ~ '\.\.' OR username ~ '__');

-- Fix usernames with invalid characters (replace with underscore, then clean)
UPDATE profiles
SET username = REGEXP_REPLACE(
  REGEXP_REPLACE(username, '[^a-z0-9._]', '_', 'g'),
  '__+', '_', 'g'
)
WHERE username IS NOT NULL
  AND username !~ '^[a-z0-9._]+$';

-- Fix usernames that are too short (pad with random suffix)
UPDATE profiles
SET username = username || FLOOR(RANDOM() * 900 + 100)::TEXT
WHERE username IS NOT NULL
  AND LENGTH(username) < 3;

-- Fix usernames that are too long (truncate)
UPDATE profiles
SET username = LEFT(username, 30)
WHERE username IS NOT NULL
  AND LENGTH(username) > 30;

-- Final cleanup: ensure no leading/trailing special chars after all fixes
UPDATE profiles
SET username = REGEXP_REPLACE(
  REGEXP_REPLACE(username, '^[._]+', ''),
  '[._]+$', ''
)
WHERE username IS NOT NULL
  AND (username ~ '^[._]' OR username ~ '[._]$');

-- Add constraint (will fail if existing data violates it)
ALTER TABLE profiles
DROP CONSTRAINT IF EXISTS username_format_check;

ALTER TABLE profiles
ADD CONSTRAINT username_format_check CHECK (
  username IS NULL OR (
    -- Length check
    LENGTH(username) >= 3 AND
    LENGTH(username) <= 30 AND
    -- Only lowercase, numbers, dots, underscores
    username ~ '^[a-z0-9._]+$' AND
    -- Cannot start with . or _
    username !~ '^[._]' AND
    -- Cannot end with . or _
    username !~ '[._]$' AND
    -- No consecutive dots or underscores
    username !~ '\.\.' AND
    username !~ '__'
  )
);

-- =====================================================================
-- STEP 2: Create trigger to validate and normalize username on UPDATE
-- =====================================================================

CREATE OR REPLACE FUNCTION validate_username_on_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- If username is being updated
  IF NEW.username IS DISTINCT FROM OLD.username THEN
    -- Normalize to lowercase
    NEW.username := LOWER(NEW.username);

    -- Check uniqueness (case-insensitive, excluding current user)
    IF EXISTS (
      SELECT 1 FROM profiles
      WHERE LOWER(username) = LOWER(NEW.username)
      AND user_id != NEW.user_id
    ) THEN
      RAISE EXCEPTION 'Username "%" is already taken', NEW.username;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Drop existing trigger if any
DROP TRIGGER IF EXISTS check_username_on_update ON profiles;

-- Create trigger
CREATE TRIGGER check_username_on_update
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  WHEN (OLD.username IS DISTINCT FROM NEW.username)
  EXECUTE FUNCTION validate_username_on_update();

-- =====================================================================
-- STEP 3: Update RPC function to support current user exclusion
-- =====================================================================

-- Drop and recreate function with optional user_id parameter
DROP FUNCTION IF EXISTS check_username_available(TEXT);

CREATE OR REPLACE FUNCTION check_username_available(
  p_username TEXT,
  p_exclude_user_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
  -- Check if username already exists (case-insensitive)
  -- Optionally exclude a specific user (for updates)
  IF p_exclude_user_id IS NULL THEN
    RETURN NOT EXISTS (
      SELECT 1 FROM profiles WHERE LOWER(username) = LOWER(p_username)
    );
  ELSE
    RETURN NOT EXISTS (
      SELECT 1 FROM profiles
      WHERE LOWER(username) = LOWER(p_username)
      AND user_id != p_exclude_user_id
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION check_username_available(TEXT, UUID) TO authenticated;

-- Add comment
COMMENT ON FUNCTION check_username_available(TEXT, UUID) IS
  'Checks if a username is available. Optional p_exclude_user_id to exclude current user when updating.';

-- =====================================================================
-- VERIFICATION
-- =====================================================================

DO $$
BEGIN
  RAISE NOTICE '=== Username Update Feature Enabled ===';
  RAISE NOTICE '1. Added CHECK constraint for username format';
  RAISE NOTICE '2. Added trigger to validate and normalize on UPDATE';
  RAISE NOTICE '3. Updated RPC function to support user exclusion';
  RAISE NOTICE '';
  RAISE NOTICE 'Username rules:';
  RAISE NOTICE '  - 3-30 characters';
  RAISE NOTICE '  - Lowercase letters, numbers, dots, underscores only';
  RAISE NOTICE '  - Cannot start/end with . or _';
  RAISE NOTICE '  - No consecutive .. or __';
END $$;
