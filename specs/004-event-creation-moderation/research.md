# Research: Event Creation and Moderation System

**Feature**: 004-event-creation-moderation
**Phase**: 0 (Research & Technical Decision Documentation)
**Date**: 2025-01-09

---

## 1. Client-Side Image Compression (Flutter)

### Decision

Use **flutter_image_compress** package with adaptive format strategy: **WebP preferred, JPEG fallback**.

### Rationale

**WebP advantages:**
- 25-35% smaller file sizes vs JPEG at same quality
- Modern format supported on iOS 14+ (target platform)
- Transparency support (not needed but future-proof)

**JPEG fallback necessity:**
- Older iOS devices (<iOS 14) may have limited WebP support in image pickers
- Some Android devices with custom ROMs may lack WebP encoding libraries
- Compression failure edge case requires robust fallback

**Implementation approach:**
```dart
Future<Uint8List> compressImage(File imageFile) async {
  try {
    // Attempt WebP compression first
    final webpResult = await FlutterImageCompress.compressWithFile(
      imageFile.absolute.path,
      minWidth: 800,
      minHeight: 450,
      quality: 85,
      format: CompressFormat.webp,
    );

    if (webpResult != null && webpResult.lengthInBytes <= 200 * 1024) {
      return webpResult;
    }
  } catch (e) {
    // WebP compression failed, fall back to JPEG
  }

  // JPEG fallback
  final jpegResult = await FlutterImageCompress.compressWithFile(
    imageFile.absolute.path,
    minWidth: 800,
    minHeight: 450,
    quality: 70, // Lower quality for JPEG to stay under 200KB
    format: CompressFormat.jpeg,
  );

  return jpegResult!;
}
```

**EXIF metadata removal:**
- `flutter_image_compress` automatically strips EXIF data during compression
- No additional library needed (privacy requirement FR-005 satisfied automatically)

### Alternatives Considered

- **image** package (Dart native): Pure Dart implementation, but slower and lacks native codec optimizations
- **Server-side compression**: Violates <3s performance budget (FR-007) due to network round-trip

---

## 2. Firebase Cloud Messaging (FCM) Integration

### Decision

Use **Firebase Cloud Messaging (FCM)** via `firebase_messaging` package integrated with Supabase Auth.

### Rationale

**Why FCM:**
- Industry-standard push notification service (99%+ delivery rate)
- Free tier supports unlimited notifications
- Excellent iOS/Android support with automatic badge management
- Deep integration with Flutter via official package

**Supabase + FCM Integration:**
```dart
// Store FCM tokens in users table
await supabase
  .from('users')
  .update({'fcm_token': await FirebaseMessaging.instance.getToken()})
  .eq('id', auth.currentUser!.id);
```

**Notification Channels (Android):**
```dart
const AndroidNotificationChannel channelApproved = AndroidNotificationChannel(
  'event_approved',
  'Eventi Approvati',
  description: 'Notifiche quando il tuo evento viene approvato',
  importance: Importance.high,
);
```

**FR-036 Opt-in Implementation:**
- Request permission on first app launch
- Store preferences in `SharedPreferences`
- Respect user opt-out in backend notification logic

### Alternatives Considered

- **Supabase Realtime**: Not suitable for push notifications (requires app open)
- **OneSignal**: Third-party tracking concerns (violates Principle 2: PRIVACY_FOUNDATION)

---

## 3. Deep Linking (uni_links + Web Fallback)

### Decision

Use **uni_links** package for deep link handling with **Supabase Storage-hosted static HTML fallback**.

### Rationale

**Deep Link Format:**
- Custom URL scheme: `nova://events/{event_id}`
- Example: `nova://events/550e8400-e29b-41d4-a716-446655440000`

**Implementation:**
```dart
// App initialization
final initialLink = await getInitialLink();
if (initialLink != null) {
  final eventId = extractEventId(initialLink); // Parse "nova://events/{id}"
  Navigator.push(context, EventDetailScreen(eventId: eventId));
}

// Stream for links while app is running
linkStream.listen((String? link) {
  final eventId = extractEventId(link);
  Navigator.push(context, EventDetailScreen(eventId: eventId));
});
```

**Web Fallback (Supabase Storage):**

Host static HTML at `supabase/storage/web-fallback/event.html`:
```html
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Evento - Nova</title>
</head>
<body>
  <div id="event-container">Loading...</div>
  <script>
    // Extract event ID from URL query param
    const params = new URLSearchParams(window.location.search);
    const eventId = params.get('id');

    // Fetch event data from Supabase REST API
    fetch(`https://{project}.supabase.co/rest/v1/events?id=eq.${eventId}`, {
      headers: { 'apikey': '{anon-key}' }
    })
    .then(res => res.json())
    .then(data => {
      // Render event preview + "Download Nova" button
      document.getElementById('event-container').innerHTML = `
        <h1>${data[0].title}</h1>
        <img src="${data[0].image_url}" />
        <p>${data[0].description}</p>
        <a href="https://apps.apple.com/...">Download Nova (iOS)</a>
        <a href="https://play.google.com/...">Download Nova (Android)</a>
      `;
    });
  </script>
</body>
</html>
```

**URL redirection logic:**
- User without app clicks `nova://events/ABC` → Browser redirects to `https://{project}.supabase.co/storage/v1/object/public/web-fallback/event.html?id=ABC`
- User with app clicks link → App intercepts and opens EventDetailScreen

### Alternatives Considered

- **Firebase Dynamic Links**: Requires Firebase Hosting setup, adds dependency (beyond FCM)
- **Custom domain hosting**: Out of scope for MVP (requires nova.galileimoro.edu.it domain setup)

---

## 4. Offline-First Form Drafts (Hive)

### Decision

Use **Hive** for local storage of event creation form drafts.

### Rationale

**Why Hive:**
- Fast, pure-Dart NoSQL database (no native dependencies)
- Excellent Flutter integration
- Type-safe with code generation
- Lightweight (<100KB)

**Implementation Pattern:**
```dart
@HiveType(typeId: 1)
class EventDraft extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  String description;

  @HiveField(2)
  DateTime? eventDate;

  @HiveField(3)
  String? location;

  @HiveField(4)
  String? imagePath; // Local file path before upload

  @HiveField(5)
  DateTime lastSaved;
}

// Save draft on form field changes
final box = Hive.box<EventDraft>('eventDrafts');
box.put('current_draft', draft);

// Restore draft on app reopen
final savedDraft = box.get('current_draft');
```

**Auto-save strategy:**
- Debounce saves (500ms delay after last keystroke)
- Single draft at a time (overwrite previous)
- Delete draft after successful event creation
- Keep draft across app restarts until form submitted

### Alternatives Considered

- **SharedPreferences**: Limited to String/int/bool, requires manual JSON serialization
- **SQLite**: Overkill for single-draft storage, heavier dependency

---

## 5. Supabase Row-Level Security (RLS) Policies

### Decision

Implement **strict RLS policies** on `events` table with role-based access control.

### Rationale

**Required Policies (per constitutional Section "Security Requirements"):**

**Policy 1: Students See Only Approved Events**
```sql
CREATE POLICY "Students see approved events"
  ON events
  FOR SELECT
  USING (status = 'approved');
```

**Policy 2: Moderators See Pending Events**
```sql
CREATE POLICY "Moderators see pending events"
  ON events
  FOR SELECT
  USING (
    auth.jwt() ->> 'role' = 'moderator'
    OR status = 'approved'
  );
```

**Policy 3: Creators/Co-Organizers Can Edit**
```sql
CREATE POLICY "Creators and co-organizers can edit"
  ON events
  FOR UPDATE
  USING (
    creator_id = auth.uid()
    OR auth.uid() = ANY(co_organizers)
  );
```

**Policy 4: Only Moderators Can Approve/Reject**
```sql
CREATE POLICY "Only moderators can change status"
  ON events
  FOR UPDATE
  USING (auth.jwt() ->> 'role' = 'moderator')
  WITH CHECK (
    -- Prevent non-moderators from changing status column
    (OLD.status IS NOT DISTINCT FROM NEW.status)
    OR (auth.jwt() ->> 'role' = 'moderator')
  );
```

**Testing RLS Policies:**
```sql
-- Test as student (should only see approved)
SET request.jwt.claims = '{"sub": "student-uuid", "role": "student"}';
SELECT * FROM events; -- Returns only status='approved'

-- Test as moderator (should see all)
SET request.jwt.claims = '{"sub": "moderator-uuid", "role": "moderator"}';
SELECT * FROM events; -- Returns all events
```

### Alternatives Considered

- **Application-layer filtering**: Insecure, bypassable via direct API calls (rejected)

---

## 6. Share Sheet Integration (share_plus)

### Decision

Use **share_plus** package for native iOS/Android share sheet integration.

### Rationale

**Why share_plus:**
- Official Flutter Community package
- Native share sheet UI (iOS UIActivityViewController, Android ShareSheet)
- Supports text + URL sharing
- Zero configuration required

**Implementation:**
```dart
import 'package:share_plus/share_plus.dart';

void shareEvent(Event event) {
  final deepLink = 'nova://events/${event.id}';
  Share.share(
    'Guarda questo evento su Nova: ${event.title}\n$deepLink',
    subject: event.title,
  );
}
```

**Platforms:**
- iOS: Opens UIActivityViewController with WhatsApp, Messages, Instagram, etc.
- Android: Opens Android ShareSheet with installed share targets

### Alternatives Considered

- **flutter_share**: Deprecated, unmaintained
- **Custom share implementation**: Reinventing the wheel, no benefit

---

## 7. Form Validation Strategy

### Decision

Use **real-time validation** with visual error indicators (FR-003).

### Rationale

**Best Practices:**
- Validate on field blur (not on every keystroke - reduces noise)
- Show errors inline below field
- Disable submit button until all required fields valid
- Use Riverpod form state provider for centralized validation

**Implementation:**
```dart
class EventFormState {
  final String title;
  final String? titleError;
  final String description;
  final String? descriptionError;
  final DateTime? eventDate;
  final String? eventDateError;
  final bool isValid;

  bool get isTitleValid => title.length >= 5 && title.length <= 100;
  bool get isDescriptionValid => description.length >= 20 && description.length <= 500;
  bool get isEventDateValid => eventDate != null && eventDate!.isAfter(DateTime.now());
}
```

**Validation Rules (from FR-001):**
- Title: 5-100 characters
- Description: 20-500 characters
- Event Date: Must be in future
- Location: Optional (no validation)
- Image: Optional (size validated after compression)

### Alternatives Considered

- **Validation on submit only**: Poor UX, user doesn't know errors until end
- **Validation on every keystroke**: Noisy, frustrating for users

---

## 8. Image Storage Architecture

### Decision

Use **Supabase Storage "event-images" bucket** with public read access and RLS write policies.

### Rationale

**Bucket Configuration:**
```sql
-- Create bucket via Supabase dashboard or CLI
INSERT INTO storage.buckets (id, name, public)
VALUES ('event-images', 'event-images', true);

-- RLS policy: Only authenticated users can upload
CREATE POLICY "Authenticated users can upload event images"
  ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'event-images'
    AND auth.role() = 'authenticated'
  );

-- RLS policy: Public read access
CREATE POLICY "Public can read event images"
  ON storage.objects
  FOR SELECT
  USING (bucket_id = 'event-images');
```

**File Naming Convention:**
- Format: `{event_id}_{timestamp}.webp` or `{event_id}_{timestamp}.jpeg`
- Example: `550e8400-e29b-41d4-a716-446655440000_1704789600.webp`
- Prevents filename conflicts
- Allows easy cleanup if event deleted

**Signed URLs:**
- Not needed (bucket is public for performance)
- Images cached by CDN (Supabase uses Cloudflare CDN)
- 1-hour expiry mentioned in spec (EventImage entity) not applicable for public bucket

### Alternatives Considered

- **Private bucket with signed URLs**: Adds complexity, slower load times, no benefit (images not sensitive)

---

## Summary of Technical Decisions

| Component | Technology | Key Rationale |
|-----------|-----------|---------------|
| Image Compression | flutter_image_compress (WebP + JPEG fallback) | Best compression, platform compatibility |
| Push Notifications | Firebase Cloud Messaging | Industry standard, 99%+ delivery, free |
| Deep Linking | uni_links + Supabase Storage HTML | Simple, no third-party dependencies |
| Offline Storage | Hive | Fast, type-safe, pure Dart |
| Access Control | Supabase RLS policies | Security at database level, impossible to bypass |
| Share Sheet | share_plus | Native UI, zero config |
| Form Validation | Real-time with Riverpod | Best UX, centralized state |
| Image Storage | Supabase Storage (public bucket) | CDN-backed, simple, fast |

---

**Phase 0 Complete**: All technical unknowns resolved. Proceed to Phase 1 (Data Model & Contracts).
