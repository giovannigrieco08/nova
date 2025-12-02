# Data Model: Sistema Ripetizioni

**Feature Branch**: `012-tutoring-system`
**Date**: 2025-12-01
**Status**: Complete

---

## Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          profiles                                │
│  (existing table)                                               │
├─────────────────────────────────────────────────────────────────┤
│  id: UUID (PK)                                                  │
│  email: TEXT                                                    │
│  full_name: TEXT                                                │
│  username: TEXT                                                 │
│  class_year: TEXT                                               │
│  avatar_url: TEXT                                               │
│  ...                                                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ 1:1 (FK user_id)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       tutor_profiles                            │
│  (new table)                                                    │
├─────────────────────────────────────────────────────────────────┤
│  id: UUID (PK)                                                  │
│  user_id: UUID (FK → profiles.id, UNIQUE)                       │
│  bio: TEXT (max 200 chars)                                      │
│  subjects: TEXT[] (max 5 items)                                 │
│  price_per_hour: DECIMAL (default 0)                            │
│  availability_days: TEXT[] (e.g., ['monday', 'wednesday'])      │
│  time_slot: TEXT (e.g., '15:00-18:00')                          │
│  whatsapp_phone: TEXT (nullable)                                │
│  instagram_username: TEXT (nullable)                            │
│  rating: DECIMAL (default 0.0, future use)                      │
│  total_reviews: INTEGER (default 0, future use)                 │
│  is_active: BOOLEAN (default true)                              │
│  created_at: TIMESTAMPTZ                                        │
│  updated_at: TIMESTAMPTZ                                        │
├─────────────────────────────────────────────────────────────────┤
│  CONSTRAINT: whatsapp_phone IS NOT NULL OR                      │
│              instagram_username IS NOT NULL                     │
│  INDEX: GIN(subjects) for fast subject filtering                │
│  INDEX: BTREE(is_active) for active tutor queries               │
└─────────────────────────────────────────────────────────────────┘
```

---

## Entities

### TutorProfile

Represents a student's tutor profile with subjects, pricing, availability, and contact information.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | UUID | PK, auto-generated | Unique identifier |
| `user_id` | UUID | FK → profiles.id, UNIQUE, NOT NULL | One-to-one with user profile |
| `bio` | TEXT | max 200 chars | Tutor's self-description |
| `subjects` | TEXT[] | max 5 items | Subjects offered (lowercase) |
| `price_per_hour` | DECIMAL | >= 0, default 0 | Hourly rate in EUR (0 = free) |
| `availability_days` | TEXT[] | valid day names | Days available for tutoring |
| `time_slot` | TEXT | nullable | Time range (e.g., "15:00-18:00") |
| `whatsapp_phone` | TEXT | nullable | Phone with country code (e.g., "393201234567") |
| `instagram_username` | TEXT | nullable | Instagram handle without @ |
| `rating` | DECIMAL | 0.0-5.0, default 0.0 | Average rating (Phase B) |
| `total_reviews` | INTEGER | >= 0, default 0 | Review count (Phase B) |
| `is_active` | BOOLEAN | default true | Visibility toggle |
| `created_at` | TIMESTAMPTZ | auto | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | auto on update | Last modification |

**Business Rules:**
- Each user can have at most 1 tutor profile (UNIQUE constraint on user_id)
- Must have at least 1 contact method (WhatsApp OR Instagram)
- Maximum 5 subjects per tutor
- Rating and reviews reserved for Phase B (default values only)

---

### Subject (Enum)

Enumeration of 12 supported school subjects.

| DB Value | Display Name (IT) |
|----------|-------------------|
| `matematica` | Matematica |
| `fisica` | Fisica |
| `latino` | Latino |
| `greco` | Greco |
| `inglese` | Inglese |
| `italiano` | Italiano |
| `informatica` | Informatica |
| `storia` | Storia |
| `filosofia` | Filosofia |
| `scienze` | Scienze |
| `arte` | Arte |
| `francese` | Francese |

**Storage:** Lowercase strings in TEXT[] array, validated at application level.

---

### AvailabilityDay (Enum)

Enumeration of valid availability days.

| DB Value | Display Name (IT) |
|----------|-------------------|
| `monday` | Lunedì |
| `tuesday` | Martedì |
| `wednesday` | Mercoledì |
| `thursday` | Giovedì |
| `friday` | Venerdì |
| `saturday` | Sabato |

**Note:** Sunday excluded as school tutoring typically not on Sundays.

---

## Database Migration

### Migration File: `012_tutor_profiles.sql`

```sql
-- ============================================
-- Migration: 012_tutor_profiles
-- Feature: Sistema Ripetizioni (012-tutoring-system)
-- Date: 2025-12-01
-- ============================================

-- 1. Create tutor_profiles table
CREATE TABLE IF NOT EXISTS tutor_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  bio TEXT CHECK (char_length(bio) <= 200),
  subjects TEXT[] DEFAULT '{}' CHECK (array_length(subjects, 1) IS NULL OR array_length(subjects, 1) <= 5),
  price_per_hour DECIMAL(10, 2) DEFAULT 0 CHECK (price_per_hour >= 0),
  availability_days TEXT[] DEFAULT '{}',
  time_slot TEXT,
  whatsapp_phone TEXT,
  instagram_username TEXT,
  rating DECIMAL(3, 2) DEFAULT 0.0 CHECK (rating >= 0 AND rating <= 5),
  total_reviews INTEGER DEFAULT 0 CHECK (total_reviews >= 0),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Unique constraint: one tutor profile per user
  CONSTRAINT tutor_profiles_user_id_unique UNIQUE (user_id),

  -- At least one contact method required
  CONSTRAINT tutor_profiles_contact_required CHECK (
    whatsapp_phone IS NOT NULL OR instagram_username IS NOT NULL
  )
);

-- 2. Create indexes for performance
-- GIN index for subject filtering (subjects @> '{matematica}')
CREATE INDEX IF NOT EXISTS idx_tutor_profiles_subjects
  ON tutor_profiles USING GIN (subjects);

-- Partial index for active tutors only
CREATE INDEX IF NOT EXISTS idx_tutor_profiles_active
  ON tutor_profiles (user_id)
  WHERE is_active = true;

-- Index for sorting by rating (future Phase B)
CREATE INDEX IF NOT EXISTS idx_tutor_profiles_rating
  ON tutor_profiles (rating DESC);

-- 3. Create updated_at trigger
CREATE OR REPLACE FUNCTION update_tutor_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tutor_profiles_updated_at
  BEFORE UPDATE ON tutor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_tutor_profiles_updated_at();

-- 4. Enable Row Level Security
ALTER TABLE tutor_profiles ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies

-- Policy: Anyone can read active tutor profiles
CREATE POLICY "read_active_tutors" ON tutor_profiles
  FOR SELECT
  USING (is_active = true);

-- Policy: Users can read their own tutor profile (even if inactive)
CREATE POLICY "read_own_tutor_profile" ON tutor_profiles
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Users can insert their own tutor profile
CREATE POLICY "insert_own_tutor_profile" ON tutor_profiles
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own tutor profile
CREATE POLICY "update_own_tutor_profile" ON tutor_profiles
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Policy: Users can delete their own tutor profile
CREATE POLICY "delete_own_tutor_profile" ON tutor_profiles
  FOR DELETE
  USING (auth.uid() = user_id);

-- 6. Grant permissions
GRANT SELECT ON tutor_profiles TO authenticated;
GRANT INSERT, UPDATE, DELETE ON tutor_profiles TO authenticated;

-- 7. Add comment for documentation
COMMENT ON TABLE tutor_profiles IS
  'Tutor profiles for Sistema Ripetizioni (012-tutoring-system).
   One profile per user, must have at least one contact method.';
```

---

## Dart Models

### TutorProfile Entity

```dart
// lib/features/tutoring/domain/entities/tutor_profile.dart

import 'package:freezed_annotation/freezed_annotation.dart';
import 'subject.dart';

part 'tutor_profile.freezed.dart';

@freezed
class TutorProfile with _$TutorProfile {
  const TutorProfile._();

  const factory TutorProfile({
    required String id,
    required String userId,
    String? bio,
    @Default([]) List<Subject> subjects,
    @Default(0.0) double pricePerHour,
    @Default([]) List<String> availabilityDays,
    String? timeSlot,
    String? whatsappPhone,
    String? instagramUsername,
    @Default(0.0) double rating,
    @Default(0) int totalReviews,
    @Default(true) bool isActive,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _TutorProfile;

  // Computed properties
  bool get isFree => pricePerHour == 0;
  bool get hasWhatsApp => whatsappPhone != null && whatsappPhone!.isNotEmpty;
  bool get hasInstagram => instagramUsername != null && instagramUsername!.isNotEmpty;
  String get priceDisplay => isFree ? 'Gratis' : '€${pricePerHour.toStringAsFixed(0)}/ora';
  String get subjectsDisplay => subjects.map((s) => s.displayName).join(', ');
}
```

### Subject Enum

```dart
// lib/features/tutoring/domain/entities/subject.dart

enum Subject {
  matematica('Matematica', 'matematica'),
  fisica('Fisica', 'fisica'),
  latino('Latino', 'latino'),
  greco('Greco', 'greco'),
  inglese('Inglese', 'inglese'),
  italiano('Italiano', 'italiano'),
  informatica('Informatica', 'informatica'),
  storia('Storia', 'storia'),
  filosofia('Filosofia', 'filosofia'),
  scienze('Scienze', 'scienze'),
  arte('Arte', 'arte'),
  francese('Francese', 'francese');

  final String displayName;
  final String dbValue;

  const Subject(this.displayName, this.dbValue);

  static Subject? fromDbValue(String value) {
    for (final subject in Subject.values) {
      if (subject.dbValue == value) return subject;
    }
    return null;
  }

  static List<Subject> fromDbValues(List<String> values) {
    return values
        .map((v) => fromDbValue(v))
        .whereType<Subject>()
        .toList();
  }
}
```

### TutorProfileModel (Data Layer)

```dart
// lib/features/tutoring/data/models/tutor_profile_model.dart

import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/tutor_profile.dart';
import '../../domain/entities/subject.dart';

part 'tutor_profile_model.freezed.dart';
part 'tutor_profile_model.g.dart';

@freezed
class TutorProfileModel with _$TutorProfileModel {
  const TutorProfileModel._();

  const factory TutorProfileModel({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    String? bio,
    @Default([]) List<String> subjects,
    @JsonKey(name: 'price_per_hour') @Default(0.0) double pricePerHour,
    @JsonKey(name: 'availability_days') @Default([]) List<String> availabilityDays,
    @JsonKey(name: 'time_slot') String? timeSlot,
    @JsonKey(name: 'whatsapp_phone') String? whatsappPhone,
    @JsonKey(name: 'instagram_username') String? instagramUsername,
    @Default(0.0) double rating,
    @JsonKey(name: 'total_reviews') @Default(0) int totalReviews,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _TutorProfileModel;

  factory TutorProfileModel.fromJson(Map<String, dynamic> json) =>
      _$TutorProfileModelFromJson(json);

  TutorProfile toEntity() => TutorProfile(
        id: id,
        userId: userId,
        bio: bio,
        subjects: Subject.fromDbValues(subjects),
        pricePerHour: pricePerHour,
        availabilityDays: availabilityDays,
        timeSlot: timeSlot,
        whatsappPhone: whatsappPhone,
        instagramUsername: instagramUsername,
        rating: rating,
        totalReviews: totalReviews,
        isActive: isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  static TutorProfileModel fromEntity(TutorProfile entity) => TutorProfileModel(
        id: entity.id,
        userId: entity.userId,
        bio: entity.bio,
        subjects: entity.subjects.map((s) => s.dbValue).toList(),
        pricePerHour: entity.pricePerHour,
        availabilityDays: entity.availabilityDays,
        timeSlot: entity.timeSlot,
        whatsappPhone: entity.whatsappPhone,
        instagramUsername: entity.instagramUsername,
        rating: entity.rating,
        totalReviews: entity.totalReviews,
        isActive: entity.isActive,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
      );
}
```

---

## State Transitions

### TutorProfile Lifecycle

```
┌─────────────┐
│ No Profile  │
└──────┬──────┘
       │ createTutorProfile()
       ▼
┌─────────────┐     deactivate()    ┌─────────────────┐
│   Active    │ ◄─────────────────► │    Inactive     │
│ (is_active  │     reactivate()    │  (is_active     │
│   = true)   │                     │    = false)     │
└──────┬──────┘                     └────────┬────────┘
       │                                     │
       │ updateTutorProfile()                │ updateTutorProfile()
       │ (subjects, price, etc.)             │ (while inactive)
       ▼                                     ▼
┌─────────────┐                     ┌─────────────────┐
│   Active    │                     │    Inactive     │
│  (updated)  │                     │   (updated)     │
└─────────────┘                     └─────────────────┘
       │
       │ deleteTutorProfile() OR
       │ deleteUserAccount() (cascade)
       ▼
┌─────────────┐
│   Deleted   │
└─────────────┘
```

### Valid Operations by State

| State | Valid Operations |
|-------|------------------|
| No Profile | `createTutorProfile()` |
| Active | `updateTutorProfile()`, `deactivate()`, `deleteTutorProfile()` |
| Inactive | `updateTutorProfile()`, `reactivate()`, `deleteTutorProfile()` |

---

## Validation Rules

### Create/Update Validation

| Field | Rule | Error Message |
|-------|------|---------------|
| `bio` | max 200 characters | "La bio non può superare 200 caratteri" |
| `subjects` | 1-5 items required | "Seleziona da 1 a 5 materie" |
| `subjects` | valid enum values | "Materia non valida" |
| `price_per_hour` | >= 0 | "Il prezzo non può essere negativo" |
| `whatsapp_phone` | valid format if present | "Formato numero non valido" |
| `instagram_username` | no @ prefix | "Username senza @" |
| Contact | at least one required | "Inserisci almeno un contatto" |

### Phone Number Format

```
Valid: 393201234567 (country code + number, no symbols)
Invalid: +39 320 1234567 (has +, spaces)
Invalid: 0039201234567 (wrong prefix)
```

### Instagram Username Format

```
Valid: mario.rossi
Valid: mario_rossi_123
Invalid: @mario.rossi (has @)
Invalid: mario rossi (has space)
```

---

## Query Patterns

### Get Tutors by Subject

```sql
SELECT tp.*, p.full_name, p.avatar_url, p.class_year
FROM tutor_profiles tp
JOIN profiles p ON tp.user_id = p.id
WHERE tp.subjects @> ARRAY['matematica']
  AND tp.is_active = true
ORDER BY tp.rating DESC, tp.created_at DESC
LIMIT 20 OFFSET 0;
```

### Get User's Tutor Profile

```sql
SELECT * FROM tutor_profiles
WHERE user_id = $1;
```

### Filter by Multiple Criteria

```sql
SELECT tp.*, p.full_name, p.avatar_url, p.class_year
FROM tutor_profiles tp
JOIN profiles p ON tp.user_id = p.id
WHERE tp.subjects @> ARRAY['matematica']
  AND tp.is_active = true
  AND tp.price_per_hour = 0  -- Free only
  AND p.class_year = '4A'    -- Same class
ORDER BY tp.rating DESC
LIMIT 20;
```
