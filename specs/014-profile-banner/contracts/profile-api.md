# API Contract: Profile Banner

**Feature**: 014-profile-banner
**Date**: 2025-01-20

## Overview

This feature uses existing Supabase REST API patterns. No new endpoints are required.

---

## Existing Endpoints (Extended)

### GET /rest/v1/profiles

**Change**: Response now includes `banner_url` field

**Response Schema**:
```json
{
  "user_id": "uuid",
  "email": "string",
  "full_name": "string",
  "username": "string",
  "class": "string | null",
  "avatar_url": "string | null",
  "banner_url": "string | null",  // NEW
  "bio": "string | null",
  "role": "string",
  "profile_visible": "boolean",
  "created_at": "timestamp",
  "updated_at": "timestamp",
  "deleted_at": "timestamp | null"
}
```

---

### PATCH /rest/v1/profiles

**Change**: Request can include `banner_url` field

**Request Schema** (partial update):
```json
{
  "banner_url": "string | null"
}
```

**Use Cases**:
- Set banner: `{ "banner_url": "https://..." }`
- Remove banner: `{ "banner_url": null }`

---

## Storage API

### Upload Banner

**Endpoint**: `POST /storage/v1/object/banners/{userId}/{filename}`

**Headers**:
```
Authorization: Bearer {access_token}
Content-Type: image/jpeg
```

**Request Body**: Binary image data

**Response**:
```json
{
  "Key": "banners/{userId}/{filename}"
}
```

---

### Get Public URL

**Endpoint**: `GET /storage/v1/object/public/banners/{userId}/{filename}`

**Response**: Image binary (via CDN)

**URL Format**:
```
https://{project}.supabase.co/storage/v1/object/public/banners/{userId}/{filename}
```

---

### Delete Banner

**Endpoint**: `DELETE /storage/v1/object/banners/{userId}/{filename}`

**Headers**:
```
Authorization: Bearer {access_token}
```

**Response**: 200 OK

---

## Client-Side Service Interface

```dart
/// Banner upload service interface
abstract class BannerUploadService {
  /// Upload banner image to Supabase Storage
  /// Returns: Public URL for banner
  Future<String> uploadBanner({
    required String userId,
    required File imageFile,
    Function(double progress)? onProgress,
  });

  /// Delete all banners for user
  Future<void> deleteBanner(String userId);

  /// Normalize signed URL to public URL
  String normalizeBannerUrl(String? signedUrl);
}
```

---

## Error Responses

| Status | Error | Description |
|--------|-------|-------------|
| 400 | Invalid file type | Only JPEG/PNG allowed |
| 413 | Payload too large | File exceeds 1MB |
| 401 | Unauthorized | Invalid/expired token |
| 403 | Forbidden | RLS policy violation |
| 500 | Storage error | Supabase storage issue |

---

## RLS Policies

No new policies required. Existing profile policies apply:

```sql
-- Users can update their own profile (includes banner_url)
CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE USING (auth.uid() = user_id);
```

Storage bucket policies:
```sql
-- Users can upload to their own folder
CREATE POLICY "banners_insert_own" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'banners' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Users can delete their own files
CREATE POLICY "banners_delete_own" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'banners' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Anyone can read (public bucket)
CREATE POLICY "banners_select_public" ON storage.objects
  FOR SELECT USING (bucket_id = 'banners');
```
