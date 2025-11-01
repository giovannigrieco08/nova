-- =====================================================================
-- Test Database Schema Deployment
-- =====================================================================
-- Purpose: Verify that all tables, functions, and triggers are created
-- Run in: Supabase SQL Editor
-- =====================================================================

-- Test 1: Verify tables exist
SELECT
  'Test 1: Tables' as test_name,
  COUNT(*) as count,
  CASE WHEN COUNT(*) = 2 THEN '✅ PASS' ELSE '❌ FAIL' END as result
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('auth_events', 'magic_link_attempts');

-- Test 2: Verify functions exist
SELECT
  'Test 2: Functions' as test_name,
  COUNT(*) as count,
  CASE WHEN COUNT(*) = 4 THEN '✅ PASS' ELSE '❌ FAIL' END as result
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'hash_email',
    'check_magic_link_rate_limit',
    'hook_restrict_signup_by_email_domain',
    'cleanup_old_auth_events'
  );

-- Test 3: Test hash_email function
SELECT
  'Test 3: hash_email()' as test_name,
  public.hash_email('test@galileimoro.edu.it') as email_hash,
  CASE
    WHEN LENGTH(public.hash_email('test@galileimoro.edu.it')) = 64
    THEN '✅ PASS (SHA256 hash = 64 chars)'
    ELSE '❌ FAIL'
  END as result;

-- Test 4: Verify RLS enabled
SELECT
  'Test 4: RLS Enabled' as test_name,
  COUNT(*) as count,
  CASE WHEN COUNT(*) = 2 THEN '✅ PASS' ELSE '❌ FAIL' END as result
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('auth_events', 'magic_link_attempts')
  AND rowsecurity = true;

-- Test 5: Verify indexes created
SELECT
  'Test 5: Indexes' as test_name,
  COUNT(*) as count,
  CASE WHEN COUNT(*) >= 7 THEN '✅ PASS' ELSE '❌ FAIL' END as result
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('auth_events', 'magic_link_attempts');

-- Test 6: Check current auth_events (should be empty initially)
SELECT
  'Test 6: auth_events Table' as test_name,
  COUNT(*) as current_count,
  '✅ Ready for logging' as result
FROM public.auth_events;

-- Summary
SELECT
  '========================================' as summary,
  'Database Schema Verification Complete' as status,
  '========================================' as end_marker;
