-- Migration: 049_fix_function_search_path_v2
-- Purpose: Fix security warning by setting search_path on all functions (dynamic approach)
-- Date: 2026-02-06
--
-- Problem: Previous migration failed because ALTER FUNCTION requires exact signatures.
-- Solution: Use dynamic SQL to query pg_proc and build exact ALTER statements.
--
-- Reference: https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable

-- ============================================================================
-- DYNAMIC FIX: Query all functions and set search_path
-- ============================================================================

DO $$
DECLARE
  func_record RECORD;
  alter_sql TEXT;
  fixed_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  -- Find all functions in public schema without search_path set
  FOR func_record IN
    SELECT
      p.oid,
      p.proname AS func_name,
      pg_get_function_identity_arguments(p.oid) AS func_args,
      pg_get_functiondef(p.oid) AS func_def
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.prokind = 'f'  -- Only functions, not procedures
      AND (
        p.proconfig IS NULL
        OR NOT EXISTS (
          SELECT 1 FROM unnest(p.proconfig) AS config
          WHERE config LIKE 'search_path=%'
        )
      )
      -- Only fix functions we know about
      AND p.proname IN (
        'update_updated_at_column',
        'check_username_available',
        'soft_delete_profile',
        'parse_name_from_email',
        'is_profile_complete',
        'get_profile_stats',
        'cancel_profile_deletion',
        'is_profile_deleted',
        'sync_email_from_auth',
        'notify_coorganizer_addition',
        'notify_coorganizer_removal',
        'set_username_on_signup',
        'clear_all_chat_messages',
        'update_event_help_requests_updated_at',
        'update_event_help_offers_updated_at',
        'trigger_chat_cleanup',
        'notify_event_modification',
        'upsert_fcm_token',
        'delete_fcm_token',
        'check_comment_depth',
        'cleanup_stale_fcm_tokens',
        'search_profiles',
        'moderate_event',
        'is_moderator',
        'trigger_remoderation_on_event_edit',
        'search_events',
        'generate_unique_username',
        'sanitize_bio',
        'check_chat_rate_limit',
        'validate_chat_profanity',
        'update_chat_reaction_count',
        'update_chat_reply_count',
        'update_chat_report_count',
        'search_users_for_mention',
        'cleanup_old_chat_messages',
        'cleanup_expired_chat_media',
        'notify_help_offer',
        'update_tutor_profiles_updated_at',
        'notify_chat_mentions',
        'contains_profanity',
        'hook_restrict_signup_by_email_domain',
        'hash_email',
        'check_magic_link_rate_limit',
        'cleanup_old_auth_events',
        'increment_media_view_count',
        'search_users_and_events'
      )
  LOOP
    BEGIN
      -- Build the ALTER FUNCTION statement with exact signature
      IF func_record.func_args = '' THEN
        alter_sql := format(
          'ALTER FUNCTION public.%I() SET search_path = public',
          func_record.func_name
        );
      ELSE
        alter_sql := format(
          'ALTER FUNCTION public.%I(%s) SET search_path = public',
          func_record.func_name,
          func_record.func_args
        );
      END IF;

      -- Execute the ALTER
      EXECUTE alter_sql;
      fixed_count := fixed_count + 1;
      RAISE NOTICE 'Fixed: %(%)', func_record.func_name, func_record.func_args;

    EXCEPTION WHEN OTHERS THEN
      error_count := error_count + 1;
      RAISE NOTICE 'Error fixing %(%) : %', func_record.func_name, func_record.func_args, SQLERRM;
    END;
  END LOOP;

  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Fixed % functions, % errors', fixed_count, error_count;
  RAISE NOTICE '========================================';
END $$;

-- ============================================================================
-- Also fix trigger functions (they may have different signatures)
-- ============================================================================

DO $$
DECLARE
  func_record RECORD;
  alter_sql TEXT;
  fixed_count INTEGER := 0;
BEGIN
  -- Find trigger functions specifically
  FOR func_record IN
    SELECT
      p.oid,
      p.proname AS func_name,
      pg_get_function_identity_arguments(p.oid) AS func_args
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.prorettype = 'trigger'::regtype
      AND (
        p.proconfig IS NULL
        OR NOT EXISTS (
          SELECT 1 FROM unnest(p.proconfig) AS config
          WHERE config LIKE 'search_path=%'
        )
      )
  LOOP
    BEGIN
      alter_sql := format(
        'ALTER FUNCTION public.%I() SET search_path = public',
        func_record.func_name
      );
      EXECUTE alter_sql;
      fixed_count := fixed_count + 1;
      RAISE NOTICE 'Fixed trigger function: %', func_record.func_name;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Error fixing trigger %: %', func_record.func_name, SQLERRM;
    END;
  END LOOP;

  IF fixed_count > 0 THEN
    RAISE NOTICE 'Fixed % trigger functions', fixed_count;
  END IF;
END $$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
  remaining_count INTEGER;
  func_list TEXT;
BEGIN
  -- Count remaining functions without search_path
  SELECT COUNT(*), string_agg(proname, ', ')
  INTO remaining_count, func_list
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
    AND p.prokind = 'f'
    AND (
      p.proconfig IS NULL
      OR NOT EXISTS (
        SELECT 1 FROM unnest(p.proconfig) AS config
        WHERE config LIKE 'search_path=%'
      )
    );

  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Migration 049_fix_function_search_path_v2 completed';
  RAISE NOTICE 'Functions still without search_path: %', remaining_count;
  IF remaining_count > 0 AND func_list IS NOT NULL THEN
    RAISE NOTICE 'Remaining: %', LEFT(func_list, 200);
  END IF;
  RAISE NOTICE '';
  RAISE NOTICE 'Note: pg_trgm extension warning requires Dashboard configuration.';
  RAISE NOTICE 'Note: auth_leaked_password_protection is an Auth setting.';
  RAISE NOTICE '========================================';
END $$;
