-- =====================================================================
-- Migration: 056_relax_username_format_constraint.sql
-- Purpose: Relax username format rules - allow . and _ at start/end and consecutive
-- Date: 2025-02-10
-- =====================================================================
--
-- Changes:
-- - Removes restriction on starting/ending with . or _
-- - Removes restriction on consecutive .. or __
-- - Keeps: 3-30 chars, lowercase letters/numbers/dots/underscores only
-- =====================================================================

-- Drop old constraint
ALTER TABLE profiles
DROP CONSTRAINT IF EXISTS username_format_check;

-- Add new relaxed constraint
-- Rules:
-- - Length: 3-30 characters
-- - Allowed chars: a-z, 0-9, ., _ (lowercase only)
-- (Removed: start/end restrictions, consecutive restrictions)
ALTER TABLE profiles
ADD CONSTRAINT username_format_check CHECK (
  username IS NULL OR (
    -- Length check
    LENGTH(username) >= 3 AND
    LENGTH(username) <= 30 AND
    -- Only lowercase, numbers, dots, underscores
    username ~ '^[a-z0-9._]+$'
  )
);

-- Update the validation trigger to reflect relaxed rules
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

-- =====================================================================
-- VERIFICATION
-- =====================================================================

DO $$
BEGIN
  RAISE NOTICE '=====================================================';
  RAISE NOTICE 'Migration 056 completed successfully';
  RAISE NOTICE '  - Username format constraint relaxed';
  RAISE NOTICE '  - Now allows . and _ at start/end';
  RAISE NOTICE '  - Now allows consecutive .. and __';
  RAISE NOTICE '  - Still requires: 3-30 chars, lowercase/numbers/dots/underscores';
  RAISE NOTICE '=====================================================';
END $$;
