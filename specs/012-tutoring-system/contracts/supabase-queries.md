# Supabase Query Contracts: Sistema Ripetizioni

**Feature Branch**: `012-tutoring-system`
**Date**: 2025-12-01

---

## Table: `tutor_profiles`

### Query: Get Tutors by Subject

**Use Case**: FR-002 - Lista tutor filtrata per materia

**Supabase Dart:**
```dart
final response = await supabase
    .from('tutor_profiles')
    .select('''
      *,
      profiles:user_id (
        full_name,
        avatar_url,
        class_year,
        username
      )
    ''')
    .contains('subjects', [subject])
    .eq('is_active', true)
    .order('rating', ascending: false)
    .order('created_at', ascending: false)
    .range(offset, offset + limit - 1);
```

**Expected Response:**
```json
[
  {
    "id": "uuid",
    "user_id": "uuid",
    "bio": "Studente di 4A, appassionato di matematica",
    "subjects": ["matematica", "fisica"],
    "price_per_hour": 15.0,
    "availability_days": ["monday", "wednesday", "friday"],
    "time_slot": "15:00-18:00",
    "whatsapp_phone": "393201234567",
    "instagram_username": "mario.rossi",
    "rating": 4.5,
    "total_reviews": 3,
    "is_active": true,
    "created_at": "2025-12-01T10:00:00Z",
    "updated_at": "2025-12-01T10:00:00Z",
    "profiles": {
      "full_name": "Mario Rossi",
      "avatar_url": "https://...",
      "class_year": "4A - Scientifico",
      "username": "mario.rossi"
    }
  }
]
```

---

### Query: Get User's Tutor Profile

**Use Case**: FR-021, FR-025 - Visualizza proprio profilo tutor

**Supabase Dart:**
```dart
final response = await supabase
    .from('tutor_profiles')
    .select()
    .eq('user_id', userId)
    .maybeSingle();
```

**Expected Response (if exists):**
```json
{
  "id": "uuid",
  "user_id": "uuid",
  "bio": "...",
  "subjects": ["matematica", "fisica"],
  "price_per_hour": 15.0,
  "availability_days": ["monday", "wednesday"],
  "time_slot": "15:00-18:00",
  "whatsapp_phone": "393201234567",
  "instagram_username": null,
  "rating": 0.0,
  "total_reviews": 0,
  "is_active": true,
  "created_at": "2025-12-01T10:00:00Z",
  "updated_at": "2025-12-01T10:00:00Z"
}
```

**Expected Response (if not exists):**
```json
null
```

---

### Query: Get Tutors with Filters

**Use Case**: FR-003 - Filtri classe, rating, prezzo

**Supabase Dart (Free tutors only):**
```dart
final response = await supabase
    .from('tutor_profiles')
    .select('*, profiles:user_id (full_name, avatar_url, class_year)')
    .contains('subjects', [subject])
    .eq('is_active', true)
    .eq('price_per_hour', 0)  // Free only
    .order('rating', ascending: false);
```

**Supabase Dart (By class):**
```dart
final response = await supabase
    .from('tutor_profiles')
    .select('*, profiles:user_id!inner (full_name, avatar_url, class_year)')
    .contains('subjects', [subject])
    .eq('is_active', true)
    .eq('profiles.class_year', '4A - Scientifico')
    .order('rating', ascending: false);
```

**Supabase Dart (By rating):**
```dart
final response = await supabase
    .from('tutor_profiles')
    .select('*, profiles:user_id (full_name, avatar_url, class_year)')
    .contains('subjects', [subject])
    .eq('is_active', true)
    .gte('rating', 4.0)  // Rating >= 4.0
    .order('rating', ascending: false);
```

---

### Mutation: Create Tutor Profile

**Use Case**: FR-011 to FR-017 - Form "Diventa Tutor"

**Supabase Dart:**
```dart
final response = await supabase
    .from('tutor_profiles')
    .insert({
      'user_id': userId,
      'bio': bio,
      'subjects': subjects,  // ['matematica', 'fisica']
      'price_per_hour': pricePerHour,
      'availability_days': availabilityDays,  // ['monday', 'wednesday']
      'time_slot': timeSlot,
      'whatsapp_phone': whatsappPhone,
      'instagram_username': instagramUsername,
    })
    .select()
    .single();
```

**Request Body:**
```json
{
  "user_id": "uuid-of-current-user",
  "bio": "Studente di 4A, amo insegnare",
  "subjects": ["matematica", "fisica"],
  "price_per_hour": 15.0,
  "availability_days": ["monday", "wednesday", "friday"],
  "time_slot": "15:00-18:00",
  "whatsapp_phone": "393201234567",
  "instagram_username": null
}
```

**Validation Errors:**
- `23505` - Duplicate: User already has tutor profile
- `23514` - Check constraint: Bio > 200 chars, subjects > 5, no contact method

---

### Mutation: Update Tutor Profile

**Use Case**: FR-018 - Modifica profilo tutor

**Supabase Dart:**
```dart
final response = await supabase
    .from('tutor_profiles')
    .update({
      'bio': bio,
      'subjects': subjects,
      'price_per_hour': pricePerHour,
      'availability_days': availabilityDays,
      'time_slot': timeSlot,
      'whatsapp_phone': whatsappPhone,
      'instagram_username': instagramUsername,
    })
    .eq('user_id', userId)
    .select()
    .single();
```

---

### Mutation: Deactivate Tutor Profile

**Use Case**: FR-019 - Disattiva profilo tutor

**Supabase Dart:**
```dart
final response = await supabase
    .from('tutor_profiles')
    .update({'is_active': false})
    .eq('user_id', userId)
    .select()
    .single();
```

---

### Mutation: Reactivate Tutor Profile

**Use Case**: FR-020 - Riattiva profilo tutor

**Supabase Dart:**
```dart
final response = await supabase
    .from('tutor_profiles')
    .update({'is_active': true})
    .eq('user_id', userId)
    .select()
    .single();
```

---

### Mutation: Delete Tutor Profile

**Use Case**: User removes tutor capability entirely

**Supabase Dart:**
```dart
await supabase
    .from('tutor_profiles')
    .delete()
    .eq('user_id', userId);
```

**Note:** Also cascades on user account deletion (ON DELETE CASCADE).

---

## Deep Link Contracts

### WhatsApp Deep Link

**Use Case**: FR-007 - Contatta tutor via WhatsApp

**Format:**
```
https://wa.me/{phone}?text={encoded_message}
```

**Example:**
```dart
final phone = '393201234567';  // No +, no spaces
final message = Uri.encodeComponent('Ciao, ti contatto per ripetizioni di matematica');
final url = 'https://wa.me/$phone?text=$message';
```

**Result URL:**
```
https://wa.me/393201234567?text=Ciao%2C%20ti%20contatto%20per%20ripetizioni%20di%20matematica
```

---

### Instagram Deep Link

**Use Case**: FR-008 - Contatta tutor via Instagram

**Format:**
```
https://instagram.com/{username}
```

**Example:**
```dart
final username = 'mario.rossi';  // No @
final url = 'https://instagram.com/$username';
```

**Result URL:**
```
https://instagram.com/mario.rossi
```

---

## Error Codes

| Code | Description | User Message |
|------|-------------|--------------|
| `23505` | Unique violation (user_id) | "Hai già un profilo tutor" |
| `23514` | Check constraint violation | Depends on constraint |
| `42501` | RLS policy violation | "Non autorizzato" |
| `PGRST116` | No rows returned | "Profilo non trovato" |
