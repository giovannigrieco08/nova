# Quickstart: Event Creation and Moderation System

**Feature**: 004-event-creation-moderation
**Purpose**: Integration scenarios, testing guides, and developer quickstart
**Date**: 2025-01-09

---

## Prerequisites

**Environment Setup:**
1. Flutter SDK 3.x+ installed
2. Supabase project created (EU Frankfurt region)
3. Firebase project created for FCM (Cloud Messaging enabled)
4. Nova app cloned and dependencies installed (`flutter pub get`)

**Required Secrets:**
- `SUPABASE_URL` (from Supabase dashboard)
- `SUPABASE_ANON_KEY` (public anon key)
- `FIREBASE_PROJECT_ID` (from Firebase console)

---

## Setup Instructions

### 1. Run Database Migration

```bash
cd C:/Users/grigi/nova_def
supabase db push
```

Or manually via Supabase SQL Editor:
- Copy contents of `specs/004-event-creation-moderation/contracts/005_create_events_tables.sql`
- Paste into SQL Editor and execute

**Verify Migration:**
```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('events', 'notifications');
```

### 2. Create Supabase Storage Bucket

Via Supabase Dashboard:
1. Navigate to Storage → Buckets
2. Click "New Bucket"
3. Name: `event-images`
4. Public bucket: **Yes** (checked)
5. File size limit: 5MB (safety buffer, app enforces 200KB)
6. Allowed MIME types: `image/webp`, `image/jpeg`, `image/png`

Via Supabase CLI:
```bash
supabase storage create-bucket event-images --public
```

### 3. Configure Firebase Cloud Messaging

**iOS Setup:**
1. Download `GoogleService-Info.plist` from Firebase Console
2. Place in `nova/ios/Runner/` directory
3. Add to Xcode project (Runner → Add Files)

**Android Setup:**
1. Download `google-services.json` from Firebase Console
2. Place in `nova/android/app/` directory

**Flutter Config:**
```dart
// lib/main.dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

### 4. Create Test Moderator User

Via Supabase SQL Editor:
```sql
-- Find your test user ID
SELECT id, email FROM auth.users WHERE email = 'test@galileimoro.edu.it';

-- Update user to moderator role
UPDATE auth.users
SET raw_user_meta_data = raw_user_meta_data || '{"role": "moderator"}'::jsonb
WHERE email = 'test@galileimoro.edu.it';
```

**Verify:**
```sql
SELECT email, raw_user_meta_data->>'role' as role
FROM auth.users
WHERE email = 'test@galileimoro.edu.it';
```

---

## Integration Scenarios

### Scenario 1: Student Creates Event (Happy Path)

**Actors**: Student user (authenticated)

**Flow:**
1. Student taps "+" FAB on MainFeedScreen
2. EventCreationScreen opens with form
3. Student fills: title, description, event date, location (optional)
4. Student selects image from gallery
5. App compresses image to <200KB (WebP or JPEG fallback)
6. Student taps "Crea Evento"
7. App uploads image to Supabase Storage
8. App creates event via POST /events (status='pending')
9. Success message shown: "Evento creato! Sarà visibile dopo l'approvazione del moderatore"
10. Event appears in "I Miei Eventi" with yellow "In Revisione" badge

**Expected Result**: Event saved with status='pending', not visible in public feed

**Code Example**:
```dart
final event = Event(
  title: 'Torneo di Calcetto',
  description: 'Torneo inter-classe...',
  eventDate: DateTime(2025, 2, 15, 14, 30),
  location: 'Campo sportivo',
  imageUrl: uploadedImageUrl,
  creatorId: auth.currentUser!.id,
  status: EventStatus.pending,
);

await eventRepository.createEvent(event);
```

---

### Scenario 2: Moderator Approves Event

**Actors**: Moderator user

**Flow:**
1. Moderator opens app, sees badge "3" on notifications icon
2. Moderator taps Moderation tab
3. ModerationQueueScreen shows 3 pending events (oldest first)
4. Moderator reviews first event (checks title, description, image, date)
5. Event appropriate → moderator swipes right OR taps "Approva"
6. App calls PATCH /events with status='approved'
7. Database trigger fires: notification created, creator receives push
8. Event removed from moderation queue
9. Event appears in public feed

**Expected Result**: Creator receives push notification within 30 seconds, event visible to all students

**Code Example**:
```dart
await eventRepository.approveEvent(
  eventId: event.id,
  moderatorId: auth.currentUser!.id,
);
```

**Database State:**
```sql
-- Before approval
status = 'pending', moderated_by = NULL, moderated_at = NULL

-- After approval
status = 'approved', moderated_by = {moderator_uuid}, moderated_at = now()
```

---

### Scenario 3: Moderator Rejects Event

**Actors**: Moderator user

**Flow:**
1. Moderator sees inappropriate event in queue
2. Moderator swipes left OR taps "Rifiuta"
3. Dialog opens: "Motivo rifiuto" text field (required, min 10 chars)
4. Moderator types: "Descrizione troppo vaga, aggiungi dettagli su orario preciso"
5. Moderator taps "Conferma"
6. App calls PATCH /events with status='rejected' + rejection_reason
7. Database trigger fires: notification created, creator receives push
8. Event removed from moderation queue

**Expected Result**: Creator receives push + sees rejection reason in "I Miei Eventi"

**Code Example**:
```dart
await eventRepository.rejectEvent(
  eventId: event.id,
  moderatorId: auth.currentUser!.id,
  reason: 'Descrizione troppo vaga...',
);
```

---

### Scenario 4: Student Shares Event via Deep Link

**Actors**: Student viewer

**Flow:**
1. Student views approved event in feed
2. Student taps "Condividi" button
3. App generates deep link: `nova://events/{event_id}`
4. Native share sheet opens (iOS UIActivityViewController / Android ShareSheet)
5. Student selects WhatsApp
6. Message sent with deep link + preview
7. Recipient (with Nova installed) taps link
8. Nova app opens directly to EventDetailScreen for that event

**Expected Result**: Seamless deep linking to specific event

**Code Example**:
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

**Deep Link Handling**:
```dart
// main.dart
final initialLink = await getInitialLink();
if (initialLink != null && initialLink.startsWith('nova://events/')) {
  final eventId = initialLink.split('/').last;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EventDetailScreen(eventId: eventId),
    ),
  );
}
```

---

### Scenario 5: Student Adds Co-Organizers

**Actors**: Event creator

**Flow:**
1. Creator opens their event in "I Miei Eventi"
2. Taps "Modifica" → EventEditScreen
3. Taps "Aggiungi Co-Organizer"
4. CoOrganizerSearchWidget opens
5. Creator searches "Mario Rossi" by name
6. Selects Mario from results (autocomplete dropdown)
7. Mario added to co-organizers list (max 3)
8. Creator taps "Salva"
9. App calls PATCH /events with updated co_organizers array
10. Database trigger fires: Mario receives push notification
11. Mario sees event in "Eventi Organizzati" section of profile

**Expected Result**: Mario can now edit the event, receives notifications

**Code Example**:
```dart
final updatedEvent = event.copyWith(
  coOrganizers: [...event.coOrganizers, 'mario-uuid'],
);

await eventRepository.updateEvent(updatedEvent);
```

---

### Scenario 6: Offline Event Creation

**Actors**: Student user (offline)

**Flow:**
1. Student has no network connection
2. Student taps "+" FAB, fills event form
3. Student selects image, fills all fields
4. Student taps "Crea Evento"
5. App detects offline state
6. App saves draft to Hive local storage
7. Snackbar shown: "Nessuna connessione. Evento salvato in bozza"
8. Student closes app
9. Network returns
10. Student reopens app
11. App detects saved draft + network available
12. Dialog shown: "Riprendere creazione evento salvato?"
13. Student taps "Sì"
14. Form pre-filled with draft data
15. Student taps "Crea Evento" again
16. App uploads image + creates event successfully
17. Draft deleted from Hive

**Expected Result**: Zero data loss, seamless offline→online transition

**Code Example**:
```dart
// Save draft on network error
try {
  await eventRepository.createEvent(event);
} on SocketException {
  await hiveDraftBox.put('current_draft', eventDraft);
  showSnackbar('Nessuna connessione. Evento salvato in bozza');
}

// Restore draft on app start
final draft = hiveDraftBox.get('current_draft');
if (draft != null) {
  final hasNetwork = await checkConnectivity();
  if (hasNetwork) {
    showDialog(/* "Riprendere creazione evento?" */);
  }
}
```

---

## Testing Guide

### Unit Tests

**Test: Event entity validation**
```dart
test('Event title must be 5-100 characters', () {
  expect(
    () => Event(title: 'abc', /* ... */), // Too short
    throwsA(isA<ValidationException>()),
  );

  expect(
    () => Event(title: 'a' * 101, /* ... */), // Too long
    throwsA(isA<ValidationException>()),
  );
});
```

**Test: Image compression**
```dart
test('compress image to under 200KB', () async {
  final largeImage = File('test_assets/large_image.jpg'); // 5MB
  final compressed = await imageCompressor.compress(largeImage);

  expect(compressed.lengthInBytes, lessThanOrEqualTo(200 * 1024));
});
```

---

### Integration Tests

**Test: Complete event creation flow**
```dart
testWidgets('Student creates event end-to-end', (tester) async {
  await tester.pumpWidget(NovaApp());

  // Tap "+" FAB
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();

  // Fill form
  await tester.enterText(find.byKey(Key('title_field')), 'Test Event');
  await tester.enterText(find.byKey(Key('description_field')), 'Test description with at least 20 characters');
  await tester.tap(find.byKey(Key('date_picker')));
  // ... select future date

  // Submit
  await tester.tap(find.text('Crea Evento'));
  await tester.pumpAndSettle();

  // Verify success message
  expect(find.text('Evento creato!'), findsOneWidget);

  // Verify event in "I Miei Eventi"
  await tester.tap(find.byIcon(Icons.person));
  await tester.pumpAndSettle();
  expect(find.text('Test Event'), findsOneWidget);
  expect(find.text('In Revisione'), findsOneWidget); // Pending badge
});
```

---

### Manual Testing Checklist

**Event Creation:**
- [ ] Form validation shows errors for invalid inputs
- [ ] Image compression reduces 5MB image to <200KB
- [ ] Event saved with status='pending'
- [ ] Success message displayed
- [ ] Event appears in "I Miei Eventi" with yellow badge

**Moderation:**
- [ ] Moderator sees pending queue sorted by oldest first
- [ ] Approve action changes status to 'approved'
- [ ] Creator receives push notification within 30 seconds
- [ ] Reject action requires min 10-char reason
- [ ] Rejected event shows reason to creator

**Deep Linking:**
- [ ] Share button generates correct `nova://events/{id}` link
- [ ] Tapping link (with app installed) opens EventDetailScreen
- [ ] Tapping link (without app) shows web fallback page

**Offline Mode:**
- [ ] Draft saved when network unavailable
- [ ] Draft restored when app reopens with network
- [ ] No duplicate events created

**Performance:**
- [ ] Image upload + event creation <3s on 4G
- [ ] Feed loads <1s with cached data
- [ ] No dropped frames during form scrolling

---

## Troubleshooting

**Issue**: RLS policy error when creating event

**Solution**: Verify user is authenticated and creator_id matches auth.uid()

```sql
-- Check RLS policies
SELECT * FROM pg_policies WHERE tablename = 'events';

-- Test as current user
SELECT * FROM events; -- Should work
```

---

**Issue**: Push notifications not delivered

**Solution**:
1. Verify FCM token stored in users table
2. Check notification channel enabled in app settings
3. Test FCM token via Firebase Console → Cloud Messaging → Send test message

```dart
final token = await FirebaseMessaging.instance.getToken();
print('FCM Token: $token');
```

---

**Issue**: Image upload fails with 413 error

**Solution**: Verify image compressed to <200KB before upload

```dart
final compressed = await imageCompressor.compress(imageFile);
print('Compressed size: ${compressed.lengthInBytes} bytes');
assert(compressed.lengthInBytes <= 200 * 1024, 'Image too large!');
```

---

## Quick Reference

**Event Statuses:**
- `pending`: Awaiting moderation (not visible in public feed)
- `approved`: Visible to all students in feed
- `rejected`: Not visible, creator can see rejection reason

**Notification Channels:**
- `event_approved`: Creator notified when event approved
- `event_rejected`: Creator notified when event rejected
- `new_pending_event`: Moderator notified (batched daily)
- `added_as_coorganizer`: User added as co-organizer
- `event_modified`: Event edited by co-organizer/creator

**Performance Budgets:**
- Image upload: <3s on 4G
- Form completion: <2 min average
- Moderation action: <30s
- Push delivery: >90% within 30s

---

**Quickstart Complete**. For detailed API contracts, see `contracts/supabase-rest-api.md`.
