// Usecase: ExportUserData
// Feature: 006-user-profile (User Story 3 - T057)
// Purpose: GDPR Right to Access - triggers data export and returns download link

import '../../data/models/gdpr_export_model.dart';
import '../../data/repositories/gdpr_repository.dart';

/// Export user data usecase (GDPR Article 15: Right to Access)
///
/// **Flow**:
/// 1. User taps "Scarica i tuoi dati" in Settings → Privacy
/// 2. Shows loading "Generazione dati in corso..."
/// 3. Calls Supabase Edge Function `export-user-data`
/// 4. Edge Function generates JSON with all user data
/// 5. Shows notification with download link (24h expiry)
///
/// **Success Criteria**:
/// - Export generation <10 seconds (FR-049)
/// - JSON includes: profile, events, participations, comments, chat (24h)
/// - Download URL expires after 24h
///
/// **Usage**:
/// ```dart
/// final exportUserData = ref.read(exportUserDataUseCaseProvider);
/// final metadata = await exportUserData(userId);
///
/// // Show notification with download link
/// showNotification(
///   'Dati pronti! Scarica entro 24h',
///   downloadUrl: metadata.downloadUrl,
/// );
/// ```
class ExportUserData {
  final GDPRRepository _repository;

  ExportUserData(this._repository);

  /// Export user data and return download metadata
  ///
  /// **Input**: User ID (UUID)
  /// **Output**: GDPRExportMetadata (download URL with 24h expiry)
  ///
  /// **Throws**: Exception if export generation fails
  Future<GDPRExportMetadata> call(String userId) async {
    return await _repository.exportUserData(userId);
  }
}
