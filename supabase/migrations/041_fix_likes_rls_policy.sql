-- Migration: 041_fix_likes_rls_policy
-- Description: Fix RLS policy for likes table to allow other users to like events
--
-- Problem: The existing policy uses an EXISTS subquery that is subject to RLS
-- on the events table. When User B tries to like User A's event, the subquery
-- runs with User B's permissions, which may not allow viewing the event due to
-- date/participation restrictions, causing the like to fail.
--
-- Fix: Create a SECURITY DEFINER function to check if an event is likeable,
-- bypassing RLS restrictions on the events table.

-- ============================================================================
-- CREATE HELPER FUNCTION WITH SECURITY DEFINER
-- ============================================================================

-- Function to check if an event can be liked (bypasses RLS)
-- An event is likeable if it exists and has status 'approved'
CREATE OR REPLACE FUNCTION is_event_likeable(event_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM events
    WHERE id = event_uuid
      AND status = 'approved'
  );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION is_event_likeable(UUID) TO authenticated;

-- ============================================================================
-- DROP EXISTING POLICY AND CREATE FIXED VERSION
-- ============================================================================

-- Drop the existing policy
DROP POLICY IF EXISTS "users_like_approved_events" ON likes;

-- Create new policy using the SECURITY DEFINER function
-- This allows users to like any approved event, regardless of whether
-- they can see it through RLS (e.g., past events they had open)
CREATE POLICY "users_like_approved_events"
  ON likes
  FOR INSERT
  TO authenticated
  WITH CHECK (
    is_event_likeable(event_id)
    AND user_id = (SELECT auth.uid())
  );

-- ============================================================================
-- ALSO FIX PARTICIPATIONS POLICY (same issue)
-- ============================================================================

-- Create helper function for participations
CREATE OR REPLACE FUNCTION is_event_participable(event_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM events
    WHERE id = event_uuid
      AND status = 'approved'
  );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION is_event_participable(UUID) TO authenticated;

-- Drop and recreate participations policy
DROP POLICY IF EXISTS "users_participate_approved_events" ON participations;

CREATE POLICY "users_participate_approved_events"
  ON participations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    is_event_participable(event_id)
    AND user_id = (SELECT auth.uid())
  );

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
BEGIN
  -- Verify function exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc
    WHERE proname = 'is_event_likeable'
  ) THEN
    RAISE EXCEPTION 'Migration failed: is_event_likeable function not created';
  END IF;

  -- Verify policy exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'likes'
      AND schemaname = 'public'
      AND policyname = 'users_like_approved_events'
  ) THEN
    RAISE EXCEPTION 'Migration failed: Likes RLS policy not created';
  END IF;

  RAISE NOTICE 'Migration 041_fix_likes_rls_policy completed successfully';
  RAISE NOTICE '   - Created is_event_likeable() function with SECURITY DEFINER';
  RAISE NOTICE '   - Created is_event_participable() function with SECURITY DEFINER';
  RAISE NOTICE '   - Updated likes INSERT policy to use helper function';
  RAISE NOTICE '   - Updated participations INSERT policy to use helper function';
END $$;
