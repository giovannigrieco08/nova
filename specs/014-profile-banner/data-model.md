# Data Model: Profile Banner

**Feature**: 014-profile-banner
**Date**: 2025-01-20

## Overview

This feature extends the existing `profiles` table with a `banner_url` column. No new entities are required.

---

## Entity Changes

### Profile (Extended)

**Table**: `profiles`

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `banner_url` | TEXT | NULL | Supabase Storage public URL for profile banner image |

**Relationships**: None (self-contained URL reference)

---

## Database Migration

**File**: `supabase/migrations/037_add_profile_banner.sql`

```sql
-- Migration: 037_add_profile_banner.sql
-- Feature: 014-profile-banner
-- Description: Add banner_url column to profiles table

-- ============================================================================
-- Add banner_url column
-- ============================================================================

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS banner_url TEXT NULL;

-- Add comment for documentation
COMMENT ON COLUMN profiles.banner_url IS 'Supabase Storage public URL for profile banner image (3:1 aspect ratio, 1200x400px)';

-- ============================================================================
-- RLS: No changes needed
-- ============================================================================
-- Existing RLS policies already handle profile updates:
-- - Users can UPDATE their own profile
-- - Users can read visible profiles
-- The banner_url follows the same access pattern as avatar_url
```

---

## Domain Entity Update

**File**: `lib/features/profile/domain/entities/profile.dart`

```dart
@freezed
class Profile with _$Profile {
  const factory Profile({
    // ... existing fields ...

    /// Supabase Storage URL for profile banner
    /// NULL = show fallback gradient
    String? bannerUrl,

    // ... existing fields ...
  }) = _Profile;
}
```

**Extension Methods**:
```dart
extension ProfileExtensions on Profile {
  // ... existing methods ...

  /// Checks if banner is set (has valid URL)
  bool get hasBanner => bannerUrl != null && bannerUrl!.isNotEmpty;
}
```

---

## Data Model Update

**File**: `lib/features/profile/data/models/profile_model.dart`

```dart
@HiveType(typeId: 1)
@JsonSerializable()
class ProfileModel {
  // ... existing fields ...

  @HiveField(12)  // Next available HiveField ID
  @JsonKey(name: 'banner_url')
  final String? bannerUrl;

  // ... constructor, fromJson, toJson, copyWith updates ...
}
```

---

## Storage Structure

**Bucket**: `banners` (new public bucket)

**Path Pattern**: `{userId}/{userId}_{timestamp}.jpg`

**Example**:
```
banners/
  abc123-def456/
    abc123-def456_1705766400000.jpg
```

**Bucket Configuration** (Supabase Dashboard):
- Public: Yes (same as avatars)
- File size limit: 1MB
- Allowed MIME types: image/jpeg, image/png

---

## Validation Rules

| Rule | Value | Enforcement |
|------|-------|-------------|
| Max file size | 1MB (upload), 300KB (after compression) | Client-side |
| Aspect ratio | 3:1 (width:height) | Client-side cropper |
| Output dimensions | 1200 x 400 px | Client-side resize |
| Min input dimensions | 600 x 200 px | Client-side validation |
| Supported formats | JPEG, PNG, HEIC | Client-side |
| Output format | JPEG | Client-side conversion |

---

## State Transitions

```
┌─────────────┐     upload      ┌─────────────┐
│  No Banner  │ ───────────────>│ Has Banner  │
│  (null)     │                 │ (URL)       │
└─────────────┘                 └─────────────┘
       ^                               │
       │         remove                │
       └───────────────────────────────┘

       │                               │
       │         replace               │
       │<──────────────────────────────│
       └──────────── (via upload) ────>│
```

---

## JSON Serialization

**From Supabase (GET profile)**:
```json
{
  "user_id": "abc123",
  "full_name": "Giovanni Rossi",
  "avatar_url": "https://...storage.../avatars/abc123/...",
  "banner_url": "https://...storage.../banners/abc123/...",
  ...
}
```

**To Supabase (UPDATE profile)**:
```json
{
  "banner_url": "https://...storage.../banners/abc123/..."
}
```

**Remove banner**:
```json
{
  "banner_url": null
}
```

---

## Hive Local Cache

**Type ID**: 1 (existing ProfileModel)

**New Field ID**: 12 (banner_url)

**Cache Behavior**:
- Banner URL cached with profile
- Invalidated on profile update
- Image cached separately by CachedNetworkImage

---

## Index Considerations

No index needed for `banner_url`:
- Not used in WHERE clauses
- Not used for filtering/sorting
- Only retrieved as part of full profile fetch
