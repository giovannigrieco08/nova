-- Migration: 062_fix_notifications_target_type
-- Purpose: Update notifications type and target_type check constraints for safety features
-- Date: 2026-03-12
-- Issue: user_block notifications fail due to check constraint violations

-- ============================================================================
-- UPDATE TYPE CONSTRAINT (notification type)
-- ============================================================================

ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
CHECK (type IN (
  'event_moderation',
  'new_comment',
  'comment_reply',
  'event_like',
  'event_participation',
  'coorganizer_update',
  'chat_mention',
  'help_offer',
  'invitation_accepted',
  'user_block',
  'user_report',
  'moderation_action'
));

-- ============================================================================
-- UPDATE TARGET TYPE CONSTRAINT (navigation target)
-- ============================================================================

ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_target_type_check;

ALTER TABLE notifications ADD CONSTRAINT notifications_target_type_check
  CHECK (target_type IN ('event', 'comment', 'chat_message', 'user_block', 'report', 'user'));

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '=====================================================';
  RAISE NOTICE 'Migration 062_fix_notifications_target_type completed';
  RAISE NOTICE '  - type: added user_block, user_report, moderation_action';
  RAISE NOTICE '  - target_type: added user_block, report, user';
  RAISE NOTICE '=====================================================';
END $$;
