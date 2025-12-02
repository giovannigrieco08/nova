# Push Notification Webhook Setup

**Feature**: 009-push-notifications
**Date**: 2025-11-30

## Overview

This document describes how to configure the database webhook that triggers push notifications when new in-app notifications are created.

## Prerequisites

1. **Edge Function Deployed**: `send-push-notification` must be deployed
2. **FCM Server Key**: Must be set as an Edge Function secret
3. **Database Migration**: `011_push_notifications.sql` must be applied

## Step 1: Set FCM Server Key

Get your FCM server key from Firebase Console:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (Nova)
3. Go to Project Settings → Cloud Messaging
4. Copy the "Server key" (Legacy server key)

Set it as a Supabase secret:
```bash
npx supabase secrets set FCM_SERVER_KEY=<your-server-key>
```

## Step 2: Deploy Edge Function

Deploy the `send-push-notification` Edge Function:

```bash
npx supabase functions deploy send-push-notification
```

Verify deployment:
```bash
npx supabase functions list
```

## Step 3: Configure Database Webhook

### Via Supabase Dashboard

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Navigate to **Database** → **Webhooks**
4. Click **Create a new webhook**

### Webhook Configuration

| Field | Value |
|-------|-------|
| **Name** | `push-notification-webhook` |
| **Table** | `notifications` |
| **Schema** | `public` |
| **Events** | `INSERT` only |
| **Type** | `Supabase Edge Functions` |
| **Function** | `send-push-notification` |

### Advanced Settings

- **HTTP Method**: POST (automatic)
- **Timeout**: 10 seconds (default)
- **HTTP Headers**: Automatically set by Supabase for Edge Functions

## Step 4: Test the Webhook

### Manual Test via SQL

Create a test notification:
```sql
INSERT INTO notifications (
  recipient_id,
  sender_id,
  type,
  title,
  description,
  target_type,
  target_id,
  metadata
) VALUES (
  '<your-user-id>',
  '<sender-user-id>',
  'new_comment',
  'Test Push Notification',
  'This is a test push notification',
  'event',
  '<event-id>',
  '{}'::jsonb
);
```

### Check Edge Function Logs

```bash
npx supabase functions logs send-push-notification
```

Expected log output:
```
📥 Webhook received: { type: 'INSERT', table: 'notifications', ... }
📱 Found 1 FCM token(s) for user: ...
📤 Sending FCM to: { token: '...', platform: 'android', ... }
✅ FCM sent successfully: ...
✅ Push notification send complete: { ... }
```

## Troubleshooting

### No push received

1. **Check FCM token exists**: Query `fcm_tokens` table for the recipient
2. **Check push_enabled**: Verify `profiles.push_enabled = true` for recipient
3. **Check Edge Function logs**: Look for errors in function execution
4. **Check FCM_SERVER_KEY**: Ensure secret is set correctly

### "No FCM tokens found"

User hasn't registered a token. This happens when:
- App hasn't been opened after login
- User denied notification permissions
- Token registration failed

### "Push notifications disabled"

User has `push_enabled = false` in their profile. This is intentional - respect user preference.

### Invalid token errors

Tokens are automatically cleaned up. Common reasons:
- User uninstalled the app
- Token expired (rare)
- User reinstalled app (new token generated)

## Payload Structure

The webhook sends this payload to the Edge Function:

```json
{
  "type": "INSERT",
  "table": "notifications",
  "schema": "public",
  "record": {
    "id": "uuid",
    "recipient_id": "uuid",
    "sender_id": "uuid",
    "type": "new_comment",
    "title": "Notification title",
    "description": "Notification body",
    "target_type": "event",
    "target_id": "uuid",
    "metadata": {},
    "is_read": false,
    "created_at": "2025-11-30T10:00:00Z"
  },
  "old_record": null
}
```

## Security Considerations

1. **Service Role Key**: The webhook uses the service role key automatically
2. **RLS Bypassed**: Edge Function runs with service role, bypassing RLS
3. **FCM Server Key**: Never expose in client code; only in Edge Function secrets
4. **Token Privacy**: FCM tokens are not logged in full (truncated in logs)

## Monitoring

### Key Metrics to Monitor

1. **Push delivery rate**: Track `sent` vs `failed` in response
2. **Invalid token rate**: Track `invalid_tokens_cleaned`
3. **Function duration**: Track `duration_ms` for performance
4. **Error rate**: Monitor 500 responses

### Log Analysis

Use Edge Function logs to analyze patterns:
```bash
npx supabase functions logs send-push-notification --limit 100
```

## Rollback

To disable push notifications:

1. **Disable webhook** in Supabase Dashboard (don't delete)
2. Or set all users' `push_enabled = false`:
   ```sql
   UPDATE profiles SET push_enabled = false;
   ```

To re-enable, reverse the above steps.
