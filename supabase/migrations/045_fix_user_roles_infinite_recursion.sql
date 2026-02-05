-- Migration: 045_fix_user_roles_infinite_recursion
-- Purpose: Fix infinite recursion in user_roles RLS policies (PostgreSQL error 42P17)
-- Date: 2026-02-05
-- Problem: The "Admins can manage roles" policy queries user_roles from within
--          a policy on user_roles, causing infinite recursion when evaluated.
-- Solution: Create a SECURITY DEFINER function that bypasses RLS to check admin status.

-- ============================================================================
-- STEP 1: Create SECURITY DEFINER function to check admin status
-- This function bypasses RLS, avoiding the recursion problem
-- ============================================================================

CREATE OR REPLACE FUNCTION is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  );
$$;

COMMENT ON FUNCTION is_admin() IS 'Check if current user is admin. SECURITY DEFINER to bypass RLS and avoid infinite recursion.';

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION is_admin() TO authenticated;

-- ============================================================================
-- STEP 2: Create helper function for moderator check (also needed elsewhere)
-- ============================================================================

CREATE OR REPLACE FUNCTION is_moderator_or_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role IN ('moderator', 'admin')
  );
$$;

COMMENT ON FUNCTION is_moderator_or_admin() IS 'Check if current user is moderator or admin. SECURITY DEFINER to bypass RLS.';

GRANT EXECUTE ON FUNCTION is_moderator_or_admin() TO authenticated;

-- ============================================================================
-- STEP 3: Fix user_roles policies using the new functions
-- ============================================================================

-- Drop all existing policies on user_roles to start fresh
DROP POLICY IF EXISTS "admins_manage_roles" ON user_roles;
DROP POLICY IF EXISTS "Admins can manage roles" ON user_roles;
DROP POLICY IF EXISTS "users_view_own_roles" ON user_roles;
DROP POLICY IF EXISTS "Users can view own roles" ON user_roles;

-- Policy 1: Users can view their own roles (simple, no recursion risk)
CREATE POLICY "Users can view own roles"
  ON user_roles FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- Policy 2: Admins can manage all roles (uses SECURITY DEFINER function to avoid recursion)
CREATE POLICY "Admins can manage roles"
  ON user_roles FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

COMMENT ON POLICY "Users can view own roles" ON user_roles IS 'All users can read their own role (needed for role-based UI)';
COMMENT ON POLICY "Admins can manage roles" ON user_roles IS 'Only admins can INSERT/UPDATE/DELETE role assignments. Uses is_admin() to avoid infinite recursion.';

-- ============================================================================
-- STEP 4: Update other policies that reference user_roles to use the new functions
-- ============================================================================

-- EVENTS TABLE
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'events') THEN
    DROP POLICY IF EXISTS "Moderators see all events" ON events;
    CREATE POLICY "Moderators see all events"
      ON events FOR SELECT
      TO authenticated
      USING (is_moderator_or_admin());

    DROP POLICY IF EXISTS "Moderators can moderate events" ON events;
    CREATE POLICY "Moderators can moderate events"
      ON events FOR UPDATE
      TO authenticated
      USING (
        is_moderator_or_admin()
        AND creator_id != (SELECT auth.uid())
        AND status = 'pending'
      )
      WITH CHECK (
        is_moderator_or_admin()
        AND creator_id != (SELECT auth.uid())
        AND status IN ('approved', 'rejected')
      );
    RAISE NOTICE 'Fixed events policies';
  END IF;
END $$;

-- CHAT_MESSAGES TABLE
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'chat_messages') THEN
    DROP POLICY IF EXISTS "chat_messages_select_moderators" ON chat_messages;
    CREATE POLICY "chat_messages_select_moderators"
      ON chat_messages FOR SELECT
      TO authenticated
      USING (is_moderator_or_admin());

    DROP POLICY IF EXISTS "chat_messages_update_moderators" ON chat_messages;
    CREATE POLICY "chat_messages_update_moderators"
      ON chat_messages FOR UPDATE
      TO authenticated
      USING (is_moderator_or_admin())
      WITH CHECK (is_moderator_or_admin());
    RAISE NOTICE 'Fixed chat_messages policies';
  END IF;
END $$;

-- CHAT_REPORTS TABLE
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'chat_reports') THEN
    DROP POLICY IF EXISTS "chat_reports_select_moderators" ON chat_reports;
    CREATE POLICY "chat_reports_select_moderators"
      ON chat_reports FOR SELECT
      TO authenticated
      USING (is_moderator_or_admin());

    DROP POLICY IF EXISTS "chat_reports_update_moderators" ON chat_reports;
    CREATE POLICY "chat_reports_update_moderators"
      ON chat_reports FOR UPDATE
      TO authenticated
      USING (is_moderator_or_admin());
    RAISE NOTICE 'Fixed chat_reports policies';
  END IF;
END $$;

-- MODERATION_LOG TABLE
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'moderation_log') THEN
    DROP POLICY IF EXISTS "Moderators can view logs" ON moderation_log;
    CREATE POLICY "Moderators can view logs"
      ON moderation_log FOR SELECT
      TO authenticated
      USING (is_moderator_or_admin());
    RAISE NOTICE 'Fixed moderation_log policies';
  END IF;
END $$;

-- ADMIN_LOG TABLE
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'admin_log') THEN
    DROP POLICY IF EXISTS "Admins can view admin logs" ON admin_log;
    CREATE POLICY "Admins can view admin logs"
      ON admin_log FOR SELECT
      TO authenticated
      USING (is_admin());
    RAISE NOTICE 'Fixed admin_log policies';
  END IF;
END $$;

-- ROLE_HISTORY TABLE
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'role_history') THEN
    DROP POLICY IF EXISTS "Admins can view role history" ON role_history;
    CREATE POLICY "Admins can view role history"
      ON role_history FOR SELECT
      TO authenticated
      USING (is_admin());
    RAISE NOTICE 'Fixed role_history policies';
  END IF;
END $$;

-- MODERATOR_STATS TABLE
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'moderator_stats') THEN
    DROP POLICY IF EXISTS "Moderators can view own stats" ON moderator_stats;
    CREATE POLICY "Moderators can view own stats"
      ON moderator_stats FOR SELECT
      TO authenticated
      USING (
        user_id = (SELECT auth.uid())
        AND is_moderator_or_admin()
      );

    DROP POLICY IF EXISTS "Admins can view all stats" ON moderator_stats;
    CREATE POLICY "Admins can view all stats"
      ON moderator_stats FOR SELECT
      TO authenticated
      USING (is_admin());
    RAISE NOTICE 'Fixed moderator_stats policies';
  END IF;
END $$;

-- MODERATOR_STATS_ARCHIVE TABLE
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'moderator_stats_archive') THEN
    DROP POLICY IF EXISTS "Admins can view archived stats" ON moderator_stats_archive;
    CREATE POLICY "Admins can view archived stats"
      ON moderator_stats_archive FOR SELECT
      TO authenticated
      USING (is_admin());
    RAISE NOTICE 'Fixed moderator_stats_archive policies';
  END IF;
END $$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
BEGIN
  -- Verify the functions exist and are SECURITY DEFINER
  IF EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname = 'is_admin'
      AND p.prosecdef = true
  ) THEN
    RAISE NOTICE '✓ is_admin() function created with SECURITY DEFINER';
  ELSE
    RAISE EXCEPTION 'is_admin() function not found or not SECURITY DEFINER';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname = 'is_moderator_or_admin'
      AND p.prosecdef = true
  ) THEN
    RAISE NOTICE '✓ is_moderator_or_admin() function created with SECURITY DEFINER';
  ELSE
    RAISE EXCEPTION 'is_moderator_or_admin() function not found or not SECURITY DEFINER';
  END IF;

  RAISE NOTICE '========================================';
  RAISE NOTICE 'Migration 045 complete: Fixed infinite recursion in user_roles RLS';
  RAISE NOTICE '  - Created is_admin() SECURITY DEFINER function';
  RAISE NOTICE '  - Created is_moderator_or_admin() SECURITY DEFINER function';
  RAISE NOTICE '  - Updated all policies to use these functions';
  RAISE NOTICE '========================================';
END $$;
