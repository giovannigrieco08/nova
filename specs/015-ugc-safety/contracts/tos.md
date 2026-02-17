# API Contract: Terms of Service

**Feature**: 015-ugc-safety
**Module**: ToS Acceptance

## Overview

Terms of Service acceptance tracking and enforcement.

---

## Endpoints

### 1. Accept Terms of Service

**Method**: Supabase RPC
**Function**: `accept_tos`

```dart
await supabase.rpc('accept_tos', params: {
  'p_version': '1.0.0',
});
```

**Parameters**:
| Name | Type | Required | Description |
|------|------|----------|-------------|
| p_version | String | Yes | ToS version being accepted |

**Response** (200 OK):
```json
{
  "success": true,
  "accepted_version": "1.0.0",
  "accepted_at": "2025-02-12T10:00:00Z"
}
```

**Side Effects**:
- Updates `profiles.tos_accepted_version` and `profiles.tos_accepted_at`

---

### 2. Check ToS Acceptance Status

**Method**: Supabase RPC
**Function**: `get_tos_status`

```dart
final status = await supabase.rpc('get_tos_status');
```

**Response** (200 OK):
```json
{
  "has_accepted": true,
  "accepted_version": "1.0.0",
  "current_version": "1.0.0",
  "needs_reaccept": false,
  "accepted_at": "2025-02-12T10:00:00Z"
}
```

**Fields**:
| Field | Type | Description |
|-------|------|-------------|
| has_accepted | boolean | User has ever accepted ToS |
| accepted_version | string | Version user accepted (null if never) |
| current_version | string | Current ToS version required |
| needs_reaccept | boolean | True if current > accepted |
| accepted_at | timestamp | When accepted (null if never) |

---

### 3. Get Current ToS Document

**Method**: Supabase Storage
**Bucket**: `public`
**Path**: `legal/tos-{version}.md`

```dart
final tosUrl = supabase.storage
    .from('public')
    .getPublicUrl('legal/tos-1.0.0.md');
```

---

## SQL Functions

### accept_tos

```sql
CREATE OR REPLACE FUNCTION accept_tos(p_version TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE profiles
  SET
    tos_accepted_version = p_version,
    tos_accepted_at = NOW()
  WHERE user_id = auth.uid();

  RETURN jsonb_build_object(
    'success', TRUE,
    'accepted_version', p_version,
    'accepted_at', NOW()
  );
END;
$$;
```

### get_tos_status

```sql
CREATE OR REPLACE FUNCTION get_tos_status()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_tos_version TEXT := '1.0.0';  -- Update when ToS changes
  user_record RECORD;
BEGIN
  SELECT tos_accepted_version, tos_accepted_at
  INTO user_record
  FROM profiles
  WHERE user_id = auth.uid();

  RETURN jsonb_build_object(
    'has_accepted', user_record.tos_accepted_version IS NOT NULL,
    'accepted_version', user_record.tos_accepted_version,
    'current_version', current_tos_version,
    'needs_reaccept', COALESCE(user_record.tos_accepted_version, '0.0.0') < current_tos_version,
    'accepted_at', user_record.tos_accepted_at
  );
END;
$$;
```

---

## Content Creation Guard

Before any content creation, check ToS acceptance:

```dart
Future<bool> canCreateContent() async {
  final status = await supabase.rpc('get_tos_status');
  return status['has_accepted'] == true && status['needs_reaccept'] == false;
}

Future<void> createPost(PostData data) async {
  if (!await canCreateContent()) {
    // Navigate to ToS acceptance screen
    throw TosNotAcceptedException();
  }

  // Proceed with post creation
  await supabase.from('posts').insert(data);
}
```

---

## ToS Document Structure

Location: `supabase/storage/public/legal/tos-1.0.0.md`

Required sections:
1. Acceptance of Terms
2. User Conduct
3. **Zero Tolerance Policy** (Apple requirement)
4. Content Guidelines
5. Reporting and Moderation
6. Account Termination
7. Privacy
8. Contact Information

### Zero Tolerance Section (Required)

```markdown
## Tolleranza Zero per Contenuti Offensivi

Nova adotta una politica di tolleranza zero per:
- Bullismo e cyberbullismo
- Contenuti discriminatori
- Linguaggio d'odio
- Molestie sessuali
- Minacce di violenza

Le violazioni comportano:
1. Prima violazione: Avvertimento
2. Seconda violazione: Sospensione temporanea
3. Terza violazione: Ban permanente

I contenuti offensivi verranno rimossi entro 24 ore dalla segnalazione.
```

---

## Version Management

When updating ToS:

1. Create new document: `tos-1.1.0.md`
2. Update `CURRENT_TOS_VERSION` constant in:
   - `get_tos_status()` SQL function
   - Dart constant file
3. Deploy migration to update function
4. Users will be prompted to re-accept on next content creation attempt

---

## UI Integration Notes

1. **First Post Flow**:
   - User taps "Create Post"
   - Check `get_tos_status()`
   - If `needs_reaccept` or `!has_accepted`:
     - Show full ToS document (scrollable)
     - "Ho letto e accetto" button at bottom
     - On accept → `accept_tos()` → proceed to camera

2. **Version Update Flow**:
   - User opens app
   - Background check `get_tos_status()`
   - If `needs_reaccept`:
     - Show modal with changes summary
     - Link to full document
     - Accept button

3. **ToS Link in Settings**:
   - Settings → "Termini di Servizio"
   - View current ToS document
   - Show "Accettato il [date]" footer
