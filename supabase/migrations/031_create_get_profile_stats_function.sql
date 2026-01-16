-- =====================================================================
-- Migration: 031_create_get_profile_stats_function.sql
-- Feature: 006-user-profile (Profile Statistics)
-- Date: 2025-01-16
-- Purpose: Create RPC function to get profile statistics (events created, participations)
-- =====================================================================

-- This function returns the count of events created and participations for a user.
-- Used by the profile screen to display user activity statistics.
--
-- Parameters:
--   p_user_id: UUID of the user to get stats for
--
-- Returns:
--   events_created_count: Number of approved events created by the user
--   participations_count: Number of events the user is participating in

-- Drop existing function if it exists (handles parameter name change)
DROP FUNCTION IF EXISTS get_profile_stats(UUID);

CREATE OR REPLACE FUNCTION get_profile_stats(p_user_id UUID)
RETURNS TABLE(events_created_count INTEGER, participations_count INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(
      (SELECT COUNT(*)::INTEGER
       FROM events
       WHERE creator_id = p_user_id
         AND status = 'approved'),
      0
    ) AS events_created_count,
    COALESCE(
      (SELECT COUNT(*)::INTEGER
       FROM participations
       WHERE participations.user_id = p_user_id),
      0
    ) AS participations_count;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_profile_stats(UUID) TO authenticated;

-- =====================================================================
-- END OF MIGRATION
-- =====================================================================
