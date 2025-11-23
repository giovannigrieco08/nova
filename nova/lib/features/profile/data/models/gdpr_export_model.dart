// Model: GDPRExportModel
// Feature: 006-user-profile (User Story 3 - T054)
// Purpose: GDPR Right to Access - complete user data export (JSON schema)

import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/profile.dart';
import '../../../events/domain/entities/event.dart';
// TODO(007-event-comments): Re-enable when Participation entity is created
// import '../../../events/domain/entities/participation.dart';
// TODO(007-event-comments): Comment entity needs JSON serialization for GDPR export
// import '../../../comments/domain/entities/comment.dart';

part 'gdpr_export_model.freezed.dart';
part 'gdpr_export_model.g.dart';

/// GDPR export data model (GDPR Article 15: Right to Access)
///
/// **Export Schema**:
/// - export_version: Format version (currently "1.0")
/// - export_date: Timestamp when export was generated
/// - user_id: User's UUID
/// - profile: Complete profile data
/// - events_created: All events user created (all statuses)
/// - participations: All participations user made
/// - comments: All comments user posted
/// - chat_messages: Chat messages from last 24h (auto-delete policy)
///
/// **GDPR Compliance**:
/// - Generated via Supabase Edge Function (export-user-data)
/// - Stored in Storage bucket 'gdpr-exports/{user_id}/{timestamp}.json'
/// - Download link expires after 24h (signed URL)
/// - Export generation target: <10 seconds (FR-049)
///
/// **Usage**:
/// ```dart
/// // Generate export via Edge Function
/// final export = await gdprRepository.exportUserData(userId);
///
/// // Download JSON
/// final downloadUrl = export.downloadUrl; // Signed URL with 24h expiry
/// ```
@freezed
class GDPRExportModel with _$GDPRExportModel {
  const factory GDPRExportModel({
    required String exportVersion, // Format version (e.g., "1.0")
    required DateTime exportDate, // Timestamp of generation
    required String userId, // User's UUID
    required Profile profile, // Complete profile data
    required List<Event> eventsCreated, // All events created by user
    // TODO(007-event-comments): Re-enable when Participation entity is created
    // required List<Participation> participations, // All participations
    // TODO(007-event-comments): Comment entity needs JSON serialization
    // required List<Comment> comments, // All comments posted
    required List<Map<String, dynamic>> chatMessages, // Last 24h chat messages (auto-delete)
  }) = _GDPRExportModel;

  factory GDPRExportModel.fromJson(Map<String, dynamic> json) =>
      _$GDPRExportModelFromJson(json);
}

/// GDPR export metadata (returned by export-user-data Edge Function)
///
/// **Flow**:
/// 1. User taps "Scarica i tuoi dati" in Settings
/// 2. Client calls Edge Function export-user-data
/// 3. Edge Function queries all user data from database
/// 4. Edge Function generates JSON and uploads to Storage
/// 5. Edge Function returns GDPRExportMetadata with signed download URL
/// 6. Client shows notification with download link (24h expiry)
///
/// **Success Criteria**:
/// - Export generation <10 seconds (FR-049)
/// - Download URL expires after 24h
/// - JSON includes all user data (profile, events, comments, participations, chat 24h)
@freezed
class GDPRExportMetadata with _$GDPRExportMetadata {
  const factory GDPRExportMetadata({
    required String exportId, // Unique export ID (timestamp-based)
    required DateTime generatedAt, // When export was generated
    required String downloadUrl, // Signed URL (24h expiry)
    required int fileSizeBytes, // Size of JSON file
    required DateTime expiresAt, // Download URL expiration (generatedAt + 24h)
  }) = _GDPRExportMetadata;

  factory GDPRExportMetadata.fromJson(Map<String, dynamic> json) =>
      _$GDPRExportMetadataFromJson(json);
}
