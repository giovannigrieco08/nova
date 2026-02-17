# API Contract: Moderation

**Feature**: 015-ugc-safety
**Module**: Moderation Dashboard

## Overview

Moderation APIs for report management, user sanctions, and content removal.

---

## Endpoints

### 1. Get Pending Reports

**Method**: Supabase RPC
**Function**: `get_pending_reports`

```dart
final reports = await supabase.rpc('get_pending_reports', params: {
  'p_limit': 50,
  'p_offset': 0,
  'p_category': null,  // optional filter
});
```

**Parameters**:
| Name | Type | Required | Description |
|------|------|----------|-------------|
| p_limit | int | No | Max results (default 50) |
| p_offset | int | No | Pagination offset |
| p_category | string | No | Filter by category |

**Response** (200 OK):
```json
{
  "reports": [
    {
      "id": "uuid",
      "content_type": "comment",
      "content_id": "uuid",
      "category": "bullying",
      "note": "Descrizione...",
      "status": "pending",
      "created_at": "2025-02-12T10:00:00Z",
      "hours_pending": 18,
      "is_urgent": false,
      "reporter": {
        "user_id": "uuid",
        "full_name": "Luigi Verdi",
        "username": "lverdi"
      },
      "reported_user": {
        "user_id": "uuid",
        "full_name": "Mario Rossi",
        "username": "mrossi"
      },
      "content_preview": "Testo del commento..."
    }
  ],
  "total_count": 125,
  "urgent_count": 3
}
```

---

### 2. Review Report

**Method**: Supabase RPC
**Function**: `review_report`

```dart
await supabase.rpc('review_report', params: {
  'p_report_id': reportId,
  'p_action': 'content_removed',  // or 'dismissed', 'user_warned', 'user_suspended', 'user_banned'
  'p_sanction_reason': 'Violazione policy anti-bullismo',  // required for sanctions
  'p_suspension_days': null,  // required for 'user_suspended'
});
```

**Parameters**:
| Name | Type | Required | Description |
|------|------|----------|-------------|
| p_report_id | UUID | Yes | Report to review |
| p_action | string | Yes | Action to take |
| p_sanction_reason | string | Conditional | Required for sanctions |
| p_suspension_days | int | Conditional | Required for suspensions |

**Actions**:
| Action | Effect |
|--------|--------|
| `dismissed` | Mark as reviewed, no action |
| `content_removed` | Soft-delete content, mark reviewed |
| `user_warned` | Create warning sanction, notify user |
| `user_suspended` | Create suspension, block login |
| `user_banned` | Create permanent ban |

**Response** (200 OK):
```json
{
  "success": true,
  "action_taken": "content_removed",
  "sanction_id": "uuid",  // if sanction created
  "notification_sent": true  // if user was notified
}
```

**Errors**:
| Code | Condition | Message |
|------|-----------|---------|
| 403 | Not moderator | "Permesso negato" |
| 404 | Report not found | "Segnalazione non trovata" |
| 400 | Already reviewed | "Segnalazione già gestita" |

---

### 3. Get User Sanctions History

**Method**: Supabase Table Select
**Table**: `user_sanctions`

```dart
final sanctions = await supabase
    .from('user_sanctions')
    .select('''
      *,
      issued_by_user:profiles!issued_by (full_name, username)
    ''')
    .eq('user_id', targetUserId)
    .order('issued_at', ascending: false);
```

**Response** (200 OK):
```json
[
  {
    "id": "uuid",
    "type": "warning",
    "reason": "Linguaggio inappropriato",
    "issued_at": "2025-02-10T10:00:00Z",
    "expires_at": null,
    "lifted_at": null,
    "issued_by_user": {
      "full_name": "Admin Nova",
      "username": "admin"
    }
  }
]
```

---

### 4. Lift Sanction

**Method**: Supabase RPC
**Function**: `lift_sanction`

```dart
await supabase.rpc('lift_sanction', params: {
  'p_sanction_id': sanctionId,
});
```

**Response** (200 OK):
```json
{
  "success": true,
  "lifted_at": "2025-02-12T10:00:00Z"
}
```

---

### 5. Get Moderation Statistics

**Method**: Supabase RPC
**Function**: `get_moderation_stats`

```dart
final stats = await supabase.rpc('get_moderation_stats');
```

**Response** (200 OK):
```json
{
  "pending_reports": 45,
  "urgent_reports": 3,
  "reports_today": 12,
  "reports_this_week": 87,
  "avg_resolution_hours": 4.2,
  "actions_by_type": {
    "dismissed": 120,
    "content_removed": 45,
    "user_warned": 15,
    "user_suspended": 5,
    "user_banned": 2
  }
}
```

---

## SQL Functions

### get_pending_reports

```sql
CREATE OR REPLACE FUNCTION get_pending_reports(
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0,
  p_category TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result JSONB;
BEGIN
  -- Verify moderator role
  IF NOT EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
    AND role IN ('moderator', 'admin')
  ) THEN
    RAISE EXCEPTION 'Permesso negato';
  END IF;

  WITH pending AS (
    SELECT
      r.*,
      EXTRACT(EPOCH FROM (NOW() - r.created_at)) / 3600 AS hours_pending,
      EXTRACT(EPOCH FROM (NOW() - r.created_at)) / 3600 > 20 AS is_urgent,
      reporter.full_name AS reporter_name,
      reporter.username AS reporter_username
    FROM reports r
    JOIN profiles reporter ON r.reporter_id = reporter.user_id
    WHERE r.status = 'pending'
    AND (p_category IS NULL OR r.category = p_category)
    ORDER BY r.created_at ASC
    LIMIT p_limit OFFSET p_offset
  )
  SELECT jsonb_build_object(
    'reports', COALESCE(jsonb_agg(row_to_json(pending)), '[]'::jsonb),
    'total_count', (SELECT COUNT(*) FROM reports WHERE status = 'pending'),
    'urgent_count', (SELECT COUNT(*) FROM reports WHERE status = 'pending' AND created_at < NOW() - INTERVAL '20 hours')
  ) INTO result
  FROM pending;

  RETURN result;
END;
$$;
```

### review_report

```sql
CREATE OR REPLACE FUNCTION review_report(
  p_report_id UUID,
  p_action TEXT,
  p_sanction_reason TEXT DEFAULT NULL,
  p_suspension_days INT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  report_record RECORD;
  sanction_id UUID;
  content_owner_id UUID;
BEGIN
  -- Verify moderator role
  IF NOT EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
    AND role IN ('moderator', 'admin')
  ) THEN
    RAISE EXCEPTION 'Permesso negato';
  END IF;

  -- Get report
  SELECT * INTO report_record
  FROM reports
  WHERE id = p_report_id
  FOR UPDATE NOWAIT;

  IF report_record IS NULL THEN
    RAISE EXCEPTION 'Segnalazione non trovata';
  END IF;

  IF report_record.status != 'pending' THEN
    RAISE EXCEPTION 'Segnalazione già gestita';
  END IF;

  -- Get content owner
  IF report_record.content_type = 'comment' THEN
    SELECT user_id INTO content_owner_id FROM comments WHERE id = report_record.content_id;
  ELSIF report_record.content_type = 'chat_message' THEN
    SELECT user_id INTO content_owner_id FROM chat_messages WHERE id = report_record.content_id;
  ELSIF report_record.content_type = 'event' THEN
    SELECT creator_id INTO content_owner_id FROM events WHERE id = report_record.content_id;
  ELSIF report_record.content_type = 'profile' THEN
    content_owner_id := report_record.content_id;
  END IF;

  -- Execute action
  IF p_action = 'content_removed' THEN
    PERFORM remove_content(report_record.content_type, report_record.content_id);
  ELSIF p_action IN ('user_warned', 'user_suspended', 'user_banned') THEN
    INSERT INTO user_sanctions (user_id, type, reason, related_report_id, issued_by, expires_at)
    VALUES (
      content_owner_id,
      CASE p_action
        WHEN 'user_warned' THEN 'warning'
        WHEN 'user_suspended' THEN 'suspension'
        WHEN 'user_banned' THEN 'ban'
      END,
      p_sanction_reason,
      p_report_id,
      auth.uid(),
      CASE WHEN p_action = 'user_suspended' THEN NOW() + (p_suspension_days || ' days')::INTERVAL ELSE NULL END
    )
    RETURNING id INTO sanction_id;

    -- Remove content as well
    PERFORM remove_content(report_record.content_type, report_record.content_id);
  END IF;

  -- Update report
  UPDATE reports
  SET
    status = CASE WHEN p_action = 'dismissed' THEN 'dismissed' ELSE 'action_taken' END,
    action_taken = p_action,
    reviewed_by = auth.uid(),
    reviewed_at = NOW()
  WHERE id = p_report_id;

  RETURN jsonb_build_object(
    'success', TRUE,
    'action_taken', p_action,
    'sanction_id', sanction_id,
    'notification_sent', TRUE
  );
END;
$$;
```

---

## Email Notifications

### Urgent Reports Digest

**Trigger**: Scheduled Edge Function every 4 hours
**Recipients**: All users with moderator/admin role

```typescript
// supabase/functions/send-urgent-reports-digest/index.ts
import { createClient } from '@supabase/supabase-js'
import { Resend } from 'resend'

Deno.serve(async () => {
  const supabase = createClient(...)
  const resend = new Resend(Deno.env.get('RESEND_API_KEY'))

  // Get urgent reports (>20h pending)
  const { data: urgentReports } = await supabase
    .from('reports')
    .select('*')
    .eq('status', 'pending')
    .lt('created_at', new Date(Date.now() - 20 * 60 * 60 * 1000).toISOString())

  if (urgentReports.length === 0) return new Response('No urgent reports')

  // Get moderator emails
  const { data: moderators } = await supabase
    .from('user_roles')
    .select('user_id, profiles!inner(email)')
    .in('role', ['moderator', 'admin'])

  // Send digest
  for (const mod of moderators) {
    await resend.emails.send({
      from: 'Nova <noreply@nova-app.it>',
      to: mod.profiles.email,
      subject: `⚠️ ${urgentReports.length} segnalazioni urgenti`,
      html: `...`
    })
  }

  return new Response('Digest sent')
})
```

---

## UI Integration Notes

### Dashboard Layout

1. **Header**: Stats summary (pending, urgent, today)
2. **Filters**: Category dropdown, urgency toggle
3. **Report List**: Cards with preview, reporter, time pending
4. **Urgent Badge**: Red indicator for >20h pending
5. **Action Buttons**: Dismiss, Remove, Warn, Suspend, Ban
6. **Confirmation Modal**: For sanctions (requires reason input)

### Mobile Admin (Future)

Accessible via in-app Settings for moderators:
- Simplified report review
- Quick actions (dismiss/remove)
- Push notification for urgent reports
