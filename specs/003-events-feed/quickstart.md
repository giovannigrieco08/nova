# Quickstart Guide: Events Feed

**Feature**: 003-events-feed
**Date**: 2025-01-02
**Purpose**: Integration scenarios, testing workflows, and developer setup guide.

---

## Prerequisites

### Required Dependencies

Ensure the following are installed before starting:

```bash
# Flutter SDK 3.x+
flutter --version

# Dart SDK 3.x+
dart --version

# VS Code or Android Studio with Flutter plugins

# Physical device or emulator (Android 8+ or iOS 15+)
```

### Supabase Project Setup

1. **Create Supabase project** at [supabase.com/dashboard](https://supabase.com/dashboard)
2. **Run database migrations** from `specs/003-events-feed/contracts/`:
   - Execute `rls-policies.sql` in Supabase SQL Editor
3. **Enable Realtime** on tables:
   ```sql
   ALTER PUBLICATION supabase_realtime ADD TABLE events;
   ALTER PUBLICATION supabase_realtime ADD TABLE comments;
   ```
4. **Configure `.env` file** in project root:
   ```env
   SUPABASE_URL=https://[your-project-id].supabase.co
   SUPABASE_ANON_KEY=[your-anon-key]
   ```

---

## Quick Start (5 Minutes)

### 1. Install Dependencies

```bash
cd nova
flutter pub get
```

### 2. Run App

```bash
# Debug mode (allows personal emails via EmailValidator.forceAllowPersonalEmails)
flutter run

# Or run on specific device
flutter run -d [device-id]
```

### 3. Test Basic Flow

1. **Login** with email (Gmail/Outlook allowed in debug mode)
2. **View feed** (should load from cache <1s if data exists)
3. **Tap event** to open detail screen
4. **Like event** (optimistic UI - instant red heart)
5. **Post comment** (500 char limit enforced)
6. **Pull to refresh** (reload events)

---

## Integration Scenarios

### Scenario 1: Feed Display (P1)

**User Story**: View infinite scroll events feed

**Test Steps**:
1. Launch app → authenticate
2. Navigate to Events tab
3. **Expected**: First 20 approved events load from cache (<1s) OR network (<3s on 4G)
4. Scroll to bottom
5. **Expected**: Next 20 events load automatically (pagination indicator at bottom)
6. Scroll back to top, pull down
7. **Expected**: Refresh indicator appears, first 20 events reload, scroll position resets to top

**Acceptance Criteria** (User Story 1):
- ✅ Feed loads in <1s from cache (FR-058)
- ✅ Feed shows 20 events per page (FR-001)
- ✅ Events sorted newest first by `created_at` (FR-003)
- ✅ Only approved events shown (FR-002)
- ✅ Pagination loads next page automatically (FR-001)
- ✅ Pull-to-refresh reloads first page (FR-006c)

**Debug**:
- Check logs: `debugPrint('🔧 EventsRepository: Loading page X')`
- Verify query: `SELECT * FROM events WHERE status='approved' AND event_date >= CURRENT_DATE ORDER BY created_at DESC LIMIT 20 OFFSET 0`

---

### Scenario 2: Event Detail Screen (P1)

**User Story**: View event detail screen with gallery

**Test Steps**:
1. Tap any event card from feed
2. **Expected**: Hero animation on image, detail screen loads with full data
3. View event details (title, description, date/time, location, creator profile)
4. If multiple images, swipe gallery horizontally
5. **Expected**: Dot indicators show current image position
6. Tap creator profile
7. **Expected**: Navigate to filtered view of creator's events (future feature)
8. Pull down from top
9. **Expected**: Refresh event data, comments, participant list

**Acceptance Criteria** (User Story 2):
- ✅ Hero animation on image (FR-006)
- ✅ Full event details displayed (FR-011)
- ✅ Gallery swipeable if multiple images (FR-012)
- ✅ Participant list shows up to 5 avatars (FR-013)
- ✅ Pull-to-refresh reloads all data (FR-014b)

**Debug**:
- Check logs: `debugPrint('🔧 EventDetailProvider: Loading event $eventId')`
- Verify query: `SELECT * FROM events WHERE id='[event-id]'`

---

### Scenario 3: Like Event (P2 - Optimistic UI)

**User Story**: Like/unlike events with instant feedback

**Test Steps**:
1. View event (feed or detail screen)
2. Tap heart icon
3. **Expected**: Heart turns red IMMEDIATELY (<200ms), like count increases by 1
4. Tap heart again
5. **Expected**: Heart turns grey IMMEDIATELY, like count decreases by 1
6. Enable airplane mode, tap heart
7. **Expected**: Heart turns red, snackbar "You're offline. Like will be synced when online"
8. Disable airplane mode
9. **Expected**: Like syncs automatically with exponential backoff (1s, 2s, 4s)
10. If sync fails after 3 attempts, **Expected**: Notification "Some actions couldn't be synced" with "Retry" button

**Acceptance Criteria** (User Story 3):
- ✅ Optimistic UI response <200ms (FR-064, SC-005)
- ✅ Like state persists across app restarts (FR-020)
- ✅ Offline actions queued and synced (FR-010, FR-010a)
- ✅ Retry notification after 3 failed attempts (FR-010b)

**Debug**:
- Check logs: `debugPrint('🔧 InteractionsRepository: Liking event $eventId')`
- Check Hive: `await Hive.box('offline_actions_queue').values.toList()`
- Verify query: `INSERT INTO likes (event_id, user_id) VALUES ('[event-id]', '[user-id]')`

---

### Scenario 4: Post Comment (P2 - Real-time)

**User Story**: Post comments with character counter and real-time updates

**Test Steps**:
1. Open event detail screen
2. Tap comment input field
3. **Expected**: Keyboard appears, character counter shows "0/500", Send button disabled
4. Type 250 characters
5. **Expected**: Counter shows "250/500", Send button enabled
6. Type 250 more characters (total 500)
7. **Expected**: Counter shows "500/500", Send button enabled
8. Try typing more
9. **Expected**: Text field prevents input beyond 500 chars
10. Delete 100 characters, tap Send
11. **Expected**: Comment appears at bottom immediately (optimistic UI), input field clears
12. On second device, view same event
13. **Expected**: New comment appears within 2 seconds (Realtime)

**Acceptance Criteria** (User Story 5):
- ✅ Character counter live updates (FR-029b)
- ✅ Send button disabled when empty or >500 chars (FR-029c)
- ✅ Comment appears immediately (optimistic UI, FR-030)
- ✅ Real-time updates <2s (SC-007)

**Debug**:
- Check logs: `debugPrint('🔧 CommentsRepository: Posting comment')`
- Check Realtime: `debugPrint('🔔 Realtime: New comment received')`
- Verify query: `INSERT INTO comments (event_id, author_id, text) VALUES ('[event-id]', '[user-id]', '[text]')`

---

### Scenario 5: Edit Own Event (P3 - Creator Only)

**User Story**: Edit event details after publishing

**Test Steps**:
1. Navigate to an event YOU created
2. **Expected**: "Edit" button visible in top right
3. Tap "Edit"
4. **Expected**: Form pre-filled with current data (title, description, date, time, location)
5. **Expected**: Images shown but NOT editable (handled by separate feature)
6. Edit title and description
7. Tap "Save"
8. **Expected**: Loading indicator, snackbar "Event updated successfully", return to detail screen
9. **Expected**: Updated data visible immediately
10. On second device, view same event
11. **Expected**: Updated data appears within 5 seconds (Realtime)

**Acceptance Criteria** (User Story 6):
- ✅ Edit button only visible to creator (FR-035)
- ✅ Form pre-filled with current data (FR-036)
- ✅ Images display-only (FR-036)
- ✅ Text fields editable (FR-037)
- ✅ Real-time updates broadcast (FR-040)

**Debug**:
- Check logs: `debugPrint('🔧 EventsRepository: Updating event $eventId')`
- Verify RLS: User can only edit their own events (creator_id = auth.uid())
- Verify query: `UPDATE events SET title='[new-title]', description='[new-description]' WHERE id='[event-id]' AND creator_id=auth.uid()`

---

### Scenario 6: Offline-First Cache (P1)

**User Story**: View cached events without network

**Test Steps**:
1. Launch app, view feed
2. **Expected**: Events load from cache <1s
3. Scroll through feed, view 3-4 events
4. Close app
5. Enable airplane mode
6. Launch app again
7. **Expected**: Previously viewed events load from cache immediately
8. **Expected**: Banner "Viewing offline events" appears at top
9. Tap event to view details
10. **Expected**: Cached event data loads
11. Try liking event
12. **Expected**: Optimistic UI shows like, action queued for sync
13. Disable airplane mode
14. **Expected**: Banner disappears, background refresh fetches fresh data silently

**Acceptance Criteria**:
- ✅ Cache loads <1s (FR-058)
- ✅ Offline banner shown (FR-009)
- ✅ Offline actions queued (FR-010, FR-010c)
- ✅ Background refresh silent (FR-008)

**Debug**:
- Check Hive: `await Hive.box<EventModel>('events_cache').values.toList()`
- Check logs: `debugPrint('🔧 LocalDataSource: Loading from cache')`

---

## Testing Workflows

### Manual Testing Checklist

**Feed Display**:
- [ ] First page loads <1s from cache
- [ ] First page loads <3s from network (4G)
- [ ] Pagination triggers at bottom (within 3 items)
- [ ] Pull-to-refresh reloads first page
- [ ] Empty state shown if no events
- [ ] Offline banner shown when offline

**Event Detail**:
- [ ] Hero animation on image
- [ ] All fields displayed correctly
- [ ] Gallery swipeable if multiple images
- [ ] Participant list shows up to 5 avatars
- [ ] Comments section scrollable
- [ ] Pull-to-refresh reloads all data

**Interactions**:
- [ ] Like button instant feedback <200ms
- [ ] Unlike button instant feedback <200ms
- [ ] Participate button instant feedback <200ms
- [ ] Comment post instant feedback <200ms
- [ ] Character counter live updates
- [ ] Send button disabled when appropriate

**Offline-First**:
- [ ] Cache loads instantly
- [ ] Offline banner shown
- [ ] Actions queued when offline
- [ ] Retry with exponential backoff (1s, 2s, 4s)
- [ ] Notification shown after 3 failed retries

**Real-Time**:
- [ ] New comments appear <2s
- [ ] Event updates appear <5s
- [ ] Reconnection indicator shown on disconnect

---

### Automated Testing

**Widget Tests**:

```dart
// Test event card widget
testWidgets('EventCard displays all fields', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: EventCard(event: mockEvent),
    ),
  );

  expect(find.text('Test Event'), findsOneWidget);
  expect(find.text('Jan 15, 2025 at 3:00 PM'), findsOneWidget);
  expect(find.byType(CachedNetworkImage), findsOneWidget);
});

// Test character counter
testWidgets('Comment input shows character counter', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CommentInputField(eventId: 'test-id'),
    ),
  );

  final textField = find.byType(TextField);
  await tester.enterText(textField, 'Hello world');
  await tester.pump();

  expect(find.text('11/500'), findsOneWidget);
});
```

**Integration Tests**:

```dart
// Test full feed flow
testWidgets('Events feed loads and paginates', (tester) async {
  await tester.pumpWidget(MyApp());

  // Wait for auth
  await tester.pumpAndSettle();

  // Navigate to Events tab
  await tester.tap(find.text('Events'));
  await tester.pumpAndSettle();

  // Verify first page loaded
  expect(find.byType(EventCard), findsNWidgets(20));

  // Scroll to bottom
  await tester.drag(find.byType(ListView), Offset(0, -5000));
  await tester.pumpAndSettle();

  // Verify second page loaded
  expect(find.byType(EventCard), findsNWidgets(40));
});
```

---

## Performance Profiling

### Measure Feed Load Time

```dart
final stopwatch = Stopwatch()..start();

final events = await repository.getEventsFeed();

stopwatch.stop();
debugPrint('🕒 Feed load time: ${stopwatch.elapsedMilliseconds}ms');

// Expected: <1000ms from cache, <3000ms from network
```

### Measure Scrolling FPS

1. Open Flutter DevTools → Performance tab
2. Scroll through feed
3. Verify **sustained 60fps** with zero dropped frames (FR-060, SC-002)

### Measure Optimistic UI Response Time

```dart
final stopwatch = Stopwatch()..start();

await likeEvent(eventId);

stopwatch.stop();
debugPrint('🕒 Like response time: ${stopwatch.elapsedMilliseconds}ms');

// Expected: <200ms perceived response (FR-064, SC-005)
```

---

## Common Pitfalls & Debugging

### Issue 1: Feed Not Loading

**Symptom**: Feed shows loading spinner forever

**Debug**:
1. Check network: `await Connectivity().checkConnectivity()`
2. Check Supabase connection: `await supabase.from('events').select().limit(1)`
3. Check RLS policies: Verify user can view approved events
4. Check logs: `debugPrint('🔧 EventsRepository: Error - $e')`

**Fix**:
- Verify `.env` file has correct Supabase credentials
- Verify RLS policies allow SELECT on approved events
- Verify events exist with `status='approved'` and `event_date >= CURRENT_DATE`

---

### Issue 2: Optimistic UI Not Working

**Symptom**: Like button shows loading spinner instead of instant feedback

**Debug**:
1. Check if optimistic state update is synchronous (no `await`)
2. Check if rollback logic is working on failure
3. Check logs: `debugPrint('🔧 InteractionsRepository: Optimistic like - event $eventId')`

**Fix**:
- Ensure local state updates BEFORE network request:
  ```dart
  // CORRECT
  await localDataSource.setLikeState(eventId, userId, liked: true);  // Instant
  await remoteDataSource.likeEvent(eventId);  // Background

  // WRONG
  await remoteDataSource.likeEvent(eventId);  // Blocks UI
  await localDataSource.setLikeState(eventId, userId, liked: true);
  ```

---

### Issue 3: Real-Time Comments Not Appearing

**Symptom**: New comments don't appear instantly on second device

**Debug**:
1. Check Realtime enabled: `ALTER PUBLICATION supabase_realtime ADD TABLE comments;`
2. Check subscription status: `debugPrint('🔔 Realtime status: $status')`
3. Check RLS policies: Verify user can view comments on approved events
4. Check network: Realtime uses WebSocket (port 443)

**Fix**:
- Verify Realtime enabled on comments table (Supabase Dashboard → Database → Publications)
- Verify RLS allows SELECT on comments
- Check browser/network allows WebSocket connections

---

### Issue 4: Character Limit Not Enforced

**Symptom**: User can type >500 characters in comment field

**Debug**:
1. Check `maxLength` prop on `TextField`: `TextField(maxLength: 500)`
2. Check database constraint: `SHOW CREATE TABLE comments;`
3. Check client-side validation before send

**Fix**:
- Ensure `TextField` has `maxLength: 500` prop
- Ensure database has `VARCHAR(500)` constraint
- Ensure send button disabled when `text.length > 500`

---

### Issue 5: Offline Sync Not Working

**Symptom**: Queued actions not syncing when back online

**Debug**:
1. Check Hive queue: `await Hive.box('offline_actions_queue').values.toList()`
2. Check connectivity listener: `Connectivity().onConnectivityChanged.listen(...)`
3. Check retry logic: `debugPrint('🔧 OfflineQueue: Retrying action $id (attempt $retryCount)')`

**Fix**:
- Verify connectivity listener is registered in `main.dart`
- Verify retry logic uses exponential backoff (1s, 2s, 4s)
- Verify notification shown after 3 failed retries (FR-010b)

---

## Next Steps

After testing:

1. **Run `/speckit.tasks`** to generate dependency-ordered task list
2. **Review tasks.md** for implementation breakdown
3. **Run `/speckit.implement`** to execute all tasks and build the feature
4. **Performance testing** with Flutter DevTools Timeline
5. **Security audit** with Supabase RLS policy verification

---

**Quickstart Status**: ✅ Complete - All integration scenarios and testing workflows documented
