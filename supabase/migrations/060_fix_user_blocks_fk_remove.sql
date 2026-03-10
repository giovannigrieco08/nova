-- Migration: 060_fix_user_blocks_fk_remove
-- Purpose: Remove problematic FK constraints from user_blocks to profiles
-- Date: 2026-03-11
-- Issue: FK constraint fails when user doesn't have a profile record
--
-- The FK was added in 059 to enable PostgREST joins, but it causes
-- INSERT failures when blocker_id doesn't exist in profiles table.
--
-- Solution: Remove FK constraints and use explicit join in queries instead

-- ============================================================================
-- REMOVE FK CONSTRAINTS
-- ============================================================================

ALTER TABLE user_blocks
DROP CONSTRAINT IF EXISTS user_blocks_blocked_id_profiles_fkey;

ALTER TABLE user_blocks
DROP CONSTRAINT IF EXISTS user_blocks_blocker_id_profiles_fkey;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '=====================================================';
  RAISE NOTICE 'Migration 060_fix_user_blocks_fk_remove completed';
  RAISE NOTICE '  - Removed FK: user_blocks.blocked_id -> profiles.user_id';
  RAISE NOTICE '  - Removed FK: user_blocks.blocker_id -> profiles.user_id';
  RAISE NOTICE '  - Original FK to auth.users remains intact';
  RAISE NOTICE '=====================================================';
END $$;
