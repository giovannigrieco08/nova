-- Migration: 035_fix_profiles_rls_auth_users
-- Purpose: Fix RLS policy that accesses auth.users causing permission denied error
-- Date: 2025-01-17
-- Issue: Migration 034 introduced a subquery to auth.users which causes
--        "permission denied for table users" error (code 42501)

-- ============================================================================
-- FIX RLS POLICY
-- ============================================================================

-- Drop the problematic policy from migration 034
DROP POLICY IF EXISTS "Students can read visible profiles" ON profiles;

-- Recreate policy WITHOUT the auth.users subquery
-- The auth.users subquery is unnecessary because:
-- 1. Profiles can only be created by authenticated users with school email
-- 2. The profiles.user_id foreign key ensures valid auth.users link
-- 3. We only need to check the requesting user's domain, not the profile owner's
CREATE POLICY "Students can read visible profiles"
ON profiles FOR SELECT
USING (
  auth.email() LIKE '%@galileimoro.edu.it'
  AND (
    -- Can always see own profile (even if deleted or hidden)
    auth.uid() = user_id
    OR (
      -- Can see others only if visible AND not deleted
      profile_visible = TRUE
      AND deleted_at IS NULL
    )
  )
);

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE 'Migration 035 complete: Fixed profiles RLS policy (removed auth.users subquery)';
END $$;
