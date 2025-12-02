# Data Model: Sistema Profilo Utente

**Feature**: 006-user-profile
**Date**: 2025-01-22
**References**: [spec.md](./spec.md), [research.md](./research.md)

---

## Overview

Questo documento definisce il data model completo per il sistema Profilo Utente Nova. Include entità, attributi, relazioni, validazioni, e state transitions. Il model è technology-agnostic ma assume PostgreSQL 15+ via Supabase Cloud con Row-Level Security (RLS) policies.

---

## Core Entities

### 1. Profile

**Purpose**: Identità digitale studente all'interno di Nova. Un profilo per utente (1:1 con auth.users).

**Attributes**:

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, REFERENCES auth.users(id) ON DELETE CASCADE | User ID (matches Supabase Auth user) |
| `email` | TEXT | NOT NULL, UNIQUE | Email scuola @galileimoro.edu.it (inherited from auth) |
| `full_name` | TEXT | NOT NULL, CHECK (LENGTH(full_name) BETWEEN 2 AND 50) | Nome completo (min 2 parole: nome + cognome) |
| `username` | TEXT | NOT NULL, UNIQUE, CHECK (LENGTH(username) BETWEEN 3 AND 50) | Auto-generated formato nome.cognome (read-only) |
| `class` | TEXT | NULL, CHECK (class ~ '^[1-5][A-Z]$' OR class = 'Altro') | Classe studente (es. "5A", "4B", "Altro") |
| `bio` | TEXT | NULL, CHECK (LENGTH(bio) <= 150) | Bio opzionale max 150 char, supporta emoji/unicode |
| `avatar_url` | TEXT | NULL | URL Supabase Storage: `avatars/{user_id}/avatar.jpg` |
| `role` | TEXT | NOT NULL, DEFAULT 'student', CHECK (role IN ('student', 'moderator', 'admin')) | Ruolo utente |
| `profile_visible` | BOOLEAN | NOT NULL, DEFAULT TRUE | Privacy toggle: se FALSE, profilo nascosto ad altri |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Data iscrizione |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Ultima modifica profilo |
| `deleted_at` | TIMESTAMPTZ | NULL | Soft delete: se NOT NULL, account in grace period (30 giorni) |

**Indexes**:
- `PRIMARY KEY (id)`
- `UNIQUE INDEX idx_profiles_username ON profiles(username)` - Fast username lookup
- `INDEX idx_profiles_deleted_at ON profiles(deleted_at)` - Fast soft delete queries (hard delete cron job)

**Validations** (enforced at application + database level):
- `full_name`: Min 2 caratteri, max 50, deve contenere almeno 2 parole (nome + cognome) → Regex: `^[A-Za-zÀ-ÿ]+(?: [A-Za-zÀ-ÿ]+)+$`
- `username`: Auto-generated, formato `nome.cognome`, lowercase, accents removed, collision handled (nome.cognome2)
- `class`: Pattern `^[1-5][A-Z]$` (1A-5Z) OR "Altro"
- `bio`: Max 150 char, NO URLs (sanitized), NO HTML tags (XSS prevention)
- `email`: Domain must be `@galileimoro.edu.it` (enforced at signup)

**State Transitions**:
```
┌──────────────┐
│ Profile      │
│ Created      │  (created_at set, deleted_at NULL)
└──────┬───────┘
       │
       ├──> Edit Profile (update full_name, class, bio, avatar_url → updated_at refreshed)
       │
       ├──> Toggle Visibility (profile_visible = TRUE/FALSE)
       │
       └──> Delete Account
            │
            ├──> Soft Delete (deleted_at = NOW(), grace period 30 giorni)
            │    │
            │    ├──> Reactivate (deleted_at = NULL) [within 30 days]
            │    │
            │    └──> Hard Delete (DELETE FROM profiles) [after 30 days, cron job]
            │
            └──> Events created remain visible (creator = "Utente eliminato")
```

**RLS Policies**:
```sql
-- SELECT: Public can view profiles where profile_visible = TRUE AND deleted_at IS NULL
CREATE POLICY "Public profiles are viewable by everyone"
  ON profiles FOR SELECT
  USING (profile_visible = TRUE AND deleted_at IS NULL);

-- SELECT: Own profile always viewable (even if hidden or soft-deleted)
CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

-- UPDATE: Users can only update own profile (and cannot modify username, email, role)
CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- DELETE: Users can soft-delete own account (set deleted_at)
-- Hard delete only via cron job (pg_cron or Supabase Edge Function scheduled)
CREATE POLICY "Users can soft delete own account"
  ON profiles FOR UPDATE
  USING (auth.uid() = id AND deleted_at IS NULL)
  WITH CHECK (auth.uid() = id);
```

---

### 2. Avatar (Storage Object)

**Purpose**: File immagine profilo utente uploadato a Supabase Storage bucket `avatars`.

**Storage Path**: `avatars/{user_id}/avatar.jpg`
- Example: `avatars/abc123-def456-.../avatar.jpg`
- Single file per user (overwrite on update)

**Attributes** (metadata):

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `user_id` | UUID | Part of path `avatars/{user_id}/` | Owner user ID |
| `file_name` | TEXT | `avatar.jpg` (fixed name) | Always `avatar.jpg` (simplifies caching) |
| `content_type` | TEXT | `image/webp`, `image/jpeg`, `image/png` | MIME type |
| `size_bytes` | INTEGER | CHECK (size_bytes <= 512000) | Max 500KB (512000 bytes) after compression |
| `created_at` | TIMESTAMPTZ | Supabase Storage auto | Upload timestamp |
| `updated_at` | TIMESTAMPTZ | Supabase Storage auto | Last update timestamp |

**Validations**:
- **Client-side compression**: 2MB original → max 500KB WebP (flutter_image_compress)
- **Dimensions**: Min 200×200px (pre-upload check), Max 2MB original file
- **Format**: JPG, PNG, WebP accepted (converted to WebP on compression)
- **Crop**: Circular crop via image_cropper (aspect ratio 1:1)

**RLS Policies** (Supabase Storage bucket `avatars`):
```sql
-- INSERT/UPDATE: Only owner can upload/update own avatar
CREATE POLICY "Users can upload own avatar"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::TEXT);

CREATE POLICY "Users can update own avatar"
  ON storage.objects FOR UPDATE
  USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::TEXT);

-- SELECT: Public read access (for caching and display in profile)
CREATE POLICY "Avatars are publicly accessible"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

-- DELETE: Only owner can delete own avatar
CREATE POLICY "Users can delete own avatar"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::TEXT);
```

**Caching Strategy**:
- Browser: `Cache-Control: public, max-age=604800` (7 giorni)
- App: Local cache (Hive) avatar URL per 7 giorni
- Invalidation: Append `?v={timestamp}` to URL after upload (cache busting)

---

### 3. ProfileStats (Computed Aggregate)

**Purpose**: Statistiche profilo (eventi creati, partecipazioni). Computed on-demand, NOT stored.

**Attributes**:

| Field | Type | Source | Description |
|-------|------|--------|-------------|
| `user_id` | UUID | Parameter | User ID |
| `events_created_count` | INTEGER | `SELECT COUNT(*) FROM events WHERE creator_id = user_id AND status = 'approved'` | Numero eventi creati e approvati |
| `participations_count` | INTEGER | `SELECT COUNT(*) FROM participations WHERE user_id = user_id` | Numero partecipazioni confermate |

**Computation**:
```sql
CREATE OR REPLACE FUNCTION get_profile_stats(user_id UUID)
RETURNS TABLE(events_created_count INTEGER, participations_count INTEGER) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE((SELECT COUNT(*)::INTEGER FROM events WHERE creator_id = user_id AND status = 'approved'), 0) AS events_created_count,
    COALESCE((SELECT COUNT(*)::INTEGER FROM participations WHERE participations.user_id = get_profile_stats.user_id), 0) AS participations_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**Performance**:
- Indexed: `events.creator_id`, `participations.user_id` → Fast COUNT queries
- Cache client-side: Stats cached 5 minuti (Riverpod provider TTL)
- Alternative: Materialized view refreshed ogni 5 minuti (future optimization se slow)

---

### 4. GDPRExport (Temporary Object)

**Purpose**: Export dati utente in JSON format per GDPR Right to Access (Art. 15).

**Storage Path**: `gdpr-exports/{user_id}/export_{timestamp}.json`
- Example: `gdpr-exports/abc123-.../export_2025-01-22T14-30-00.json`
- Link expira dopo 24h (Supabase Storage signed URL)

**Schema** (vedi [contracts/gdpr-export-schema.json](./contracts/gdpr-export-schema.json)):

| Section | Type | Source | Description |
|---------|------|--------|-------------|
| `export_version` | STRING | `"1.0.0"` | Schema version |
| `export_date` | ISO 8601 | `NOW()` | Export generation timestamp |
| `user_id` | UUID | `auth.uid()` | User ID |
| `profile` | OBJECT | `profiles.*` | Full profile data |
| `events_created` | ARRAY | `events WHERE creator_id = user_id` | All events created (approved + rejected) |
| `participations` | ARRAY | `participations WHERE user_id = user_id` | All event participations |
| `comments` | ARRAY | `comments WHERE user_id = user_id` | All comments made |
| `chat_messages` | ARRAY | `chat_messages WHERE user_id = user_id AND created_at > NOW() - INTERVAL '24 hours'` | Last 24h chat (ephemeral by design) |

**Generation Flow**:
1. User tap "Scarica i tuoi dati" in Settings → Privacy
2. Supabase Edge Function `export-user-data` triggered (async)
3. Function queries all data (profile, events, participations, comments, chat)
4. Generates JSON (pretty-printed)
5. Uploads to Storage `gdpr-exports/{user_id}/export_{timestamp}.json`
6. Generates signed URL (24h expiry)
7. Sends in-app notification with download link
8. Target: <10s total (SC-004 success criteria)

**Cleanup**: Cron job deletes exports older than 30 giorni (GDPR retention limit).

---

## Relationships

### Profile ↔ Event (One-to-Many)

```
Profile (1) ────< (N) Event
  ↓                    ↓
  id                   creator_id
```

- One profile creates many events
- Foreign key: `events.creator_id → profiles.id` (ON DELETE SET DEFAULT 'deleted_user')
- When profile deleted (soft or hard): `events.creator_id` updated to special UUID `'00000000-0000-0000-0000-000000000000'` (represents "Utente eliminato")

### Profile ↔ Participation (One-to-Many)

```
Profile (1) ────< (N) Participation
  ↓                    ↓
  id                   user_id
```

- One profile has many participations
- Foreign key: `participations.user_id → profiles.id` (ON DELETE CASCADE)
- When profile deleted: All participations deleted (privacy - user left community)

### Profile ↔ Comment (One-to-Many)

```
Profile (1) ────< (N) Comment
  ↓                    ↓
  id                   user_id
```

- One profile writes many comments
- Foreign key: `comments.user_id → profiles.id` (ON DELETE CASCADE)
- When profile deleted: Comments deleted (privacy)

### Profile ↔ Avatar (One-to-One)

```
Profile (1) ──── (0..1) Avatar
  ↓                      ↓
  id                     avatars/{user_id}/avatar.jpg
```

- One profile has zero or one avatar
- Relationship: `profiles.avatar_url` stores Storage URL
- When profile deleted: Avatar file deleted from Storage (cleanup job)

---

## Edge Cases & Business Rules

### Username Collision Handling

```sql
-- Function: generate_unique_username(email TEXT) → TEXT
-- Logic:
--   1. Extract part before @ → "marco.rossi@galileimoro.edu.it" → "marco.rossi"
--   2. Lowercase, remove accents (è→e, à→a)
--   3. Check if "marco.rossi" exists in profiles.username
--   4. If exists: append 2 → "marco.rossi2"
--   5. If "marco.rossi2" exists: append 3 → "marco.rossi3"
--   6. Repeat until unique found
--   7. Return unique username

-- Trigger: Auto-run on profile INSERT (after Supabase Auth creates user)
CREATE TRIGGER trigger_set_username BEFORE INSERT ON profiles
FOR EACH ROW EXECUTE FUNCTION set_username_on_signup();
```

### Soft Delete Grace Period

```sql
-- User taps "Elimina account" → deleted_at = NOW()
-- Profile hidden from public queries (RLS policy: WHERE deleted_at IS NULL)
-- Events created remain visible (creator = "Utente eliminato")
-- User can reactivate within 30 days: UPDATE profiles SET deleted_at = NULL WHERE id = auth.uid()

-- Cron job (daily at 3am UTC):
DELETE FROM profiles WHERE deleted_at < NOW() - INTERVAL '30 days';
-- Also delete avatar from Storage: Storage.deleteFile(`avatars/${user_id}/avatar.jpg`)
```

### Profile Visibility Toggle

```sql
-- User toggles "Profilo visibile" OFF → profile_visible = FALSE
-- Public RLS policy: WHERE profile_visible = TRUE AND deleted_at IS NULL
-- Result: Other users see "Profilo non disponibile"
-- BUT: Events created still visible in feed (separation contenuto/identità)
-- Own profile still viewable (RLS: auth.uid() = id override)
```

### Bio Sanitization

```dart
// Client-side (Flutter) + Server-side (PostgreSQL function)
String sanitizeBio(String bio) {
  bio = bio.replaceAll(RegExp(r'http[s]?://\S+'), '');  // Remove URLs
  bio = bio.replaceAll(RegExp(r'<[^>]*>'), '');        // Remove HTML tags
  if (bio.length > 150) bio = bio.substring(0, 150);   // Truncate
  return bio.trim();
}

-- PostgreSQL function:
CREATE OR REPLACE FUNCTION sanitize_bio() RETURNS TRIGGER AS $$
BEGIN
  NEW.bio := REGEXP_REPLACE(NEW.bio, 'http[s]?://\S+', '', 'g');  -- Remove URLs
  NEW.bio := REGEXP_REPLACE(NEW.bio, '<[^>]*>', '', 'g');         -- Remove HTML
  IF LENGTH(NEW.bio) > 150 THEN
    NEW.bio := SUBSTRING(NEW.bio, 1, 150);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_sanitize_bio BEFORE INSERT OR UPDATE ON profiles
FOR EACH ROW EXECUTE FUNCTION sanitize_bio();
```

### Avatar Upload Failure Rollback

```dart
// Optimistic UI: Display avatar immediately, rollback if upload fails
try {
  // 1. Compress avatar (2MB → 500KB WebP)
  final compressedFile = await compressAvatar(pickedFile);

  // 2. Upload to Storage
  final String avatarPath = 'avatars/${userId}/avatar.jpg';
  await supabase.storage.from('avatars').upload(avatarPath, compressedFile, upsert: true);

  // 3. Get public URL
  final String publicUrl = supabase.storage.from('avatars').getPublicUrl(avatarPath);

  // 4. Update profile.avatar_url
  await supabase.from('profiles').update({'avatar_url': publicUrl}).eq('id', userId);
} catch (e) {
  // Rollback optimistic UI, show error toast
  setState(() => _avatarUrl = previousAvatarUrl);
  showErrorToast('Errore caricamento immagine. Riprova.');
}
```

---

## Performance Considerations

### Indexes for Fast Queries

```sql
-- Profile lookup by username (tap @username in chat)
CREATE INDEX idx_profiles_username ON profiles(username);

-- Soft delete cron job (daily hard delete)
CREATE INDEX idx_profiles_deleted_at ON profiles(deleted_at) WHERE deleted_at IS NOT NULL;

-- Events created count (profile stats)
CREATE INDEX idx_events_creator_id ON events(creator_id) WHERE status = 'approved';

-- Participations count (profile stats)
CREATE INDEX idx_participations_user_id ON participations(user_id);
```

### Caching Strategy

| Data | Cache Duration | Invalidation |
|------|----------------|--------------|
| **Profile data** | 24h (Hive local) | On edit profile save |
| **Avatar URL** | 7 giorni (Hive + CDN) | Append `?v={timestamp}` after upload |
| **Profile stats** | 5 minuti (Riverpod TTL) | Auto-refresh every 5min |
| **Other user profile** | 1h (Riverpod TTL) | Manual refresh pull-to-refresh |

### N+1 Query Prevention

```sql
-- BAD: N+1 query for feed with creator names
SELECT * FROM events;  -- Then for each event: SELECT full_name FROM profiles WHERE id = creator_id

-- GOOD: Single JOIN query
SELECT
  events.*,
  profiles.full_name AS creator_name,
  profiles.avatar_url AS creator_avatar,
  profiles.username AS creator_username
FROM events
LEFT JOIN profiles ON events.creator_id = profiles.id
WHERE events.status = 'approved'
ORDER BY events.created_at DESC;
```

---

## Migration Script Outline

```sql
-- supabase/migrations/006_user_profile_system.sql

-- 1. Extend existing profiles table (created by Supabase Auth)
ALTER TABLE profiles
  ADD COLUMN full_name TEXT,
  ADD COLUMN username TEXT UNIQUE,
  ADD COLUMN class TEXT CHECK (class ~ '^[1-5][A-Z]$' OR class = 'Altro' OR class IS NULL),
  ADD COLUMN bio TEXT CHECK (LENGTH(bio) <= 150),
  ADD COLUMN avatar_url TEXT,
  ADD COLUMN role TEXT NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'moderator', 'admin')),
  ADD COLUMN profile_visible BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN deleted_at TIMESTAMPTZ;

-- 2. Create indexes
CREATE INDEX idx_profiles_username ON profiles(username);
CREATE INDEX idx_profiles_deleted_at ON profiles(deleted_at) WHERE deleted_at IS NOT NULL;

-- 3. Create username generation function + trigger
-- [See "Username Collision Handling" section above]

-- 4. Create bio sanitization trigger
-- [See "Bio Sanitization" section above]

-- 5. Create Supabase Storage bucket 'avatars'
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', TRUE);

-- 6. Create RLS policies (profiles table + storage.objects)
-- [See "RLS Policies" sections above]

-- 7. Create profile stats function
-- [See "ProfileStats" section above]

-- 8. Create soft delete cleanup function (pg_cron job)
-- SELECT cron.schedule('hard-delete-profiles', '0 3 * * *', $$ DELETE FROM profiles WHERE deleted_at < NOW() - INTERVAL '30 days' $$);
```

---

## Summary

**Entities**: 4 (Profile, Avatar, ProfileStats computed, GDPRExport temporary)
**Key Relationships**: Profile ↔ Event/Participation/Comment (1:N), Profile ↔ Avatar (1:0..1)
**Validations**: Name length, username format, bio max 150, avatar size 500KB
**State Transitions**: Create → Edit → Soft Delete (grace period) → Hard Delete OR Reactivate
**Performance**: Indexes on username/deleted_at/creator_id, caching 24h profile / 7d avatar / 5min stats
**GDPR**: Export JSON includes all data, soft delete with 30-day grace, hard delete cleanup

**Ready for Phase 1 Next Step**: Generate API contracts (OpenAPI) and quickstart scenarios.
