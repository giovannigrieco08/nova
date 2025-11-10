# Supabase Query Patterns: Events Feed

**Feature**: 003-events-feed
**Date**: 2025-01-02
**Purpose**: Document all Supabase query patterns (SELECT, INSERT, UPDATE, DELETE) for events feed operations.

---

## Query 1: Fetch Paginated Events Feed

**Purpose**: Load upcoming approved events with creator info for infinite scroll feed (20 events per page).

**Requirements**: FR-001, FR-002, FR-003, FR-003a

```dart
// Dart (Flutter)
Future<List<EventModel>> fetchEventsFeed({int page = 1, int limit = 20}) async {
  final offset = (page - 1) * limit;

  final response = await supabase
      .from('events')
      .select('''
        *,
        creator:users!creator_id(id, name, avatar_url, class)
      ''')
      .eq('status', 'approved')
      .gte('event_date', 'current_date')
      .order('created_at', ascending: false)
      .range(offset, offset + limit - 1);

  return (response as List)
      .map((json) => EventModel.fromJson(json))
      .toList();
}
```

**SQL Equivalent**:

```sql
SELECT
  events.*,
  jsonb_build_object(
    'id', users.id,
    'name', users.name,
    'avatar_url', users.avatar_url,
    'class', users.class
  ) AS creator
FROM events
LEFT JOIN users ON events.creator_id = users.id
WHERE events.status = 'approved'
  AND events.event_date >= CURRENT_DATE
ORDER BY events.created_at DESC
LIMIT 20 OFFSET 0;
```

**Performance Notes**:
- Uses composite index `idx_events_date_status(event_date, status)`
- Query plan: Index Scan → Join (cheap due to small result set)

---

## Query 2: Fetch Single Event with Full Details

**Purpose**: Load event detail screen with creator info, counts (likes, participants, comments).

**Requirements**: FR-011

```dart
// Dart (Flutter)
Future<EventModel> fetchEventDetails(String eventId) async {
  final response = await supabase
      .from('events')
      .select('''
        *,
        creator:users!creator_id(id, name, avatar_url, class),
        like_count:likes(count),
        participant_count:participations(count),
        comment_count:comments(count)
      ''')
      .eq('id', eventId)
      .single();

  return EventModel.fromJson(response);
}
```

**SQL Equivalent**:

```sql
SELECT
  events.*,
  jsonb_build_object(
    'id', users.id,
    'name', users.name,
    'avatar_url', users.avatar_url,
    'class', users.class
  ) AS creator,
  (SELECT COUNT(*) FROM likes WHERE likes.event_id = events.id) AS like_count,
  (SELECT COUNT(*) FROM participations WHERE participations.event_id = events.id) AS participant_count,
  (SELECT COUNT(*) FROM comments WHERE comments.event_id = events.id) AS comment_count
FROM events
LEFT JOIN users ON events.creator_id = users.id
WHERE events.id = $1;
```

---

## Query 3: Check if User Liked Event

**Purpose**: Determine like button state (liked vs not liked).

**Requirements**: FR-015

```dart
// Dart (Flutter)
Future<bool> isEventLiked(String eventId, String userId) async {
  final response = await supabase
      .from('likes')
      .select('user_id')
      .eq('event_id', eventId)
      .eq('user_id', userId)
      .maybeSingle();

  return response != null;
}
```

**SQL Equivalent**:

```sql
SELECT EXISTS (
  SELECT 1 FROM likes
  WHERE event_id = $1 AND user_id = $2
) AS is_liked;
```

---

## Query 4: Like Event (Optimistic UI)

**Purpose**: Insert like record (idempotent - fails silently if already liked due to composite PK).

**Requirements**: FR-016, FR-019

```dart
// Dart (Flutter)
Future<void> likeEvent(String eventId, String userId) async {
  await supabase.from('likes').insert({
    'event_id': eventId,
    'user_id': userId,
  });
}
```

**SQL Equivalent**:

```sql
INSERT INTO likes (event_id, user_id)
VALUES ($1, $2)
ON CONFLICT (event_id, user_id) DO NOTHING;  -- Idempotent
```

**Error Handling**:
- 409 Conflict: User already liked (ignored by optimistic UI)
- 403 Forbidden: Event not approved or doesn't exist (RLS blocks insert)

---

## Query 5: Unlike Event (Optimistic UI)

**Purpose**: Delete like record.

**Requirements**: FR-017

```dart
// Dart (Flutter)
Future<void> unlikeEvent(String eventId, String userId) async {
  await supabase
      .from('likes')
      .delete()
      .eq('event_id', eventId)
      .eq('user_id', userId);
}
```

**SQL Equivalent**:

```sql
DELETE FROM likes
WHERE event_id = $1 AND user_id = $2;
```

---

## Query 6: Participate in Event (Optimistic UI)

**Purpose**: Insert participation record (RSVP).

**Requirements**: FR-022

```dart
// Dart (Flutter)
Future<void> participateInEvent(String eventId, String userId) async {
  await supabase.from('participations').insert({
    'event_id': eventId,
    'user_id': userId,
  });
}
```

**SQL Equivalent**:

```sql
INSERT INTO participations (event_id, user_id)
VALUES ($1, $2)
ON CONFLICT (event_id, user_id) DO NOTHING;  -- Idempotent
```

**Capacity Check (Client-Side)**:

```dart
// Check capacity before insert (if event has capacity limit)
Future<void> participateWithCapacityCheck(String eventId, String userId) async {
  final event = await fetchEventDetails(eventId);

  if (event.capacity != null) {
    final currentCount = event.participantCount;
    if (currentCount >= event.capacity!) {
      throw Exception('Event is full');
    }
  }

  await participateInEvent(eventId, userId);
}
```

---

## Query 7: Unparticipate from Event (Optimistic UI)

**Purpose**: Delete participation record.

**Requirements**: FR-023

```dart
// Dart (Flutter)
Future<void> unparticipateFromEvent(String eventId, String userId) async {
  await supabase
      .from('participations')
      .delete()
      .eq('event_id', eventId)
      .eq('user_id', userId);
}
```

**SQL Equivalent**:

```sql
DELETE FROM participations
WHERE event_id = $1 AND user_id = $2;
```

---

## Query 8: Fetch Comments for Event

**Purpose**: Load comments with author info for detail screen (chronological order, oldest first).

**Requirements**: FR-027, FR-028

```dart
// Dart (Flutter)
Future<List<CommentModel>> fetchComments(String eventId, {int limit = 50}) async {
  final response = await supabase
      .from('comments')
      .select('''
        *,
        author:users!author_id(id, name, avatar_url, class)
      ''')
      .eq('event_id', eventId)
      .order('created_at', ascending: true)  // Oldest first (FR-027)
      .limit(limit);

  return (response as List)
      .map((json) => CommentModel.fromJson(json))
      .toList();
}
```

**SQL Equivalent**:

```sql
SELECT
  comments.*,
  jsonb_build_object(
    'id', users.id,
    'name', users.name,
    'avatar_url', users.avatar_url,
    'class', users.class
  ) AS author
FROM comments
LEFT JOIN users ON comments.author_id = users.id
WHERE comments.event_id = $1
ORDER BY comments.created_at ASC
LIMIT 50;
```

---

## Query 9: Post Comment (Optimistic UI)

**Purpose**: Insert comment with 500 character validation.

**Requirements**: FR-029, FR-029a, FR-030

```dart
// Dart (Flutter)
Future<CommentModel> postComment(String eventId, String userId, String text) async {
  // Client-side validation (FR-029a)
  if (text.trim().isEmpty || text.length > 500) {
    throw Exception('Comment must be 1-500 characters');
  }

  final response = await supabase
      .from('comments')
      .insert({
        'event_id': eventId,
        'author_id': userId,
        'text': text.trim(),
      })
      .select('''
        *,
        author:users!author_id(id, name, avatar_url, class)
      ''')
      .single();

  return CommentModel.fromJson(response);
}
```

**SQL Equivalent**:

```sql
INSERT INTO comments (event_id, author_id, text)
VALUES ($1, $2, $3)
RETURNING
  comments.*,
  jsonb_build_object(
    'id', users.id,
    'name', users.name,
    'avatar_url', users.avatar_url,
    'class', users.class
  ) AS author
FROM users
WHERE users.id = comments.author_id;
```

**Validation**:
- Client: Text length 1-500 chars (FR-029c)
- Server: VARCHAR(500) constraint + CHECK (length(trim(text)) > 0)

---

## Query 10: Fetch Participants with Avatars

**Purpose**: Load participant list for detail screen (up to 5 avatars shown, rest in modal).

**Requirements**: FR-013

```dart
// Dart (Flutter)
Future<List<UserProfile>> fetchParticipants(String eventId, {int limit = 5}) async {
  final response = await supabase
      .from('participations')
      .select('''
        user:users!user_id(id, name, avatar_url, class)
      ''')
      .eq('event_id', eventId)
      .order('created_at', ascending: false)  // Most recent participants first
      .limit(limit);

  return (response as List)
      .map((json) => UserProfile.fromJson(json['user']))
      .toList();
}
```

**SQL Equivalent**:

```sql
SELECT
  jsonb_build_object(
    'id', users.id,
    'name', users.name,
    'avatar_url', users.avatar_url,
    'class', users.class
  ) AS user
FROM participations
LEFT JOIN users ON participations.user_id = users.id
WHERE participations.event_id = $1
ORDER BY participations.created_at DESC
LIMIT 5;
```

---

## Query 11: Update Event (Creator Only)

**Purpose**: Edit event details (text fields only, images display-only).

**Requirements**: FR-036, FR-037

```dart
// Dart (Flutter)
Future<EventModel> updateEvent(String eventId, {
  String? title,
  String? description,
  DateTime? eventDate,
  String? eventTime,
  String? location,
}) async {
  final updates = <String, dynamic>{};
  if (title != null) updates['title'] = title;
  if (description != null) updates['description'] = description;
  if (eventDate != null) updates['event_date'] = eventDate.toIso8601String().split('T')[0];
  if (eventTime != null) updates['event_time'] = eventTime;
  if (location != null) updates['location'] = location;

  final response = await supabase
      .from('events')
      .update(updates)
      .eq('id', eventId)
      .select()
      .single();

  return EventModel.fromJson(response);
}
```

**SQL Equivalent**:

```sql
UPDATE events
SET
  title = COALESCE($2, title),
  description = COALESCE($3, description),
  event_date = COALESCE($4, event_date),
  event_time = COALESCE($5, event_time),
  location = COALESCE($6, location),
  updated_at = NOW()
WHERE id = $1
  AND creator_id = auth.uid()  -- RLS enforces creator-only access
RETURNING *;
```

---

## Query 12: Delete Event (Creator Only)

**Purpose**: Permanently delete event and all related data (likes, comments, participations cascade).

**Requirements**: FR-043

```dart
// Dart (Flutter)
Future<void> deleteEvent(String eventId) async {
  await supabase
      .from('events')
      .delete()
      .eq('id', eventId);
}
```

**SQL Equivalent**:

```sql
DELETE FROM events
WHERE id = $1
  AND creator_id = auth.uid();  -- RLS enforces creator-only access
```

**Cascade Behavior**:
- Deletes all associated likes (ON DELETE CASCADE)
- Deletes all associated participations (ON DELETE CASCADE)
- Deletes all associated comments (ON DELETE CASCADE)
- Deletes all associated reports (ON DELETE CASCADE)

---

## Query 13: Submit Report

**Purpose**: Report inappropriate event content to moderation queue.

**Requirements**: FR-049

```dart
// Dart (Flutter)
Future<void> submitReport(
  String eventId,
  String userId,
  String reason,
  String explanation,
) async {
  await supabase.from('reports').insert({
    'event_id': eventId,
    'reporter_id': userId,
    'reason': reason,  // 'inappropriate', 'spam', 'harassment', 'other'
    'explanation': explanation,
  });
}
```

**SQL Equivalent**:

```sql
INSERT INTO reports (event_id, reporter_id, reason, explanation)
VALUES ($1, $2, $3, $4);
```

**Validation**:
- Reason must be one of: 'inappropriate', 'spam', 'harassment', 'other'
- Explanation is required (NOT NULL)

---

## Query Performance Summary

| Query | Expected Latency (p95) | Indexes Used | Notes |
|-------|------------------------|--------------|-------|
| Fetch Feed (20 events) | <300ms (4G) | `idx_events_date_status`, `idx_events_created_at` | Hot path - most critical query |
| Fetch Event Details | <200ms | Primary key lookup | Single event by ID |
| Like/Unlike | <100ms | `idx_likes_event_id`, `idx_likes_user_id` | Simple insert/delete |
| Participate/Unparticipate | <100ms | `idx_participations_event_id`, `idx_participations_user_id` | Simple insert/delete |
| Fetch Comments | <200ms | `idx_comments_event_id` | Up to 50 comments, rarely paginated |
| Post Comment | <150ms | Single insert | Returns with author join |
| Update Event | <150ms | Primary key lookup + RLS check | Creator-only |
| Delete Event | <200ms | Cascade deletes (fast due to indexes on foreign keys) | Creator-only |

**Overall Target**: API response time p95 <500ms (FR-060)

---

**Supabase Queries Status**: ✅ Complete - All 13 query patterns documented
