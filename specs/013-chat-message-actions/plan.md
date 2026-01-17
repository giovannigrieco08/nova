# Implementation Plan: Chat Message Actions (Edit & Delete)

**Branch**: `013-chat-message-actions` | **Date**: 2026-01-17 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/013-chat-message-actions/spec.md`

## Summary

Estensione della funzionalità chat esistente per supportare:
- **Edit**: Modifica messaggi entro 15 minuti (attualmente 5 minuti)
- **Delete**: Soft delete senza limite di tempo con placeholder "Messaggio eliminato" (attualmente hard delete con limite 30 minuti)
- **UX**: Dialog di conferma per eliminazione

La feature riutilizza l'infrastruttura esistente (realtime, repository pattern) con modifiche incrementali.

## Technical Context

**Language/Version**: Dart (Flutter SDK 3.x+)
**Primary Dependencies**: Riverpod, Supabase Client, freezed
**Storage**: PostgreSQL 15+ (Supabase)
**Testing**: flutter_test, integration_test
**Target Platform**: iOS 15+, Android API 24+
**Project Type**: Mobile (Flutter)
**Performance Goals**: Edit/Delete <3s, Realtime propagation <1s (SC-001, SC-002, SC-003)
**Constraints**: Offline-capable (optimistic updates), 60fps during scroll
**Scale/Scope**: ~500 users/school, 1000s of messages/day

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Compliance | Notes |
|-----------|------------|-------|
| **ENGAGEMENT_FIRST** | PASS | Non impatta negativamente engagement. Edit/delete migliora UX e riduce friction. |
| **SCHOOL_IDENTITY** | PASS | Messaggi associati a utenti verificati. Placeholder preserva identità autore. |
| **EPHEMERAL_CONTENT** | PASS | Chat non è soggetta a ephemeral (no 24h reset). Soft delete preserva cronologia. |
| **CAMERA_FIRST** | N/A | Feature non coinvolge camera. |
| **AMBASSADOR_GROWTH** | N/A | Feature non coinvolge growth. |
| **AD_SUPPORTED** | PASS | No ads in chat (policy esistente). |
| **PERFORMANCE_FIRST** | PASS | No nuove query, solo field check. Target <3s per azioni. |

**Constitution Check Result**: ✅ PASS - Nessuna violazione.

## Project Structure

### Documentation (this feature)

```text
specs/013-chat-message-actions/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── chat-message-actions.yaml
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
nova/lib/features/chat/
├── data/
│   ├── datasources/
│   │   └── chat_remote_datasource.dart     # MODIFY: Update delete to soft delete
│   ├── models/
│   │   └── chat_message_model.dart         # MODIFY: Add deleted_at, deleted_by_user
│   └── repositories/
│       └── chat_repository_impl.dart       # MODIFY: Update validation logic
├── domain/
│   ├── entities/
│   │   └── chat_message.dart               # MODIFY: Update canEdit, canDelete, add isDeleted
│   └── repositories/
│       └── chat_repository.dart            # NO CHANGE: Interface unchanged
└── presentation/
    ├── providers/
    │   ├── chat_providers.dart             # NO CHANGE: Providers unchanged
    │   └── chat_realtime_provider.dart     # NO CHANGE: UPDATE events already handled
    └── widgets/
        ├── chat_message_tile.dart          # MODIFY: Render deleted placeholder
        ├── chat_message_context_overlay.dart # MODIFY: Add confirmation dialog
        ├── edit_message_dialog.dart        # MODIFY: Update timer from 5 to 15 min
        └── delete_message_confirmation_dialog.dart  # NEW: Confirmation dialog

supabase/migrations/
└── 036_soft_delete_messages.sql            # NEW: Add soft delete fields and policy
```

**Structure Decision**: Mobile (Flutter) - Feature-first Clean Architecture. Modifiche concentrate nel feature `chat/` esistente.

## Complexity Tracking

> Nessuna violazione della Constitution. Tabella non applicabile.

## Implementation Summary

### Database Changes
1. Add `deleted_at` TIMESTAMPTZ field
2. Add `deleted_by_user` BOOLEAN field
3. Update RLS policy: soft delete (UPDATE) instead of hard delete (DELETE)

### Code Changes
1. **Domain**: Update `canEdit` to 15 min, `canDelete` unlimited, add `isDeleted`
2. **Data**: Parse new fields, implement soft delete in repository
3. **Presentation**: Confirmation dialog, placeholder rendering, timer update

### Estimated Scope
- 1 new migration file
- 1 new widget (confirmation dialog)
- 5 files to modify
- ~200 lines of code changes

## Generated Artifacts

| Artifact | Status | Path |
|----------|--------|------|
| research.md | ✅ Complete | [research.md](./research.md) |
| data-model.md | ✅ Complete | [data-model.md](./data-model.md) |
| contracts/ | ✅ Complete | [contracts/chat-message-actions.yaml](./contracts/chat-message-actions.yaml) |
| quickstart.md | ✅ Complete | [quickstart.md](./quickstart.md) |

## Next Steps

1. Run `/speckit.tasks` to generate the task list
2. Run `/speckit.implement` to execute implementation
