# Feature Specification: Global Chat

**Feature Branch**: `011-global-chat`
**Created**: 2025-11-30
**Status**: Draft
**Input**: User description: "Global Chat - chat di scuola in tempo reale con messaggi effimeri (24h auto-delete), menzioni @username, reactions emoji, reply/quote, typing indicator, e media view-once con protezione screenshot"

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View and Send Messages in Global Chat (Priority: P1)

As a student, I want to view and send text messages in a school-wide chat room so that I can communicate with all students in real-time.

The global chat is a single, unified chat room visible to all authenticated students of Liceo Galilei Moro. Messages appear in real-time as other students send them. Each message displays the sender's avatar, name, class, and a relative timestamp (e.g., "2 minuti fa").

**Why this priority**: This is the core functionality of the chat feature. Without the ability to view and send messages, no other feature makes sense. This provides immediate value as the primary communication channel.

**Independent Test**: Can be fully tested by logging in as a student, opening the chat tab, and verifying that messages can be sent and received in real-time. Delivers value immediately as a communication tool.

**Acceptance Scenarios**:

1. **Given** I am a logged-in student with a complete profile, **When** I navigate to the Chat tab, **Then** I see a scrollable list of messages from newest (bottom) to oldest (top)
2. **Given** I am viewing the chat, **When** another student sends a message, **Then** I see it appear instantly (within 1 second) without refreshing
3. **Given** I type a message (max 500 characters) and tap Send, **When** the message is submitted, **Then** it appears immediately in my view and is visible to all other students
4. **Given** I send a message, **When** it appears in the chat, **Then** it displays my avatar, full name, class (e.g., "3A"), and the relative timestamp
5. **Given** I am viewing the chat without network connectivity, **When** I attempt to send a message, **Then** I see an error indicating I'm offline and the message is queued for retry

---

### User Story 2 - Report Inappropriate Messages (Priority: P1)

As a student, I want to report messages that contain inappropriate content so that the chat remains a safe environment for all students.

Every message in the chat has a report option accessible via long-press. Students can report messages for specific reasons. Messages receiving multiple reports are automatically hidden pending moderator review.

**Why this priority**: Content moderation is a constitutional requirement (Principle 7). Without reporting, the chat could become a vector for bullying or inappropriate content, making it unsafe for minors.

**Independent Test**: Can be tested by long-pressing a message, selecting "Segnala", choosing a reason, and verifying the report is submitted. Works independently of other features.

**Acceptance Scenarios**:

1. **Given** I see a message in the chat, **When** I long-press on it, **Then** I see a context menu with "Segnala" option
2. **Given** I tap "Segnala", **When** the report dialog opens, **Then** I can select from: Spam, Contenuto inappropriato, Bullismo, Off-topic
3. **Given** I select a reason and submit, **When** the report is recorded, **Then** I see a confirmation "Segnalazione inviata"
4. **Given** a message receives 3 or more reports from different users, **When** the third report is submitted, **Then** the message is automatically hidden from the chat and added to the moderation queue
5. **Given** I have already reported a specific message, **When** I try to report it again, **Then** I see a message "Hai gia segnalato questo messaggio"

---

### User Story 3 - Automatic Message Deletion (Priority: P1)

As a student and as the school, I want all chat messages to be automatically deleted after 24 hours so that the chat remains ephemeral and complies with privacy regulations.

All messages in the global chat are automatically and permanently deleted 24 hours after they were sent. This is a GDPR compliance requirement for minors and ensures the chat doesn't become an archive of conversations.

**Why this priority**: This is a constitutional requirement (Principle 2 - Privacy Foundation). GDPR compliance for minors in the EU is mandatory and non-negotiable.

**Independent Test**: Can be verified by sending a message and checking that it no longer exists after 24 hours. Works independently as a background process.

**Acceptance Scenarios**:

1. **Given** a message was sent exactly 24 hours ago, **When** the cleanup process runs, **Then** the message is permanently deleted from the system
2. **Given** a message is deleted, **When** I refresh the chat, **Then** the message no longer appears and cannot be retrieved
3. **Given** a message has reactions and is 24 hours old, **When** it is deleted, **Then** all associated reactions are also deleted
4. **Given** a message is a reply to another message that was deleted, **When** I view the reply, **Then** I see "[Messaggio eliminato]" as the quoted content

---

### User Story 4 - @Mention Other Students (Priority: P2)

As a student, I want to mention other students using @username so that I can get their attention and they receive a notification.

Students can type @ followed by a username to mention another student. The mentioned username is highlighted in the message, and the mentioned student receives an in-app notification.

**Why this priority**: Mentions add significant engagement value by enabling targeted communication. However, the core chat works without them, making this an enhancement rather than essential.

**Independent Test**: Can be tested by typing @username in a message, sending it, and verifying the mentioned user receives a notification. Works independently of reactions and replies.

**Acceptance Scenarios**:

1. **Given** I am composing a message, **When** I type "@", **Then** I see an autocomplete list of students matching what I type
2. **Given** I select a student from autocomplete, **When** the username is inserted, **Then** it appears highlighted in purple in my message
3. **Given** I send a message with @mario.rossi, **When** Mario views the chat, **Then** he sees his mention highlighted
4. **Given** I am mentioned in a message, **When** the message is sent, **Then** I receive an in-app notification "Ti hanno menzionato in chat"
5. **Given** I tap the mention notification, **When** the app opens, **Then** I am taken to the chat with the relevant message visible

---

### User Story 5 - Reply to Specific Messages (Priority: P2)

As a student, I want to reply to specific messages so that I can maintain context in conversations and make discussions easier to follow.

Students can reply to any message by swiping right on it. The reply shows a preview of the original message above the new content, creating a visual thread.

**Why this priority**: Reply functionality improves conversation flow significantly, especially in a busy global chat. However, basic messaging works without it.

**Independent Test**: Can be tested by swiping on a message, composing a reply, and verifying the reply shows the quoted context. Independent of mentions and reactions.

**Acceptance Scenarios**:

1. **Given** I see a message I want to reply to, **When** I swipe right on it, **Then** the compose area shows a preview of the original message
2. **Given** I am composing a reply, **When** I tap the X on the preview, **Then** the reply context is removed and I return to normal compose mode
3. **Given** I send a reply, **When** it appears in the chat, **Then** it shows a small preview of the original message above my response
4. **Given** I tap on the preview in a reply, **When** the original message exists, **Then** the chat scrolls to show the original message
5. **Given** the original message was deleted, **When** I view a reply to it, **Then** the preview shows "[Messaggio eliminato]"

---

### User Story 6 - React to Messages with Emoji (Priority: P2)

As a student, I want to react to messages with emoji so that I can express quick feedback without sending a full message.

Students can add emoji reactions to any message. A limited set of 6 emoji is available to keep reactions focused. Each user can add one of each reaction type per message.

**Why this priority**: Reactions add engagement and expressiveness but are not essential for communication. They enhance the experience without being critical.

**Independent Test**: Can be tested by long-pressing a message, selecting a reaction, and verifying it appears below the message. Independent of other features.

**Acceptance Scenarios**:

1. **Given** I see a message, **When** I long-press on it, **Then** I see a reaction picker with 6 emoji options (heart, thumbs up, laughing, surprised, sad, fire)
2. **Given** I tap a reaction emoji, **When** it is recorded, **Then** the reaction appears below the message with a count
3. **Given** a message has reactions, **When** I view it, **Then** I see each unique emoji with its count (e.g., "heart 5, thumbs up 3")
4. **Given** I have already reacted with heart, **When** I tap heart again, **Then** my reaction is removed
5. **Given** I tap on the reaction count, **When** the detail view opens, **Then** I see who reacted with each emoji

---

### User Story 7 - See Typing Indicators (Priority: P3)

As a student, I want to see when other students are typing so that I know someone is about to send a message.

When one or more students are actively typing, a typing indicator appears above the compose area showing their names.

**Why this priority**: Typing indicators add polish and real-time awareness but are not essential for communication. This is a "nice to have" feature.

**Independent Test**: Can be tested by having two users online, one typing, and verifying the other sees the indicator. Independent of message content.

**Acceptance Scenarios**:

1. **Given** Mario is typing in the chat, **When** I view the chat, **Then** I see "Mario sta scrivendo..." below the message list
2. **Given** Mario and Giulia are both typing, **When** I view the chat, **Then** I see "Mario e Giulia stanno scrivendo..."
3. **Given** three or more students are typing, **When** I view the chat, **Then** I see "Mario, Giulia e altri 2 stanno scrivendo..."
4. **Given** a student stops typing for 3 seconds, **When** the timeout expires, **Then** their name disappears from the indicator
5. **Given** I am typing, **When** I view the chat, **Then** I do not see my own name in the typing indicator

---

### User Story 8 - Send View-Once Ephemeral Media (Priority: P3)

As a student, I want to send images and videos that can only be viewed once so that I can share temporary content with privacy protection.

Students can send images and short videos (max 30 seconds) that recipients can view only once. After viewing, the media is deleted. Screenshot protection is enabled to prevent capture.

**Why this priority**: Ephemeral media is a complex feature that adds privacy protection for sensitive content. The core chat works fully without it, making it an advanced enhancement.

**Independent Test**: Can be tested by sending a view-once image, having another user view it, and verifying it becomes unavailable after viewing. Complex but independent feature.

**Acceptance Scenarios**:

1. **Given** I tap the camera/gallery icon in compose area, **When** I select an image or record a video (max 30s), **Then** I see a preview with "Visualizzazione singola" toggle
2. **Given** I enable "Visualizzazione singola" and send, **When** the media is uploaded, **Then** it appears in chat with a special "view-once" indicator icon
3. **Given** I tap on a view-once media message, **When** it opens full-screen, **Then** screenshot protection is activated (screen capture blocked or detected)
4. **Given** I close the view-once media viewer, **When** I return to the chat, **Then** the media shows as "Visualizzato" and cannot be opened again
5. **Given** a view-once media was not viewed within 24 hours, **When** the cleanup runs, **Then** it is deleted along with the message
6. **Given** I attempt to screenshot a view-once media on iOS, **When** the system detects the attempt, **Then** the sender is notified "Mario ha fatto uno screenshot"

---

### Edge Cases

- **What happens when a user sends an empty message?** The send button is disabled until the message contains at least 1 non-whitespace character
- **What happens when network connectivity is lost mid-message?** The message is queued locally and retried with exponential backoff (1s, 2s, 4s). After 3 failures, user is notified
- **What happens when a user rapidly sends many messages?** Rate limiting (max 10 messages per minute) prevents spam. User sees "Troppi messaggi. Attendi qualche secondo."
- **What happens when the chat has thousands of messages?** Only the most recent messages are loaded initially. Older messages load on scroll up (pagination)
- **What happens when a mentioned user has notifications disabled?** The mention is still highlighted but no notification is sent
- **What happens when two users react simultaneously?** Both reactions are recorded - reactions are additive, not exclusive
- **What happens when view-once media fails to upload?** User is notified and can retry. Media is not sent until upload completes successfully

---

## Requirements *(mandatory)*

### Functional Requirements

**Core Messaging (P1)**

- **FR-001**: System MUST display all non-deleted, non-hidden chat messages in a single global chat room
- **FR-002**: System MUST show messages in reverse chronological order (newest at bottom)
- **FR-003**: System MUST display sender's avatar, full name, class, and relative timestamp for each message
- **FR-004**: System MUST deliver new messages to all connected clients within 1 second
- **FR-005**: System MUST limit message length to 500 characters
- **FR-006**: System MUST prevent sending empty or whitespace-only messages
- **FR-007**: System MUST support pull-to-refresh to manually reload messages
- **FR-008**: System MUST show connection status indicator when offline or reconnecting

**Auto-Deletion (P1)**

- **FR-009**: System MUST automatically delete all messages older than 24 hours
- **FR-010**: System MUST cascade delete all associated data (reactions, media) when a message is deleted
- **FR-011**: System MUST run deletion cleanup at least once per hour

**Reporting (P1)**

- **FR-012**: System MUST provide a report option on every message via long-press
- **FR-013**: System MUST offer 4 report reasons: Spam, Contenuto inappropriato, Bullismo, Off-topic
- **FR-014**: System MUST prevent users from reporting the same message twice
- **FR-015**: System MUST automatically hide messages with 3 or more reports
- **FR-016**: System MUST add auto-hidden messages to the moderation queue

**Rate Limiting (P1)**

- **FR-017**: System MUST limit users to 10 messages per minute
- **FR-018**: System MUST display a user-friendly message when rate limit is exceeded

**@Mentions (P2)**

- **FR-019**: System MUST recognize @username patterns in message text
- **FR-020**: System MUST provide autocomplete suggestions when user types @
- **FR-021**: System MUST highlight mentioned usernames in a distinct color (purple)
- **FR-022**: System MUST generate an in-app notification for mentioned users
- **FR-023**: System MUST respect user notification preferences for mentions

**Reply/Quote (P2)**

- **FR-024**: System MUST allow users to reply to any message via swipe gesture
- **FR-025**: System MUST display quoted message preview above the reply
- **FR-026**: System MUST show "[Messaggio eliminato]" for replies to deleted messages
- **FR-027**: System MUST allow tapping quoted preview to scroll to original message
- **FR-028**: System MUST limit threading to one level (no replies to replies)

**Emoji Reactions (P2)**

- **FR-029**: System MUST provide 6 reaction options: heart, thumbs up, laughing, surprised, sad, fire
- **FR-030**: System MUST display reactions below the message with counts
- **FR-031**: System MUST allow users to add one of each reaction type per message
- **FR-032**: System MUST allow users to remove their own reactions
- **FR-033**: System MUST update reaction counts in real-time

**Typing Indicators (P3)**

- **FR-034**: System MUST show typing indicator when users are composing messages
- **FR-035**: System MUST display up to 3 names in the typing indicator
- **FR-036**: System MUST hide typing indicator 3 seconds after user stops typing
- **FR-037**: System MUST not show user's own name in typing indicator

**Ephemeral Media (P3)**

- **FR-038**: System MUST support sending images (JPEG, PNG, WebP) as view-once
- **FR-039**: System MUST support sending videos (MP4) up to 30 seconds as view-once
- **FR-040**: System MUST compress media to max 10MB before upload
- **FR-041**: System MUST enable screenshot protection when displaying view-once media
- **FR-042**: System MUST mark media as viewed after first open and prevent re-opening
- **FR-043**: System MUST notify sender when recipient screenshots on iOS
- **FR-044**: System MUST delete view-once media after viewing or after 24 hours (whichever first)
- **FR-045**: System MUST limit users to 5 view-once media per day

**Accessibility & Privacy**

- **FR-046**: System MUST NOT allow private/direct messages between users
- **FR-047**: System MUST require authentication to access chat
- **FR-048**: System MUST NOT log message content in application logs

---

### Key Entities

- **ChatMessage**: Represents a single message in the global chat. Contains sender reference, text content, mentions list, reaction count, reply reference, timestamps, and deletion/hidden status
- **ChatReaction**: Represents a user's emoji reaction to a message. Links user to message with specific emoji type
- **ChatReport**: Represents a report submitted against a message. Contains reporter, reason, and timestamp
- **ChatMedia**: Represents view-once image or video. Contains storage reference, media type, view status, and expiration

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Messages appear to all connected users within 1 second of being sent (real-time delivery)
- **SC-002**: 100% of messages older than 24 hours are automatically deleted (GDPR compliance)
- **SC-003**: Users can send and view messages with a perceived response time under 200ms (optimistic UI)
- **SC-004**: Reported messages are reviewed by moderators within 24 hours
- **SC-005**: Chat supports 500 concurrent users without performance degradation
- **SC-006**: Users can complete the flow of sending a message in under 5 seconds (compose, type, send)
- **SC-007**: View-once media cannot be re-opened after initial viewing (100% enforcement)
- **SC-008**: Screenshot protection successfully blocks capture on Android
- **SC-009**: iOS screenshot attempts result in sender notification within 2 seconds
- **SC-010**: 95% of users successfully complete their first message send without assistance
- **SC-011**: Rate limiting prevents spam without impacting normal usage (10 msg/min threshold)
- **SC-012**: Typing indicators appear within 500ms of user starting to type

---

## Assumptions

1. **Single Chat Room**: This specification assumes a single global chat room. No multiple channels, groups, or topic-based chats are included.
2. **School Email Required**: Users must be authenticated with @galileimoro.edu.it email to access chat.
3. **Profile Required**: Users must have a complete profile (name, class) before sending messages.
4. **No Message Editing**: Messages cannot be edited after sending. Users can only delete their own messages.
5. **Italian Language**: All UI text and system messages are in Italian.
6. **Screenshot Protection Best-Effort**: While Android screenshot protection is reliable, iOS protection is detection-based and cannot prevent all captures.
7. **No Read Receipts**: The chat does not show read receipts to protect user privacy and prevent surveillance dynamics.
8. **Reactions Not Notified**: Adding a reaction does not generate a notification to the message author.

---

## Constitutional Alignment

This feature aligns with Nova's constitutional principles:

- **Principle 2 (Privacy Foundation)**: 24-hour auto-delete ensures minimal data retention. No private messaging prevents cyberbullying accumulation.
- **Principle 4 (Performance First)**: Real-time delivery under 1 second, optimistic UI for perceived response under 200ms.
- **Principle 6 (Design System Strict)**: All UI uses NovaColors, NovaSpacing, NovaTypography constants.
- **Principle 7 (Content Moderation)**: Mandatory report button, auto-hide at 3 reports, moderator queue integration.
