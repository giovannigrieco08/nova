-- Migration: 044_fix_notifications_constraint
-- Description: Remove obsolete notifications_channel_check constraint
-- Date: 2026-02-05
--
-- Problem: An old constraint (notifications_channel_check) was blocking inserts
--          with newer notification types like 'event_moderation', 'new_comment', etc.
--          The correct constraint (notifications_type_check) already exists.
--
-- Fix: Drop the obsolete constraint.

-- Remove obsolete constraint
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_channel_check;

-- Also remove obsolete body check if it exists (we use description now)
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_body_check;

-- Verification
DO $$
DECLARE
  constraint_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO constraint_count
  FROM pg_constraint
  WHERE conrelid = 'notifications'::regclass
    AND conname LIKE 'notifications_%_check';

  RAISE NOTICE 'Migration 044 complete: Removed obsolete notification constraints';
  RAISE NOTICE '   - Remaining check constraints: %', constraint_count;
END $$;
