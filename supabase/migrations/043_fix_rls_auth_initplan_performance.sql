-- Migration: 043_fix_rls_auth_initplan_performance
-- Description: Fix RLS policies to wrap auth.uid() and auth.email() in subqueries
--              to prevent re-evaluation for each row (Supabase linter warning 0003)
-- Date: 2026-02-05
--
-- Problem: Direct calls to auth.uid(), auth.email(), auth.jwt() in RLS policies
--          are re-evaluated for each row, causing performance degradation at scale.
--
-- Solution: Wrap auth functions in SELECT subqueries: (SELECT auth.uid())
--           This evaluates once per query instead of once per row.
--
-- Reference: https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan
--
-- NOTE: This migration checks if each table exists before modifying policies,
--       making it safe to run even if some tables haven't been created yet.

-- ============================================================================
-- AUTH_EVENTS TABLE
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'auth_events') THEN
    DROP POLICY IF EXISTS "Users can read own events" ON auth_events;
    CREATE POLICY "Users can read own events"
      ON auth_events FOR SELECT
      TO authenticated
      USING (user_id = (SELECT auth.uid()));
    RAISE NOTICE 'Fixed auth_events policies';
  END IF;
END $$;

-- ============================================================================
-- PROFILES TABLE
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
    DROP POLICY IF EXISTS "Users can read own profile" ON profiles;
    CREATE POLICY "Users can read own profile"
      ON profiles FOR SELECT
      USING ((SELECT auth.uid()) = user_id);

    DROP POLICY IF EXISTS "Students can read verified profiles" ON profiles;
    -- Note: This policy is superseded by "Students can read visible profiles" in migration 035

    DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
    CREATE POLICY "Users can insert own profile"
      ON profiles FOR INSERT
      WITH CHECK ((SELECT auth.uid()) = user_id);

    DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
    CREATE POLICY "Users can update own profile"
      ON profiles FOR UPDATE
      USING ((SELECT auth.uid()) = user_id)
      WITH CHECK ((SELECT auth.uid()) = user_id);

    DROP POLICY IF EXISTS "Users can delete own profile" ON profiles;
    CREATE POLICY "Users can delete own profile"
      ON profiles FOR DELETE
      USING ((SELECT auth.uid()) = user_id);

    DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
    CREATE POLICY "Users can view own profile"
      ON profiles FOR SELECT
      USING ((SELECT auth.uid()) = user_id);

    DROP POLICY IF EXISTS "Users can soft delete own account" ON profiles;
    CREATE POLICY "Users can soft delete own account"
      ON profiles FOR UPDATE
      USING ((SELECT auth.uid()) = user_id)
      WITH CHECK ((SELECT auth.uid()) = user_id);

    DROP POLICY IF EXISTS "Students can read visible profiles" ON profiles;
    CREATE POLICY "Students can read visible profiles"
      ON profiles FOR SELECT
      USING (
        (SELECT auth.email()) LIKE '%@galileimoro.edu.it'
        AND (
          (SELECT auth.uid()) = user_id
          OR (
            profile_visible = TRUE
            AND deleted_at IS NULL
          )
        )
      );
    RAISE NOTICE 'Fixed profiles policies';
  END IF;
END $$;

-- ============================================================================
-- USER_ROLES TABLE
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_roles') THEN
    DROP POLICY IF EXISTS "admins_manage_roles" ON user_roles;
    DROP POLICY IF EXISTS "Admins can manage roles" ON user_roles;
    CREATE POLICY "Admins can manage roles"
      ON user_roles FOR ALL
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM user_roles ur
          WHERE ur.user_id = (SELECT auth.uid()) AND ur.role = 'admin'
        )
      )
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM user_roles ur
          WHERE ur.user_id = (SELECT auth.uid()) AND ur.role = 'admin'
        )
      );

    DROP POLICY IF EXISTS "Users can view own roles" ON user_roles;
    CREATE POLICY "Users can view own roles"
      ON user_roles FOR SELECT
      TO authenticated
      USING (user_id = (SELECT auth.uid()));
    RAISE NOTICE 'Fixed user_roles policies';
  END IF;
END $$;

-- ============================================================================
-- TUTOR_PROFILES TABLE
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'tutor_profiles') THEN
    DROP POLICY IF EXISTS "read_own_tutor_profile" ON tutor_profiles;
    CREATE POLICY "read_own_tutor_profile"
      ON tutor_profiles FOR SELECT
      USING ((SELECT auth.uid()) = user_id);

    DROP POLICY IF EXISTS "insert_own_tutor_profile" ON tutor_profiles;
    CREATE POLICY "insert_own_tutor_profile"
      ON tutor_profiles FOR INSERT
      WITH CHECK ((SELECT auth.uid()) = user_id);

    DROP POLICY IF EXISTS "update_own_tutor_profile" ON tutor_profiles;
    CREATE POLICY "update_own_tutor_profile"
      ON tutor_profiles FOR UPDATE
      USING ((SELECT auth.uid()) = user_id);

    DROP POLICY IF EXISTS "delete_own_tutor_profile" ON tutor_profiles;
    CREATE POLICY "delete_own_tutor_profile"
      ON tutor_profiles FOR DELETE
      USING ((SELECT auth.uid()) = user_id);
    RAISE NOTICE 'Fixed tutor_profiles policies';
  END IF;
END $$;

-- ============================================================================
-- FCM_TOKENS TABLE
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'fcm_tokens') THEN
    DROP POLICY IF EXISTS "Users can view own fcm_tokens" ON fcm_tokens;
    CREATE POLICY "Users can view own fcm_tokens"
      ON fcm_tokens FOR SELECT
      USING ((SELECT auth.uid()) = user_id);

    DROP POLICY IF EXISTS "Users can insert own fcm_tokens" ON fcm_tokens;
    CREATE POLICY "Users can insert own fcm_tokens"
      ON fcm_tokens FOR INSERT
      WITH CHECK ((SELECT auth.uid()) = user_id);

    DROP POLICY IF EXISTS "Users can update own fcm_tokens" ON fcm_tokens;
    CREATE POLICY "Users can update own fcm_tokens"
      ON fcm_tokens FOR UPDATE
      USING ((SELECT auth.uid()) = user_id)
      WITH CHECK ((SELECT auth.uid()) = user_id);

    DROP POLICY IF EXISTS "Users can delete own fcm_tokens" ON fcm_tokens;
    CREATE POLICY "Users can delete own fcm_tokens"
      ON fcm_tokens FOR DELETE
      USING ((SELECT auth.uid()) = user_id);
    RAISE NOTICE 'Fixed fcm_tokens policies';
  END IF;
END $$;

-- ============================================================================
-- NOTIFICATIONS TABLE
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notifications') THEN
    DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
    CREATE POLICY "Users can view own notifications"
      ON notifications FOR SELECT
      USING ((SELECT auth.uid()) = recipient_id);

    DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
    CREATE POLICY "Users can update own notifications"
      ON notifications FOR UPDATE
      USING ((SELECT auth.uid()) = recipient_id)
      WITH CHECK ((SELECT auth.uid()) = recipient_id);

    DROP POLICY IF EXISTS "Users can delete own notifications" ON notifications;
    CREATE POLICY "Users can delete own notifications"
      ON notifications FOR DELETE
      USING ((SELECT auth.uid()) = recipient_id);
    RAISE NOTICE 'Fixed notifications policies';
  END IF;
END $$;

-- ============================================================================
-- CHAT_MEDIA TABLE
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'chat_media') THEN
    DROP POLICY IF EXISTS "Users can view media" ON chat_media;
    DROP POLICY IF EXISTS "chat_media_select_visible" ON chat_media;
    CREATE POLICY "chat_media_select_visible"
      ON chat_media FOR SELECT
      TO authenticated
      USING (
        message_id IN (
          SELECT id FROM chat_messages WHERE hidden_at IS NULL
        )
      );

    DROP POLICY IF EXISTS "Users can insert own media" ON chat_media;
    DROP POLICY IF EXISTS "chat_media_insert_own" ON chat_media;
    CREATE POLICY "chat_media_insert_own"
      ON chat_media FOR INSERT
      TO authenticated
      WITH CHECK ((SELECT auth.uid()) = uploader_user_id);

    DROP POLICY IF EXISTS "chat_media_update_viewed" ON chat_media;
    CREATE POLICY "chat_media_update_viewed"
      ON chat_media FOR UPDATE
      TO authenticated
      USING (
        is_viewed = FALSE
        AND (SELECT auth.uid()) != uploader_user_id
      )
      WITH CHECK (
        is_viewed = TRUE
        AND viewed_by_user_id = (SELECT auth.uid())
      );
    RAISE NOTICE 'Fixed chat_media policies';
  END IF;
END $$;

-- ============================================================================
-- EVENT_INVITATIONS TABLE
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'event_invitations') THEN
    DROP POLICY IF EXISTS "Users can create invitations" ON event_invitations;
    CREATE POLICY "Users can create invitations"
      ON event_invitations FOR INSERT
      WITH CHECK ((SELECT auth.uid()) = inviter_id);

    DROP POLICY IF EXISTS "Users can view their invitations" ON event_invitations;
    CREATE POLICY "Users can view their invitations"
      ON event_invitations FOR SELECT
      USING ((SELECT auth.uid()) = inviter_id OR (SELECT auth.uid()) = invitee_id);

    DROP POLICY IF EXISTS "Invitees can respond to invitations" ON event_invitations;
    CREATE POLICY "Invitees can respond to invitations"
      ON event_invitations FOR UPDATE
      USING ((SELECT auth.uid()) = invitee_id)
      WITH CHECK ((SELECT auth.uid()) = invitee_id);

    DROP POLICY IF EXISTS "Inviters can cancel pending invitations" ON event_invitations;
    CREATE POLICY "Inviters can cancel pending invitations"
      ON event_invitations FOR DELETE
      USING ((SELECT auth.uid()) = inviter_id AND status = 'pending');
    RAISE NOTICE 'Fixed event_invitations policies';
  END IF;
END $$;

-- ============================================================================
-- EVENT_HELP_REQUESTS TABLE
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'event_help_requests') THEN
    DROP POLICY IF EXISTS "Event creators can insert help requests" ON event_help_requests;
    CREATE POLICY "Event creators can insert help requests"
      ON event_help_requests FOR INSERT
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM events
          WHERE events.id = event_help_requests.event_id
          AND events.creator_id = (SELECT auth.uid())
        )
      );

    DROP POLICY IF EXISTS "Event creators can update help requests" ON event_help_requests;
    CREATE POLICY "Event creators can update help requests"
      ON event_help_requests FOR UPDATE
      USING (
        EXISTS (
          SELECT 1 FROM events
          WHERE events.id = event_help_requests.event_id
          AND events.creator_id = (SELECT auth.uid())
        )
      );

    DROP POLICY IF EXISTS "Event creators can delete help requests" ON event_help_requests;
    CREATE POLICY "Event creators can delete help requests"
      ON event_help_requests FOR DELETE
      USING (
        EXISTS (
          SELECT 1 FROM events
          WHERE events.id = event_help_requests.event_id
          AND events.creator_id = (SELECT auth.uid())
        )
      );
    RAISE NOTICE 'Fixed event_help_requests policies';
  END IF;
END $$;

-- ============================================================================
-- EVENT_HELP_OFFERS TABLE
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'event_help_offers') THEN
    DROP POLICY IF EXISTS "Event creators can view offers for their requests" ON event_help_offers;
    CREATE POLICY "Event creators can view offers for their requests"
      ON event_help_offers FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM event_help_requests hr
          JOIN events e ON e.id = hr.event_id
          WHERE hr.id = event_help_offers.request_id
          AND e.creator_id = (SELECT auth.uid())
        )
        OR user_id = (SELECT auth.uid())
      );

    DROP POLICY IF EXISTS "Authenticated users can make offers" ON event_help_offers;
    CREATE POLICY "Authenticated users can make offers"
      ON event_help_offers FOR INSERT
      WITH CHECK (
        (SELECT auth.uid()) = user_id
        AND EXISTS (
          SELECT 1 FROM event_help_requests hr
          JOIN events e ON e.id = hr.event_id
          WHERE hr.id = event_help_offers.request_id
          AND e.status = 'approved'
          AND hr.is_fulfilled = FALSE
        )
      );

    DROP POLICY IF EXISTS "Users can update their own offers" ON event_help_offers;
    CREATE POLICY "Users can update their own offers"
      ON event_help_offers FOR UPDATE
      USING (user_id = (SELECT auth.uid()));

    DROP POLICY IF EXISTS "Event creators can update offer status" ON event_help_offers;
    CREATE POLICY "Event creators can update offer status"
      ON event_help_offers FOR UPDATE
      USING (
        EXISTS (
          SELECT 1 FROM event_help_requests hr
          JOIN events e ON e.id = hr.event_id
          WHERE hr.id = event_help_offers.request_id
          AND e.creator_id = (SELECT auth.uid())
        )
      );

    DROP POLICY IF EXISTS "Users can delete their own offers" ON event_help_offers;
    CREATE POLICY "Users can delete their own offers"
      ON event_help_offers FOR DELETE
      USING (user_id = (SELECT auth.uid()));
    RAISE NOTICE 'Fixed event_help_offers policies';
  END IF;
END $$;

-- ============================================================================
-- CHAT_MESSAGES TABLE
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'chat_messages') THEN
    DROP POLICY IF EXISTS "chat_messages_select_moderators" ON chat_messages;
    CREATE POLICY "chat_messages_select_moderators"
      ON chat_messages FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM user_roles
          WHERE user_roles.user_id = (SELECT auth.uid())
            AND role IN ('moderator', 'admin')
        )
      );

    DROP POLICY IF EXISTS "chat_messages_insert_own" ON chat_messages;
    CREATE POLICY "chat_messages_insert_own"
      ON chat_messages FOR INSERT
      TO authenticated
      WITH CHECK (
        (SELECT auth.uid()) = user_id
        AND hidden_at IS NULL
      );

    DROP POLICY IF EXISTS "chat_messages_update_moderators" ON chat_messages;
    CREATE POLICY "chat_messages_update_moderators"
      ON chat_messages FOR UPDATE
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM user_roles
          WHERE user_roles.user_id = (SELECT auth.uid())
            AND role IN ('moderator', 'admin')
        )
      )
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM user_roles
          WHERE user_roles.user_id = (SELECT auth.uid())
            AND role IN ('moderator', 'admin')
        )
      );
    RAISE NOTICE 'Fixed chat_messages policies';
  END IF;
END $$;

-- ============================================================================
-- EVENT_REPORTS TABLE
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'event_reports') THEN
    DROP POLICY IF EXISTS "Users can create reports" ON event_reports;
    CREATE POLICY "Users can create reports"
      ON event_reports FOR INSERT
      WITH CHECK ((SELECT auth.uid()) = reporter_id);

    DROP POLICY IF EXISTS "Users can view their own reports" ON event_reports;
    CREATE POLICY "Users can view their own reports"
      ON event_reports FOR SELECT
      USING ((SELECT auth.uid()) = reporter_id);
    RAISE NOTICE 'Fixed event_reports policies';
  END IF;
END $$;

-- ============================================================================
-- CHAT_REACTIONS TABLE
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'chat_reactions') THEN
    DROP POLICY IF EXISTS "chat_reactions_insert_own" ON chat_reactions;
    CREATE POLICY "chat_reactions_insert_own"
      ON chat_reactions FOR INSERT
      TO authenticated
      WITH CHECK ((SELECT auth.uid()) = user_id);

    DROP POLICY IF EXISTS "chat_reactions_delete_own" ON chat_reactions;
    CREATE POLICY "chat_reactions_delete_own"
      ON chat_reactions FOR DELETE
      TO authenticated
      USING ((SELECT auth.uid()) = user_id);
    RAISE NOTICE 'Fixed chat_reactions policies';
  END IF;
END $$;

-- ============================================================================
-- CHAT_REPORTS TABLE
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'chat_reports') THEN
    DROP POLICY IF EXISTS "chat_reports_select_own" ON chat_reports;
    CREATE POLICY "chat_reports_select_own"
      ON chat_reports FOR SELECT
      TO authenticated
      USING ((SELECT auth.uid()) = reporter_user_id);

    DROP POLICY IF EXISTS "chat_reports_select_moderators" ON chat_reports;
    CREATE POLICY "chat_reports_select_moderators"
      ON chat_reports FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM user_roles
          WHERE user_roles.user_id = (SELECT auth.uid())
            AND role IN ('moderator', 'admin')
        )
      );

    DROP POLICY IF EXISTS "chat_reports_insert_own" ON chat_reports;
    CREATE POLICY "chat_reports_insert_own"
      ON chat_reports FOR INSERT
      TO authenticated
      WITH CHECK (
        (SELECT auth.uid()) = reporter_user_id
        AND status = 'pending'
      );

    DROP POLICY IF EXISTS "chat_reports_update_moderators" ON chat_reports;
    CREATE POLICY "chat_reports_update_moderators"
      ON chat_reports FOR UPDATE
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM user_roles
          WHERE user_roles.user_id = (SELECT auth.uid())
            AND role IN ('moderator', 'admin')
        )
      );
    RAISE NOTICE 'Fixed chat_reports policies';
  END IF;
END $$;

-- ============================================================================
-- EVENTS TABLE (Policies from moderation system)
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'events') THEN
    DROP POLICY IF EXISTS "Students see approved events" ON events;
    CREATE POLICY "Students see approved events"
      ON events FOR SELECT
      TO authenticated
      USING (
        status = 'approved'
        OR creator_id = (SELECT auth.uid())
      );

    DROP POLICY IF EXISTS "Moderators see all events" ON events;
    CREATE POLICY "Moderators see all events"
      ON events FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM user_roles
          WHERE user_id = (SELECT auth.uid()) AND role IN ('moderator', 'admin')
        )
      );

    DROP POLICY IF EXISTS "Students can create events" ON events;
    CREATE POLICY "Students can create events"
      ON events FOR INSERT
      TO authenticated
      WITH CHECK (
        creator_id = (SELECT auth.uid())
        AND status = 'pending'
      );

    DROP POLICY IF EXISTS "Creators can update rejected events" ON events;
    CREATE POLICY "Creators can update rejected events"
      ON events FOR UPDATE
      TO authenticated
      USING (
        creator_id = (SELECT auth.uid())
        AND status = 'rejected'
      )
      WITH CHECK (
        creator_id = (SELECT auth.uid())
        AND status = 'pending'
        AND rejection_reason IS NULL
      );

    DROP POLICY IF EXISTS "Moderators can moderate events" ON events;
    CREATE POLICY "Moderators can moderate events"
      ON events FOR UPDATE
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM user_roles
          WHERE user_id = (SELECT auth.uid()) AND role IN ('moderator', 'admin')
        )
        AND creator_id != (SELECT auth.uid())
        AND status = 'pending'
      )
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM user_roles
          WHERE user_id = (SELECT auth.uid()) AND role IN ('moderator', 'admin')
        )
        AND creator_id != (SELECT auth.uid())
        AND status IN ('approved', 'rejected')
      );
    RAISE NOTICE 'Fixed events policies';
  END IF;
END $$;

-- ============================================================================
-- MODERATION_LOG TABLE
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'moderation_log') THEN
    DROP POLICY IF EXISTS "Moderators can view logs" ON moderation_log;
    CREATE POLICY "Moderators can view logs"
      ON moderation_log FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM user_roles
          WHERE user_id = (SELECT auth.uid()) AND role IN ('moderator', 'admin')
        )
      );
    RAISE NOTICE 'Fixed moderation_log policies';
  END IF;
END $$;

-- ============================================================================
-- ADMIN_LOG TABLE
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'admin_log') THEN
    DROP POLICY IF EXISTS "Admins can view admin logs" ON admin_log;
    CREATE POLICY "Admins can view admin logs"
      ON admin_log FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM user_roles
          WHERE user_id = (SELECT auth.uid()) AND role = 'admin'
        )
      );
    RAISE NOTICE 'Fixed admin_log policies';
  END IF;
END $$;

-- ============================================================================
-- ROLE_HISTORY TABLE
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'role_history') THEN
    DROP POLICY IF EXISTS "Admins can view role history" ON role_history;
    CREATE POLICY "Admins can view role history"
      ON role_history FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM user_roles
          WHERE user_id = (SELECT auth.uid()) AND role = 'admin'
        )
      );
    RAISE NOTICE 'Fixed role_history policies';
  END IF;
END $$;

-- ============================================================================
-- MODERATOR_STATS TABLE
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'moderator_stats') THEN
    DROP POLICY IF EXISTS "Moderators can view own stats" ON moderator_stats;
    CREATE POLICY "Moderators can view own stats"
      ON moderator_stats FOR SELECT
      TO authenticated
      USING (
        user_id = (SELECT auth.uid())
        AND EXISTS (
          SELECT 1 FROM user_roles
          WHERE user_id = (SELECT auth.uid()) AND role IN ('moderator', 'admin')
        )
      );

    DROP POLICY IF EXISTS "Admins can view all stats" ON moderator_stats;
    CREATE POLICY "Admins can view all stats"
      ON moderator_stats FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM user_roles
          WHERE user_id = (SELECT auth.uid()) AND role = 'admin'
        )
      );
    RAISE NOTICE 'Fixed moderator_stats policies';
  END IF;
END $$;

-- ============================================================================
-- MODERATOR_STATS_ARCHIVE TABLE
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'moderator_stats_archive') THEN
    DROP POLICY IF EXISTS "Admins can view archived stats" ON moderator_stats_archive;
    CREATE POLICY "Admins can view archived stats"
      ON moderator_stats_archive FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM user_roles
          WHERE user_id = (SELECT auth.uid()) AND role = 'admin'
        )
      );
    RAISE NOTICE 'Fixed moderator_stats_archive policies';
  END IF;
END $$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
  policy_count INTEGER;
BEGIN
  -- Count policies that should now use (SELECT auth.uid())
  SELECT COUNT(*) INTO policy_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND (
      qual LIKE '%(SELECT auth.uid())%'
      OR with_check LIKE '%(SELECT auth.uid())%'
    );

  RAISE NOTICE '========================================';
  RAISE NOTICE 'Migration 043_fix_rls_auth_initplan_performance completed';
  RAISE NOTICE '   - Fixed % policies to use (SELECT auth.uid()) pattern', policy_count;
  RAISE NOTICE '   - This improves query performance by evaluating auth.uid() once per query';
  RAISE NOTICE '   - Reference: https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan';
  RAISE NOTICE '========================================';
END $$;
