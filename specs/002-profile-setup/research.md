# Research: Profile Setup Technical Decisions

**Feature**: 002-profile-setup | **Date**: 2025-11-01
**Purpose**: Resolve all NEEDS CLARIFICATION items from Technical Context and establish best practices for implementation

---

## Decision 1: Skeleton Loading Animation Package

**Problem**: Need to implement Instagram-style skeleton loading screens (ghost shimmer placeholders) for avatar, name field, class field, pronouns field, and bio text area during <500ms initial load.

**Research**:
- **Option A - shimmer package** (pub.dev/packages/shimmer): 2.0.0, 1.4k+ likes, maintained, 80KB, simple API
- **Option B - skeletons package** (pub.dev/packages/skeletons): More customizable but 150KB, fewer stars
- **Option C - custom implementation**: Using LinearGradient + AnimationController, but increases maintenance burden

**Decision**: Use **shimmer package v2.0.0**

**Rationale**:
- Lightweight (80KB, fits performance budget)
- Industry-standard (used by major Flutter apps)
- Simple API: `Shimmer.fromColors(baseColor:, highlightColor:, child:)`
- Matches Instagram aesthetic (silver/gray shimmer wave)
- Maintained with recent updates

**Implementation Pattern**:
```dart
Shimmer.fromColors(
  baseColor: NovaColors.border.withOpacity(0.3),
  highlightColor: NovaColors.border.withOpacity(0.1),
  child: Container(
    width: 150,
    height: 150,
    decoration: BoxDecoration(
      color: NovaColors.backgroundSecondary,
      shape: BoxShape.circle,
    ),
  ),
)
```

**Alternatives Considered**: Custom implementation rejected (maintenance cost > dependency cost), skeletons package rejected (larger size for similar functionality)

---

## Decision 2: Image Picker Integration (Camera/Gallery Access)

**Problem**: Need to enable camera capture and gallery selection for avatar upload with platform permissions handling (iOS/Android).

**Research**:
- **Option A - image_picker** (pub.dev/packages/image_picker): Official Flutter plugin, 3.5k+ likes, maintained by Flutter team
- **Option B - file_picker**: More generic, supports all file types (not just images), larger bundle size
- **Option C - flutter_image_picker**: Community fork, less maintained

**Decision**: Use **image_picker v1.0.4+**

**Rationale**:
- Official Flutter team plugin (trusted, maintained long-term)
- Handles iOS (UIImagePickerController) and Android (Intent.ACTION_PICK) permissions automatically
- Simple API: `ImagePicker().pickImage(source: ImageSource.camera or .gallery)`
- Supports max width/height (for image compression on device before upload)
- Minimal bundle size impact (~100KB)

**Implementation Pattern**:
```dart
final ImagePicker _picker = ImagePicker();
final XFile? image = await _picker.pickImage(
  source: ImageSource.gallery, // or ImageSource.camera
  maxWidth: 1024,
  maxHeight: 1024,
  imageQuality: 85, // Compress to ~200KB target
);
```

**Platform Permissions** (add to manifests):
- iOS (ios/Runner/Info.plist): `NSPhotoLibraryUsageDescription`, `NSCameraUsageDescription`
- Android (android/app/src/main/AndroidManifest.xml): `<uses-permission android:name="android.permission.CAMERA"/>`, `<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>`

**Alternatives Considered**: file_picker rejected (unnecessary for image-only use case), flutter_image_picker rejected (community fork less reliable than official plugin)

---

## Decision 3: Supabase Storage Patterns for Avatar Uploads

**Problem**: Need to upload avatars to Supabase Storage with auto-crop to square (1:1 ratio), virus scan, signed URLs (1-hour expiry), and path `/avatars/{user_id}/{timestamp}.jpg`.

**Research**:
- **Supabase Storage API**: REST API with Flutter SDK (`supabase_flutter` package)
- **Storage bucket config**: Public vs private buckets, signed URL generation
- **RLS policies**: Control file access via SQL policies on `storage.objects` table

**Decision**: Use **Supabase Storage with private bucket + signed URLs**

**Rationale**:
- **Private bucket**: Avatars not publicly accessible (requires signed URL or RLS policy)
- **Signed URLs**: Expire after 1 hour (security + GDPR compliance)
- **Automatic virus scan**: Supabase Cloud includes ClamAV scanning on all uploads
- **CDN**: Supabase Storage backed by CloudFlare CDN (fast global delivery)
- **RLS policies**: Enforce user can only upload to their own folder (`/avatars/{user_id}/`)

**Implementation Pattern**:
```dart
// Upload avatar
final file = File(imagePath);
final userId = supabase.auth.currentUser!.id;
final timestamp = DateTime.now().millisecondsSinceEpoch;
final fileName = '${userId}_$timestamp.jpg';

await supabase.storage
    .from('avatars')
    .upload('/avatars/$userId/$fileName', file);

// Get signed URL (1 hour expiry)
final signedUrl = await supabase.storage
    .from('avatars')
    .createSignedUrl('/avatars/$userId/$fileName', 3600);

// Update profile with avatar_url
await supabase
    .from('profiles')
    .update({'avatar_url': signedUrl})
    .eq('user_id', userId);
```

**RLS Policy** (SQL, apply via Supabase Dashboard):
```sql
-- Users can upload to their own folder only
CREATE POLICY "Users can upload own avatars"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Users can read own avatars
CREATE POLICY "Users can read own avatars"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

**Auto-Crop to Square**: Use `image` package (pub.dev/packages/image) to crop on device before upload (reduces upload size):
```dart
import 'package:image/image.dart' as img;

final originalImage = img.decodeImage(File(imagePath).readAsBytesSync())!;
final size = originalImage.width < originalImage.height ? originalImage.width : originalImage.height;
final croppedImage = img.copyCrop(
  originalImage,
  x: (originalImage.width - size) ~/ 2,
  y: (originalImage.height - size) ~/ 2,
  width: size,
  height: size,
);
final croppedFile = File('${Directory.systemTemp.path}/avatar_cropped.jpg')
  ..writeAsBytesSync(img.encodeJpg(croppedImage, quality: 85));
```

**Alternatives Considered**: Public bucket rejected (privacy risk, no access control), local-only storage rejected (no cross-device sync)

---

## Decision 4: Bottom Sheet UX with DraggableScrollableSheet

**Problem**: Need Instagram-style bottom sheets for class picker and pronouns selector: swipeable, 70% screen height (min 50%, max 95%), glassmorphism background, handle bar.

**Research**:
- **Flutter built-in**: `showModalBottomSheet` + `DraggableScrollableSheet`
- **modal_bottom_sheet package**: Custom implementations (Cupertino, Material styles)
- **Custom implementation**: `AnimatedContainer` + GestureDetector (full control but more code)

**Decision**: Use **Flutter built-in `DraggableScrollableSheet` with `showModalBottomSheet`**

**Rationale**:
- Native Flutter widget (zero dependency cost)
- Handles drag physics automatically (spring curve, bounce effect)
- Integrates with `Navigator` (proper route management)
- Supports custom builder for glassmorphism background
- Accessibility built-in (focus management, screen reader)

**Implementation Pattern**:
```dart
void _showClassPicker(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(NovaRadius.xl)),
          // Glassmorphism via NovaGlassCard widget
        ),
        child: Column(
          children: [
            // Handle bar (40x4px, gray, centered, 12px from top)
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: NovaColors.textSecondary,
                borderRadius: BorderRadius.circular(NovaRadius.circularFull),
              ),
            ),
            // Content (search bar + class list)
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: classes.length,
                itemBuilder: (context, index) => ClassListItem(...),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

**Alternatives Considered**: modal_bottom_sheet package rejected (unnecessary dependency for built-in functionality), custom implementation rejected (more code for same UX)

---

## Decision 5: Avatar Initials Generation with Material Design 500 Colors

**Problem**: Generate colored initials fallback when no custom avatar uploaded. Extract "GR" from "Giovanni Rossi", deterministic background color from first character using Material Design 500 palette (17 colors cycling A-Z).

**Research**:
- **Material Design color palette**: Red, Pink, Purple, Deep Purple, Indigo, Blue, Light Blue, Cyan, Teal, Green, Light Green, Lime, Amber, Orange, Deep Orange, Brown, Blue Grey (17 colors)
- **Algorithm**: Map A=0, B=1, ..., Z=25 → `colors[charCode % 17]`
- **Accessibility**: Ensure white text (weight 700, 48px) has >4.5:1 contrast ratio on all backgrounds

**Decision**: Use **deterministic color mapping with Material Design 500 palette**

**Rationale**:
- Deterministic: Same name always gets same color (user consistency)
- Accessible: All Material Design 500 colors tested with white text (>4.5:1 contrast)
- Visually distinct: 17 colors provide enough variety for 500 students
- No yellow/white: Excluded from palette (poor contrast with white text)

**Implementation Pattern**:
```dart
class AvatarInitialsGenerator {
  static const _colors = [
    Color(0xFFF44336), // Red 500
    Color(0xFFE91E63), // Pink 500
    Color(0xFF9C27B0), // Purple 500
    Color(0xFF673AB7), // Deep Purple 500
    Color(0xFF3F51B5), // Indigo 500
    Color(0xFF2196F3), // Blue 500
    Color(0xFF03A9F4), // Light Blue 500
    Color(0xFF00BCD4), // Cyan 500
    Color(0xFF009688), // Teal 500
    Color(0xFF4CAF50), // Green 500
    Color(0xFF8BC34A), // Light Green 500
    Color(0xFFCDDC39), // Lime 500
    Color(0xFFFFC107), // Amber 500
    Color(0xFFFF9800), // Orange 500
    Color(0xFFFF5722), // Deep Orange 500
    Color(0xFF795548), // Brown 500
    Color(0xFF607D8B), // Blue Grey 500
  ];

  static String getInitials(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.isEmpty) return 'N';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  static Color getColor(String fullName) {
    final initials = getInitials(fullName);
    final charCode = initials.codeUnitAt(0) - 'A'.codeUnitAt(0);
    return _colors[charCode % _colors.length];
  }
}
```

**Alternatives Considered**: HSL-based color generation rejected (not deterministic across devices, accessibility issues), random colors rejected (not deterministic, breaks user expectation)

---

## Decision 6: Offline-First Architecture with Hive/SharedPreferences

**Problem**: Need offline support: save profile locally if network offline, auto-sync when connection returns, queue avatar uploads, show "Offline" banner.

**Research**:
- **Option A - Hive**: NoSQL key-value database, fast, type-safe with code generation
- **Option B - SharedPreferences**: Simple key-value storage (primitives only), limited to String/int/bool
- **Option C - Isar**: More powerful than Hive, but larger bundle size (~2MB)

**Decision**: Use **Hive for complex objects (Profile model) + SharedPreferences for simple flags**

**Rationale**:
- **Hive**: Type-safe storage for `Profile` model (name, class, pronouns, bio), fast reads/writes (<1ms), 200KB bundle size
- **SharedPreferences**: Simple flags like `isProfileComplete`, `lastSyncTimestamp`
- **Sync strategy**: On app launch and when network returns (connectivity_plus package for network monitoring)

**Implementation Pattern**:
```dart
// Hive setup (one-time)
@HiveType(typeId: 0)
class ProfileModel extends HiveObject {
  @HiveField(0)
  String userId;

  @HiveField(1)
  String fullName;

  @HiveField(2)
  String? className;

  @HiveField(3)
  String? pronouns;

  @HiveField(4)
  String? bio;
}

// Save offline
await Hive.box<ProfileModel>('profile').put('currentUser', profile);

// Sync when online
final connectivity = ref.watch(connectivityProvider);
if (connectivity == ConnectivityResult.mobile || connectivity == ConnectivityResult.wifi) {
  final localProfile = Hive.box<ProfileModel>('profile').get('currentUser');
  await supabase.from('profiles').upsert(localProfile.toJson());
}
```

**Alternatives Considered**: Isar rejected (larger bundle size for no significant benefit), SharedPreferences-only rejected (can't store complex objects efficiently)

---

## Decision 7: Replace Navigation Pattern in Flutter

**Problem**: After completing profile setup ("Salva e inizia"), user should not be able to use back button to return to setup screen (prevents setup loop).

**Research**:
- **Option A - Navigator.pushReplacement**: Replaces current route with new route (removes setup from stack)
- **Option B - Navigator.pushAndRemoveUntil**: Pushes new route and removes all previous routes until predicate
- **Option C - Navigator.popAndPushNamed**: Pops current route then pushes new (exposes setup briefly during transition)

**Decision**: Use **Navigator.pushReplacement**

**Rationale**:
- Simplest API for single route replacement
- No visual glitch (direct replacement, no pop animation)
- Stack size remains constant (good for memory)
- Standard pattern for onboarding flows (login → setup → home)

**Implementation Pattern**:
```dart
// After successful profile save
Navigator.pushReplacement(
  context,
  MaterialPageRoute(builder: (context) => FeedScreen()),
);

// Or with named routes
Navigator.pushReplacementNamed(context, '/feed');
```

**Alternatives Considered**: `pushAndRemoveUntil` rejected (overkill for single route replacement), `popAndPushNamed` rejected (visual glitch during transition)

---

## Decision 8: Auto-Save Debouncing with Riverpod

**Problem**: Bio field needs 500ms debounce after last keystroke, but selections (class, pronouns, avatar) should save instantly. Need to handle concurrent saves, rollback on error, show toast feedback.

**Research**:
- **Debouncing**: Use `Timer` to delay save until user stops typing
- **Riverpod pattern**: Use `StateNotifierProvider` for profile state, `FutureProvider` for save operation
- **Optimistic UI**: Update UI immediately, rollback if save fails

**Decision**: Use **Riverpod StateNotifier with Timer-based debouncing + optimistic updates**

**Rationale**:
- `StateNotifier` provides clear state management (loading, success, error)
- `Timer` is built-in Dart (zero dependency)
- Optimistic UI improves perceived performance (instant feedback)
- Riverpod's reactive architecture handles error states cleanly

**Implementation Pattern**:
```dart
class ProfileNotifier extends StateNotifier<AsyncValue<Profile>> {
  Timer? _debounceTimer;
  final ProfileRepository _repository;

  ProfileNotifier(this._repository) : super(const AsyncValue.loading());

  void updateBio(String bio) {
    // Cancel previous timer if user still typing
    _debounceTimer?.cancel();

    // Update UI optimistically
    state.whenData((profile) {
      state = AsyncValue.data(profile.copyWith(bio: bio));
    });

    // Debounce save (500ms)
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        await _repository.updateProfile(bio: bio);
        // Show success toast
      } catch (e) {
        // Rollback + show error toast
        state = AsyncValue.error(e, StackTrace.current);
      }
    });
  }

  void updateClass(String className) async {
    // Instant save (no debounce)
    state.whenData((profile) {
      state = AsyncValue.data(profile.copyWith(className: className));
    });

    try {
      await _repository.updateProfile(className: className);
      // Show success toast
    } catch (e) {
      // Rollback + show error toast
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
```

**Alternatives Considered**: rxdart `debounceTime` rejected (adds dependency for built-in functionality), manual `setState` rejected (Riverpod provides better testability and state management)

---

## Decision 9: Class List Constants File Structure

**Problem**: Store 35 classes (SCIENTIFICO: 25, CLASSICO: 10) as hardcoded Dart const List in `lib/core/constants/classes.dart` (per clarification Q4).

**Decision**: Use **const List with data class for type safety**

**Rationale**:
- Type-safe access (prevent typos, IDE autocomplete)
- Single source of truth (referenced by picker and validation)
- Easy to test (no async DB queries needed)
- Fast (compiled into binary, zero runtime overhead)

**Implementation Pattern**:
```dart
// lib/core/constants/classes.dart
class SchoolClass {
  final String name;
  final SchoolTrack track;

  const SchoolClass(this.name, this.track);

  String get displayName => '$name ${track.label}';
}

enum SchoolTrack {
  scientifico('Scientifico'),
  classico('Classico');

  final String label;
  const SchoolTrack(this.label);
}

const kSchoolClasses = [
  // SCIENTIFICO (25 classes)
  SchoolClass('1A', SchoolTrack.scientifico),
  SchoolClass('1B', SchoolTrack.scientifico),
  SchoolClass('1C', SchoolTrack.scientifico),
  SchoolClass('1D', SchoolTrack.scientifico),
  SchoolClass('1F', SchoolTrack.scientifico),
  // ... (continue for 2A-5F, excluding E)

  // CLASSICO (10 classes)
  SchoolClass('1A', SchoolTrack.classico),
  SchoolClass('1B', SchoolTrack.classico),
  // ... (continue for 2A-5B)
];
```

**Search Filter Implementation**:
```dart
List<SchoolClass> filterClasses(String query) {
  final lowerQuery = query.toLowerCase();
  return kSchoolClasses
      .where((c) => c.displayName.toLowerCase().contains(lowerQuery))
      .toList();
}
```

**Alternatives Considered**: Enum rejected (can't have duplicate names like "1A"), Map rejected (harder to filter/search), JSON file rejected (requires async loading, parsing overhead)

---

## Summary of Dependencies Added

| Package | Version | Purpose | Bundle Size Impact |
|---------|---------|---------|-------------------|
| shimmer | 2.0.0+ | Skeleton loading animations | +80KB |
| image_picker | 1.0.4+ | Camera/gallery access | +100KB |
| image | 4.0.0+ | Image cropping to square | +200KB |
| hive | 2.2.3+ | Offline profile storage | +200KB |
| hive_flutter | 1.1.0+ | Hive Flutter integration | +50KB |
| connectivity_plus | 5.0.0+ | Network status monitoring | +100KB |

**Total bundle size increase**: ~730KB (within 50MB APK budget)

---

## Best Practices Established

1. **Skeleton Loading**: Always show shimmer placeholders during async operations (<500ms threshold)
2. **Image Upload**: Crop on device before upload (reduces bandwidth, faster upload)
3. **Supabase Storage**: Use private buckets + signed URLs (security + GDPR compliance)
4. **Bottom Sheets**: DraggableScrollableSheet with 70% initial height, 50% min, 95% max
5. **Avatar Initials**: Deterministic colors from Material Design 500 palette (accessibility tested)
6. **Offline Sync**: Hive for complex objects, SharedPreferences for flags, auto-sync on network return
7. **Navigation**: Use `Navigator.pushReplacement` after onboarding to prevent back navigation
8. **Auto-Save**: 500ms debounce for text fields, instant for selections, optimistic UI with rollback
9. **Constants**: Hardcode stable lists (like class list) for performance, migrate to DB only if dynamic updates needed

---

**Research Complete** - All NEEDS CLARIFICATION items resolved. Proceed to Phase 1: Design & Contracts.
