-- Migration: 034_add_profile_gdpr_columns
-- Purpose: Add GDPR compliance columns (profile_visible, deleted_at) to profiles table
-- Date: 2025-01-17
-- Feature: Profile soft delete (GDPR Article 17 - Right to Erasure)

-- ============================================================================
-- ADD COLUMNS
-- ============================================================================

-- Add profile_visible column (GDPR privacy control)
-- Default TRUE: profiles are visible unless user explicitly hides
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS profile_visible BOOLEAN NOT NULL DEFAULT TRUE;

-- Add deleted_at column (soft delete for GDPR)
-- NULL = active profile, timestamp = soft-deleted (30-day grace period)
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ NULL;

-- Add username column if not exists (might be missing in some schemas)
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS username TEXT;

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Index for finding soft-deleted profiles (for cleanup job)
CREATE INDEX IF NOT EXISTS idx_profiles_deleted_at
  ON profiles(deleted_at)
  WHERE deleted_at IS NOT NULL;

-- Index for profile visibility filtering
CREATE INDEX IF NOT EXISTS idx_profiles_visible
  ON profiles(profile_visible)
  WHERE profile_visible = TRUE;

-- Unique index on username (case-insensitive)
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_username_unique
  ON profiles(LOWER(username))
  WHERE username IS NOT NULL;

-- ============================================================================
-- RLS POLICY UPDATES
-- ============================================================================

-- Drop existing policies that need updating
DROP POLICY IF EXISTS "Students can read verified profiles" ON profiles;

-- Updated policy: Students can only see non-deleted, visible profiles
CREATE POLICY "Students can read visible profiles"
ON profiles FOR SELECT
USING (
  auth.email() LIKE '%@galileimoro.edu.it'
  AND (
    -- Can always see own profile
    auth.uid() = user_id
    OR (
      -- Can see others only if visible AND not deleted
      profile_visible = TRUE
      AND deleted_at IS NULL
      AND EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id = profiles.user_id
        AND auth.users.email LIKE '%@galileimoro.edu.it'
      )
    )
  )
);

-- ============================================================================
-- SOFT DELETE HELPER FUNCTIONS
-- ============================================================================

-- Function to soft delete a profile
CREATE OR REPLACE FUNCTION soft_delete_profile(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Verify the requesting user is the profile owner
  IF auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'You can only delete your own profile';
  END IF;

  -- Set deleted_at timestamp
  UPDATE profiles
  SET deleted_at = NOW()
  WHERE user_id = p_user_id
    AND deleted_at IS NULL;  -- Don't update if already deleted
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION soft_delete_profile(UUID) TO authenticated;

-- Function to cancel profile deletion (within 30-day grace period)
CREATE OR REPLACE FUNCTION cancel_profile_deletion(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Verify the requesting user is the profile owner
  IF auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'You can only restore your own profile';
  END IF;

  -- Check if still within grace period (30 days)
  IF EXISTS (
    SELECT 1 FROM profiles
    WHERE user_id = p_user_id
      AND deleted_at IS NOT NULL
      AND deleted_at > NOW() - INTERVAL '30 days'
  ) THEN
    -- Clear deleted_at to restore profile
    UPDATE profiles
    SET deleted_at = NULL
    WHERE user_id = p_user_id;
  ELSE
    RAISE EXCEPTION 'Profile cannot be restored (grace period expired or not deleted)';
  END IF;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION cancel_profile_deletion(UUID) TO authenticated;

-- Function to check if profile is scheduled for deletion
CREATE OR REPLACE FUNCTION is_profile_deleted(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  deletion_date TIMESTAMPTZ;
BEGIN
  SELECT deleted_at INTO deletion_date
  FROM profiles
  WHERE user_id = p_user_id;

  RETURN deletion_date IS NOT NULL;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION is_profile_deleted(UUID) TO authenticated;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON COLUMN profiles.profile_visible IS 'Privacy toggle: if FALSE, profile is hidden from other users';
COMMENT ON COLUMN profiles.deleted_at IS 'Soft delete timestamp. NULL = active, timestamp = pending permanent deletion (30-day grace period)';
COMMENT ON FUNCTION soft_delete_profile(UUID) IS 'GDPR Article 17: Soft delete user profile with 30-day grace period';
COMMENT ON FUNCTION cancel_profile_deletion(UUID) IS 'Cancel pending profile deletion within 30-day grace period';
COMMENT ON FUNCTION is_profile_deleted(UUID) IS 'Check if profile is scheduled for deletion';

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE 'Migration 034 complete: Added profile_visible, deleted_at columns and GDPR helper functions';
END $$;
