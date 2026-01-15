-- Migration: Add moderate_event function
-- Description: Creates the moderate_event RPC function for event moderation workflow
-- This function handles event approval/rejection with concurrent modification protection

-- T011: Function - Moderate Event (with Concurrent Modification Protection)
CREATE OR REPLACE FUNCTION moderate_event(
  p_event_id UUID,
  p_action TEXT,
  p_rejection_reason TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  v_event_record RECORD;
  v_moderator_id UUID;
BEGIN
  -- Get current user ID
  v_moderator_id := auth.uid();

  -- Validate action
  IF p_action NOT IN ('approved', 'rejected') THEN
    RAISE EXCEPTION 'Invalid action. Must be "approved" or "rejected".';
  END IF;

  -- Validate rejection reason provided if action is rejected
  IF p_action = 'rejected' AND (p_rejection_reason IS NULL OR p_rejection_reason = '') THEN
    RAISE EXCEPTION 'Rejection reason required when rejecting event';
  END IF;

  -- Lock row for update (fail immediately if locked by another moderator)
  BEGIN
    SELECT * INTO STRICT v_event_record
    FROM events
    WHERE id = p_event_id
    FOR UPDATE NOWAIT;
  EXCEPTION
    WHEN lock_not_available THEN
      RAISE EXCEPTION 'Another moderator is currently reviewing this event';
    WHEN no_data_found THEN
      RAISE EXCEPTION 'Event not found';
  END;

  -- Check if event is pending (not already moderated)
  IF v_event_record.status != 'pending' THEN
    RAISE EXCEPTION 'Event already moderated with status: %', v_event_record.status;
  END IF;

  -- Check if moderator is not the creator (prevent self-moderation)
  IF v_event_record.creator_id = v_moderator_id THEN
    RAISE EXCEPTION 'Cannot moderate your own event';
  END IF;

  -- Update event with moderation info
  UPDATE events
  SET
    status = p_action,
    moderated_by = v_moderator_id,
    moderated_at = NOW(),
    rejection_reason = CASE WHEN p_action = 'rejected' THEN p_rejection_reason ELSE NULL END,
    updated_at = NOW()
  WHERE id = p_event_id;

  -- Insert into moderation log (audit trail) - only if table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'moderation_log') THEN
    INSERT INTO moderation_log (event_id, moderator_id, action, rejection_reason)
    VALUES (p_event_id, v_moderator_id, p_action, p_rejection_reason);
  END IF;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION moderate_event IS 'Approve or reject event with concurrent modification protection (FOR UPDATE NOWAIT) and self-moderation prevention';
