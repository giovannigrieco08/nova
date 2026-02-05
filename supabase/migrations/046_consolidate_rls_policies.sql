-- Migration: 046_consolidate_rls_policies
-- Purpose: Fix remaining auth_rls_initplan warning and consolidate multiple permissive policies
-- Date: 2026-02-05
--
-- Problem 1: chat_messages_soft_delete_own uses auth.uid() without subquery wrapper
-- Problem 2: Multiple permissive policies for same role/action cause performance issues
--            Each policy must be evaluated for every query, even though only one needs to match.
--
-- Solution: Consolidate multiple permissive policies into single combined policies using OR conditions
--
-- Reference: https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies

-- ============================================================================
-- CHAT_MESSAGES TABLE
-- Consolidate SELECT and UPDATE policies
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'chat_messages') THEN
    -- Drop all existing SELECT policies
    DROP POLICY IF EXISTS "chat_messages_select_moderators" ON chat_messages;
    DROP POLICY IF EXISTS "chat_messages_select_visible" ON chat_messages;

    -- Create single consolidated SELECT policy
    CREATE POLICY "chat_messages_select"
      ON chat_messages FOR SELECT
      TO authenticated
      USING (
        -- Visible messages (not hidden)
        hidden_at IS NULL
        OR
        -- Moderators/admins can see all including hidden
        is_moderator_or_admin()
      );

    -- Drop all existing UPDATE policies
    DROP POLICY IF EXISTS "chat_messages_soft_delete_own" ON chat_messages;
    DROP POLICY IF EXISTS "chat_messages_update_moderators" ON chat_messages;

    -- Create single consolidated UPDATE policy
    CREATE POLICY "chat_messages_update"
      ON chat_messages FOR UPDATE
      TO authenticated
      USING (
        -- Users can soft-delete their own messages
        user_id = (SELECT auth.uid())
        OR
        -- Moderators can update any message (hide/unhide)
        is_moderator_or_admin()
      )
      WITH CHECK (
        -- Users can only soft-delete (set deleted_at)
        user_id = (SELECT auth.uid())
        OR
        -- Moderators can make any update
        is_moderator_or_admin()
      );

    RAISE NOTICE 'Consolidated chat_messages policies';
  END IF;
END $$;

-- ============================================================================
-- CHAT_REPORTS TABLE
-- Consolidate SELECT policies
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'chat_reports') THEN
    -- Drop all existing SELECT policies
    DROP POLICY IF EXISTS "chat_reports_select_moderators" ON chat_reports;
    DROP POLICY IF EXISTS "chat_reports_select_own" ON chat_reports;

    -- Create single consolidated SELECT policy
    CREATE POLICY "chat_reports_select"
      ON chat_reports FOR SELECT
      TO authenticated
      USING (
        -- Users can see their own reports
        reporter_user_id = (SELECT auth.uid())
        OR
        -- Moderators can see all reports
        is_moderator_or_admin()
      );

    RAISE NOTICE 'Consolidated chat_reports policies';
  END IF;
END $$;

-- ============================================================================
-- EVENT_HELP_OFFERS TABLE
-- Consolidate UPDATE policies
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'event_help_offers') THEN
    -- Drop all existing UPDATE policies
    DROP POLICY IF EXISTS "Event creators can update offer status" ON event_help_offers;
    DROP POLICY IF EXISTS "Users can update their own offers" ON event_help_offers;

    -- Create single consolidated UPDATE policy
    CREATE POLICY "event_help_offers_update"
      ON event_help_offers FOR UPDATE
      TO authenticated
      USING (
        -- Users can update their own offers
        user_id = (SELECT auth.uid())
        OR
        -- Event creators can update offers for their requests
        EXISTS (
          SELECT 1 FROM event_help_requests hr
          JOIN events e ON e.id = hr.event_id
          WHERE hr.id = event_help_offers.request_id
          AND e.creator_id = (SELECT auth.uid())
        )
      );

    RAISE NOTICE 'Consolidated event_help_offers policies';
  END IF;
END $$;

-- ============================================================================
-- EVENT_REPORTS TABLE
-- Consolidate SELECT policies
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'event_reports') THEN
    -- Drop all existing SELECT policies
    DROP POLICY IF EXISTS "Moderators can view all reports" ON event_reports;
    DROP POLICY IF EXISTS "Users can view their own reports" ON event_reports;

    -- Create single consolidated SELECT policy
    CREATE POLICY "event_reports_select"
      ON event_reports FOR SELECT
      TO authenticated
      USING (
        -- Users can see their own reports
        reporter_id = (SELECT auth.uid())
        OR
        -- Moderators can see all reports
        is_moderator_or_admin()
      );

    RAISE NOTICE 'Consolidated event_reports policies';
  END IF;
END $$;

-- ============================================================================
-- EVENTS TABLE
-- Consolidate SELECT, INSERT, and UPDATE policies
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'events') THEN
    -- Drop all existing SELECT policies
    DROP POLICY IF EXISTS "Moderators see all events" ON events;
    DROP POLICY IF EXISTS "Students see approved events" ON events;
    DROP POLICY IF EXISTS "coorganizers_view_events" ON events;
    DROP POLICY IF EXISTS "creators_view_own_events" ON events;
    DROP POLICY IF EXISTS "moderators_view_all_events" ON events;
    DROP POLICY IF EXISTS "users_view_approved_upcoming_events" ON events;
    DROP POLICY IF EXISTS "users_view_own_events" ON events;
    DROP POLICY IF EXISTS "users_view_participating_events" ON events;

    -- Create single consolidated SELECT policy
    CREATE POLICY "events_select"
      ON events FOR SELECT
      TO authenticated
      USING (
        -- Approved events visible to everyone
        status = 'approved'
        OR
        -- Creators can see their own events (any status)
        creator_id = (SELECT auth.uid())
        OR
        -- Co-organizers can see events they co-organize
        (SELECT auth.uid()) = ANY(co_organizers)
        OR
        -- Moderators can see all events
        is_moderator_or_admin()
      );

    -- Drop all existing INSERT policies
    DROP POLICY IF EXISTS "Students can create events" ON events;
    DROP POLICY IF EXISTS "users_create_events" ON events;

    -- Create single consolidated INSERT policy
    CREATE POLICY "events_insert"
      ON events FOR INSERT
      TO authenticated
      WITH CHECK (
        creator_id = (SELECT auth.uid())
        AND status = 'pending'
      );

    -- Drop all existing UPDATE policies
    DROP POLICY IF EXISTS "Creators can update rejected events" ON events;
    DROP POLICY IF EXISTS "Moderators can moderate events" ON events;
    DROP POLICY IF EXISTS "coorganizers_update_events" ON events;
    DROP POLICY IF EXISTS "moderators_update_event_status" ON events;
    DROP POLICY IF EXISTS "users_update_own_events" ON events;

    -- Create single consolidated UPDATE policy
    CREATE POLICY "events_update"
      ON events FOR UPDATE
      TO authenticated
      USING (
        -- Creators can update their own events (with restrictions in WITH CHECK)
        creator_id = (SELECT auth.uid())
        OR
        -- Co-organizers can update events they co-organize
        (SELECT auth.uid()) = ANY(co_organizers)
        OR
        -- Moderators can moderate events
        (is_moderator_or_admin() AND creator_id != (SELECT auth.uid()))
      )
      WITH CHECK (
        -- Creators updating rejected events must reset to pending
        (creator_id = (SELECT auth.uid()) AND (status IN ('pending', 'rejected') OR status = 'pending'))
        OR
        -- Co-organizers can update
        (SELECT auth.uid()) = ANY(co_organizers)
        OR
        -- Moderators can approve/reject
        (is_moderator_or_admin() AND creator_id != (SELECT auth.uid()))
      );

    RAISE NOTICE 'Consolidated events policies';
  END IF;
END $$;

-- ============================================================================
-- NOTIFICATIONS TABLE
-- Consolidate SELECT and UPDATE policies
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notifications') THEN
    -- Drop all existing SELECT policies
    DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
    DROP POLICY IF EXISTS "users_view_own_notifications" ON notifications;

    -- Create single consolidated SELECT policy
    CREATE POLICY "notifications_select"
      ON notifications FOR SELECT
      TO authenticated
      USING (recipient_id = (SELECT auth.uid()));

    -- Drop all existing UPDATE policies
    DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
    DROP POLICY IF EXISTS "users_update_own_notifications" ON notifications;

    -- Create single consolidated UPDATE policy
    CREATE POLICY "notifications_update"
      ON notifications FOR UPDATE
      TO authenticated
      USING (recipient_id = (SELECT auth.uid()))
      WITH CHECK (recipient_id = (SELECT auth.uid()));

    RAISE NOTICE 'Consolidated notifications policies';
  END IF;
END $$;

-- ============================================================================
-- PROFILES TABLE
-- Consolidate SELECT and UPDATE policies
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
    -- Drop all existing SELECT policies
    DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;
    DROP POLICY IF EXISTS "Students can read visible profiles" ON profiles;
    DROP POLICY IF EXISTS "Users can read own profile" ON profiles;
    DROP POLICY IF EXISTS "Users can view own profile" ON profiles;

    -- Create single consolidated SELECT policy
    CREATE POLICY "profiles_select"
      ON profiles FOR SELECT
      TO authenticated
      USING (
        -- Users can always see their own profile
        user_id = (SELECT auth.uid())
        OR
        -- Students can see visible, non-deleted profiles
        (
          (SELECT auth.email()) LIKE '%@galileimoro.edu.it'
          AND profile_visible = TRUE
          AND deleted_at IS NULL
        )
      );

    -- Drop all existing UPDATE policies
    DROP POLICY IF EXISTS "Users can soft delete own account" ON profiles;
    DROP POLICY IF EXISTS "Users can update own profile" ON profiles;

    -- Create single consolidated UPDATE policy
    CREATE POLICY "profiles_update"
      ON profiles FOR UPDATE
      TO authenticated
      USING (user_id = (SELECT auth.uid()))
      WITH CHECK (user_id = (SELECT auth.uid()));

    RAISE NOTICE 'Consolidated profiles policies';
  END IF;
END $$;

-- ============================================================================
-- TUTOR_PROFILES TABLE
-- Consolidate SELECT policies
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'tutor_profiles') THEN
    -- Drop all existing SELECT policies
    DROP POLICY IF EXISTS "read_active_tutors" ON tutor_profiles;
    DROP POLICY IF EXISTS "read_own_tutor_profile" ON tutor_profiles;

    -- Create single consolidated SELECT policy
    CREATE POLICY "tutor_profiles_select"
      ON tutor_profiles FOR SELECT
      TO authenticated
      USING (
        -- Users can see their own profile (even if inactive)
        user_id = (SELECT auth.uid())
        OR
        -- Anyone can see active tutor profiles
        is_active = TRUE
      );

    RAISE NOTICE 'Consolidated tutor_profiles policies';
  END IF;
END $$;

-- ============================================================================
-- USER_ROLES TABLE
-- The "Admins can manage roles" is a FOR ALL policy which includes SELECT
-- We need to make sure it doesn't conflict with "Users can view own roles"
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_roles') THEN
    -- Drop existing policies
    DROP POLICY IF EXISTS "Admins can manage roles" ON user_roles;
    DROP POLICY IF EXISTS "Users can view own roles" ON user_roles;

    -- Create separate policies for each operation to avoid overlap

    -- SELECT: Users see their own roles OR admins see all
    CREATE POLICY "user_roles_select"
      ON user_roles FOR SELECT
      TO authenticated
      USING (
        user_id = (SELECT auth.uid())
        OR
        is_admin()
      );

    -- INSERT: Only admins
    CREATE POLICY "user_roles_insert"
      ON user_roles FOR INSERT
      TO authenticated
      WITH CHECK (is_admin());

    -- UPDATE: Only admins
    CREATE POLICY "user_roles_update"
      ON user_roles FOR UPDATE
      TO authenticated
      USING (is_admin())
      WITH CHECK (is_admin());

    -- DELETE: Only admins
    CREATE POLICY "user_roles_delete"
      ON user_roles FOR DELETE
      TO authenticated
      USING (is_admin());

    RAISE NOTICE 'Consolidated user_roles policies';
  END IF;
END $$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
  warning_count INTEGER;
BEGIN
  -- Check for remaining multiple permissive policies on key tables
  SELECT COUNT(DISTINCT tablename) INTO warning_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename IN ('chat_messages', 'chat_reports', 'event_help_offers', 'event_reports',
                      'events', 'notifications', 'profiles', 'tutor_profiles', 'user_roles')
  GROUP BY tablename, cmd
  HAVING COUNT(*) > 1;

  RAISE NOTICE '========================================';
  RAISE NOTICE 'Migration 046_consolidate_rls_policies completed';
  RAISE NOTICE '  - Consolidated chat_messages SELECT and UPDATE policies';
  RAISE NOTICE '  - Consolidated chat_reports SELECT policies';
  RAISE NOTICE '  - Consolidated event_help_offers UPDATE policies';
  RAISE NOTICE '  - Consolidated event_reports SELECT policies';
  RAISE NOTICE '  - Consolidated events SELECT, INSERT, and UPDATE policies';
  RAISE NOTICE '  - Consolidated notifications SELECT and UPDATE policies';
  RAISE NOTICE '  - Consolidated profiles SELECT and UPDATE policies';
  RAISE NOTICE '  - Consolidated tutor_profiles SELECT policies';
  RAISE NOTICE '  - Split user_roles into separate operation policies';
  RAISE NOTICE '========================================';
END $$;
