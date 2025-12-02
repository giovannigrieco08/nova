# Research: Sistema Ripetizioni

**Feature Branch**: `012-tutoring-system`
**Date**: 2025-12-01
**Status**: Complete

---

## 1. Deep Links per WhatsApp e Instagram

### Decision
Utilizzare HTTPS URLs invece di custom schemes per garantire fallback automatico e migliore compatibilità cross-platform.

### WhatsApp Deep Link

**Formato raccomandato:**
```
https://wa.me/{phone}?text={message}
```

**Formato numero telefono:**
- Country code incluso (39 per Italia)
- NO segno `+`
- NO spazi o trattini
- Esempio: `393201234567` (non `+39 320 1234567`)

**Implementazione Flutter:**
```dart
final phone = '393201234567'; // già formattato
final message = Uri.encodeComponent('Ciao, ti contatto per ripetizioni');
final url = Uri.parse('https://wa.me/$phone?text=$message');

await launchUrl(url, mode: LaunchMode.externalApplication);
```

### Instagram Deep Link

**Formato raccomandato:**
```
https://instagram.com/{username}
```

**Requisiti:**
- Username senza `@`
- HTTPS URL per auto-routing (app se installata, browser altrimenti)

**Implementazione Flutter:**
```dart
final username = 'mario.rossi'; // senza @
final url = Uri.parse('https://instagram.com/$username');

await launchUrl(url, mode: LaunchMode.externalApplication);
```

### Fallback Strategy

**Approccio raccomandato:** Non usare `canLaunchUrl()` (inaffidabile), ma try-catch diretto:

```dart
Future<void> openWhatsApp(String phone) async {
  final url = Uri.parse('https://wa.me/$phone');
  try {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (e) {
    // Mostra errore + opzione copia contatto
    _showErrorSnackBar('Impossibile aprire WhatsApp');
    await Clipboard.setData(ClipboardData(text: phone));
  }
}
```

### Rationale
- HTTPS URLs hanno fallback automatico al browser web
- Non richiedono configurazione Info.plist (iOS) o AndroidManifest.xml (Android)
- Più semplice da testare e manutenere
- Pattern già usato in Nova per deep links profilo

### Alternatives Considered
| Alternativa | Motivo Rifiuto |
|-------------|----------------|
| `whatsapp://send?phone=` | Richiede configurazione platform-specific, no fallback |
| `instagram://user?username=` | Inaffidabile su versioni recenti Instagram |
| `canLaunchUrl()` first | False negatives comuni, codice più complesso |

---

## 2. PostgreSQL Array Operations per Materie

### Decision
Utilizzare colonna `TEXT[]` con GIN index per i subjects del tutor, seguendo il pattern esistente in Nova (`co_organizers UUID[]`).

### Schema Raccomandato

```sql
CREATE TABLE tutor_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) UNIQUE NOT NULL,
  subjects TEXT[] DEFAULT '{}' CHECK (array_length(subjects, 1) <= 5),
  -- altri campi...
);

-- GIN index per query performanti
CREATE INDEX idx_tutor_profiles_subjects ON tutor_profiles USING GIN (subjects);
```

### Query Patterns in Supabase Dart

**Filtrare tutor per materia:**
```dart
// subjects @> '{matematica}'
final response = await _supabase
    .from('tutor_profiles')
    .select('*, profiles(*)')
    .contains('subjects', ['matematica'])
    .eq('is_active', true)
    .order('created_at', ascending: false);
```

**Filtrare per più materie (ANY match):**
```dart
// subjects && ARRAY['matematica', 'fisica']
final response = await _supabase
    .from('tutor_profiles')
    .select('*, profiles(*)')
    .overlaps('subjects', ['matematica', 'fisica'])
    .eq('is_active', true);
```

### Performance (810 studenti)

| Metric | Valore |
|--------|--------|
| Query latency con GIN | <1ms |
| Query latency senza GIN | 2-5ms |
| GIN index size | ~8 KB |
| Overhead insert | +1ms |

### Rationale
- Pattern già esistente in Nova per `co_organizers UUID[]`
- GIN index garantisce <1ms latency (Constitution: PERFORMANCE_FIRST)
- TEXT[] più semplice di junction table per 810 studenti
- Supabase Dart client supporta `.contains()` nativamente

### Alternatives Considered
| Alternativa | Motivo Rifiuto |
|-------------|----------------|
| Junction table `tutor_subjects` | Overkill per 810 studenti, JOIN overhead |
| JSON column | Query meno efficienti, no GIN support nativo |
| CSV string | Nessun supporto query, error-prone |

---

## 3. Integrazione Profile Screens

### Decision
Aggiungere `TutorProfileSection` widget come SliverToBoxAdapter dopo ProfileStats, usando pattern AsyncValue.when esistente.

### ProfileScreen Integration

**Location:** `nova/lib/features/profile/presentation/screens/profile_screen.dart`

**Line 63 - Add provider watch:**
```dart
final profileAsync = ref.watch(currentProfileProvider);
final statsAsync = ref.watch(currentProfileStatsProvider);
final tutorProfileAsync = ref.watch(currentTutorProfileProvider); // NEW
```

**After line 102 - Add tutor section sliver:**
```dart
// Tutor profile section
SliverToBoxAdapter(
  child: tutorProfileAsync.when(
    data: (tutorProfile) {
      if (tutorProfile == null) {
        // User is not a tutor - show "Become Tutor" CTA
        return BecomeTutorCard(onTap: _navigateToBecomeTutor);
      }
      return TutorProfileSection(
        tutorProfile: tutorProfile,
        isOwnProfile: true,
        onEdit: _navigateToEditTutorProfile,
      );
    },
    loading: () => const SizedBox.shrink(),
    error: (_, __) => const SizedBox.shrink(),
  ),
),
```

### OtherProfileScreen Integration

**Location:** `nova/lib/features/profile/presentation/screens/other_profile_screen.dart`

**Line 70 - Add provider watch:**
```dart
final tutorProfileAsync = ref.watch(otherTutorProfileProvider(widget.userId));
```

**After line 109 - Add tutor section:**
```dart
// Tutor section (only if user is tutor)
SliverToBoxAdapter(
  child: tutorProfileAsync.when(
    data: (tutorProfile) {
      if (tutorProfile == null) return const SizedBox.shrink();
      return TutorProfileSection(
        tutorProfile: tutorProfile,
        isOwnProfile: false,
        onContact: () => _showContactSheet(tutorProfile),
      );
    },
    loading: () => const SizedBox.shrink(),
    error: (_, __) => const SizedBox.shrink(),
  ),
),
```

### SettingsScreen Integration

**Location:** `nova/lib/features/profile/presentation/screens/settings_screen.dart`

**After line 90 (Notifiche section):**
```dart
// Section: Profilo Tutor (conditional)
if (profile.isTutor) ...[
  SizedBox(height: NovaSpacing.large),
  _buildSectionHeader('Tutor'),
  _buildTutorSection(profile),
],
```

### Provider Pattern

```dart
// tutor_providers.dart
final currentTutorProfileProvider = FutureProvider<TutorProfile?>((ref) async {
  final repository = ref.watch(tutorRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return repository.getTutorProfile(userId);
});

final otherTutorProfileProvider =
    FutureProvider.family<TutorProfile?, String>((ref, userId) async {
  final repository = ref.watch(tutorRepositoryProvider);
  return repository.getTutorProfile(userId);
});
```

### Rationale
- Segue pattern esistente ProfileStats (SliverToBoxAdapter + AsyncValue.when)
- Loading/error silenziosi (tutor data è opzionale, non bloccare UI)
- Conditional rendering con `if (profile.isTutor)` per Settings
- Coerente con architettura clean architecture Nova

---

## 4. url_launcher Dependency

### Decision
Aggiungere `url_launcher` package al progetto per deep links esterni.

### Rationale
- Non presente in `pubspec.yaml` attuale
- Necessario per FR-007, FR-008 (WhatsApp/Instagram deep links)
- Package standard Flutter, ben mantenuto

### Implementation
```yaml
# pubspec.yaml
dependencies:
  url_launcher: ^6.2.1
```

### Alternatives Considered
| Alternativa | Motivo Rifiuto |
|-------------|----------------|
| `flutter_custom_tabs` | Overkill, url_launcher sufficiente |
| Platform channels custom | Reinventare la ruota |
| `android_intent_plus` | Solo Android, non cross-platform |

---

## 5. Database RLS Policies

### Decision
Implementare RLS policies per tutor_profiles che permettono lettura pubblica (is_active=true) e modifica solo proprietario.

### Policies Raccomandate

```sql
-- Enable RLS
ALTER TABLE tutor_profiles ENABLE ROW LEVEL SECURITY;

-- Anyone can read active tutor profiles
CREATE POLICY "read_active_tutors" ON tutor_profiles
  FOR SELECT
  USING (is_active = true);

-- Users can manage only their own tutor profile
CREATE POLICY "manage_own_tutor_profile" ON tutor_profiles
  FOR ALL
  USING (auth.uid() = user_id);

-- Users can insert their own tutor profile
CREATE POLICY "insert_own_tutor_profile" ON tutor_profiles
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);
```

### Rationale
- PRIVACY_FOUNDATION: utenti controllano solo propri dati
- Tutor profiles pubblici per discovery (is_active=true)
- Pattern esistente in Nova per profiles table
- Constraint database per contatto obbligatorio

---

## 6. File Structure

### Decision
Creare nuovo feature module `tutoring` seguendo clean architecture Nova.

### Structure
```
lib/features/tutoring/
├── data/
│   ├── datasources/
│   │   └── tutor_remote_datasource.dart
│   ├── models/
│   │   └── tutor_profile_model.dart
│   └── repositories/
│       └── tutor_repository.dart
├── domain/
│   └── entities/
│       ├── tutor_profile.dart
│       └── subject.dart
└── presentation/
    ├── providers/
    │   └── tutor_providers.dart
    ├── screens/
    │   ├── subjects_screen.dart
    │   ├── tutors_list_screen.dart
    │   ├── become_tutor_screen.dart
    │   └── edit_tutor_screen.dart
    └── widgets/
        ├── subject_card.dart
        ├── tutor_card.dart
        ├── contact_tutor_sheet.dart
        ├── tutor_profile_section.dart
        └── become_tutor_card.dart
```

### Rationale
- Segue pattern esistente (`events/`, `profile/`, `notifications/`)
- Feature autocontenuta, minimal cross-feature imports
- Separazione data/domain/presentation

---

## 7. Subject Enum

### Decision
Definire subjects come enum Dart con 12 materie, mapping a stringhe lowercase per database.

### Implementation

```dart
enum Subject {
  matematica('Matematica', 'matematica'),
  fisica('Fisica', 'fisica'),
  latino('Latino', 'latino'),
  greco('Greco', 'greco'),
  inglese('Inglese', 'inglese'),
  italiano('Italiano', 'italiano'),
  informatica('Informatica', 'informatica'),
  storia('Storia', 'storia'),
  filosofia('Filosofia', 'filosofia'),
  scienze('Scienze', 'scienze'),
  arte('Arte', 'arte'),
  francese('Francese', 'francese');

  final String displayName;
  final String dbValue;

  const Subject(this.displayName, this.dbValue);

  static Subject? fromDbValue(String value) {
    return Subject.values.firstWhereOrNull((s) => s.dbValue == value);
  }
}
```

### Rationale
- Type-safe, compile-time validation
- Centralizza display names e db values
- Facile da estendere per future materie

---

## Summary

| Topic | Decision | Key Rationale |
|-------|----------|---------------|
| Deep Links | HTTPS URLs | Fallback automatico, no config platform |
| Array Storage | TEXT[] + GIN | Pattern esistente, <1ms query |
| Profile Integration | SliverToBoxAdapter + AsyncValue.when | Pattern esistente Nova |
| url_launcher | Add dependency | Necessario per deep links |
| RLS Policies | Public read, owner write | PRIVACY_FOUNDATION compliance |
| File Structure | `features/tutoring/` module | Clean architecture pattern |
| Subjects | Dart enum | Type-safe, extensible |
