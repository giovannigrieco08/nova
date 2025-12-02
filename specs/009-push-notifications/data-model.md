# Data Model: Push Notifications

**Feature**: 009-push-notifications
**Date**: 2025-11-30
**Status**: Design Complete

## Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        PUSH NOTIFICATIONS ERD                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────┐         ┌─────────────────┐                   │
│  │    profiles     │         │   fcm_tokens    │                   │
│  ├─────────────────┤         ├─────────────────┤                   │
│  │ user_id (PK)    │────┐    │ id (PK)         │                   │
│  │ full_name       │    │    │ user_id (FK)  ◄─┘                   │
│  │ ...             │    │    │ token (UNIQUE)  │                   │
│  │ push_enabled*   │    │    │ platform        │                   │
│  └─────────────────┘    │    │ device_name     │                   │
│                         │    │ created_at      │                   │
│  ┌─────────────────┐    │    │ last_used_at    │                   │
│  │  notifications  │    │    └─────────────────┘                   │
│  ├─────────────────┤    │                                          │
│  │ id (PK)         │    │    * New column to be added              │
│  │ recipient_id ◄──┘    │                                          │
│  │ type            │                                                │
│  │ title           │    Relationship: 1 user → N tokens            │
│  │ description     │    (multi-device support)                     │
│  │ target_type     │                                                │
│  │ target_id       │                                                │
│  │ is_read         │                                                │
│  │ created_at      │                                                │
│  └─────────────────┘                                                │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## New Table: fcm_tokens

### Schema Definition

```sql
CREATE TABLE fcm_tokens (
  -- Primary key
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Foreign key to profiles
  user_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,

  -- FCM token (unique per device)
  token TEXT UNIQUE NOT NULL,

  -- Platform identifier
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),

  -- Device name (for user-facing UI, e.g., "iPhone di Mario")
  device_name TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_used_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Table comment
COMMENT ON TABLE fcm_tokens IS 'Firebase Cloud Messaging tokens for push notification delivery';
```

### Column Details

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PK, auto-generated | Unique identifier |
| `user_id` | UUID | FK → profiles, NOT NULL | User who owns this token |
| `token` | TEXT | UNIQUE, NOT NULL | FCM registration token |
| `platform` | TEXT | CHECK (android/ios) | Device platform |
| `device_name` | TEXT | nullable | Human-readable device name |
| `created_at` | TIMESTAMPTZ | NOT NULL, default NOW() | Token registration time |
| `last_used_at` | TIMESTAMPTZ | NOT NULL, default NOW() | Last successful push sent |

### Indexes

```sql
-- Index for querying user's tokens (used by Edge Function)
CREATE INDEX idx_fcm_tokens_user_id ON fcm_tokens(user_id);

-- Index for token cleanup job (stale tokens)
CREATE INDEX idx_fcm_tokens_last_used ON fcm_tokens(last_used_at);
```

### Row-Level Security

```sql
ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Users can view their own tokens
CREATE POLICY "Users can view own tokens"
  ON fcm_tokens FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own tokens
CREATE POLICY "Users can insert own tokens"
  ON fcm_tokens FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own tokens
CREATE POLICY "Users can update own tokens"
  ON fcm_tokens FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can delete their own tokens
CREATE POLICY "Users can delete own tokens"
  ON fcm_tokens FOR DELETE
  USING (auth.uid() = user_id);
```

## Extended Profile Column

### New Column: push_enabled

```sql
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS push_enabled BOOLEAN NOT NULL DEFAULT TRUE;

COMMENT ON COLUMN profiles.push_enabled IS 'Master toggle for push notifications (overrides all channels)';
```

**Purpose:** Global kill switch for push notifications. When false, no push is sent regardless of individual channel preferences.

## Dart Entity: FcmToken

```dart
/// FCM token entity for push notifications
///
/// Represents a device registration for receiving push notifications.
/// One user can have multiple tokens (multi-device support).
class FcmToken {
  /// Unique identifier
  final String id;

  /// User who owns this token
  final String userId;

  /// FCM registration token (device-specific)
  final String token;

  /// Platform: 'android' or 'ios'
  final String platform;

  /// Human-readable device name (e.g., "iPhone di Mario")
  final String? deviceName;

  /// When token was registered
  final DateTime createdAt;

  /// Last successful push delivery
  final DateTime lastUsedAt;

  const FcmToken({
    required this.id,
    required this.userId,
    required this.token,
    required this.platform,
    this.deviceName,
    required this.createdAt,
    required this.lastUsedAt,
  });

  factory FcmToken.fromJson(Map<String, dynamic> json) => FcmToken(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    token: json['token'] as String,
    platform: json['platform'] as String,
    deviceName: json['device_name'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    lastUsedAt: DateTime.parse(json['last_used_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'token': token,
    'platform': platform,
    'device_name': deviceName,
    'created_at': createdAt.toIso8601String(),
    'last_used_at': lastUsedAt.toIso8601String(),
  };
}
```

## Dart Entity: PushPayload

```dart
/// Push notification payload structure
///
/// Used for both sending (Edge Function) and receiving (Flutter app).
class PushPayload {
  /// Notification title (displayed in system tray)
  final String title;

  /// Notification body text
  final String body;

  /// Navigation target type: 'event' or 'comment'
  final String targetType;

  /// Navigation target ID
  final String targetId;

  /// Reference to in-app notification (for marking as read)
  final String notificationId;

  /// Current unread count (for badge update)
  final int badgeCount;

  /// Optional metadata
  final Map<String, dynamic>? metadata;

  const PushPayload({
    required this.title,
    required this.body,
    required this.targetType,
    required this.targetId,
    required this.notificationId,
    required this.badgeCount,
    this.metadata,
  });

  /// Parse from FCM RemoteMessage data
  factory PushPayload.fromFcmData(Map<String, dynamic> data) => PushPayload(
    title: data['title'] as String? ?? 'Nova',
    body: data['body'] as String? ?? '',
    targetType: data['target_type'] as String? ?? 'event',
    targetId: data['target_id'] as String? ?? '',
    notificationId: data['notification_id'] as String? ?? '',
    badgeCount: int.tryParse(data['badge_count']?.toString() ?? '0') ?? 0,
    metadata: data['metadata'] != null
      ? Map<String, dynamic>.from(data['metadata'] as Map)
      : null,
  );

  /// Convert to FCM data payload
  Map<String, String> toFcmData() => {
    'title': title,
    'body': body,
    'target_type': targetType,
    'target_id': targetId,
    'notification_id': notificationId,
    'badge_count': badgeCount.toString(),
    if (metadata != null) 'metadata': metadata.toString(),
  };
}
```

## Dart Enum: NotificationPermissionState

```dart
/// Push notification permission state
enum NotificationPermissionState {
  /// User hasn't been asked yet
  notDetermined,

  /// User granted permission
  granted,

  /// User denied permission
  denied,

  /// Permission permanently denied (must go to settings)
  permanentlyDenied,
}
```

## Database Trigger: Push Notification Webhook

The webhook is configured via Supabase Dashboard, not SQL:

```
Webhook Configuration:
- Table: notifications
- Event: INSERT
- URL: https://<project-ref>.supabase.co/functions/v1/send-push-notification
- Headers: Authorization: Bearer <service_role_key>
- Payload: { "type": "INSERT", "record": <row>, "schema": "public", "table": "notifications" }
```

## Data Flow Summary

```
1. Event triggers notification
   └── INSERT INTO notifications (via create_notification())

2. Database webhook fires
   └── POST to send-push-notification Edge Function

3. Edge Function queries tokens
   └── SELECT * FROM fcm_tokens WHERE user_id = recipient_id

4. Edge Function sends FCM
   └── POST to https://fcm.googleapis.com/fcm/send

5. Device receives push
   └── firebase_messaging handles in Flutter

6. User taps notification
   └── Navigate to target using PushPayload data
```

## Migration Script Location

**File**: `supabase/migrations/009_push_notifications.sql`

This migration will:
1. Create `fcm_tokens` table
2. Add `push_enabled` column to profiles
3. Create RLS policies
4. Create indexes
5. Create token cleanup function (weekly job)
