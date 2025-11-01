# Data Model: Profile Setup

**Feature**: 002-profile-setup | **Date**: 2025-11-01
**Database**: Supabase PostgreSQL 15+
**Purpose**: Define schema, relationships, validation rules, and RLS policies for profile data

---

## Entity: Profile

### Description

Represents a student user profile in the Nova school events platform. Each authenticated user has exactly one profile (one-to-one with `auth.users`). Profiles store minimal data per PRIVACY_FOUNDATION principle: name + class required, avatar/pronouns/bio optional.

### Table Schema

**Table Name**: `profiles`

```sql
CREATE TABLE profiles (
  -- Primary Key & Identity
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Required Fields
  full_name VARCHAR(50) NOT NULL
    CHECK (LENGTH(TRIM(full_name)) >= 2),

  class VARCHAR(20) NOT NULL
    CHECK (class IN (
      -- SCIENTIFICO (25 classes, excluding E)
      '1A Scientifico', '1B Scientifico', '1C Scientifico', '1D Scientifico', '1F Scientifico',
      '2A Scientifico', '2B Scientifico', '2C Scientifico', '2D Scientifico', '2F Scientifico',
      '3A Scientifico', '3B Scientifico', '3C Scientifico', '3D Scientifico', '3F Scientifico',
      '4A Scientifico', '4B Scientifico', '4C Scientifico', '4D Scientifico', '4F Scientifico',
      '5A Scientifico', '5B Scientifico', '5C Scientifico', '5D Scientifico', '5F Scientifico',
      -- CLASSICO (10 classes, A-B only)
      '1A Classico', '1B Classico',
      '2A Classico', '2B Classico',
      '3A Classico', '3B Classico',
      '4A Classico', '4B Classico',
      '5A Classico', '5B Classico'
    )),

  -- Optional Fields
  pronouns VARCHAR(30) NULL
    CHECK (pronouns IS NULL OR pronouns IN ('Lui', 'Lei', 'They', 'Altro', 'Preferisco non dire')),

  avatar_url TEXT NULL, -- Signed URL to Supabase Storage, 1-hour expiry

  bio VARCHAR(150) NULL
    CHECK (bio IS NULL OR LENGTH(bio) <= 150),

  -- Metadata
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Field Specifications

| Field | Type | Nullable | Constraints | Purpose |
|-------|------|----------|-------------|---------|
| `user_id` | UUID | ❌ | PRIMARY KEY, FK → auth.users(id) | Links to authentication system, one profile per user |
| `full_name` | VARCHAR(50) | ❌ | LENGTH >= 2, <= 50, trimmed | Student's full name (auto-populated from email or manual entry) |
| `class` | VARCHAR(20) | ❌ | CHECK (one of 35 values) | Student's school class, required for protected actions (create event, comment, chat) |
| `pronouns` | VARCHAR(30) | ✅ | CHECK (one of 5 values or NULL) | Optional pronouns (NULL = "Non specificato"), opt-in for inclusivity |
| `avatar_url` | TEXT | ✅ | Signed URL format | Supabase Storage signed URL (1-hour expiry), NULL = show colored initials |
| `bio` | VARCHAR(150) | ✅ | MAX LENGTH 150 | Optional bio text, sanitized (no HTML, no URLs) |
| `created_at` | TIMESTAMPTZ | ❌ | DEFAULT NOW() | Profile creation timestamp (never changes) |
| `updated_at` | TIMESTAMPTZ | ❌ | AUTO-UPDATED | Last update timestamp (auto-updated via trigger) |

### Validation Rules

**Name Validation (FR-001b)**:
- Regex: `^[a-zA-Z\u00C0-\u017F\s'-]{2,50}$`
- Allows: Letters (including accented like à, è, ì, ò, ù), spaces, hyphens, apostrophes
- Disallows: Numbers, special symbols (except `-` and `'`)
- Example valid: "Giovanni Rossi", "Maria D'Angelo", "François Müller"
- Example invalid: "User123", "Name@2024"

**Class Validation (FR-002)**:
- Must match one of 35 values exactly (enforced by CHECK constraint)
- Format: `{number}{letter} {track}` (e.g., "3A Scientifico", "2B Classico")
- Case-sensitive (use exact casing in database)

**Pronouns Validation (FR-007)**:
- NULL allowed (represents "Non specificato", not stored in DB)
- If not NULL, must be one of: "Lui", "Lei", "They", "Altro", "Preferisco non dire"

**Bio Validation (FR-008, SEC-002)**:
- Max 150 characters (enforced client + server)
- Sanitized: Strip HTML tags, remove URLs, remove `<script>` tags
- Allowed: Letters, numbers, spaces, basic punctuation (.,!?'"-), common emojis (whitelist: 🎨🚀💡📚)
- Regex: `^[a-zA-Z0-9\s\u00C0-\u017F.,!?'"-🎨🚀💡📚]*$`

### Indexes

```sql
-- Primary key index (automatic)
-- user_id PRIMARY KEY → B-tree index

-- Index on class for filtering/search
CREATE INDEX idx_profiles_class ON profiles(class);

-- Index on updated_at for recent profiles query
CREATE INDEX idx_profiles_updated_at ON profiles(updated_at DESC);

-- Partial index for incomplete profiles (class IS NULL)
CREATE INDEX idx_profiles_incomplete ON profiles(user_id) WHERE class IS NULL;
```

**Rationale**:
- `idx_profiles_class`: Enables fast filtering by class (e.g., "show all students in 3A Scientifico")
- `idx_profiles_updated_at`: Supports "recently updated profiles" queries (admin dashboard)
- `idx_profiles_incomplete`: Fast lookup for users who skipped setup (WHERE class IS NULL)

### Triggers

**Auto-Update `updated_at` Timestamp**:

```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_profiles_updated_at
BEFORE UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();
```

---

## Row-Level Security (RLS) Policies

**Enable RLS**:
```sql
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
```

### Policy 1: Read Own Profile

**Purpose**: Users can SELECT their own profile data only.

```sql
CREATE POLICY "Users can read own profile"
ON profiles
FOR SELECT
USING (auth.uid() = user_id);
```

**Validation Test**:
```sql
-- As user A (auth.uid() = 'aaa...')
SELECT * FROM profiles WHERE user_id = 'aaa...'; -- ✅ PASS (own profile)
SELECT * FROM profiles WHERE user_id = 'bbb...'; -- ❌ FAIL (other user's profile)
```

### Policy 2: Read Profiles of Verified Students

**Purpose**: Authenticated students can view other students' profiles (for events, comments).

```sql
CREATE POLICY "Students can read verified profiles"
ON profiles
FOR SELECT
USING (
  auth.email() LIKE '%@galileimoro.edu.it'
  AND EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = profiles.user_id
    AND auth.users.email LIKE '%@galileimoro.edu.it'
  )
);
```

**Rationale**: Enables social features (view event creator's profile, comment author's avatar) while restricting to verified @galileimoro.edu.it students only (PRIVACY_FOUNDATION).

### Policy 3: Insert Own Profile (One-Time)

**Purpose**: User can create their own profile during initial setup.

```sql
CREATE POLICY "Users can insert own profile"
ON profiles
FOR INSERT
WITH CHECK (auth.uid() = user_id);
```

**Validation Test**:
```sql
-- As user A (auth.uid() = 'aaa...')
INSERT INTO profiles (user_id, full_name, class)
VALUES ('aaa...', 'Giovanni Rossi', '3A Scientifico'); -- ✅ PASS

INSERT INTO profiles (user_id, full_name, class)
VALUES ('bbb...', 'Other User', '3A Scientifico'); -- ❌ FAIL (not own user_id)
```

### Policy 4: Update Own Profile

**Purpose**: Users can update their own profile fields only.

```sql
CREATE POLICY "Users can update own profile"
ON profiles
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
```

**Validation Test**:
```sql
-- As user A (auth.uid() = 'aaa...')
UPDATE profiles
SET bio = 'New bio text'
WHERE user_id = 'aaa...'; -- ✅ PASS (own profile)

UPDATE profiles
SET bio = 'Hacked bio'
WHERE user_id = 'bbb...'; -- ❌ FAIL (other user's profile)
```

### Policy 5: Delete Own Profile (GDPR Right to Erasure)

**Purpose**: Users can delete their own profile (soft delete handled by app, hard delete via RLS).

```sql
CREATE POLICY "Users can delete own profile"
ON profiles
FOR DELETE
USING (auth.uid() = user_id);
```

**Rationale**: Supports GDPR Right to Erasure (Art. 17). User triggers delete via Settings → Privacy → Delete Account, which hard-deletes profile after 30-day grace period.

---

## Relationships

### 1. Profile ↔ Auth User (One-to-One)

```
profiles.user_id → auth.users.id (FK, ON DELETE CASCADE)
```

**Cardinality**: One-to-One (each auth user has exactly one profile)

**Cascade Behavior**:
- If user deletes their auth account → profile auto-deleted (CASCADE)
- If profile deleted → auth user remains (for re-registration)

### 2. Profile ↔ Events (One-to-Many)

```
events.creator_id → profiles.user_id (FK)
```

**Cardinality**: One-to-Many (one profile can create many events)

**Business Rule**: User must have complete profile (`class IS NOT NULL`) to create events (enforced in app logic, not FK constraint).

### 3. Profile ↔ Comments (One-to-Many)

```
comments.user_id → profiles.user_id (FK)
```

**Cardinality**: One-to-Many (one profile can write many comments)

**Business Rule**: User must have complete profile to comment (enforced in app logic).

### 4. Profile ↔ Likes (One-to-Many)

```
likes.user_id → profiles.user_id (FK)
```

**Cardinality**: One-to-Many (one profile can like many items)

**Business Rule**: Likes are public actions, no profile completion requirement (viewing content is free).

---

## State Diagram: Profile Lifecycle

```
┌──────────────┐
│ Auth Created │ (User completes magic link authentication)
│  (no profile)│
└──────┬───────┘
       │
       ▼
┌──────────────────┐
│ Profile Created  │ (Email parsing → name auto-populated)
│  (class = NULL)  │ (User lands on setup screen)
└──────┬───────────┘
       │
       ├─────────────────────────────┐
       │                             │
       ▼ (Skip button)                ▼ (Complete setup)
┌──────────────────┐           ┌──────────────────┐
│ Incomplete       │           │ Complete         │
│  (class = NULL)  │           │  (class != NULL) │
│  (can view only) │           │  (full access)   │
└──────┬───────────┘           └──────┬───────────┘
       │                             │
       │ (Forced completion)          │
       └─────────────┬────────────────┘
                     │
                     ▼
              ┌──────────────┐
              │ Active User  │ (Can create events, comment, chat)
              │              │
              └──────┬───────┘
                     │
                     ▼ (Settings → Delete Account)
              ┌──────────────┐
              │ Soft-Deleted │ (30-day grace period)
              │              │
              └──────┬───────┘
                     │
                     ▼ (After 30 days)
              ┌──────────────┐
              │ Hard-Deleted │ (Profile + auth.user removed)
              └──────────────┘
```

### State Transitions

| From State | Event | To State | Actions |
|------------|-------|----------|---------|
| Auth Created | Profile insert | Incomplete | Parse email → populate name, set class = NULL |
| Incomplete | Skip setup | Incomplete | Redirect to Feed, block protected actions |
| Incomplete | Complete setup | Complete | Update class, redirect to Feed (replace navigation) |
| Complete | Edit profile | Complete | Update fields (auto-save), show toast |
| Complete | Delete account | Soft-Deleted | Set deleted_at timestamp, hide from queries |
| Soft-Deleted | 30 days elapsed | Hard-Deleted | DELETE FROM profiles, CASCADE to auth.users |

---

## Validation Functions (PostgreSQL)

### Email Parsing Function

**Purpose**: Auto-populate name from email (e.g., `giovanni.rossi@galileimoro.edu.it` → "Giovanni Rossi")

```sql
CREATE OR REPLACE FUNCTION parse_name_from_email(email TEXT)
RETURNS TEXT AS $$
DECLARE
  local_part TEXT;
  name_parts TEXT[];
  parsed_name TEXT;
BEGIN
  -- Extract local part (before @)
  local_part := SPLIT_PART(email, '@', 1);

  -- Check if format is firstname.lastname
  IF local_part LIKE '%.%' THEN
    name_parts := STRING_TO_ARRAY(local_part, '.');

    -- Capitalize each part
    parsed_name := INITCAP(name_parts[1]) || ' ' || INITCAP(name_parts[2]);

    RETURN parsed_name;
  ELSE
    -- Single word (like student123), return empty for manual entry
    RETURN NULL;
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
```

**Usage**:
```sql
SELECT parse_name_from_email('giovanni.rossi@galileimoro.edu.it'); -- "Giovanni Rossi"
SELECT parse_name_from_email('student123@galileimoro.edu.it');     -- NULL
```

### Profile Completion Check Function

**Purpose**: Check if profile is complete (name AND class exist)

```sql
CREATE OR REPLACE FUNCTION is_profile_complete(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  profile_class VARCHAR(20);
BEGIN
  SELECT class INTO profile_class
  FROM profiles
  WHERE user_id = p_user_id;

  RETURN profile_class IS NOT NULL;
END;
$$ LANGUAGE plpgsql STABLE;
```

**Usage**:
```sql
SELECT is_profile_complete(auth.uid()); -- true or false
```

---

## Migration Script

**File**: `supabase/migrations/002_create_profiles_table.sql`

```sql
-- Create profiles table
CREATE TABLE profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name VARCHAR(50) NOT NULL CHECK (LENGTH(TRIM(full_name)) >= 2),
  class VARCHAR(20) NOT NULL CHECK (class IN (
    '1A Scientifico', '1B Scientifico', '1C Scientifico', '1D Scientifico', '1F Scientifico',
    '2A Scientifico', '2B Scientifico', '2C Scientifico', '2D Scientifico', '2F Scientifico',
    '3A Scientifico', '3B Scientifico', '3C Scientifico', '3D Scientifico', '3F Scientifico',
    '4A Scientifico', '4B Scientifico', '4C Scientifico', '4D Scientifico', '4F Scientifico',
    '5A Scientifico', '5B Scientifico', '5C Scientifico', '5D Scientifico', '5F Scientifico',
    '1A Classico', '1B Classico', '2A Classico', '2B Classico', '3A Classico', '3B Classico',
    '4A Classico', '4B Classico', '5A Classico', '5B Classico'
  )),
  pronouns VARCHAR(30) NULL CHECK (pronouns IS NULL OR pronouns IN ('Lui', 'Lei', 'They', 'Altro', 'Preferisco non dire')),
  avatar_url TEXT NULL,
  bio VARCHAR(150) NULL CHECK (bio IS NULL OR LENGTH(bio) <= 150),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_profiles_class ON profiles(class);
CREATE INDEX idx_profiles_updated_at ON profiles(updated_at DESC);
CREATE INDEX idx_profiles_incomplete ON profiles(user_id) WHERE class IS NULL;

-- Create trigger for auto-updating updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_profiles_updated_at
BEFORE UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can read own profile"
ON profiles FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Students can read verified profiles"
ON profiles FOR SELECT
USING (
  auth.email() LIKE '%@galileimoro.edu.it'
  AND EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = profiles.user_id
    AND auth.users.email LIKE '%@galileimoro.edu.it'
  )
);

CREATE POLICY "Users can insert own profile"
ON profiles FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own profile"
ON profiles FOR DELETE
USING (auth.uid() = user_id);

-- Create utility functions
CREATE OR REPLACE FUNCTION parse_name_from_email(email TEXT)
RETURNS TEXT AS $$
DECLARE
  local_part TEXT;
  name_parts TEXT[];
  parsed_name TEXT;
BEGIN
  local_part := SPLIT_PART(email, '@', 1);

  IF local_part LIKE '%.%' THEN
    name_parts := STRING_TO_ARRAY(local_part, '.');
    parsed_name := INITCAP(name_parts[1]) || ' ' || INITCAP(name_parts[2]);
    RETURN parsed_name;
  ELSE
    RETURN NULL;
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION is_profile_complete(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  profile_class VARCHAR(20);
BEGIN
  SELECT class INTO profile_class
  FROM profiles
  WHERE user_id = p_user_id;

  RETURN profile_class IS NOT NULL;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON TABLE profiles IS 'Student user profiles for Nova school events platform';
COMMENT ON COLUMN profiles.user_id IS 'Links to auth.users, one profile per user';
COMMENT ON COLUMN profiles.full_name IS 'Student full name (auto-parsed from email or manual)';
COMMENT ON COLUMN profiles.class IS 'School class (35 values: SCIENTIFICO + CLASSICO)';
COMMENT ON COLUMN profiles.pronouns IS 'Optional pronouns (NULL = "Non specificato")';
COMMENT ON COLUMN profiles.avatar_url IS 'Supabase Storage signed URL (1-hour expiry)';
COMMENT ON COLUMN profiles.bio IS 'Optional bio text (max 150 chars, sanitized)';
```

---

## Test Data (Development Only)

```sql
-- Insert test profiles (use real auth.users IDs from Supabase dashboard)
INSERT INTO profiles (user_id, full_name, class, pronouns, bio) VALUES
('11111111-1111-1111-1111-111111111111', 'Giovanni Rossi', '3A Scientifico', 'Lui', 'Appassionato di fisica e matematica 🎨'),
('22222222-2222-2222-2222-222222222222', 'Maria Bianchi', '3A Classico', 'Lei', 'Amo la filosofia e la letteratura 📚'),
('33333333-3333-3333-3333-333333333333', 'Alex Verdi', '3A Scientifico', 'They', NULL),
('44444444-4444-4444-4444-444444444444', 'Incomplete User', NULL, NULL, NULL); -- Skipped setup
```

**Validation Queries**:
```sql
-- Count total profiles
SELECT COUNT(*) FROM profiles; -- 4

-- Count incomplete profiles
SELECT COUNT(*) FROM profiles WHERE class IS NULL; -- 1

-- Get profile with avatar initials color
SELECT
  user_id,
  full_name,
  SUBSTRING(UPPER(full_name) FROM 1 FOR 1) || SUBSTRING(UPPER(SPLIT_PART(full_name, ' ', 2)) FROM 1 FOR 1) AS initials,
  ASCII(UPPER(full_name)) % 17 AS color_index
FROM profiles;
```

---

**Data Model Complete** - Proceed to Phase 1: API Contracts.
