-- =====================================================================
-- Nova Magic Link Authentication Database Schema (Webhook Version)
-- =====================================================================
-- Version: 1.0.1-webhook
-- Date: 2025-10-30
-- Description: PostgreSQL schema for magic link authentication
--              using Database Webhooks + Edge Functions for event logging
--              (NO PostgreSQL trigger on auth.users)
-- Dependencies: Supabase Auth (auth.users, auth.sessions)
-- Architecture: Database Webhooks → Edge Function → auth_events table
-- =====================================================================

-- =====================================================================
-- PART 1: CUSTOM TABLES
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table: public.auth_events
-- Purpose: Audit log for all authentication events (signin, signout, etc.)
-- Retention: 90 days (automatic cleanup via scheduled function)
-- Populated by: Edge Function via Database Webhook
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.auth_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  email_hash TEXT NOT NULL,
  event_type TEXT NOT NULL CHECK (event_type IN (
    'signup',
    'signin',
    'signout',
    'session_expired',
    'token_refreshed',
    'failed_signin'
  )),
  event_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ip_address INET,
  user_agent TEXT,
  device_info JSONB,
  metadata JSONB
);

COMMENT ON TABLE public.auth_events IS 'Audit log for authentication events with 90-day retention (populated via webhook)';
COMMENT ON COLUMN public.auth_events.user_id IS 'User who triggered event (nullable for failed_signin)';
COMMENT ON COLUMN public.auth_events.email_hash IS 'SHA256 hash of normalized email for privacy';
COMMENT ON COLUMN public.auth_events.event_type IS 'Event type: signup, signin, signout, session_expired, token_refreshed, failed_signin';
COMMENT ON COLUMN public.auth_events.device_info IS 'Structured metadata: {platform, version, app_version}';
COMMENT ON COLUMN public.auth_events.metadata IS 'Event-specific data: {reason, provider, error_code, method}';

-- ---------------------------------------------------------------------
-- Table: public.magic_link_attempts
-- Purpose: Track magic link requests for rate limiting (3 per 15 minutes)
-- Retention: 90 days (automatic cleanup via scheduled function)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.magic_link_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sent_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '15 minutes'),
  used_at TIMESTAMPTZ,
  status TEXT NOT NULL CHECK (status IN (
    'pending',
    'sent',
    'expired',
    'consumed',
    'failed'
  )) DEFAULT 'pending',
  ip_address INET,
  user_agent TEXT
);

COMMENT ON TABLE public.magic_link_attempts IS 'Track magic link requests for rate limiting';
COMMENT ON COLUMN public.magic_link_attempts.email IS 'Email address (normalized to lowercase)';
COMMENT ON COLUMN public.magic_link_attempts.status IS 'Status: pending, sent, expired, consumed, failed';
COMMENT ON COLUMN public.magic_link_attempts.expires_at IS 'Magic link expiration (15 minutes from request)';

-- =====================================================================
-- PART 2: HELPER FUNCTIONS
-- =====================================================================

-- ---------------------------------------------------------------------
-- Function: public.hash_email
-- Purpose: Consistent SHA256 hashing of email addresses for privacy
-- Returns: Hexadecimal string (64 characters)
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.hash_email(email TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
SECURITY DEFINER
AS $$
BEGIN
  RETURN encode(digest(LOWER(TRIM(email)), 'sha256'), 'hex');
END;
$$;

COMMENT ON FUNCTION public.hash_email IS 'SHA256 hash email for privacy-preserving audit logs';

-- Test hash_email function
DO $$
DECLARE
  test_hash TEXT;
  expected_length INTEGER := 64;
BEGIN
  test_hash := public.hash_email('test@galileimoro.edu.it');
  IF LENGTH(test_hash) = expected_length THEN
    RAISE NOTICE '✓ hash_email test passed: % (length: %)', test_hash, expected_length;
  ELSE
    RAISE EXCEPTION 'hash_email test failed: expected length %, got %', expected_length, LENGTH(test_hash);
  END IF;
END;
$$;

-- ---------------------------------------------------------------------
-- Function: public.check_magic_link_rate_limit
-- Purpose: Enforce rate limiting: 3 requests per email per 15-minute sliding window
-- Returns: JSONB {allowed: boolean}
-- Raises: Exception if rate limit exceeded
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.check_magic_link_rate_limit(
  user_email TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  attempt_count INTEGER;
  time_window INTERVAL := INTERVAL '15 minutes';
  max_attempts INTEGER := 3;
BEGIN
  -- Normalize email
  user_email := LOWER(TRIM(user_email));

  -- Count recent attempts with sliding window
  SELECT COUNT(*)
  INTO attempt_count
  FROM public.magic_link_attempts
  WHERE email = user_email
    AND requested_at >= NOW() - time_window
    AND status IN ('sent', 'pending');

  -- Check if rate limit exceeded
  IF attempt_count >= max_attempts THEN
    -- Log failed attempt
    INSERT INTO public.magic_link_attempts (email, status)
    VALUES (user_email, 'failed');

    RAISE EXCEPTION 'Too many requests. Please wait 15 minutes before requesting another magic link'
      USING HINT = 'Rate limit: 3 requests per 15 minutes';
  END IF;

  -- Log successful attempt
  INSERT INTO public.magic_link_attempts (email, status)
  VALUES (user_email, 'sent');

  RETURN jsonb_build_object('allowed', true);
END;
$$;

COMMENT ON FUNCTION public.check_magic_link_rate_limit IS 'Rate limit: Max 3 magic link requests per 15 minutes';

-- ---------------------------------------------------------------------
-- Function: public.hook_restrict_signup_by_email_domain
-- Purpose: Auth Hook to validate email domain is @galileimoro.edu.it
-- Usage: Attach to "Before User Created" hook in Supabase Dashboard
-- Returns: JSONB {} if valid, raises exception if invalid
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.hook_restrict_signup_by_email_domain()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_email TEXT;
  user_email_domain TEXT;
BEGIN
  -- Extract email from JWT claims
  user_email := LOWER(TRIM((current_setting('request.jwt.claims', true)::jsonb->'email')::text, '"'));
  user_email_domain := SPLIT_PART(user_email, '@', 2);

  -- Validate domain
  IF user_email_domain != 'galileimoro.edu.it' THEN
    RAISE EXCEPTION 'Email address cannot be used as it is not authorized'
      USING HINT = 'Please use your school email (@galileimoro.edu.it)';
  END IF;

  RETURN jsonb_build_object();
END;
$$;

COMMENT ON FUNCTION public.hook_restrict_signup_by_email_domain IS 'Auth hook: Validate @galileimoro.edu.it domain';

-- ---------------------------------------------------------------------
-- Function: public.cleanup_old_auth_events
-- Purpose: Delete auth events and magic link attempts older than 90 days
-- Schedule: Daily at 2:00 AM UTC via pg_cron
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.cleanup_old_auth_events()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  deleted_events INTEGER;
  deleted_attempts INTEGER;
BEGIN
  -- Delete old auth events
  DELETE FROM public.auth_events
  WHERE event_timestamp < NOW() - INTERVAL '90 days';
  GET DIAGNOSTICS deleted_events = ROW_COUNT;

  -- Delete old magic link attempts
  DELETE FROM public.magic_link_attempts
  WHERE requested_at < NOW() - INTERVAL '90 days';
  GET DIAGNOSTICS deleted_attempts = ROW_COUNT;

  -- Log cleanup results
  RAISE NOTICE 'Cleanup completed: % auth_events deleted, % magic_link_attempts deleted',
    deleted_events, deleted_attempts;
END;
$$;

COMMENT ON FUNCTION public.cleanup_old_auth_events IS 'Scheduled cleanup: Delete records older than 90 days';

-- =====================================================================
-- PART 3: ROW-LEVEL SECURITY (RLS)
-- =====================================================================
-- Note: auth_events is populated by Edge Function via service_role
--       Users can only read their own events
-- =====================================================================

-- ---------------------------------------------------------------------
-- Enable RLS on custom tables
-- ---------------------------------------------------------------------

ALTER TABLE public.auth_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.magic_link_attempts ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------
-- RLS Policies: auth_events
-- ---------------------------------------------------------------------

DROP POLICY IF EXISTS "Service role can insert events" ON public.auth_events;
DROP POLICY IF EXISTS "Users can read own events" ON public.auth_events;
DROP POLICY IF EXISTS "No updates allowed" ON public.auth_events;
DROP POLICY IF EXISTS "No deletes allowed" ON public.auth_events;

-- Service role can insert events (via Edge Function)
CREATE POLICY "Service role can insert events"
  ON public.auth_events
  FOR INSERT
  TO service_role
  WITH CHECK (true);

-- Authenticated users can read their own events
CREATE POLICY "Users can read own events"
  ON public.auth_events
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- No updates allowed (immutable audit log)
CREATE POLICY "No updates allowed"
  ON public.auth_events
  FOR UPDATE
  TO public
  USING (false);

-- No deletes allowed (except via cleanup function)
CREATE POLICY "No deletes allowed"
  ON public.auth_events
  FOR DELETE
  TO public
  USING (false);

-- ---------------------------------------------------------------------
-- RLS Policies: magic_link_attempts
-- ---------------------------------------------------------------------

DROP POLICY IF EXISTS "Service role can manage attempts" ON public.magic_link_attempts;
DROP POLICY IF EXISTS "No direct user access" ON public.magic_link_attempts;

-- Service role can manage all attempts
CREATE POLICY "Service role can manage attempts"
  ON public.magic_link_attempts
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- No direct user access (managed by backend functions)
CREATE POLICY "No direct user access"
  ON public.magic_link_attempts
  FOR ALL
  TO authenticated
  USING (false);

-- =====================================================================
-- PART 4: INDEXES
-- =====================================================================
-- Optimized indexes for performance-critical queries
-- =====================================================================

-- auth_events indexes
CREATE INDEX IF NOT EXISTS idx_auth_events_user_time
  ON public.auth_events(user_id, event_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_auth_events_type_time
  ON public.auth_events(event_type, event_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_auth_events_email_hash
  ON public.auth_events(email_hash);

CREATE INDEX IF NOT EXISTS idx_auth_events_timestamp
  ON public.auth_events(event_timestamp DESC);

-- magic_link_attempts indexes
CREATE INDEX IF NOT EXISTS idx_magic_link_attempts_email_time
  ON public.magic_link_attempts(email, requested_at DESC);

CREATE INDEX IF NOT EXISTS idx_magic_link_attempts_status
  ON public.magic_link_attempts(status, requested_at DESC);

CREATE INDEX IF NOT EXISTS idx_magic_link_attempts_ip
  ON public.magic_link_attempts(ip_address, requested_at DESC);

-- =====================================================================
-- PART 5: SCHEDULED JOBS (pg_cron)
-- =====================================================================
-- Automatic cleanup of old records every day at 2:00 AM UTC
-- =====================================================================

DO $$
BEGIN
  -- Check if pg_cron extension is available
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- Unschedule existing job if present
    PERFORM cron.unschedule('cleanup-auth-events');

    -- Schedule new job
    PERFORM cron.schedule(
      'cleanup-auth-events',
      '0 2 * * *', -- Daily at 2:00 AM UTC
      'SELECT public.cleanup_old_auth_events()'
    );

    RAISE NOTICE '✓ pg_cron job scheduled: cleanup-auth-events (daily at 2:00 AM UTC)';
  ELSE
    RAISE WARNING 'pg_cron extension not available. Manual cleanup required: SELECT public.cleanup_old_auth_events()';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Failed to schedule cleanup job: %. Run cleanup manually: SELECT public.cleanup_old_auth_events()', SQLERRM;
END;
$$;

-- =====================================================================
-- PART 6: GRANT PERMISSIONS
-- =====================================================================

GRANT USAGE ON SCHEMA public TO service_role;
GRANT ALL ON public.auth_events TO service_role;
GRANT ALL ON public.magic_link_attempts TO service_role;
GRANT EXECUTE ON FUNCTION public.hash_email TO service_role;
GRANT EXECUTE ON FUNCTION public.check_magic_link_rate_limit TO service_role;
GRANT EXECUTE ON FUNCTION public.hook_restrict_signup_by_email_domain TO service_role;
GRANT EXECUTE ON FUNCTION public.cleanup_old_auth_events TO service_role;

GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT ON public.auth_events TO authenticated;

-- =====================================================================
-- PART 7: VERIFICATION
-- =====================================================================

-- Verify tables created
DO $$
DECLARE
  table_count INTEGER;
BEGIN
  SELECT COUNT(*)
  INTO table_count
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_name IN ('auth_events', 'magic_link_attempts');

  IF table_count = 2 THEN
    RAISE NOTICE '✓ Tables created: auth_events, magic_link_attempts';
  ELSE
    RAISE EXCEPTION 'Table creation failed: expected 2 tables, found %', table_count;
  END IF;
END;
$$;

-- Verify functions created
DO $$
DECLARE
  function_count INTEGER;
BEGIN
  SELECT COUNT(*)
  INTO function_count
  FROM information_schema.routines
  WHERE routine_schema = 'public'
    AND routine_name IN (
      'hash_email',
      'check_magic_link_rate_limit',
      'hook_restrict_signup_by_email_domain',
      'cleanup_old_auth_events'
    );

  IF function_count = 4 THEN
    RAISE NOTICE '✓ Functions created: hash_email, check_magic_link_rate_limit, hook_restrict_signup_by_email_domain, cleanup_old_auth_events';
  ELSE
    RAISE EXCEPTION 'Function creation failed: expected 4 functions, found %', function_count;
  END IF;
END;
$$;

-- Verify RLS enabled
DO $$
DECLARE
  rls_count INTEGER;
BEGIN
  SELECT COUNT(*)
  INTO rls_count
  FROM pg_tables
  WHERE schemaname = 'public'
    AND tablename IN ('auth_events', 'magic_link_attempts')
    AND rowsecurity = true;

  IF rls_count = 2 THEN
    RAISE NOTICE '✓ RLS enabled on both tables';
  ELSE
    RAISE WARNING 'RLS verification: expected 2 tables with RLS, found %', rls_count;
  END IF;
END;
$$;

-- Verify indexes created
DO $$
DECLARE
  index_count INTEGER;
BEGIN
  SELECT COUNT(*)
  INTO index_count
  FROM pg_indexes
  WHERE schemaname = 'public'
    AND tablename IN ('auth_events', 'magic_link_attempts');

  IF index_count >= 7 THEN
    RAISE NOTICE '✓ Indexes created: % indexes on auth_events and magic_link_attempts', index_count;
  ELSE
    RAISE WARNING 'Index verification: expected >= 7 indexes, found %', index_count;
  END IF;
END;
$$;

-- Final success message
SELECT
  '✅ Database setup complete (webhook version)!' AS status,
  'Next steps:' AS next_step_1,
  '1. Create Edge Function: supabase functions new log-auth-event' AS next_step_2,
  '2. Deploy Edge Function: supabase functions deploy log-auth-event' AS next_step_3,
  '3. Configure Database Webhook in Dashboard → Database → Webhooks' AS next_step_4,
  '4. Attach webhook to auth.users table (INSERT, UPDATE events)' AS next_step_5;

-- =====================================================================
-- ROLLBACK INSTRUCTIONS (if needed)
-- =====================================================================
-- Run these commands to completely remove the schema:
--
-- DROP TABLE IF EXISTS public.auth_events CASCADE;
-- DROP TABLE IF EXISTS public.magic_link_attempts CASCADE;
-- DROP FUNCTION IF EXISTS public.hash_email CASCADE;
-- DROP FUNCTION IF EXISTS public.check_magic_link_rate_limit CASCADE;
-- DROP FUNCTION IF EXISTS public.hook_restrict_signup_by_email_domain CASCADE;
-- DROP FUNCTION IF EXISTS public.cleanup_old_auth_events CASCADE;
--
-- If pg_cron is available:
-- SELECT cron.unschedule('cleanup-auth-events');
-- =====================================================================
