# Technical Research: Push Notifications

**Feature**: 009-push-notifications
**Date**: 2025-11-30
**Status**: Research Complete

## Executive Summary

Push notifications for Nova will leverage Firebase Cloud Messaging (FCM) for cross-platform delivery, integrated with Supabase Edge Functions for server-side triggering. The existing in-app notification system (008-realtime-notifications) provides the foundation - push notifications extend this to reach users when the app is closed.

## Architecture Decision

### Approach: Supabase Database Webhook + Edge Function + FCM

```
┌─────────────────────────────────────────────────────────────────────┐
│                        PUSH NOTIFICATION FLOW                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. Notification Created        2. Webhook Triggered                │
│  ┌──────────────────┐          ┌──────────────────┐                │
│  │ notifications    │  ──────▶ │ Database Webhook │                │
│  │ table INSERT     │          │ (Supabase)       │                │
│  └──────────────────┘          └────────┬─────────┘                │
│                                         │                          │
│  3. Edge Function Called       4. FCM API Called                   │
│  ┌──────────────────┐          ┌──────────────────┐                │
│  │ send-push        │  ──────▶ │ Firebase Cloud   │                │
│  │ Edge Function    │          │ Messaging        │                │
│  └──────────────────┘          └────────┬─────────┘                │
│                                         │                          │
│  5. Push Delivered                                                  │
│  ┌──────────────────┐          ┌──────────────────┐                │
│  │ Android (FCM)    │          │ iOS (APNs)       │                │
│  └──────────────────┘          └──────────────────┘                │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**Why this approach over alternatives:**

| Alternative | Rejected Because |
|-------------|------------------|
| Supabase Realtime only | Doesn't work with app terminated |
| Firebase Functions | Requires separate Firebase project management |
| Direct FCM from app | Security risk (FCM server key exposed) |
| Third-party service (OneSignal) | Extra vendor dependency, GDPR concerns |

## Technical Findings

### 1. FCM Token Management

**Token Lifecycle:**
1. App startup → Get FCM token via `FirebaseMessaging.instance.getToken()`
2. Token stored in `fcm_tokens` table linked to user
3. Token refresh → `onTokenRefresh` stream triggers update
4. Logout → Token deleted from database
5. Invalid token → FCM returns error → Token removed

**Multi-device Support:**
- Users may have multiple devices (phone + tablet)
- Store multiple tokens per user_id
- Send push to ALL user tokens (FCM handles deduplication)

**Token Table Design:**
```sql
fcm_tokens (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES profiles(user_id),
  token TEXT UNIQUE NOT NULL,
  platform TEXT CHECK (platform IN ('android', 'ios')),
  created_at TIMESTAMPTZ,
  last_used_at TIMESTAMPTZ
)
```

### 2. Supabase Edge Function

**Function: `send-push-notification`**

Triggered by database webhook when notification is inserted:

```typescript
// Deno Edge Function
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY')!

Deno.serve(async (req) => {
  const { record } = await req.json() // notification row

  // Get FCM tokens for recipient
  const supabase = createClient(...)
  const { data: tokens } = await supabase
    .from('fcm_tokens')
    .select('token, platform')
    .eq('user_id', record.recipient_id)

  // Send to each device
  for (const { token, platform } of tokens) {
    await sendFCM(token, {
      title: record.title,
      body: record.description,
      data: {
        target_type: record.target_type,
        target_id: record.target_id,
        notification_id: record.id
      }
    })
  }
})
```

### 3. Flutter FCM Integration

**Existing Dependencies (already in pubspec.yaml):**
```yaml
firebase_core: ^2.24.0
firebase_messaging: ^14.7.0
flutter_local_notifications: ^17.0.0
```

**Three App States Handling:**

| State | Handler | Behavior |
|-------|---------|----------|
| Foreground | `FirebaseMessaging.onMessage` | Show in-app banner |
| Background | `FirebaseMessaging.onMessageOpenedApp` | Navigate on tap |
| Terminated | `FirebaseMessaging.getInitialMessage()` | Navigate on cold start |

**Permission Request Strategy (iOS):**
1. Show pre-permission dialog explaining value
2. If user agrees, trigger iOS permission request
3. Store permission state in SharedPreferences
4. Provide settings link if denied

### 4. Deep Linking from Push

**Payload Structure:**
```json
{
  "notification": {
    "title": "Nuovo commento sul tuo evento",
    "body": "Mario ha commentato su \"Festa di Fine Anno\""
  },
  "data": {
    "target_type": "event",
    "target_id": "uuid-of-event",
    "notification_id": "uuid-of-notification",
    "action": "open_comments"
  }
}
```

**Navigation Logic (already exists for in-app):**
```dart
void _navigateToTarget(String targetType, String targetId) {
  if (targetType == 'event') {
    context.push('/events/$targetId');
  } else if (targetType == 'comment') {
    final eventId = metadata['event_id'];
    context.push('/events/$eventId?commentId=$targetId');
  }
}
```

### 5. Badge Count Management

**iOS Badge:**
- Set via `FlutterAppBadger.updateBadgeCount(count)`
- Clear via `FlutterAppBadger.removeBadge()`
- Silent push can update badge without alert

**Android Badge:**
- Not natively supported (manufacturer-dependent)
- Use `flutter_app_badger` package for best-effort support
- Falls back gracefully on unsupported devices

**Badge Count Sync:**
- Badge = unread notification count from `notifications` table
- Update badge on: new push, mark as read, open app
- Edge Function includes `badge_count` in payload

### 6. User Preference Respect

**Existing Preferences (from 008):**
```sql
profiles.eventi_moderati_enabled
profiles.nuovi_commenti_enabled
profiles.risposte_commenti_enabled
profiles.like_eventi_enabled
profiles.nuove_partecipazioni_enabled
profiles.coorganizer_updates_enabled
```

**Check Flow in Edge Function:**
1. Notification inserted → webhook fires
2. Edge Function receives notification data
3. Query user preferences from profiles
4. If preference disabled → skip FCM call
5. If enabled → send push

**Note:** The existing `create_notification()` function already checks preferences before inserting. Edge Function should NOT duplicate this check - if notification exists, it means user wants it.

### 7. Rate Limiting & Deduplication

**Deduplication Strategy:**
- Existing `create_notification()` prevents self-notifications
- FCM handles device-level deduplication
- No additional deduplication needed (each notification = one push)

**Rate Limiting (optional, future):**
- Consider rate limiting if users complain about too many pushes
- Potential: max 10 pushes per hour per user
- Implementation: Add `push_count` column with hourly reset

### 8. Error Handling

**FCM Error Codes to Handle:**

| Error | Action |
|-------|--------|
| `messaging/invalid-registration-token` | Delete token from database |
| `messaging/registration-token-not-registered` | Delete token from database |
| `messaging/quota-exceeded` | Retry with exponential backoff |
| `messaging/server-unavailable` | Retry with exponential backoff |

**Token Cleanup:**
- Invalid tokens removed immediately on error
- Stale tokens (no `last_used_at` update for 30 days) cleaned weekly

## Security Considerations

### Secrets Management
- FCM Server Key stored in Supabase Edge Function secrets
- Never exposed to client
- Rotated annually or on suspected compromise

### RLS Policies
- `fcm_tokens` table: users can only manage their own tokens
- Webhook bypasses RLS (SECURITY DEFINER pattern)

### Token Security
- FCM tokens are device-specific, not user credentials
- Leaked token = spam risk, not data breach
- Still treated as sensitive (not logged)

## Performance Analysis

**Latency Budget (target: <5 seconds):**

| Step | Expected Time |
|------|--------------|
| DB INSERT + trigger | ~50ms |
| Webhook to Edge Function | ~100ms |
| Edge Function execution | ~200ms |
| FCM API call | ~200ms |
| FCM to device delivery | ~500-2000ms |
| **Total** | **~1-3 seconds** |

**Within 5-second target for 95%+ of cases.**

## Dependencies

### New Dependencies Required
```yaml
flutter_app_badger: ^1.6.0  # Badge count management
```

### Existing Dependencies (already present)
- `firebase_core: ^2.24.0`
- `firebase_messaging: ^14.7.0`
- `flutter_local_notifications: ^17.0.0`

### Supabase Requirements
- Edge Functions (free tier includes 500k invocations/month)
- Database Webhooks (built-in feature)
- Secrets management for FCM_SERVER_KEY

## iOS-Specific Requirements

### APNs Configuration
1. Enable Push Notifications capability in Xcode
2. Generate APNs key in Apple Developer Portal
3. Upload APNs key to Firebase Console
4. Add `GoogleService-Info.plist` to iOS project

### Info.plist Entries
```xml
<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>remote-notification</string>
</array>
```

### Permission Request (iOS 10+)
```dart
await FirebaseMessaging.instance.requestPermission(
  alert: true,
  badge: true,
  sound: true,
);
```

## Android-Specific Requirements

### Manifest Entries (already configured)
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

### Android 13+ Permission
- Runtime permission required for Android 13+
- `permission_handler` package can request this
- OR use `firebase_messaging` built-in request

## Testing Strategy

### Manual Testing
1. Login on device, verify token saved
2. Trigger notification via another account
3. Verify push received in all three states
4. Tap notification, verify navigation
5. Disable preference, verify no push

### Automated Testing
- Unit tests for navigation logic
- Integration tests for token CRUD
- Mock FCM for Edge Function testing

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| FCM quota exceeded | Low | Medium | Monitor usage, upgrade plan if needed |
| APNs certificate expiry | Medium | High | Set calendar reminder 30 days before |
| Users deny permissions | Medium | Low | Clear value proposition in pre-permission |
| Token rotation issues | Low | Medium | Robust error handling, auto-retry |

## Conclusion

Push notifications are technically feasible with the existing stack. Firebase Cloud Messaging provides reliable cross-platform delivery. Supabase Edge Functions enable secure server-side sending. The main work is:

1. **Database**: Add `fcm_tokens` table
2. **Edge Function**: Create `send-push-notification` function
3. **Flutter**: Initialize FCM, handle tokens, process incoming pushes
4. **iOS**: Configure APNs certificates
5. **UI**: Add permission request flow, foreground banners

Estimated implementation: 15-20 tasks across 4-5 phases.
