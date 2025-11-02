-- Migration: 003_fix_profiles_rls_policy
-- Feature: Profile Setup (002-profile-setup)
-- Date: 2025-11-02
-- Purpose: Fix RLS policy that accesses auth.users causing permission denied error

-- ============================================================================
-- FIX RLS POLICY
-- ============================================================================

-- Drop the problematic policy that accesses auth.users
DROP POLICY IF EXISTS "Students can read verified profiles" ON profiles;

-- Recreate policy WITHOUT the auth.users subquery
-- Simplified: If you're an authenticated @galileimoro.edu.it student, you can read all profiles
CREATE POLICY "Students can read verified profiles"
ON profiles FOR SELECT
USING (
  auth.email() LIKE '%@galileimoro.edu.it'
);

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

-- Verify policy was recreated
SELECT 'Migration 003 complete: Fixed profiles RLS policy'
WHERE EXISTS (
  SELECT 1 FROM pg_policies
  WHERE tablename = 'profiles'
  AND policyname = 'Students can read verified profiles'
);
