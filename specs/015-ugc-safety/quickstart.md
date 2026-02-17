# Quickstart: UGC Safety System

**Feature**: 015-ugc-safety
**Purpose**: Apple Guideline 1.2 compliance for User-Generated Content

## Prerequisites

- Supabase CLI installed
- Access to Nova Supabase project
- Moderator role for testing

---

## 1. Database Setup

### Run Migration

```bash
# From project root
supabase db push

# Or apply specific migration
supabase migration up 057_ugc_safety_system.sql
```

### Verify Tables

```sql
-- Check tables created
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('reports', 'user_blocks', 'banned_words', 'user_sanctions');

-- Should return 4 rows
```

---

## 2. Seed Banned Words

```bash
# Run seed script
supabase db seed --file supabase/seeds/banned_words.sql
```

Or manually:

```sql
-- Seed from existing profanity list
INSERT INTO banned_words (word, pattern_type, severity, language, created_by)
VALUES
  ('cazzo', 'exact', 'block', 'it', 'ADMIN_UUID'),
  ('merda', 'exact', 'block', 'it', 'ADMIN_UUID'),
  -- ... (see full list in migration)
;
```

---

## 3. Test Report System

### Create Test Report

```dart
// In Flutter app
final report = await supabase.from('reports').insert({
  'reporter_id': currentUserId,
  'content_type': 'comment',
  'content_id': 'test-comment-uuid',
  'category': 'bullying',
  'note': 'Test segnalazione',
}).select().single();

print('Report created: ${report['id']}');
```

### Verify in Dashboard

```sql
SELECT * FROM reports WHERE status = 'pending';
```

---

## 4. Test Block System

### Block User

```dart
await supabase.from('user_blocks').insert({
  'blocker_id': currentUserId,
  'blocked_id': 'target-user-uuid',
});
```

### Verify Block Effect

```dart
// Check if blocked content is filtered
final isBlocked = await supabase.rpc('is_user_blocked', params: {
  'p_target_user_id': 'target-user-uuid',
});

print('Is blocked: $isBlocked');  // Should be true
```

### Verify Moderator Notification

```sql
SELECT * FROM notifications
WHERE type = 'user_block'
ORDER BY created_at DESC
LIMIT 1;
```

---

## 5. Test ToS Acceptance

### Check Status

```dart
final status = await supabase.rpc('get_tos_status');
print('ToS Status: $status');
// {has_accepted: false, current_version: "1.0.0", needs_reaccept: true}
```

### Accept ToS

```dart
await supabase.rpc('accept_tos', params: {
  'p_version': '1.0.0',
});
```

### Verify Acceptance

```sql
SELECT tos_accepted_version, tos_accepted_at
FROM profiles
WHERE user_id = 'your-user-uuid';
```

---

## 6. Test Content Filter

### Check Clean Content

```dart
final result = await supabase.rpc('check_content', params: {
  'p_text': 'Ciao, come stai?',
});
print(result);  // {allowed: true, blocked: false, matched_words: []}
```

### Check Blocked Content

```dart
final result = await supabase.rpc('check_content', params: {
  'p_text': 'Testo con parola vietata',
});
print(result);  // {allowed: false, blocked: true, matched_words: [...]}
```

---

## 7. Test Moderation Actions

### Review Report (as Moderator)

```dart
// Requires moderator role
await supabase.rpc('review_report', params: {
  'p_report_id': 'report-uuid',
  'p_action': 'content_removed',
});
```

### Create Sanction

```dart
await supabase.rpc('review_report', params: {
  'p_report_id': 'report-uuid',
  'p_action': 'user_warned',
  'p_sanction_reason': 'Violazione policy linguaggio',
});
```

---

## 8. Edge Functions

### Deploy Functions

```bash
supabase functions deploy send-urgent-reports-digest
supabase functions deploy check-ban-status
```

### Test Locally

```bash
supabase functions serve send-urgent-reports-digest --env-file .env.local
```

---

## Key Files

| File | Purpose |
|------|---------|
| `supabase/migrations/057_ugc_safety_system.sql` | Database migration |
| `supabase/seeds/banned_words.sql` | Initial word list |
| `lib/features/safety/` | Flutter feature module |
| `supabase/functions/send-urgent-reports-digest/` | Email digest function |

---

## Common Issues

### RLS Policy Blocking

If queries fail with permission denied:

```sql
-- Check user role
SELECT * FROM user_roles WHERE user_id = auth.uid();

-- Verify RLS is correctly configured
SELECT * FROM pg_policies WHERE tablename = 'reports';
```

### Content Filter Not Working

```sql
-- Check banned_words is populated
SELECT COUNT(*) FROM banned_words WHERE deleted_at IS NULL;

-- Test function directly
SELECT check_content('test text');
```

### Notifications Not Sent

```sql
-- Check trigger exists
SELECT * FROM pg_trigger WHERE tgname = 'trg_notify_moderators_on_block';

-- Check notifications table
SELECT * FROM notifications WHERE type = 'user_block';
```

---

## Verification Checklist

- [ ] Migration applied successfully
- [ ] 4 new tables exist (reports, user_blocks, banned_words, user_sanctions)
- [ ] Profiles has tos_accepted_version column
- [ ] banned_words seeded with initial list
- [ ] Report creation works
- [ ] Block creates notification for moderators
- [ ] ToS acceptance updates profile
- [ ] Content filter blocks banned words
- [ ] Moderator can review reports
- [ ] User sanctions are created correctly
