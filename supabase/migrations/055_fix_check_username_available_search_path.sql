-- =====================================================================
-- Migration: 055_fix_check_username_available_search_path.sql
-- Purpose: Fix search_path security warning for check_username_available
-- Date: 2025-02-07
-- =====================================================================
--
-- Problem: The function check_username_available is SECURITY DEFINER but
-- doesn't have search_path set, which is a security concern.
--
-- Fix: Recreate the function with SET search_path = public
-- =====================================================================

-- Recreate function with search_path set
CREATE OR REPLACE FUNCTION check_username_available(p_username TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if username already exists (case-insensitive)
  RETURN NOT EXISTS (
    SELECT 1 FROM profiles WHERE LOWER(username) = LOWER(p_username)
  );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION check_username_available(TEXT) TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION check_username_available(TEXT) IS
  'Checks if a username is available for registration (case-insensitive check)';

-- =====================================================================
-- VERIFICATION
-- =====================================================================

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname = 'check_username_available'
      AND p.proconfig IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM unnest(p.proconfig) AS config
        WHERE config LIKE 'search_path=%'
      )
  ) THEN
    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'Migration 055 completed successfully';
    RAISE NOTICE '  - check_username_available now has search_path set';
    RAISE NOTICE '=====================================================';
  ELSE
    RAISE EXCEPTION 'Migration failed: search_path not set on function';
  END IF;
END $$;
