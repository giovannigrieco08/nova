# Research: Chat Message Actions (Edit & Delete)

**Feature Branch**: `013-chat-message-actions`
**Created**: 2026-01-17
**Status**: Complete

## Executive Summary

L'analisi del codebase esistente rivela che la funzionalità di edit/delete **esiste già parzialmente**. Sono necessarie modifiche per allinearla alle specifiche richieste.

## Existing Implementation Analysis

### Current State

| Feature | Status | Current Behavior | Required Behavior |
|---------|--------|------------------|-------------------|
| Message Edit | Implemented | 5-minute window | 15-minute window |
| Edit Indicator | Implemented | Shows "Modificato" | Matches spec |
| Message Delete | Implemented | 30-minute window, hard delete | Unlimited, soft delete |
| Delete Placeholder | Not Implemented | Row removed | Show "Messaggio eliminato" |
| Confirmation Dialog | Not Found | None | Required before delete |

### Database Schema (Current)

**File**: `supabase/migrations/015_global_chat_system.sql`

```sql
-- Existing fields for edit support
edited_at TIMESTAMPTZ NULL,
original_content TEXT NULL,

-- Existing fields for moderation (can be repurposed)
hidden_at TIMESTAMPTZ NULL,
hidden_reason TEXT NULL,
moderator_id UUID NULL
```

**File**: `supabase/migrations/019_chat_message_deletion.sql`

```sql
-- Current RLS policy (30-minute window)
CREATE POLICY "chat_messages_delete_own" ON chat_messages
  FOR DELETE USING (
    auth.uid() = user_id
    AND created_at > NOW() - INTERVAL '30 minutes'
    AND hidden_at IS NULL
  );
```

### Dart Implementation (Current)

**Domain Entity** (`chat_message.dart`):
```dart
bool get canDelete => DateTime.now().difference(createdAt).inMinutes < 30;
bool get canEdit => DateTime.now().difference(createdAt).inMinutes < 5;
bool get isEdited => editedAt != null;
```

**Repository** (`chat_repository_impl.dart`):
- Edit validation: 5-minute window
- Delete: Calls Supabase delete (hard delete)

---

## Research Decisions

### Decision 1: Soft Delete Implementation

**Decision**: Use `deleted_at` field for soft delete instead of hard delete

**Rationale**:
- Preserves conversation chronology
- Allows showing "Messaggio eliminato" placeholder
- Maintains referential integrity for replies
- Existing `hidden_at` field is for moderation, not user-initiated delete

**Alternatives Considered**:
| Alternative | Rejected Because |
|-------------|------------------|
| Reuse `hidden_at` field | Semantic confusion - hidden is for moderation |
| Hard delete with tombstone | Complex, requires separate table |
| Replace content with placeholder | Loses original_content for audit |

**Implementation**:
- Add `deleted_at TIMESTAMPTZ NULL` field
- Add `deleted_by_user BOOLEAN DEFAULT FALSE` to distinguish from moderation
- Update RLS policy to allow soft delete (UPDATE instead of DELETE)
- Never expose `content` when `deleted_at IS NOT NULL`

### Decision 2: Edit Window Extension

**Decision**: Extend edit window from 5 minutes to 15 minutes

**Rationale**:
- Spec requirement (FR-004)
- Industry standard (WhatsApp uses 15 minutes)
- Simple configuration change

**Implementation**:
- Update constant in domain entity: `canEdit` from 5 to 15 minutes
- Update repository validation
- Update UI countdown timer

### Decision 3: Delete Window Removal

**Decision**: Remove 30-minute delete restriction

**Rationale**:
- Spec requirement (FR-001): "in qualsiasi momento dopo l'invio"
- Privacy-first approach
- Soft delete reduces impact of unlimited deletion

**Implementation**:
- Update RLS policy to remove time constraint
- Remove `canDelete` time check in domain entity
- Keep ownership check (can only delete own messages)

### Decision 4: Confirmation Dialog

**Decision**: Implement confirmation dialog for delete actions only

**Rationale**:
- Spec requirement (FR-008)
- Deletion is irreversible (content removed from DB)
- Edit doesn't need confirmation (can be re-edited)

**Implementation**:
- Create `DeleteMessageConfirmationDialog` widget
- Show before calling delete API
- Options: "Annulla" / "Elimina"

### Decision 5: Realtime Propagation

**Decision**: Leverage existing Postgres Changes channel for soft delete

**Rationale**:
- Edit already works via UPDATE event
- Soft delete is also UPDATE (sets `deleted_at`)
- No new realtime channel needed

**Implementation**:
- Existing `_subscribeToMessages()` handles UPDATE events
- Message re-fetch will return `deleted_at` field
- UI will render placeholder when `deleted_at IS NOT NULL`

---

## Technical Specifications

### Database Changes

```sql
-- Migration: 036_soft_delete_messages.sql
ALTER TABLE chat_messages ADD COLUMN deleted_at TIMESTAMPTZ NULL;
ALTER TABLE chat_messages ADD COLUMN deleted_by_user BOOLEAN DEFAULT FALSE;

-- Drop old delete policy
DROP POLICY IF EXISTS "chat_messages_delete_own" ON chat_messages;

-- New soft delete policy (UPDATE to set deleted_at)
CREATE POLICY "chat_messages_soft_delete_own" ON chat_messages
  FOR UPDATE USING (
    auth.uid() = user_id
  ) WITH CHECK (
    auth.uid() = user_id
    AND (deleted_at IS NULL OR deleted_at = NEW.deleted_at)
  );
```

### API Changes

| Endpoint | Current | New |
|----------|---------|-----|
| Delete Message | `DELETE /chat_messages/{id}` | `PATCH /chat_messages/{id}` with `deleted_at` |
| Edit Window | 5 minutes | 15 minutes |

### UI Changes

| Component | Change |
|-----------|--------|
| `ChatMessageTile` | Render "Messaggio eliminato" when `deletedAt != null` |
| `ChatMessage` entity | Add `deletedAt`, update `canEdit` to 15 min |
| Context Menu | Add confirmation dialog before delete |
| Edit Dialog | Update countdown from 5 to 15 minutes |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Data migration issues | Low | Medium | Test migration on staging first |
| UI inconsistency during rollout | Low | Low | Soft delete is additive change |
| Performance impact | Very Low | Low | No new queries, just field check |

---

## Compatibility

### Backward Compatibility

- Existing messages without `deleted_at` will work (NULL = not deleted)
- Old client versions won't show "Messaggio eliminato" but won't crash
- Realtime channel unchanged

### Migration Path

1. Deploy database migration
2. Deploy backend changes (repository, RPC)
3. Deploy frontend changes (UI, entity)
4. No downtime required

---

## References

- Current implementation: `nova/lib/features/chat/`
- Migrations: `supabase/migrations/015_*, 019_*`
- Spec: `specs/013-chat-message-actions/spec.md`
