# Implementation Plan: Admin Panel & Moderation Queue

**Branch**: `005-moderation-admin-panel` | **Date**: 2025-11-13 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/005-moderation-admin-panel/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command.

## Summary

Implement complete event moderation system with 3-tier role-based access control (students, moderators, admins), moderation queue for approving/rejecting pending events, admin panel for managing moderators and viewing system statistics, real-time updates via Supabase Realtime, comprehensive audit logging, and push notifications for all approval/rejection workflows.

**Core Value**: Ensures all events are vetted before appearing in public feed, protecting the school community from inappropriate content while maintaining transparency and accountability.

## Technical Context

**Language/Version**: Dart (Flutter SDK 3.x+)
**Primary Dependencies**: Riverpod (state management), Supabase Client (backend integration)
**Storage**: PostgreSQL 15+ via Supabase Cloud (EU Frankfurt region for GDPR compliance)
**Testing**: Flutter test framework, integration tests for moderation workflows
**Target Platform**: iOS 15+ and Android 8+ (cross-platform Flutter app)
**Project Type**: Mobile (feature-first clean architecture)
**Performance Goals**: <1s dashboard load (cached), 60fps UI, real-time updates within 2 seconds
**Constraints**: <200ms user interaction response time, moderation queue <24h review time, badge updates in real-time
**Scale/Scope**: ~500 students, 5-10 moderators, 1 admin, 50+ events/month, real-time collaboration

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle Alignment

✅ **STUDENTS_FIRST (Principle 1)**
- Moderators are students, not teachers/admin
- Fast moderation flow (<30 seconds per event, 3 taps max per SC-001)
- Re-submission flow allows students to fix rejected events instead of discarding work
- Students don't see moderator identities (privacy protection per FR-018)

✅ **PRIVACY_FOUNDATION (Principle 2)**
- No additional data collection beyond existing user model
- Audit logs track actions, not personal data (moderator_id not exposed to students)
- Push notifications don't leak sensitive info (rejection reasons shown only to creator)
- Real-time updates use Supabase Realtime (privacy-respecting WebSocket)

✅ **SIMPLICITY_FIRST (Principle 3)**
- MVP scope: 69 functional requirements organized into 5 user stories (P1-P3)
- Out of Scope section explicitly excludes: bulk actions, advanced analytics, custom training content, priority queues
- Single responsibility: event moderation only (no chat/comment moderation)
- Linear workflow: pending → approved/rejected (no complex state machine)

✅ **PERFORMANCE_FIRST (Principle 4)**
- Dashboard <1s load time (SC-006 requirement)
- 60fps smooth scrolling (SC-006 requirement)
- Real-time updates within 2 seconds (SC-005, FR-027)
- Fallback to 15-second polling if Realtime fails (FR-069 resilience)

✅ **SPEC_FIRST (Principle 5)**
- Complete specification with 69 functional requirements
- 5 clarification questions resolved (0 [NEEDS CLARIFICATION] markers remaining)
- All user stories have acceptance scenarios
- Success criteria are measurable (12 SC items)

✅ **DESIGN_SYSTEM_STRICT (Principle 6)**
- Will use NovaSpacing, NovaColors, NovaTypography constants
- Native widgets (CupertinoButton/ElevatedButton) for platform consistency
- BackdropFilter for glassmorphism effects (constitution-compliant)
- No hardcoded values (enforced in code review)

✅ **CONTENT_MODERATION (Principle 7)**
- **Core feature implemented by this spec**
- Human moderation mandatory (moderators review all pending events per FR-019)
- Moderator dashboard with approval/rejection actions (FR-023)
- Rejection reasons required (FR-026, prevents arbitrary decisions)
- Appeals process specified (User Story 5, FR-064-067)
- Audit logging for accountability (FR-059-061, immutable logs)
- Admin panel for moderator management (User Story 2, FR-033-043)
- Statistics tracking (FR-029-032, FR-044-048)

### Gate Evaluation

**PASS** ✅ - All constitution principles aligned.

**Special Notes**:
- This feature implements Principle 7 (CONTENT_MODERATION) in its entirety
- Constitution v1.1.0 Section "Moderator Selection & Accountability" directly maps to User Story 2 (Admin Panel)
- Appeals process (User Story 5) satisfies constitution requirement: "Appeals process: content creators can request re-review with explanation if rejected"
- Transparency requirements met: FR-059-061 (audit logs), quarterly report feasible from ModerationLog data

## Project Structure

### Documentation (this feature)

```text
specs/005-moderation-admin-panel/
├── spec.md              # Feature specification (already complete)
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (to be generated)
├── data-model.md        # Phase 1 output (to be generated)
├── quickstart.md        # Phase 1 output (to be generated)
├── contracts/           # Phase 1 output (to be generated)
│   ├── moderation.yaml  # Moderation queue API contracts
│   ├── admin.yaml       # Admin panel API contracts
│   └── statistics.yaml  # Statistics API contracts
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

**Structure Decision**: Flutter mobile app with feature-first clean architecture per constitution.

```text
lib/
├── core/
│   ├── theme/                      # Design system (NovaColors, NovaSpacing, NovaTypography)
│   └── router/                     # Navigation (role-based tab visibility)
├── features/
│   ├── moderation/                 # NEW: Moderation Queue feature (P1)
│   │   ├── data/
│   │   │   ├── repositories/
│   │   │   │   └── moderation_repository.dart
│   │   │   └── models/
│   │   │       └── moderation_event.dart
│   │   ├── domain/
│   │   │   └── entities/
│   │   │       ├── pending_event.dart
│   │   │       └── moderation_action.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── moderation_dashboard_screen.dart
│   │       │   └── event_review_screen.dart
│   │       ├── widgets/
│   │       │   ├── pending_event_card.dart
│   │       │   ├── rejection_dialog.dart
│   │       │   └── moderator_stats_widget.dart
│   │       └── providers/
│   │           ├── pending_events_provider.dart
│   │           └── moderator_stats_provider.dart
│   ├── admin/                      # NEW: Admin Panel feature (P2)
│   │   ├── data/
│   │   │   ├── repositories/
│   │   │   │   └── admin_repository.dart
│   │   │   └── models/
│   │   │       └── admin_action.dart
│   │   ├── domain/
│   │   │   └── entities/
│   │   │       ├── moderator.dart
│   │   │       └── system_stats.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── admin_panel_screen.dart
│   │       ├── widgets/
│   │       │   ├── moderator_search.dart
│   │       │   ├── moderator_card.dart
│   │       │   ├── system_statistics_widget.dart
│   │       │   └── activity_log_widget.dart
│   │       └── providers/
│   │           ├── moderators_provider.dart
│   │           └── system_stats_provider.dart
│   ├── events/                     # EXISTING: Extend for re-submission (P3)
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── rejected_event_edit_screen.dart  # NEW for re-submission
│   │       └── widgets/
│   │           └── rejection_reason_badge.dart  # NEW to display rejection
│   └── auth/                       # EXISTING: Role management integration
│       └── domain/
│           └── entities/
│               └── user.dart       # Extended with role field (student/moderator/admin)
└── shared/
    └── widgets/
        └── realtime_badge.dart     # NEW: Badge with real-time count + fallback indicator

tests/
├── integration/
│   ├── moderation_flow_test.dart   # P1: Approve/reject workflow
│   ├── admin_flow_test.dart        # P2: Promote/remove moderator workflow
│   └── resubmission_flow_test.dart # P3: Rejection → edit → resubmit workflow
└── unit/
    ├── moderation_repository_test.dart
    └── admin_repository_test.dart
```

**Key Integrations**:
- **Bottom Navigation**: Add "Moderazione" tab (visible to moderators/admins only via role check in router)
- **Bottom Navigation**: Add "Admin" tab (visible to admins only)
- **Events Feed**: RLS policies ensure only approved events visible to students
- **Profile Screen**: Show rejected events with "Modifica e Ri-sottometti" button
- **Push Notifications**: Integrate with existing FCM/APNs setup (FR-054-058)

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

**No violations.** All requirements align with constitution principles. This feature implements Principle 7 (CONTENT_MODERATION) which was mandated by the constitution but not yet implemented.

---

## Post-Design Constitution Re-Check

*Re-evaluated after Phase 1 design completion*

### Technical Design Review

✅ **All constitutional principles maintained after design:**

**PRIVACY_FOUNDATION (Principle 2)**
- ✅ RLS policies enforce data access control at database level
- ✅ No PII in audit logs (moderator_id not exposed to students)
- ✅ JWT-based authentication (no passwords, no tracking)
- ✅ GDPR Right to Erasure implemented (CASCADE deletes)

**PERFORMANCE_FIRST (Principle 4)**
- ✅ Aggressive indexing strategy (15+ indexes) meets <1s load requirement
- ✅ Denormalized statistics table avoids expensive aggregations
- ✅ Real-time WebSocket <500ms latency (target: <2s)
- ✅ Fallback polling at 15s intervals when Realtime fails

**DESIGN_SYSTEM_STRICT (Principle 6)**
- ✅ Code examples use NovaColors, NovaSpacing, NovaTypography
- ✅ Platform-native widgets (CupertinoButton/ElevatedButton)
- ✅ No hardcoded values in quickstart guide
- ✅ BackdropFilter for glassmorphism (constitution-compliant)

**CONTENT_MODERATION (Principle 7)**
- ✅ Human moderation enforced via RLS (no direct status updates)
- ✅ Rejection reasons mandatory (FR-026, prevents arbitrary decisions)
- ✅ Immutable audit logs (FR-061, accountability)
- ✅ Appeals process via re-submission (User Story 5)
- ✅ Moderator accountability system (statistics, activity log, admin oversight)

### Design Decisions Alignment

**Security-in-Depth:**
- Database functions enforce business rules (concurrent moderation, self-moderation)
- RLS policies prevent unauthorized access
- CHECK constraints validate data integrity
- Triggers maintain audit trails

**Simplicity:**
- Linear workflow (pending → approved/rejected)
- Single responsibility (event moderation only, no chat/comments)
- No complex state machines or priority queues
- Standard Supabase patterns (no custom backends)

**Performance:**
- Indexed all RLS policy columns (prevents 100x slowdown)
- Partial indexes for common queries
- Denormalized statistics (no on-the-fly aggregations)
- Real-time optimizations (filter at source, not client)

### Gate Re-Evaluation: **PASS** ✅

No constitutional violations introduced during design phase. All technical decisions align with the 7 core principles. Ready to proceed to `/speckit.tasks` for implementation planning.
