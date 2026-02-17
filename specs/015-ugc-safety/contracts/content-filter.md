# API Contract: Content Filter

**Feature**: 015-ugc-safety
**Module**: Content Filtering

## Overview

Automated content filtering for banned words and inappropriate language.

---

## Endpoints

### 1. Check Content

**Method**: Supabase RPC
**Function**: `check_content`

```dart
final result = await supabase.rpc('check_content', params: {
  'p_text': 'Testo da verificare',
});
```

**Parameters**:
| Name | Type | Required | Description |
|------|------|----------|-------------|
| p_text | string | Yes | Text to check |

**Response** (200 OK):
```json
{
  "allowed": false,
  "blocked": true,
  "matched_words": ["parola1", "parola2"],
  "severity": "block"
}
```

**Fields**:
| Field | Type | Description |
|-------|------|-------------|
| allowed | boolean | Content can be published |
| blocked | boolean | Content was blocked |
| matched_words | string[] | Words that triggered filter |
| severity | string | 'warning' or 'block' |

---

### 2. Get Banned Words (Moderators)

**Method**: Supabase Table Select
**Table**: `banned_words`

```dart
final words = await supabase
    .from('banned_words')
    .select('*')
    .is('deleted_at', null)
    .order('word');
```

**Response** (200 OK):
```json
[
  {
    "id": "uuid",
    "word": "example",
    "pattern_type": "contains",
    "severity": "block",
    "language": "it",
    "created_at": "2025-02-12T10:00:00Z"
  }
]
```

---

### 3. Add Banned Word (Moderators)

**Method**: Supabase Table Insert
**Table**: `banned_words`

```dart
await supabase.from('banned_words').insert({
  'word': 'nuovaparola',
  'pattern_type': 'contains',
  'severity': 'block',
  'language': 'it',
  'created_by': currentUserId,
});
```

**Request**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| word | string | Yes | Word or regex pattern |
| pattern_type | string | Yes | 'exact', 'contains', 'regex' |
| severity | string | Yes | 'warning', 'block' |
| language | string | No | ISO 639-1 code, default 'it' |
| created_by | UUID | Yes | Moderator ID |

---

### 4. Remove Banned Word (Moderators)

**Method**: Supabase Table Update (soft delete)
**Table**: `banned_words`

```dart
await supabase
    .from('banned_words')
    .update({'deleted_at': DateTime.now().toIso8601String()})
    .eq('id', wordId);
```

---

## SQL Functions

### check_content

```sql
CREATE OR REPLACE FUNCTION check_content(p_text TEXT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result JSONB := '{"allowed": true, "blocked": false, "matched_words": [], "severity": null}';
  banned_record RECORD;
  lower_text TEXT := LOWER(p_text);
  matched_words TEXT[] := ARRAY[]::TEXT[];
  max_severity TEXT := NULL;
  is_match BOOLEAN;
BEGIN
  FOR banned_record IN
    SELECT word, pattern_type, severity
    FROM banned_words
    WHERE deleted_at IS NULL
  LOOP
    is_match := FALSE;

    IF banned_record.pattern_type = 'exact' THEN
      -- Exact whole word match
      is_match := lower_text ~ ('\y' || LOWER(banned_record.word) || '\y');
    ELSIF banned_record.pattern_type = 'contains' THEN
      -- Substring match
      is_match := lower_text LIKE '%' || LOWER(banned_record.word) || '%';
    ELSIF banned_record.pattern_type = 'regex' THEN
      -- Regex match
      BEGIN
        is_match := lower_text ~ banned_record.word;
      EXCEPTION WHEN OTHERS THEN
        is_match := FALSE;  -- Invalid regex, skip
      END;
    END IF;

    IF is_match THEN
      matched_words := array_append(matched_words, banned_record.word);
      IF max_severity IS NULL OR banned_record.severity = 'block' THEN
        max_severity := banned_record.severity;
      END IF;
    END IF;
  END LOOP;

  IF array_length(matched_words, 1) > 0 THEN
    result := jsonb_build_object(
      'allowed', max_severity = 'warning',  -- Warnings allow but flag
      'blocked', max_severity = 'block',
      'matched_words', to_jsonb(matched_words),
      'severity', max_severity
    );
  END IF;

  RETURN result;
END;
$$;
```

---

## Client-Side Integration

### Pre-Submit Validation

```dart
class ContentFilterService {
  final SupabaseClient _supabase;

  Future<ContentCheckResult> checkContent(String text) async {
    final result = await _supabase.rpc('check_content', params: {
      'p_text': text,
    });

    return ContentCheckResult(
      allowed: result['allowed'] as bool,
      blocked: result['blocked'] as bool,
      matchedWords: List<String>.from(result['matched_words'] ?? []),
      severity: result['severity'] as String?,
    );
  }
}

class ContentCheckResult {
  final bool allowed;
  final bool blocked;
  final List<String> matchedWords;
  final String? severity;

  bool get isClean => allowed && !blocked;
}
```

### Usage in Text Input

```dart
class PostComposerController {
  final ContentFilterService _filter;

  Future<void> submitPost(String content) async {
    final check = await _filter.checkContent(content);

    if (check.blocked) {
      throw ContentBlockedException(
        message: 'Il contenuto contiene linguaggio non consentito',
        matchedWords: check.matchedWords,
      );
    }

    if (check.severity == 'warning') {
      // Log warning but allow
      _analytics.logContentWarning(check.matchedWords);
    }

    // Proceed with submission
    await _submitPost(content);
  }
}
```

### Real-Time Validation (Debounced)

```dart
class ContentTextField extends StatefulWidget {
  @override
  _ContentTextFieldState createState() => _ContentTextFieldState();
}

class _ContentTextFieldState extends State<ContentTextField> {
  final _debouncer = Debouncer(milliseconds: 500);
  String? _warningMessage;

  void _onTextChanged(String text) {
    _debouncer.run(() async {
      if (text.length < 5) return;

      final check = await _filter.checkContent(text);

      setState(() {
        if (check.blocked) {
          _warningMessage = 'Contenuto non consentito';
        } else if (check.severity == 'warning') {
          _warningMessage = 'Attenzione: linguaggio sensibile rilevato';
        } else {
          _warningMessage = null;
        }
      });
    });
  }
}
```

---

## Pattern Types

| Type | Description | Example |
|------|-------------|---------|
| `exact` | Whole word boundary match | "word" matches "this word here" but not "wording" |
| `contains` | Substring match | "word" matches "wording", "keyword" |
| `regex` | Regular expression | `st[u0]pid` matches "stupid" and "st0pid" |

---

## Severity Levels

| Level | Effect | Use Case |
|-------|--------|----------|
| `warning` | Allow but flag for review | Borderline words, context-dependent |
| `block` | Prevent publication | Slurs, explicit profanity |

---

## Initial Seed Data

Migration should seed from existing `contains_profanity()` function's word list:

```sql
-- Extract from existing function and insert
INSERT INTO banned_words (word, pattern_type, severity, language, created_by)
SELECT
  unnest(ARRAY[
    -- Italian profanity list (150+ words from existing function)
    'cazzo', 'merda', 'stronzo', ...
  ]),
  'exact',
  'block',
  'it',
  (SELECT user_id FROM user_roles WHERE role = 'admin' LIMIT 1);
```

---

## UI Integration Notes

### Post/Comment Composer

1. Real-time validation with 500ms debounce
2. Red underline on blocked words (if identifiable)
3. Warning banner for warnings
4. Submit button disabled when blocked

### Error Message

```dart
// When submission blocked
showSnackBar(
  message: 'Il contenuto contiene linguaggio non consentito. '
           'Modifica il testo e riprova.',
  action: SnackBarAction(
    label: 'Modifica',
    onPressed: () => _focusTextField(),
  ),
);
```

### Moderator Dashboard

1. Table of banned words with search
2. Add word form (word, type, severity)
3. Delete button (soft delete)
4. Import/export CSV functionality
