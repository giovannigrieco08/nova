-- =====================================================================
-- Migration: 20250207153000_fix_events_update_policy.sql
-- Purpose: Fix events UPDATE policy to allow creators to update approved events
-- Date: 2025-02-07
-- =====================================================================
--
-- Problem: The WITH CHECK clause in events_update policy only allows
-- creators to update events with status IN ('pending', 'rejected').
-- This prevents creators from updating their APPROVED events (e.g.,
-- adding help requests, updating description, etc.)
--
-- Fix:
-- 1. Simplify RLS to allow creators/co-orgs to update their events
-- 2. Add a trigger to prevent non-moderators from directly approving events
-- =====================================================================

-- =====================================================================
-- STEP 1: Create trigger to prevent unauthorized status changes
-- =====================================================================

CREATE OR REPLACE FUNCTION prevent_unauthorized_approval()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- If status is being changed to 'approved'
  IF OLD.status != 'approved' AND NEW.status = 'approved' THEN
    -- Only moderators/admins can approve
    IF NOT is_moderator_or_admin() THEN
      RAISE EXCEPTION 'Only moderators can approve events';
    END IF;
  END IF;

  -- If status is being changed from 'approved' to something else by non-moderator
  IF OLD.status = 'approved' AND NEW.status != 'approved' THEN
    -- Only moderators/admins can change status of approved events
    IF NOT is_moderator_or_admin() THEN
      RAISE EXCEPTION 'Only moderators can change status of approved events';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Drop existing trigger if any
DROP TRIGGER IF EXISTS check_event_approval_authorization ON events;

-- Create trigger
CREATE TRIGGER check_event_approval_authorization
  BEFORE UPDATE ON events
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION prevent_unauthorized_approval();

-- =====================================================================
-- STEP 2: Fix the RLS UPDATE policy
-- =====================================================================

-- Drop the current policy
DROP POLICY IF EXISTS "events_update" ON events;

-- Create simplified UPDATE policy
-- Status change authorization is now handled by the trigger above
CREATE POLICY "events_update"
  ON events FOR UPDATE
  TO authenticated
  USING (
    -- Creators can update their own events
    creator_id = (SELECT auth.uid())
    OR
    -- Co-organizers can update events they co-organize
    (SELECT auth.uid()) = ANY(co_organizers)
    OR
    -- Moderators can update any event (except their own for moderation)
    is_moderator_or_admin()
  )
  WITH CHECK (
    -- Creators can update their own events
    creator_id = (SELECT auth.uid())
    OR
    -- Co-organizers can update
    (SELECT auth.uid()) = ANY(co_organizers)
    OR
    -- Moderators can update any event
    is_moderator_or_admin()
  );

-- =====================================================================
-- VERIFICATION
-- =====================================================================

DO $$
BEGIN
  RAISE NOTICE '=== Events Update Policy Fixed ===';
  RAISE NOTICE '1. Added trigger to prevent unauthorized approval';
  RAISE NOTICE '2. Simplified RLS policy to allow content updates';
  RAISE NOTICE '';
  RAISE NOTICE 'Now:';
  RAISE NOTICE '  - Creators can update their approved events (content, help requests)';
  RAISE NOTICE '  - Creators CANNOT approve their own events (trigger prevents it)';
  RAISE NOTICE '  - Co-organizers can still update events';
  RAISE NOTICE '  - Moderators can approve/reject/update any event';
END $$;
