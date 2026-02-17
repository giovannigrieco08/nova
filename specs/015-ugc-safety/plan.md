# Implementation Plan: UGC Safety System

**Branch**: `015-ugc-safety` | **Date**: 2025-02-12 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/015-ugc-safety/spec.md`

## Summary

Sistema completo per la conformità Apple Guideline 1.2 che include: sistema di segnalazione contenuti unificato, blocco utenti con filtro feed automatico, accettazione ToS con tracking versioni, filtro contenuti configurabile, e dashboard di moderazione per gestione segnalazioni entro 24h.

## Technical Context

**Language/Version**: Dart 3.x (Flutter SDK 3.x+)
**Primary Dependencies**: Riverpod (state), Supabase Flutter SDK, Go Router
**Storage**: PostgreSQL 15+ (Supabase), Supabase Storage per ToS documents
**Testing**: flutter_test, integration_test
**Target Platform**: iOS 15+, Android 8+
**Project Type**: Mobile (Flutter) + Backend (Supabase Edge Functions)
**Performance Goals**: Report submission <500ms, Block effect <1s (feed filter)
**Constraints**: Moderation response <24h (Apple requirement), offline not required
**Scale/Scope**: ~5k users initial, ~100 reports/day estimated

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| ENGAGEMENT_FIRST | ✅ Pass | Blocking removes toxic content, improves UX |
| SCHOOL_IDENTITY | ✅ Pass | Reports linked to real identities (accountability) |
| EPHEMERAL_CONTENT | ✅ Pass | Reports persist but content may expire |
| CAMERA_FIRST | ✅ N/A | No impact on camera flow |
| AMBASSADOR_GROWTH | ✅ Pass | Moderators = representatives (existing pattern) |
| AD_SUPPORTED | ✅ N/A | No ad integration in safety features |
| PERFORMANCE_FIRST | ✅ Pass | Indexes optimized, blocking filter <1s |

**Content Moderation (Constitution Section)**:
- ✅ Report button on every content
- ✅ Moderators can remove content
- ✅ Auto-detection via banned_words
- ✅ Ban for repeat violations
- ✅ Response time <24h (dashboard with urgency indicators)
- ✅ Appeals process (lift_sanction function)

## Project Structure

### Documentation (this feature)

```text
specs/015-ugc-safety/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Research findings
├── data-model.md        # Database schema
├── quickstart.md        # Setup guide
├── contracts/           # API contracts
│   ├── reports.md
│   ├── blocks.md
│   ├── tos.md
│   ├── moderation.md
│   └── content-filter.md
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

```text
lib/
├── features/
│   └── safety/                    # NEW FEATURE MODULE
│       ├── data/
│       │   ├── repositories/
│       │   │   ├── report_repository.dart
│       │   │   ├── block_repository.dart
│       │   │   ├── tos_repository.dart
│       │   │   └── content_filter_repository.dart
│       │   └── models/
│       │       ├── report.dart
│       │       ├── user_block.dart
│       │       ├── tos_status.dart
│       │       ├── content_check_result.dart
│       │       └── user_sanction.dart
│       ├── domain/
│       │   └── services/
│       │       ├── report_service.dart
│       │       ├── block_service.dart
│       │       └── content_filter_service.dart
│       ├── presentation/
│       │   ├── screens/
│       │   │   ├── blocked_users_screen.dart
│       │   │   └── tos_acceptance_screen.dart
│       │   ├── widgets/
│       │   │   ├── report_button.dart
│       │   │   ├── report_sheet.dart
│       │   │   ├── block_button.dart
│       │   │   └── content_warning_banner.dart
│       │   └── providers/
│       │       ├── report_provider.dart
│       │       ├── block_provider.dart
│       │       ├── tos_provider.dart
│       │       └── content_filter_provider.dart
│       └── safety.dart            # Feature barrel export
│
├── core/
│   └── providers/
│       └── feed_filter_provider.dart  # MODIFIED: integrate block filtering
│
└── shared/
    └── widgets/
        └── content_menu.dart          # MODIFIED: add Report/Block options

supabase/
├── migrations/
│   └── 057_ugc_safety_system.sql      # NEW: All tables, functions, triggers
├── seeds/
│   └── banned_words.sql               # NEW: Initial word list
├── functions/
│   ├── send-urgent-reports-digest/    # NEW: Email digest
│   │   └── index.ts
│   └── check-ban-status/              # NEW: Auth hook
│       └── index.ts
└── storage/
    └── public/
        └── legal/
            └── tos-1.0.0.md           # NEW: ToS document
```

**Structure Decision**: Mobile + Supabase Backend. New `safety` feature module following existing feature-first pattern. Edge Functions for scheduled tasks and auth hooks.

## Complexity Tracking

> No violations - standard patterns used.

## Generated Artifacts

| Artifact | Status | Description |
|----------|--------|-------------|
| [research.md](./research.md) | ✅ Complete | Technical decisions and rationale |
| [data-model.md](./data-model.md) | ✅ Complete | 4 new tables, 2 profile columns, 6 functions |
| [contracts/reports.md](./contracts/reports.md) | ✅ Complete | Report system API |
| [contracts/blocks.md](./contracts/blocks.md) | ✅ Complete | Block system API |
| [contracts/tos.md](./contracts/tos.md) | ✅ Complete | ToS acceptance API |
| [contracts/moderation.md](./contracts/moderation.md) | ✅ Complete | Moderation dashboard API |
| [contracts/content-filter.md](./contracts/content-filter.md) | ✅ Complete | Content filter API |
| [quickstart.md](./quickstart.md) | ✅ Complete | Setup and testing guide |

## Implementation Phases

### Phase 1: Database & Core (P1 Stories)

1. Database migration (tables, functions, triggers, RLS)
2. Report repository + service
3. Block repository + service (+ feed filtering)
4. ToS repository + service
5. Profile columns migration

### Phase 2: UI Components (P1 Stories)

1. Report button + sheet component
2. Block button + confirmation dialog
3. ToS acceptance screen
4. Blocked users settings screen
5. Integration with existing content menus

### Phase 3: Moderation (P2 Stories)

1. Edge Function: urgent reports digest
2. Edge Function: check-ban-status auth hook
3. Content filter repository + service
4. Content warning UI components

### Phase 4: Testing & Polish (P3 Stories)

1. Unblock functionality
2. Integration tests
3. Edge case handling
4. Performance optimization

## Next Steps

Run `/speckit.tasks` to generate the detailed task list for implementation.
