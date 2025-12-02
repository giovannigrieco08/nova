# Supabase API Specification: Event Comments

**Feature**: Event Comments System
**Branch**: `007-event-comments`
**Created**: 2025-01-22
**Phase**: Phase 1 (API Contracts)

## Overview

This document specifies the concrete Supabase client API calls used by the comments remote data source. All calls assume authenticated user context via Supabase Auth (`auth.uid()`).

---

## Configuration

### Supabase Client Initialization

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;
```

### Environment Variables

```env
SUPABASE_URL=https://jhnxscorszeslkhnxtif.supabase.co
SUPABASE_ANON_KEY=eyJhbGc... (public anon key)
```

---

## API Endpoints (Table Operations)

### 1. Fetch Top-Level Comments for Event

**Method**: `GET` (via Supabase client `select()`)

**Supabase Call**:
```dart
final response = await supabase
  .from('comments')
  .select('''
    *,
    author:profiles!user_id (
      id,
      name,
      avatar_url,
      class,
      role
    )
  ''')
  .eq('event_id', eventId)
  .is_('parent_comment_id', null) // Top-level only
  .is_('deleted_at', null) // Not deleted
  .is_('hidden_at', null) // Not hidden
  .order('created_at', ascending: false)
  .limit(limit)
  .lt('created_at', cursorCreatedAt?.toIso8601String()); // Cursor pagination

final comments = (response as List)
  .map((json) => CommentModel.fromJson(json))
  .toList();
```

**Response Format** (single comment JSON):
```json
{
  "id": "uuid",
  "event_id": "uuid",
  "user_id": "uuid",
  "parent_comment_id": null,
  "text": "Ci sono ancora posti?",
  "like_count": 3,
  "reply_count": 1,
  "report_count": 0,
  "deleted_at": null,
  "hidden_at": null,
  "created_at": "2025-01-22T14:30:00Z",
  "updated_at": null,
  "author": {
    "id": "uuid",
    "name": "Marco Rossi",
    "avatar_url": "https://...",
    "class": "5A",
    "role": "student"
  }
}
```

**RLS Policy Applied**: `Students view approved event comments`

---

### 2. Fetch Replies for Comment

**Method**: `GET`

**Supabase Call**:
```dart
final response = await supabase
  .from('comments')
  .select('''
    *,
    author:profiles!user_id (
      id,
      name,
      avatar_url,
      class,
      role
    )
  ''')
  .eq('parent_comment_id', commentId)
  .is_('deleted_at', null)
  .is_('hidden_at', null)
  .order('created_at', ascending: true); // Oldest replies first

final replies = (response as List)
  .map((json) => CommentModel.fromJson(json))
  .toList();
```

**RLS Policy Applied**: `Students view approved event comments`

---

### 3. Check if User Liked Comment

**Method**: `GET`

**Supabase Call**:
```dart
final response = await supabase
  .from('comment_likes')
  .select('comment_id')
  .eq('comment_id', commentId)
  .eq('user_id', currentUserId)
  .is_('deleted_at', null)
  .limit(1);

final isLiked = (response as List).isNotEmpty;
```

**Response Format**:
```json
[
  { "comment_id": "uuid" }
]
```

**RLS Policy Applied**: `Users view comment likes`

---

### 4. Post New Comment

**Method**: `POST` (via Supabase client `insert()`)

**Supabase Call**:
```dart
final response = await supabase
  .from('comments')
  .insert({
    'event_id': eventId,
    'user_id': currentUserId, // Injected by RLS policy check
    'parent_comment_id': parentCommentId, // null for top-level
    'text': text.trim(),
  })
  .select('''
    *,
    author:profiles!user_id (
      id,
      name,
      avatar_url,
      class,
      role
    )
  ''')
  .single();

final comment = CommentModel.fromJson(response);
```

**Request Body**:
```json
{
  "event_id": "uuid",
  "parent_comment_id": null,
  "text": "Quando inizia?"
}
```

**Response Format**: Same as fetch response (single comment with joined author)

**Triggers Executed**:
1. `check_profanity_on_insert`: Validates text against Italian profanity list
2. `prevent_comment_spam`: Checks rate limit (3 identical in 5 min)
3. `sync_comment_reply_count`: Increments `reply_count` on parent if reply
4. `sync_event_comment_count`: Increments `comment_count` on event

**Possible Errors**:
- `23514`: CHECK constraint violation (profanity filter)
  ```json
  {
    "code": "23514",
    "message": "Comment contains inappropriate language"
  }
  ```
- `P0001`: Rate limit exceeded (custom PostgreSQL exception)
  ```json
  {
    "code": "P0001",
    "message": "Rate limit exceeded: max 3 identical comments in 5 minutes"
  }
  ```
- `23503`: Foreign key violation (event or parent comment not found)

**RLS Policy Applied**: `Students insert comments`

---

### 5. Like Comment

**Method**: `POST`

**Supabase Call**:
```dart
try {
  await supabase
    .from('comment_likes')
    .insert({
      'comment_id': commentId,
      'user_id': currentUserId,
    })
    .select()
    .single();
} on PostgrestException catch (e) {
  if (e.code == '23505') {
    // Duplicate like (idempotent - ignore)
    return;
  }
  rethrow;
}
```

**Request Body**:
```json
{
  "comment_id": "uuid",
  "user_id": "uuid"
}
```

**Response Format**:
```json
{
  "comment_id": "uuid",
  "user_id": "uuid",
  "created_at": "2025-01-22T14:35:00Z",
  "deleted_at": null
}
```

**Triggers Executed**:
1. `prevent_like_spam`: Checks rate limit (100 likes/hour)
2. `sync_comment_like_count`: Increments `like_count` on comment

**Possible Errors**:
- `23505`: Unique constraint violation (duplicate like - expected, ignore)
- `P0001`: Rate limit exceeded (100 likes/hour)

**RLS Policy Applied**: `Users like comments`

---

### 6. Unlike Comment

**Method**: `DELETE`

**Supabase Call**:
```dart
await supabase
  .from('comment_likes')
  .delete()
  .eq('comment_id', commentId)
  .eq('user_id', currentUserId);
```

**Triggers Executed**:
1. `sync_comment_like_count`: Decrements `like_count` on comment

**RLS Policy Applied**: `Users unlike comments`

---

### 7. Edit Comment

**Method**: `PATCH` (via Supabase client `update()`)

**Supabase Call**:
```dart
final response = await supabase
  .from('comments')
  .update({
    'text': newText.trim(),
    'updated_at': DateTime.now().toIso8601String(),
  })
  .eq('id', commentId)
  .eq('user_id', currentUserId) // Ensure ownership
  .gte('created_at', DateTime.now().subtract(Duration(minutes: 5)).toIso8601String()) // 5-min window
  .select('''
    *,
    author:profiles!user_id (
      id,
      name,
      avatar_url,
      class,
      role
    )
  ''')
  .single();

final updatedComment = CommentModel.fromJson(response);
```

**Request Body**:
```json
{
  "text": "Quando inizia esattamente?",
  "updated_at": "2025-01-22T14:40:00Z"
}
```

**Triggers Executed**:
1. `check_profanity_on_update`: Validates new text

**Possible Errors**:
- `23514`: Profanity filter violation
- `PGRST116`: No rows updated (comment not found, not owned, or edit window expired)

**RLS Policy Applied**: `Users edit own recent comments`

---

### 8. Soft Delete Comment

**Method**: `PATCH`

**Supabase Call**:
```dart
await supabase
  .from('comments')
  .update({
    'text': '[Commento eliminato]',
    'deleted_at': DateTime.now().toIso8601String(),
    'deleted_by_user_id': currentUserId,
  })
  .eq('id', commentId)
  .eq('user_id', currentUserId) // Ensure ownership
  .is_('deleted_at', null); // Not already deleted
```

**Request Body**:
```json
{
  "text": "[Commento eliminato]",
  "deleted_at": "2025-01-22T14:45:00Z",
  "deleted_by_user_id": "uuid"
}
```

**Triggers Executed**:
1. `sync_comment_reply_count`: Decrements parent's `reply_count` if reply
2. `sync_event_comment_count`: Decrements event's `comment_count` if top-level

**RLS Policy Applied**: `Users delete own comments`

---

### 9. Report Comment

**Method**: `POST`

**Supabase Call**:
```dart
try {
  final response = await supabase
    .from('comment_reports')
    .insert({
      'comment_id': commentId,
      'reporter_user_id': currentUserId,
      'reason': reason.value, // 'spam', 'inappropriate', 'bullying', 'off_topic'
      'details': details?.trim(),
    })
    .select()
    .single();

  return CommentReportModel.fromJson(response);
} on PostgrestException catch (e) {
  if (e.code == '23505') {
    // Duplicate report (user already reported this comment)
    throw ConflictException('Hai già segnalato questo commento');
  }
  rethrow;
}
```

**Request Body**:
```json
{
  "comment_id": "uuid",
  "reporter_user_id": "uuid",
  "reason": "spam",
  "details": "Pubblicizza eventi esterni alla scuola"
}
```

**Response Format**:
```json
{
  "id": "uuid",
  "comment_id": "uuid",
  "reporter_user_id": "uuid",
  "reason": "spam",
  "details": "Pubblicizza eventi esterni alla scuola",
  "status": "pending",
  "created_at": "2025-01-22T14:50:00Z"
}
```

**Triggers Executed**:
1. `sync_comment_report_count`: Increments `report_count` on comment
2. Auto-hide logic: If `report_count >= 3`, sets `hidden_at = NOW()`, `hidden_reason = 'auto_hide_reports'`

**Possible Errors**:
- `23505`: Unique constraint violation (duplicate report from same user)

**RLS Policy Applied**: `Users submit reports`

---

### 10. Moderator Remove Comment

**Method**: `PATCH`

**Supabase Call**:
```dart
await supabase
  .from('comments')
  .update({
    'hidden_at': DateTime.now().toIso8601String(),
    'hidden_reason': 'moderator_removed',
    'moderator_id': currentUserId,
  })
  .eq('id', commentId);
```

**Request Body**:
```json
{
  "hidden_at": "2025-01-22T15:00:00Z",
  "hidden_reason": "moderator_removed",
  "moderator_id": "uuid"
}
```

**RLS Policy Applied**: `Moderators remove comments` (requires `profiles.role = 'moderator'`)

---

### 11. Moderator Restore Comment

**Method**: `PATCH`

**Supabase Call**:
```dart
await supabase
  .from('comments')
  .update({
    'hidden_at': null,
    'hidden_reason': null,
  })
  .eq('id', commentId)
  .not('hidden_at', 'is', null); // Ensure comment was hidden
```

**Request Body**:
```json
{
  "hidden_at": null,
  "hidden_reason": null
}
```

**RLS Policy Applied**: `Moderators remove comments`

---

## Real-Time Subscriptions

### Subscribe to Event Comments

**Method**: WebSocket (Supabase Realtime)

**Supabase Call**:
```dart
final subscription = supabase
  .from('comments')
  .stream(primaryKey: ['id'])
  .eq('event_id', eventId)
  .eq('parent_comment_id', null) // Top-level only
  .order('created_at')
  .listen((List<Map<String, dynamic>> data) {
    final comments = data.map((json) => CommentModel.fromJson(json)).toList();
    // Update Riverpod state
    ref.read(commentsNotifierProvider.notifier).updateFromRealtime(comments);
  });

// Dispose when done
subscription.cancel();
```

**Real-Time Events Received**:
- `INSERT`: New comment posted
- `UPDATE`: Comment edited, liked/unliked (counter updated), or hidden
- `DELETE`: Comment hard-deleted (GDPR cleanup - rare)

**Payload Format** (same as SELECT response):
```json
{
  "eventType": "INSERT",
  "new": {
    "id": "uuid",
    "event_id": "uuid",
    "text": "Nuovo commento!",
    "like_count": 0,
    "created_at": "2025-01-22T15:05:00Z",
    ...
  },
  "old": null
}
```

**Note**: Real-time subscriptions require RLS policies to pass. Students only receive events for comments they can SELECT (approved events, non-hidden comments).

---

## Error Handling

### Supabase Error Codes

| Error Code | Meaning | Client Handling |
|-----------|---------|----------------|
| `23505` | Unique constraint violation | Idempotent operations (like, report) - ignore |
| `23503` | Foreign key violation | Throw `NotFoundException` (parent not found) |
| `23514` | CHECK constraint violation | Throw `ValidationException` (profanity, rate limit) |
| `P0001` | Custom PostgreSQL exception | Parse message for rate limit details |
| `PGRST116` | No rows returned/updated | Throw `NotFoundException` or `ForbiddenException` |
| `401` | Unauthorized | Throw `UnauthorizedException` (not logged in) |
| `403` | Forbidden | Throw `ForbiddenException` (RLS policy failed) |
| `500`-`599` | Server error | Throw `ServerException` |

### Error Transformation Example

```dart
try {
  final response = await supabase.from('comments').insert({...});
} on PostgrestException catch (e) {
  if (e.code == '23514') {
    throw ValidationException('Testo non valido', {'text': 'Contiene linguaggio inappropriato'});
  } else if (e.code == 'P0001' && e.message.contains('rate limit')) {
    throw RateLimitException('Limite superato', Duration(minutes: 5));
  } else if (e.code == '23503') {
    throw NotFoundException('Commento o evento non trovato');
  } else {
    throw ServerException('Errore del server: ${e.message}');
  }
} on SocketException catch (e) {
  throw NetworkException('Connessione assente');
}
```

---

## Performance Optimizations

### 1. Batch Fetch Replies

When loading top-level comments, batch-fetch all replies in a single query:

```dart
// Step 1: Fetch top-level comments
final topLevelComments = await _fetchTopLevelComments(eventId);

// Step 2: Extract parent IDs
final parentIds = topLevelComments.map((c) => c.id).toList();

// Step 3: Batch fetch all replies
final allReplies = await supabase
  .from('comments')
  .select('*, author:profiles!user_id(*)')
  .in_('parent_comment_id', parentIds)
  .order('created_at');

// Step 4: Group replies by parent
final repliesByParent = <String, List<Comment>>{};
for (final reply in allReplies) {
  final parentId = reply['parent_comment_id'];
  repliesByParent.putIfAbsent(parentId, () => []).add(CommentModel.fromJson(reply).toEntity());
}

// Step 5: Attach replies to parents
final commentsWithReplies = topLevelComments.map((comment) {
  return comment.copyWith(replies: repliesByParent[comment.id] ?? []);
}).toList();
```

**Rationale**: Avoids N+1 query problem (1 query for top-level + 1 query for all replies, instead of 1+N queries).

---

### 2. Denormalized Counters

Leverage denormalized `like_count`, `reply_count`, `report_count` fields to avoid COUNT(*) queries:

```dart
// ✅ FAST - Uses denormalized counter
final comment = await supabase.from('comments').select('*, like_count').single();
print('Likes: ${comment['like_count']}');

// ❌ SLOW - Counts rows every time
final likes = await supabase.from('comment_likes').select('*', count: CountOption.exact).eq('comment_id', commentId);
print('Likes: ${likes.count}');
```

**Trade-off**: Counters updated via triggers (slight write overhead), but read performance is O(1).

---

### 3. Index-Only Scans

Queries using indexed columns (`event_id`, `parent_comment_id`, `created_at`) with WHERE filters benefit from index-only scans:

```sql
-- Uses idx_comments_event_top_level (index-only scan)
EXPLAIN SELECT * FROM comments
WHERE event_id = 'uuid'
  AND parent_comment_id IS NULL
  AND deleted_at IS NULL
ORDER BY created_at DESC
LIMIT 20;

-- Output: Index Scan using idx_comments_event_top_level (cost=0.42..8.45)
```

---

## Testing Checklist

### Unit Tests (Data Source)

- [ ] `postComment` with valid text returns created comment
- [ ] `postComment` with profanity throws `ValidationException`
- [ ] `postComment` with rate limit exceeded throws `RateLimitException`
- [ ] `likeComment` increments like_count
- [ ] `likeComment` twice is idempotent (no duplicate)
- [ ] `unlikeComment` decrements like_count
- [ ] `reportComment` with 3rd report auto-hides comment
- [ ] `editComment` within 5 min succeeds
- [ ] `editComment` after 5 min throws `ForbiddenException`
- [ ] `deleteComment` replaces text with "[Commento eliminato]"
- [ ] `subscribeToComments` emits real-time updates

### Integration Tests

- [ ] Full flow: Post comment → Like → Reply → Report → Moderator remove
- [ ] Pagination: Load 20 comments → Scroll → Load next 20
- [ ] Offline: Post comment offline → Queue → Sync when online
- [ ] Real-time: User A posts → User B sees update instantly

---

**Status**: ✅ Supabase API Specification Complete
**Next**: Quickstart Guide (Integration & Testing Scenarios)
