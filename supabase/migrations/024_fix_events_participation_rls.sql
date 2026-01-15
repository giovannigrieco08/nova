-- =====================================================================
-- Migration: 024_fix_events_participation_rls.sql
-- Purpose: Allow users to view events they are participating in
-- Date: 2025-12-06
-- Issue: Users can't see their participated events because RLS only
--        allows viewing upcoming approved events (event_date >= CURRENT_DATE)
-- =====================================================================

-- Add policy to allow users to view events they are participating in
-- This allows seeing both upcoming and past events the user has RSVP'd to
DROP POLICY IF EXISTS "users_view_participating_events" ON events;
CREATE POLICY "users_view_participating_events"
  ON events
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM participations
      WHERE participations.event_id = events.id
        AND participations.user_id = (SELECT auth.uid())
    )
    AND status = 'approved'
  );

-- Also add policy to allow users to view events they created (regardless of date)
-- This fixes the profile "Eventi" tab for past events
DROP POLICY IF EXISTS "users_view_own_events" ON events;
CREATE POLICY "users_view_own_events"
  ON events
  FOR SELECT
  TO authenticated
  USING (creator_id = (SELECT auth.uid()));

-- =====================================================================
-- END OF MIGRATION
-- =====================================================================
