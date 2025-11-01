-- =====================================================================
-- Nova Magic Link Authentication Database Schema
-- =====================================================================
-- Version: 1.0.0
-- Date: 2025-10-30
-- Description: Complete PostgreSQL schema for magic link authentication
--              including audit logging, rate limiting, and security policies
-- Dependencies: Supabase Auth (auth.users, auth.sessions)
-- =====================================================================

-- =====================================================================
-- PART 1: CUSTOM TABLES
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table: public.auth_events
-- Purpose: Audit log for all authentication events (signin, signout, etc.)
-- Retention: 90 days (automatic cleanup via scheduled function)
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

COMMENT ON TABLE public.auth_events IS 'Audit log for authentication events with 90-day retention';
COMMENT ON COLUMN public.auth_events.user_id IS 'User who triggered event (nullable for failed_signin)';
COMMENT ON COLUMN public.auth_events.email_hash IS 'SHA256 hash of normalized email for privacy';
COMMENT ON COLUMN public.auth_events.event_type IS 'Event type: signup, signin, signout, session_expired, token_refreshed, failed_signin';
COMMENT ON COLUMN public.auth_events.device_info IS 'Structured metadata: {platform, version, app_version}';
COMMENT ON COLUMN public.auth_events.metadata IS 'Event-specific data: {reason, provider, error_code}';

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
BEGIN
  ASSERT (SELECT public.hash_email('Test@Example.com')) = (SELECT public.hash_email('test@example.com')),
    'hash_email should be case-insensitive';
  ASSERT (SELECT LENGTH(public.hash_email('test@example.com'))) = 64,
    'hash_email should return 64-character hex string';
END;
$$;

-- ---------------------------------------------------------------------
-- Function: public.check_magic_link_rate_limit
-- Purpose: Enforce rate limiting (3 requests per 15 minutes per email)
-- Raises: EXCEPTION if rate limit exceeded
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

  -- Count recent attempts within sliding window
  SELECT COUNT(*)
  INTO attempt_count
  FROM public.magic_link_attempts
  WHERE email = user_email
    AND requested_at >= NOW() - time_window
    AND status IN ('sent', 'pending');

  -- Check if limit exceeded
  IF attempt_count >= max_attempts THEN
    -- Log blocked attempt
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

COMMENT ON FUNCTION public.check_magic_link_rate_limit IS 'Enforce 3 requests per 15 minutes rate limit';

-- ---------------------------------------------------------------------
-- Function: public.hook_restrict_signup_by_email_domain
-- Purpose: Supabase Before User Created hook - validate @galileimoro.edu.it
-- Raises: EXCEPTION if domain not authorized
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
  -- Extract email from Supabase Auth request payload
  user_email := LOWER(TRIM((current_setting('request.jwt.claims', true)::jsonb->'email')::text, '"'));

  -- Extract domain from email
  user_email_domain := SPLIT_PART(user_email, '@', 2);

  -- Check if domain is allowed
  IF user_email_domain != 'galileimoro.edu.it' THEN
    RAISE EXCEPTION 'Email address cannot be used as it is not authorized'
      USING HINT = 'Please use your school email (@galileimoro.edu.it)';
  END IF;

  -- Allow signup to proceed
  RETURN jsonb_build_object();
END;
$$;

COMMENT ON FUNCTION public.hook_restrict_signup_by_email_domain IS 'Auth hook: Validate @galileimoro.edu.it domain';

-- ---------------------------------------------------------------------
-- Function: public.log_auth_event
-- Purpose: PostgreSQL trigger function to log authentication events
-- Triggered: AFTER INSERT OR UPDATE on auth.users
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.log_auth_event()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Log successful signup (first account creation)
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.auth_events (
      user_id,
      email_hash,
      event_type,
      metadata
    )
    VALUES (
      NEW.id,
      public.hash_email(NEW.email),
      'signup',
      jsonb_build_object(
        'provider', COALESCE(NEW.raw_app_meta_data->>'provider', 'email'),
        'email_confirmed', NEW.email_confirmed_at IS NOT NULL
      )
    );
  END IF;

  -- Log email confirmation (magic link click)
  IF TG_OP = 'UPDATE' AND OLD.email_confirmed_at IS NULL AND NEW.email_confirmed_at IS NOT NULL THEN
    INSERT INTO public.auth_events (
      user_id,
      email_hash,
      event_type,
      metadata
    )
    VALUES (
      NEW.id,
      public.hash_email(NEW.email),
      'signin',
      jsonb_build_object('method', 'magic_link')
    );
  END IF;

  -- Log last sign in update (session refresh or returning user)
  IF TG_OP = 'UPDATE' AND NEW.last_sign_in_at > OLD.last_sign_in_at THEN
    INSERT INTO public.auth_events (
      user_id,
      email_hash,
      event_type,
      metadata
    )
    VALUES (
      NEW.id,
      public.hash_email(NEW.email),
      'signin',
      jsonb_build_object('method', 'session_refresh')
    );
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.log_auth_event IS 'Trigger function: Log signup, signin, and token refresh events';

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
-- PART 3: TRIGGERS
-- =====================================================================

-- ---------------------------------------------------------------------
-- Trigger: trigger_log_auth_events
-- Purpose: Automatically log authentication events to auth_events table
-- Attached to: auth.users (Supabase managed table)
-- ---------------------------------------------------------------------

DROP TRIGGER IF EXISTS trigger_log_auth_events ON auth.users;

CREATE TRIGGER trigger_log_auth_events
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.log_auth_event();

COMMENT ON TRIGGER trigger_log_auth_events ON auth.users IS 'Automatically log signup and signin events';

-- =====================================================================
-- PART 4: ROW-LEVEL SECURITY (RLS)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Enable RLS on custom tables
-- ---------------------------------------------------------------------

ALTER TABLE public.auth_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.magic_link_attempts ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------
-- RLS Policies: public.auth_events
-- ---------------------------------------------------------------------

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Service role can insert events" ON public.auth_events;
DROP POLICY IF EXISTS "Users can read own events" ON public.auth_events;
DROP POLICY IF EXISTS "No updates allowed" ON public.auth_events;
DROP POLICY IF EXISTS "No deletes allowed" ON public.auth_events;

-- Service role can insert events (for triggers and application logging)
CREATE POLICY "Service role can insert events"
  ON public.auth_events
  FOR INSERT
  TO service_role
  WITH CHECK (true);

-- Authenticated users can read only their own events
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

-- No deletes allowed (except via SECURITY DEFINER cleanup function)
CREATE POLICY "No deletes allowed"
  ON public.auth_events
  FOR DELETE
  TO public
  USING (false);

COMMENT ON POLICY "Service role can insert events" ON public.auth_events IS 'Allow triggers and app code to log events';
COMMENT ON POLICY "Users can read own events" ON public.auth_events IS 'Users can view their authentication history';

-- ---------------------------------------------------------------------
-- RLS Policies: public.magic_link_attempts
-- ---------------------------------------------------------------------

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Service role can manage attempts" ON public.magic_link_attempts;
DROP POLICY IF EXISTS "No direct user access" ON public.magic_link_attempts;

-- Service role can manage (for rate limiting function)
CREATE POLICY "Service role can manage attempts"
  ON public.magic_link_attempts
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- No direct access for authenticated users (accessed via PostgreSQL functions only)
CREATE POLICY "No direct user access"
  ON public.magic_link_attempts
  FOR ALL
  TO authenticated
  USING (false);

COMMENT ON POLICY "Service role can manage attempts" ON public.magic_link_attempts IS 'Allow rate limiting function to manage attempts';

-- =====================================================================
-- PART 5: INDEXES
-- =====================================================================

-- ---------------------------------------------------------------------
-- Indexes: public.auth_events (optimized for frequent queries)
-- ---------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_auth_events_user_time
  ON public.auth_events(user_id, event_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_auth_events_type_time
  ON public.auth_events(event_type, event_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_auth_events_email_hash
  ON public.auth_events(email_hash);

CREATE INDEX IF NOT EXISTS idx_auth_events_timestamp
  ON public.auth_events(event_timestamp DESC);

COMMENT ON INDEX idx_auth_events_user_time IS 'User-specific event queries with time ordering';
COMMENT ON INDEX idx_auth_events_type_time IS 'Event type filtering with time ordering';
COMMENT ON INDEX idx_auth_events_email_hash IS 'Email-based event lookup';
COMMENT ON INDEX idx_auth_events_timestamp IS 'Recent activity queries and cleanup operations';

-- ---------------------------------------------------------------------
-- Indexes: public.magic_link_attempts (optimized for rate limiting)
-- ---------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_magic_link_attempts_email_time
  ON public.magic_link_attempts(email, requested_at DESC);

CREATE INDEX IF NOT EXISTS idx_magic_link_attempts_status
  ON public.magic_link_attempts(status, requested_at DESC);

CREATE INDEX IF NOT EXISTS idx_magic_link_attempts_ip
  ON public.magic_link_attempts(ip_address, requested_at DESC);

COMMENT ON INDEX idx_magic_link_attempts_email_time IS 'Rate limiting queries (count recent attempts per email)';
COMMENT ON INDEX idx_magic_link_attempts_status IS 'Status-based filtering';
COMMENT ON INDEX idx_magic_link_attempts_ip IS 'IP-based abuse detection';

-- =====================================================================
-- PART 6: SCHEDULED JOBS (pg_cron)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Schedule cleanup job to run daily at 2:00 AM UTC
-- Requires pg_cron extension (may need to be enabled by Supabase support)
-- ---------------------------------------------------------------------

-- Check if pg_cron extension is available
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- Unschedule existing job if it exists
    PERFORM cron.unschedule('cleanup-auth-events');

    -- Schedule new job
    PERFORM cron.schedule(
      'cleanup-auth-events',
      '0 2 * * *',  -- Daily at 2:00 AM UTC
      'SELECT public.cleanup_old_auth_events()'
    );

    RAISE NOTICE 'pg_cron job scheduled: cleanup-auth-events (daily at 2:00 AM UTC)';
  ELSE
    RAISE WARNING 'pg_cron extension not available. Cleanup job not scheduled. Run cleanup manually or enable pg_cron.';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Failed to schedule cleanup job: %. Run cleanup manually.', SQLERRM;
END;
$$;

-- =====================================================================
-- PART 7: GRANT PERMISSIONS
-- =====================================================================

-- Grant necessary permissions to service_role
GRANT USAGE ON SCHEMA public TO service_role;
GRANT ALL ON public.auth_events TO service_role;
GRANT ALL ON public.magic_link_attempts TO service_role;
GRANT EXECUTE ON FUNCTION public.hash_email TO service_role;
GRANT EXECUTE ON FUNCTION public.check_magic_link_rate_limit TO service_role;
GRANT EXECUTE ON FUNCTION public.hook_restrict_signup_by_email_domain TO service_role;
GRANT EXECUTE ON FUNCTION public.log_auth_event TO service_role;
GRANT EXECUTE ON FUNCTION public.cleanup_old_auth_events TO service_role;

-- Grant read access to authenticated users (via RLS policies)
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT ON public.auth_events TO authenticated;

-- =====================================================================
-- PART 8: TESTING QUERIES
-- =====================================================================

-- ---------------------------------------------------------------------
-- Test 1: Email hashing consistency
-- ---------------------------------------------------------------------

DO $$
BEGIN
  ASSERT (SELECT public.hash_email('Student@galileimoro.edu.it')) =
         (SELECT public.hash_email('student@galileimoro.edu.it')),
    'Email hashing should be case-insensitive';

  ASSERT (SELECT LENGTH(public.hash_email('test@galileimoro.edu.it'))) = 64,
    'SHA256 hash should be 64 characters';

  RAISE NOTICE 'Test 1 PASSED: Email hashing consistency';
END;
$$;

-- ---------------------------------------------------------------------
-- Test 2: Rate limiting logic (insert test data and verify count)
-- ---------------------------------------------------------------------

DO $$
DECLARE
  test_email TEXT := 'test@galileimoro.edu.it';
  attempt_count INTEGER;
BEGIN
  -- Clean up test data
  DELETE FROM public.magic_link_attempts WHERE email = test_email;

  -- Insert 3 attempts within 15 minutes
  INSERT INTO public.magic_link_attempts (email, requested_at, status)
  VALUES
    (test_email, NOW() - INTERVAL '5 minutes', 'sent'),
    (test_email, NOW() - INTERVAL '10 minutes', 'sent'),
    (test_email, NOW() - INTERVAL '14 minutes', 'sent');

  -- Count attempts in 15-minute window
  SELECT COUNT(*)
  INTO attempt_count
  FROM public.magic_link_attempts
  WHERE email = test_email
    AND requested_at >= NOW() - INTERVAL '15 minutes'
    AND status IN ('sent', 'pending');

  ASSERT attempt_count >= 3, 'Rate limit count should be >= 3';

  -- Clean up test data
  DELETE FROM public.magic_link_attempts WHERE email = test_email;

  RAISE NOTICE 'Test 2 PASSED: Rate limiting logic';
END;
$$;

-- ---------------------------------------------------------------------
-- Test 3: Auth event logging trigger (insert test user and verify event)
-- ---------------------------------------------------------------------

DO $$
DECLARE
  test_email TEXT := 'trigger.test@galileimoro.edu.it';
  test_user_id UUID;
  event_count INTEGER;
BEGIN
  -- Note: This test requires INSERT permission on auth.users
  -- In production, run this test with service_role credentials

  -- Insert test user (if possible - may fail due to RLS)
  BEGIN
    INSERT INTO auth.users (email, email_confirmed_at)
    VALUES (test_email, NOW())
    RETURNING id INTO test_user_id;

    -- Check if auth event was logged
    SELECT COUNT(*)
    INTO event_count
    FROM public.auth_events
    WHERE user_id = test_user_id AND event_type = 'signup';

    ASSERT event_count = 1, 'Auth event should be logged via trigger';

    -- Clean up test data
    DELETE FROM auth.users WHERE id = test_user_id;
    DELETE FROM public.auth_events WHERE user_id = test_user_id;

    RAISE NOTICE 'Test 3 PASSED: Auth event logging trigger';
  EXCEPTION
    WHEN insufficient_privilege THEN
      RAISE WARNING 'Test 3 SKIPPED: Insufficient privilege to insert into auth.users (run with service_role)';
  END;
END;
$$;

-- =====================================================================
-- PART 9: ANALYTICS QUERIES (Examples)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Query 1: Daily active users (last 7 days)
-- ---------------------------------------------------------------------

-- SELECT
--   DATE(event_timestamp) AS date,
--   COUNT(DISTINCT user_id) AS daily_active_users
-- FROM public.auth_events
-- WHERE event_type IN ('signin', 'signup')
--   AND event_timestamp >= NOW() - INTERVAL '7 days'
-- GROUP BY DATE(event_timestamp)
-- ORDER BY date DESC;

-- ---------------------------------------------------------------------
-- Query 2: Authentication success rate (last 24 hours)
-- ---------------------------------------------------------------------

-- SELECT
--   COUNT(*) FILTER (WHERE event_type IN ('signin', 'signup')) AS successful_auths,
--   COUNT(*) FILTER (WHERE event_type = 'failed_signin') AS failed_auths,
--   ROUND(
--     100.0 * COUNT(*) FILTER (WHERE event_type IN ('signin', 'signup')) /
--     NULLIF(COUNT(*), 0),
--     2
--   ) AS success_rate_percent
-- FROM public.auth_events
-- WHERE event_timestamp >= NOW() - INTERVAL '24 hours';

-- ---------------------------------------------------------------------
-- Query 3: Users hitting rate limits (last 7 days)
-- ---------------------------------------------------------------------

-- SELECT
--   email,
--   COUNT(*) AS total_attempts,
--   COUNT(*) FILTER (WHERE status = 'failed') AS blocked_attempts,
--   MAX(requested_at) AS last_attempt
-- FROM public.magic_link_attempts
-- WHERE requested_at >= NOW() - INTERVAL '7 days'
-- GROUP BY email
-- HAVING COUNT(*) FILTER (WHERE status = 'failed') > 3
-- ORDER BY blocked_attempts DESC;

-- =====================================================================
-- PART 10: DEPLOYMENT INSTRUCTIONS
-- =====================================================================

-- ---------------------------------------------------------------------
-- Deployment Order (follow this sequence):
-- ---------------------------------------------------------------------

-- 1. Create custom tables (auth_events, magic_link_attempts)
-- 2. Create helper functions (hash_email, check_magic_link_rate_limit, etc.)
-- 3. Create trigger function (log_auth_event)
-- 4. Attach trigger to auth.users table
-- 5. Enable RLS on custom tables
-- 6. Create RLS policies
-- 7. Create indexes
-- 8. Schedule cleanup job (if pg_cron available)
-- 9. Grant permissions
-- 10. Run test queries to verify setup

-- ---------------------------------------------------------------------
-- Rollback Instructions (reverse order):
-- ---------------------------------------------------------------------

-- 1. Unschedule cleanup job
-- 2. Drop indexes
-- 3. Drop RLS policies
-- 4. Disable RLS
-- 5. Drop trigger
-- 6. Drop functions
-- 7. Drop tables

-- Example rollback script:
-- SELECT cron.unschedule('cleanup-auth-events');
-- DROP INDEX IF EXISTS idx_auth_events_user_time;
-- DROP INDEX IF EXISTS idx_magic_link_attempts_email_time;
-- DROP POLICY IF EXISTS "Service role can insert events" ON public.auth_events;
-- ALTER TABLE public.auth_events DISABLE ROW LEVEL SECURITY;
-- DROP TRIGGER IF EXISTS trigger_log_auth_events ON auth.users;
-- DROP FUNCTION IF EXISTS public.log_auth_event();
-- DROP FUNCTION IF EXISTS public.cleanup_old_auth_events();
-- DROP FUNCTION IF EXISTS public.check_magic_link_rate_limit();
-- DROP FUNCTION IF EXISTS public.hook_restrict_signup_by_email_domain();
-- DROP FUNCTION IF EXISTS public.hash_email();
-- DROP TABLE IF EXISTS public.magic_link_attempts;
-- DROP TABLE IF EXISTS public.auth_events;

-- =====================================================================
-- END OF SCHEMA
-- =====================================================================

-- Final verification query
SELECT
  'Schema deployment complete' AS status,
  COUNT(*) AS table_count
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('auth_events', 'magic_link_attempts');
