// Repository: GDPRRepository
// Feature: 006-user-profile (User Story 3 - T056)
// Purpose: GDPR compliance operations (export, soft delete, reactivate)

import '../datasources/gdpr_export_datasource.dart';
import '../models/gdpr_export_model.dart';

/// GDPR repository for compliance operations
///
/// **GDPR Rights Implemented**:
/// - Article 15: Right to Access (exportUserData)
/// - Article 17: Right to Erasure (softDeleteAccount + 30-day grace period)
/// - Article 20: Right to Data Portability (exportUserData returns JSON)
/// - Article 16: Right to Rectification (via ProfileRepository.updateProfile)
///
/// **Usage**:
/// ```dart
/// final repository = GDPRRepository(datasource);
///
/// // GDPR Right to Access (Article 15)
/// final metadata = await repository.exportUserData(userId);
/// print('Download: ${metadata.downloadUrl}');
///
/// // GDPR Right to Erasure (Article 17)
/// await repository.softDeleteAccount(userId);
///
/// // Reactivate within 30 days
/// await repository.reactivateAccount(userId);
/// ```
class GDPRRepository {
  final GDPRExportDatasource _datasource;

  GDPRRepository(this._datasource);

  /// Export user data (GDPR Article 15: Right to Access)
  ///
  /// **Flow**:
  /// 1. Calls Supabase Edge Function `export-user-data`
  /// 2. Edge Function queries all user data from database
  /// 3. Edge Function generates JSON and uploads to Storage
  /// 4. Returns GDPRExportMetadata with signed download URL (24h expiry)
  ///
  /// **Success Criteria**:
  /// - Export generation <10 seconds (FR-049)
  /// - JSON includes: profile, events, participations, comments, chat (24h)
  /// - Download URL expires after 24h
  ///
  /// **Throws**: Exception if export generation fails
  Future<GDPRExportMetadata> exportUserData(String userId) async {
    return await _datasource.exportUserData(userId);
  }

  /// Soft delete account (GDPR Article 17: Right to Erasure)
  ///
  /// **Flow**:
  /// 1. Sets deleted_at = NOW() in profiles table
  /// 2. RLS policy "Public profiles are viewable by everyone" hides profile
  /// 3. User has 30-day grace period to reactivate
  /// 4. After 30 days, cron job hard-deletes account and avatar
  ///
  /// **Success Criteria**:
  /// - Profile immediately hidden to other users
  /// - User can still login and see reactivation banner
  /// - Soft delete reversible within 30 days
  ///
  /// **Throws**: Exception if update fails
  Future<void> softDeleteAccount(String userId) async {
    return await _datasource.softDeleteAccount(userId);
  }

  /// Reactivate soft-deleted account (undo deletion within 30 days)
  ///
  /// **Flow**:
  /// 1. Checks deleted_at is within 30 days
  /// 2. Sets deleted_at = NULL
  /// 3. Profile becomes visible again if profile_visible = true
  ///
  /// **Success Criteria**:
  /// - Reactivation only allowed within 30 days
  /// - Profile restored to previous state
  ///
  /// **Throws**: Exception if >30 days passed or reactivation fails
  Future<void> reactivateAccount(String userId) async {
    return await _datasource.reactivateAccount(userId);
  }
}
