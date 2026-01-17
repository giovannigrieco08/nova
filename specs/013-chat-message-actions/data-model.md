# Data Model: Chat Message Actions (Edit & Delete)

**Feature Branch**: `013-chat-message-actions`
**Created**: 2026-01-17
**Status**: Complete

## Overview

Questo documento descrive le modifiche al data model esistente per supportare le funzionalità di edit (15 minuti) e soft delete (illimitato) dei messaggi chat.

## Entity Changes

### ChatMessage (Modified)

**Table**: `chat_messages`

#### Existing Fields (No Changes)

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Primary key |
| `user_id` | UUID | FK to profiles.user_id |
| `content` | TEXT | Message content (max 500 chars) |
| `created_at` | TIMESTAMPTZ | When message was sent |
| `edited_at` | TIMESTAMPTZ | When message was last edited |
| `original_content` | TEXT | Original content before edit |

#### New Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `deleted_at` | TIMESTAMPTZ | NULL | When message was soft-deleted |
| `deleted_by_user` | BOOLEAN | FALSE | TRUE if user deleted, FALSE if system/mod |

### State Diagram

```
┌─────────────┐
│   ACTIVE    │ ← Initial state
│ deleted_at  │
│    NULL     │
└──────┬──────┘
       │
       ├─────────────────────────────────┐
       │ User edits (≤15 min)            │ User deletes (any time)
       │                                 │
       ▼                                 ▼
┌─────────────┐                 ┌─────────────┐
│   EDITED    │                 │   DELETED   │
│ edited_at   │                 │ deleted_at  │
│  NOT NULL   │                 │  NOT NULL   │
└──────┬──────┘                 └─────────────┘
       │                                ▲
       │ User deletes (any time)        │
       └────────────────────────────────┘
```

### Validation Rules

| Rule | Enforcement |
|------|-------------|
| Can edit own messages only | RLS policy + Repository |
| Edit window: 15 minutes | Repository validation |
| Can delete own messages only | RLS policy + Repository |
| Delete window: unlimited | No time restriction |
| Cannot edit deleted messages | Repository validation |
| Content hidden when deleted | View policy |

## Database Schema Changes

### Migration: 036_soft_delete_messages.sql

```sql
-- Add soft delete fields
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ NULL;
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS deleted_by_user BOOLEAN DEFAULT FALSE;

-- Create index for efficient filtering
CREATE INDEX IF NOT EXISTS idx_chat_messages_deleted_at
  ON chat_messages(deleted_at) WHERE deleted_at IS NULL;

-- Drop old hard-delete policy
DROP POLICY IF EXISTS "chat_messages_delete_own" ON chat_messages;

-- Soft delete policy: users can set deleted_at on their own messages
CREATE POLICY "chat_messages_soft_delete_own" ON chat_messages
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id
    -- Only allow setting deleted_at, not unsetting
    AND (
      (OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL)
      OR OLD.deleted_at = NEW.deleted_at
      OR (OLD.deleted_at IS NULL AND NEW.deleted_at IS NULL)
    )
  );
```

### View Changes

Per mascherare il contenuto dei messaggi eliminati, si utilizza la logica applicativa nel Dart model piuttosto che una view SQL, per mantenere la flessibilità.

## Dart Model Changes

### Domain Entity: ChatMessage

```dart
class ChatMessage {
  // ... existing fields ...

  // NEW: Soft delete support
  final DateTime? deletedAt;
  final bool deletedByUser;

  // UPDATED: Edit window from 5 to 15 minutes
  bool get canEdit {
    if (deletedAt != null) return false; // Cannot edit deleted
    return DateTime.now().difference(createdAt).inMinutes < 15;
  }

  // UPDATED: Delete always allowed (removed time check)
  bool get canDelete {
    if (deletedAt != null) return false; // Already deleted
    return true; // Always allowed for own messages
  }

  // NEW: Check if deleted
  bool get isDeleted => deletedAt != null;

  // NEW: Get display content (masked if deleted)
  String get displayContent {
    if (isDeleted) return 'Messaggio eliminato';
    return content;
  }

  // UPDATED: Time remaining calculation
  int get editWindowMinutesRemaining {
    if (!canEdit) return 0;
    return 15 - DateTime.now().difference(createdAt).inMinutes;
  }
}
```

### Data Model: ChatMessageModel

```dart
class ChatMessageModel {
  // ... existing fields ...

  // NEW fields
  final DateTime? deletedAt;
  final bool deletedByUser;

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      // ... existing parsing ...
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'])
          : null,
      deletedByUser: json['deleted_by_user'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    // ... existing fields ...
    'deleted_at': deletedAt?.toIso8601String(),
    'deleted_by_user': deletedByUser,
  };
}
```

## Relationships

### Affected Entities

| Entity | Relationship | Impact |
|--------|--------------|--------|
| `chat_reactions` | FK to chat_messages | No change - reactions stay on deleted messages |
| `chat_reports` | FK to chat_messages | No change - reports preserved |
| `chat_media` | FK to chat_messages | Media files should be deleted when message is soft-deleted |

### Media Cleanup

Quando un messaggio viene soft-deleted:
1. I file media associati vengono eliminati dallo storage
2. Il record `chat_media` rimane per referenza ma il file è inaccessibile
3. L'URL firmato restituisce 404

```dart
// In ChatRepositoryImpl.deleteMessage()
Future<void> deleteMessage(String messageId) async {
  // 1. Delete associated media files from storage
  final media = await _getMessageMedia(messageId);
  if (media != null) {
    await _storageService.deleteFile(media.storagePath);
  }

  // 2. Soft delete the message
  await _supabase
      .from('chat_messages')
      .update({
        'deleted_at': DateTime.now().toIso8601String(),
        'deleted_by_user': true,
      })
      .eq('id', messageId);
}
```

## Query Patterns

### Fetch Messages (with soft delete)

```sql
SELECT
  m.*,
  CASE WHEN m.deleted_at IS NOT NULL THEN NULL ELSE m.content END as content,
  p.display_name, p.photo_url
FROM chat_messages m
JOIN profiles p ON m.user_id = p.user_id
WHERE m.created_at > NOW() - INTERVAL '24 hours'
ORDER BY m.created_at DESC
LIMIT 50;
```

### Realtime Subscription

```dart
// Existing subscription handles UPDATE events
// Soft delete triggers UPDATE (sets deleted_at)
// UI re-renders with "Messaggio eliminato" placeholder
```

## Migration Strategy

1. **Pre-migration**: No action required
2. **Migration**: Run `036_soft_delete_messages.sql`
3. **Post-migration**: Deploy updated Dart code
4. **Rollback**: Remove columns (no data loss for existing messages)

## Performance Considerations

| Aspect | Impact | Mitigation |
|--------|--------|------------|
| Index on deleted_at | Minimal | Partial index excludes NULLs |
| Content masking | None | Done in Dart, not SQL |
| Media cleanup | Async | Triggered by soft delete, non-blocking |
