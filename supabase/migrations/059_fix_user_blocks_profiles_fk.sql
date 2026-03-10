-- Migration: 059_fix_user_blocks_profiles_fk
-- Purpose: Add foreign key from user_blocks to profiles for PostgREST joins
-- Date: 2026-03-10
-- Issue: PGRST200 error when querying user_blocks with profiles join
--
-- Problem: user_blocks.blocked_id references auth.users(id), not profiles(user_id)
--          PostgREST cannot find relationship for "profiles!blocked_id" hint
--
-- Solution: Add explicit foreign keys from user_blocks to profiles table

-- ============================================================================
-- ADD FOREIGN KEYS TO PROFILES
-- ============================================================================

-- Add FK from blocked_id to profiles
-- Note: profiles.user_id already references auth.users(id), so this creates
-- a transitive relationship that PostgREST can follow
ALTER TABLE user_blocks
DROP CONSTRAINT IF EXISTS user_blocks_blocked_id_profiles_fkey;

ALTER TABLE user_blocks
ADD CONSTRAINT user_blocks_blocked_id_profiles_fkey
FOREIGN KEY (blocked_id) REFERENCES profiles(user_id) ON DELETE CASCADE;

-- Add FK from blocker_id to profiles (for consistency)
ALTER TABLE user_blocks
DROP CONSTRAINT IF EXISTS user_blocks_blocker_id_profiles_fkey;

ALTER TABLE user_blocks
ADD CONSTRAINT user_blocks_blocker_id_profiles_fkey
FOREIGN KEY (blocker_id) REFERENCES profiles(user_id) ON DELETE CASCADE;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
  fk_count INT;
BEGIN
  SELECT COUNT(*) INTO fk_count
  FROM information_schema.table_constraints
  WHERE table_name = 'user_blocks'
  AND constraint_type = 'FOREIGN KEY'
  AND constraint_name LIKE '%profiles%';

  RAISE NOTICE '=====================================================';
  RAISE NOTICE 'Migration 059_fix_user_blocks_profiles_fk completed';
  RAISE NOTICE '  - Added FK: user_blocks.blocked_id -> profiles.user_id';
  RAISE NOTICE '  - Added FK: user_blocks.blocker_id -> profiles.user_id';
  RAISE NOTICE '  - FK constraints to profiles: %', fk_count;
  RAISE NOTICE '=====================================================';
END $$;
