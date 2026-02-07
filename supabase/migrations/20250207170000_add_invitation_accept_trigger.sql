-- =====================================================================
-- Migration: 20250207170000_add_invitation_accept_trigger.sql
-- Purpose: Add trigger to handle invitation acceptance (add to co_organizers)
-- Date: 2025-02-07
-- =====================================================================

-- =====================================================================
-- Trigger: Add user to co_organizers when invitation is accepted
-- =====================================================================

CREATE OR REPLACE FUNCTION handle_invitation_response()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only trigger when status changes to 'accepted'
  IF NEW.status = 'accepted' AND (OLD.status IS NULL OR OLD.status != 'accepted') THEN
    -- Add invitee to co_organizers array of the event
    UPDATE events
    SET co_organizers = array_append(
      COALESCE(co_organizers, ARRAY[]::UUID[]),
      NEW.invitee_id
    )
    WHERE id = NEW.event_id
    AND NOT (NEW.invitee_id = ANY(COALESCE(co_organizers, ARRAY[]::UUID[])));
  END IF;

  RETURN NEW;
END;
$$;

-- Create the trigger (drop first if exists)
DROP TRIGGER IF EXISTS on_invitation_response ON event_invitations;
CREATE TRIGGER on_invitation_response
  AFTER UPDATE ON event_invitations
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION handle_invitation_response();

-- =====================================================================
-- VERIFICATION
-- =====================================================================

DO $$
BEGIN
  RAISE NOTICE '=== Invitation Accept Trigger Added ===';
  RAISE NOTICE 'When an invitation is accepted, the invitee is automatically added to co_organizers';
END $$;
