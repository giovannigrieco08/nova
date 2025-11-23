-- =====================================================================
-- RLS Policy Updates for Events Table - Feature 005
-- =====================================================================
-- Purpose: Prevent students from seeing pending events (except own events)
-- Updated: 2025-11-15
-- =====================================================================

-- Drop existing SELECT policy if exists
DROP POLICY IF EXISTS "events_select_policy" ON events;

-- Create new SELECT policy with moderation visibility rules
--
-- Rules:
-- 1. Approved events: Visible to all authenticated users
-- 2. Pending events: Visible only to creator AND moderators/admins
-- 3. Rejected events: Visible only to creator
--
CREATE POLICY "events_select_policy"
ON events
FOR SELECT
TO authenticated
USING (
  -- Approved events visible to all
  status = 'approved'
  OR
  -- Pending events visible to creator OR moderators/admins
  (
    status = 'pending'
    AND
    (
      created_by = auth.uid() -- Creator can see own pending event
      OR
      EXISTS (
        SELECT 1
        FROM user_roles
        WHERE user_roles.user_id = auth.uid()
        AND user_roles.role IN ('moderator', 'admin')
      )
    )
  )
  OR
  -- Rejected events visible only to creator
  (
    status = 'rejected'
    AND created_by = auth.uid()
  )
);

-- Add SELECT FOR UPDATE policy to prevent race conditions during moderation
--
-- This ensures only one moderator can actively review an event at a time
-- by locking the row during the moderate_event RPC transaction.
--
CREATE POLICY "events_select_for_update_policy"
ON events
FOR UPDATE
TO authenticated
USING (
  -- Only moderators/admins can update moderation fields
  EXISTS (
    SELECT 1
    FROM user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role IN ('moderator', 'admin')
  )
)
WITH CHECK (
  -- Same condition for check
  EXISTS (
    SELECT 1
    FROM user_roles
    WHERE user_roles.user_id = auth.uid()
    AND user_roles.role IN ('moderator', 'admin')
  )
);

-- Add comments for documentation
COMMENT ON POLICY "events_select_policy" ON events IS
'Controls event visibility based on status and user role: approved (all), pending (creator + moderators), rejected (creator only)';

COMMENT ON POLICY "events_select_for_update_policy" ON events IS
'Allows only moderators/admins to update events for moderation purposes, prevents race conditions';

-- =====================================================================
-- END OF RLS POLICY UPDATES
-- =====================================================================
