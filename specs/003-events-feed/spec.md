# Feature Specification: Events Feed (Instagram-Style Infinite Scroll)

**Feature Branch**: `003-events-feed`
**Created**: 2025-01-02
**Status**: Draft
**Input**: User description: "Instagram-style infinite scroll events feed with glassmorphic event cards (16:9 image, title, date/time, location, creator profile), event detail screen with gallery, participants, real-time comments, optimistic UI for interactions (like, comment, participate), offline-first with Hive cache, performance targets (<1s feed load cached, 60fps scroll, <200KB WebP images), Supabase Realtime for live updates, pagination (20 events/page), moderation (only status='approved' events shown), creator can edit/delete own events, report button for inappropriate content, design system strict compliance (zero hardcoded values), constitutional alignment (STUDENTS_FIRST, PERFORMANCE_FIRST, PRIVACY_FOUNDATION, SIMPLICITY_FIRST)"

## Clarifications

### Session 2025-01-02

- Q: Image Upload & Management Scope - Does this feature handle image upload/selection, or only display already-uploaded images? → A: Events already have uploaded images; this feature only displays them (event creation is separate)
- Q: Comment Length Limits - What is the maximum character length for event comments? → A: 500 characters maximum (Twitter-like length, forces concise communication)
- Q: Offline Action Sync Strategy - Should queued offline actions be retried automatically or require manual intervention? → A: Auto-retry with exponential backoff (3 attempts: 1s, 2s, 4s delays), then show notification with manual retry option if still failing
- Q: Pull-to-Refresh Behavior - Should the app include pull-to-refresh gesture for manual content refresh? → A: Include pull-to-refresh on both feed screen (reload events) and detail screen (refresh comments, participant list, event data)
- Q: Event Archival & Past Events Handling - How should old events be handled (always visible, archived after time limit, or based on event date)? → A: Archive after event date passes - main feed filters `event_date >= today`, past events accessible via separate "Past Events" screen (future feature)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Infinite Scroll Events Feed (Priority: P1)

As a student, I want to scroll through an infinite feed of school events so I can discover what's happening at my school.

**Why this priority**: This is the core feature - without the feed, there is no Events feature. It's the primary entry point for all event discovery and must work perfectly before any other interactions.

**Independent Test**: Can be fully tested by launching the app, navigating to Events tab, and scrolling through the feed. Delivers immediate value by showing all approved events without requiring any user interaction beyond scrolling.

**Acceptance Scenarios**:

1. **Given** I am authenticated and on the Events tab, **When** the feed loads, **Then** I see the first 20 approved events in reverse chronological order (newest first)
2. **Given** I am viewing the feed, **When** I scroll to the bottom (within 3 items of the end), **Then** the next page of 20 events loads automatically
3. **Given** the feed is loading the first page, **When** the request is in progress, **Then** I see a centered CircularProgressIndicator
4. **Given** the feed is loading more pages, **When** I scroll to the bottom, **Then** I see a loading indicator at the bottom while new events load
5. **Given** there are no events in the database, **When** the feed loads, **Then** I see an empty state with icon and message "No events yet. Be the first to create one!"
6. **Given** I previously loaded the feed, **When** I return to the Events tab, **Then** I see cached events immediately (<1 second), then fresh data loads silently in the background
7. **Given** I am offline, **When** I view the feed, **Then** I see cached events with a subtle banner "Viewing offline events"
8. **Given** I am viewing the feed, **When** I pull down from the top of the screen, **Then** I see a refresh indicator and the feed reloads the first 20 events with latest data

---

### User Story 2 - View Event Detail Screen (Priority: P1)

As a student, I want to tap an event card to see full details so I can decide if I want to participate.

**Why this priority**: Without the detail screen, the feed is just a list of thumbnails with no actionable information. This is essential for the MVP because students need to see full event descriptions, locations, times, and participant lists before committing to attend.

**Independent Test**: Can be fully tested by tapping any event card in the feed. Delivers value by showing all event information including images, description, creator, participants, and metadata.

**Acceptance Scenarios**:

1. **Given** I am viewing the events feed, **When** I tap an event card, **Then** I navigate to the event detail screen with a hero animation on the event image
2. **Given** I am on the event detail screen, **When** the screen loads, **Then** I see the event title, full-width 16:9 image, date/time, location, creator profile (avatar + name), description, participant count, and participant avatars (max 5 shown)
3. **Given** the event has multiple images, **When** I swipe the image horizontally, **Then** I see a paginated gallery with dot indicators
4. **Given** I am viewing event details, **When** I tap the back button or swipe from left edge, **Then** I return to the feed with the scroll position preserved
5. **Given** the event has no participants yet, **When** I view the detail screen, **Then** I see "No participants yet. Be the first!"
6. **Given** I am viewing the event detail screen, **When** I pull down from the top of the screen, **Then** I see a refresh indicator and the event data, comments, and participant list reload with latest data

---

### User Story 3 - Like/Unlike Events with Optimistic UI (Priority: P2)

As a student, I want to like events I'm interested in so I can bookmark them and show support to the creator.

**Why this priority**: Engagement features like likes are important for community building but not blocking for basic event discovery. This can be added after the feed and detail screens work.

**Independent Test**: Can be fully tested by tapping the like button on any event card or detail screen. Delivers value by allowing students to express interest and bookmark events.

**Acceptance Scenarios**:

1. **Given** I am viewing an event I haven't liked, **When** I tap the heart icon, **Then** it immediately turns red with a scale animation (optimistic UI), and the like count increases by 1
2. **Given** I am viewing an event I have liked, **When** I tap the heart icon, **Then** it immediately turns grey (optimistic UI), and the like count decreases by 1
3. **Given** the optimistic like fails (network error), **When** the request fails, **Then** the UI reverts to the previous state and shows a snackbar "Failed to like event. Try again."
4. **Given** I liked an event, **When** I refresh the feed or restart the app, **Then** the like state persists correctly
5. **Given** I am offline, **When** I tap the like button, **Then** I see an immediate snackbar "You're offline. Like will be synced when online" and the action is queued
6. **Given** I queued an offline action and came back online, **When** the sync starts, **Then** it auto-retries up to 3 times (1s, 2s, 4s delays) before showing a "Some actions couldn't be synced" notification with "Retry" button

---

### User Story 4 - Participate/Unparticipate in Events (Priority: P2)

As a student, I want to mark events I'm attending so the creator knows I'm coming and I get reminded.

**Why this priority**: Participation is core to the value proposition (connecting students to events), but can be added after basic browsing works. It's more important than comments because it directly impacts event attendance.

**Independent Test**: Can be fully tested by tapping the "Participate" button on any event detail screen. Delivers value by allowing students to RSVP and see who else is attending.

**Acceptance Scenarios**:

1. **Given** I am viewing an event I'm not participating in, **When** I tap the "Participate" button, **Then** it immediately changes to "Participating" with a checkmark icon (optimistic UI), my avatar appears in the participant list, and the participant count increases by 1
2. **Given** I am viewing an event I'm participating in, **When** I tap the "Participating" button, **Then** it immediately changes to "Participate" (optimistic UI), my avatar is removed from the participant list, and the participant count decreases by 1
3. **Given** the optimistic participation fails, **When** the request fails, **Then** the UI reverts and shows "Failed to update participation. Try again."
4. **Given** I am participating in an event, **When** I view it in the feed, **Then** I see a green checkmark badge on the event card
5. **Given** the event is at capacity (if limit exists), **When** I try to participate, **Then** I see a snackbar "This event is full"

---

### User Story 5 - View and Post Real-Time Comments (Priority: P2)

As a student, I want to read and post comments on events so I can ask questions and discuss details with the creator and other participants.

**Why this priority**: Comments enable community discussion but are not blocking for basic event discovery and participation. This is valuable for engagement but can be added after core RSVP functionality.

**Independent Test**: Can be fully tested by scrolling to the comments section on any event detail screen, typing a comment, and tapping send. Delivers value by enabling Q&A between students and event creators.

**Acceptance Scenarios**:

1. **Given** I am on the event detail screen, **When** I scroll to the comments section, **Then** I see all comments in chronological order (oldest first) with author avatar, name, comment text, and timestamp
2. **Given** I am viewing the comments section, **When** I tap the comment input field, **Then** the keyboard appears, a character counter shows "0/500", and the "Send" button is disabled
3. **Given** I typed a comment (1-500 chars), **When** the character count updates, **Then** I see "X/500" and the "Send" button becomes enabled
4. **Given** I typed 500+ characters, **When** the limit is reached, **Then** the text field prevents further input and the "Send" button is disabled
5. **Given** I typed a valid comment, **When** I tap "Send", **Then** the comment immediately appears at the bottom with a loading indicator (optimistic UI), and the input field clears
6. **Given** another user posts a comment, **When** I'm viewing the event detail screen, **Then** the new comment appears in real-time via Supabase Realtime (no refresh needed)
7. **Given** the optimistic comment fails, **When** the request fails, **Then** the comment shows a red error icon and a "Retry" button
8. **Given** there are no comments yet, **When** I view the comments section, **Then** I see "No comments yet. Start the conversation!"
9. **Given** there are more than 50 comments, **When** I scroll to the top of comments, **Then** older comments load on demand (pagination)

---

### User Story 6 - Edit Own Events (Priority: P3)

As an event creator, I want to edit my events after publishing so I can fix mistakes or update details.

**Why this priority**: Edit functionality is nice-to-have but not critical for MVP. Events can be created correctly the first time, and this can be added later to improve creator experience.

**Independent Test**: Can be fully tested by navigating to an event I created, tapping the "Edit" button, making changes, and saving. Delivers value by allowing creators to update event information without deleting and recreating.

**Acceptance Scenarios**:

1. **Given** I am viewing an event I created, **When** I view the detail screen, **Then** I see an "Edit" button in the top right corner (only visible to me, not other students)
2. **Given** I tapped the "Edit" button, **When** the edit screen loads, **Then** I see a form pre-filled with current event data (title, description, date, time, location; images shown but not editable in this feature)
3. **Given** I made changes to text fields, **When** I tap "Save", **Then** I see a loading indicator, then a snackbar "Event updated successfully", and I return to the detail screen with updated data
4. **Given** I made changes but tap "Cancel", **When** the confirmation dialog appears, **Then** I can choose "Discard Changes" or "Keep Editing"
5. **Given** I edited an event, **When** the update is saved, **Then** all users viewing that event see the updated data in real-time via Supabase Realtime

---

### User Story 7 - Delete Own Events (Priority: P3)

As an event creator, I want to delete my events if they're cancelled or posted by mistake.

**Why this priority**: Deletion is less common than editing and not critical for MVP. This is a content management feature that can be added later.

**Independent Test**: Can be fully tested by navigating to an event I created, tapping the "Delete" button, confirming, and seeing the event removed. Delivers value by allowing creators to remove cancelled or incorrect events.

**Acceptance Scenarios**:

1. **Given** I am viewing an event I created, **When** I tap the "..." menu in the top right, **Then** I see a "Delete Event" option with a red destructive style
2. **Given** I tapped "Delete Event", **When** the confirmation dialog appears, **Then** I see "Are you sure? This action cannot be undone." with "Cancel" and "Delete" buttons
3. **Given** I confirmed deletion, **When** the request completes, **Then** I see a snackbar "Event deleted", I navigate back to the feed, and the event is immediately removed from the feed
4. **Given** the event has participants, **When** I delete it, **Then** I see a warning "X students are participating. They will be notified of the cancellation." before confirming
5. **Given** the deletion fails, **When** the request fails, **Then** I see an error snackbar "Failed to delete event. Try again."

---

### User Story 8 - Report Inappropriate Events (Priority: P3)

As a student, I want to report events with inappropriate content so moderators can review them.

**Why this priority**: Reporting is important for content safety but not blocking for MVP launch. Moderators can manually review the moderation queue initially, and this can be added later for student-initiated reporting.

**Independent Test**: Can be fully tested by viewing any event (not created by me), tapping the "..." menu, selecting "Report", choosing a reason, and submitting. Delivers value by empowering students to flag inappropriate content.

**Acceptance Scenarios**:

1. **Given** I am viewing an event I didn't create, **When** I tap the "..." menu in the top right, **Then** I see a "Report Event" option
2. **Given** I tapped "Report Event", **When** the report dialog appears, **Then** I see multiple report reasons: "Inappropriate content", "Spam", "Misinformation", "Other"
3. **Given** I selected a report reason, **When** I tap "Submit Report", **Then** I see a snackbar "Report submitted. Moderators will review within 24 hours", and the event remains visible to me (not automatically hidden)
4. **Given** I already reported this event, **When** I tap the "..." menu, **Then** "Report Event" is disabled and shows "(Already reported)"
5. **Given** the report is submitted, **When** the request completes, **Then** the event status is updated in the database with a report flag, and moderators see it in their queue

---

### User Story 9 - Real-Time Feed Updates (Priority: P3)

As a student, I want to see new events appear in the feed automatically so I don't miss newly published events.

**Why this priority**: Real-time updates are a nice-to-have polish feature but not critical for MVP. Pull-to-refresh and auto-refresh on navigation are sufficient initially.

**Independent Test**: Can be fully tested by having a second user create a new event while I'm viewing the feed. Delivers value by ensuring students see the latest events without manual refresh.

**Acceptance Scenarios**:

1. **Given** I am viewing the events feed, **When** a new event is approved and published, **Then** I see a subtle banner at the top "New events available. Tap to refresh" (non-intrusive)
2. **Given** the "New events available" banner is visible, **When** I tap it, **Then** the feed scrolls to the top smoothly and inserts the new events with a subtle fade-in animation
3. **Given** I am viewing the feed, **When** an event I'm viewing is deleted by its creator, **Then** it fades out from the feed with a smooth animation
4. **Given** I am viewing the feed, **When** an event I'm viewing is edited by its creator, **Then** the card updates in-place with updated data (no animation, just data change)

---

### Edge Cases

- **What happens when I scroll extremely fast to the bottom?** - Pagination debouncing ensures only one page loads at a time. Additional scroll triggers are queued until the current page finishes loading.

- **What happens if an image fails to load (404)?** - Show a fallback placeholder image with the Nova logo in a muted color. Log the error for investigation but don't block the UI.

- **What happens if Supabase Realtime disconnects?** - Show a subtle reconnection indicator at the top. When reconnected, silently fetch any missed updates via REST API to ensure consistency.

- **What happens if I like an event, go offline, and someone else unlikes it?** - When back online, the optimistic like syncs with exponential backoff (3 attempts: 1s, 2s, 4s). If there's a conflict (race condition), the server's state wins. User sees no error but the final state matches server truth. If sync fails after 3 attempts, user sees notification "Some actions couldn't be synced" with manual retry option.

- **What happens if the event date has passed?** - Events where `event_date < CURRENT_DATE` are automatically archived and hidden from the feed (server-side filter). User can access archived events via a separate "Past Events" screen (future feature).

- **What happens if I try to participate in an event that was just deleted?** - The optimistic UI shows participation, but the API returns 404. UI reverts and shows snackbar "This event was deleted by the creator."

- **What happens if I post a comment with inappropriate content?** - The comment is sent to the moderation queue instead of appearing immediately. User sees a banner "Your comment is being reviewed by moderators" instead of the comment itself.

- **What happens if the feed has exactly 20 events (one page)?** - Pagination logic doesn't trigger because there's no next page. No loading indicator appears at the bottom. If a 21st event is added later, real-time updates notify the user.

- **What happens if I rapidly tap the like button 10 times?** - Debouncing prevents multiple rapid requests. Only the final state (liked or unliked) is sent to the server. UI shows the final state immediately (optimistic).

- **What happens if the participant count reaches 999+?** - Display "999+" instead of the actual number. Full participant list is available on the detail screen via a scrollable modal.

## Requirements *(mandatory)*

### Functional Requirements

#### Feed Display
- **FR-001**: System MUST display an infinite scroll feed of events with automatic pagination (20 events per page)
- **FR-002**: System MUST show only events with `status = 'approved'` (events in moderation or rejected are hidden)
- **FR-003**: Feed MUST display events in reverse chronological order by `created_at` (newest first) WHERE `event_date >= CURRENT_DATE` (only upcoming and today's events)
- **FR-003a**: System MUST filter out events where `event_date < CURRENT_DATE` from main feed (archived events - past events accessible via separate "Past Events" screen in future feature)
- **FR-003b**: Database MUST have index on `event_date` column for performant date-based filtering
- **FR-004**: Each event card MUST display: 16:9 cover image, title, date/time (formatted as "Jan 15, 2025 at 3:00 PM"), location, creator profile (avatar + name), participant count, like count
- **FR-005**: Event cards MUST use glassmorphism effect via `GlassContainer` widget (per design system)
- **FR-006**: System MUST apply hero animation when transitioning from event card to detail screen (image hero tag)
- **FR-006a**: Feed MUST support pull-to-refresh gesture - swipe down from top triggers manual refresh
- **FR-006b**: Pull-to-refresh MUST show native refresh indicator during reload
- **FR-006c**: Pull-to-refresh MUST reload first page (20 events), reset scroll position to top, and update cache

#### Offline-First & Caching
- **FR-007**: System MUST cache the last 100 viewed events locally using Hive for offline access
- **FR-008**: Feed MUST load from cache first (<1 second), then fetch fresh data from Supabase in the background
- **FR-009**: When offline, system MUST show cached events with a dismissible banner "Viewing offline events"
- **FR-010**: System MUST queue optimistic actions (likes, comments, participations) when offline and sync when back online
- **FR-010a**: Queued actions MUST auto-retry with exponential backoff on failure: 3 attempts with delays of 1s, 2s, 4s
- **FR-010b**: If all 3 retry attempts fail, system MUST show persistent notification "Some actions couldn't be synced" with "Retry" button
- **FR-010c**: Queued actions MUST be stored in Hive and persist across app restarts until successfully synced or manually discarded

#### Event Detail Screen
- **FR-011**: Detail screen MUST display: full-width 16:9 image(s) with swipeable gallery, title, formatted date/time, location, creator profile (tappable to view creator's other events), full description, participant list (avatars + count), like count, comment thread
- **FR-012**: If event has multiple images, system MUST show a paginated gallery with dot indicators
- **FR-013**: Participant list MUST show up to 5 avatar thumbnails. If more than 5, show "+X more" button that opens a modal with full scrollable list
- **FR-014**: Creator profile MUST be tappable and navigate to a filtered view of events created by that user
- **FR-014a**: Detail screen MUST support pull-to-refresh gesture - swipe down from top triggers manual refresh
- **FR-014b**: Pull-to-refresh on detail screen MUST reload event data, comments, participant list, and like count
- **FR-014c**: Pull-to-refresh MUST show native refresh indicator during reload

#### Like/Unlike
- **FR-015**: System MUST allow users to like/unlike events with a single tap on the heart icon (both feed card and detail screen)
- **FR-016**: Like action MUST use optimistic UI - heart turns red immediately, like count increments by 1
- **FR-017**: Unlike action MUST use optimistic UI - heart turns grey immediately, like count decrements by 1
- **FR-018**: If like/unlike request fails, system MUST revert UI to previous state and show error snackbar "Failed to like event. Try again."
- **FR-019**: System MUST prevent duplicate likes (database constraint + client-side check)
- **FR-020**: Like state MUST persist across app restarts via Supabase user_event_likes table

#### Participate/Unparticipate
- **FR-021**: System MUST allow users to participate/unparticipate in events via a button on the detail screen
- **FR-022**: Participate action MUST use optimistic UI - button changes to "Participating" with checkmark, user's avatar appears in participant list, count increments
- **FR-023**: Unparticipate action MUST use optimistic UI - button changes to "Participate", user's avatar removed, count decrements
- **FR-024**: If participation request fails, system MUST revert UI and show error snackbar
- **FR-025**: System MUST show a green checkmark badge on event cards in the feed for events the user is participating in
- **FR-026**: System MUST enforce event capacity limits (if capacity field exists and is set). Show "Event is full" snackbar if at capacity.

#### Comments
- **FR-027**: Detail screen MUST display comments in chronological order (oldest first) below the event details
- **FR-028**: Each comment MUST show: author avatar, author name, comment text, timestamp (formatted as "2 hours ago" or "Jan 15 at 3:00 PM" if older than 24 hours)
- **FR-029**: System MUST allow users to post comments via a text input field at the bottom of the screen (sticky input)
- **FR-029a**: Comments MUST be limited to 500 characters maximum (client-side validation, database VARCHAR(500) constraint)
- **FR-029b**: Comment input field MUST show live character count "X/500" below the text field
- **FR-029c**: Send button MUST be disabled when comment is empty or exceeds 500 characters
- **FR-030**: Comment posting MUST use optimistic UI - comment appears immediately with a loading indicator, then replaced with server response
- **FR-031**: If comment fails, system MUST show a red error icon and "Retry" button next to the failed comment
- **FR-032**: System MUST use Supabase Realtime to push new comments to all users viewing the event detail screen (no manual refresh needed)
- **FR-033**: If more than 50 comments exist, system MUST paginate comments (load 50 initially, load more on scroll to top)
- **FR-034**: Empty comments section MUST show placeholder "No comments yet. Start the conversation!"

#### Edit Events (Creator Only)
- **FR-035**: System MUST show an "Edit" button in the top right of the detail screen ONLY if the current user is the event creator
- **FR-036**: Edit button MUST open a form pre-filled with current event data: title, description, date, time, location (images display-only; upload handled by separate event creation feature)
- **FR-037**: User MUST be able to modify text fields (title, description, date, time, location) and tap "Save" to update the event
- **FR-038**: If user taps "Cancel" with unsaved changes, system MUST show a confirmation dialog "Discard changes?"
- **FR-039**: On successful save, system MUST show snackbar "Event updated successfully" and return to detail screen with updated data
- **FR-040**: System MUST broadcast event updates via Supabase Realtime so all users viewing the event see changes immediately

#### Delete Events (Creator Only)
- **FR-041**: System MUST show a "Delete Event" option in the "..." menu ONLY if the current user is the event creator
- **FR-042**: Delete option MUST have a destructive (red) style to indicate irreversibility
- **FR-043**: System MUST show a confirmation dialog "Are you sure? This action cannot be undone." with "Cancel" and "Delete" buttons
- **FR-044**: If the event has participants, system MUST show additional warning "X students are participating. They will be notified of the cancellation."
- **FR-045**: On successful deletion, system MUST show snackbar "Event deleted", navigate back to feed, and remove the event from the feed immediately
- **FR-046**: System MUST broadcast deletion via Supabase Realtime so the event disappears from all users' feeds

#### Report Events
- **FR-047**: System MUST show a "Report Event" option in the "..." menu for all events NOT created by the current user
- **FR-048**: Report dialog MUST show multiple report reasons: "Inappropriate content", "Spam", "Misinformation", "Other"
- **FR-049**: System MUST allow users to select one reason and optionally add a text explanation
- **FR-050**: On submit, system MUST show snackbar "Report submitted. Moderators will review within 24 hours"
- **FR-051**: System MUST prevent duplicate reports - if user already reported this event, "Report Event" option is disabled and shows "(Already reported)"
- **FR-052**: System MUST update the event record with a report flag and add an entry to the moderation queue table

#### Real-Time Updates
- **FR-053**: System MUST subscribe to Supabase Realtime for the events table (filtered to `status = 'approved'`)
- **FR-054**: When a new event is published, system MUST show a non-intrusive banner at the top "New events available. Tap to refresh"
- **FR-055**: When user taps the banner, feed MUST scroll to top smoothly and insert new events with a fade-in animation
- **FR-056**: When an event is deleted, system MUST fade out the event card from the feed with a smooth animation
- **FR-057**: When an event is edited, system MUST update the event card in-place with new data (no animation, just data change)

#### Performance Requirements
- **FR-058**: Feed MUST load from cache in under 1 second on app launch (cached data)
- **FR-059**: Feed MUST load first page from network in under 3 seconds on 4G connection (first load, no cache)
- **FR-060**: Feed scrolling MUST maintain 60fps with zero dropped frames (performance profiling required)
- **FR-061**: Images MUST be in WebP format with max size 200KB each
- **FR-062**: Image loading MUST use progressive loading with blur-up effect (show low-quality placeholder while high-quality loads)
- **FR-063**: Pagination MUST debounce scroll events (max 1 page load every 500ms to prevent race conditions)
- **FR-064**: Optimistic UI actions (like, comment, participate) MUST show perceived response time under 200ms

#### Design System Compliance
- **FR-065**: All colors MUST come from `NovaColors` class (zero hardcoded hex values)
- **FR-066**: All spacing MUST come from `NovaSpacing` class (zero magic numbers)
- **FR-067**: All typography MUST come from `NovaTypography` class (zero inline TextStyle)
- **FR-068**: All border radius MUST come from `NovaRadius` class (zero hardcoded radius values)
- **FR-069**: Event cards MUST use `GlassContainer` widget for glassmorphism effect
- **FR-070**: All animations MUST use `NovaDurations` class for consistent timing (e.g., `NovaDurations.short = 200ms`, `NovaDurations.medium = 300ms`)

#### Security & Privacy
- **FR-071**: All event queries MUST be protected by Supabase Row-Level Security (RLS) policies
- **FR-072**: Users MUST only see events with `status = 'approved'` (enforced at database level)
- **FR-073**: Users MUST only be able to edit/delete their own events (enforced by RLS policy checking `creator_id = auth.uid()`)
- **FR-074**: System MUST NOT log sensitive user data (emails, IP addresses, user IDs) in analytics or error logs
- **FR-075**: All images MUST be served over HTTPS via Supabase Storage CDN

### Key Entities

- **Event**: Represents a school event with metadata (title, description, event_date DATE, event_time TIME, location, cover image(s), creator, status, created_at, updated_at). Status can be 'pending', 'approved', or 'rejected'. Only 'approved' events with `event_date >= CURRENT_DATE` are shown in the feed (past events are archived).

- **User**: Represents a student profile (id, email, name, class, avatar_url, created_at). Creator relationship links events to users.

- **Like**: Represents a user liking an event (composite primary key: user_id + event_id, created_at). Used to track like state and count.

- **Participation**: Represents a user RSVPing to an event (composite primary key: user_id + event_id, created_at). Used to track participation state and count.

- **Comment**: Represents a user comment on an event (id, event_id, author_id, text VARCHAR(500), created_at). Maximum 500 characters. Ordered chronologically for display.

- **Report**: Represents a user-submitted report for inappropriate content (id, event_id, reporter_id, reason, explanation, created_at, reviewed). Links to moderation queue.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Feed loads from cache in under 1 second on app launch (90th percentile measured via Firebase Performance Monitoring)
- **SC-002**: Feed scrolling maintains 60fps with zero dropped frames during performance profiling (Flutter DevTools Timeline)
- **SC-003**: Images load progressively with blur-up effect visible to user (no blank white boxes during load)
- **SC-004**: 80% of students use the Events feed at least once per week (measured via usage analytics)
- **SC-005**: Optimistic UI actions (like, comment, participate) show perceived response time under 200ms (timed via DevTools)
- **SC-006**: Zero hardcoded color/spacing values found during code review (enforced via linter rules if possible)
- **SC-007**: Real-time comment updates appear within 2 seconds for all users viewing the event detail screen (measured via WebSocket latency)
- **SC-008**: Offline caching allows users to view last 100 events without network connection (tested via airplane mode)
- **SC-009**: Average event detail screen load time under 500ms (cached images, 90th percentile)
- **SC-010**: Less than 5% of optimistic actions fail and require retry (measured via error rate analytics)

### Constitutional Alignment Check

#### Principle 1: STUDENTS_FIRST
- **Alignment**: Feed prioritizes student needs (event discovery, easy participation, Q&A via comments). No administrative burden or complexity added.
- **Evidence**: Infinite scroll requires zero configuration. Students discover events immediately upon login.

#### Principle 2: PRIVACY_FOUNDATION
- **Alignment**: Minimal data collection (only likes, comments, participations - all reversible). Zero tracking of browsing behavior. No analytics on which events users view.
- **Evidence**: No third-party analytics. RLS policies prevent data leaks. User can delete account and all associated likes/comments/participations are cascade deleted.

#### Principle 3: SIMPLICITY_FIRST
- **Alignment**: Single-purpose screen (view events). No extraneous features. Instagram-style UI is familiar to students. Zero configuration required.
- **Evidence**: Default answer to feature requests is "no" unless proven student need. No filters, no sorting options (just chronological), no algorithmic feed.

#### Principle 4: PERFORMANCE_FIRST
- **Alignment**: <1s cached load, 60fps scroll, <200KB images, optimistic UI for instant feedback, offline-first with Hive cache.
- **Evidence**: Performance budgets defined in FR-058 through FR-064. Blur-up progressive loading prevents layout shift.

#### Principle 5: SPEC_FIRST
- **Alignment**: This specification written BEFORE any implementation. User stories prioritized (P1/P2/P3). Success criteria measurable.
- **Evidence**: Specification document complete with FR IDs, acceptance scenarios, and constitutional alignment check.

#### Principle 6: DESIGN_SYSTEM_STRICT
- **Alignment**: All colors from NovaColors, all spacing from NovaSpacing, all typography from NovaTypography, all radius from NovaRadius. GlassContainer widget mandated.
- **Evidence**: FR-065 through FR-070 enforce design system compliance. Code review checklist requires zero hardcoded values.

#### Principle 7: CONTENT_MODERATION
- **Alignment**: Only approved events shown (status='approved'). Report button for student-initiated flagging. Moderators review within 24 hours.
- **Evidence**: FR-002 enforces approved-only filter. FR-047 through FR-052 define reporting workflow. Moderation queue updated on report submission.

---

**Specification Complete**: Ready for `/speckit.clarify` (if needed) or `/speckit.plan` (if no clarifications needed).
