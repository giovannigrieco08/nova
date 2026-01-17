# Quickstart: Chat Message Actions (Edit & Delete)

**Feature Branch**: `013-chat-message-actions`
**Created**: 2026-01-17

## Overview

Questa guida descrive come implementare le modifiche per la funzionalità di edit e delete dei messaggi chat secondo le specifiche.

## Prerequisites

- Flutter SDK 3.x+
- Accesso a Supabase project
- Branch `013-chat-message-actions` checked out

## Implementation Steps

### Step 1: Database Migration

Crea il file di migrazione per il soft delete:

```bash
# Crea nuovo file migrazione
touch supabase/migrations/036_soft_delete_messages.sql
```

Contenuto della migrazione:

```sql
-- Add soft delete fields
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ NULL;
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS deleted_by_user BOOLEAN DEFAULT FALSE;

-- Index for efficient filtering
CREATE INDEX IF NOT EXISTS idx_chat_messages_deleted_at
  ON chat_messages(deleted_at) WHERE deleted_at IS NULL;

-- Drop old hard-delete policy
DROP POLICY IF EXISTS "chat_messages_delete_own" ON chat_messages;

-- New soft delete policy
CREATE POLICY "chat_messages_soft_delete_own" ON chat_messages
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id
    AND (
      (OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL)
      OR OLD.deleted_at = NEW.deleted_at
      OR (OLD.deleted_at IS NULL AND NEW.deleted_at IS NULL)
    )
  );
```

Applica la migrazione:

```bash
supabase db push
```

### Step 2: Update Domain Entity

File: `nova/lib/features/chat/domain/entities/chat_message.dart`

Aggiungi i nuovi campi e aggiorna la logica:

```dart
class ChatMessage {
  // ... existing fields ...

  // NEW: Soft delete support
  final DateTime? deletedAt;
  final bool deletedByUser;

  // UPDATED: Edit window = 15 minutes (was 5)
  static const int editWindowMinutes = 15;

  bool get canEdit {
    if (deletedAt != null) return false;
    return DateTime.now().difference(createdAt).inMinutes < editWindowMinutes;
  }

  // UPDATED: Delete always allowed
  bool get canDelete => deletedAt == null;

  // NEW
  bool get isDeleted => deletedAt != null;

  String get displayContent => isDeleted ? 'Messaggio eliminato' : content;

  int get editWindowMinutesRemaining {
    if (!canEdit) return 0;
    return editWindowMinutes - DateTime.now().difference(createdAt).inMinutes;
  }
}
```

### Step 3: Update Data Model

File: `nova/lib/features/chat/data/models/chat_message_model.dart`

Aggiungi parsing per i nuovi campi:

```dart
factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
  return ChatMessageModel(
    // ... existing fields ...
    deletedAt: json['deleted_at'] != null
        ? DateTime.parse(json['deleted_at'])
        : null,
    deletedByUser: json['deleted_by_user'] ?? false,
  );
}
```

### Step 4: Update Repository

File: `nova/lib/features/chat/data/repositories/chat_repository_impl.dart`

Implementa soft delete invece di hard delete:

```dart
@override
Future<void> deleteMessage(String messageId) async {
  final message = await getMessage(messageId);

  if (message == null) {
    throw ChatDeleteNotAllowedException('Messaggio non trovato.');
  }

  if (message.userId != _currentUserId) {
    throw ChatDeleteNotAllowedException('Puoi eliminare solo i tuoi messaggi.');
  }

  if (message.isDeleted) {
    throw ChatDeleteNotAllowedException('Messaggio già eliminato.');
  }

  // Delete associated media files
  if (message.hasMedia) {
    await _deleteMessageMedia(messageId);
  }

  // Soft delete
  await _supabase
      .from('chat_messages')
      .update({
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'deleted_by_user': true,
      })
      .eq('id', messageId);
}

@override
Future<ChatMessage> editMessage({
  required String messageId,
  required String newContent,
}) async {
  final message = await getMessage(messageId);

  if (message == null) {
    throw ChatEditNotAllowedException('Messaggio non trovato.');
  }

  if (message.userId != _currentUserId) {
    throw ChatEditNotAllowedException('Puoi modificare solo i tuoi messaggi.');
  }

  if (message.isDeleted) {
    throw ChatEditNotAllowedException('Non puoi modificare un messaggio eliminato.');
  }

  if (!message.canEdit) {
    throw ChatEditNotAllowedException(
      'Puoi modificare un messaggio solo entro 15 minuti dall\'invio.',
    );
  }

  return await _remoteDataSource.editMessage(
    messageId: messageId,
    newContent: newContent,
  );
}
```

### Step 5: Create Confirmation Dialog

File: `nova/lib/features/chat/presentation/widgets/delete_message_confirmation_dialog.dart`

```dart
class DeleteMessageConfirmationDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const DeleteMessageConfirmationDialog({
    super.key,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Elimina messaggio'),
      content: const Text(
        'Sei sicuro di voler eliminare questo messaggio? '
        'Il messaggio sarà sostituito con "Messaggio eliminato" '
        'visibile a tutti i partecipanti.',
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('Annulla'),
        ),
        TextButton(
          onPressed: onConfirm,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Elimina'),
        ),
      ],
    );
  }
}
```

### Step 6: Update Message Tile

File: `nova/lib/features/chat/presentation/widgets/chat_message_tile.dart`

Aggiungi rendering per messaggi eliminati:

```dart
Widget _buildMessageContent(ChatMessage message) {
  if (message.isDeleted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            'Messaggio eliminato',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Normal message content...
  return _buildNormalContent(message);
}
```

### Step 7: Update Context Menu

File: `nova/lib/features/chat/presentation/widgets/chat_message_context_overlay.dart`

Aggiungi conferma prima di eliminare:

```dart
void _handleDelete(BuildContext context, WidgetRef ref, String messageId) {
  showDialog(
    context: context,
    builder: (context) => DeleteMessageConfirmationDialog(
      onConfirm: () {
        Navigator.pop(context);
        ref.read(deleteMessageProvider(messageId));
        // Close context menu
        _closeOverlay();
      },
      onCancel: () => Navigator.pop(context),
    ),
  );
}
```

### Step 8: Update Edit Dialog Timer

File: `nova/lib/features/chat/presentation/widgets/edit_message_dialog.dart`

Aggiorna il timer da 5 a 15 minuti:

```dart
// Change constant
static const int editWindowMinutes = 15;

// Update warning threshold (show warning at 2 minutes remaining)
final showWarning = remainingMinutes <= 2;
```

## Testing

### Unit Tests

```dart
// test/features/chat/domain/entities/chat_message_test.dart
test('canEdit returns true within 15 minutes', () {
  final message = ChatMessage(
    createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    // ...
  );
  expect(message.canEdit, isTrue);
});

test('canEdit returns false after 15 minutes', () {
  final message = ChatMessage(
    createdAt: DateTime.now().subtract(const Duration(minutes: 16)),
    // ...
  );
  expect(message.canEdit, isFalse);
});

test('canDelete returns true for non-deleted messages', () {
  final message = ChatMessage(deletedAt: null, /* ... */);
  expect(message.canDelete, isTrue);
});

test('displayContent returns placeholder when deleted', () {
  final message = ChatMessage(
    content: 'Original',
    deletedAt: DateTime.now(),
    // ...
  );
  expect(message.displayContent, 'Messaggio eliminato');
});
```

### Integration Tests

1. Send a message
2. Verify edit is available within 15 minutes
3. Edit the message
4. Verify "Modificato" indicator appears
5. Wait 15 minutes (or mock time)
6. Verify edit is no longer available
7. Delete the message
8. Verify "Messaggio eliminato" placeholder appears
9. Verify other users see the placeholder in realtime

## Verification Checklist

- [ ] Database migration applied successfully
- [ ] Edit window extended to 15 minutes
- [ ] Delete works without time limit
- [ ] Confirmation dialog shows before delete
- [ ] "Messaggio eliminato" placeholder renders correctly
- [ ] "Modificato" indicator still works
- [ ] Realtime updates propagate to other users
- [ ] Media files deleted when message is soft-deleted
- [ ] Cannot edit deleted messages
- [ ] Cannot delete already deleted messages

## Rollback

If issues occur:

1. Revert Dart code changes
2. Run rollback migration:

```sql
-- 036_soft_delete_messages_rollback.sql
ALTER TABLE chat_messages DROP COLUMN IF EXISTS deleted_at;
ALTER TABLE chat_messages DROP COLUMN IF EXISTS deleted_by_user;
DROP INDEX IF EXISTS idx_chat_messages_deleted_at;
```

## References

- [Spec](./spec.md)
- [Research](./research.md)
- [Data Model](./data-model.md)
- [API Contract](./contracts/chat-message-actions.yaml)
