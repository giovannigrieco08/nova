-- =====================================================================
-- Migration: 006_add_coorganizer_notifications.sql
-- Feature: 004-event-creation-moderation (Phase 7 - Co-Organizers)
-- Date: 2025-01-12
-- Purpose: Add notification triggers for co-organizer management
-- =====================================================================

-- This migration adds 3 notification triggers:
-- 1. Notify when user is added as co-organizer
-- 2. Notify when user is removed as co-organizer
-- 3. Notify all co-organizers + creator when event is modified

-- =====================================================================
-- TRIGGER 1: Notify Added Co-Organizers
-- =====================================================================

-- Function to notify users added as co-organizers
CREATE OR REPLACE FUNCTION notify_coorganizer_addition()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  added_user_id UUID;
  creator_name TEXT;
BEGIN
  -- Only run on UPDATE (not INSERT)
  IF TG_OP = 'INSERT' THEN
    RETURN NEW;
  END IF;

  -- Find newly added co-organizers (in NEW but not in OLD)
  FOR added_user_id IN
    SELECT unnest(NEW.co_organizers)
    EXCEPT
    SELECT unnest(OLD.co_organizers)
  LOOP
    -- Get creator name from profiles table
    SELECT full_name INTO creator_name
    FROM profiles
    WHERE user_id = NEW.creator_id;

    -- Create notification for added user
    INSERT INTO notifications (user_id, channel, title, body, event_id)
    VALUES (
      added_user_id,
      'added_as_coorganizer',
      'Aggiunto come Co-Organizer',
      format('%s ti ha aggiunto come co-organizer dell''evento "%s"', creator_name, NEW.title),
      NEW.id
    );
  END LOOP;

  RETURN NEW;
END;
$$;

-- Create trigger on events table
DROP TRIGGER IF EXISTS trigger_notify_coorganizer_addition ON events;
CREATE TRIGGER trigger_notify_coorganizer_addition
  AFTER UPDATE ON events
  FOR EACH ROW
  WHEN (NEW.co_organizers IS DISTINCT FROM OLD.co_organizers)
  EXECUTE FUNCTION notify_coorganizer_addition();

-- =====================================================================
-- TRIGGER 2: Notify Removed Co-Organizers
-- =====================================================================

-- Function to notify users removed as co-organizers
CREATE OR REPLACE FUNCTION notify_coorganizer_removal()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  removed_user_id UUID;
  creator_name TEXT;
BEGIN
  -- Only run on UPDATE (not DELETE)
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  -- Find removed co-organizers (in OLD but not in NEW)
  FOR removed_user_id IN
    SELECT unnest(OLD.co_organizers)
    EXCEPT
    SELECT unnest(NEW.co_organizers)
  LOOP
    -- Get creator name from profiles table
    SELECT full_name INTO creator_name
    FROM profiles
    WHERE user_id = NEW.creator_id;

    -- Create notification for removed user
    INSERT INTO notifications (user_id, channel, title, body, event_id)
    VALUES (
      removed_user_id,
      'event_modified',  -- Reusing event_modified channel for removal
      'Rimosso come Co-Organizer',
      format('%s ti ha rimosso come co-organizer dell''evento "%s"', creator_name, NEW.title),
      NEW.id
    );
  END LOOP;

  RETURN NEW;
END;
$$;

-- Create trigger on events table
DROP TRIGGER IF EXISTS trigger_notify_coorganizer_removal ON events;
CREATE TRIGGER trigger_notify_coorganizer_removal
  AFTER UPDATE ON events
  FOR EACH ROW
  WHEN (NEW.co_organizers IS DISTINCT FROM OLD.co_organizers)
  EXECUTE FUNCTION notify_coorganizer_removal();

-- =====================================================================
-- TRIGGER 3: Notify Event Modification
-- =====================================================================

-- Function to notify creator + co-organizers when event is modified
CREATE OR REPLACE FUNCTION notify_event_modification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  recipient_id UUID;
  modifier_name TEXT;
BEGIN
  -- Only notify if content fields changed (not status/moderation fields)
  IF (OLD.title IS DISTINCT FROM NEW.title
      OR OLD.description IS DISTINCT FROM NEW.description
      OR OLD.event_date IS DISTINCT FROM NEW.event_date
      OR OLD.location IS DISTINCT FROM NEW.location
      OR OLD.image_url IS DISTINCT FROM NEW.image_url) THEN

    -- Get modifier name from profiles table
    SELECT full_name INTO modifier_name
    FROM profiles
    WHERE user_id = (SELECT auth.uid());

    -- Notify creator (if they didn't make the change)
    IF NEW.creator_id != (SELECT auth.uid()) THEN
      INSERT INTO notifications (user_id, channel, title, body, event_id)
      VALUES (
        NEW.creator_id,
        'event_modified',
        'Evento Modificato',
        format('%s ha modificato l''evento "%s"', modifier_name, NEW.title),
        NEW.id
      );
    END IF;

    -- Notify all co-organizers (except the one who made the change)
    FOR recipient_id IN
      SELECT unnest(NEW.co_organizers)
      WHERE unnest(NEW.co_organizers) != (SELECT auth.uid())
    LOOP
      INSERT INTO notifications (user_id, channel, title, body, event_id)
      VALUES (
        recipient_id,
        'event_modified',
        'Evento Modificato',
        format('%s ha modificato l''evento "%s"', modifier_name, NEW.title),
        NEW.id
      );
    END LOOP;

  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger on events table
DROP TRIGGER IF EXISTS trigger_notify_event_modification ON events;
CREATE TRIGGER trigger_notify_event_modification
  AFTER UPDATE ON events
  FOR EACH ROW
  EXECUTE FUNCTION notify_event_modification();

-- =====================================================================
-- GRANT PERMISSIONS
-- =====================================================================

-- Grant execute permission to authenticated users (triggers run as SECURITY DEFINER)
GRANT EXECUTE ON FUNCTION notify_coorganizer_addition() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_coorganizer_removal() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_event_modification() TO authenticated;

-- =====================================================================
-- VALIDATION QUERIES (Uncomment to verify setup after migration)
-- =====================================================================

-- Verify triggers exist:
-- SELECT tgname FROM pg_trigger WHERE tgrelid = 'events'::regclass AND tgname LIKE '%notify%';

-- Verify functions exist:
-- SELECT proname FROM pg_proc WHERE proname LIKE 'notify_%';

-- Test trigger (as authenticated user):
-- UPDATE events SET co_organizers = array_append(co_organizers, 'USER_UUID_HERE') WHERE id = 'EVENT_UUID_HERE';
-- SELECT * FROM notifications WHERE user_id = 'USER_UUID_HERE' ORDER BY sent_at DESC LIMIT 1;

-- =====================================================================
-- END OF MIGRATION
-- =====================================================================
