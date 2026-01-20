# Implementation Plan: Profile Banner

**Branch**: `014-profile-banner` | **Date**: 2025-01-20 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/014-profile-banner/spec.md`

## Summary

Add customizable profile banner that displays behind the profile photo, similar to Twitter/X. Users can upload, crop (3:1 aspect ratio), preview, and save banner images. Fallback to brand gradient when no banner is set.

**Technical Approach**: Extend existing avatar upload patterns to support banners with different dimensions (1200x400 JPEG) and integrate into profile header UI.

## Technical Context

**Language/Version**: Dart 3.x (Flutter SDK 3.x+)
**Primary Dependencies**: flutter_riverpod, image_picker, image_cropper, image, cached_network_image, supabase_flutter
**Storage**: Supabase Storage (`banners` bucket) + PostgreSQL (profiles.banner_url)
**Testing**: flutter_test (unit), integration_test (widget)
**Target Platform**: iOS 15+, Android 6.0+
**Project Type**: Mobile (Flutter)
**Performance Goals**: 60fps scroll, <2s banner load, <300KB file size
**Constraints**: <300KB compressed banner, 3:1 aspect ratio, offline-capable (cached)
**Scale/Scope**: Single screen modification (profile), ~10 files changed

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Assessment |
|-----------|--------|------------|
| **ENGAGEMENT_FIRST** | PASS | Profile customization increases user investment and profile visits |
| **SCHOOL_IDENTITY** | PASS | Enhances personal expression within school context |
| **EPHEMERAL_CONTENT** | N/A | Profile data is permanent (not ephemeral) |
| **CAMERA_FIRST** | PASS | Supports camera as source for banner |
| **AMBASSADOR_GROWTH** | N/A | Not growth-related |
| **AD_SUPPORTED** | N/A | No ad implications |
| **PERFORMANCE_FIRST** | PASS | <300KB images, CachedNetworkImage, 60fps maintained |

**Performance Budget Compliance**:
| Metric | Constitution Limit | Implementation Target |
|--------|-------------------|----------------------|
| Image size | <500KB | <300KB (banner) |
| Load time | <1s cached | <2s (4G), instant cached |
| Frame rate | 60fps | 60fps (no heavy ops during scroll) |

**Result**: All applicable principles satisfied. No violations.

## Project Structure

### Documentation (this feature)

```text
specs/014-profile-banner/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Research findings
├── data-model.md        # Data model changes
├── quickstart.md        # Implementation guide
├── contracts/           # API contracts
│   └── profile-api.md
├── checklists/
│   └── requirements.md  # Quality checklist
└── tasks.md             # Task list (created by /speckit.tasks)
```

### Source Code (repository root)

```text
nova/lib/features/profile/
├── domain/
│   └── entities/
│       └── profile.dart              # Add bannerUrl field
├── data/
│   ├── models/
│   │   └── profile_model.dart        # Add bannerUrl field + HiveField
│   └── services/
│       ├── avatar_upload_service.dart  # Reference pattern
│       └── banner_upload_service.dart  # NEW: Banner upload logic
├── presentation/
│   ├── widgets/
│   │   ├── profile_header.dart       # Add banner display
│   │   ├── banner_cropper.dart       # NEW: 3:1 aspect ratio cropper
│   │   └── banner_picker_bottom_sheet.dart  # NEW: Camera/gallery picker
│   ├── screens/
│   │   └── edit_profile_screen.dart  # Add banner picker section
│   └── providers/
│       └── profile_provider.dart     # Add bannerUploadServiceProvider

supabase/migrations/
└── 037_add_profile_banner.sql        # NEW: Database migration

nova/test/features/profile/
└── data/services/
    └── banner_upload_service_test.dart  # NEW: Unit tests
```

**Structure Decision**: Mobile (Flutter) with feature-first clean architecture. Extends existing `profile` feature module.

## Complexity Tracking

> No constitution violations. No complexity justification needed.

## Generated Artifacts

| Artifact | Path | Description |
|----------|------|-------------|
| Research | [research.md](./research.md) | Decision documentation |
| Data Model | [data-model.md](./data-model.md) | Schema changes |
| API Contract | [contracts/profile-api.md](./contracts/profile-api.md) | API extensions |
| Quickstart | [quickstart.md](./quickstart.md) | Implementation guide |

## Next Steps

1. Run `/speckit.tasks` to generate task list
2. Run `/speckit.implement` to execute implementation

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Large image uploads on slow network | Medium | Low | Progress indicator, compression feedback |
| Cropper UX inconsistency | Low | Low | Mirror existing AvatarCropper patterns |
| Cache invalidation issues | Medium | Medium | Clear both old and new URLs from cache |
