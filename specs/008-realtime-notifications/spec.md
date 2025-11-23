# Feature Specification: Real-Time In-App Notifications System

**Feature Branch**: `008-realtime-notifications`
**Created**: 2025-11-23
**Status**: Draft
**Input**: User description: "Sistema notifiche in-app che permette agli studenti di rimanere aggiornati su eventi, commenti e interazioni senza aprire costantemente l'app. Notifiche in tempo reale tramite Supabase Realtime, con notification center nativo iOS/Android, preferenze granulari, e auto-eliminazione dopo 90 giorni per privacy GDPR."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Notification Center Access and Navigation (Priority: P1)

Students need to quickly view all notifications and navigate to relevant content without friction. The notification center serves as the primary hub for staying updated on event activities.

**Why this priority**: Core UX requirement - without a notification center, there's no way for users to see or interact with notifications. This is the foundation that all other notification features depend on.

**Independent Test**: Can be fully tested by tapping the bell icon in the app bar, viewing the notification list with mock data, tapping a notification, and verifying navigation to the target screen. Delivers immediate value by centralizing all activity updates.

**Acceptance Scenarios**:

1. **Given** a student has 3 unread notifications, **When** they look at the app bar, **Then** the bell icon displays a red circular badge with "3"
2. **Given** a student has 12 unread notifications, **When** they look at the app bar, **Then** the bell icon displays a red circular badge with "9+" (capped display)
3. **Given** a student taps the bell icon, **When** the notification center opens, **Then** they see a full-screen native list (Cupertino on iOS, Material on Android) showing all notifications sorted by recency
4. **Given** a notification list is displayed, **When** the student views each notification item, **Then** each shows: circular sender avatar, bold title, description text, relative timestamp ("2h fa"), and a dot indicator for unread status
5. **Given** a student taps a notification, **When** the tap registers, **Then** the notification is marked as read (dot disappears), badge count decrements, and navigation occurs to the linked event/comment
6. **Given** a student has zero notifications, **When** they open the notification center, **Then** they see an empty state with a crossed-out bell icon, "Nessuna notifica" heading, and "Ti avviseremo quando succede qualcosa" subtext
7. **Given** a student is viewing the notification list, **When** they pull down to refresh, **Then** the list refreshes and shows any new notifications
8. **Given** a student swipes left/right on a notification (platform-specific), **When** they complete the swipe gesture, **Then** that notification is deleted from the list

---

### User Story 2 - Notification Preferences Management (Priority: P1)

Students need granular control over which notification types they receive to avoid notification fatigue while staying informed about important events.

**Why this priority**: Essential for user retention - without preference controls, students will be overwhelmed by notification noise and disable them entirely or stop using the app. GDPR Right to Rectification requires users to control their data preferences.

**Independent Test**: Can be fully tested by navigating to Settings → Notifiche, toggling various notification types on/off, and verifying changes persist after app restart. Delivers value by empowering users to customize their notification experience.

**Acceptance Scenarios**:

1. **Given** a student navigates to Settings, **When** they tap "Notifiche", **Then** they see a list of 6 toggle switches (one per notification channel type)
2. **Given** the notification preferences screen is displayed, **When** the student views the initial state, **Then** all 6 notification types are enabled by default (opt-out model)
3. **Given** a student taps a toggle switch for "Like agli eventi", **When** the toggle animates to off position, **Then** the preference is immediately saved to their profile in the database
4. **Given** a student has disabled "Like agli eventi" notifications, **When** someone likes their event, **Then** no notification is generated for that action
5. **Given** a student has customized their preferences, **When** they close and reopen the app, **Then** their preferences are preserved exactly as set
6. **Given** a student is on the preferences screen, **When** they toggle a switch, **Then** the UI responds within 200ms with visual feedback (platform-native switch animation)

---

### User Story 3 - Event Moderation Status Notifications (Priority: P1)

Students who create events need immediate feedback when moderators approve or reject their submissions to understand what happened to their content and take appropriate action.

**Why this priority**: Core workflow closure - without moderation notifications, creators have no way to know if their event was approved unless they manually check. This creates uncertainty and poor UX. Critical for event creation feature completeness.

**Independent Test**: Can be fully tested by creating a test event, having a moderator approve/reject it, and verifying the creator receives a notification with appropriate messaging. Delivers value by closing the feedback loop on content moderation.

**Acceptance Scenarios**:

1. **Given** a student creates an event and it enters the moderation queue, **When** a moderator approves the event, **Then** the creator receives a notification titled "Evento Approvato! 🎉" with description "Il tuo evento [event name] è ora visibile a tutti"
2. **Given** a student creates an event and it enters the moderation queue, **When** a moderator rejects the event with a reason, **Then** the creator receives a notification titled "Evento Rifiutato" with description including the rejection reason
3. **Given** a student receives an event approved notification, **When** they tap it, **Then** they navigate to the approved event detail screen and the notification is marked as read
4. **Given** a student receives an event rejected notification, **When** they tap it, **Then** they navigate to the event edit screen where they can revise and resubmit
5. **Given** a moderator approves an event, **When** the approval is saved to the database, **Then** the notification appears in the creator's notification center within 1 second (real-time delivery)

---

### User Story 4 - New Comment Notifications (Priority: P1)

Event creators need to know when people comment on their events to foster engagement and respond to questions or feedback in a timely manner.

**Why this priority**: Core engagement driver - comments represent direct interaction with the event creator. Without notifications, creators miss opportunities to build community and respond to their audience. Critical for event discussion feature completeness.

**Independent Test**: Can be fully tested by creating an event, having another user comment on it, and verifying the creator receives a notification with the commenter's name and navigates to the comment thread. Delivers value by enabling real-time conversation.

**Acceptance Scenarios**:

1. **Given** a student created an event, **When** another user posts a comment on that event, **Then** the creator receives a notification titled "[Commenter name] ha commentato sul tuo evento" with a preview of the comment text
2. **Given** a student receives a comment notification, **When** they tap it, **Then** they navigate to the event detail screen scrolled to the comments section, with the new comment highlighted
3. **Given** multiple students comment on the same event within a short timeframe, **When** the creator checks their notifications, **Then** they see separate notifications for each commenter (no grouping in MVP)
4. **Given** a student has disabled "Nuovi commenti" in preferences, **When** someone comments on their event, **Then** no notification is generated
5. **Given** someone comments on an event, **When** the comment is submitted, **Then** the notification appears in the creator's notification center within 1 second (real-time delivery)

---

### User Story 5 - Comment Reply Notifications (Priority: P2)

Students who participate in event discussions need to know when others reply to their comments to continue conversations and stay engaged.

**Why this priority**: Enhances discussion threads but not critical for basic event functionality. Users can still check events manually. Improves engagement for active participants.

**Independent Test**: Can be fully tested by posting a comment on an event, having another user reply to that specific comment, and verifying the original commenter receives a notification. Delivers value by maintaining discussion continuity.

**Acceptance Scenarios**:

1. **Given** a student posted a comment on an event, **When** another user replies to that specific comment, **Then** the original commenter receives a notification titled "[Replier name] ha risposto al tuo commento"
2. **Given** a student receives a comment reply notification, **When** they tap it, **Then** they navigate to the event detail screen scrolled to the comment thread, with the reply highlighted
3. **Given** a student has disabled "Risposte commenti" in preferences, **When** someone replies to their comment, **Then** no notification is generated
4. **Given** someone replies to a comment, **When** the reply is submitted, **Then** the notification appears within 1 second (real-time delivery)

---

### User Story 6 - Event Like Notifications (Priority: P2)

Event creators want to know when their events receive likes to gauge popularity and feel validated, though this is less urgent than comment-based interactions.

**Why this priority**: Nice-to-have social validation feature. Helps creators understand event popularity but not critical for core functionality. Can create notification noise if not managed well (hence opt-out capability).

**Independent Test**: Can be fully tested by creating an event, having another user like it, and verifying the creator receives a notification. Delivers value by providing engagement feedback.

**Acceptance Scenarios**:

1. **Given** a student created an event, **When** another user likes that event, **Then** the creator receives a notification titled "[Liker name] ha messo like al tuo evento"
2. **Given** a student receives a like notification, **When** they tap it, **Then** they navigate to the event detail screen
3. **Given** multiple users like the same event within a short timeframe, **When** the creator checks notifications, **Then** they see separate notifications for each like (no grouping in MVP)
4. **Given** a student has disabled "Like agli eventi" in preferences (common for reducing noise), **When** someone likes their event, **Then** no notification is generated
5. **Given** someone likes an event, **When** the like is registered, **Then** the notification appears within 1 second (real-time delivery)

---

### User Story 7 - Event Participation Notifications (Priority: P2)

Event creators want to know when people join their events to track interest and prepare accordingly (e.g., booking larger venue if many participants).

**Why this priority**: Useful for event planning but not critical for core app functionality. Creators can check participant counts manually. Helps with event logistics but secondary to moderation and comment notifications.

**Independent Test**: Can be fully tested by creating an event, having another user join as a participant, and verifying the creator receives a notification. Delivers value by tracking event interest in real-time.

**Acceptance Scenarios**:

1. **Given** a student created an event, **When** another user joins as a participant, **Then** the creator receives a notification titled "[Participant name] parteciperà al tuo evento"
2. **Given** a student receives a participation notification, **When** they tap it, **Then** they navigate to the event detail screen showing the updated participant list
3. **Given** multiple users join the same event rapidly, **When** the creator checks notifications, **Then** they see separate notifications for each participant (no grouping in MVP)
4. **Given** a student has disabled "Nuove partecipazioni" in preferences, **When** someone joins their event, **Then** no notification is generated
5. **Given** someone joins an event, **When** the participation is registered, **Then** the notification appears within 1 second (real-time delivery)

---

### User Story 8 - Co-Organizer Update Notifications (Priority: P3)

Students who are co-organizers of events need to be informed when the primary organizer makes changes to event details so they stay aligned on logistics.

**Why this priority**: Relevant only for events with multiple organizers (subset of total events). Nice-to-have for coordination but co-organizers can check event details manually. Lower priority as this feature enhances collaboration but isn't core to basic event functionality.

**Independent Test**: Can be fully tested by being added as a co-organizer to an event, having the primary organizer edit event details, and verifying the co-organizer receives a notification. Delivers value for collaborative event planning.

**Acceptance Scenarios**:

1. **Given** a student is a co-organizer on an event, **When** the primary organizer edits event details (title, description, date, location), **Then** all co-organizers receive a notification titled "[Organizer name] ha modificato [event name]"
2. **Given** a student receives a co-organizer update notification, **When** they tap it, **Then** they navigate to the event detail screen showing the updated information
3. **Given** a student has disabled "Co-organizer updates" in preferences, **When** an event they co-organize is edited, **Then** no notification is generated
4. **Given** an event is edited by the primary organizer, **When** the changes are saved, **Then** co-organizer notifications appear within 1 second (real-time delivery)

---

### Edge Cases

- What happens when a user receives a notification for an event that is subsequently deleted? (Notification should handle gracefully, show "Evento non disponibile" message when tapped)
- What happens when notification badge count exceeds 99? (Display "9+" cap as specified, actual count tracked in backend)
- How does the system handle notifications for users who haven't opened the app in 90+ days? (Auto-delete per GDPR retention policy, user sees empty state on return)
- What happens when a notification targets a deleted user account? (Notification creation should fail gracefully, no orphaned notifications)
- What happens when a student rapidly toggles notification preferences on/off? (Debounce UI updates, ensure last state is persisted correctly)
- How does the system handle network failures when marking notifications as read? (Optimistic UI update, retry in background, show error if persistent failure)
- What happens when two notification types fire simultaneously for the same event? (Create separate notification entries, display both in chronological order)
- What happens when a user has notifications disabled at the OS level but enabled in-app? (In-app notifications only, no OS-level push, so preferences still work)
- How does the system handle notification deep links when the target content requires additional permissions? (Redirect to appropriate error screen or permission request flow)

## Requirements *(mandatory)*

### Functional Requirements

#### Notification Center UI

- **FR-001**: System MUST display a bell icon in the top-right corner of the app bar on all main screens
- **FR-002**: Bell icon MUST show a red circular badge with the count of unread notifications (1-9, or "9+" if 10 or more)
- **FR-003**: When bell icon is tapped, system MUST open a full-screen notification center displaying all notifications
- **FR-004**: Notification center MUST use platform-native UI components (CupertinoNavigationBar and CupertinoListTile on iOS, AppBar and ListTile on Android)
- **FR-005**: Each notification item MUST display: sender's circular avatar (40px diameter), bold title, description text (up to 2 lines), relative timestamp ("2h fa", "1 giorno fa"), and a colored dot indicator for unread status
- **FR-006**: Notification list MUST be sorted by creation time, newest first
- **FR-007**: System MUST support pull-to-refresh gesture to fetch latest notifications
- **FR-008**: System MUST support swipe-to-delete gesture on individual notifications (platform-specific swipe direction)
- **FR-009**: When no notifications exist, system MUST display an empty state with: crossed-out bell icon, "Nessuna notifica" heading, "Ti avviseremo quando succede qualcosa" subtext
- **FR-010**: When a notification is tapped, system MUST mark it as read, decrement the badge count, and navigate to the target content (event detail, comment thread, etc.)

#### Notification Preferences

- **FR-011**: System MUST provide a "Notifiche" settings screen accessible from Settings menu
- **FR-012**: Notification preferences screen MUST display 6 toggle switches, one for each notification type: Eventi moderati, Nuovi commenti, Risposte commenti, Like agli eventi, Nuove partecipazioni, Co-organizer updates
- **FR-013**: All notification types MUST be enabled by default (opt-out model)
- **FR-014**: When a user toggles a notification preference, system MUST immediately save the change to the user's profile in the database
- **FR-015**: System MUST respect user preferences when generating notifications (disabled types must not create notification records)
- **FR-016**: Toggle switches MUST use platform-native components (CupertinoSwitch on iOS, Switch on Android)

#### Notification Generation and Delivery

- **FR-017**: System MUST generate a notification when a moderator approves an event, targeted to the event creator
- **FR-018**: System MUST generate a notification when a moderator rejects an event with reason, targeted to the event creator
- **FR-019**: System MUST generate a notification when someone comments on an event, targeted to the event creator
- **FR-020**: System MUST generate a notification when someone replies to a comment, targeted to the original commenter
- **FR-021**: System MUST generate a notification when someone likes an event, targeted to the event creator
- **FR-022**: System MUST generate a notification when someone joins an event as a participant, targeted to the event creator
- **FR-023**: System MUST generate notifications when an event is edited, targeted to all co-organizers (excluding the editor)
- **FR-024**: Notification delivery MUST occur within 1 second of the triggering action (real-time via Supabase Realtime subscriptions)
- **FR-025**: System MUST update the badge count in real-time when new notifications are received while the app is open
- **FR-026**: System MUST not generate notifications for actions triggered by the user themselves (e.g., no notification when you comment on your own event)

#### Privacy and Data Management

- **FR-027**: Notifications MUST be visible only to the intended recipient (enforced via Row-Level Security policies)
- **FR-028**: System MUST automatically delete notifications older than 90 days (GDPR data minimization)
- **FR-029**: System MUST not send notifications to third-party services (no Firebase Cloud Messaging analytics, no OneSignal)
- **FR-030**: Notifications MUST be in-app only (no OS-level push notifications)
- **FR-031**: Users MUST be able to delete individual notifications via swipe gesture

#### Performance

- **FR-032**: Notification list rendering MUST complete within 500ms for up to 100 notifications
- **FR-033**: Tap interaction on notification items MUST provide perceived feedback within 200ms
- **FR-034**: Scrolling through notification list MUST maintain 60fps sustained frame rate
- **FR-035**: Notification fetch API calls MUST have p95 latency under 300ms
- **FR-036**: Badge count updates MUST be accurate 99% of the time (real-time sync reliability)

#### Design System Compliance

- **FR-037**: All colors MUST use NovaColors constants (no hardcoded hex values)
- **FR-038**: All spacing MUST use NovaSpacing constants (no magic numbers)
- **FR-039**: All typography MUST use NovaTypography constants (no inline TextStyle definitions)
- **FR-040**: Notification list items MUST use GlassContainer widget for glassmorphism effect
- **FR-041**: Platform detection MUST use `Platform.isIOS` to render Cupertino vs Material components appropriately

### Key Entities *(include if feature involves data)*

- **Notification**: Represents a single notification sent to a user. Attributes include: unique ID, recipient user ID, sender user ID (nullable for system notifications), notification type (enum of 6 channels), title text, description text, target entity type (event/comment), target entity ID, read status (boolean), creation timestamp, and optional metadata (JSON for extensibility).

- **NotificationPreferences**: Represents a user's notification preferences, stored as part of their profile. Attributes include: user ID (foreign key to profiles), and 6 boolean flags (eventi_moderati_enabled, nuovi_commenti_enabled, risposte_commenti_enabled, like_eventi_enabled, nuove_partecipazioni_enabled, coorganizer_updates_enabled). All default to true.

- **NotificationChannel**: Enumeration of the 6 notification types: EVENT_MODERATION, NEW_COMMENT, COMMENT_REPLY, EVENT_LIKE, EVENT_PARTICIPATION, COORGANIZER_UPDATE.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 80% or more of students keep at least 4 out of 6 notification types enabled after 2 weeks of usage (indicates system is not invasive)
- **SC-002**: 90% or more of received notifications are tapped by users (indicates high relevance and engagement)
- **SC-003**: Zero spam notification reports from users (indicates backend validation is working correctly)
- **SC-004**: Badge count displays accurately 99% or more of the time when compared to actual unread count (indicates reliable real-time sync)
- **SC-005**: Less than 5% of students disable all notification types (indicates system provides value without being overwhelming)
- **SC-006**: Notification center renders the notification list in under 500ms for typical usage (50-100 notifications)
- **SC-007**: Users perceive tap interactions as instant (under 200ms response time from tap to visual feedback)
- **SC-008**: Notification list scrolling maintains 60fps with zero dropped frames during user testing
- **SC-009**: New notifications appear in the notification center within 1 second of the triggering action (real-time delivery validation)
- **SC-010**: Notification fetch API calls complete within 300ms for 95th percentile of requests

## Assumptions

- Students have stable internet connectivity (4G or WiFi) during app usage for real-time notifications to function properly
- Supabase Realtime subscriptions are reliable and provide sub-second latency for notification delivery
- Users understand relative timestamp formats ("2h fa", "1 giorno fa") common in social apps
- Platform-native swipe gestures (swipe-to-delete) are familiar to iOS and Android users
- The existing deep link handler supports navigation to events and comment threads
- Avatar images for notification senders are already available via existing user profile system
- The user profile/settings screen structure already exists and can accommodate the new "Notifiche" section
- Notification badge display conventions (red circle with white text, capped at "9+") are universally understood

## Out of Scope

- OS-level push notifications (deliberately excluded for privacy and to avoid permission friction)
- Notification grouping or summarization (e.g., "Marco and 3 others commented on your event") - MVP shows individual notifications
- Notification sound or vibration customization - relies on system defaults only
- Email notifications as a fallback for important events
- Notification history export or archiving beyond 90-day auto-deletion period
- Rich notification content (images, videos, interactive buttons) - text and navigation only
- Notification scheduling or quiet hours (do not disturb mode)
- Third-party notification service integration (Firebase, OneSignal, etc.) - in-app only per constitutional privacy requirements
- Notification analytics or tracking beyond basic preference adoption metrics
- Notification threading or conversation view - notifications are flat list only
