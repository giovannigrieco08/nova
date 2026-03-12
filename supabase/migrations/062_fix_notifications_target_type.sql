-- Migration: 062_fix_notifications_target_type
-- Purpose: Update notifications target_type check constraint to allow safety-related types
-- Date: 2026-03-12
-- Issue: user_block notifications fail due to check constraint violation

-- ============================================================================
-- UPDATE TARGET TYPE CONSTRAINT
-- ============================================================================

-- Drop old constraint
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_target_type_check;

-- Add updated constraint with safety types
ALTER TABLE notifications ADD CONSTRAINT notifications_target_type_check
  CHECK (target_type IN ('event', 'comment', 'chat_message', 'user_block', 'report', 'user'));

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '=====================================================';
  RAISE NOTICE 'Migration 062_fix_notifications_target_type completed';
  RAISE NOTICE '  - Updated constraint to allow: event, comment, chat_message, user_block, report, user';
  RAISE NOTICE '=====================================================';
END $$;
