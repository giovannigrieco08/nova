# Research: Profile Banner

**Feature**: 014-profile-banner
**Date**: 2025-01-20

## Research Summary

This document consolidates findings from codebase exploration to inform the implementation plan.

---

## 1. Banner Upload Service Pattern

### Decision: Extend existing AvatarUploadService

**Rationale**: The existing `AvatarUploadService` provides a well-tested pattern for image upload that includes compression, storage management, and URL handling.

**Alternatives Considered**:
| Alternative | Why Rejected |
|-------------|--------------|
| Create separate BannerUploadService | Code duplication; same pattern needed |
| Generic ImageUploadService | Over-engineering for 2 use cases |

**Implementation Approach**:
- Add `uploadBanner()` method to existing service
- Use same Supabase Storage patterns
- Different bucket path: `banners/{userId}/` vs `avatars/{userId}/`
- Different image specs: 1200x400 JPEG vs 512x512 PNG

**Reference**: [avatar_upload_service.dart](../../nova/lib/features/profile/data/services/avatar_upload_service.dart)

---

## 2. Image Compression Strategy

### Decision: JPEG format at 80% quality, target <300KB

**Rationale**:
- Banners are larger (1200x400) than avatars (512x512)
- JPEG better for photographic content vs PNG for avatars
- 80% quality balances file size and visual quality
- <300KB aligns with constitution performance budget (500KB max for images)

**Alternatives Considered**:
| Alternative | Why Rejected |
|-------------|--------------|
| PNG format | Too large for 1200x400 (typically 500KB+) |
| WebP format | iOS compatibility concerns on older devices |
| 100% JPEG quality | Files >500KB, violates constitution |

**Technical Details**:
```
Input: Any image (JPEG, PNG, HEIC)
Output: 1200x400 JPEG, quality 80%, <300KB
Crop: Center-crop to 3:1 aspect ratio
```

---

## 3. Storage Bucket Strategy

### Decision: Use existing `avatars` bucket with subfolder pattern

**Rationale**:
- Simpler than creating new bucket
- Same RLS policies apply (user owns their files)
- Path structure: `banners/{userId}/{userId}_{timestamp}.jpg`

**Alternatives Considered**:
| Alternative | Why Rejected |
|-------------|--------------|
| New `banners` bucket | Requires Supabase dashboard config, additional RLS setup |
| Same folder as avatars | Harder to distinguish, cleanup complexity |

**Storage Path Pattern**:
```
avatars/
  {userId}/
    {userId}_{timestamp}.png     # Avatar
banners/
  {userId}/
    {userId}_{timestamp}.jpg     # Banner
```

**Note**: After review, a separate `banners` bucket is cleaner. Will create via migration.

---

## 4. Fallback Gradient Design

### Decision: Use existing `brandGradient` from NovaColors

**Rationale**:
- Consistent with Nova brand identity
- Already defined in design system
- Works in both light and dark mode

**Implementation**:
```dart
// From NovaColors
static const LinearGradient brandGradient = LinearGradient(
  colors: [gradientStart, gradientEnd],  // #833AB4 -> #FD1D1D
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
```

**Alternatives Considered**:
| Alternative | Why Rejected |
|-------------|--------------|
| Blurred avatar as fallback | Additional processing, complexity |
| Solid color | Less visually appealing |
| User-selectable gradient | Over-engineering for v1 |

---

## 5. Image Cropping Approach

### Decision: Use existing `image_cropper` package with 3:1 aspect ratio lock

**Rationale**:
- Package already in pubspec.yaml
- `AvatarCropper` widget exists as reference implementation
- Supports aspect ratio locking

**Reference**: [avatar_cropper.dart](../../nova/lib/features/profile/presentation/widgets/avatar_cropper.dart)

**Implementation**:
- Create `BannerCropper` widget mirroring `AvatarCropper`
- Lock aspect ratio to 3:1 (width:height)
- Use same UI patterns for consistency

---

## 6. Profile Model Extension

### Decision: Add `bannerUrl` field to Profile entity

**Rationale**:
- Mirrors `avatarUrl` pattern
- Nullable (null = show fallback)
- No separate Banner entity needed (simple URL reference)

**Changes Required**:
1. `Profile` entity (Freezed) - add `String? bannerUrl`
2. `ProfileModel` (Hive) - add field with HiveField annotation
3. Database migration - add `banner_url` column
4. Repository - include in update operations

**Reference**: [profile.dart](../../nova/lib/features/profile/domain/entities/profile.dart)

---

## 7. UI Integration Points

### Decision: Modify ProfileHeader widget with banner as background

**Layout Change**:
```
BEFORE:
┌────────────────────────────────┐
│ [Avatar 80px]  [Stats]         │
│ Name                           │
│ Class                          │
│ Bio                            │
└────────────────────────────────┘

AFTER:
┌────────────────────────────────┐
│ ┌─────────────────────────────┐│
│ │     BANNER (3:1 ratio)      ││
│ │                             ││
│ └─────────────────────────────┘│
│       [Avatar 80px]            │  <- overlapping banner bottom
│ Name                           │
│ [Stats]                        │
│ Bio                            │
└────────────────────────────────┘
```

**Reference**: [profile_header.dart](../../nova/lib/features/profile/presentation/widgets/profile_header.dart)

---

## 8. Edit Profile Integration

### Decision: Add banner picker above avatar in EditProfileScreen

**Rationale**:
- Logical visual flow (banner first, then avatar)
- Reuse same picker pattern (bottom sheet with camera/gallery options)

**Reference**: [edit_profile_screen.dart](../../nova/lib/features/profile/presentation/screens/edit_profile_screen.dart)

---

## 9. Performance Considerations

### Constitution Alignment:
| Metric | Requirement | Implementation |
|--------|-------------|----------------|
| Image size | <500KB | <300KB (banner JPEG) |
| Feed load | <1s cached | CachedNetworkImage handles |
| 60fps | Sustained | No heavy operations during scroll |

**Optimizations**:
- Use `CachedNetworkImage` for banner display
- Preload banner in list views if needed
- Compress during upload (not display)

---

## 10. Packages Confirmed Available

From pubspec.yaml:
- `image_picker: ^1.0.4` - Camera/gallery access
- `image: ^4.0.0` - Image manipulation
- `image_cropper: ^11.0.0` - Image cropping
- `cached_network_image` - Network image caching

No new dependencies required.

---

## Open Questions Resolved

| Question | Resolution |
|----------|------------|
| Storage bucket | Use `banners` bucket (new) |
| Fallback type | Brand gradient |
| Compression format | JPEG 80% |
| Target dimensions | 1200x400px |
| Min dimensions | 600x200px |

---

## Next Steps

1. Create database migration for `banner_url` column
2. Update Profile entity and model
3. Create BannerUploadService (or extend AvatarUploadService)
4. Create BannerCropper widget
5. Update ProfileHeader with banner display
6. Update EditProfileScreen with banner picker
