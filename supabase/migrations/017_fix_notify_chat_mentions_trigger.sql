-- =====================================================================
-- Migration: 017_fix_notify_chat_mentions_trigger.sql
-- Purpose: Fix notify_chat_mentions() to use correct column names
-- Date: 2025-12-04
-- =====================================================================
--
-- The trigger function was created before the notifications table
-- schema was updated. This migration updates the function to use
-- the correct column names: recipient_id, description, metadata
-- =====================================================================

CREATE OR REPLACE FUNCTION notify_chat_mentions()
RETURNS TRIGGER AS $$
DECLARE
  mention JSONB;
  mentioned_user_id UUID;
  sender_name TEXT;
BEGIN
  -- Get sender name
  SELECT full_name INTO sender_name
  FROM profiles
  WHERE user_id = NEW.user_id;

  -- Parse mentions array and create notifications
  FOR mention IN SELECT * FROM jsonb_array_elements(NEW.mentions) LOOP
    mentioned_user_id := (mention->>'user_id')::UUID;

    -- Don't notify self-mentions
    IF mentioned_user_id != NEW.user_id THEN
      -- Insert notification using correct schema
      INSERT INTO notifications (
        recipient_id,
        sender_id,
        type,
        title,
        description,
        target_type,
        target_id,
        metadata,
        created_at
      ) VALUES (
        mentioned_user_id,
        NEW.user_id,
        'chat_mention',
        'Ti hanno menzionato in chat',
        COALESCE(sender_name, 'Qualcuno') || ': ' || substring(NEW.content from 1 for 100),
        'chat_message',
        NEW.id,
        jsonb_build_object(
          'message_id', NEW.id,
          'sender_id', NEW.user_id
        ),
        NOW()
      );
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION notify_chat_mentions() IS 'Create notifications for @mentioned users (fixed column names)';
