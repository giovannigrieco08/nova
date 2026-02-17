# API Contract: Reports

**Feature**: 015-ugc-safety
**Module**: Report System

## Overview

Content reporting API for posts, comments, chat messages, and profiles.

---

## Endpoints

### 1. Create Report

**Method**: Supabase Table Insert
**Table**: `reports`

```dart
// Dart/Flutter usage
final response = await supabase
    .from('reports')
    .insert({
      'reporter_id': currentUserId,
      'content_type': 'comment',  // 'event' | 'comment' | 'chat_message' | 'profile'
      'content_id': contentId,
      'category': 'bullying',     // 'spam' | 'offensive_content' | 'bullying' | 'inappropriate' | 'other'
      'note': 'Descrizione opzionale',  // max 500 chars, nullable
    })
    .select()
    .single();
```

**Request**:
| Field | Type | Required | Validation |
|-------|------|----------|------------|
| reporter_id | UUID | Yes | Must match auth.uid() |
| content_type | String | Yes | Enum: event, comment, chat_message, profile |
| content_id | UUID | Yes | Must exist |
| category | String | Yes | Enum: spam, offensive_content, bullying, inappropriate, other |
| note | String | No | Max 500 characters |

**Response** (201 Created):
```json
{
  "id": "uuid",
  "reporter_id": "uuid",
  "content_type": "comment",
  "content_id": "uuid",
  "category": "bullying",
  "note": "Descrizione",
  "status": "pending",
  "created_at": "2025-02-12T10:00:00Z"
}
```

**Errors**:
| Code | Condition | Message |
|------|-----------|---------|
| 409 | Duplicate report | "Hai già segnalato questo contenuto" |
| 400 | Invalid category | "Categoria non valida" |
| 404 | Content not found | "Contenuto non trovato" |

---

### 2. Check If Already Reported

**Method**: Supabase RPC
**Function**: `has_user_reported`

```dart
final hasReported = await supabase.rpc('has_user_reported', params: {
  'p_content_type': 'comment',
  'p_content_id': contentId,
});
```

**Parameters**:
| Name | Type | Required | Description |
|------|------|----------|-------------|
| p_content_type | String | Yes | Content type |
| p_content_id | UUID | Yes | Content ID |

**Response**: `boolean`

---

### 3. Get User's Reports

**Method**: Supabase Table Select
**Table**: `reports`

```dart
final reports = await supabase
    .from('reports')
    .select('*')
    .eq('reporter_id', currentUserId)
    .order('created_at', ascending: false);
```

**Response** (200 OK):
```json
[
  {
    "id": "uuid",
    "content_type": "comment",
    "content_id": "uuid",
    "category": "bullying",
    "status": "reviewed",
    "action_taken": "content_removed",
    "created_at": "2025-02-12T10:00:00Z"
  }
]
```

---

## SQL Function: has_user_reported

```sql
CREATE OR REPLACE FUNCTION has_user_reported(
  p_content_type TEXT,
  p_content_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM reports
    WHERE reporter_id = auth.uid()
    AND content_type = p_content_type
    AND content_id = p_content_id
  );
$$;
```

---

## Report Categories

| Category | Display Text (IT) | Description |
|----------|-------------------|-------------|
| spam | Spam | Contenuto commerciale o ripetitivo |
| offensive_content | Contenuto offensivo | Linguaggio volgare o offensivo |
| bullying | Bullismo | Comportamento intimidatorio o molesto |
| inappropriate | Contenuto inappropriato | Non adatto all'ambiente scolastico |
| other | Altro | Motivo diverso (richiede nota) |

---

## UI Integration Notes

1. Report button available on all content via overflow menu (⋮)
2. Single tap → category selection sheet
3. Optional note field (textarea, max 500 chars)
4. Show confirmation dialog on success
5. Disable report button if `has_user_reported` returns true
6. Show "Già segnalato" indicator on reported content
