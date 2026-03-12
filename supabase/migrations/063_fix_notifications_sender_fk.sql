-- Migration: 063_fix_notifications_sender_fk
-- Purpose: Fix notifications sender_id FK constraint that fails when user has no profile
-- Date: 2026-03-12
-- Issue: Block notifications fail because sender_id references profiles, not auth.users

-- ============================================================================
-- PROBLEM ANALYSIS
-- ============================================================================
--
-- notifications.sender_id has FK to profiles(user_id)
-- But some authenticated users may not have a profile record yet
-- The notify_moderators_on_block trigger tries to insert with blocker's user_id
-- This fails if the blocker doesn't have a profile
--
-- SOLUTION: Remove FK to profiles, keep data integrity via trigger logic

-- ============================================================================
-- REMOVE FK CONSTRAINT ON SENDER_ID
-- ============================================================================

-- Drop the FK constraint (if it exists)
ALTER TABLE notifications
DROP CONSTRAINT IF EXISTS notifications_sender_id_fkey;

-- Also try common naming patterns
DO $$
DECLARE
  constraint_name TEXT;
BEGIN
  -- Find and drop any FK constraint on sender_id
  FOR constraint_name IN
    SELECT tc.constraint_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
    WHERE tc.table_name = 'notifications'
      AND tc.constraint_type = 'FOREIGN KEY'
      AND kcu.column_name = 'sender_id'
  LOOP
    EXECUTE 'ALTER TABLE notifications DROP CONSTRAINT IF EXISTS ' || quote_ident(constraint_name);
    RAISE NOTICE 'Dropped FK constraint: %', constraint_name;
  END LOOP;
END $$;

-- ============================================================================
-- UPDATE TRIGGER TO HANDLE MISSING PROFILES GRACEFULLY
-- ============================================================================

CREATE OR REPLACE FUNCTION notify_moderators_on_block()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  blocker_name TEXT;
  blocked_name TEXT;
  blocker_profile_exists BOOLEAN;
BEGIN
  -- Check if blocker has a profile
  SELECT EXISTS(SELECT 1 FROM profiles WHERE user_id = NEW.blocker_id) INTO blocker_profile_exists;

  -- Get user names (will be NULL if profile doesn't exist)
  SELECT full_name INTO blocker_name FROM profiles WHERE user_id = NEW.blocker_id;
  SELECT full_name INTO blocked_name FROM profiles WHERE user_id = NEW.blocked_id;

  -- Use fallback names if NULL
  blocker_name := COALESCE(blocker_name, 'Utente');
  blocked_name := COALESCE(blocked_name, 'Utente');

  -- Insert notification for all moderators
  -- Only set sender_id if the profile exists (to avoid display issues)
  INSERT INTO notifications (recipient_id, sender_id, type, title, description, target_type, target_id)
  SELECT
    ur.user_id,
    CASE WHEN blocker_profile_exists THEN NEW.blocker_id ELSE NULL END,
    'user_block',
    'Nuovo blocco utente',
    blocker_name || ' ha bloccato ' || blocked_name,
    'user_block',
    NEW.id
  FROM user_roles ur
  WHERE ur.role IN ('moderator', 'admin');

  -- Mark as notified
  UPDATE user_blocks
  SET moderator_notified = TRUE, notified_at = NOW()
  WHERE id = NEW.id;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Log error but don't fail the block operation
  RAISE WARNING 'notify_moderators_on_block failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
  fk_count INT;
BEGIN
  SELECT COUNT(*) INTO fk_count
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
  WHERE tc.table_name = 'notifications'
    AND tc.constraint_type = 'FOREIGN KEY'
    AND kcu.column_name = 'sender_id';

  RAISE NOTICE '=====================================================';
  RAISE NOTICE 'Migration 063_fix_notifications_sender_fk completed';
  RAISE NOTICE '  - Removed FK constraints on sender_id';
  RAISE NOTICE '  - Updated trigger to handle missing profiles';
  RAISE NOTICE '  - Remaining sender_id FK constraints: %', fk_count;
  RAISE NOTICE '=====================================================';
END $$;
