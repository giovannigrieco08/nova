# API Contract: User Blocks

**Feature**: 015-ugc-safety
**Module**: Block System

## Overview

User blocking API for preventing unwanted interactions.

---

## Endpoints

### 1. Block User

**Method**: Supabase Table Insert
**Table**: `user_blocks`

```dart
final response = await supabase
    .from('user_blocks')
    .insert({
      'blocker_id': currentUserId,
      'blocked_id': targetUserId,
    })
    .select()
    .single();
```

**Request**:
| Field | Type | Required | Validation |
|-------|------|----------|------------|
| blocker_id | UUID | Yes | Must match auth.uid() |
| blocked_id | UUID | Yes | Must exist, cannot be self |

**Response** (201 Created):
```json
{
  "id": "uuid",
  "blocker_id": "uuid",
  "blocked_id": "uuid",
  "created_at": "2025-02-12T10:00:00Z",
  "moderator_notified": false
}
```

**Side Effects**:
- Trigger notifies all moderators
- Blocked user's content hidden from blocker's feed immediately

**Errors**:
| Code | Condition | Message |
|------|-----------|---------|
| 409 | Already blocked | "Utente già bloccato" |
| 400 | Self-block | "Non puoi bloccare te stesso" |
| 404 | User not found | "Utente non trovato" |

---

### 2. Unblock User

**Method**: Supabase Table Delete
**Table**: `user_blocks`

```dart
await supabase
    .from('user_blocks')
    .delete()
    .eq('blocker_id', currentUserId)
    .eq('blocked_id', targetUserId);
```

**Response** (204 No Content)

---

### 3. Get Blocked Users List

**Method**: Supabase Table Select with Join
**Table**: `user_blocks`

```dart
final blockedUsers = await supabase
    .from('user_blocks')
    .select('''
      id,
      blocked_id,
      created_at,
      blocked:profiles!blocked_id (
        user_id,
        full_name,
        username,
        avatar_url
      )
    ''')
    .eq('blocker_id', currentUserId)
    .order('created_at', ascending: false);
```

**Response** (200 OK):
```json
[
  {
    "id": "uuid",
    "blocked_id": "uuid",
    "created_at": "2025-02-12T10:00:00Z",
    "blocked": {
      "user_id": "uuid",
      "full_name": "Mario Rossi",
      "username": "mrossi",
      "avatar_url": "https://..."
    }
  }
]
```

---

### 4. Check If User Is Blocked

**Method**: Supabase RPC
**Function**: `is_user_blocked`

```dart
final isBlocked = await supabase.rpc('is_user_blocked', params: {
  'p_target_user_id': targetUserId,
});
```

**Parameters**:
| Name | Type | Required | Description |
|------|------|----------|-------------|
| p_target_user_id | UUID | Yes | User to check |

**Response**: `boolean` (true if current user has blocked target)

---

### 5. Check If Blocked By User

**Method**: Supabase RPC
**Function**: `is_blocked_by_user`

```dart
final isBlockedBy = await supabase.rpc('is_blocked_by_user', params: {
  'p_target_user_id': targetUserId,
});
```

**Parameters**:
| Name | Type | Required | Description |
|------|------|----------|-------------|
| p_target_user_id | UUID | Yes | User to check |

**Response**: `boolean` (true if target user has blocked current user)

---

## SQL Functions

### is_user_blocked

```sql
CREATE OR REPLACE FUNCTION is_user_blocked(p_target_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_blocks
    WHERE blocker_id = auth.uid()
    AND blocked_id = p_target_user_id
  );
$$;
```

### is_blocked_by_user

```sql
CREATE OR REPLACE FUNCTION is_blocked_by_user(p_target_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_blocks
    WHERE blocker_id = p_target_user_id
    AND blocked_id = auth.uid()
  );
$$;
```

---

## Feed Filtering Integration

All feed queries must filter blocked users. Example for events feed:

```dart
final events = await supabase
    .from('events')
    .select('*')
    .eq('status', 'approved')
    .not('creator_id', 'in', await _getBlockedUserIds());

// Helper method
Future<List<String>> _getBlockedUserIds() async {
  final blocks = await supabase
      .from('user_blocks')
      .select('blocked_id')
      .eq('blocker_id', currentUserId);
  return blocks.map((b) => b['blocked_id'] as String).toList();
}
```

**Alternative**: Server-side RLS policy modification (recommended for performance):

```sql
-- Example: Events visible excluding blocked users
CREATE POLICY "Events visible excluding blocked users"
ON events FOR SELECT
TO authenticated
USING (
  status = 'approved'
  AND NOT is_blocked_by(creator_id, auth.uid())
  AND NOT is_user_blocked(creator_id)
);
```

---

## Profile Visibility

When a blocked user tries to view blocker's profile:

```dart
// Check before loading profile
final canViewProfile = !await supabase.rpc('is_blocked_by_user', params: {
  'p_target_user_id': profileUserId,
});

if (!canViewProfile) {
  // Show "Profilo non disponibile" screen
}
```

---

## UI Integration Notes

1. Block button in profile overflow menu (⋮)
2. Confirmation dialog: "Bloccare @username?"
3. Immediate visual feedback: content disappears
4. Settings → "Utenti bloccati" → List with unblock option
5. Blocked user sees "Profilo non disponibile" when viewing blocker
6. No notification sent to blocked user
