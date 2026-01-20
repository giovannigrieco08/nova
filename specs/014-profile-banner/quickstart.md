# Quickstart: Profile Banner

**Feature**: 014-profile-banner
**Date**: 2025-01-20

## Prerequisites

- Flutter SDK 3.x+
- Supabase project configured
- Existing profile feature working

---

## Implementation Steps

### Step 1: Database Migration

Create `supabase/migrations/037_add_profile_banner.sql`:

```sql
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS banner_url TEXT NULL;
COMMENT ON COLUMN profiles.banner_url IS 'Profile banner image URL (3:1 aspect ratio)';
```

Run migration:
```bash
supabase db push
```

### Step 2: Create Banners Storage Bucket

In Supabase Dashboard:
1. Go to Storage
2. Create new bucket: `banners`
3. Set as Public
4. Add policies (see contracts/profile-api.md)

Or via migration in `037_add_profile_banner.sql`:
```sql
INSERT INTO storage.buckets (id, name, public)
VALUES ('banners', 'banners', true)
ON CONFLICT (id) DO NOTHING;
```

### Step 3: Update Profile Entity

In `lib/features/profile/domain/entities/profile.dart`:

```dart
@freezed
class Profile with _$Profile {
  const factory Profile({
    // ... existing fields ...
    String? bannerUrl,  // Add this field
    // ... existing fields ...
  }) = _Profile;
}
```

Run code generation:
```bash
cd nova && dart run build_runner build --delete-conflicting-outputs
```

### Step 4: Update ProfileModel

In `lib/features/profile/data/models/profile_model.dart`:

```dart
@HiveField(12)
@JsonKey(name: 'banner_url')
final String? bannerUrl;
```

Update constructor, copyWith, fromEntity, toEntity methods.

Run code generation again.

### Step 5: Create Banner Upload Service

Create `lib/features/profile/data/services/banner_upload_service.dart`:

```dart
class BannerUploadService {
  final SupabaseClient _supabase;

  Future<String> uploadBanner({
    required String userId,
    required File imageFile,
    Function(double)? onProgress,
  }) async {
    // 1. Compress to 1200x400 JPEG, <300KB
    // 2. Upload to banners/{userId}/{timestamp}.jpg
    // 3. Return public URL
  }

  Future<void> deleteBanner(String userId) async {
    // Delete all files in banners/{userId}/
  }
}
```

### Step 6: Create Banner Cropper Widget

Create `lib/features/profile/presentation/widgets/banner_cropper.dart`:

```dart
class BannerCropper {
  static Future<File?> show(BuildContext context, File imageFile) async {
    return ImageCropper().cropImage(
      sourcePath: imageFile.path,
      aspectRatio: CropAspectRatio(ratioX: 3, ratioY: 1),
      // ... styling options
    );
  }
}
```

### Step 7: Update Profile Header

In `lib/features/profile/presentation/widgets/profile_header.dart`:

```dart
Widget build(BuildContext context) {
  return Column(
    children: [
      // Banner section (NEW)
      _buildBanner(context),
      // Avatar (overlapping banner)
      Transform.translate(
        offset: Offset(0, -40),
        child: _buildAvatar(context),
      ),
      // Rest of header...
    ],
  );
}

Widget _buildBanner(BuildContext context) {
  return Container(
    height: 120,  // 360px width / 3:1 = 120px height
    decoration: BoxDecoration(
      gradient: profile.bannerUrl == null
          ? NovaColors.brandGradient
          : null,
      image: profile.bannerUrl != null
          ? DecorationImage(
              image: CachedNetworkImageProvider(profile.bannerUrl!),
              fit: BoxFit.cover,
            )
          : null,
    ),
  );
}
```

### Step 8: Update Edit Profile Screen

In `lib/features/profile/presentation/screens/edit_profile_screen.dart`:

Add banner picker above avatar section:

```dart
// Banner section
GestureDetector(
  onTap: _handleBannerPicker,
  child: Stack(
    children: [
      // Banner preview (gradient or image)
      _buildBannerPreview(),
      // Edit icon overlay
      Positioned(
        bottom: 8,
        right: 8,
        child: _buildEditIcon(),
      ),
    ],
  ),
),
```

### Step 9: Add Provider

In `lib/features/profile/presentation/providers/profile_provider.dart`:

```dart
final bannerUploadServiceProvider = Provider<BannerUploadService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return BannerUploadService(supabase);
});
```

---

## Testing

### Manual Testing Checklist

- [ ] Upload banner from gallery
- [ ] Upload banner from camera
- [ ] Preview shows correctly before save
- [ ] Banner displays in own profile
- [ ] Banner displays in other user profiles
- [ ] Remove banner shows fallback gradient
- [ ] Replace banner deletes old file
- [ ] Fallback gradient on network error
- [ ] Min dimension validation (600x200)
- [ ] Loading indicator during upload

### Unit Tests

```dart
// test/features/profile/data/services/banner_upload_service_test.dart
void main() {
  group('BannerUploadService', () {
    test('compresses image to <300KB', () async { ... });
    test('resizes to 1200x400', () async { ... });
    test('converts to JPEG', () async { ... });
    test('returns public URL', () async { ... });
  });
}
```

---

## Common Issues

### "Storage bucket not found"
- Ensure `banners` bucket exists in Supabase
- Check bucket is set to public

### "RLS policy violation"
- Ensure storage policies are configured
- Check user is authenticated

### "Image too large"
- Compression may fail for very large images
- Add pre-upload size check

### Banner not updating
- Clear CachedNetworkImage cache
- Invalidate profile provider

---

## Performance Notes

- Banner images cached by CachedNetworkImage
- Compression happens client-side (no server load)
- Use `fadeInDuration: Duration.zero` to avoid flash on cached images
