# Feature Specification: Admin Panel & Moderation Queue

**Feature Branch**: `005-moderation-admin-panel`
**Created**: 2025-11-12
**Status**: Draft
**Input**: User description: "Implementa un sistema completo di moderazione eventi con Admin Panel per Nova. Sistema con 3 ruoli utente (studenti, moderatori, admin), moderation queue per approvare/rifiutare eventi pending, admin panel per gestire moderatori, statistiche complete, real-time updates, audit logging, e notifiche push per tutti i workflow di approvazione/rifiuto."

## Clarifications

### Session 2025-11-12

- Q: When a student re-submits a rejected event, which fields can they edit? → A: Only description editable (other fields locked to prevent event identity changes)
- Q: Should moderators receive push notifications when a new event enters the moderation queue? → A: No - Only badge update (prevents notification fatigue for high-volume periods)
- Q: How should "average review time" be calculated for the Admin Panel statistics (FR-046)? → A: Rolling 7-day average of (moderated_at - created_at) for events moderated in last 7 days (reflects current team performance)
- Q: Does the moderation queue badge count (FR-021) show ALL pending events or only events not yet viewed by the current moderator? → A: Total count of ALL pending events (simpler implementation, all moderators see same number, aligns with system-wide metrics)
- Q: What should happen if Supabase Realtime subscription fails or consistently exceeds the 2-second latency requirement? → A: Hybrid fallback - automatically switch to 15-second polling with subtle warning indicator (yellow dot), retry Realtime connection every 45 seconds in background

## User Scenarios & Testing

### User Story 1 - Basic Event Moderation Flow (Priority: P1)

A moderator reviews and approves/rejects pending events submitted by students. This is the core value proposition - ensuring all events are vetted before appearing in the public feed.

**Why this priority**: This is the most critical functionality that delivers immediate value. Without event moderation, the entire system cannot function as intended (protecting the community from inappropriate content).

**Independent Test**: Can be fully tested by creating a test event, logging in as a moderator, viewing it in the queue, and approving/rejecting it. Delivers the core value of content moderation.

**Acceptance Scenarios**:

1. **Given** Marco (student) creates event "Torneo Basket 3v3" with valid details, **When** system saves the event, **Then** event status is "pending" and Marco sees "In attesa di approvazione ⏳" message in his profile
2. **Given** Sofia (moderator) opens the moderation dashboard, **When** there is 1 pending event, **Then** she sees a badge [1] on the Moderazione tab and the event appears in the queue showing emoji/image, title, description preview, organizer, date/time, location, and timestamp
3. **Given** Sofia views event details in queue, **When** she clicks "Approva", **Then** event status changes to "approved", event appears in public feed for all users, Marco receives notification "✅ Il tuo evento 'Torneo Basket 3v3' è stato approvato!", and moderation action is logged with moderator_id and timestamp
4. **Given** Sofia views event "Festa Halloween" with inappropriate language, **When** she clicks "Rifiuta" and provides reason "Contenuto inappropriato - Modifica la descrizione", **Then** event status changes to "rejected", only Marco can see it, Marco receives notification "❌ Il tuo evento 'Festa Halloween' è stato rifiutato. Motivo: Contenuto inappropriato - Modifica la descrizione", and rejection is logged
5. **Given** new event becomes pending while Sofia has dashboard open, **When** system detects change, **Then** dashboard updates automatically within 2 seconds showing new event and badge count increments

---

### User Story 2 - Moderator Management by Admin (Priority: P2)

An admin promotes students to moderators, removes moderator roles, and monitors moderator activity to ensure effective content moderation at scale.

**Why this priority**: Essential for scaling moderation beyond the initial admin. Without ability to add/remove moderators, the system cannot grow to handle 810 students.

**Independent Test**: Can be tested independently by logging in as admin, searching for a student, promoting them to moderator, and verifying they gain access to moderation queue. Delivers value of distributed moderation.

**Acceptance Scenarios**:

1. **Given** admin opens Admin Panel, **When** he searches for "Luca Verdi" in search bar, **Then** system displays student card with name, class, email, date of registration, and "Promuovi a Moderatore" button
2. **Given** admin views Luca's card, **When** he clicks "Promuovi a Moderatore" and confirms dialog "Luca Verdi (3A) diventerà moderatore e potrà approvare/rifiutare eventi", **Then** system updates Luca's role to 'moderator', saves promoted_by and promotion timestamp, creates admin_log entry, sends notification "🛡️ Sei stato nominato moderatore Nova!" to Luca, and card updates to show 🛡️ icon with initial statistics (0 reviews)
3. **Given** Luca has moderator role and receives notification, **When** he opens the app, **Then** he sees new "Moderazione" tab (5th tab in bottom navigation) and can access moderation queue
4. **Given** admin sees alert "Anna Ferrari inattiva da 7 giorni", **When** he clicks "Rimuovi Ruolo" and confirms "Anna perderà accesso dashboard moderazione. Statistiche archiviate.", **Then** system updates Anna's role to 'student', archives her statistics, creates admin_log entry, sends notification to Anna, and if Anna has app open the Moderazione tab disappears automatically
5. **Given** admin views moderator list, **When** any moderator is inactive for >7 days, **Then** system displays inactivity alert next to that moderator's card

---

### User Story 3 - Real-time Statistics and Activity Monitoring (Priority: P2)

Moderators and admins view real-time statistics about moderation activity to understand workload, performance, and system health.

**Why this priority**: Critical for transparency and accountability. Moderators need to see their contribution, and admins need visibility into system performance to identify issues early.

**Independent Test**: Can be tested by performing moderation actions and verifying statistics update immediately. Delivers value of transparency and performance monitoring without requiring full feature set.

**Acceptance Scenarios**:

1. **Given** Sofia (moderator) opens moderation dashboard, **When** she views her personal statistics section, **Then** she sees: reviews completed today, reviews this week, total reviews, approval rate percentage, and last review timestamp
2. **Given** admin opens Admin Panel statistics section, **When** page loads, **Then** he sees: total events (with pending/approved/rejected percentages), total moderators (with active last 7 days vs inactive counts), average review time, count of events pending >24h (highlighted if >0), and current backlog size
3. **Given** Sofia approves an event, **When** approval completes, **Then** her personal statistics update immediately (reviews today +1, total +1, approval rate recalculated) without page refresh
4. **Given** admin views moderator list, **When** he looks at Sofia's card, **Then** he sees: reviews per week average, total reviews, approval rate percentage, and timestamp of last activity
5. **Given** system has events pending >24 hours, **When** admin views statistics, **Then** this metric is highlighted in red/warning color to indicate attention needed

---

### User Story 4 - Admin Activity Log and Audit Trail (Priority: P3)

Admin views complete audit trail of all moderation and administrative actions to ensure accountability and investigate issues.

**Why this priority**: Important for accountability and debugging, but not critical for day-to-day operations. Can be added after core moderation is stable.

**Independent Test**: Can be tested by performing various actions (approve, reject, promote, remove) and verifying they appear in the activity log with correct details.

**Acceptance Scenarios**:

1. **Given** admin opens Admin Panel activity log section, **When** page loads, **Then** he sees real-time stream of moderation actions formatted as: timestamp, actor name, action type (approved/rejected/promoted/removed), and target (event title or user name)
2. **Given** admin views activity log, **When** he applies filter for "rejected" actions, **Then** only rejection actions are displayed, showing moderator name, rejected event title, and rejection reason
3. **Given** Sofia rejects event "Festa Halloween", **When** rejection completes, **Then** new entry appears in admin activity log within 2 seconds showing: "[timestamp] Sofia Rossi rejected event 'Festa Halloween'"
4. **Given** admin promotes Luca to moderator, **When** promotion completes, **Then** new entry appears in log: "[timestamp] Admin promoted Luca Verdi to moderator"
5. **Given** admin wants to review actions from last week, **When** he navigates to past dates in log, **Then** system retrieves and displays historical entries chronologically

---

### User Story 5 - Event Re-submission After Rejection (Priority: P3)

Students edit and re-submit rejected events to address moderator feedback and get another chance at approval.

**Why this priority**: Improves user experience and reduces friction, but core moderation can function without it. Students can create new events as workaround.

**Independent Test**: Can be tested by rejecting an event, logging in as the creator, editing it, and re-submitting. Verifies the feedback loop works.

**Acceptance Scenarios**:

1. **Given** Marco's event "Festa Halloween" was rejected with reason "Modifica la descrizione", **When** Marco opens his profile and views the rejected event, **Then** he sees rejection reason and "Modifica e Ri-sottometti" button
2. **Given** Marco clicks "Modifica e Ri-sottometti", **When** he edits description to remove inappropriate content and submits, **Then** system updates event status back to "pending", clears previous rejection reason, creates new moderation queue entry, and notifies moderators of re-submission
3. **Given** event has been rejected and re-submitted multiple times, **When** system checks submission count, **Then** no limit is enforced - students may re-submit indefinitely (per Assumption #10), but only the description field is editable

---

### Edge Cases

- What happens when a moderator tries to moderate their own event? System should prevent self-moderation and show appropriate message.
- What happens if an event is deleted by creator while it's in pending state in the moderation queue? Moderators should no longer see it in queue, and attempt to moderate it should show "Event no longer exists" error.
- What happens when admin tries to promote someone who is already a moderator? System should show informational message "User is already a moderator" and disable the button.
- What happens when admin tries to remove admin role from themselves? System should prevent this and require at least one admin to exist.
- What happens if multiple moderators try to approve/reject the same event simultaneously? First action should succeed, second should fail with "Event already moderated" message.
- How does system handle moderator who is promoted, moderates events, then role is removed, then promoted again? Previous statistics are restored from archive showing continuity of their moderation history (per Assumption #9).
- What happens when a moderator clicks approve but network fails before save completes? System should show error message and allow retry, event should remain pending.
- What happens to events pending in queue when moderator account is deleted (not just demoted)? Events remain in queue for other moderators, no data loss.

## Requirements

### Functional Requirements

**Role Management & Access Control**

- **FR-001**: System MUST support three distinct user roles: student (default), moderator, and admin
- **FR-002**: System MUST store user role in database and use it to determine UI visibility and data access permissions
- **FR-003**: System MUST implement Row-Level Security (RLS) policies ensuring students can ONLY query approved events (or their own pending/rejected events)
- **FR-004**: System MUST implement RLS policies allowing moderators and admins to query ALL events regardless of status
- **FR-005**: System MUST prevent bypassing role restrictions even when using direct database API calls
- **FR-006**: System MUST conditionally show "Moderazione" tab in bottom navigation only when user role is moderator or admin
- **FR-007**: System MUST conditionally show "Admin" tab in bottom navigation only when user role is admin
- **FR-008**: Admin Panel routes MUST verify role=admin server-side before returning data
- **FR-009**: Moderation Queue routes MUST verify role in (moderator, admin) server-side before returning data

**Event Status Workflow**

- **FR-010**: All newly created events MUST be saved with status = "pending"
- **FR-011**: Event status MUST be one of three values: pending, approved, or rejected
- **FR-012**: System MUST prevent students from directly modifying event status (only moderators/admins can change it)
- **FR-013**: When moderator approves event, system MUST: set status=approved, save moderator_id, save moderation timestamp, create audit log entry
- **FR-014**: When moderator rejects event, system MUST: set status=rejected, save moderator_id, save rejection_reason text, save moderation timestamp, create audit log entry
- **FR-015**: Approved events MUST appear in public feed visible to all users
- **FR-016**: Pending events MUST NOT appear in public feed
- **FR-017**: Rejected events MUST be visible only to their creator and to moderators/admins
- **FR-018**: Students MUST NOT see which specific moderator approved or rejected their event (privacy requirement)

**Moderation Queue Interface**

- **FR-019**: Moderation dashboard MUST display list of all pending events sorted by creation timestamp (oldest first)
- **FR-020**: Each event in queue MUST show: emoji or image, title, description preview (first 150 characters), organizer name, event date/time, location, and submission timestamp
- **FR-021**: Moderation dashboard MUST display badge with total count of ALL pending events in the system on the "Moderazione" navigation tab (all moderators see the same count)
- **FR-022**: Clicking event in queue MUST open full event detail view with all fields
- **FR-023**: Event detail view MUST provide "Approva" and "Rifiuta" action buttons for moderators
- **FR-024**: Clicking "Rifiuta" MUST open dialog requiring moderator to provide rejection reason before confirming
- **FR-025**: Rejection reason dialog MUST include predefined options (Contenuto inappropriato, Informazioni incomplete, Duplicato, Fuori tema) plus custom text field
- **FR-026**: Moderators MUST NOT be able to submit rejection without providing a reason
- **FR-027**: Moderation dashboard MUST update in real-time when new events become pending (within 2 seconds latency)
- **FR-028**: Moderation dashboard MUST update in real-time when events are moderated by other moderators
- **FR-069**: When Supabase Realtime connection fails or drops, system MUST automatically fallback to 15-second polling mode, display subtle warning indicator (yellow dot), and retry Realtime connection every 45 seconds in background

**Moderator Statistics**

- **FR-029**: Moderation dashboard MUST display personal statistics for logged-in moderator: reviews today, reviews this week, total reviews, approval rate percentage
- **FR-030**: Moderator statistics MUST update immediately after each moderation action without requiring page refresh
- **FR-031**: Approval rate MUST be calculated as: (approved events / total moderated events) × 100
- **FR-032**: System MUST track timestamp of moderator's last moderation action for inactivity monitoring

**Admin Panel - Moderator Management**

- **FR-033**: Admin Panel MUST provide search functionality to find any student by name, email, or class
- **FR-034**: Search results MUST display student cards showing: full name, class, email, registration date, current role
- **FR-035**: Student cards MUST show "Promuovi a Moderatore" button when role=student
- **FR-036**: Moderator cards MUST show "Rimuovi Ruolo" button and moderator statistics
- **FR-037**: Clicking "Promuovi a Moderatore" MUST show confirmation dialog: "Luca Verdi (3A) diventerà moderatore e potrà approvare/rifiutare eventi"
- **FR-038**: Confirming promotion MUST: update user role to moderator, save promoted_by admin_id, save promotion timestamp, create admin_log entry, send push notification to user
- **FR-039**: Clicking "Rimuovi Ruolo" MUST show confirmation dialog: "Anna perderà accesso dashboard moderazione. Statistiche archiviate."
- **FR-040**: Confirming role removal MUST: update user role to student, archive moderator statistics, create admin_log entry, send notification to user
- **FR-041**: Admin Panel MUST display list of all active moderators with their statistics: reviews/week, total reviews, approval rate, last activity timestamp
- **FR-042**: System MUST highlight moderators inactive for >7 days with warning indicator
- **FR-043**: When moderator role is removed while they have app open, Moderazione tab MUST disappear automatically via real-time update

**Admin Panel - System Statistics**

- **FR-044**: Admin Panel MUST display total event counts broken down by status: total, pending, approved, rejected (with percentages)
- **FR-045**: Admin Panel MUST display moderator counts: total moderators, active (moderated in last 7 days), inactive
- **FR-046**: Admin Panel MUST display performance metrics: average review time (rolling 7-day average of moderated_at - created_at), events pending >24 hours (with alert if >0), current backlog size
- **FR-047**: System statistics MUST update in real-time as moderation actions occur
- **FR-048**: Events pending >24 hours metric MUST be visually highlighted (red/warning color) when count > 0

**Admin Panel - Activity Log**

- **FR-049**: Admin Panel MUST display real-time activity log stream of all moderation and admin actions
- **FR-050**: Each log entry MUST show: timestamp, actor name, action type (approved/rejected/promoted/removed), target (event title or username)
- **FR-051**: Activity log MUST support filtering by action type
- **FR-052**: Activity log MUST support navigation by date to view historical entries
- **FR-053**: New log entries MUST appear within 2 seconds of action completion via real-time subscription

**Notifications**

- **FR-054**: System MUST send push notification to event creator when event is approved: "✅ Il tuo evento '[title]' è stato approvato!"
- **FR-055**: System MUST send push notification to event creator when event is rejected: "❌ Il tuo evento '[title]' è stato rifiutato. Motivo: [reason]"
- **FR-056**: System MUST send push notification when user is promoted to moderator: "🛡️ Sei stato nominato moderatore Nova!"
- **FR-057**: System MUST send notification when moderator role is removed: "Il tuo ruolo moderatore è stato rimosso"
- **FR-058**: All notifications MUST be delivered even when app is closed (true push notifications, not in-app only)
- **FR-068**: System MUST NOT send push notifications to moderators when new events become pending; real-time badge updates and dashboard refresh provide sufficient notification to avoid notification fatigue

**Audit & Security**

- **FR-059**: System MUST log all moderation actions (approve/reject) with: moderator_id, event_id, action type, timestamp, rejection_reason (if applicable)
- **FR-060**: System MUST log all admin actions (promote/remove moderator) with: admin_id, target_user_id, action type, timestamp
- **FR-061**: Audit logs MUST be immutable (no deletion or modification allowed after creation)
- **FR-062**: System MUST prevent moderators from moderating their own events
- **FR-063**: System MUST prevent concurrent moderation (if moderator A approves while moderator B is viewing, moderator B's action should fail with appropriate error)

**Event Re-submission**

- **FR-064**: Event creators MUST be able to view rejection reason on rejected events in their profile
- **FR-065**: System MUST provide "Modifica e Ri-sottometti" option for rejected events
- **FR-066**: Re-submitting an event MUST: reset status to pending, clear previous rejection reason, maintain original event_id, create new queue entry
- **FR-067**: During re-submission, ONLY the description field can be edited; all other fields (title, emoji, image, event_date, location) remain locked to preserve event identity

### Key Entities

- **User**: Represents any app user. Key attributes: user_id, full_name, email, class, role (enum: student/moderator/admin), registration_date, last_activity_timestamp. A user can create events, and moderators/admins can perform moderation actions.

- **Event**: Represents a school event. Key attributes: event_id, title, description, emoji, image_url, event_date, location, status (enum: pending/approved/rejected), creator_user_id, rejection_reason, created_at, moderated_at, moderator_id. Relationships: created by one User, moderated by one User (if moderated).

- **ModeratorStats**: Tracks performance metrics for each moderator. Key attributes: user_id, total_reviews, reviews_today, reviews_this_week, approval_count, rejection_count, approval_rate_percent, last_review_timestamp. Derived from ModerationLog aggregations.

- **ModerationLog**: Immutable audit trail of moderation actions. Key attributes: log_id, event_id, moderator_user_id, action (enum: approved/rejected), rejection_reason, timestamp. Used for statistics calculation and audit trail.

- **AdminLog**: Immutable audit trail of admin actions. Key attributes: log_id, admin_user_id, target_user_id, action (enum: promoted/removed), timestamp. Used for activity log and accountability.

- **RoleHistory**: Tracks changes to user roles for accountability. Key attributes: history_id, user_id, old_role, new_role, changed_by_user_id, timestamp. Enables restoration of context when users are promoted again.

- **SystemStatistics**: Aggregate view of system health. Key attributes: total_events, pending_count, approved_count, rejected_count, total_moderators, active_moderators_7d, avg_review_time_minutes (rolling 7-day average of moderated_at - created_at), events_pending_over_24h. Calculated via database views, not stored directly.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Moderators can review and approve/reject an event in under 30 seconds (3 taps maximum)
- **SC-002**: Admin can promote a student to moderator in under 20 seconds using search + 2 taps
- **SC-003**: Zero events with status=pending appear in public feed (100% enforcement of moderation workflow)
- **SC-004**: 100% of moderation actions are logged in audit trail with timestamp, actor, and action details
- **SC-005**: Real-time updates appear within 2 seconds of action completion (new pending events, statistics updates, role changes)
- **SC-006**: Dashboard loads in under 1 second with 60fps smooth scrolling even with 50+ pending events
- **SC-007**: Moderator badge count updates instantly when new event becomes pending (no manual refresh required)
- **SC-008**: Event creators receive push notification within 5 seconds of approval/rejection action
- **SC-009**: Admin activity log captures 100% of role changes (promotions and removals) with attribution
- **SC-010**: System correctly prevents self-moderation in 100% of attempts (moderator cannot approve own events)
- **SC-011**: 90% of moderators successfully complete first review without training or assistance
- **SC-012**: Average moderation backlog stays below 10 events during normal school hours

## Assumptions

1. **Push Notification Infrastructure**: Assumes push notification system integration (FCM for Android, APNs for iOS) is already in place or will be implemented as part of this feature. The spec defines notification triggers but not the underlying delivery mechanism.

2. **User Authentication**: Assumes Supabase Auth with magic link is already implemented and all users have authenticated user_id available in session.

3. **Real-time Technology**: Assumes Supabase Realtime subscriptions are used for all real-time updates (moderation queue, statistics, activity log, role changes). No polling-based solutions.

4. **Initial Admin**: Assumes at least one user is manually set to role=admin in the database before system launch to bootstrap the admin panel access.

5. **Event Model**: Assumes events table already exists with fields: event_id, title, description, emoji, image_url, event_date, location, creator_user_id, created_at. This feature adds: status, moderated_at, moderator_id, rejection_reason.

6. **Role Persistence**: Assumes user role is stored in profiles table and persists across sessions. Role changes take effect immediately without requiring logout/login.

7. **Statistics Calculation**: Assumes moderator statistics are calculated using SQL views or aggregations, not client-side computation. Reviews "today" and "this week" use server timezone.

8. **Concurrent Moderation**: Assumes database-level locking or transaction isolation prevents race conditions when multiple moderators try to moderate the same event simultaneously.

9. **Archived Statistics**: When moderator role is removed, statistics are archived (not deleted) in a separate table. If user is re-promoted, statistics are restored from archive showing continuity of their moderation history.

10. **Re-submission Behavior**: Event re-submission creates a new moderation queue entry but maintains the same event_id (it's an update, not a new event). Previous rejection reason is cleared upon re-submission. No limit on number of re-submissions.

11. **Mobile-First UI**: All interfaces are optimized for mobile screens (375px-414px width) as primary platform, with responsive design for larger screens.

12. **Performance Budget**: Assumes backend can handle: 810 students, up to 50 concurrent moderators, 100+ events pending simultaneously, with <1s query response times.

## Dependencies

- Supabase backend with PostgreSQL database
- Supabase Realtime enabled for tables: events, users/profiles, moderation_log, admin_log
- Supabase Row-Level Security (RLS) policies configured for role-based access
- Push notification service integration (FCM/APNs)
- Existing authentication system (Supabase Auth magic link)
- User profiles table with role field

## Out of Scope

The following items are explicitly excluded from this feature and should not be implemented:

- **Appeal System**: Students cannot contest or appeal rejected events. They can only re-submit after editing.
- **Automatic Moderator Rotation**: No automatic scheduling or rotation of moderator duties. Admin handles all assignments manually.
- **Advanced Analytics**: No temporal graphs, charts, or trend analysis of moderation patterns over time.
- **Bulk Actions**: Moderators cannot approve/reject multiple events at once. Each action is individual.
- **Comment Moderation**: This feature only handles event moderation. Comment/chat moderation is separate.
- **Custom In-App Notification UI**: Only push notifications are required. Custom in-app notification center is out of scope.
- **Moderator Training Content**: No built-in tutorials, guidelines, or training materials for new moderators.
- **Event Categories/Tags**: Events have no category system. All events are treated equally in the queue.
- **Priority Queue**: All pending events are first-come-first-served. No priority or escalation system.
- **Moderator Workload Balancing**: No automatic assignment or distribution of moderation tasks among moderators.
