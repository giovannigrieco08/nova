-- =====================================================================
-- Test Auth Events Logging
-- =====================================================================
-- Purpose: Verify that auth events are being logged correctly
-- Run in: Supabase SQL Editor AFTER running signup tests
-- =====================================================================

-- Test 1: Check if any events were logged
SELECT
  'Test 1: Events Logged' as test_name,
  COUNT(*) as total_events,
  CASE
    WHEN COUNT(*) > 0 THEN '✅ PASS (events are being logged)'
    ELSE '⚠️  No events yet (run signup test first)'
  END as result
FROM public.auth_events;

-- Test 2: Check event types distribution
SELECT
  'Test 2: Event Types' as test_name,
  event_type,
  COUNT(*) as count,
  MAX(event_timestamp) as last_occurrence
FROM public.auth_events
GROUP BY event_type
ORDER BY count DESC;

-- Test 3: Verify email hashing (should be SHA256 = 64 chars)
SELECT
  'Test 3: Email Hashing' as test_name,
  email_hash,
  LENGTH(email_hash) as hash_length,
  CASE
    WHEN LENGTH(email_hash) = 64 THEN '✅ PASS (SHA256)'
    ELSE '❌ FAIL (not SHA256)'
  END as result
FROM public.auth_events
LIMIT 5;

-- Test 4: Check metadata structure
SELECT
  'Test 4: Metadata' as test_name,
  event_type,
  metadata,
  CASE
    WHEN metadata IS NOT NULL THEN '✅ PASS (metadata present)'
    ELSE '⚠️  No metadata'
  END as result
FROM public.auth_events
ORDER BY event_timestamp DESC
LIMIT 5;

-- Test 5: Recent events (last 10)
SELECT
  'Test 5: Recent Events' as test_section,
  event_type,
  LEFT(email_hash, 16) || '...' as email_hash_preview,
  event_timestamp,
  metadata->>'provider' as provider,
  metadata->>'method' as method
FROM public.auth_events
ORDER BY event_timestamp DESC
LIMIT 10;

-- Test 6: Events per user
SELECT
  'Test 6: Events Per User' as test_name,
  user_id,
  COUNT(*) as event_count,
  STRING_AGG(DISTINCT event_type, ', ' ORDER BY event_type) as event_types
FROM public.auth_events
GROUP BY user_id
ORDER BY event_count DESC;

-- Summary
SELECT
  '========================================' as summary,
  'Auth Events Logging Verification Complete' as status,
  COUNT(*) as total_events_in_database,
  MAX(event_timestamp) as latest_event
FROM public.auth_events;
