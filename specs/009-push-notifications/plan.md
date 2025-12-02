# Implementation Plan: Push Notifications

**Branch**: `009-push-notifications` | **Date**: 2025-11-30 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/009-push-notifications/spec.md`

## Summary

Integrate Firebase Cloud Messaging (FCM) to deliver push notifications when the app is closed/backgrounded. The system will register FCM tokens at login, store them in the profiles table, use Supabase Edge Functions to intercept notification creation and send FCM API calls, handle iOS APNs and Android FCM differences, manage badge counts, and enable deep link navigation from notification taps.

## Technical Context

**Language/Version**: Dart (Flutter SDK 3.x+)
**Primary Dependencies**: firebase_core, firebase_messaging, flutter_local_notifications, supabase_flutter
**Storage**: Supabase PostgreSQL (fcm_tokens table, profiles.fcm_token field)
**Testing**: Flutter integration tests, manual device testing (iOS/Android)
**Target Platform**: iOS 15+, Android 5.0+ (API 21+)
**Project Type**: Mobile (Flutter cross-platform)
**Performance Goals**: 95% push delivered within 5 seconds, zero duplicates
**Constraints**: Respect user notification preferences, handle all app states (foreground/background/terminated)
**Scale/Scope**: ~1000 students at Liceo Galilei Moro, multi-device support

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Assessment |
|-----------|--------|------------|
| **1. STUDENTS_FIRST** | ✅ PASS | Push notifications keep students informed about event activity even when not actively using app. Clear permission explanation respects student autonomy. |
| **2. PRIVACY_FOUNDATION** | ✅ PASS | FCM tokens are device identifiers, not personal data. No additional PII collected. Tokens removed on logout. User preferences respected (disabled channels = no push). |
| **3. SIMPLICITY_FIRST** | ✅ PASS | Push notifications are essential for engagement on mobile platform. Not a "nice to have" - core expectation of mobile app users. |
| **4. PERFORMANCE_FIRST** | ✅ PASS | Target <5s delivery aligns with performance standards. FCM is industry-standard with proven reliability. |
| **5. SPEC_FIRST** | ✅ PASS | Following SpecKit workflow with spec → plan → tasks → implement sequence. |
| **6. DESIGN_SYSTEM_STRICT** | ⚪ N/A | Push notifications are backend/service layer. Foreground banner will use design system. |
| **7. CONTENT_MODERATION** | ⚪ N/A | Notifications are system-generated for approved content only (events, comments). |

**Gate Status**: ✅ ALL GATES PASS - Proceed with Phase 0 research.

## Project Structure

### Documentation (this feature)

```text
specs/009-push-notifications/
├── plan.md              # This file
├── research.md          # Phase 0 output - FCM integration patterns
├── data-model.md        # Phase 1 output - fcm_tokens table schema
├── quickstart.md        # Phase 1 output - integration scenarios
├── contracts/           # Phase 1 output - Edge Function contracts
│   ├── fcm-webhook.yaml # Supabase Edge Function API
│   └── push-payload.json# FCM message payload schema
└── tasks.md             # Phase 2 output (by /speckit.tasks)
```

### Source Code (repository root)

```text
# Mobile + Supabase Functions structure

nova/lib/
├── core/
│   └── services/
│       ├── notification_service.dart  # Existing - extend for push
│       └── push_notification_service.dart  # New - FCM handling
├── features/
│   └── notifications/
│       ├── data/
│       │   ├── datasources/
│       │   │   └── fcm_token_datasource.dart  # Token CRUD
│       │   └── repositories/
│       │       └── push_repository.dart  # Token management
│       ├── domain/
│       │   └── usecases/
│       │       ├── register_fcm_token.dart
│       │       ├── remove_fcm_token.dart
│       │       └── handle_push_tap.dart
│       └── presentation/
│           ├── providers/
│           │   └── push_permission_provider.dart
│           └── widgets/
│               └── foreground_notification_banner.dart

supabase/
├── functions/
│   └── send-push-notification/  # Edge Function
│       └── index.ts
└── migrations/
    └── 009_push_notifications.sql  # New migration
```

**Structure Decision**: Extend existing notifications feature with FCM-specific components. Create Supabase Edge Function to handle webhook from database trigger and call FCM API.

## Complexity Tracking

> No constitution violations - section not required.

---

## Phase 0: Research (Complete)

**Output**: [research.md](./research.md)

### Key Findings

1. **Firebase/FCM Already Configured**: `firebase_core`, `firebase_messaging`, and `flutter_local_notifications` are present in pubspec.yaml
2. **Existing NotificationService**: Located at `nova/lib/core/services/notification_service.dart` - currently stores token in `user_metadata` (needs refactoring)
3. **Edge Function Pattern Established**: `log-auth-event` function provides template for webhook handling
4. **Deep Link Infrastructure**: `DeepLinkHandler` supports `nova://events/{id}/comments/{id}` format already
5. **Notification Preferences**: 6 channels already defined in profiles table with boolean toggles

### Architecture Decision

**Supabase Database Webhook → Edge Function → FCM API**

- Database trigger on `notifications` table INSERT fires webhook
- Edge Function queries `fcm_tokens` table for recipient's devices
- Edge Function sends FCM HTTP API call for each token
- Client handles foreground/background/terminated states

---

## Phase 1: Design (Complete)

**Outputs**:
- [data-model.md](./data-model.md) - `fcm_tokens` table schema, Dart entities
- [quickstart.md](./quickstart.md) - Integration scenarios and code snippets
- [contracts/edge-function-api.md](./contracts/edge-function-api.md) - Edge Function API contract

### Data Model Summary

**New Table: `fcm_tokens`**
```sql
fcm_tokens (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES profiles(user_id),
  token TEXT UNIQUE NOT NULL,
  platform TEXT CHECK ('android', 'ios'),
  device_name TEXT,
  created_at TIMESTAMPTZ,
  last_used_at TIMESTAMPTZ
)
```

**New Profile Column**: `push_enabled BOOLEAN DEFAULT TRUE` (global kill switch)

### Contract Summary

**Edge Function**: `send-push-notification`
- Triggered by: Database webhook on `notifications` INSERT
- Queries: `fcm_tokens` WHERE user_id = recipient_id
- Sends: FCM Legacy HTTP API (`https://fcm.googleapis.com/fcm/send`)
- Handles: Invalid token cleanup, badge count inclusion

---

## Implementation Phases

### Phase 1: Database & Backend Infrastructure
**Foundation for all push functionality**

1. Create `fcm_tokens` table with RLS policies
2. Add `push_enabled` column to profiles
3. Create Supabase Edge Function `send-push-notification`
4. Configure database webhook to trigger Edge Function
5. Set FCM_SERVER_KEY as Edge Function secret

### Phase 2: Flutter FCM Initialization (P1 - US1)
**User Story 1**: Ricevere Push con App Chiusa

1. Add `flutter_app_badger` dependency
2. Create `PushNotificationService` in core/services
3. Initialize FCM in main.dart with background handler
4. Create FcmToken entity and repository
5. Implement token registration on login
6. Implement token deletion on logout
7. Handle token refresh events

### Phase 3: Deep Linking from Push (P1 - US2)
**User Story 2**: Navigazione da Push a Contenuto

1. Create `PushPayload` entity for parsing FCM data
2. Implement `onMessageOpenedApp` handler (background state)
3. Implement `getInitialMessage` handler (terminated state)
4. Add navigation logic for event deep links
5. Add navigation logic for comment deep links
6. Handle deleted content gracefully (show error message)

### Phase 4: Permission Request Flow (P1 - US3)
**User Story 3**: Gestione Permessi Notifiche

1. Create pre-permission explanation screen
2. Implement iOS permission request flow
3. Implement Android 13+ permission request
4. Store permission state in SharedPreferences
5. Add "Enable notifications" link in settings for denied users
6. Add platform-adaptive UI (Cupertino/Material)

### Phase 5: Foreground Notifications (P2 - US5)
**User Story 5**: Notifiche in Foreground

1. Create `InAppNotificationBanner` widget
2. Implement `onMessage` handler for foreground state
3. Add banner animation (slide in from top, auto-dismiss)
4. Handle banner tap for navigation
5. Handle banner swipe to dismiss

### Phase 6: Badge Count Management (P3 - US6)
**User Story 6**: Aggiornamento Badge Count

1. Implement badge update on push received
2. Implement badge clear when notifications read
3. Add silent push support for badge-only updates
4. Test badge on iOS (native support)
5. Test badge on Android (best-effort via flutter_app_badger)

### Phase 7: iOS Platform Configuration

1. Enable Push Notifications capability in Xcode
2. Add Background Modes (remote-notification)
3. Generate and upload APNs key to Firebase
4. Verify GoogleService-Info.plist is in project
5. Test on physical iOS device

### Phase 8: Android Platform Configuration

1. Verify POST_NOTIFICATIONS permission in manifest
2. Create notification channel for Android 8+
3. Verify google-services.json is in project
4. Test on Android 13+ device for permission flow
5. Test on older Android devices

### Phase 9: Testing & Polish

1. Test all three app states (foreground/background/terminated)
2. Test multi-device scenario
3. Test preference respect (disabled channel = no push)
4. Test token cleanup on logout
5. Test deep link to deleted content
6. Performance test: verify <5s delivery

---

## Dependency Graph

```
Phase 1 (Database) ──┬──► Phase 2 (FCM Init) ──► Phase 3 (Deep Link)
                     │                               │
                     │                               ▼
                     │                          Phase 4 (Permissions)
                     │                               │
                     │                               ▼
                     │                          Phase 5 (Foreground)
                     │                               │
                     │                               ▼
                     └──────────────────────────► Phase 6 (Badge)

Phase 7 (iOS) ─────────┐
                       ├──► Phase 9 (Testing)
Phase 8 (Android) ─────┘
```

**Parallelization:**
- Phase 7 and Phase 8 can run in parallel
- Phase 5 and Phase 6 are independent after Phase 4

---

## Success Criteria Mapping

| Criteria | Implementation |
|----------|----------------|
| SC-001: 95% delivery <5s | FCM infrastructure + webhook + Edge Function |
| SC-002: Zero duplicates | FCM handles device deduplication |
| SC-003: 100% navigation | Deep link handlers in Phase 3 |
| SC-004: 80%+ permission accept | Pre-permission explanation in Phase 4 |
| SC-005: Badge accuracy | Badge sync in Phase 6 |
| SC-006: All app states | Handlers in Phase 2-3 |
| SC-007: Preference respect | Checked at notification creation (existing) |

---

## Next Step

Run `/speckit.tasks` to generate implementation task list based on this plan.
