// Datasource: GDPRExportDatasource
// Feature: 006-user-profile (User Story 3 - T055)
// Purpose: GDPR export via Supabase Edge Function with polling

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gdpr_export_model.dart';

/// GDPR export remote datasource
///
/// **Flow**:
/// 1. Call Edge Function `export-user-data` with user_id
/// 2. Edge Function queries all user data (profile, events, participations, comments, chat 24h)
/// 3. Edge Function generates JSON and uploads to Storage bucket `gdpr-exports/{user_id}/{timestamp}.json`
/// 4. Edge Function returns GDPRExportMetadata with signed download URL (24h expiry)
/// 5. Client shows notification with download link
///
/// **Success Criteria**:
/// - Export generation <10 seconds (FR-049)
/// - Returns download URL with 24h expiry
/// - JSON includes all user data per GDPR Article 15
///
/// **Usage**:
/// ```dart
/// final datasource = GDPRExportDatasource(Supabase.instance.client);
/// final metadata = await datasource.exportUserData(userId);
/// print('Download: ${metadata.downloadUrl}');
/// ```
class GDPRExportDatasource {
  final SupabaseClient _client;

  GDPRExportDatasource(this._client);

  /// Export user data via Edge Function
  ///
  /// **Edge Function**: `export-user-data`
  /// **Input**: `{ user_id: UUID }`
  /// **Output**: GDPRExportMetadata (export_id, download_url, file_size, expires_at)
  ///
  /// **Success**: Export generated within 10 seconds (FR-049)
  /// **Error**: Throws if user not found or export generation fails
  Future<GDPRExportMetadata> exportUserData(String userId) async {
    try {
      // Call Edge Function export-user-data
      final response = await _client.functions.invoke(
        'export-user-data',
        body: {'user_id': userId},
      );

      // Check response status
      if (response.status != 200) {
        throw Exception(
            'Failed to export user data: ${response.status} ${response.data}');
      }

      // Parse GDPRExportMetadata from response
      final metadata = GDPRExportMetadata.fromJson(
        response.data as Map<String, dynamic>,
      );

      return metadata;
    } catch (e) {
      throw Exception('Error exporting user data: ${e.toString()}');
    }
  }

  /// Soft delete account (set deleted_at = NOW())
  ///
  /// **RLS Policy**: "Users can update own profile" (auth.uid() = user_id)
  /// **Grace Period**: 30 days before hard delete
  ///
  /// **Success**: Account soft-deleted (profile hidden to others)
  /// **Error**: Throws if update fails
  Future<void> softDeleteAccount(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('user_id', userId)
          .select();

      if (response.isEmpty) {
        throw Exception('Failed to soft delete account');
      }
    } catch (e) {
      throw Exception('Error soft deleting account: ${e.toString()}');
    }
  }

  /// Reactivate soft-deleted account (set deleted_at = NULL)
  ///
  /// **Condition**: deleted_at must be within 30 days
  /// **RLS Policy**: User can update own profile
  ///
  /// **Success**: Account reactivated (profile visible again if profile_visible=true)
  /// **Error**: Throws if reactivation fails or >30 days passed
  Future<void> reactivateAccount(String userId) async {
    try {
      // Check if deletion is within 30 days
      final profile = await _client
          .from('profiles')
          .select('deleted_at')
          .eq('user_id', userId)
          .single();

      if (profile['deleted_at'] == null) {
        throw Exception('Account is not deleted');
      }

      final deletedAt = DateTime.parse(profile['deleted_at']);
      final daysSinceDeletion = DateTime.now().difference(deletedAt).inDays;

      if (daysSinceDeletion > 30) {
        throw Exception(
            'Account deletion grace period expired (>30 days). Account will be hard-deleted.');
      }

      // Reactivate account
      final response = await _client
          .from('profiles')
          .update({'deleted_at': null})
          .eq('user_id', userId)
          .select();

      if (response.isEmpty) {
        throw Exception('Failed to reactivate account');
      }
    } catch (e) {
      throw Exception('Error reactivating account: ${e.toString()}');
    }
  }
}
