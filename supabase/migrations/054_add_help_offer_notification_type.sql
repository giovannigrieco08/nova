-- =====================================================================
-- Migration: 054_add_help_offer_notification_type.sql
-- Purpose: Add 'help_offer' to allowed notification types
-- Date: 2025-02-07
-- =====================================================================
--
-- Problem: The notifications table has a CHECK constraint that doesn't
-- include 'help_offer' as a valid type, causing the notification trigger
-- to fail silently.
--
-- Fix: Drop and recreate the CHECK constraint to include 'help_offer'
-- =====================================================================

-- =====================================================================
-- DROP EXISTING CHECK CONSTRAINT
-- =====================================================================

-- First, we need to find and drop the existing constraint
DO $$
DECLARE
  constraint_name TEXT;
BEGIN
  -- Find the constraint name for the type check
  SELECT conname INTO constraint_name
  FROM pg_constraint
  WHERE conrelid = 'notifications'::regclass
  AND contype = 'c'
  AND pg_get_constraintdef(oid) LIKE '%type%';

  IF constraint_name IS NOT NULL THEN
    EXECUTE 'ALTER TABLE notifications DROP CONSTRAINT ' || constraint_name;
    RAISE NOTICE 'Dropped constraint: %', constraint_name;
  ELSE
    RAISE NOTICE 'No type constraint found to drop';
  END IF;
END $$;

-- =====================================================================
-- ADD NEW CHECK CONSTRAINT WITH help_offer
-- =====================================================================

-- Drop our constraint if it exists (from previous partial run)
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Add the new constraint with all types
ALTER TABLE notifications
ADD CONSTRAINT notifications_type_check
CHECK (type IN (
  'event_moderation',
  'new_comment',
  'comment_reply',
  'event_like',
  'event_participation',
  'coorganizer_update',
  'chat_mention',
  'help_offer',
  'invitation_accepted'
));

-- =====================================================================
-- VERIFICATION
-- =====================================================================

DO $$
BEGIN
  -- Verify constraint exists with new values
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'notifications'::regclass
    AND conname = 'notifications_type_check'
  ) THEN
    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'Migration 054_add_help_offer_notification_type completed';
    RAISE NOTICE '  - Added help_offer to allowed notification types';
    RAISE NOTICE '  - Added invitation_accepted to allowed types';
    RAISE NOTICE '=====================================================';
  ELSE
    RAISE EXCEPTION 'Migration failed: constraint not created';
  END IF;
END $$;
