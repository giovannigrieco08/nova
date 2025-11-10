# Supabase REST API Contract: Event Creation and Moderation

**Feature**: 004-event-creation-moderation
**Backend**: Supabase PostgREST
**Authentication**: Supabase Auth JWT (Bearer token)
**Base URL**: `https://{project-id}.supabase.co/rest/v1`

---

## Authentication

All requests require JWT token from Supabase Auth:

```http
Authorization: Bearer {access_token}
```

---

## Endpoints

### 1. Create Event (Student)

**Endpoint**: `POST /events`

**Purpose**: Student creates a new school event (FR-001, FR-002)

**Request Headers**:
```
Authorization: Bearer {jwt_token}
Content-Type: application/json
Prefer: return=representation
```

**Request Body**:
```json
{
  "title": "Torneo di Calcetto",
  "description": "Torneo di calcetto inter-classe. Tutti i livelli sono benvenuti! Porta le tue scarpe da calcio.",
  "event_date": "2025-02-15T14:30:00Z",
  "location": "Campo sportivo dietro la scuola",
  "image_url": "https://{project}.supabase.co/storage/v1/object/public/event-images/{uuid}_{timestamp}.webp",
  "creator_id": "{auth.uid()}",
  "co_organizers": [],
  "status": "pending"
}
```

**Response**: `201 Created`
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "Torneo di Calcetto",
  "description": "Torneo di calcetto inter-classe...",
  "event_date": "2025-02-15T14:30:00Z",
  "location": "Campo sportivo dietro la scuola",
  "image_url": "https://...",
  "creator_id": "user-uuid",
  "co_organizers": [],
  "status": "pending",
  "rejection_reason": null,
  "moderated_by": null,
  "moderated_at": null,
  "created_at": "2025-01-09T10:30:00Z",
  "updated_at": "2025-01-09T10:30:00Z"
}
```

**Errors**:
- `400 Bad Request`: Validation error (title too short, date in past, etc.)
- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: RLS policy violation (creator_id mismatch)

---

### 2. Get Approved Events (Feed)

**Endpoint**: `GET /events?status=eq.approved&order=event_date.asc`

**Purpose**: Fetch all approved events for public feed (sorted by event date)

**Request Headers**:
```
Authorization: Bearer {jwt_token}
```

**Query Parameters**:
- `status=eq.approved`: Filter only approved events
- `order=event_date.asc`: Sort by event date ascending (upcoming first)
- `select=*`: Return all columns (default)

**Response**: `200 OK`
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "Torneo di Calcetto",
    "description": "Torneo di calcetto inter-classe...",
    "event_date": "2025-02-15T14:30:00Z",
    "location": "Campo sportivo",
    "image_url": "https://...",
    "creator_id": "user-uuid",
    "co_organizers": ["co-org-uuid-1"],
    "status": "approved",
    "created_at": "2025-01-09T10:30:00Z"
  },
  ...
]
```

---

### 3. Get My Events (Student Profile)

**Endpoint**: `GET /events?creator_id=eq.{auth.uid()}`

**Purpose**: Fetch all events created by the logged-in user (FR-008)

**Request Headers**:
```
Authorization: Bearer {jwt_token}
```

**Response**: `200 OK`
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "Torneo di Calcetto",
    "status": "approved",
    ...
  },
  {
    "id": "660e8400-e29b-41d4-a716-446655440001",
    "title": "Gruppo Studio Matematica",
    "status": "pending",
    ...
  },
  {
    "id": "770e8400-e29b-41d4-a716-446655440002",
    "title": "Festa di Classe",
    "status": "rejected",
    "rejection_reason": "Descrizione troppo vaga, aggiungi dettagli su orario e luogo preciso",
    ...
  }
]
```

---

### 4. Get Moderation Queue (Moderator)

**Endpoint**: `GET /events?status=eq.pending&order=created_at.asc`

**Purpose**: Moderator fetches pending events (FIFO queue) (FR-013)

**Request Headers**:
```
Authorization: Bearer {jwt_token_moderator}
```

**Query Parameters**:
- `status=eq.pending`: Only pending events
- `order=created_at.asc`: Oldest first (FIFO)

**Response**: `200 OK`
```json
[
  {
    "id": "880e8400-e29b-41d4-a716-446655440003",
    "title": "Evento 1",
    "description": "...",
    "created_at": "2025-01-08T09:00:00Z",
    ...
  },
  {
    "id": "990e8400-e29b-41d4-a716-446655440004",
    "title": "Evento 2",
    "description": "...",
    "created_at": "2025-01-09T08:30:00Z",
    ...
  }
]
```

**RLS Enforcement**: Only users with `role='moderator'` in `raw_user_meta_data` can access pending events.

---

### 5. Approve Event (Moderator)

**Endpoint**: `PATCH /events?id=eq.{event_id}`

**Purpose**: Moderator approves a pending event (FR-015)

**Request Headers**:
```
Authorization: Bearer {jwt_token_moderator}
Content-Type: application/json
Prefer: return=representation
```

**Request Body**:
```json
{
  "status": "approved",
  "moderated_by": "{auth.uid()}",
  "moderated_at": "{now()}"
}
```

**Response**: `200 OK`
```json
{
  "id": "880e8400-e29b-41d4-a716-446655440003",
  "status": "approved",
  "moderated_by": "moderator-uuid",
  "moderated_at": "2025-01-09T11:00:00Z",
  ...
}
```

**Side Effects**:
- Database trigger `trigger_notify_event_approval` fires
- Notification inserted into `notifications` table
- Creator receives push notification via FCM (handled by Edge Function)

---

### 6. Reject Event (Moderator)

**Endpoint**: `PATCH /events?id=eq.{event_id}`

**Purpose**: Moderator rejects a pending event with reason (FR-016)

**Request Headers**:
```
Authorization: Bearer {jwt_token_moderator}
Content-Type: application/json
Prefer: return=representation
```

**Request Body**:
```json
{
  "status": "rejected",
  "rejection_reason": "Descrizione troppo vaga. Aggiungi dettagli su orario preciso e come partecipare.",
  "moderated_by": "{auth.uid()}",
  "moderated_at": "{now()}"
}
```

**Response**: `200 OK`
```json
{
  "id": "880e8400-e29b-41d4-a716-446655440003",
  "status": "rejected",
  "rejection_reason": "Descrizione troppo vaga...",
  "moderated_by": "moderator-uuid",
  "moderated_at": "2025-01-09T11:05:00Z",
  ...
}
```

**Validation**:
- `rejection_reason` must be at least 10 characters (enforced in Flutter app, not DB)

---

### 7. Update Event (Creator/Co-Organizer)

**Endpoint**: `PATCH /events?id=eq.{event_id}`

**Purpose**: Creator or co-organizer edits event details (FR-031)

**Request Headers**:
```
Authorization: Bearer {jwt_token}
Content-Type: application/json
Prefer: return=representation
```

**Request Body**:
```json
{
  "title": "Updated Title",
  "description": "Updated description with more details...",
  "event_date": "2025-02-16T15:00:00Z"
}
```

**Response**: `200 OK`

**Side Effects**:
- If event was `approved`, status automatically changes back to `pending` (FR-033)
- Database trigger `trigger_notify_event_modification` fires
- All co-organizers + creator receive notification (except the modifier)

**RLS Enforcement**: Only creator or co-organizers can edit. Non-moderators cannot change `status` field.

---

### 8. Add Co-Organizers (Creator)

**Endpoint**: `PATCH /events?id=eq.{event_id}`

**Purpose**: Creator adds co-organizers to event (FR-027, FR-028)

**Request Body**:
```json
{
  "co_organizers": ["user-uuid-1", "user-uuid-2", "user-uuid-3"]
}
```

**Response**: `200 OK`

**Validation**:
- Maximum 3 co-organizers (enforced in Flutter app)

**Side Effects**:
- Database trigger `trigger_notify_co_organizer_addition` fires
- Each new co-organizer receives notification

---

### 9. Get Notifications (User)

**Endpoint**: `GET /notifications?user_id=eq.{auth.uid()}&order=sent_at.desc`

**Purpose**: Fetch user's notifications (unread + read)

**Response**: `200 OK`
```json
[
  {
    "id": "notif-uuid-1",
    "user_id": "{auth.uid()}",
    "channel": "event_approved",
    "title": "Evento Approvato!",
    "body": "✅ Evento \"Torneo di Calcetto\" approvato!...",
    "event_id": "event-uuid",
    "sent_at": "2025-01-09T11:00:00Z",
    "read": false,
    "delivered": true
  },
  ...
]
```

---

### 10. Mark Notification as Read

**Endpoint**: `PATCH /notifications?id=eq.{notification_id}`

**Purpose**: User marks notification as read

**Request Body**:
```json
{
  "read": true
}
```

**Response**: `200 OK`

---

## Supabase Storage Endpoints

### Upload Event Image

**Endpoint**: `POST /storage/v1/object/event-images/{filename}`

**Purpose**: Upload compressed event image (FR-004)

**Request Headers**:
```
Authorization: Bearer {jwt_token}
Content-Type: image/webp (or image/jpeg)
```

**Request Body**: Binary image data (max 200KB)

**Response**: `200 OK`
```json
{
  "Key": "event-images/550e8400_{timestamp}.webp",
  "Id": "...",
  "path": "event-images/550e8400_{timestamp}.webp"
}
```

**Public URL**: `https://{project}.supabase.co/storage/v1/object/public/event-images/{filename}`

---

## Error Responses

**400 Bad Request** - Validation error
```json
{
  "code": "23514",
  "details": "new row for relation \"events\" violates check constraint \"events_title_check\"",
  "hint": null,
  "message": "Check constraint violation"
}
```

**401 Unauthorized** - Missing/invalid JWT
```json
{
  "message": "JWT token is missing or invalid"
}
```

**403 Forbidden** - RLS policy violation
```json
{
  "code": "42501",
  "details": null,
  "hint": null,
  "message": "new row violates row-level security policy for table \"events\""
}
```

---

## Rate Limiting

Supabase free tier limits:
- API requests: 500/second per project
- Database connections: 60 concurrent
- Storage uploads: 50MB/minute

---

## Summary

**Total Endpoints**: 10 (8 PostgREST + 2 Storage)
**Authentication**: All require Supabase Auth JWT
**RLS Enforcement**: Automatic via Supabase RLS policies
**Automatic Triggers**: 4 database functions for notifications
