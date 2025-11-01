# Quickstart: Profile Setup Implementation

**Feature**: 002-profile-setup | **Date**: 2025-11-01
**Purpose**: Integration scenarios, testing guidance, and developer onboarding for profile setup feature

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Integration Scenarios](#integration-scenarios)
4. [Testing Guide](#testing-guide)
5. [Common Pitfalls](#common-pitfalls)
6. [Debugging Tips](#debugging-tips)

---

## Prerequisites

### Required Tools

- **Flutter SDK**: 3.x+ (`flutter --version`)
- **Dart**: 3.x+ (bundled with Flutter)
- **Supabase CLI**: `npm install -g supabase` (for local development)
- **IDE**: VS Code with Flutter extension OR Android Studio with Flutter plugin
- **Devices**: iOS Simulator/Android Emulator OR physical device

### Required Accounts

- **Supabase Cloud**: Free tier account at [supabase.com](https://supabase.com)
- **@galileimoro.edu.it email**: For testing magic link authentication

### Required Knowledge

- Dart/Flutter basics (widgets, state management)
- Riverpod state management (providers, consumers)
- Async/await patterns in Dart
- REST API concepts (GET, POST, PATCH)

---

## Environment Setup

### Step 1: Install Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_riverpod: ^2.4.0
  riverpod_annotation: ^2.3.0

  # Backend Integration
  supabase_flutter: ^2.0.0

  # Image Handling
  image_picker: ^1.0.4
  image: ^4.0.0

  # UI Components
  shimmer: ^2.0.0

  # Offline Storage
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  path_provider: ^2.1.1

  # Network Monitoring
  connectivity_plus: ^5.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter

  # Code Generation
  riverpod_generator: ^2.3.0
  build_runner: ^2.4.0

  # Linting
  flutter_lints: ^3.0.0
```

Run:
```bash
flutter pub get
flutter pub run build_runner build
```

### Step 2: Configure Platform Permissions

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Nova needs access to your photo library to set your profile avatar.</string>
<key>NSCameraUsageDescription</key>
<string>Nova needs camera access to take your profile photo.</string>
```

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

### Step 3: Initialize Supabase

In `lib/main.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  await Hive.initFlutter();
  await Hive.openBox<ProfileModel>('profile');

  runApp(const ProviderScope(child: MyApp()));
}

final supabase = Supabase.instance.client;
```

### Step 4: Run Database Migration

1. Open Supabase Dashboard → SQL Editor
2. Paste migration script from `data-model.md` → Section "Migration Script"
3. Click "Run" to create `profiles` table, indexes, RLS policies, and functions

Verify:
```sql
SELECT * FROM profiles; -- Should return empty table
SELECT * FROM pg_policies WHERE tablename = 'profiles'; -- Should show 5 policies
```

### Step 5: Create Storage Bucket

1. Supabase Dashboard → Storage → Create Bucket
2. Name: `avatars`
3. Public: **No** (private bucket with RLS)
4. File size limit: 5MB
5. Allowed MIME types: `image/jpeg, image/png, image/webp`

---

## Integration Scenarios

### Scenario 1: First-Time Profile Setup (Happy Path)

**User Flow**:
1. User completes magic link authentication → Redirected to `/profile/setup`
2. Name field auto-populated from email (`giovanni.rossi@galileimoro.edu.it` → "Giovanni Rossi")
3. User selects class "3A Scientifico" from bottom sheet picker
4. User uploads avatar from gallery
5. User taps "Salva e inizia" → Profile saved → Redirected to Feed (replace navigation)

**Code Snippet**:

```dart
// lib/features/profile/presentation/screens/profile_setup_screen.dart
class ProfileSetupScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  String _fullName = '';
  String? _selectedClass;

  @override
  void initState() {
    super.initState();
    _autoPopulateName();
  }

  Future<void> _autoPopulateName() async {
    final email = supabase.auth.currentUser?.email ?? '';
    final parsedName = await supabase
        .rpc('parse_name_from_email', params: {'email': email});

    if (parsedName != null) {
      setState(() => _fullName = parsedName);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = supabase.auth.currentUser!.id;

    await supabase.from('profiles').insert({
      'user_id': userId,
      'full_name': _fullName.trim(),
      'class': _selectedClass,
    });

    // Navigate to Feed with replace (remove setup from stack)
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => FeedScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: _skipSetup,
            child: Text('Skip per ora'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            AvatarPicker(userId: supabase.auth.currentUser!.id),
            TextFormField(
              initialValue: _fullName,
              decoration: InputDecoration(labelText: 'Nome e Cognome'),
              validator: (val) => val!.length < 2 ? 'Inserisci nome valido' : null,
              onChanged: (val) => _fullName = val,
            ),
            ClassPicker(
              selectedClass: _selectedClass,
              onClassSelected: (className) => setState(() => _selectedClass = className),
            ),
            ElevatedButton(
              onPressed: _selectedClass != null ? _saveProfile : null,
              child: Text('Salva e inizia'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Scenario 2: Avatar Upload with Auto-Crop

**Code Snippet**:

```dart
// lib/features/profile/presentation/widgets/avatar_picker.dart
class AvatarPicker extends StatefulWidget {
  final String userId;
  const AvatarPicker({required this.userId});

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  String? _avatarUrl;
  bool _isUploading = false;

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      // Crop to square using `image` package
      final originalImage = img.decodeImage(await pickedFile.readAsBytes())!;
      final size = min(originalImage.width, originalImage.height);
      final croppedImage = img.copyCrop(
        originalImage,
        x: (originalImage.width - size) ~/ 2,
        y: (originalImage.height - size) ~/ 2,
        width: size,
        height: size,
      );

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final croppedFile = File('${tempDir.path}/avatar_cropped.jpg')
        ..writeAsBytesSync(img.encodeJpg(croppedImage, quality: 85));

      // Upload to Supabase Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${widget.userId}_$timestamp.jpg';
      final path = '/avatars/${widget.userId}/$fileName';

      await supabase.storage
          .from('avatars')
          .upload(path, croppedFile);

      // Generate signed URL (1-hour expiry)
      final signedUrl = await supabase.storage
          .from('avatars')
          .createSignedUrl(path, 3600);

      // Update profile
      await supabase
          .from('profiles')
          .update({'avatar_url': signedUrl})
          .eq('user_id', widget.userId);

      setState(() {
        _avatarUrl = signedUrl;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Avatar aggiornato ✓')),
      );
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore caricamento foto')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAvatarOptions(context),
      child: Stack(
        children: [
          if (_avatarUrl != null)
            CircleAvatar(
              radius: 75,
              backgroundImage: NetworkImage(_avatarUrl!),
            )
          else
            AvatarInitials(fullName: 'Giovanni Rossi'), // Colored initials fallback

          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: NovaColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Icon(Icons.camera_alt, size: 20, color: Colors.white),
            ),
          ),

          if (_isUploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  void _showAvatarOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Scatta foto'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadAvatar(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Scegli da galleria'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadAvatar(ImageSource.gallery);
              },
            ),
            if (_avatarUrl != null)
              ListTile(
                leading: Icon(Icons.delete),
                title: Text('Rimuovi foto'),
                onTap: () async {
                  Navigator.pop(context);
                  await supabase
                      .from('profiles')
                      .update({'avatar_url': null})
                      .eq('user_id', widget.userId);
                  setState(() => _avatarUrl = null);
                },
              ),
          ],
        ),
      ),
    );
  }
}
```

### Scenario 3: Auto-Save with Riverpod + Debouncing

**Code Snippet**:

```dart
// lib/features/profile/presentation/providers/profile_provider.dart
@riverpod
class ProfileNotifier extends _$ProfileNotifier {
  Timer? _debounceTimer;

  @override
  FutureOr<Profile> build() async {
    final userId = supabase.auth.currentUser!.id;
    final response = await supabase
        .from('profiles')
        .select()
        .eq('user_id', userId)
        .single();

    return Profile.fromJson(response);
  }

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
        final userId = supabase.auth.currentUser!.id;
        await supabase
            .from('profiles')
            .update({'bio': bio})
            .eq('user_id', userId);

        // Show success toast
        ref.read(toastProvider.notifier).show('Profilo aggiornato ✓');
      } catch (e) {
        // Rollback on error
        state = AsyncValue.error(e, StackTrace.current);
        ref.read(toastProvider.notifier).show('Errore nel salvataggio');
      }
    });
  }

  Future<void> updateClass(String className) async {
    // Instant save (no debounce)
    state.whenData((profile) {
      state = AsyncValue.data(profile.copyWith(className: className));
    });

    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase
          .from('profiles')
          .update({'class': className})
          .eq('user_id', userId);

      ref.read(toastProvider.notifier).show('Profilo aggiornato ✓');
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      ref.read(toastProvider.notifier).show('Errore nel salvataggio');
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
```

### Scenario 4: Offline Save with Sync

**Code Snippet**:

```dart
// lib/features/profile/data/repositories/profile_repository.dart
class ProfileRepository {
  final SupabaseClient _supabase;
  final Box<ProfileModel> _hiveBox;

  ProfileRepository(this._supabase, this._hiveBox);

  Future<void> updateProfile(Profile profile) async {
    // Check network connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none;

    if (isOnline) {
      try {
        // Try online save first
        await _supabase
            .from('profiles')
            .update(profile.toJson())
            .eq('user_id', profile.userId);

        // Save to local cache as backup
        await _hiveBox.put('currentUser', ProfileModel.fromProfile(profile));
      } catch (e) {
        // If online save fails, save locally
        await _saveLocally(profile);
        rethrow;
      }
    } else {
      // Offline mode: save locally
      await _saveLocally(profile);
      throw OfflineException('Profilo salvato offline, sincronizzazione in corso...');
    }
  }

  Future<void> _saveLocally(Profile profile) async {
    await _hiveBox.put('currentUser', ProfileModel.fromProfile(profile));
    await _hiveBox.put('pendingSync_${profile.userId}', ProfileModel.fromProfile(profile));
  }

  Future<void> syncPendingChanges() async {
    final pendingKeys = _hiveBox.keys.where((k) => k.toString().startsWith('pendingSync_'));

    for (final key in pendingKeys) {
      final profileModel = _hiveBox.get(key);
      if (profileModel == null) continue;

      try {
        await _supabase
            .from('profiles')
            .update(profileModel.toJson())
            .eq('user_id', profileModel.userId);

        await _hiveBox.delete(key); // Remove from pending queue
      } catch (e) {
        // Keep in queue, will retry next time
        print('Sync failed for $key: $e');
      }
    }
  }
}
```

---

## Testing Guide

### Unit Tests

**Test Name Resolution Functions**:

```dart
// test/features/profile/domain/avatar_initials_test.dart
void main() {
  group('AvatarInitialsGenerator', () {
    test('extracts initials from full name', () {
      expect(AvatarInitialsGenerator.getInitials('Giovanni Rossi'), 'GR');
      expect(AvatarInitialsGenerator.getInitials('Maria Bianchi'), 'MB');
      expect(AvatarInitialsGenerator.getInitials('Name'), 'N');
    });

    test('generates deterministic color from name', () {
      final color1 = AvatarInitialsGenerator.getColor('Giovanni Rossi');
      final color2 = AvatarInitialsGenerator.getColor('Giovanni Rossi');
      expect(color1, color2); // Same name → same color
    });

    test('different names get different colors', () {
      final colorG = AvatarInitialsGenerator.getColor('Giovanni Rossi');
      final colorM = AvatarInitialsGenerator.getColor('Maria Bianchi');
      expect(colorG, isNot(colorM)); // G vs M → different colors
    });
  });
}
```

### Widget Tests

**Test Profile Setup Screen**:

```dart
// test/features/profile/presentation/screens/profile_setup_screen_test.dart
void main() {
  testWidgets('disables save button when class not selected', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ProfileSetupScreen()));

    final saveButton = find.widgetWithText(ElevatedButton, 'Salva e inizia');
    expect(tester.widget<ElevatedButton>(saveButton).enabled, false);
  });

  testWidgets('enables save button after class selection', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ProfileSetupScreen()));

    // Open class picker
    await tester.tap(find.text('Seleziona classe'));
    await tester.pumpAndSettle();

    // Select a class
    await tester.tap(find.text('3A Scientifico'));
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(ElevatedButton, 'Salva e inizia');
    expect(tester.widget<ElevatedButton>(saveButton).enabled, true);
  });
}
```

### Integration Tests

**Test Complete Setup Flow**:

```dart
// integration_test/profile_setup_flow_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('complete profile setup flow', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MyApp()));

    // 1. User lands on setup screen
    expect(find.text('Seleziona classe'), findsOneWidget);

    // 2. Select class
    await tester.tap(find.text('Seleziona classe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3A Scientifico'));
    await tester.pumpAndSettle();

    // 3. Tap save
    await tester.tap(find.text('Salva e inizia'));
    await tester.pumpAndSettle();

    // 4. Verify redirected to Feed
    expect(find.byType(FeedScreen), findsOneWidget);

    // 5. Verify cannot go back to setup
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ProfileSetupScreen), findsNothing);
  });
}
```

---

## Common Pitfalls

### Pitfall 1: Hardcoded Values in UI

❌ **Bad**:
```dart
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Color(0xFF8B5CF6),
    borderRadius: BorderRadius.circular(12),
  ),
)
```

✅ **Good**:
```dart
Container(
  padding: EdgeInsets.all(NovaSpacing.l),
  decoration: BoxDecoration(
    color: NovaColors.primary,
    borderRadius: BorderRadius.circular(NovaRadius.s),
  ),
)
```

### Pitfall 2: Direct Supabase Calls from UI

❌ **Bad**:
```dart
class ProfileSetupScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final profile = supabase.from('profiles').select(); // ❌ Direct DB call
  }
}
```

✅ **Good**:
```dart
class ProfileSetupScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider); // ✅ Via Riverpod provider
  }
}
```

### Pitfall 3: Not Trimming User Input

❌ **Bad**:
```dart
await supabase.from('profiles').insert({'full_name': _nameController.text}); // ❌ Not trimmed
```

✅ **Good**:
```dart
await supabase.from('profiles').insert({'full_name': _nameController.text.trim()}); // ✅ Trimmed
```

### Pitfall 4: Forgetting to Cancel Timers

❌ **Bad**:
```dart
class ProfileNotifier extends StateNotifier<Profile> {
  Timer? _debounceTimer;

  void updateBio(String bio) {
    _debounceTimer = Timer(...);
  }
  // ❌ Timer not cancelled on dispose → memory leak
}
```

✅ **Good**:
```dart
@override
void dispose() {
  _debounceTimer?.cancel(); // ✅ Clean up timer
  super.dispose();
}
```

---

## Debugging Tips

### Tip 1: Verify RLS Policies

If you get 403 errors when accessing profiles:

```sql
-- Check if RLS is enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE tablename = 'profiles'; -- Should show rowsecurity = true

-- Check policies
SELECT *
FROM pg_policies
WHERE tablename = 'profiles'; -- Should show 5 policies

-- Test policy as current user
SELECT * FROM profiles WHERE user_id = auth.uid(); -- Should return your profile
```

### Tip 2: Debug Signed URL Expiry

If avatar images fail to load:

```dart
print('Avatar URL: $_avatarUrl');
print('Expiry: ${Uri.parse(_avatarUrl!).queryParameters['exp']}');

// If expired, regenerate:
final newSignedUrl = await supabase.storage
    .from('avatars')
    .createSignedUrl(path, 3600);
```

### Tip 3: Check Network Connectivity

If offline save not working:

```dart
final connectivity = await Connectivity().checkConnectivity();
print('Network status: $connectivity'); // none, mobile, wifi

// Listen to changes
Connectivity().onConnectivityChanged.listen((result) {
  if (result != ConnectivityResult.none) {
    profileRepository.syncPendingChanges();
  }
});
```

### Tip 4: Profile Flutter DevTools Timeline

If animations drop frames:

1. Open Flutter DevTools → Performance
2. Record timeline during bottom sheet animation
3. Look for red bars (dropped frames)
4. Check for expensive builds in widget tree

Target: **Sustained 60fps** (16ms per frame)

---

## Next Steps

After completing this quickstart:

1. **Proceed to `/speckit.tasks`** to generate implementation tasks
2. **Review**: [research.md](./research.md) for detailed technical decisions
3. **Reference**: [data-model.md](./data-model.md) for database schema
4. **API Docs**: [contracts/profile-api.openapi.yaml](./contracts/profile-api.openapi.yaml) for endpoint specs

---

**Quickstart Complete** - Ready for `/speckit.implement` execution.
