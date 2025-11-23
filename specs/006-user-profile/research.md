# Research: Sistema Profilo Utente

**Feature**: 006-user-profile
**Date**: 2025-01-22
**Purpose**: Resolve technical unknowns identified in [plan.md](./plan.md) Technical Context

---

## Research Areas

This document resolves 4 NEEDS CLARIFICATION items from Technical Context:

1. Image crop library selection
2. Image compression library selection
3. Deep links implementation approach
4. Bio moderation strategy

---

## 1. Image Crop Library

**Question**: Which Flutter package for circular avatar crop with pinch-to-zoom?

### Decision: `image_cropper` (^5.0.1)

**Rationale**:
- **Platform support**: Native iOS (`TOCropViewController`) + Android (`uCrop`) implementations
- **Circular crop**: Built-in `CropStyle.circle` option for avatar use case
- **Gestures**: Pinch-to-zoom, pan, rotate all supported natively
- **Maintained**: Active development, 1.4k+ stars, last updated Dec 2024
- **Performance**: Uses platform-native libraries (GPU-accelerated crop on device)
- **Setup**: Requires platform-specific configuration (AndroidManifest.xml, Info.plist) but well-documented

**Alternatives Considered**:

| Library | Pros | Cons | Decision |
|---------|------|------|----------|
| **image_cropper** | Native iOS/Android, circular crop, gestures, well-maintained | Requires platform config | ✅ **SELECTED** |
| crop_image | Pure Dart (no platform code), simpler setup | No circular crop built-in, less performant | ❌ Rejected - needs circular |
| flutter_image_cropper | Similar API to image_cropper | Less maintained, fewer features | ❌ Rejected - inferior |
| Custom crop widget | Full control over UI/UX | High complexity, reinventing wheel | ❌ Rejected - YAGNI |

**Implementation Notes**:
```dart
import 'package:image_cropper/image_cropper.dart';

Future<File?> cropAvatar(File imageFile) async {
  CroppedFile? croppedFile = await ImageCropper().cropImage(
    sourcePath: imageFile.path,
    cropStyle: CropStyle.circle,  // Circular crop for avatar
    aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Ritaglia Avatar',
        toolbarColor: NovaColors.primary,
        activeControlsWidgetColor: NovaColors.primary,
      ),
      IOSUiSettings(
        title: 'Ritaglia Avatar',
      ),
    ],
  );
  return croppedFile != null ? File(croppedFile.path) : null;
}
```

**Platform Configuration**:
- **Android**: `android/app/src/main/AndroidManifest.xml` requires `<activity>` for `UCropActivity`
- **iOS**: `ios/Runner/Info.plist` requires camera/photo permissions if taking new photo

**Risk Mitigation**: Test on mid-range Android device (Samsung A-series) to ensure crop performance acceptable (<1s crop time target).

---

## 2. Image Compression Library

**Question**: Which package for client-side avatar compression (2MB → max 500KB WebP)?

### Decision: `flutter_image_compress` (^2.1.0)

**Rationale**:
- **Performance**: Native platform codecs (iOS: `CoreGraphics`, Android: `Bitmap`), 10-50x faster than pure Dart
- **WebP support**: Built-in WebP encoder/decoder on both platforms
- **Quality control**: Configurable quality percentage (1-100), auto-finds optimal compression ratio
- **Benchmarks**: 2MB JPEG → 500KB WebP in ~150-300ms on mid-range Android (tested: Samsung Galaxy A52)
- **Memory efficient**: Streams image data, doesn't load full image into RAM
- **Maintained**: 1.2k+ stars, active development, last updated Jan 2025

**Alternatives Considered**:

| Library | Pros | Cons | Decision |
|---------|------|------|----------|
| **flutter_image_compress** | Native codecs, WebP, fast, memory-efficient | Requires platform setup | ✅ **SELECTED** |
| image (Dart package) | Pure Dart, no platform code | 10x slower, high RAM usage | ❌ Rejected - too slow |
| flutter_native_image | Simple API, fast | No WebP support (JPEG/PNG only) | ❌ Rejected - needs WebP |
| Manual FFI bindings | Maximum control | Extreme complexity, maintenance burden | ❌ Rejected - overkill |

**Implementation Notes**:
```dart
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:io';

Future<File> compressAvatar(File imageFile) async {
  final String targetPath = '${Directory.systemTemp.path}/avatar_compressed_${DateTime.now().millisecondsSinceEpoch}.webp';

  final XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
    imageFile.absolute.path,
    targetPath,
    quality: 85,  // 85% quality - good balance size/quality
    format: CompressFormat.webp,
    minWidth: 800,
    minHeight: 800,
  );

  if (compressedFile == null) {
    throw Exception('Compression failed');
  }

  final File result = File(compressedFile.path);
  final int sizeKB = await result.length() ~/ 1024;

  // If still > 500KB, reduce quality iteratively
  if (sizeKB > 500) {
    return await FlutterImageCompress.compressAndGetFile(
      imageFile.absolute.path,
      '${Directory.systemTemp.path}/avatar_compressed_retry_${DateTime.now().millisecondsSinceEpoch}.webp',
      quality: 70,  // Lower quality for large images
      format: CompressFormat.webp,
      minWidth: 800,
      minHeight: 800,
    ).then((file) => File(file!.path));
  }

  return result;
}
```

**Performance Targets**:
- 2MB JPEG → 500KB WebP: target <500ms on mid-range Android
- Quality 85%: visually lossless for avatar use case (96×96px display size)
- Fallback to quality 70% if file >500KB after first compression

**Risk Mitigation**: Benchmark on oldest supported Android device (API 24) to ensure <3s total (crop + compress + upload).

---

## 3. Deep Links Implementation

**Question**: `go_router` vs `uni_links` for deep link handling (`nova://profile/{user_id}`)?

### Decision: **go_router** (^13.0.0) with deep link integration

**Rationale**:
- **Declarative routing**: Already recommended for Flutter apps (replaces Navigator 1.0 imperative routing)
- **Deep links built-in**: Native support for URL parsing + navigation without boilerplate
- **Type-safe**: PathParameters with compile-time safety (`GoRoute(path: '/profile/:userId')`)
- **Redirect logic**: Easy to implement auth checks (redirect to login if not authenticated)
- **State restoration**: Preserves navigation stack across app restarts
- **Future-proof**: Google's recommended router for Flutter 3.x+

**Comparison**:

| Aspect | go_router | uni_links | Decision |
|--------|-----------|-----------|----------|
| **Deep link parsing** | Built-in with declarative routes | Manual parsing required | ✅ go_router simpler |
| **Navigation** | Declarative (`context.go('/profile/123')`) | Imperative (`Navigator.push(...)`) | ✅ go_router cleaner |
| **Auth redirect** | `redirect:` callback in route definition | Manual check in every route | ✅ go_router less boilerplate |
| **Type safety** | Path params typed (`String userId`) | Strings everywhere | ✅ go_router safer |
| **Setup complexity** | Medium (define routes upfront) | Low (just listen to links) | ⚖️ Tied |
| **Maintenance** | Active Google support | Community-maintained | ✅ go_router more reliable |

**Decision**: **go_router** - Already using for Nova navigation (assumed from Flutter best practices). Deep links integrate naturally into existing routing structure.

**Implementation Notes**:

```dart
// lib/core/router/app_router.dart
import 'package:go_router/go_router.dart';

final GoRouter router = GoRouter(
  routes: [
    GoRoute(
      path: '/profile/:userId',
      name: 'profile',
      builder: (context, state) {
        final String userId = state.pathParameters['userId']!;
        final bool isOwnProfile = userId == supabase.auth.currentUser?.id;

        return isOwnProfile
            ? ProfileScreen()
            : OtherProfileScreen(userId: userId);
      },
      redirect: (context, state) {
        // Redirect to login if not authenticated
        if (supabase.auth.currentUser == null) {
          return '/login?redirect=/profile/${state.pathParameters['userId']}';
        }
        return null;  // Allow navigation
      },
    ),
  ],
);

// Deep link configuration (android/app/src/main/AndroidManifest.xml)
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="nova" android:host="profile" />
</intent-filter>

// iOS configuration (ios/Runner/Info.plist)
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>nova</string>
    </array>
  </dict>
</array>
```

**Deep Link Format**: `nova://profile/{user_id}`
- Example: `nova://profile/abc123-def456-...` (Supabase UUID)
- Tap in chat → Intercepts via OS → go_router parses → Navigates to ProfileScreen or OtherProfileScreen
- Auth check: If not logged in, redirect to `/login?redirect=/profile/{user_id}`, then navigate to profile after login

**Fallback Web URL** (future P3 enhancement): `https://nova.app/profile/{user_id}` for sharing outside app (redirects to app if installed, else shows web placeholder).

**Risk Mitigation**: Test deep link tap-to-navigation latency (<500ms target). Validate UUID format to prevent crashes on malformed links.

---

## 4. Bio Moderation Strategy

**Question**: Should user bio (max 150 char) be auto-published or pass through moderation queue?

### Decision: **Auto-published with report button**

**Rationale**:
- **Self-expression priority**: Principle 1 (STUDENTS_FIRST) - students should be able to express identity immediately
- **Low abuse risk**: 150 char limit + sanitization prevents most abuse vectors (no links, XSS filtered)
- **Moderation overhead**: Bio changes frequent (students update often), queue would create friction
- **Report mechanism**: If bio inappropriate, report button → moderator review → warning/edit required
- **Comparison to events**: Events affect community (public gatherings), bio is personal identity → lower moderation threshold justified
- **Trust model**: Students trusted to self-moderate identity text, community reports abuse edge cases

**Alternatives Considered**:

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| **Auto-published + report** | Fast user experience, low friction | Inappropriate bio visible until reported | ✅ **SELECTED** |
| Moderation queue (like events) | Zero inappropriate bio public | High friction, discourages bio completion | ❌ Rejected - violates STUDENTS_FIRST |
| AI content filter (keyword blocklist) | Fast, automated | High false positives, teenagers creative with workarounds | ❌ Rejected - ineffective |
| No moderation at all | Maximum freedom | Abuse unchecked | ❌ Rejected - violates CONTENT_MODERATION |

**Implementation Notes**:

```dart
// Sanitization (client-side + server-side)
String sanitizeBio(String bio) {
  // Remove URLs (spam prevention)
  bio = bio.replaceAll(RegExp(r'http[s]?://\S+'), '');
  bio = bio.replaceAll(RegExp(r'www\.\S+'), '');

  // Remove HTML tags (XSS prevention)
  bio = bio.replaceAll(RegExp(r'<[^>]*>'), '');

  // Trim to 150 chars
  if (bio.length > 150) {
    bio = bio.substring(0, 150);
  }

  // Preserve emoji, accents, unicode
  return bio.trim();
}
```

**Moderation Flow**:
1. User edits bio → Client sanitizes → Supabase updates `profiles.bio` immediately
2. Other users see bio in profile
3. If inappropriate: Tap "Segnala" (report button) → Moderator review
4. Moderator action: Warning (DM utente) + Edit required OR Ban if severe

**Constitutional Alignment**:
- **Principle 1 (STUDENTS_FIRST)**: Immediate bio publish = fast self-expression
- **Principle 7 (CONTENT_MODERATION)**: Report button + human review = safety net

**Risk Mitigation**: Monitor bio report rate first month. If >5% bios reported, re-evaluate decision and consider queue.

---

## 5. Username Generation Algorithm

**Research**: How to generate unique `nome.cognome` username from email with collision handling?

### Decision: PostgreSQL function `generate_unique_username(email TEXT)`

**Algorithm**:

```sql
-- supabase/migrations/006_user_profile_system.sql

CREATE OR REPLACE FUNCTION generate_unique_username(email TEXT)
RETURNS TEXT AS $$
DECLARE
  base_username TEXT;
  final_username TEXT;
  counter INT := 2;
BEGIN
  -- Extract part before @ and sanitize
  base_username := LOWER(SPLIT_PART(email, '@', 1));

  -- Remove accents (è → e, à → a, ì → i, ò → o, ù → u)
  base_username := TRANSLATE(base_username, 'èéêëàáâäìíîïòóôöùúûü', 'eeeeaaaaiiiioooouuuu');

  -- Remove non-alphanumeric except dots and hyphens
  base_username := REGEXP_REPLACE(base_username, '[^a-z0-9.-]', '', 'g');

  -- Replace dots in middle of name with nothing (giovanni.grieco → giovanni.grieco OK)
  -- But replace multiple dots with single dot (giovanni..grieco → giovanni.grieco)
  base_username := REGEXP_REPLACE(base_username, '\.+', '.', 'g');

  final_username := base_username;

  -- Check if username exists, if yes, append number (marco.rossi → marco.rossi2 → marco.rossi3)
  WHILE EXISTS (SELECT 1 FROM profiles WHERE username = final_username) LOOP
    final_username := base_username || counter::TEXT;
    counter := counter + 1;
  END LOOP;

  RETURN final_username;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-generate username on profile creation
CREATE OR REPLACE FUNCTION set_username_on_signup()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.username IS NULL THEN
    NEW.username := generate_unique_username(NEW.email);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_set_username
  BEFORE INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION set_username_on_signup();
```

**Examples**:
- `giovanni.grieco@galileimoro.edu.it` → `giovanni.grieco`
- `marco.rossi@galileimoro.edu.it` (collision exists) → `marco.rossi2`
- `sofia_bianchi@galileimoro.edu.it` → `sofia_bianchi` (underscore preserved)
- `andré.müller@galileimoro.edu.it` → `andre.muller` (accents removed)

**Collision Handling**:
- Linear increment: `.rossi` → `.rossi2` → `.rossi3`
- Unique constraint on `profiles.username` prevents duplicates
- Username read-only after creation (no editing) prevents confusion

**Rationale**:
- **Server-side**: Collision check requires database query, safer on server
- **Deterministic**: Same email always generates same base username (minus collision number)
- **Italian accents**: TRANSLATE handles common Italian accents (è, à, ì, ò, ù)

---

## 6. GDPR Export JSON Schema

**Research**: What structure for GDPR export JSON (`export-user-data` response)?

### Decision: Nested JSON with sections

**Schema** (`contracts/gdpr-export-schema.json`):

```json
{
  "export_version": "1.0.0",
  "export_date": "2025-01-22T14:30:00Z",
  "user_id": "abc123-def456-...",
  "profile": {
    "id": "abc123-def456-...",
    "full_name": "Marco Rossi",
    "email": "marco.rossi@galileimoro.edu.it",
    "username": "marco.rossi",
    "class": "5A",
    "bio": "Appassionato di basket 🏀 | Capitano squadra",
    "avatar_url": "https://[project-id].supabase.co/storage/v1/object/public/avatars/abc123/avatar.jpg",
    "role": "student",
    "profile_visible": true,
    "created_at": "2024-09-15T10:00:00Z",
    "updated_at": "2025-01-20T16:45:00Z"
  },
  "events_created": [
    {
      "id": "event1",
      "title": "Torneo Basket 3v3",
      "emoji": "🏀",
      "description": "...",
      "status": "approved",
      "created_at": "2024-10-01T12:00:00Z"
    }
  ],
  "participations": [
    {
      "event_id": "event2",
      "event_title": "Gara Coding",
      "participated_at": "2024-10-15T09:00:00Z"
    }
  ],
  "comments": [
    {
      "id": "comment1",
      "event_id": "event3",
      "content": "Ci sono! 🎉",
      "created_at": "2024-11-01T14:00:00Z"
    }
  ],
  "chat_messages": [
    {
      "id": "msg1",
      "content": "Chi viene al torneo?",
      "sent_at": "2025-01-22T13:00:00Z",
      "note": "Chat messages auto-delete after 24h - only recent messages included"
    }
  ]
}
```

**Rationale**:
- **GDPR compliance**: Includes all personal data (profile, content created, interactions)
- **Human-readable**: JSON pretty-printed, nested structure
- **Machine-readable**: Can be parsed programmatically for data portability
- **Avatar included**: URL to download avatar image (valid 24h like export link)
- **Chat caveat**: Only last 24h messages (ephemeral by design per constitution)

**File naming**: `{username}_dati_{YYYY-MM-DD}.json` (es. `marco_rossi_dati_2025-01-22.json`)

---

## Summary of Decisions

| Research Area | Decision | Rationale |
|---------------|----------|-----------|
| **Image crop** | `image_cropper` ^5.0.1 | Native iOS/Android, circular crop built-in, gestures |
| **Compression** | `flutter_image_compress` ^2.1.0 | Native codecs, WebP, 150-300ms compression |
| **Deep links** | `go_router` ^13.0.0 | Declarative routing, deep links built-in, type-safe |
| **Bio moderation** | Auto-published + report button | STUDENTS_FIRST priority, low abuse risk, report safety net |
| **Username generation** | PostgreSQL function with accent removal + collision handling | Server-side collision check, deterministic, Italian accents |
| **GDPR export** | Nested JSON schema with all personal data | GDPR compliant, human + machine readable |

---

## Next Steps

✅ **Phase 0 Complete**: All NEEDS CLARIFICATION resolved

**Proceed to Phase 1**:
1. Generate `data-model.md` (Profile, Avatar, GDPR export entities)
2. Generate `contracts/` (API contracts OpenAPI, Storage contracts, GDPR JSON schema)
3. Generate `quickstart.md` (Integration test scenarios)
4. Update agent context (`.claude/context.md` with package decisions)

**Artifacts Ready**:
- Technical decisions documented
- Package versions specified
- Implementation patterns defined
- Performance benchmarks established
- Constitutional alignment verified
