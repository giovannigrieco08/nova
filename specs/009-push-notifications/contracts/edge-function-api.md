# API Contract: Push Notification Edge Function

**Feature**: 009-push-notifications
**Type**: Supabase Edge Function
**Date**: 2025-11-30

## Function: send-push-notification

### Endpoint

```
POST https://<project-ref>.supabase.co/functions/v1/send-push-notification
```

### Authentication

- **Type**: Service Role Key (Bearer token)
- **Header**: `Authorization: Bearer <service_role_key>`
- **Note**: Only called by database webhook, not client apps

### Request

**Triggered by**: Database webhook on `notifications` table INSERT

**Content-Type**: `application/json`

**Body Schema**:
```typescript
interface WebhookPayload {
  type: 'INSERT';
  table: 'notifications';
  schema: 'public';
  record: NotificationRecord;
  old_record: null; // Always null for INSERT
}

interface NotificationRecord {
  id: string;           // UUID
  recipient_id: string; // UUID - user to receive push
  sender_id: string | null; // UUID - who triggered notification
  type: NotificationType;
  title: string;
  description: string;
  target_type: 'event' | 'comment';
  target_id: string;    // UUID
  metadata: Record<string, unknown>;
  is_read: boolean;
  created_at: string;   // ISO 8601 timestamp
}

type NotificationType =
  | 'event_moderation'
  | 'new_comment'
  | 'comment_reply'
  | 'event_like'
  | 'event_participation'
  | 'coorganizer_update';
```

**Example Request**:
```json
{
  "type": "INSERT",
  "table": "notifications",
  "schema": "public",
  "record": {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "recipient_id": "user-uuid-here",
    "sender_id": "sender-uuid-here",
    "type": "new_comment",
    "title": "Mario ha commentato sul tuo evento",
    "description": "Che bella idea! Ci sarò sicuramente...",
    "target_type": "event",
    "target_id": "event-uuid-here",
    "metadata": {
      "comment_id": "comment-uuid-here"
    },
    "is_read": false,
    "created_at": "2025-11-30T10:30:00Z"
  },
  "old_record": null
}
```

### Response

**Success (200 OK)**:
```json
{
  "success": true,
  "message": "Push notifications sent",
  "results": {
    "tokens_found": 2,
    "sent": 2,
    "failed": 0
  }
}
```

**No Tokens (200 OK)**:
```json
{
  "success": true,
  "message": "No FCM tokens found for user",
  "results": {
    "tokens_found": 0,
    "sent": 0,
    "failed": 0
  }
}
```

**Push Disabled (200 OK)**:
```json
{
  "success": true,
  "message": "Push notifications disabled for user",
  "results": {
    "tokens_found": 0,
    "sent": 0,
    "failed": 0,
    "skipped_reason": "push_disabled"
  }
}
```

**Error (500 Internal Server Error)**:
```json
{
  "success": false,
  "error": "Failed to send push notifications",
  "details": "FCM API returned error: QuotaExceeded"
}
```

### Internal Logic

```typescript
// Pseudocode for Edge Function
async function handleWebhook(payload: WebhookPayload) {
  const notification = payload.record;

  // 1. Check if user has push enabled
  const { data: profile } = await supabase
    .from('profiles')
    .select('push_enabled')
    .eq('user_id', notification.recipient_id)
    .single();

  if (!profile?.push_enabled) {
    return { success: true, message: 'Push disabled' };
  }

  // 2. Get all FCM tokens for recipient
  const { data: tokens } = await supabase
    .from('fcm_tokens')
    .select('token, platform')
    .eq('user_id', notification.recipient_id);

  if (!tokens?.length) {
    return { success: true, message: 'No tokens' };
  }

  // 3. Get unread count for badge
  const { count } = await supabase
    .from('notifications')
    .select('*', { count: 'exact', head: true })
    .eq('recipient_id', notification.recipient_id)
    .eq('is_read', false);

  // 4. Send to each token
  const results = await Promise.all(
    tokens.map(({ token }) => sendFcm(token, notification, count))
  );

  // 5. Handle invalid tokens (remove from DB)
  for (const result of results) {
    if (result.error?.includes('invalid-registration-token')) {
      await supabase
        .from('fcm_tokens')
        .delete()
        .eq('token', result.token);
    }
  }

  return { success: true, results };
}
```

---

## FCM API Contract (called by Edge Function)

### Endpoint

```
POST https://fcm.googleapis.com/fcm/send
```

### Authentication

- **Type**: Server Key
- **Header**: `Authorization: key=<FCM_SERVER_KEY>`

### Request Body

```typescript
interface FcmRequest {
  to: string; // FCM token
  notification: {
    title: string;
    body: string;
    sound: 'default';
    badge?: number; // iOS only
  };
  data: {
    target_type: string;
    target_id: string;
    notification_id: string;
    badge_count: string;
    click_action: 'FLUTTER_NOTIFICATION_CLICK';
  };
  apns?: {
    payload: {
      aps: {
        'mutable-content': 1;
        'content-available': 1;
      };
    };
  };
  android?: {
    priority: 'high';
    notification: {
      channel_id: 'nova_notifications';
    };
  };
}
```

**Example**:
```json
{
  "to": "fMJr_ABC123...",
  "notification": {
    "title": "Mario ha commentato sul tuo evento",
    "body": "Che bella idea! Ci sarò sicuramente...",
    "sound": "default",
    "badge": 5
  },
  "data": {
    "target_type": "event",
    "target_id": "event-uuid-here",
    "notification_id": "notif-uuid-here",
    "badge_count": "5",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  },
  "apns": {
    "payload": {
      "aps": {
        "mutable-content": 1,
        "content-available": 1
      }
    }
  },
  "android": {
    "priority": "high",
    "notification": {
      "channel_id": "nova_notifications"
    }
  }
}
```

### FCM Response

**Success**:
```json
{
  "multicast_id": 1234567890,
  "success": 1,
  "failure": 0,
  "results": [
    { "message_id": "0:1234567890%abc123" }
  ]
}
```

**Invalid Token**:
```json
{
  "multicast_id": 1234567890,
  "success": 0,
  "failure": 1,
  "results": [
    { "error": "InvalidRegistration" }
  ]
}
```

---

## Client API: FCM Token Management

### Register Token

**Endpoint**: Supabase REST API
```
POST /rest/v1/fcm_tokens
```

**Headers**:
```
Authorization: Bearer <user_jwt>
apikey: <anon_key>
Content-Type: application/json
Prefer: return=representation
```

**Body**:
```json
{
  "user_id": "current-user-uuid",
  "token": "fMJr_ABC123...",
  "platform": "android",
  "device_name": "Pixel 7 di Mario"
}
```

**Response (201 Created)**:
```json
{
  "id": "token-uuid",
  "user_id": "current-user-uuid",
  "token": "fMJr_ABC123...",
  "platform": "android",
  "device_name": "Pixel 7 di Mario",
  "created_at": "2025-11-30T10:00:00Z",
  "last_used_at": "2025-11-30T10:00:00Z"
}
```

### Delete Token (Logout)

**Endpoint**:
```
DELETE /rest/v1/fcm_tokens?token=eq.fMJr_ABC123...
```

**Headers**:
```
Authorization: Bearer <user_jwt>
apikey: <anon_key>
```

**Response**: `204 No Content`

### Upsert Token (Token Refresh)

**Endpoint**:
```
POST /rest/v1/fcm_tokens
```

**Headers**:
```
Prefer: resolution=merge-duplicates
```

Uses `token` UNIQUE constraint for upsert behavior.

---

## Silent Push Contract (Badge Update)

For updating badge without visible notification:

```json
{
  "to": "fMJr_ABC123...",
  "content_available": true,
  "data": {
    "type": "badge_update",
    "badge_count": "5"
  },
  "apns": {
    "payload": {
      "aps": {
        "content-available": 1
      }
    }
  }
}
```

Flutter handler receives this in `onBackgroundMessage` and updates badge.
