# Feature Specification: Event Comments System

**Feature Branch**: `007-event-comments`
**Created**: 2025-01-22
**Status**: Draft
**Input**: User description: "Implementa un sistema completo di Commenti per eventi Nova, ispirato ai commenti Instagram ma adattato alla filosofia anti-social-network della scuola."

## Clarifications

### Session 2025-01-22

- Q: Should comments support accessibility features for visually impaired students (screen readers, VoiceOver/TalkBack)? → A: Basic compliance with screen reader labels on all interactive elements (buttons, inputs) and semantic widget structure, without specialized VoiceOver/TalkBack testing in MVP
- Q: What should happen if Supabase Realtime is unavailable for extended periods (>5 min)? → A: Fall back to pull-to-refresh with visual indicator. Show banner "Aggiornamenti in tempo reale non disponibili. Usa pull-to-refresh", disable auto-updates, allow manual refresh
- Q: What UI feedback should users receive when they hit rate limits (3 identical comments in 5 min, 100 likes/hour)? → A: Toast/Snackbar with countdown timer showing "Hai raggiunto il limite. Riprova tra 3m 24s" with live countdown, auto-dismiss after 5 seconds
- Q: When a moderator removes a comment, should the original author be notified? → A: Yes, send in-app notification with moderator-provided reason (e.g., "Il tuo commento è stato rimosso: Linguaggio inappropriato"). Transparent, educational, aligns with STUDENTS_FIRST and anti-shadow-banning principles
- Q: Should edited comments display an "edited" indicator to other users? → A: Yes, show "(modificato)" label next to timestamp when updated_at != created_at (e.g., "5 min fa (modificato)"). Transparency prevents deceptive edits, standard Instagram pattern students recognize

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View and Write Top-Level Comments (Priority: P1)

Students can view existing comments on an event and add their own comments to ask questions, share information, or discuss event details. Comments appear in a dedicated fullscreen sheet with smooth animations and clear visual hierarchy.

**Why this priority**: Core functionality that enables basic event discussion. Without this, students cannot communicate about events at all. This is the minimum viable product for event engagement.

**Independent Test**: Can be fully tested by opening any event, viewing the comments sheet (even if empty), writing a new comment, and seeing it appear in the list. Delivers immediate value for event organizers and participants to communicate.

**Acceptance Scenarios**:

1. **Given** Sofia is viewing the "Torneo Basket 3v3" event card, **When** she taps the "💬 24 commenti" icon, **Then** a fullscreen bottom sheet (iOS) or modal (Android) slides up smoothly with centered title "Commenti", comment count "24 commenti", and scrollable list of existing comments
2. **Given** Sofia scrolls to the bottom of the comments list, **When** she taps the input field with placeholder "Aggiungi un commento...", **Then** the keyboard opens and she can type up to 500 characters with auto-expand up to 4 lines
3. **Given** Sofia has typed "Ci sono ancora posti? Vorrei iscrivermi 🏀" (45 characters), **When** she taps the send button (→ arrow icon), **Then** her comment appears immediately at the top of the list with optimistic UI, the input field clears, and the event creator receives a notification
4. **Given** an event has zero comments, **When** a student opens the comments sheet, **Then** they see an empty state with "💬" icon, "Nessun commento ancora", and "Sii il primo a commentare!"
5. **Given** Sofia tries to send an empty comment or only whitespace, **When** she taps send, **Then** the send button remains disabled and nothing is submitted

---

### User Story 2 - Like Comments and View Engagement (Priority: P1)

Students can like comments they find helpful or agree with, see like counts, and unlike comments. Likes provide social validation and help surface valuable contributions.

**Why this priority**: Essential feedback mechanism that encourages constructive contributions. Allows community to signal agreement without cluttering the thread with "+1" comments. Required for P2 "sort by popular" feature.

**Independent Test**: Can be tested by viewing any comment, tapping the ❤️ icon, seeing the visual feedback (color change, animation, counter update), and tapping again to unlike. Works completely independently of other features.

**Acceptance Scenarios**:

1. **Given** Anna is reading Marco's comment "Sì! Ci sono 3 posti liberi", **When** she taps the ❤️ icon, **Then** the icon animates with a "pop" scale effect, changes from gray to purple (Nova brand color), and shows "❤️ 1" counter
2. **Given** Anna has already liked a comment showing "❤️ 5", **When** she taps the ❤️ icon again, **Then** the icon turns gray, the counter decrements to "❤️ 4", and the unlike is saved optimistically
3. **Given** a comment has zero likes, **When** displayed in the list, **Then** the like icon appears gray with no counter (counter only shows when >0)
4. **Given** a comment has 1,234 likes, **When** displayed in the list, **Then** the counter shows "❤️ 1K+" (abbreviated for large numbers >999)
5. **Given** network error occurs during like, **When** optimistic UI has already updated, **Then** the UI rolls back to previous state and shows error message to user

---

### User Story 3 - Reply to Comments with Threading (Priority: P1)

Students can reply to specific comments, creating threaded conversations. Replies are visually indented and reference the parent comment with @mentions, making discussions easier to follow.

**Why this priority**: Enables actual conversations rather than just a flat list of disconnected comments. Critical for answering questions and building on others' contributions. Supports the school's goal of constructive discussion.

**Independent Test**: Can be tested by tapping "💬 Rispondi" on any comment, typing a reply with auto-prefilled @mention, sending it, and seeing it appear indented below the parent. Delivers threaded discussion value immediately.

**Acceptance Scenarios**:

1. **Given** Marco sees Sofia's comment "Ci sono ancora posti?", **When** he taps "💬 Rispondi", **Then** the input field switches to reply mode with purple header "Rispondi a Sofia", close button (✕), and input pre-filled with "@Sofia "
2. **Given** Marco is in reply mode, **When** he types "Sì! Ci sono 3 posti liberi 👍" and taps send, **Then** his reply appears indented 48px to the right below Sofia's comment, with vertical line connecting them, and Sofia receives a notification "Marco ha risposto al tuo commento"
3. **Given** a comment has 2 replies, **When** displayed in the list, **Then** it shows thread indicator "└─ 2 risposte" below the reply button
4. **Given** a thread has more than 3 replies and is collapsed by default, **When** a student taps "└─ 5 risposte", **Then** all 5 replies expand smoothly with animation, and tapping again collapses them
5. **Given** student is in reply mode, **When** they tap the close button (✕) in the reply header, **Then** reply mode exits and input returns to normal mode with empty field

---

### User Story 4 - Report Inappropriate Comments (Priority: P1)

Students and moderators can report comments that violate school guidelines (spam, inappropriate content, bullying). Reports trigger moderation review and auto-hide comments with multiple reports.

**Why this priority**: Essential safety feature for a school environment with minors (ages 14-19). Without this, the platform cannot maintain school-appropriate content. Required for GDPR compliance and duty of care.

**Independent Test**: Can be tested by long-pressing (Android) or swiping left (iOS) on any comment, selecting "🚩 Segnala", choosing a reason, and submitting. Moderators see the report in their dashboard. Delivers safety immediately.

**Acceptance Scenarios**:

1. **Given** Luca sees a spam comment "COMPRA BIGLIETTI QUI [link]", **When** he long-presses (Android) or swipes left (iOS) and taps "🚩 Segnala", **Then** a dialog opens with title "Perché segnali questo commento?" and checkboxes for: Spam, Contenuto inappropriato, Bullismo/molestie, Off-topic, Altro (with optional text field)
2. **Given** Luca selects "Spam" and taps "Invia segnalazione", **When** the report is submitted, **Then** the report is saved to the database, moderators receive a notification in their dashboard, and Luca sees confirmation message
3. **Given** a comment has been reported by 3 or more different users, **When** the third report is submitted, **Then** the comment is automatically hidden from the feed (auto-hide) and placed in the moderation queue for review
4. **Given** a moderator reviews a reported comment and determines it's legitimate, **When** they dismiss the report, **Then** the comment is unhidden and the report count resets
5. **Given** student tries to spam-report the same comment multiple times, **When** they attempt to submit a second report, **Then** the system rejects it (each user can only report a comment once)

---

### User Story 5 - Delete Own Comments (Priority: P1)

Students can delete their own comments if they made a mistake, the information is outdated, or they change their mind. Deleted comments are soft-deleted, preserving replies if they exist.

**Why this priority**: Gives students control over their contributions, reduces clutter from outdated information, and supports GDPR Right to Erasure. Essential for user autonomy.

**Independent Test**: Can be tested by posting a comment, long-pressing it, selecting "🗑️ Elimina", confirming deletion, and seeing it removed or replaced with placeholder. Works independently of all other features.

**Acceptance Scenarios**:

1. **Given** Sofia has posted "Ci sono posti?" but the event is now full, **When** she long-presses her comment and taps "🗑️ Elimina", **Then** a confirmation dialog appears: "Sei sicuro di voler eliminare questo commento?" with [Annulla] and [Elimina] buttons (destructive color)
2. **Given** Sofia confirms deletion on a comment with zero replies, **When** the deletion completes, **Then** the comment disappears completely from the list and is soft-deleted (deleted_at timestamp set)
3. **Given** Sofia deletes a comment that has 2 replies, **When** the deletion completes, **Then** the comment text is replaced with "[Commento eliminato]" placeholder but the 2 replies remain visible and indented below it
4. **Given** Sofia deletes a comment, **When** other users refresh their view, **Then** they see the deleted state immediately (or "[Commento eliminato]" if it has replies)
5. **Given** Sofia attempts to delete someone else's comment, **When** she long-presses it, **Then** the "🗑️ Elimina" option does not appear in the action menu (only "💬 Rispondi", "🚩 Segnala", "📋 Copia testo" are shown)

---

### User Story 6 - Moderator Comment Removal (Priority: P1)

Moderators can immediately remove inappropriate comments without confirmation, hard-delete them from the system, and log the action in the admin panel. This power tool enables rapid response to policy violations.

**Why this priority**: Moderators need quick action capability for serious violations (bullying, explicit content, threats). 24-hour SLA for moderation review requires efficient tools. Protects the student community.

**Independent Test**: Can be tested by a moderator account long-pressing any comment, selecting "🛡️ Rimuovi commento", and seeing it hard-deleted instantly with action logged. Delivers immediate moderation power.

**Acceptance Scenarios**:

1. **Given** moderator Anna sees an inappropriate comment in the review queue or feed, **When** she long-presses the comment, **Then** she sees moderator-only actions: "🛡️ Rimuovi commento" and "⚠️ Avvisa utente" in addition to standard actions
2. **Given** moderator Anna taps "🛡️ Rimuovi commento", **When** the action executes, **Then** the comment is hard-deleted immediately (no confirmation dialog), disappears from all users' views, and the deletion is logged with "Moderatore Anna ha rimosso commento ID 123"
3. **Given** a moderator removes a comment, **When** the original comment author checks their notifications, **Then** they do NOT receive a notification about the deletion (to avoid conflicts and reduce moderator harassment)
4. **Given** moderator Anna taps "⚠️ Avvisa utente", **When** the warning is sent, **Then** the comment author receives a notification explaining the violation and the comment remains visible (warning without deletion)
5. **Given** a non-moderator student account, **When** they long-press any comment, **Then** they NEVER see the "🛡️ Rimuovi commento" or "⚠️ Avvisa utente" options (role-based access control)

---

### User Story 7 - Real-Time Comment Updates (Priority: P1)

Students see new comments, replies, and likes appear in real-time without refreshing. This creates a live, engaging experience and prevents confusion from stale data.

**Why this priority**: Prevents students from missing new responses or duplicate-posting questions already answered. Critical for time-sensitive event coordination (e.g., "Are we meeting at 3pm?"). Enhances engagement.

**Independent Test**: Can be tested by having two devices open the same event's comments, posting from one device, and seeing it appear on the other within 500ms. Delivers live discussion value immediately.

**Acceptance Scenarios**:

1. **Given** Marco and Sofia both have the "Torneo Basket 3v3" comments sheet open, **When** Marco posts a new comment, **Then** Sofia sees it appear at the top of her list within 500ms without manual refresh (Supabase Realtime subscription)
2. **Given** Anna has the comments sheet open, **When** another user likes a comment she's viewing, **Then** the like count updates in real-time on her screen (e.g., "❤️ 4" → "❤️ 5")
3. **Given** students are viewing a thread with 3 replies, **When** a 4th reply is posted by another user, **Then** the thread indicator updates from "└─ 3 risposte" to "└─ 4 risposte" and the new reply appears if the thread is expanded
4. **Given** a moderator removes a comment while students are viewing it, **When** the hard-delete occurs, **Then** the comment disappears from all users' screens in real-time
5. **Given** network connectivity is lost, **When** users attempt to interact with comments, **Then** optimistic UI still works but shows pending state, and updates sync when connection is restored

---

### User Story 8 - Pull-to-Refresh and Pagination (Priority: P1)

Students can manually refresh the comments list by pulling down and scroll through long comment threads with automatic pagination. This ensures they can always get the latest data and view all comments efficiently.

**Why this priority**: Handles edge cases where real-time subscriptions fail or users want to force-refresh. Prevents performance issues with events that have hundreds of comments. Essential for scalability.

**Independent Test**: Can be tested by opening an event with 50+ comments, scrolling to the bottom to trigger pagination, and pulling down from the top to refresh. Works independently as data-fetching mechanism.

**Acceptance Scenarios**:

1. **Given** student is viewing the comments list (iOS), **When** they pull down from the top, **Then** a CupertinoSliverRefreshControl appears, the comments re-fetch from the server, and any new comments appear at the top
2. **Given** student is viewing the comments list (Android), **When** they pull down from the top, **Then** a Material RefreshIndicator appears, the comments re-fetch, and the list updates
3. **Given** an event has 50 comments loaded (20 per page = 2.5 pages), **When** student scrolls to the bottom, **Then** the next 20 comments load automatically (infinite scroll) without requiring a button press
4. **Given** student scrolls through paginated comments, **When** they reach the absolute bottom (no more comments), **Then** pagination stops and no loading indicator appears
5. **Given** student force-refreshes the list, **When** new comments exist on the server, **Then** they appear at the top with smooth insertion animation (not jarring full-list reload)

---

### User Story 9 - Sort Comments by Recenti vs Popolari (Priority: P2)

Students can toggle between viewing comments sorted by "Recenti" (most recent first, default) or "Popolari" (most liked first). This helps surface the most valuable contributions.

**Why this priority**: Enhances discoverability of helpful comments on popular events with hundreds of comments. "Recenti" shows latest updates, "Popolari" surfaces community-validated content. Nice-to-have for improved UX.

**Independent Test**: Can be tested by opening any event with multiple comments, toggling the sort control (iOS: CupertinoSegmentedControl, Android: Chip selector), and seeing the list re-order. Works independently as UI feature.

**Acceptance Scenarios**:

1. **Given** student opens the comments sheet (iOS), **When** they see the sort toggle below the title, **Then** it shows two segments: "Recenti" (selected by default) and "Popolari", styled as CupertinoSegmentedControl
2. **Given** student taps "Popolari", **When** the sort changes, **Then** the comments re-order by like_count DESC (highest first), and the selection updates visually
3. **Given** student is viewing "Popolari" sort, **When** they tap "Recenti", **Then** the comments re-order by created_at DESC (newest first), returning to default sort
4. **Given** student toggles sort, **When** the list re-orders, **Then** the animation is smooth (no jarring jump) and scroll position resets to top
5. **Given** student selects "Popolari" and closes the comments sheet, **When** they reopen it, **Then** the sort resets to "Recenti" (default, no persistence across sessions)

---

### User Story 10 - Edit Comments Within 5-Minute Window (Priority: P2)

Students can edit their own comments within 5 minutes of posting to fix typos or clarify meaning. After 5 minutes, comments become immutable to prevent abuse.

**Why this priority**: Reduces need to delete-and-repost for minor corrections. Prevents abuse scenarios like "bait-and-switch" edits on older comments. Balances flexibility with integrity.

**Independent Test**: Can be tested by posting a comment, immediately long-pressing it, selecting "✏️ Modifica", making changes, saving, and seeing the updated text. Time-window can be tested by waiting 5+ minutes and verifying edit option disappears.

**Acceptance Scenarios**:

1. **Given** student posted a comment 2 minutes ago, **When** they long-press their comment, **Then** they see "✏️ Modifica" option in the action menu (in addition to "🗑️ Elimina")
2. **Given** student taps "✏️ Modifica", **When** the edit mode opens, **Then** the input field is pre-filled with the current comment text, max 500 characters, with character counter and save button
3. **Given** student edits the text and taps save, **When** the update is submitted, **Then** the comment text updates in the list (server-validated to ensure <500 chars and no profanity), and other users see the new text via real-time sync
4. **Given** student posted a comment 6 minutes ago, **When** they long-press their comment, **Then** "✏️ Modifica" does NOT appear (5-minute window expired), only "🗑️ Elimina" and other standard actions
5. **Given** student tries to edit profanity into a comment, **When** they tap save, **Then** the server rejects it with error "Il commento contiene linguaggio inappropriato" and the original text is preserved

---

### User Story 11 - Tap Mentions to View Profiles (Priority: P2)

Students can tap @mentions in comment text to navigate to the mentioned user's profile. This enables exploring who's participating in discussions and builds community awareness.

**Why this priority**: Enhances discoverability of other students and encourages profile completeness. Supports the anti-social-network philosophy by keeping profiles focused on school contribution (events created, participation) rather than follower counts.

**Independent Test**: Can be tested by viewing any comment with @mention (e.g., "@Marco Sì!"), tapping the highlighted mention, and seeing Marco's profile open. Works independently as navigation feature.

**Acceptance Scenarios**:

1. **Given** a comment contains "@Marco Sì! Ci sono tornei", **When** displayed in the list, **Then** "@Marco" is highlighted in purple (Nova brand color) to indicate it's tappable
2. **Given** student taps "@Marco" mention, **When** the navigation completes, **Then** Marco's profile screen opens showing avatar, name, class, events created, participation count, and bio (if set)
3. **Given** a mention references a user who no longer exists (deleted account), **When** student taps it, **Then** the mention remains styled but shows error toast "Profilo non trovato" and does not navigate
4. **Given** student is composing a reply, **When** they manually type "@" followed by any username (no autocomplete in MVP), **Then** the text is saved as-is and rendered as a mention when posted (server validates username exists)
5. **Given** a comment has multiple mentions like "@Sofia @Anna @Luca", **When** displayed, **Then** all three are highlighted and independently tappable

---

### User Story 12 - Copy Comment Text to Clipboard (Priority: P2)

Students can copy comment text to their device clipboard for sharing outside the app or referencing later. This supports information portability and student autonomy.

**Why this priority**: Useful for sharing event details via other channels (WhatsApp, email) or saving important information. Aligns with GDPR data portability principles. Low-effort, high-utility feature.

**Independent Test**: Can be tested by long-pressing any comment, selecting "📋 Copia testo", and pasting into another app (Notes, Messages). Works independently as clipboard operation.

**Acceptance Scenarios**:

1. **Given** student long-presses (Android) or swipes left (iOS) on any comment, **When** they tap "📋 Copia testo" in the action menu, **Then** the comment text (without author name, timestamp, or likes) is copied to the system clipboard
2. **Given** comment text is copied, **When** student opens another app and pastes, **Then** they see the plain text content including emoji (e.g., "Ottimo evento! Ci sono anche i tornei 3v3? 🏀")
3. **Given** student copies a comment with @mentions, **When** pasted, **Then** mentions are preserved as plain text (e.g., "@Marco Sì! Ci sono tornei" → "@Marco Sì! Ci sono tornei")
4. **Given** student copies a deleted comment showing "[Commento eliminato]", **When** pasted, **Then** they see "[Commento eliminato]" as the text (system prevents copying deleted content's original text)
5. **Given** student successfully copies text, **When** the action completes, **Then** a brief toast notification appears: "Testo copiato" (confirmation feedback)

---

### User Story 13 - Receive Notifications for Comments and Replies (Priority: P2)

Event creators receive notifications when someone comments on their event. Comment authors receive notifications when someone replies to their comment. This keeps students engaged and informed of conversations.

**Why this priority**: Drives engagement and ensures event creators see questions/feedback. Prevents "dead" comment threads where questions go unanswered. Balances notification value with spam prevention (no notifications for likes).

**Independent Test**: Can be tested by posting a comment on someone else's event, verifying they receive a notification, and tapping the notification to see it deep-links to the specific comment. Works independently as notification feature.

**Acceptance Scenarios**:

1. **Given** Sofia posts a comment on Marco's event "Torneo Basket 3v3", **When** the comment is saved, **Then** Marco receives a notification: "Sofia ha commentato il tuo evento 'Torneo Basket'" with deep link nova://event/{event_id}/comment/{comment_id}
2. **Given** Marco receives the comment notification, **When** he taps it, **Then** the app opens the event's comments sheet, scrolls to Sofia's specific comment, and highlights it briefly with a fade animation
3. **Given** Marco replies to Sofia's comment, **When** the reply is saved, **Then** Sofia receives a notification: "Marco ha risposto al tuo commento" with deep link to the specific reply
4. **Given** student has disabled "Notifiche commenti" in Settings → Privacy, **When** someone comments on their event or replies to them, **Then** NO notification is sent (toggle is OFF by default: ON for all users)
5. **Given** a comment receives 10 likes, **When** the likes accumulate, **Then** the comment author does NOT receive notifications for likes (to prevent notification spam - only comments and replies trigger notifications)

---

### Edge Cases

- **What happens when a student tries to post a comment while offline?** The optimistic UI shows the comment immediately with a "pending" indicator. When connection is restored, the comment syncs to the server. If sync fails after 3 retries, the comment is removed from the UI and the student sees an error toast "Impossibile inviare il commento. Riprova."

- **How does the system handle spam (3 identical comments in 5 minutes)?** The server-side PostgreSQL function checks the last 3 comments by the user. If 3 identical texts exist within 5 minutes, the submission is rejected with error: "Troppi commenti simili, attendi." The rate limit is per-user, per-event.

- **What happens when a moderator removes a comment that has active replies?** The comment is hard-deleted entirely. All child replies are also deleted (cascade delete) because they reference a non-existent parent. This is intentional to prevent orphaned replies that lack context.

- **How are comments on deleted events handled?** When an event is soft-deleted (deleted_at set), all its comments remain in the database but are inaccessible via the UI. If the event is hard-deleted (GDPR erasure), comments are cascade-deleted via database foreign key constraint.

- **What happens when network latency causes duplicate real-time updates?** The Supabase Realtime subscription uses `primaryKey: ['id']` to deduplicate updates. If the same comment appears twice in the stream, the UI ignores the duplicate based on ID matching.

- **How does the system handle profanity filter edge cases (e.g., legitimate words containing profane substrings)?** The server-side filter uses a curated Italian profanity list with whole-word matching (not substring). False positives are manually reviewed and whitelisted. Students can appeal via "Contact Support" if a legitimate comment is blocked.

- **What happens when a student deletes their account while their comments exist?** Comments are soft-deleted (deleted_at set) and display as "[Commento eliminato]" with author shown as "Utente Eliminato". This preserves thread context while respecting GDPR Right to Erasure after the 30-day grace period.

- **How does the system handle like count consistency when multiple users like/unlike simultaneously?** The database uses `like_count` as a cached counter updated via database trigger on the `comment_likes` table. Each insert increments, each delete decrements. This prevents race conditions and ensures eventual consistency.

- **What happens when a comment thread grows beyond 100 replies?** The UI limits pagination to 20 comments per load. If a single parent has >100 replies, the "└─ X risposte" indicator shows the count but only loads replies in chunks of 20 when expanded. Performance remains at 60fps via virtualized scrolling.

- **How are timestamps displayed for comments older than 7 days?** Relative timestamps ("2h fa", "Ieri", "3 giorni fa") are used for comments <7 days old. Comments ≥7 days show absolute date ("15 Gen 2025"). This balances recency cues with clarity for older content.

## Requirements *(mandatory)*

### Functional Requirements

#### Core Comment Viewing & Composition

- **FR-001**: System MUST display a comments icon "💬 X commenti" on every event card showing the current comment count (0 if no comments)
- **FR-002**: System MUST open a fullscreen bottom sheet (iOS CupertinoModalPopup) or modal (Android ModalBottomSheet) when user taps the comments icon, with smooth slide-up animation
- **FR-003**: Comments sheet MUST display a centered title "Commenti", close button (X) in top-left, and subtitle showing count "X commenti" in secondary text color
- **FR-004**: System MUST render comments in a vertically scrollable list with infinite pagination (20 comments per page), loading more automatically as user scrolls to bottom
- **FR-005**: Each comment card MUST display: circular avatar (40×40px), author name (bold, 14px), class badge (e.g., "5A", 12px, secondary color), relative timestamp (e.g., "2h fa"), comment text (14px, max 500 characters), like count (if >0), reply button, and thread indicator (if replies exist)
- **FR-006**: System MUST show moderator badge (🛡️ emoji in brand color) next to name if author has moderator role
- **FR-007**: Comments MUST support inline Unicode emoji without breaking layout or requiring external libraries
- **FR-008**: System MUST display empty state (centered "💬" icon, "Nessun commento ancora", "Sii il primo a commentare!") when event has zero comments
- **FR-009**: Input field MUST be fixed to bottom of comments sheet (sticky during scroll) with elevation shadow, showing user's avatar (32×32px), multiline text input (auto-expand up to 4 lines), character counter when >400 chars, and send button (→ arrow)
- **FR-010**: Send button MUST be disabled (gray) when input is empty or only whitespace, and enabled (brand color purple) when valid text exists
- **FR-011**: System MUST validate comment text on submit: min 1 character (after trim), max 500 characters hard limit, no profanity (server-side filter), and reject if fails with clear error message
- **FR-012**: System MUST use optimistic UI: new comment appears immediately at top of list, syncs to server in background, and rolls back with error if server rejects

#### Threading & Replies

- **FR-013**: System MUST allow users to reply to any comment by tapping "💬 Rispondi" button
- **FR-014**: When replying, input field MUST switch to reply mode: purple header showing "Rispondi a [Author Name]", close button (✕) to exit reply mode, and input pre-filled with "@[AuthorName] "
- **FR-015**: Replies MUST be visually indented 48px to the right of parent comment, with vertical line (light gray) connecting reply to parent
- **FR-016**: System MUST enforce max 1 level of threading: replies to replies are treated as top-level sibling replies (no sub-sub-replies)
- **FR-017**: Comments with replies MUST show thread indicator "└─ X risposte" below reply button, where X is the reply count
- **FR-018**: Threads with >3 replies MUST be collapsed by default, showing only parent comment and thread indicator
- **FR-019**: Tapping thread indicator "└─ X risposte" MUST expand all replies with smooth animation; tapping again MUST collapse them
- **FR-020**: System MUST preserve thread structure in real-time: new replies appear immediately under parent when posted by any user

#### Like System

- **FR-021**: Users MUST be able to like/unlike any comment by tapping the ❤️ icon
- **FR-022**: Like action MUST trigger "pop" scale animation and change icon color from gray (unliked) to purple (liked)
- **FR-023**: Like counter MUST show "❤️ X" when count >0, and hide completely when count = 0
- **FR-024**: Like counter MUST abbreviate large numbers: "❤️ 1K+" for counts >999
- **FR-025**: System MUST use optimistic UI for likes: update UI immediately, sync to server in background, rollback if error
- **FR-026**: System MUST enforce rate limit: max 100 likes per user per hour, with 500ms debounce to prevent double-tap
- **FR-027**: System MUST prevent duplicate likes: each user can like a comment only once (database constraint: PRIMARY KEY on comment_id, user_id in comment_likes table)

#### Moderation & Safety

- **FR-028**: Users MUST be able to report comments via long-press (Android) or swipe-left (iOS) gesture, revealing "🚩 Segnala" action
- **FR-029**: Report dialog MUST show checkboxes for: Spam, Contenuto inappropriato, Bullismo/molestie, Off-topic, Altro (with optional text field)
- **FR-030**: System MUST save report to database with reporter_user_id, comment_id, reason, and timestamp
- **FR-031**: System MUST auto-hide comments when reported by 3+ different users, placing them in moderation queue with status "pending review"
- **FR-032**: Moderators MUST receive real-time notification when a comment is reported or auto-hidden
- **FR-033**: Moderators MUST see additional actions when long-pressing comments: "🛡️ Rimuovi commento" (hard delete) and "⚠️ Avvisa utente" (send warning without deletion)
- **FR-034**: Moderator hard-delete MUST remove comment immediately without confirmation, cascade-delete all replies, and log action with moderator ID and timestamp
- **FR-035**: System MUST NOT notify comment author when moderator removes their comment (to prevent harassment)
- **FR-036**: System MUST validate all comment text server-side using Italian profanity filter (whole-word matching), rejecting submissions with error "Il commento contiene linguaggio inappropriato"
- **FR-037**: System MUST NOT use shadow-banning: all rejections MUST show explicit error messages to the user

#### User Actions on Own Comments

- **FR-038**: Users MUST be able to delete their own comments via "🗑️ Elimina" action in long-press/swipe menu
- **FR-039**: Delete action MUST show confirmation dialog: "Sei sicuro di voler eliminare questo commento?" with [Annulla] and [Elimina] buttons (destructive color for Elimina)
- **FR-040**: Deleting a comment with zero replies MUST soft-delete it (set deleted_at timestamp) and remove from UI entirely
- **FR-041**: Deleting a comment with 1+ replies MUST soft-delete it but show placeholder "[Commento eliminato]" in place of original text, preserving replies
- **FR-042**: Users MUST be able to edit their own comments within 5 minutes of posting via "✏️ Modifica" action
- **FR-043**: Edit mode MUST pre-fill input with current text, enforce 500-character limit, validate profanity server-side, and update comment text on save
- **FR-044**: After 5-minute window expires, "✏️ Modifica" action MUST NOT appear in the menu (only "🗑️ Elimina" remains)

#### Additional User Actions

- **FR-045**: Users MUST be able to copy comment text to clipboard via "📋 Copia testo" action
- **FR-046**: Copy action MUST copy plain text (no formatting, author name, or timestamp), including emoji, and show toast "Testo copiato" on success
- **FR-047**: Users MUST be able to tap author avatar or name to navigate to that user's profile screen

#### Real-Time & Data Sync

- **FR-048**: System MUST use Supabase Realtime subscriptions to stream new comments, replies, likes, and deletions to all clients viewing the same event
- **FR-049**: Real-time updates MUST appear within 500ms of server save (measured p95 latency)
- **FR-050**: System MUST deduplicate real-time events using comment ID to prevent duplicate UI updates
- **FR-051**: Users MUST be able to pull-to-refresh the comments list using platform-native gestures (iOS: CupertinoSliverRefreshControl, Android: RefreshIndicator)
- **FR-052**: Pull-to-refresh MUST re-fetch comments from server and display new content with smooth animation
- **FR-053**: System MUST handle offline scenarios: allow optimistic UI updates while offline, queue them, and sync when connection is restored

#### Notifications

- **FR-054**: System MUST send push notification to event creator when someone comments on their event: "Marco ha commentato il tuo evento 'Torneo Basket'"
- **FR-055**: System MUST send push notification to comment author when someone replies to their comment: "Sofia ha risposto al tuo commento"
- **FR-056**: Tapping notification MUST deep-link to the specific comment using schema nova://event/{event_id}/comment/{comment_id}, open the comments sheet, scroll to the comment, and briefly highlight it with fade animation
- **FR-057**: Users MUST be able to toggle "Notifiche commenti" in Settings → Privacy (default: ON)
- **FR-058**: System MUST NOT send notifications for likes (to prevent spam)

#### Sorting & Filtering

- **FR-059**: Comments sheet MUST display sort toggle with two options: "Recenti" (default, sort by created_at DESC) and "Popolari" (sort by like_count DESC)
- **FR-060**: Sort toggle MUST use platform-native UI: iOS = CupertinoSegmentedControl, Android = Material Chip selector
- **FR-061**: Changing sort MUST re-order the comment list with smooth animation and reset scroll position to top
- **FR-062**: Sort preference MUST NOT persist across sessions: always defaults to "Recenti" when reopening comments sheet

#### Mentions

- **FR-063**: System MUST highlight @mentions in comment text using brand purple color to indicate they are tappable
- **FR-064**: Tapping an @mention MUST navigate to the mentioned user's profile screen
- **FR-065**: If mentioned user no longer exists (deleted account), tapping mention MUST show error toast "Profilo non trovato" and not navigate
- **FR-066**: System MUST validate @mentions server-side: reject if mentioned username does not exist in database

#### Rate Limiting & Anti-Spam

- **FR-067**: System MUST enforce rate limit: max 3 identical comments (by text content) in 5 minutes per user per event
- **FR-068**: If rate limit is hit, system MUST reject with error "Troppi commenti simili, attendi"
- **FR-069**: System MUST enforce like rate limit: max 100 likes per user per hour across all comments
- **FR-070**: System MUST debounce like button taps with 500ms delay to prevent accidental double-taps

#### Performance & Scalability

- **FR-071**: Comments list MUST maintain 60fps sustained scroll performance even with 100+ comments loaded
- **FR-072**: Initial load of 20 comments MUST complete in <1 second on 4G connection
- **FR-073**: Real-time comment updates MUST have p95 latency <500ms from server save to UI update
- **FR-074**: Like/unlike actions MUST have perceived response time <200ms (optimistic UI)

#### Data Retention & GDPR

- **FR-075**: When a user deletes their account, all their comments MUST be soft-deleted (deleted_at set) and display as "[Commento eliminato]" with author "Utente Eliminato"
- **FR-076**: Hard deletion (after 30-day grace period) MUST cascade-delete all comments by that user from the database
- **FR-077**: System MUST support GDPR data export: include all comments (text, timestamps, like counts) in user's JSON export file

#### Accessibility

- **FR-078**: All interactive elements (buttons, inputs, action menus) MUST have semantic labels for screen reader support (iOS VoiceOver, Android TalkBack), including: comment author name, timestamp, like button state, reply button, delete button, report button, and input field placeholder

### Key Entities *(data involved)*

- **Comment**: Represents a single comment on an event. Attributes: id (UUID), event_id (foreign key to events table), user_id (foreign key to auth.users), parent_comment_id (nullable, foreign key to comments.id for threading), text (max 500 chars), like_count (integer, cached counter), report_count (integer, cached counter), deleted_at (nullable timestamp for soft delete), created_at (timestamp), updated_at (timestamp). Relationships: belongs to one Event, belongs to one User (author), has many Replies (self-referential), has many CommentLikes, has many CommentReports.

- **CommentLike**: Represents a user liking a specific comment. Attributes: comment_id (foreign key to comments.id), user_id (foreign key to auth.users), created_at (timestamp). Constraints: PRIMARY KEY (comment_id, user_id) to prevent duplicate likes. Relationships: belongs to one Comment, belongs to one User.

- **CommentReport**: Represents a user reporting a comment as inappropriate. Attributes: id (UUID), comment_id (foreign key to comments.id), reporter_user_id (foreign key to auth.users), reason (text enum: "spam", "inappropriate", "bullying", "other"), details (nullable text for "other" explanations), created_at (timestamp). Relationships: belongs to one Comment, belongs to one User (reporter).

- **Event**: Existing entity extended with comment_count field. Attributes include: id, title, description, creator_id, status (approved/pending/rejected), comment_count (cached integer, updated via database trigger on comments table). Relationships: has many Comments.

- **User**: Existing entity (from auth.users Supabase table) extended with profile data. Attributes include: id, email, name, class, role (student/moderator), avatar_url. Relationships: has many Comments (authored), has many CommentLikes, has many CommentReports (created).

## Success Criteria *(mandatory)*

### Measurable Outcomes

#### Adoption Metrics

- **SC-001**: 60% or more of monthly active users post at least one comment per week within the first month of launch
- **SC-002**: Events categorized as "popular" (>50 participants) average 10 or more comments each within 48 hours of event creation
- **SC-003**: 40% or more of users who post comments also use the reply feature (thread engagement) at least once per week

#### Engagement Quality

- **SC-004**: 50% or more of top-level comments receive at least one reply, indicating active discussions rather than isolated messages
- **SC-005**: 70% or more of comments receive at least one like, showing community validation and engagement
- **SC-006**: Reply rate (percentage of comments that are replies vs. top-level) reaches 30% or higher, demonstrating threaded conversations

#### Moderation Effectiveness

- **SC-007**: Less than 1% of all comments are reported by users, indicating low rate of inappropriate content
- **SC-008**: 90% or more of comment reports are reviewed by moderators within 24 hours (moderation SLA)
- **SC-009**: Auto-hide mechanism (3+ reports) achieves 80% or higher accuracy: comments that are auto-hidden are confirmed as policy violations upon moderator review (false positive rate <20%)

#### Content Quality

- **SC-010**: Zero spam comments reach the feed (profanity filter intercepts 100% of profane submissions before save)
- **SC-011**: 100% of comment notifications are delivered to recipients within 1 minute of the triggering action (comment posted or reply sent)
- **SC-012**: Like/unlike optimistic UI has error rate <0.5% (less than 1 in 200 like actions require rollback due to server errors)

#### Performance & Reliability

- **SC-013**: Comments list loads initial 20 comments in under 1 second for 95% of users on 4G connection (p95 latency <1s)
- **SC-014**: Real-time comment updates appear on other users' screens within 500ms for 95% of updates (p95 real-time latency <500ms)
- **SC-015**: Comments UI maintains 60fps sustained scroll performance for lists up to 100 comments (measured via Flutter DevTools performance overlay, zero jank frames >16ms)
- **SC-016**: Like button responds within 200ms perceived time for 99% of taps (optimistic UI, p99 <200ms)

#### User Satisfaction

- **SC-017**: Post-launch survey shows 80% or more of users rate the comment system as "helpful" or "very helpful" for event coordination
- **SC-018**: Task completion rate: 85% or more of users successfully post their first comment without errors or confusion on first attempt
- **SC-019**: Students report feeling "safe" to participate in discussions: 90% or more agree with statement "I feel comments are monitored for inappropriate content" in safety survey

#### Business Impact

- **SC-020**: Events with comments enabled see 25% higher participation rate compared to events with comments disabled (A/B test control group)
- **SC-021**: Average session duration increases by 15% or more for users who engage with comments vs. users who only view events
- **SC-022**: Support tickets related to "how do I ask questions about events" decrease by 60% or more after comments launch (reduced need for external communication channels)
