-- Migration: 049_add_invitation_notification_trigger
-- Purpose: Add notification trigger for event invitations
-- Date: 2026-02-06
-- Issue: Users don't receive notifications when invited to collaborate on an event

-- ============================================================================
-- PART 1: ADD NOTIFICATION TYPE FOR INVITATIONS
-- ============================================================================

-- First, we need to add 'event_invitation' to the allowed notification types
-- We'll alter the check constraint on the notifications table

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notifications') THEN
    -- Drop the existing check constraint
    ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

    -- Add updated check constraint with event_invitation type
    ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
      CHECK (type IN (
        'event_moderation',
        'new_comment',
        'comment_reply',
        'event_like',
        'event_participation',
        'coorganizer_update',
        'chat_mention',
        'event_invitation'  -- NEW: Invitation notifications
      ));

    RAISE NOTICE 'Added event_invitation to notification types';
  END IF;
END $$;

-- ============================================================================
-- PART 2: ADD PREFERENCE COLUMN FOR INVITATION NOTIFICATIONS
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
    -- Add preference column (opt-out model: enabled by default)
    ALTER TABLE profiles
      ADD COLUMN IF NOT EXISTS event_invitations_enabled BOOLEAN NOT NULL DEFAULT TRUE;

    COMMENT ON COLUMN profiles.event_invitations_enabled IS 'Receive notifications when invited to collaborate on events';

    RAISE NOTICE 'Added event_invitations_enabled preference column';
  END IF;
END $$;

-- ============================================================================
-- PART 3: UPDATE create_notification() TO HANDLE NEW TYPE
-- ============================================================================

-- We need to recreate the function to include the new notification type check
CREATE OR REPLACE FUNCTION create_notification(
  p_recipient_id UUID,
  p_sender_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_description TEXT,
  p_target_type TEXT,
  p_target_id UUID,
  p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_notification_id UUID;
  v_preference_enabled BOOLEAN;
BEGIN
  -- Check if recipient has this notification type enabled
  SELECT
    CASE p_type
      WHEN 'event_moderation' THEN eventi_moderati_enabled
      WHEN 'new_comment' THEN nuovi_commenti_enabled
      WHEN 'comment_reply' THEN risposte_commenti_enabled
      WHEN 'event_like' THEN like_eventi_enabled
      WHEN 'event_participation' THEN nuove_partecipazioni_enabled
      WHEN 'coorganizer_update' THEN coorganizer_updates_enabled
      WHEN 'chat_mention' THEN chat_mentions_enabled
      WHEN 'event_invitation' THEN event_invitations_enabled  -- NEW
      ELSE TRUE -- Unknown types default to enabled
    END INTO v_preference_enabled
  FROM profiles
  WHERE user_id = p_recipient_id;

  -- If preference is disabled or user doesn't exist, skip notification
  IF NOT COALESCE(v_preference_enabled, FALSE) THEN
    RETURN NULL;
  END IF;

  -- Prevent self-notifications (don't notify yourself of your own actions)
  IF p_sender_id = p_recipient_id THEN
    RETURN NULL;
  END IF;

  -- Insert notification (bypasses RLS due to SECURITY DEFINER)
  INSERT INTO notifications (
    recipient_id,
    sender_id,
    type,
    title,
    description,
    target_type,
    target_id,
    metadata
  ) VALUES (
    p_recipient_id,
    p_sender_id,
    p_type,
    p_title,
    p_description,
    p_target_type,
    p_target_id,
    p_metadata
  )
  RETURNING id INTO v_notification_id;

  RETURN v_notification_id;
END;
$$;

COMMENT ON FUNCTION create_notification IS 'Creates notification if recipient preferences allow it. Returns NULL if skipped. Supports event_invitation type.';

-- ============================================================================
-- PART 4: CREATE TRIGGER FUNCTION FOR INVITATION NOTIFICATIONS
-- ============================================================================

CREATE OR REPLACE FUNCTION trigger_invitation_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_title TEXT;
  v_inviter_name TEXT;
BEGIN
  -- Get event title
  SELECT title INTO v_event_title
  FROM events
  WHERE id = NEW.event_id;

  -- Get inviter's name
  SELECT full_name INTO v_inviter_name
  FROM profiles
  WHERE user_id = NEW.inviter_id;

  -- Create notification for the invitee
  PERFORM create_notification(
    NEW.invitee_id,                                    -- recipient
    NEW.inviter_id,                                    -- sender
    'event_invitation',                                -- type
    COALESCE(v_inviter_name, 'Qualcuno') || ' ti ha invitato a collaborare',  -- title
    'Sei stato invitato a collaborare all''evento "' || LEFT(COALESCE(v_event_title, 'Evento'), 50) || '"',  -- description
    'event',                                           -- target_type
    NEW.event_id,                                      -- target_id
    jsonb_build_object('invitation_id', NEW.id)       -- metadata
  );

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION trigger_invitation_notification IS 'Sends notification when a user is invited to collaborate on an event';

-- ============================================================================
-- PART 5: ATTACH TRIGGER TO event_invitations TABLE
-- ============================================================================

-- Drop existing trigger if it exists (for idempotent migration)
DROP TRIGGER IF EXISTS on_invitation_notify_invitee ON event_invitations;

-- Create trigger on INSERT
CREATE TRIGGER on_invitation_notify_invitee
  AFTER INSERT ON event_invitations
  FOR EACH ROW
  EXECUTE FUNCTION trigger_invitation_notification();

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE 'Migration 049 complete: Added invitation notification trigger';
  RAISE NOTICE '- Added event_invitation notification type';
  RAISE NOTICE '- Added event_invitations_enabled preference column';
  RAISE NOTICE '- Created trigger_invitation_notification() function';
  RAISE NOTICE '- Attached trigger to event_invitations table';
END $$;
