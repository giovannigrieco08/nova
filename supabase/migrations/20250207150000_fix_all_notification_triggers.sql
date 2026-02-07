-- =====================================================================
-- Migration: 20250207150000_fix_all_notification_triggers.sql
-- Purpose: Fix all notification triggers and add missing ones
-- Date: 2025-02-07
-- =====================================================================
--
-- This migration:
-- 1. Fixes notify_coorganizer_addition to use new schema
-- 2. Fixes notify_coorganizer_removal to use new schema
-- 3. Fixes notify_event_modification to use new schema
-- 4. Adds event_moderation notification trigger (approved/rejected)
-- 5. Adds event_invitation notification trigger
-- =====================================================================

-- =====================================================================
-- 1. FIX: Coorganizer Addition Notification
-- =====================================================================

CREATE OR REPLACE FUNCTION notify_coorganizer_addition()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  added_user_id UUID;
  creator_name TEXT;
BEGIN
  -- Only run on UPDATE (not INSERT)
  IF TG_OP = 'INSERT' THEN
    RETURN NEW;
  END IF;

  -- Skip if co_organizers array is null
  IF NEW.co_organizers IS NULL THEN
    RETURN NEW;
  END IF;

  -- Find newly added co-organizers (in NEW but not in OLD)
  FOR added_user_id IN
    SELECT unnest(NEW.co_organizers)
    EXCEPT
    SELECT unnest(COALESCE(OLD.co_organizers, ARRAY[]::UUID[]))
  LOOP
    -- Get creator name
    SELECT full_name INTO creator_name
    FROM profiles
    WHERE user_id = NEW.creator_id;

    -- Create notification using correct function
    PERFORM create_notification(
      p_recipient_id := added_user_id,
      p_sender_id := NEW.creator_id,
      p_type := 'coorganizer_update',
      p_title := 'Aggiunto come co-organizer',
      p_description := COALESCE(creator_name, 'Qualcuno') || ' ti ha aggiunto come co-organizer dell''evento "' || NEW.title || '"',
      p_target_type := 'event',
      p_target_id := NEW.id,
      p_metadata := jsonb_build_object('event_title', NEW.title, 'action', 'added')
    );
  END LOOP;

  RETURN NEW;
END;
$$;

-- =====================================================================
-- 2. FIX: Coorganizer Removal Notification
-- =====================================================================

CREATE OR REPLACE FUNCTION notify_coorganizer_removal()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  removed_user_id UUID;
  creator_name TEXT;
BEGIN
  -- Skip if OLD co_organizers array is null
  IF OLD.co_organizers IS NULL THEN
    RETURN NEW;
  END IF;

  -- Find removed co-organizers (in OLD but not in NEW)
  FOR removed_user_id IN
    SELECT unnest(OLD.co_organizers)
    EXCEPT
    SELECT unnest(COALESCE(NEW.co_organizers, ARRAY[]::UUID[]))
  LOOP
    -- Get creator name
    SELECT full_name INTO creator_name
    FROM profiles
    WHERE user_id = NEW.creator_id;

    -- Create notification
    PERFORM create_notification(
      p_recipient_id := removed_user_id,
      p_sender_id := NEW.creator_id,
      p_type := 'coorganizer_update',
      p_title := 'Rimosso come co-organizer',
      p_description := COALESCE(creator_name, 'Qualcuno') || ' ti ha rimosso come co-organizer dell''evento "' || NEW.title || '"',
      p_target_type := 'event',
      p_target_id := NEW.id,
      p_metadata := jsonb_build_object('event_title', NEW.title, 'action', 'removed')
    );
  END LOOP;

  RETURN NEW;
END;
$$;

-- =====================================================================
-- 3. FIX: Event Modification Notification
-- =====================================================================

CREATE OR REPLACE FUNCTION notify_event_modification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  recipient_id UUID;
  modifier_name TEXT;
BEGIN
  -- Only notify if content fields changed (not status/moderation fields)
  IF NOT (OLD.title IS DISTINCT FROM NEW.title
      OR OLD.description IS DISTINCT FROM NEW.description
      OR OLD.event_date IS DISTINCT FROM NEW.event_date
      OR OLD.location IS DISTINCT FROM NEW.location) THEN
    RETURN NEW;
  END IF;

  -- Skip if no co-organizers
  IF NEW.co_organizers IS NULL OR array_length(NEW.co_organizers, 1) IS NULL THEN
    RETURN NEW;
  END IF;

  -- Get modifier name (the person who made the change)
  SELECT full_name INTO modifier_name
  FROM profiles
  WHERE user_id = auth.uid();

  -- Notify all co-organizers
  FOR recipient_id IN SELECT unnest(NEW.co_organizers) LOOP
    PERFORM create_notification(
      p_recipient_id := recipient_id,
      p_sender_id := auth.uid(),
      p_type := 'coorganizer_update',
      p_title := 'Evento modificato',
      p_description := COALESCE(modifier_name, 'Qualcuno') || ' ha modificato l''evento "' || NEW.title || '"',
      p_target_type := 'event',
      p_target_id := NEW.id,
      p_metadata := jsonb_build_object('event_title', NEW.title, 'action', 'modified')
    );
  END LOOP;

  RETURN NEW;
END;
$$;

-- =====================================================================
-- 4. NEW: Event Moderation Notification
-- =====================================================================

CREATE OR REPLACE FUNCTION trigger_event_moderation_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_moderator_name TEXT;
  v_title TEXT;
  v_description TEXT;
BEGIN
  -- Only trigger when status changes from pending to approved/rejected
  IF OLD.status != 'pending' OR NEW.status = 'pending' THEN
    RETURN NEW;
  END IF;

  -- Get moderator name
  SELECT full_name INTO v_moderator_name
  FROM profiles
  WHERE user_id = NEW.moderated_by;

  -- Set title and description based on action
  IF NEW.status = 'approved' THEN
    v_title := 'Evento approvato';
    v_description := 'Il tuo evento "' || NEW.title || '" è stato approvato';
  ELSE
    v_title := 'Evento rifiutato';
    v_description := 'Il tuo evento "' || NEW.title || '" è stato rifiutato';
    IF NEW.rejection_reason IS NOT NULL AND NEW.rejection_reason != '' THEN
      v_description := v_description || ': ' || NEW.rejection_reason;
    END IF;
  END IF;

  -- Create notification for event creator
  PERFORM create_notification(
    p_recipient_id := NEW.creator_id,
    p_sender_id := NEW.moderated_by,
    p_type := 'event_moderation',
    p_title := v_title,
    p_description := v_description,
    p_target_type := 'event',
    p_target_id := NEW.id,
    p_metadata := jsonb_build_object(
      'event_title', NEW.title,
      'status', NEW.status,
      'rejection_reason', NEW.rejection_reason
    )
  );

  RETURN NEW;
END;
$$;

-- Create the trigger (drop first if exists)
DROP TRIGGER IF EXISTS on_event_moderation_notify_creator ON events;
CREATE TRIGGER on_event_moderation_notify_creator
  AFTER UPDATE ON events
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION trigger_event_moderation_notification();

-- =====================================================================
-- 5. NEW: Event Invitation Notification
-- =====================================================================

CREATE OR REPLACE FUNCTION trigger_event_invitation_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_inviter_name TEXT;
  v_event_title TEXT;
BEGIN
  -- Get inviter name
  SELECT full_name INTO v_inviter_name
  FROM profiles
  WHERE user_id = NEW.inviter_id;

  -- Get event title
  SELECT title INTO v_event_title
  FROM events
  WHERE id = NEW.event_id;

  -- Create notification for invitee
  PERFORM create_notification(
    p_recipient_id := NEW.invitee_id,
    p_sender_id := NEW.inviter_id,
    p_type := 'event_invitation',
    p_title := 'Richiesta di collaborazione',
    p_description := COALESCE(v_inviter_name, 'Qualcuno') || ' ti ha invitato a collaborare all''evento "' || COALESCE(v_event_title, 'Evento') || '"',
    p_target_type := 'event',
    p_target_id := NEW.event_id,
    p_metadata := jsonb_build_object(
      'event_title', v_event_title,
      'invitation_id', NEW.id,
      'status', NEW.status
    )
  );

  RETURN NEW;
END;
$$;

-- Create the trigger (drop first if exists)
DROP TRIGGER IF EXISTS on_event_invitation_notify_invitee ON event_invitations;
CREATE TRIGGER on_event_invitation_notify_invitee
  AFTER INSERT ON event_invitations
  FOR EACH ROW
  EXECUTE FUNCTION trigger_event_invitation_notification();

-- =====================================================================
-- VERIFICATION
-- =====================================================================

DO $$
BEGIN
  RAISE NOTICE '=== Notification Triggers Fixed ===';
  RAISE NOTICE '1. notify_coorganizer_addition - FIXED';
  RAISE NOTICE '2. notify_coorganizer_removal - FIXED';
  RAISE NOTICE '3. notify_event_modification - FIXED';
  RAISE NOTICE '4. trigger_event_moderation_notification - ADDED';
  RAISE NOTICE '5. trigger_event_invitation_notification - ADDED';
END $$;
