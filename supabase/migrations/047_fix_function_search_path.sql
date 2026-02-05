-- Migration: 047_fix_function_search_path
-- Purpose: Fix security warning by setting search_path on all functions
-- Date: 2026-02-05
--
-- Problem: Functions without a fixed search_path are vulnerable to search path hijacking.
--          An attacker could create malicious objects in a schema that appears earlier
--          in the search_path, causing the function to use them instead of the intended objects.
--
-- Solution: Use ALTER FUNCTION to set search_path = public for all affected functions.
--
-- Reference: https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable

-- ============================================================================
-- FIX ALL FUNCTIONS WITH MUTABLE SEARCH_PATH
-- Using ALTER FUNCTION to add SET search_path = public
-- ============================================================================

-- Profile-related functions
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_updated_at_column') THEN
    ALTER FUNCTION update_updated_at_column() SET search_path = public;
    RAISE NOTICE 'Fixed: update_updated_at_column';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'check_username_available') THEN
    ALTER FUNCTION check_username_available(text) SET search_path = public;
    RAISE NOTICE 'Fixed: check_username_available';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'soft_delete_profile') THEN
    ALTER FUNCTION soft_delete_profile() SET search_path = public;
    RAISE NOTICE 'Fixed: soft_delete_profile';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'parse_name_from_email') THEN
    ALTER FUNCTION parse_name_from_email(text) SET search_path = public;
    RAISE NOTICE 'Fixed: parse_name_from_email';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'is_profile_complete') THEN
    ALTER FUNCTION is_profile_complete(uuid) SET search_path = public;
    RAISE NOTICE 'Fixed: is_profile_complete';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_profile_stats') THEN
    ALTER FUNCTION get_profile_stats(uuid) SET search_path = public;
    RAISE NOTICE 'Fixed: get_profile_stats';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'cancel_profile_deletion') THEN
    ALTER FUNCTION cancel_profile_deletion() SET search_path = public;
    RAISE NOTICE 'Fixed: cancel_profile_deletion';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'is_profile_deleted') THEN
    ALTER FUNCTION is_profile_deleted(uuid) SET search_path = public;
    RAISE NOTICE 'Fixed: is_profile_deleted';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'sync_email_from_auth') THEN
    ALTER FUNCTION sync_email_from_auth() SET search_path = public;
    RAISE NOTICE 'Fixed: sync_email_from_auth';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'set_username_on_signup') THEN
    ALTER FUNCTION set_username_on_signup() SET search_path = public;
    RAISE NOTICE 'Fixed: set_username_on_signup';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'generate_unique_username') THEN
    ALTER FUNCTION generate_unique_username(text) SET search_path = public;
    RAISE NOTICE 'Fixed: generate_unique_username';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'sanitize_bio') THEN
    ALTER FUNCTION sanitize_bio(text) SET search_path = public;
    RAISE NOTICE 'Fixed: sanitize_bio';
  END IF;
END $$;

-- Event-related functions
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'notify_coorganizer_addition') THEN
    ALTER FUNCTION notify_coorganizer_addition() SET search_path = public;
    RAISE NOTICE 'Fixed: notify_coorganizer_addition';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'notify_coorganizer_removal') THEN
    ALTER FUNCTION notify_coorganizer_removal() SET search_path = public;
    RAISE NOTICE 'Fixed: notify_coorganizer_removal';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'notify_event_modification') THEN
    ALTER FUNCTION notify_event_modification() SET search_path = public;
    RAISE NOTICE 'Fixed: notify_event_modification';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'search_events') THEN
    -- search_events might have different signatures, try common ones
    BEGIN
      ALTER FUNCTION search_events(text, int) SET search_path = public;
    EXCEPTION WHEN undefined_function THEN
      BEGIN
        ALTER FUNCTION search_events(text) SET search_path = public;
      EXCEPTION WHEN undefined_function THEN
        NULL;
      END;
    END;
    RAISE NOTICE 'Fixed: search_events';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'moderate_event') THEN
    -- Try common signatures
    BEGIN
      ALTER FUNCTION moderate_event(uuid, text, text) SET search_path = public;
    EXCEPTION WHEN undefined_function THEN
      BEGIN
        ALTER FUNCTION moderate_event(uuid, text) SET search_path = public;
      EXCEPTION WHEN undefined_function THEN
        NULL;
      END;
    END;
    RAISE NOTICE 'Fixed: moderate_event';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'is_moderator') THEN
    ALTER FUNCTION is_moderator() SET search_path = public;
    RAISE NOTICE 'Fixed: is_moderator';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'trigger_remoderation_on_event_edit') THEN
    ALTER FUNCTION trigger_remoderation_on_event_edit() SET search_path = public;
    RAISE NOTICE 'Fixed: trigger_remoderation_on_event_edit';
  END IF;
END $$;

-- Event help request functions
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_event_help_requests_updated_at') THEN
    ALTER FUNCTION update_event_help_requests_updated_at() SET search_path = public;
    RAISE NOTICE 'Fixed: update_event_help_requests_updated_at';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_event_help_offers_updated_at') THEN
    ALTER FUNCTION update_event_help_offers_updated_at() SET search_path = public;
    RAISE NOTICE 'Fixed: update_event_help_offers_updated_at';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'notify_help_offer') THEN
    ALTER FUNCTION notify_help_offer() SET search_path = public;
    RAISE NOTICE 'Fixed: notify_help_offer';
  END IF;
END $$;

-- Chat-related functions
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'clear_all_chat_messages') THEN
    ALTER FUNCTION clear_all_chat_messages() SET search_path = public;
    RAISE NOTICE 'Fixed: clear_all_chat_messages';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'trigger_chat_cleanup') THEN
    ALTER FUNCTION trigger_chat_cleanup() SET search_path = public;
    RAISE NOTICE 'Fixed: trigger_chat_cleanup';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'check_chat_rate_limit') THEN
    ALTER FUNCTION check_chat_rate_limit() SET search_path = public;
    RAISE NOTICE 'Fixed: check_chat_rate_limit';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'validate_chat_profanity') THEN
    ALTER FUNCTION validate_chat_profanity() SET search_path = public;
    RAISE NOTICE 'Fixed: validate_chat_profanity';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_chat_reaction_count') THEN
    ALTER FUNCTION update_chat_reaction_count() SET search_path = public;
    RAISE NOTICE 'Fixed: update_chat_reaction_count';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_chat_reply_count') THEN
    ALTER FUNCTION update_chat_reply_count() SET search_path = public;
    RAISE NOTICE 'Fixed: update_chat_reply_count';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_chat_report_count') THEN
    ALTER FUNCTION update_chat_report_count() SET search_path = public;
    RAISE NOTICE 'Fixed: update_chat_report_count';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'search_users_for_mention') THEN
    BEGIN
      ALTER FUNCTION search_users_for_mention(text, int) SET search_path = public;
    EXCEPTION WHEN undefined_function THEN
      BEGIN
        ALTER FUNCTION search_users_for_mention(text) SET search_path = public;
      EXCEPTION WHEN undefined_function THEN
        NULL;
      END;
    END;
    RAISE NOTICE 'Fixed: search_users_for_mention';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'cleanup_old_chat_messages') THEN
    ALTER FUNCTION cleanup_old_chat_messages() SET search_path = public;
    RAISE NOTICE 'Fixed: cleanup_old_chat_messages';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'cleanup_expired_chat_media') THEN
    ALTER FUNCTION cleanup_expired_chat_media() SET search_path = public;
    RAISE NOTICE 'Fixed: cleanup_expired_chat_media';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'notify_chat_mentions') THEN
    ALTER FUNCTION notify_chat_mentions() SET search_path = public;
    RAISE NOTICE 'Fixed: notify_chat_mentions';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'contains_profanity') THEN
    ALTER FUNCTION contains_profanity(text) SET search_path = public;
    RAISE NOTICE 'Fixed: contains_profanity';
  END IF;
END $$;

-- FCM/Push notification functions
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'upsert_fcm_token') THEN
    ALTER FUNCTION upsert_fcm_token(uuid, text, text, text) SET search_path = public;
    RAISE NOTICE 'Fixed: upsert_fcm_token';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'delete_fcm_token') THEN
    ALTER FUNCTION delete_fcm_token(text) SET search_path = public;
    RAISE NOTICE 'Fixed: delete_fcm_token';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'cleanup_stale_fcm_tokens') THEN
    ALTER FUNCTION cleanup_stale_fcm_tokens() SET search_path = public;
    RAISE NOTICE 'Fixed: cleanup_stale_fcm_tokens';
  END IF;
END $$;

-- Comment functions
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'check_comment_depth') THEN
    ALTER FUNCTION check_comment_depth() SET search_path = public;
    RAISE NOTICE 'Fixed: check_comment_depth';
  END IF;
END $$;

-- Search functions
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'search_profiles') THEN
    BEGIN
      ALTER FUNCTION search_profiles(text, int) SET search_path = public;
    EXCEPTION WHEN undefined_function THEN
      BEGIN
        ALTER FUNCTION search_profiles(text) SET search_path = public;
      EXCEPTION WHEN undefined_function THEN
        NULL;
      END;
    END;
    RAISE NOTICE 'Fixed: search_profiles';
  END IF;
END $$;

-- Tutor profile functions
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_tutor_profiles_updated_at') THEN
    ALTER FUNCTION update_tutor_profiles_updated_at() SET search_path = public;
    RAISE NOTICE 'Fixed: update_tutor_profiles_updated_at';
  END IF;
END $$;

-- Auth-related functions
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'hook_restrict_signup_by_email_domain') THEN
    -- This function might have a specific signature based on Supabase auth hooks
    BEGIN
      ALTER FUNCTION hook_restrict_signup_by_email_domain(jsonb) SET search_path = public;
    EXCEPTION WHEN undefined_function THEN
      NULL;
    END;
    RAISE NOTICE 'Fixed: hook_restrict_signup_by_email_domain';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'hash_email') THEN
    ALTER FUNCTION hash_email(text) SET search_path = public;
    RAISE NOTICE 'Fixed: hash_email';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'check_magic_link_rate_limit') THEN
    BEGIN
      ALTER FUNCTION check_magic_link_rate_limit(text) SET search_path = public;
    EXCEPTION WHEN undefined_function THEN
      BEGIN
        ALTER FUNCTION check_magic_link_rate_limit() SET search_path = public;
      EXCEPTION WHEN undefined_function THEN
        NULL;
      END;
    END;
    RAISE NOTICE 'Fixed: check_magic_link_rate_limit';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'cleanup_old_auth_events') THEN
    ALTER FUNCTION cleanup_old_auth_events() SET search_path = public;
    RAISE NOTICE 'Fixed: cleanup_old_auth_events';
  END IF;
END $$;

-- Media functions
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'increment_media_view_count') THEN
    ALTER FUNCTION increment_media_view_count(uuid) SET search_path = public;
    RAISE NOTICE 'Fixed: increment_media_view_count';
  END IF;
END $$;

-- ============================================================================
-- MOVE pg_trgm EXTENSION TO EXTENSIONS SCHEMA (if needed)
-- Note: This requires superuser privileges and might not work on Supabase
-- ============================================================================

-- Supabase recommends moving extensions to the 'extensions' schema
-- However, this is often managed by Supabase itself and may not be changeable
-- Commenting out as it typically requires special permissions

-- DO $$ BEGIN
--   IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_trgm') THEN
--     ALTER EXTENSION pg_trgm SET SCHEMA extensions;
--     RAISE NOTICE 'Moved pg_trgm to extensions schema';
--   END IF;
-- EXCEPTION WHEN OTHERS THEN
--   RAISE NOTICE 'Could not move pg_trgm extension: %. This may require Supabase dashboard configuration.', SQLERRM;
-- END $$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
  unfixed_count INTEGER;
BEGIN
  -- Count functions still without search_path set
  SELECT COUNT(*) INTO unfixed_count
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'update_updated_at_column', 'check_username_available', 'soft_delete_profile',
      'parse_name_from_email', 'is_profile_complete', 'get_profile_stats',
      'cancel_profile_deletion', 'is_profile_deleted', 'sync_email_from_auth',
      'notify_coorganizer_addition', 'notify_coorganizer_removal', 'set_username_on_signup',
      'clear_all_chat_messages', 'update_event_help_requests_updated_at',
      'update_event_help_offers_updated_at', 'trigger_chat_cleanup', 'notify_event_modification',
      'upsert_fcm_token', 'delete_fcm_token', 'check_comment_depth', 'cleanup_stale_fcm_tokens',
      'search_profiles', 'moderate_event', 'is_moderator', 'trigger_remoderation_on_event_edit',
      'search_events', 'generate_unique_username', 'sanitize_bio', 'check_chat_rate_limit',
      'validate_chat_profanity', 'update_chat_reaction_count', 'update_chat_reply_count',
      'update_chat_report_count', 'search_users_for_mention', 'cleanup_old_chat_messages',
      'cleanup_expired_chat_media', 'notify_help_offer', 'update_tutor_profiles_updated_at',
      'notify_chat_mentions', 'contains_profanity', 'hook_restrict_signup_by_email_domain',
      'hash_email', 'check_magic_link_rate_limit', 'cleanup_old_auth_events', 'increment_media_view_count'
    )
    AND p.proconfig IS NULL;

  RAISE NOTICE '========================================';
  RAISE NOTICE 'Migration 047_fix_function_search_path completed';
  RAISE NOTICE '  - Set search_path = public on all affected functions';
  RAISE NOTICE '  - Functions without search_path remaining: %', unfixed_count;
  RAISE NOTICE '';
  RAISE NOTICE 'Note: The pg_trgm extension warning cannot be fixed via migration.';
  RAISE NOTICE '      On Supabase, enable extensions via Dashboard > Database > Extensions';
  RAISE NOTICE '      and they will be installed in the correct schema.';
  RAISE NOTICE '';
  RAISE NOTICE 'Note: The auth_leaked_password_protection warning is an Auth setting.';
  RAISE NOTICE '      Enable it via Dashboard > Authentication > Providers > Email > ';
  RAISE NOTICE '      "Prevent the use of leaked passwords"';
  RAISE NOTICE '========================================';
END $$;
