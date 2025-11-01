# Feature Specification: Instagram-Style Profile Setup

**Feature Branch**: `002-profile-setup`
**Created**: 2025-11-01
**Status**: Draft
**Target Users**: Students aged 14-19 at Liceo Galilei Moro
**Post-Step**: Magic link authentication completed
**UX Philosophy**: Instagram-inspired (teenager-friendly, minimal, tap-to-edit)

## Overview

Nova's profile setup system enables students to create and manage their profiles with an Instagram-inspired user experience. The system prioritizes simplicity (2 required fields only), privacy (minimal data collection), and teenage familiarity (bottom sheets, auto-save, tap-to-edit patterns).

**Core Principles**:
- **STUDENTS_FIRST**: Minimal friction, skip option, teen-friendly
- **PRIVACY_FOUNDATION**: Only name + class required; avatar, pronouns, bio optional
- **SIMPLICITY_FIRST**: Single screen setup, auto-save, clear hierarchy
- **PERFORMANCE_FIRST**: <500ms loads, <2s uploads, 60fps animations

## Clarifications

### Session 2025-11-01

- Q: What loading state strategy should be used for the profile setup screen? → A: Skeleton screens (ghost shimmer placeholders for name/class/avatar fields)
- Q: How should class names differentiate SCIENTIFICO vs CLASSICO in the picker (when both have same class like "3A")? → A: Suffix format: "3A Scientifico", "3A Classico"
- Q: Which specific Material Design 500 colors and mapping should be used for avatar initials backgrounds? → A: Material Design 500 palette: Red, Pink, Purple, Deep Purple, Indigo, Blue, Light Blue, Cyan, Teal, Green, Light Green, Lime, Amber, Orange, Deep Orange, Brown, Blue Grey (17 colors, cycle for remaining 9 letters)
- Q: Where should the authoritative list of 35 classes be stored? → A: Hardcoded Dart const List in Flutter code (e.g., `lib/core/constants/classes.dart`)
- Q: Should users be able to navigate back to setup screen after completing profile (device back button behavior)? → A: Replace navigation - Back button exits app or goes to previous authenticated screen (setup removed from stack)

## User Scenarios & Testing

### User Story 1 - First Time Profile Setup (Priority: P1)

**Description**: New user completes magic link authentication and is redirected to profile setup. They provide their name (auto-populated from email) and select their class from a searchable picker. Optionally, they can upload an avatar, set pronouns, and write a bio.

**Why this priority**: This is the core onboarding flow that every new user must experience. Without it, users cannot fully participate in Nova (creating events, commenting). It's the foundation for all profile-related features.

**Independent Test**: Create a new account via magic link → Complete profile setup with name + class → Verify redirection to Feed. Delivers immediate value: user can now view events and participate in the community.

**Acceptance Scenarios**:

1. **Given** user just completed magic link authentication, **When** they open the app for the first time, **Then** they are redirected to /profile/setup screen
2. **Given** user is on setup screen, **When** screen loads, **Then** name field is pre-filled with "Giovanni Rossi" (parsed from giovanni.rossi@galileimoro.edu.it)
3. **Given** user is on setup screen, **When** they view the form, **Then** they see:
   - Large circular avatar (150px) with camera icon overlay
   - Name field (pre-filled, editable)
   - Class field showing "Seleziona classe" placeholder
   - Pronouns field showing "Non specificato"
   - Bio text area showing "0/150" counter
   - "Salva e inizia" button (disabled)
   - "Skip per ora" button (top-right)
4. **Given** user has not selected a class, **When** they attempt to tap "Salva e inizia", **Then** button remains disabled
5. **Given** user taps "Seleziona classe" field, **When** bottom sheet opens, **Then** they see:
   - Title "Seleziona la tua classe"
   - Search bar with placeholder "Cerca..."
   - Section "SCIENTIFICO" with 25 classes (1A-5F)
   - Section "CLASSICO" with 10 classes (1A-5B)
6. **Given** user types "3A" in class search, **When** filtering occurs, **Then** only "3A Scientifico" and "3A Classico" appear
7. **Given** user selects "3A Scientifico", **When** class is selected, **Then**:
   - Bottom sheet closes automatically
   - Class field updates to show "3A Scientifico"
   - Check icon appears next to selected class
   - "Salva e inizia" button becomes enabled
8. **Given** user has selected a class, **When** they tap "Salva e inizia", **Then**:
   - Profile saves to database
   - Toast appears "Profilo aggiornato ✓" (2 seconds)
   - User is redirected to Feed screen using replace navigation (setup screen removed from navigation stack, back button will not return to setup)
9. **Given** email is not firstname.lastname format (e.g., student123@galileimoro.edu.it), **When** setup screen loads, **Then** name field is empty with placeholder "Inserisci nome e cognome"

---

### User Story 2 - Avatar Upload & Management (Priority: P2)

**Description**: User can upload a custom avatar photo from camera or gallery, with automatic square cropping. If no photo is uploaded, the system displays colored initials (deterministic color based on first character of name).

**Why this priority**: Avatar upload is optional but highly valued for personalization and engagement. Instagram research shows 40% avatar upload rate is achievable with good UX. This enhances the social aspect without being mandatory.

**Independent Test**: Complete P1 setup → Upload avatar from gallery → Verify it appears in profile and events. Delivers standalone value: visual personalization and identity.

**Acceptance Scenarios**:

1. **Given** user is on setup or edit screen, **When** they tap camera icon overlay on avatar, **Then** bottom sheet opens with options:
   - 📷 Scatta foto
   - 🖼️ Scegli da galleria
   - 🗑️ Rimuovi foto (only if avatar exists)
2. **Given** user selects "Scegli da galleria", **When** photo picker opens, **Then** user can select any JPG/PNG/WebP image up to 5MB
3. **Given** user selects a photo, **When** upload completes, **Then**:
   - Photo is automatically cropped to square (1:1 ratio)
   - Uploaded to Supabase Storage at `/avatars/{user_id}/{timestamp}.jpg`
   - Profile updated with `avatar_url` (signed URL, 1 hour expiry)
   - Toast appears "Avatar aggiornato ✓"
   - Avatar display updates immediately (optimistic UI)
4. **Given** user has no custom avatar, **When** avatar is displayed, **Then** show colored initials:
   - Extract first letter of first name + first letter of last name (e.g., "Giovanni Rossi" → "GR")
   - Background color: Deterministic from first character (26 Material Design 500 palette colors, excluding yellow/white)
   - Text: White, 48px, weight 700, centered
5. **Given** user selects "Rimuovi foto", **When** confirmation dialog appears, **Then**:
   - Show "Rimuovere la foto?" prompt
   - If confirmed: Delete from Storage, set `avatar_url = null`, show colored initials, toast "Avatar rimosso ✓"
   - If cancelled: Close dialog, no changes
6. **Given** upload fails due to network error, **When** error occurs, **Then**:
   - Show toast "Errore caricamento foto" with retry button
   - Keep existing avatar visible
   - After 3 failed retries, show "Riprova più tardi"
7. **Given** user uploads a 200px x 400px image, **When** processing occurs, **Then** image is cropped to 200px x 200px (square, center-cropped)

---

### User Story 3 - Skip Setup Flow (Priority: P2)

**Description**: User can skip initial profile setup to browse the feed immediately, but certain actions (create event, comment, join chat) are blocked until profile is completed (name + class).

**Why this priority**: Respects user autonomy and reduces onboarding friction. Some users may want to explore first before committing. Forced completion on protected actions ensures data quality while maintaining flexibility.

**Independent Test**: Skip setup → Browse feed successfully → Attempt to create event → See completion prompt → Complete profile. Delivers standalone value: exploration without commitment.

**Acceptance Scenarios**:

1. **Given** user is on first-time setup screen, **When** they tap "Skip per ora" (top-right), **Then**:
   - Profile created with name only (class = null)
   - User redirected to Feed immediately
   - Can view events and browse content
2. **Given** user skipped setup (incomplete profile), **When** they attempt to create event, **Then**:
   - Action blocked
   - Modal appears: "Completa il tuo profilo" / "Per creare eventi devi selezionare la tua classe"
   - Single button "Completa ora"
3. **Given** user sees completion modal, **When** they tap "Completa ora", **Then** redirected to setup screen (forced completion)
4. **Given** user skipped setup, **When** they attempt to comment on event, **Then** same blocking modal appears
5. **Given** user skipped setup, **When** they attempt to join global chat, **Then** same blocking modal appears
6. **Given** user has incomplete profile, **When** they navigate to Settings, **Then** show completion banner "Completa il tuo profilo per creare eventi"

---

### User Story 4 - Edit Profile (Priority: P2)

**Description**: Returning user can edit their profile from Settings. Changes auto-save after 500ms (bio debounce) or instantly (selections). Same UI as first-time setup but with pre-filled values.

**Why this priority**: Users need to update their information as it changes (class progression, pronouns evolution, bio updates). Auto-save pattern reduces friction and matches Instagram UX expectations.

**Independent Test**: Edit profile → Change class from 3A to 4A → Verify auto-save toast and persistence. Delivers standalone value: profile updates without manual save actions.

**Acceptance Scenarios**:

1. **Given** user has completed profile, **When** they navigate to Settings → "Modifica profilo", **Then** setup screen appears with:
   - Avatar showing uploaded photo or colored initials
   - Name field showing current value (editable)
   - Class field showing selected class (tap to change)
   - Pronouns field showing selected value (tap to change)
   - Bio showing saved text with character counter
   - "X" icon (top-left) to go back
   - NO "Skip per ora" button (only on first setup)
2. **Given** user changes class from "3A Scientifico" to "4A Scientifico", **When** selection is made, **Then**:
   - Change saved immediately (no debounce)
   - Toast "Profilo aggiornato ✓" appears
   - Optimistic UI update (field shows new value before server confirmation)
3. **Given** user types in bio field, **When** they stop typing for 500ms, **Then**:
   - Auto-save triggers
   - API call: PATCH /profiles/{user_id} with {bio: "new text"}
   - Toast "Profilo aggiornato ✓" appears
4. **Given** auto-save fails (network offline), **When** error occurs, **Then**:
   - Show toast "Errore nel salvataggio" with retry button
   - Profile saved locally (Hive/SharedPreferences)
   - Retry automatically when network returns
5. **Given** user makes multiple edits quickly, **When** auto-save triggers, **Then** only ONE API call is made with most recent values (debounce working correctly)

---

### User Story 5 - Bio with Live Character Counter (Priority: P3)

**Description**: User can write a bio (max 150 characters) with live counter that changes color based on character count. Counter turns orange at 140, red at 150, and blocks submission over 150.

**Why this priority**: Bio is optional and enhances personalization. Live counter is a nice-to-have UX feature that prevents errors and matches Instagram patterns.

**Independent Test**: Write bio with exactly 150 characters → Verify counter turns red and save works. Write 151 characters → Verify save is blocked. Delivers standalone value: self-expression with clear limits.

**Acceptance Scenarios**:

1. **Given** user types in bio field, **When** character count is 0-139, **Then** counter shows "X/150" in gray (#6B7280)
2. **Given** user types in bio field, **When** character count is 140-150, **Then** counter turns orange (#F59E0B)
3. **Given** user types in bio field, **When** character count reaches 150, **Then**:
   - Counter turns red (#EF4444)
   - Cannot type more (maxLength enforced)
   - "Salva e inizia" button remains enabled
4. **Given** user types 151+ characters (bypassing client validation), **When** save occurs, **Then**:
   - Server truncates to 150 characters
   - Returns truncated value to client
   - Client updates to match server
   - Logs warning (potential attack)
5. **Given** user has 150 characters in bio, **When** they delete one character, **Then** counter returns to orange (149/150)
6. **Given** user types bio with multiline content, **When** text wraps, **Then** text area expands vertically (no scrolling)

---

### User Story 6 - Pronouns Selection (Priority: P3)

**Description**: User can optionally set pronouns via bottom sheet picker. Default is "Non specificato" (not stored). Options: Lui, Lei, They, Altro, Preferisco non dire.

**Why this priority**: Optional inclusivity feature. 30% adoption target is achievable. Opt-in design respects privacy while supporting self-expression.

**Independent Test**: Select pronouns "They" → Verify it saves and displays in profile. Delivers standalone value: gender expression support.

**Acceptance Scenarios**:

1. **Given** user taps pronouns field, **When** bottom sheet opens, **Then** they see options:
   - Non specificato (default, shown first)
   - Lui
   - Lei
   - They
   - Altro
   - Preferisco non dire
2. **Given** user selects "They", **When** selection is made, **Then**:
   - Bottom sheet closes
   - Field updates to show "They"
   - Saved immediately (instant save, no debounce)
   - Toast "Profilo aggiornato ✓"
3. **Given** user selects "Non specificato", **When** saved, **Then** `pronouns` column in database is set to NULL (not stored)
4. **Given** user has pronouns set to "Lui", **When** they view their profile, **Then** pronouns are visible only to authenticated students (@galileimoro.edu.it - RLS policy enforced)

---

### Edge Cases

#### Profile Creation & Parsing

- **EDGE-001 - Email Parsing Failure**: Email is `student123@galileimoro.edu.it` (not firstname.lastname format) → Name field empty with placeholder "Inserisci nome e cognome" → User types manually
- **EDGE-011 - First Name Only**: Email is `name@galileimoro.edu.it` (single word) → Capitalize to "Name" → Show in field → User can edit to add last name
- **EDGE-012 - Long Name Display**: User has 50-character name (max length) → Extract first + last initial only for avatar (2 chars max) → Example: "Giovanni Maria Alessandro Rossi Bianchi" → "GB"

#### Avatar Upload

- **EDGE-002 - Avatar Upload Failure**: User selects photo, Supabase upload fails (network error, timeout) → Show toast "Errore caricamento foto" with retry button → Keep initials avatar → After 3 retries: "Riprova più tardi"
- **EDGE-009 - Avatar Delete with Slow Network**: User taps "Rimuovi foto", delete request takes 5+ seconds → Show loading spinner on avatar → Keep old avatar visible during load → After success: switch to initials + toast → After failure: keep old avatar + error toast

#### Validation & Limits

- **EDGE-003 - Class Not Selected**: User on setup screen taps "Salva e inizia" without selecting class → Button is disabled (should not be tappable) → If somehow triggered: show toast "Seleziona la tua classe"
- **EDGE-004 - Bio Over Limit (Client-Side)**: User typing in bio field reaches 151 characters → Counter turns red, text field border turns red, "Salva e inizia" disabled, cannot type more (maxLength enforced)
- **EDGE-005 - Bio Over Limit (Server-Side)**: Malicious request bypasses client validation, POSTs bio with 200 characters → Server truncates to 150, logs warning (potential attack), returns truncated value, client updates to match server

#### Network & Offline

- **EDGE-006 - Network Offline During Save**: User completes profile, taps "Salva e inizia" but network offline → Show banner "Nessuna connessione" → Profile saved locally (Hive/SharedPreferences) → Retry automatically when network returns → Toast "Profilo salvato offline, sincronizzazione in corso..."
- **EDGE-007 - Concurrent Profile Edit**: User has 2 devices (phone + tablet), edits profile on both simultaneously → Last write wins (Supabase default behavior) → No conflict resolution needed (single user, low risk) → `updated_at` shows most recent change

#### Search & Picker

- **EDGE-010 - Search Class with Typo**: User in class picker types "sceintifico" (typo) → No results shown → Show message "Nessuna classe trovata" → Search is case-insensitive → Partial match: "3a" matches "3A Scientifico" and "3A Classico"

#### Skip Flow

- **EDGE-008 - Skip Setup Then Create Event**: User tapped "Skip per ora", attempts to create event (class = null in DB) → Block action with modal: "Completa il tuo profilo" / "Per creare eventi devi selezionare la tua classe" / [Completa ora] → Tap button redirects to setup (forced completion)

## Requirements

### Functional Requirements

#### Name & Email Parsing

- **FR-001**: System MUST parse email local part to auto-populate name field (e.g., `giovanni.rossi@galileimoro.edu.it` → "Giovanni Rossi" with capitalized first letters)
- **FR-001a**: If email parsing fails (single word like `student123`), system MUST show empty name field with placeholder "Inserisci nome e cognome" and allow manual entry
- **FR-001b**: Name field MUST validate: 2-50 characters, letters (including accented) + spaces + hyphens + apostrophes only (regex: `^[a-zA-Z\u00C0-\u017F\s'-]{2,50}$`)
- **FR-001c**: Name MUST be trimmed of whitespace before saving

#### Class Selection (REQUIRED)

- **FR-002**: System MUST provide bottom sheet picker with 35 classes in 2 sections:
  - **SCIENTIFICO** (25 classes): 1A-1F, 2A-2F, 3A-3F, 4A-4F, 5A-5F (excluding 1E, 2E, 3E, 4E, 5E)
  - **CLASSICO** (10 classes): 1A-5B (2 classes per year)
  - Class list stored as hardcoded Dart const List in `lib/core/constants/classes.dart` (no DB query required)
- **FR-002a**: Class names MUST use suffix format to differentiate tracks: "3A Scientifico", "3A Classico" (not prefix or section-only)
- **FR-002b**: Class picker MUST include search functionality filtering by class name (case-insensitive, partial match)
- **FR-002c**: Class selection MUST be single-selection (radio behavior) with check icon on selected class
- **FR-002d**: "Salva e inizia" button MUST remain disabled until class is selected
- **FR-002e**: User MUST NOT be able to proceed to Feed without class selected (except via "Skip per ora" → forced completion later)

#### Avatar Upload (OPTIONAL)

- **FR-004**: System MUST provide avatar upload with options: Camera, Gallery, Remove (if avatar exists)
- **FR-004a**: Avatar upload MUST enforce: Max size 5MB, allowed formats JPG/PNG/WebP, auto-crop to square (1:1 ratio)
- **FR-004b**: Uploaded avatars MUST be stored in Supabase Storage at `/avatars/{user_id}/{timestamp}.jpg`
- **FR-004c**: Avatar URLs MUST be signed URLs with 1-hour expiry
- **FR-004d**: System MUST perform virus scan on upload (Supabase Storage automatic)
- **FR-004e**: Filenames MUST be sanitized: `{user_id}_{timestamp}.{ext}`

#### Avatar Initials Fallback

- **FR-005**: If no custom avatar uploaded, system MUST display colored initials:
  - Extract first letter of first name + first letter of last name (e.g., "Giovanni Rossi" → "GR")
  - Deterministic background color from first character using Material Design 500 palette in sequential A-Z mapping: Red, Pink, Purple, Deep Purple, Indigo, Blue, Light Blue, Cyan, Teal, Green, Light Green, Lime, Amber, Orange, Deep Orange, Brown, Blue Grey (17 colors cycling for 26 letters: A=Red, B=Pink, ..., Q=Red, R=Pink, etc.)
  - White text, 48px font size, weight 700, centered
- **FR-005a**: For long names (50 chars), extract first word first letter + last word first letter only (2 chars max)

#### Camera Icon Overlay

- **FR-006**: Avatar display MUST show camera icon overlay:
  - Position: Bottom-right of avatar circle
  - Size: 40px diameter circle
  - Background: `NovaColors.primary` with 3px white border
  - Icon: Camera icon (20px) in white
  - Tap target: Minimum 44x44px (accessibility)

#### Pronouns Selection (OPTIONAL)

- **FR-007**: System MUST provide pronouns picker (bottom sheet) with options: Non specificato, Lui, Lei, They, Altro, Preferisco non dire
- **FR-007a**: Default selection MUST be "Non specificato" (stored as NULL in database)
- **FR-007b**: Pronouns selection MUST save immediately (instant save, no debounce)
- **FR-007c**: Pronouns MUST be visible only to authenticated students (RLS policy: `auth.email LIKE '%@galileimoro.edu.it'`)

#### Bio Text Area (OPTIONAL)

- **FR-008**: System MUST provide bio text area with live character counter:
  - Max 150 characters (Instagram standard)
  - Counter updates on every keystroke
  - Color coding: 0-139 chars gray (#6B7280), 140-150 chars orange (#F59E0B), 151+ chars red (#EF4444)
- **FR-008a**: At 151+ characters: Counter red, text field border red, "Salva e inizia" disabled, cannot type more (maxLength enforced)
- **FR-008b**: Bio MUST support multiline (no scrolling, text area expands vertically)
- **FR-008c**: Placeholder text: "Scrivi qualcosa su di te..."

#### Auto-Save Mechanism

- **FR-009**: System MUST implement auto-save:
  - **Bio**: Debounce 500ms after last keystroke
  - **Selections** (class, pronouns, avatar): Instant save (no debounce)
  - API call: `PATCH /profiles/{user_id}`
  - Optimistic UI update (update immediately, rollback on error)
- **FR-009a**: On save success: Toast "Profilo aggiornato ✓" (2 seconds)
- **FR-009b**: On save error: Toast "Errore nel salvataggio" with retry button
- **FR-009c**: If offline: Save locally (Hive/SharedPreferences), retry automatically when network returns, toast "Profilo salvato offline, sincronizzazione in corso..."
- **FR-009d**: On first-time setup completion: Navigate to Feed using replace navigation (Navigator.pushReplacement) to remove setup screen from navigation stack, preventing back button from returning to setup

#### Skip Setup Flow

- **FR-010**: System MUST provide "Skip per ora" button (top-right) on first-time setup only (NOT on edit screen)
- **FR-010a**: On skip: Create profile with name only (class = NULL), redirect to Feed immediately
- **FR-010b**: System MUST block protected actions for incomplete profiles:
  - Create event → Modal "Completa il tuo profilo" / "Per creare eventi devi selezionare la tua classe" / [Completa ora]
  - Comment on event → Same modal
  - Join chat → Same modal
- **FR-010c**: Modal "Completa ora" button MUST redirect to setup screen (forced completion)

#### Profile Completion Check

- **FR-011**: System MUST implement `isProfileComplete()` helper function: Returns `true` if name AND class exist, `false` otherwise
- **FR-011a**: On protected action attempts: If profile incomplete, redirect to setup
- **FR-011b**: In Settings: If profile incomplete, show completion banner "Completa il tuo profilo per creare eventi"

### Key Entities

**Profile**:
- Represents student user profile for Nova school events platform
- **Core Attributes**:
  - `user_id` (UUID, primary key, foreign key → auth.users): Unique identifier, links to authentication system
  - `full_name` (VARCHAR 50, NOT NULL): Student's full name, auto-populated from email or manually entered, validated regex, 2-50 chars
  - `class` (VARCHAR 20, NOT NULL): Student's school class, one of 35 values (SCIENTIFICO: 1A-5F excluding E, CLASSICO: 1A-5B), required for protected actions
  - `pronouns` (VARCHAR 30, NULLABLE): Optional pronouns (Lui, Lei, They, Altro, Preferisco non dire), NULL = "Non specificato"
  - `avatar_url` (TEXT, NULLABLE): Signed URL to uploaded avatar in Supabase Storage (1-hour expiry), NULL = show colored initials
  - `bio` (VARCHAR 150, NULLABLE): Optional bio text, max 150 characters, sanitized (no HTML, no URLs)
  - `created_at` (TIMESTAMPTZ): Profile creation timestamp (defaults to now())
  - `updated_at` (TIMESTAMPTZ): Last update timestamp (auto-updated on every PATCH via trigger)
- **Relationships**:
  - One-to-one with `auth.users` (via `user_id`)
  - One-to-many with `events.creator_id` (user can create multiple events)
  - One-to-many with `comments.user_id` (user can write multiple comments)
  - One-to-many with `likes.user_id` (user can like multiple items)
- **Constraints**:
  - `full_name`: NOT NULL, length 2-50
  - `class`: NOT NULL, CHECK (class IN [35 values])
  - `pronouns`: NULLABLE, CHECK (pronouns IN [6 values] OR NULL)
  - `bio`: NULLABLE, length 0-150
- **Indexes**:
  - PRIMARY KEY on `user_id`
  - INDEX on `class` (for filtering/search)
  - INDEX on `updated_at` (for recent profiles)

**Class** (enumerated type, not a table):
- Represents student's class at Liceo Galilei Moro
- **Values** (35 total):
  - **SCIENTIFICO** (25 classes): 1A, 1B, 1C, 1D, 1F, 2A, 2B, 2C, 2D, 2F, 3A, 3B, 3C, 3D, 3F, 4A, 4B, 4C, 4D, 4F, 5A, 5B, 5C, 5D, 5F
  - **CLASSICO** (10 classes): 1A, 1B, 2A, 2B, 3A, 3B, 4A, 4B, 5A, 5B
- **Purpose**: Enables event filtering by class, community segmentation

## Success Criteria

### Measurable Outcomes

#### User Adoption & Engagement

- **SC-001**: 95% of users complete profile setup in under 1 minute (measured via analytics)
- **SC-002**: 100% of profiles in production database have non-null name AND class
- **SC-003**: 40% of users upload custom avatar (target Instagram-level engagement)
- **SC-004**: 30% of users set pronouns (opt-in adoption metric)
- **SC-005**: 25% of users write bio (creative engagement metric)
- **SC-006**: <5% of users skip setup initially (most complete immediately)
- **SC-007**: <1% of users skip setup permanently (forced completion works)

#### Technical Performance

- **SC-008**: Zero XSS vulnerabilities in bio field (verified via security audit)
- **SC-009**: Avatar upload success rate >95% with p95 latency <2 seconds
- **SC-010**: Auto-save success rate >99% (reliable persistence)

#### User Experience Quality

- **SC-011**: User testing shows "feels like Instagram" with 5/5 familiarity score from teenage testers
- **SC-012**: Zero users confused by bottom sheet pickers (0% support tickets related to class/pronouns selection)
- **SC-013**: Teenage testers describe UI as "clean" and "modern" in feedback surveys (qualitative target: 80% positive sentiment)
- **SC-014**: Zero complaints about privacy (pronouns/bio optional appreciated, measured via feedback and support tickets)

#### Acceptance Tests

- **AC-001**: Create profile with name + class only → Success (minimal viable profile)
- **AC-002**: Upload avatar → Shows in profile view AND in event cards (cross-feature integration)
- **AC-003**: Skip setup → Can view feed successfully BUT blocked from creating event (skip flow works)
- **AC-004**: Edit profile after initial setup → Changes persist across sessions
- **AC-005**: Type 151 characters in bio → Cannot save (validation enforced)
- **AC-006**: Select class from picker → Field updates, button enables (interaction flow)
- **AC-007**: Save profile offline → Syncs when network returns (offline resilience)
- **AC-008**: Delete avatar → Shows colored initials instead (fallback works)

## Privacy Requirements

- **PRIV-001 - Minimal Required Data**: Only name + class required for full participation. Avatar, pronouns, bio fully optional. NO Instagram handle collection. NO other social media links.
- **PRIV-002 - Pronouns Privacy**: Default "Non specificato" not stored in DB (NULL value). Opt-in selection required. Visible only to verified students (RLS policy). "Preferisco non dire" option available.
- **PRIV-003 - Bio Privacy**: Optional field (empty by default). NO @mentions parsing (avoid profile linking). NO hashtags parsing (not a social network). NO link detection (prevent external site promotion).
- **PRIV-004 - Avatar Privacy**: Upload optional. Stored in private Supabase bucket (not public URL). Accessible only via signed URL (1-hour expiry). Automatic deletion when user deletes account (cascade delete).
- **PRIV-005 - Class Visibility**: Class visible only to authenticated students (`auth.email LIKE '%@galileimoro.edu.it'` RLS policy). Not exposed in any public API.

## Security Requirements

- **SEC-001 - Profile Ownership (RLS)**: User can only edit own profile. Supabase RLS policy: `UPDATE profiles WHERE user_id = auth.uid()`. Cannot modify other users' profiles (enforced at DB level).
- **SEC-002 - Bio Sanitization**: Strip all HTML tags (XSS prevention). Remove URLs (prevent phishing). Remove `<script>` tags. Max length enforced server-side (150 chars). Regex validation: `^[a-zA-Z0-9\s\u00C0-\u017F.,!?'"-🎨🚀💡📚]*$` (letters, numbers, spaces, basic punctuation, common emojis).
- **SEC-003 - Avatar Upload Security**: File size limit 5MB (enforced client + server). MIME type validation: `image/jpeg`, `image/png`, `image/webp` only. File extension validation: `.jpg`, `.jpeg`, `.png`, `.webp`. Virus scan on upload (Supabase Storage automatic). Filename sanitization: `{user_id}_{timestamp}.{ext}`.
- **SEC-004 - Name Validation**: Length 2-50 characters. Allowed characters: Letters (including accented), spaces, hyphens, apostrophes. Regex: `^[a-zA-Z\u00C0-\u017F\s'-]{2,50}$`. No numbers. No special symbols (except `-` and `'`). Trim whitespace before save.
- **SEC-005 - Rate Limiting**: Profile updates max 10 per minute per user. Avatar uploads max 5 per hour per user. Enforced via Supabase Edge Functions middleware.
- **SEC-006 - Session Validation**: All profile endpoints require valid JWT token. Token verified on every request. Expired tokens (>30 days) rejected. Logout invalidates token immediately.

## UI/UX Requirements

### Avatar Presentation

- **UI-001**: Avatar size 150px diameter (75px radius), no border (clean Instagram style), shadow `NovaShadows.small` for depth
- **UI-001a**: Camera icon overlay: 40px circle, bottom-right (-5px offset), background `NovaColors.primary` + 3px white border, camera icon 20px white
- **UI-001b**: Initials: 48px font size, weight 700, centered, white text, deterministic background color

### Bottom Sheet Design

- **UI-002**: Bottom sheets use `DraggableScrollableSheet` at 70% screen height (min 50%, max 95%)
- **UI-002a**: Background: `NovaGlassCard` with `GlassLevel.medium`
- **UI-002b**: Border radius `NovaRadius.xl` (24px) on top corners only
- **UI-002c**: Handle bar: 40x4px, centered, 12px from top, gray color
- **UI-002d**: Swipeable to dismiss (swipe down gesture or tap outside)

### Class Picker Layout

- **UI-003**: Title "Seleziona la tua classe" (`NovaTextStyles.h2`)
- **UI-003a**: Search bar: 16px margin, rounded corners `NovaRadius.m`
- **UI-003b**: Section headers: "─── SCIENTIFICO ───" (gray, 11px uppercase)
- **UI-003c**: List items: 56px height, checkmark icon on selected, selected item has primary color background (10% opacity)

### Toast Notifications

- **UI-004**: Position bottom center, 100px from bottom (above nav bar)
- **UI-004a**: Width auto-fit content, max 80% screen width, padding 12x20px
- **UI-004b**: Border radius `NovaRadius.circularFull` (pill shape)
- **UI-004c**: Background: Success green or Error red, icon + text layout (horizontal), duration 2 seconds
- **UI-004d**: Animation: Slide up + fade in, slide down + fade out

### Text Input Styling

- **UI-005**: Border 1px solid `NovaColors.border` (default), 2px solid `NovaColors.primary` (focused), 2px solid `NovaColors.error` (error)
- **UI-005a**: Padding 12px, border radius `NovaRadius.s` (12px), font `NovaTextStyles.body`

### Button Styling

- **UI-006**: "Salva e inizia" button: Full width, 48px height, rounded `NovaRadius.m`
- **UI-006a**: Background `NovaColors.primary` (enabled), gray (disabled), text white `NovaTextStyles.button`, disabled opacity 0.4
- **UI-006b**: Press animation: Scale 0.98 (100ms spring curve)

### Skip Button

- **UI-007**: Position top-right, 16px from edge, text button (no background), color `NovaColors.textSecondary`, font `NovaTextStyles.body`, underline on press

## Non-Functional Requirements

### Performance

- **NFR-001**: Setup screen loads <500ms
- **NFR-001a**: During initial load, display skeleton screens (ghost shimmer placeholders) for avatar, name field, class field, pronouns field, and bio text area
- **NFR-002**: Avatar upload completes <2 seconds (p95)
- **NFR-003**: Auto-save response <500ms
- **NFR-004**: Bottom sheet animation smooth (60fps sustained, spring curve `Curves.easeOutBack`)
- **NFR-005**: Search filter instant (<50ms for 35 items)

### Accessibility (WCAG 2.1 AA)

- **NFR-006**: All tap targets minimum 44x44px
- **NFR-007**: Color contrast ratio >4.5:1 for all text
- **NFR-008**: Screen reader support (semantic labels on all interactive elements)
- **NFR-009**: Bio counter readable by screen readers ("45 of 150 characters")
- **NFR-010**: Focus indicators on text inputs

### Instagram-Inspired UX

- **NFR-011**: Bottom sheets use `DraggableScrollableSheet` with handle bar (40x4px gray), swipe down to close, spring animation curve
- **NFR-012**: Toast floating style (rounded full, bottom center positioning)
- **NFR-013**: Tap to edit inline (no heavy multi-step forms)
- **NFR-014**: Auto-save with toast feedback (no explicit "Save" buttons except initial setup)

### Offline Behavior

- **NFR-015**: Setup screen accessible offline (cached data)
- **NFR-016**: Avatar upload queued if offline → upload when online
- **NFR-017**: Show "Offline" banner if save fails due to network
- **NFR-018**: Retry mechanism: 3 attempts with exponential backoff (1s, 2s, 4s)

## Out of Scope

### Future Features (Post-MVP)

- Cover photo (Instagram has, but not necessary for MVP launch)
- Link in bio (not relevant for school app, may add in v1.1 if requested)
- Multiple photos carousel (profile gallery)
- Story highlights section
- Follow/followers system (explicitly NOT a social network per constitution anti-goal #1)
- Verification badge (moderator badge possible in v1.1)
- Rich text bio (markdown, bold, italic - adds complexity, defer)
- Profile views counter ("who viewed my profile" - privacy concern)
- Profile completion percentage badge (UX noise)
- Suggested profiles/friends (social network feature, out of scope)
- Profile themes/customization (adds complexity)
- QR code for profile sharing (not needed for school context)
- Profile analytics (views, engagement - admin feature, not student-facing)

### Explicitly NOT Supported

- Instagram handle field (removed for privacy - constitution PRIVACY_FOUNDATION principle)
- Other social media links (Twitter, TikTok, etc. - privacy risk, not relevant)
- Email visible on profile (privacy concern - already authenticated via email)
- Phone number field (not needed for MVP, privacy risk)
- Address/location (privacy concern, not relevant for school app)
- Birthday (not needed for MVP, adds privacy complexity)
- Gender field (pronouns are more inclusive and sufficient)

### Technical Debt Accepted

- No image cropper UI (auto-crop to square only - reduces implementation time, acceptable UX tradeoff)
- No avatar filters/editing (use uploaded photo as-is - not core to MVP)
- No bulk profile import (manual setup only - admin feature, defer)
- No profile templates (single layout only - simplicity over customization)

## Assumptions

1. **Email Domain Validation**: All users have `@galileimoro.edu.it` email addresses (enforced by magic link authentication from feature 001)
2. **Class List Stability**: The 35 classes (SCIENTIFICO 25, CLASSICO 10) are current and won't change mid-school-year. Class list updates require spec amendment.
3. **Avatar Storage**: Supabase Storage has sufficient quota for 500+ student avatars (5MB max each = ~2.5GB total for full school). Confirmed sufficient for MVP.
4. **Auto-Save UX**: 500ms debounce for bio is acceptable (Instagram uses similar timing). No user complaints expected based on industry standards.
5. **Profile Completion Timing**: Profile record is created during magic link authentication (feature 001) with email-parsed name. Setup screen updates existing record, not creating new one.
6. **Pronouns Cultural Context**: Italian high school students are familiar with English pronouns ("They", etc.) or will use "Altro" if preferred. No translation needed for MVP.
7. **Device Permissions**: Users grant camera and photo library permissions when prompted by OS. No special permission handling needed beyond standard Flutter `image_picker` package.

## Constitution Alignment

**STUDENTS_FIRST** ✓
- UX designed for 14-19 year olds using Instagram patterns they already know
- Minimal friction: Only 2 required fields (name + class)
- Skip option respects user autonomy (can explore before committing)
- Teen-friendly pronouns options support inclusive self-expression

**PRIVACY_FOUNDATION** ✓
- Minimal data collection: Only name + class required for participation
- All extras opt-in: Avatar, pronouns, bio fully optional
- No Instagram handle collection (removed for privacy after constitution review)
- RLS policies enforce student-only visibility (no public profiles)
- Avatar stored in private Supabase bucket with signed URLs (1-hour expiry)

**SIMPLICITY_FIRST** ✓
- 5 fields total (2 required, 3 optional) - not overwhelming
- Single screen setup (no multi-step wizard complexity)
- Auto-save eliminates explicit "Save" button spam
- Clear visual hierarchy: Avatar → Name → Class → Optional extras

**PERFORMANCE_FIRST** ✓
- Setup screen loads <500ms (fast initial render)
- Avatar upload <2s p95 (acceptable for image upload)
- Auto-save response <500ms (instant feedback)
- 60fps bottom sheet animations (smooth, no jank)
- Instant search filter for 35 items (<50ms)

**SPEC_FIRST** ✓
- This specification created before any implementation
- All requirements explicit and testable
- Edge cases documented comprehensively
- Success criteria measurable and achievable

**DESIGN_SYSTEM_STRICT** ✓
- All colors from `NovaColors` (no hardcoded hex values)
- All spacing from `NovaSpacing` (no magic numbers)
- All typography from `NovaTextStyles` (consistent text rendering)
- `NovaGlassCard` for bottom sheets (design system component)
- Zero hardcoded values in spec (all reference design system constants)

**CONTENT_MODERATION** ✓
- Bio sanitization: Strip HTML, remove URLs (prevent XSS and phishing)
- Avatar virus scan via Supabase Storage (automatic on upload)
- Name validation: No numbers/special symbols (data quality)
- Max length enforcement: 150 chars bio, 50 chars name (prevent spam)
- Server-side validation mirrors client-side (security in depth)

## Design System References

### Colors
- Primary: `NovaColors.primary(context)` - #8B5CF6 (light) / #A78BFA (dark)
- Success: `NovaColors.success` - #10B981 (light) / #34D399 (dark)
- Error: `NovaColors.error` - #EF4444 (light) / #F87171 (dark)
- Background: `NovaColors.background(context)`
- Text: `NovaColors.textPrimary(context)`
- Border: `NovaColors.border`
- Text Secondary: `NovaColors.textSecondary`

### Typography
- Title: `NovaTextStyles.h2` (20px, weight 600)
- Body: `NovaTextStyles.body` (15px, weight 400)
- Caption: `NovaTextStyles.caption` (13px, weight 400)
- Button: `NovaTextStyles.button` (15px, weight 600)

### Spacing
- Screen padding: `NovaSpacing.l` (16px)
- Element spacing: `NovaSpacing.m` (12px)
- Tight spacing: `NovaSpacing.s` (8px)
- Section spacing: `NovaSpacing.xl` (20px)

### Radius
- Avatar: `NovaRadius.circularFull` (9999px)
- Cards: `NovaRadius.m` (16px)
- Inputs: `NovaRadius.s` (12px)
- Bottom sheet: `NovaRadius.xl` (24px)
- Toast: `NovaRadius.circularFull` (pill shape)

### Glass Effect
- Bottom sheet: `NovaGlassCard` with `GlassLevel.medium`
- Settings: `NovaGlass.getSettings(context, GlassLevel.subtle)`

### Shadows
- Avatar: `NovaShadows.small`
- Bottom sheet: `NovaShadows.medium`

### Icons
- Camera: `LucideIcons.camera` (or `Icons.camera_alt`)
- Check: `LucideIcons.check` (or `Icons.check_circle`)
- Close: `LucideIcons.x` (or `Icons.close`)
- Size: `NovaIconSizes.m` (24px)

## Priority Classification

### P1 (Must Have - MVP Launch)
- Setup screen with name + class (required fields)
- Avatar upload with camera icon overlay
- Class picker bottom sheet with 35 classes
- Auto-save with toast notifications
- Skip setup flow with forced completion on protected actions
- Edit profile screen with auto-save
- Profile completion check (`isProfileComplete()`)
- Supabase RLS policies (profile ownership, student-only visibility)
- Bio sanitization (XSS prevention, URL removal)
- Colored initials fallback algorithm

### P2 (Should Have - Post-Launch Week 1)
- Pronouns field with bottom sheet picker
- Bio with live character counter (color-coded 0-139 gray, 140-150 orange, 151+ red)
- Avatar colored initials algorithm (deterministic colors A-Z)
- Search functionality in class picker (case-insensitive, partial match)
- Offline save with sync (Hive/SharedPreferences local storage)
- Avatar delete functionality with confirmation dialog
- Profile validation (name regex enforcement)

### P3 (Nice to Have - v1.1)
- Avatar cropper UI (currently auto-crop to square only)
- Profile completion banner in Settings (if incomplete profile)
- Advanced bio validation (emojis whitelist, more granular content filtering)
- Rate limiting via Edge Functions (currently Supabase default limits)
- Analytics tracking (setup completion time, dropout points)
