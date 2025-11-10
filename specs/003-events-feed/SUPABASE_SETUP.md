# Supabase Setup Guide - Events Feed

**Feature**: 003-events-feed
**Migration File**: `supabase/migrations/004_create_events_feed_tables.sql` (Patched: 2025-11-02)
**Estimated Time**: 2 minutes (SQL Editor method)
**Tables Created**: 5 (events, likes, participations, comments, reports)
**Policies**: 15 active + 4 future moderator policies (commented out)

---

## ⚠️ IMPORTANT: Migration Conflict Issue

**The Supabase CLI won't work** for this project due to a migration tracking conflict:

- **Problem**: Migrations 002 and 003 are already in your database, but not tracked in `supabase_migrations.schema_migrations`
- **Error**: Running `npx supabase db push` fails with "relation 'profiles' already exists"
- **Solution**: Use the SQL Editor approach below to apply only migration 004

---

## ⚡ RECOMMENDED: Automated Setup via Supabase CLI

~~The database setup has been **fully automated**! One command does everything:~~

**❌ CLI APPROACH DOESN'T WORK** - See migration conflict warning above. Use SQL Editor instead.

<details>
<summary>Click to see why CLI fails (technical explanation)</summary>

```bash
npx supabase db push
```

**Expected behavior**: Apply only migration 004

**Actual error**:
```
ERROR: relation "profiles" already exists (SQLSTATE 42P07)
At statement: 0
-- Migration: 002_create_profiles_table
```

**Why this happens**: The CLI sees migrations 002, 003, and 004 as "new" (not tracked), but when it tries to apply 002 first, the `profiles` table already exists from a previous manual setup. The CLI doesn't know it was already applied.

**Fix required**: Either register old migrations in tracking table OR use SQL Editor to apply only 004.

</details>

---

## Quick Start (2 Minutes)

### Option A: Manual SQL Editor (Recommended)

**This is the safest approach** - we skip migrations 002/003 (already in database) and apply only 004:

1. **Navigate to Supabase Dashboard**: [https://supabase.com/dashboard](https://supabase.com/dashboard)

2. **Select your project** (the Nova events project)

3. **Open SQL Editor**: Click **SQL Editor** in left sidebar → **+ New query** button

4. **Open the migration file** in your code editor:
   ```
   C:\Users\grigi\nova_def\supabase\migrations\004_create_events_feed_tables.sql
   ```

5. **Copy the entire file contents** (all ~400 lines)

6. **Paste into SQL Editor** (replace any placeholder text)

7. **Run the migration**: Click **Run** button (or press `Ctrl+Enter`)

8. **Expected output**:
   ```
   Success. No rows returned
   ```

   This means:
   - ✅ All 5 tables created (events, likes, participations, comments, reports)
   - ✅ All 14 indexes created
   - ✅ All 15 RLS policies applied (moderator policies commented out for future use)
   - ✅ Trigger for auto-updating `updated_at` on events table
   - ✅ Realtime enabled on events and comments tables (with guards)

**Note**: This migration uses the existing `profiles` table from migration 002. No new `users` table is created.

**Done!** ✅ Database setup complete. Proceed to verification checklist below.

---

## Verification Checklist

After setup, verify everything is correct:

### 1. Check Tables (should be 5)

```sql
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('events', 'likes', 'participations', 'comments', 'reports')
ORDER BY tablename;
```

**Expected**: 5 rows (comments, events, likes, participations, reports)

**Note**: No `users` table - the migration uses the existing `profiles` table from migration 002.

### 2. Check Indexes (should be 14)

```sql
SELECT indexname
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname LIKE 'idx_%'
ORDER BY indexname;
```

**Expected**: 14 rows (all indexes starting with `idx_`)

### 3. Check RLS Policies (should be 15)

```sql
SELECT tablename, policyname
FROM pg_policies
WHERE tablename IN ('events', 'likes', 'participations', 'comments', 'reports')
ORDER BY tablename, policyname;
```

**Expected**: 15 rows (15 policies across 5 tables - moderator policies excluded)

### 4. Check Realtime (should be 2 tables)

```sql
SELECT tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND tablename IN ('events', 'comments');
```

**Expected**: 2 rows (events, comments)

---

## What This Migration Creates

### Tables (5)

**Note**: Uses existing `profiles` table from migration 002 instead of creating new `users` table.

| Table | Columns | Primary Key | Foreign Keys | Purpose |
|-------|---------|-------------|--------------|---------|
| `events` | 11 | `id` (UUID) | `creator_id` → auth.users | School events with moderation |
| `likes` | 3 | `(user_id, event_id)` | `user_id` → auth.users, `event_id` → events | Event likes (junction) |
| `participations` | 3 | `(user_id, event_id)` | `user_id` → auth.users, `event_id` → events | Event RSVPs (junction) |
| `comments` | 5 | `id` (UUID) | `event_id` → events, `author_id` → auth.users | Event comments (500 char max) |
| `reports` | 7 | `id` (UUID) | `event_id` → events, `reporter_id` → auth.users | Content moderation reports |

### Indexes (14)

**Performance optimizations for common queries:**

- **Events** (3 indexes): Date/status filter (feed), creator lookup, chronological order
- **Likes** (2 indexes): Event lookup, user lookup
- **Participations** (2 indexes): Event lookup, user lookup
- **Comments** (2 indexes): Event lookup with order, author lookup
- **Reports** (2 indexes): Event lookup, reviewed filter
- **Profiles** (3 indexes): From migration 002 - class filter, updated_at, incomplete profiles

### RLS Policies (15 active + 4 future)

**Security rules enforced at database level (with Supabase best practices):**

- **Events** (4 policies): View approved/upcoming only, creator-only create/edit/delete
- **Likes** (3 policies): View all, like approved events only, unlike own only
- **Participations** (3 policies): View all, RSVP to approved events only, cancel own only
- **Comments** (3 policies): View on approved events, post on approved events, delete own only
- **Reports** (2 policies): View own reports, submit reports
- **Moderators** (4 policies - commented out): View all events/reports, update event status/reports (future feature when `user_roles` table exists)

**Security improvements applied:**
- All policies use `DROP POLICY IF EXISTS` before `CREATE POLICY` (PostgreSQL doesn't support `IF NOT EXISTS` for policies)
- All policies explicitly specify `TO authenticated` to prevent unintended anonymous access
- All `auth.uid()` calls wrapped with `(SELECT auth.uid())` per Supabase best practices

### Realtime (2 tables)

- **events**: Live updates when creator edits event details
- **comments**: Live comments appear instantly (<2s latency)

### Important Schema Changes

**1. Using existing `profiles` table instead of creating `users`:**
   - All foreign keys reference `auth.users(id)` directly
   - User profile data (name, class, avatar) comes from existing `profiles` table (migration 002)
   - No data duplication between auth and profile systems

**2. Comments table column rename:**
   - Column name changed from `text` to `content` to avoid confusion with PostgreSQL `TEXT` type
   - All Flutter code should use `content` field when querying comments

**3. Triggers for `updated_at`:**
   - Events table has auto-updating `updated_at` trigger using existing `update_updated_at_column()` function from migration 002

**4. Guarded Realtime publication:**
   - Publication changes wrapped in `DO $$ ... END $$` block to prevent errors if publication doesn't exist
   - Checks for existing tables in publication before adding

---

## Troubleshooting

### Issue: `npx supabase db push` fails with "No linked project"

**Solution**: Link your Supabase project:
```bash
npx supabase link --project-ref <your-project-id>
```

Get your project ID from Supabase Dashboard → Settings → General → Reference ID

### Issue: Migration fails with "relation already exists"

**Solution**: The migration is idempotent (uses `IF NOT EXISTS`). This is safe to ignore if tables already exist. If you want to reset:

```bash
# DANGER: This drops all data!
npx supabase db reset
```

**⚠️ WARNING**: Only use `db reset` in local development, never in production!

### Issue: RLS policies block all queries

**Solution**: Ensure you're authenticated when testing:
1. Check user is logged in via Supabase Auth
2. Verify `auth.uid()` returns a valid UUID
3. Test queries as authenticated user, not anonymous

For debugging, you can temporarily disable RLS (development only):
```sql
ALTER TABLE events DISABLE ROW LEVEL SECURITY;
```

**⚠️ CRITICAL**: Re-enable RLS before deploying:
```sql
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
```

### Issue: Realtime not working

**Solution**: Check Realtime is enabled:
```sql
SELECT tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime';
```

If `events` or `comments` are missing, manually add them:
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE events;
ALTER PUBLICATION supabase_realtime ADD TABLE comments;
```

---

## Next Steps

Once setup is complete:

1. ✅ **Verify** using the checklists above (6 tables, 14 indexes, 21 policies, 2 realtime)
2. ✅ **Notify Claude Code** that Supabase setup is done
3. ✅ **Continue implementation** - Phase 3 (User Stories) can now begin!

---

## Manual Setup (Old Method - Not Recommended)

<details>
<summary>Click to expand manual dashboard instructions (legacy, use CLI instead)</summary>

If CLI doesn't work, you can create tables manually via Supabase Dashboard:

1. Create each table using Table Editor
2. Add indexes via SQL Editor
3. Apply RLS policies via SQL Editor
4. Enable Realtime via Publications

**⚠️ NOT RECOMMENDED**: Manual setup takes 15-20 minutes and is error-prone. Use CLI instead!

</details>

---

---

## Security & Schema Fixes Applied (2025-11-02)

This migration has been **fully patched** to address all security and schema issues:

### ✅ Fixed Issues

1. **PostgreSQL Policy Syntax** - Changed from unsupported `CREATE POLICY IF NOT EXISTS` to `DROP POLICY IF EXISTS` + `CREATE POLICY` pattern
2. **Supabase Auth Best Practice** - Wrapped all `auth.uid()` calls with `(SELECT auth.uid())` per official Supabase guidelines
3. **Security Definer Function** - Commented out `is_moderator()` function until `user_roles` table exists (prevents execution errors)
4. **Policy Access Control** - Added explicit `TO authenticated` clause to all policies to prevent anonymous access
5. **Schema Conflict Resolution** - Uses existing `profiles` table instead of creating duplicate `users` table
6. **Column Naming** - Renamed `comments.text` to `comments.content` to avoid confusion with PostgreSQL `TEXT` type
7. **Auto-updating Timestamps** - Added trigger for `events.updated_at` using existing `update_updated_at_column()` function
8. **Realtime Publication Guards** - Wrapped `ALTER PUBLICATION` in `DO $$ ... END $$` block with existence checks
9. **Foreign Key Correctness** - All user references point to `auth.users(id)` (consistent with existing `profiles` table)

### 🛡️ Security Verification Checklist

Before running this migration in production, verify:

- [ ] All policies have `TO authenticated` clause (prevents anonymous queries)
- [ ] All policies use `(SELECT auth.uid())` instead of bare `auth.uid()`
- [ ] No `SECURITY DEFINER` functions without proper `REVOKE EXECUTE` statements
- [ ] All foreign keys reference correct tables (`auth.users` for user IDs)
- [ ] Triggers exist for all `updated_at` columns
- [ ] Realtime publication changes are idempotent (won't fail if already added)

---

**Setup Method**: Manual SQL Editor (CLI blocked by migration tracking conflict)
**Status**: ✅ Production-ready with security hardening
**Last Patched**: 2025-11-02
**Original Version**: 2025-01-02
