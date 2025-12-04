-- =====================================================================
-- Migration: 005_upgrade_events_add_moderation.sql
-- Feature: 004-event-creation-moderation (Event Creation & Moderation System)
-- Date: 2025-01-10
-- Purpose: Upgrade events table for moderation + add notifications/user_roles
-- =====================================================================

-- This migration:
-- 1. Upgrades events table schema (merge event_date+event_time, add moderation fields)
-- 2. Creates notifications table for FCM push notifications
-- 3. Creates user_roles table for moderator permissions
-- 4. Adds new RLS policies for moderation
-- 5. Preserves existing data from Feature 003

-- =====================================================================
-- PHASE 1: UPGRADE EVENTS TABLE SCHEMA
-- =====================================================================

-- Step 1: Add new columns for Feature 004
ALTER TABLE events
  ADD COLUMN IF NOT EXISTS co_organizers UUID[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS moderated_by UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS moderated_at TIMESTAMPTZ;

-- Step 1b: Drop objects that depend on event_date column (will be recreated later)
DROP POLICY IF EXISTS "users_view_approved_upcoming_events" ON events;
DROP INDEX IF EXISTS idx_events_date_status;
DROP INDEX IF EXISTS idx_events_event_date;

-- Step 2: Merge event_date + event_time into single TIMESTAMPTZ column
-- Create temporary column for merged datetime
ALTER TABLE events ADD COLUMN IF NOT EXISTS event_date_new TIMESTAMPTZ;

-- Migrate existing data: combine DATE + TIME into TIMESTAMPTZ
UPDATE events
SET event_date_new = (event_date::text || ' ' || event_time::text)::TIMESTAMPTZ
WHERE event_date_new IS NULL;

-- Make new column NOT NULL after data migration
ALTER TABLE events ALTER COLUMN event_date_new SET NOT NULL;

-- Drop old columns and rename new one
ALTER TABLE events DROP COLUMN IF EXISTS event_time;
ALTER TABLE events DROP COLUMN IF EXISTS event_date;
ALTER TABLE events RENAME COLUMN event_date_new TO event_date;

-- Step 2b: Recreate policy and indexes updated for TIMESTAMPTZ
CREATE POLICY "users_view_approved_upcoming_events"
  ON events
  FOR SELECT
  TO authenticated
  USING (
    status = 'approved'
    AND event_date >= now()  -- Updated for TIMESTAMPTZ
  );

-- Recreate indexes for TIMESTAMPTZ
CREATE INDEX IF NOT EXISTS idx_events_date_status
  ON events(event_date, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_events_event_date
  ON events(event_date)
  WHERE status = 'approved';

-- Step 3: Change location from required to optional
ALTER TABLE events ALTER COLUMN location DROP NOT NULL;

-- Step 4: Replace cover_images array with single image_url
ALTER TABLE events ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Migrate existing data: take first image from cover_images array
UPDATE events
SET image_url = cover_images[1]
WHERE image_url IS NULL AND array_length(cover_images, 1) > 0;

-- Drop old cover_images column
ALTER TABLE events DROP COLUMN IF EXISTS cover_images;

-- Step 5: Update status column constraint to include 'pending' (if not already there)
-- Drop existing constraint and recreate with all three statuses
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_status_check;
ALTER TABLE events ADD CONSTRAINT events_status_check
  CHECK (status IN ('pending', 'approved', 'rejected'));

-- Step 6: Add validation for rejection_reason (min 10 chars when status=rejected)
-- This is app-enforced, but we can add a CHECK constraint
ALTER TABLE events ADD CONSTRAINT events_rejection_reason_check
  CHECK (
    (status != 'rejected') OR
    (status = 'rejected' AND length(trim(rejection_reason)) >= 10)
  );

-- Step 7: Add index for co_organizers array (GIN index for fast lookups)
CREATE INDEX IF NOT EXISTS idx_events_co_organizers ON events USING GIN (co_organizers);

-- Step 8: Add index for moderation queue (pending events ordered by creation)
CREATE INDEX IF NOT EXISTS idx_events_moderation_queue
  ON events(status, created_at)
  WHERE status = 'pending';

-- =====================================================================
-- PHASE 2: NOTIFICATIONS TABLE
-- =====================================================================
-- NOTE: Notifications table moved to 008_realtime_notifications.sql
-- with complete schema (recipient_id, sender_id, type, metadata, preferences)

-- =====================================================================
-- PHASE 3: CREATE USER_ROLES TABLE (FOR MODERATORS)
-- =====================================================================

CREATE TABLE IF NOT EXISTS user_roles (
  -- Composite Primary Key
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('student', 'moderator', 'admin')),

  -- Metadata
  granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  granted_by UUID REFERENCES auth.users(id),

  PRIMARY KEY (user_id, role)
);

-- Index for fast role lookups
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role ON user_roles(role);

-- Enable RLS on user_roles
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view their own roles
DROP POLICY IF EXISTS "users_view_own_roles" ON user_roles;
CREATE POLICY "users_view_own_roles"
  ON user_roles
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- RLS Policy: Only admins can manage roles (using JWT metadata check)
DROP POLICY IF EXISTS "admins_manage_roles" ON user_roles;
CREATE POLICY "admins_manage_roles"
  ON user_roles
  FOR ALL
  TO authenticated
  USING ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin')
  WITH CHECK ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin');

-- =====================================================================
-- PHASE 4: CREATE HELPER FUNCTION FOR MODERATOR CHECK
-- =====================================================================

-- Function to check if current user is a moderator
CREATE OR REPLACE FUNCTION is_moderator()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = (SELECT auth.uid())
      AND role IN ('moderator', 'admin')
  );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION is_moderator() TO authenticated;

-- =====================================================================
-- PHASE 5: ADD NEW RLS POLICIES FOR MODERATION
-- =====================================================================

-- Policy: Moderators can view all events (including pending/rejected)
DROP POLICY IF EXISTS "moderators_view_all_events" ON events;
CREATE POLICY "moderators_view_all_events"
  ON events
  FOR SELECT
  TO authenticated
  USING (is_moderator());

-- Policy: Creators can view their own events (any status)
DROP POLICY IF EXISTS "creators_view_own_events" ON events;
CREATE POLICY "creators_view_own_events"
  ON events
  FOR SELECT
  TO authenticated
  USING (creator_id = (SELECT auth.uid()));

-- Policy: Co-organizers can view their events
DROP POLICY IF EXISTS "coorganizers_view_events" ON events;
CREATE POLICY "coorganizers_view_events"
  ON events
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = ANY(co_organizers));

-- Policy: Moderators can update event status (approve/reject)
DROP POLICY IF EXISTS "moderators_update_event_status" ON events;
CREATE POLICY "moderators_update_event_status"
  ON events
  FOR UPDATE
  TO authenticated
  USING (is_moderator())
  WITH CHECK (is_moderator());

-- Policy: Co-organizers can update event details (triggers re-moderation)
DROP POLICY IF EXISTS "coorganizers_update_events" ON events;
CREATE POLICY "coorganizers_update_events"
  ON events
  FOR UPDATE
  TO authenticated
  USING (
    (creator_id = (SELECT auth.uid())) OR
    ((SELECT auth.uid()) = ANY(co_organizers))
  )
  WITH CHECK (
    (creator_id = (SELECT auth.uid())) OR
    ((SELECT auth.uid()) = ANY(co_organizers))
  );

-- =====================================================================
-- PHASE 6: CREATE TRIGGER FOR AUTO RE-MODERATION
-- =====================================================================

-- Function to reset status to 'pending' when event is modified by non-moderators
CREATE OR REPLACE FUNCTION trigger_remoderation_on_event_edit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- If event was approved and non-moderator edits it, reset to pending
  IF OLD.status = 'approved'
     AND NOT is_moderator()
     AND (OLD.title != NEW.title
          OR OLD.description != NEW.description
          OR OLD.event_date != NEW.event_date
          OR OLD.location IS DISTINCT FROM NEW.location
          OR OLD.image_url IS DISTINCT FROM NEW.image_url) THEN
    NEW.status := 'pending';
    NEW.moderated_by := NULL;
    NEW.moderated_at := NULL;
    NEW.rejection_reason := NULL;
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger on events table
DROP TRIGGER IF EXISTS events_remoderation_trigger ON events;
CREATE TRIGGER events_remoderation_trigger
  BEFORE UPDATE ON events
  FOR EACH ROW
  EXECUTE FUNCTION trigger_remoderation_on_event_edit();

-- =====================================================================
-- PHASE 7: GRANT DEFAULT STUDENT ROLE TO EXISTING USERS
-- =====================================================================

-- Insert 'student' role for all existing auth.users who don't have a role yet
INSERT INTO user_roles (user_id, role, granted_at, granted_by)
SELECT
  id,
  'student',
  NOW(),
  NULL
FROM auth.users
WHERE id NOT IN (SELECT user_id FROM user_roles)
ON CONFLICT (user_id, role) DO NOTHING;

-- =====================================================================
-- VALIDATION QUERIES (Uncomment to verify setup after migration)
-- =====================================================================

-- Verify events table structure:
-- SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name = 'events' ORDER BY ordinal_position;

-- Verify notifications table exists:
-- SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename = 'notifications';

-- Verify user_roles table exists:
-- SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename = 'user_roles';

-- Verify is_moderator() function exists:
-- SELECT proname FROM pg_proc WHERE proname = 'is_moderator';

-- Verify new RLS policies exist (should be 21 total):
-- SELECT tablename, policyname FROM pg_policies WHERE tablename IN ('events', 'notifications', 'user_roles') ORDER BY tablename, policyname;

-- =====================================================================
-- END OF MIGRATION
-- =====================================================================
