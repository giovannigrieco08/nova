# Comments Repository Interface Contract

**Feature**: Event Comments System
**Branch**: `007-event-comments`
**Created**: 2025-01-22
**Phase**: Phase 1 (API Contracts)

## Overview

This document defines the abstract repository interface for the comments domain. The interface specifies all methods that data layer implementations must provide, ensuring clean architecture separation between domain and data layers.

---

## Interface Definition

### File Location
```
lib/features/comments/domain/repositories/comments_repository_interface.dart
```

---

## Method Signatures

### 1. Query Operations

#### `getCommentsForEvent`

**Purpose**: Fetch paginated top-level comments for an event with optional sorting.

**Signature**:
```dart
Future<PaginatedComments> getCommentsForEvent({
  required String eventId,
  CommentSortOrder sortOrder = CommentSortOrder.recent,
  int limit = 20,
  DateTime? cursorCreatedAt, // For pagination
});
```

**Parameters**:
- `eventId` (required): Event UUID to fetch comments for
- `sortOrder` (optional): Sort by `recent` (created_at DESC) or `popular` (like_count DESC, created_at DESC)
- `limit` (optional): Number of comments per page (default 20, max 50)
- `cursorCreatedAt` (optional): Cursor for pagination (timestamp of last comment from previous page)

**Returns**:
```dart
class PaginatedComments {
  final List<Comment> comments;
  final bool hasMore; // True if more pages available
  final DateTime? nextCursor; // Cursor for next page (created_at of last comment)

  const PaginatedComments({
    required this.comments,
    required this.hasMore,
    this.nextCursor,
  });
}
```

**Exceptions**:
- `NetworkException`: Network error or timeout
- `UnauthorizedException`: User not authenticated
- `NotFoundException`: Event does not exist
- `ServerException`: Supabase error (5xx)

---

#### `getRepliesForComment`

**Purpose**: Fetch all replies for a specific top-level comment.

**Signature**:
```dart
Future<List<Comment>> getRepliesForComment({
  required String commentId,
});
```

**Parameters**:
- `commentId` (required): Parent comment UUID

**Returns**: List of `Comment` entities (sorted by `created_at ASC`)

**Exceptions**:
- `NetworkException`: Network error
- `UnauthorizedException`: User not authenticated
- `NotFoundException`: Parent comment does not exist
- `ServerException`: Supabase error

---

#### `getCommentById`

**Purpose**: Fetch a single comment by ID (used for real-time updates).

**Signature**:
```dart
Future<Comment> getCommentById({
  required String commentId,
});
```

**Parameters**:
- `commentId` (required): Comment UUID

**Returns**: `Comment` entity

**Exceptions**:
- `NetworkException`: Network error
- `UnauthorizedException`: User not authenticated
- `NotFoundException`: Comment does not exist or is deleted
- `ServerException`: Supabase error

---

#### `getUserComments`

**Purpose**: Fetch all comments posted by a specific user (for profile view).

**Signature**:
```dart
Future<List<Comment>> getUserComments({
  required String userId,
  int limit = 50,
  int offset = 0,
});
```

**Parameters**:
- `userId` (required): User UUID
- `limit` (optional): Max comments to return (default 50)
- `offset` (optional): Skip first N comments (for pagination)

**Returns**: List of `Comment` entities (sorted by `created_at DESC`)

**Exceptions**:
- `NetworkException`: Network error
- `UnauthorizedException`: User not authenticated
- `ServerException`: Supabase error

---

### 2. Mutation Operations

#### `postComment`

**Purpose**: Create a new top-level comment on an event.

**Signature**:
```dart
Future<Comment> postComment({
  required String eventId,
  required String text,
});
```

**Parameters**:
- `eventId` (required): Event UUID
- `text` (required): Comment text (1-500 chars after trim)

**Returns**: Created `Comment` entity with generated UUID

**Exceptions**:
- `ValidationException`: Text length invalid or contains profanity
- `RateLimitException`: User exceeded rate limit (3 identical comments in 5 min)
- `NetworkException`: Network error
- `UnauthorizedException`: User not authenticated
- `ForbiddenException`: Event not approved or user not allowed to comment
- `ServerException`: Supabase error

---

#### `replyToComment`

**Purpose**: Create a reply to an existing comment (top-level or reply).

**Signature**:
```dart
Future<Comment> replyToComment({
  required String commentId,
  required String text,
});
```

**Parameters**:
- `commentId` (required): Parent comment UUID (can be top-level or reply - system enforces 1-level max)
- `text` (required): Reply text (1-500 chars after trim)

**Returns**: Created `Comment` entity with `parent_comment_id` set

**Exceptions**:
- `ValidationException`: Text length invalid or contains profanity
- `RateLimitException`: User exceeded rate limit
- `NetworkException`: Network error
- `UnauthorizedException`: User not authenticated
- `NotFoundException`: Parent comment does not exist
- `ForbiddenException`: Parent comment is deleted or hidden
- `ServerException`: Supabase error

---

#### `editComment`

**Purpose**: Edit own comment within 5-minute window.

**Signature**:
```dart
Future<Comment> editComment({
  required String commentId,
  required String newText,
});
```

**Parameters**:
- `commentId` (required): Comment UUID to edit
- `newText` (required): Updated text (1-500 chars after trim)

**Returns**: Updated `Comment` entity with `updated_at` set to NOW()

**Exceptions**:
- `ValidationException`: Text length invalid or contains profanity
- `ForbiddenException`: Comment not owned by user, or edit window expired (>5 min)
- `NetworkException`: Network error
- `UnauthorizedException`: User not authenticated
- `NotFoundException`: Comment does not exist
- `ServerException`: Supabase error

---

#### `deleteComment`

**Purpose**: Soft-delete own comment (text replaced with "[Commento eliminato]").

**Signature**:
```dart
Future<void> deleteComment({
  required String commentId,
});
```

**Parameters**:
- `commentId` (required): Comment UUID to delete

**Returns**: `void` (success is no exception thrown)

**Exceptions**:
- `ForbiddenException`: Comment not owned by user, or already deleted
- `NetworkException`: Network error
- `UnauthorizedException`: User not authenticated
- `NotFoundException`: Comment does not exist
- `ServerException`: Supabase error

---

### 3. Like Operations

#### `likeComment`

**Purpose**: Add a like to a comment (idempotent - duplicate likes ignored).

**Signature**:
```dart
Future<void> likeComment({
  required String commentId,
});
```

**Parameters**:
- `commentId` (required): Comment UUID to like

**Returns**: `void` (success is no exception thrown)

**Side Effects**:
- Increments `like_count` on comment (via database trigger)
- Inserts row in `comment_likes` table

**Exceptions**:
- `RateLimitException`: User exceeded like rate limit (100 likes/hour)
- `NetworkException`: Network error
- `UnauthorizedException`: User not authenticated
- `NotFoundException`: Comment does not exist or is deleted
- `ServerException`: Supabase error

---

#### `unlikeComment`

**Purpose**: Remove a like from a comment (idempotent - unliking already-unliked comment is no-op).

**Signature**:
```dart
Future<void> unlikeComment({
  required String commentId,
});
```

**Parameters**:
- `commentId` (required): Comment UUID to unlike

**Returns**: `void` (success is no exception thrown)

**Side Effects**:
- Decrements `like_count` on comment (via database trigger)
- Deletes row from `comment_likes` table

**Exceptions**:
- `NetworkException`: Network error
- `UnauthorizedException`: User not authenticated
- `NotFoundException`: Comment does not exist
- `ServerException`: Supabase error

---

### 4. Report Operations

#### `reportComment`

**Purpose**: Submit a report for inappropriate comment.

**Signature**:
```dart
Future<CommentReport> reportComment({
  required String commentId,
  required CommentReportReason reason,
  String? details, // Optional elaboration (max 500 chars)
});
```

**Parameters**:
- `commentId` (required): Comment UUID to report
- `reason` (required): Enum value (`spam`, `inappropriate`, `bullying`, `off_topic`)
- `details` (optional): Additional context (max 500 chars)

**Returns**: Created `CommentReport` entity

**Side Effects**:
- Increments `report_count` on comment (via database trigger)
- Auto-hides comment if `report_count >= 3` (via database trigger)

**Exceptions**:
- `ValidationException`: Details exceed 500 chars
- `ConflictException`: User already reported this comment
- `NetworkException`: Network error
- `UnauthorizedException`: User not authenticated
- `NotFoundException`: Comment does not exist
- `ServerException`: Supabase error

---

### 5. Moderation Operations (Moderator-Only)

#### `moderatorRemoveComment`

**Purpose**: Hard-hide a comment (moderator action).

**Signature**:
```dart
Future<void> moderatorRemoveComment({
  required String commentId,
  String? reason, // Internal notes for moderation log
});
```

**Parameters**:
- `commentId` (required): Comment UUID to remove
- `reason` (optional): Internal notes explaining removal

**Returns**: `void` (success is no exception thrown)

**Side Effects**:
- Sets `hidden_at = NOW()`, `hidden_reason = 'moderator_removed'`, `moderator_id = current_user`
- Comment no longer visible to students (visible to moderators for audit)

**Exceptions**:
- `ForbiddenException`: User is not a moderator
- `NetworkException`: Network error
- `UnauthorizedException`: User not authenticated
- `NotFoundException`: Comment does not exist
- `ServerException`: Supabase error

---

#### `moderatorRestoreComment`

**Purpose**: Restore an auto-hidden comment (moderator reviewed and approved).

**Signature**:
```dart
Future<void> moderatorRestoreComment({
  required String commentId,
});
```

**Parameters**:
- `commentId` (required): Comment UUID to restore

**Returns**: `void` (success is no exception thrown)

**Side Effects**:
- Sets `hidden_at = NULL`, `hidden_reason = NULL`
- Comment becomes visible to students again

**Exceptions**:
- `ForbiddenException`: User is not a moderator
- `NetworkException`: Network error
- `UnauthorizedException`: User not authenticated
- `NotFoundException`: Comment does not exist or not hidden
- `ServerException`: Supabase error

---

### 6. Real-Time Operations

#### `subscribeToComments`

**Purpose**: Subscribe to real-time comment updates for an event.

**Signature**:
```dart
Stream<List<Comment>> subscribeToComments({
  required String eventId,
});
```

**Parameters**:
- `eventId` (required): Event UUID to subscribe to

**Returns**: `Stream<List<Comment>>` that emits updated comment list on each change

**Behavior**:
- Emits initial snapshot of all top-level comments
- Emits updated list on INSERT, UPDATE, DELETE operations (via Supabase Realtime)
- Stream closes when disposed or on error

**Exceptions** (emitted via stream):
- `NetworkException`: WebSocket connection failed
- `UnauthorizedException`: User not authenticated
- `ServerException`: Supabase Realtime error

---

### 7. Offline Operations

#### `getCachedComments`

**Purpose**: Fetch comments from local Hive cache (offline support).

**Signature**:
```dart
Future<List<Comment>?> getCachedComments({
  required String eventId,
});
```

**Parameters**:
- `eventId` (required): Event UUID

**Returns**: List of `Comment` entities from cache, or `null` if cache miss or expired (15-min TTL)

**Exceptions**:
- `CacheException`: Hive database error

---

#### `cachesComments`

**Purpose**: Store comments in local Hive cache for offline viewing.

**Signature**:
```dart
Future<void> cacheComments({
  required String eventId,
  required List<Comment> comments,
});
```

**Parameters**:
- `eventId` (required): Event UUID (cache key)
- `comments` (required): List of comments to cache

**Returns**: `void` (success is no exception thrown)

**Exceptions**:
- `CacheException`: Hive database error (e.g., disk full)

---

#### `queueOfflineAction`

**Purpose**: Queue a comment action (post, like, delete, report) for sync when online.

**Signature**:
```dart
Future<void> queueOfflineAction({
  required OfflineCommentAction action,
});
```

**Parameters**:
- `action` (required): Action data (type, comment ID, text, etc.)

**Returns**: `void` (success is no exception thrown)

**Exceptions**:
- `CacheException`: Hive database error

---

#### `syncOfflineQueue`

**Purpose**: Sync all queued offline actions to server.

**Signature**:
```dart
Future<OfflineSyncResult> syncOfflineQueue();
```

**Returns**:
```dart
class OfflineSyncResult {
  final int successCount;
  final int failureCount;
  final List<OfflineActionError> errors;

  const OfflineSyncResult({
    required this.successCount,
    required this.failureCount,
    required this.errors,
  });
}
```

**Exceptions**:
- `NetworkException`: Network unavailable (queue remains, retry later)
- `CacheException`: Hive database error

---

## Supporting Types

### `CommentSortOrder` Enum

```dart
enum CommentSortOrder {
  recent, // created_at DESC (default)
  popular, // like_count DESC, created_at DESC
}
```

---

### `OfflineCommentAction` Model

```dart
class OfflineCommentAction {
  final String tempId; // Client-generated UUID
  final OfflineActionType type;
  final String? commentId; // For edit, delete, like, unlike, report
  final String? eventId; // For post
  final String? parentCommentId; // For reply
  final String? text; // For post, reply, edit
  final CommentReportReason? reportReason; // For report
  final String? reportDetails; // For report
  final DateTime queuedAt;

  const OfflineCommentAction({
    required this.tempId,
    required this.type,
    this.commentId,
    this.eventId,
    this.parentCommentId,
    this.text,
    this.reportReason,
    this.reportDetails,
    required this.queuedAt,
  });
}

enum OfflineActionType {
  post,
  reply,
  edit,
  delete,
  like,
  unlike,
  report,
}
```

---

### `OfflineActionError` Model

```dart
class OfflineActionError {
  final OfflineCommentAction action;
  final Exception exception;

  const OfflineActionError({
    required this.action,
    required this.exception,
  });
}
```

---

## Exception Hierarchy

```dart
// Base exception
abstract class CommentException implements Exception {
  final String message;
  final String? code;

  const CommentException(this.message, [this.code]);
}

// Network errors
class NetworkException extends CommentException {
  const NetworkException(String message) : super(message, 'NETWORK_ERROR');
}

// Authentication errors
class UnauthorizedException extends CommentException {
  const UnauthorizedException(String message) : super(message, 'UNAUTHORIZED');
}

class ForbiddenException extends CommentException {
  const ForbiddenException(String message) : super(message, 'FORBIDDEN');
}

// Validation errors
class ValidationException extends CommentException {
  final Map<String, String> fieldErrors;

  const ValidationException(String message, this.fieldErrors)
      : super(message, 'VALIDATION_ERROR');
}

// Rate limiting
class RateLimitException extends CommentException {
  final Duration retryAfter;

  const RateLimitException(String message, this.retryAfter)
      : super(message, 'RATE_LIMIT_EXCEEDED');
}

// Resource errors
class NotFoundException extends CommentException {
  const NotFoundException(String message) : super(message, 'NOT_FOUND');
}

class ConflictException extends CommentException {
  const ConflictException(String message) : super(message, 'CONFLICT');
}

// Server errors
class ServerException extends CommentException {
  const ServerException(String message) : super(message, 'SERVER_ERROR');
}

// Offline errors
class CacheException extends CommentException {
  const CacheException(String message) : super(message, 'CACHE_ERROR');
}
```

---

## Implementation Notes

### Dependency Injection (Riverpod)

```dart
// Repository provider (abstract interface bound to concrete implementation)
final commentsRepositoryProvider = Provider<CommentsRepositoryInterface>((ref) {
  return CommentsRepository(
    remoteDataSource: ref.read(commentsRemoteDataSourceProvider),
    localDataSource: ref.read(commentsLocalDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});
```

### Error Handling Pattern

All repository methods should:
1. Catch data source exceptions
2. Transform to domain exceptions (e.g., `SupabaseException` → `ServerException`)
3. Log errors with context
4. Re-throw domain exception

Example:
```dart
@override
Future<Comment> postComment({
  required String eventId,
  required String text,
}) async {
  try {
    final commentModel = await _remoteDataSource.createComment(
      eventId: eventId,
      text: text.trim(),
    );
    return commentModel.toEntity();
  } on SupabaseException catch (e) {
    if (e.message.contains('profanity')) {
      throw ValidationException(
        'Il commento contiene linguaggio inappropriato',
        {'text': 'Linguaggio inappropriato rilevato'},
      );
    } else if (e.message.contains('rate limit')) {
      throw RateLimitException(
        'Hai superato il limite di commenti',
        Duration(minutes: 5),
      );
    } else if (e.statusCode == '401') {
      throw UnauthorizedException('Devi effettuare il login');
    } else {
      _logger.error('Failed to post comment', e);
      throw ServerException('Errore del server. Riprova più tardi.');
    }
  } on SocketException catch (e) {
    throw NetworkException('Connessione assente. Verifica la tua rete.');
  }
}
```

---

**Status**: ✅ Repository Interface Contract Complete
**Next**: Supabase API Specification (concrete method calls)
