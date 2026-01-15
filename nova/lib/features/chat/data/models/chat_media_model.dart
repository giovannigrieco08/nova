import 'package:nova/features/chat/domain/entities/chat_media_info.dart';

/// Data model for ChatMediaInfo with JSON serialization.
class ChatMediaModel {
  final String id;
  final String messageId;
  final String uploaderUserId;
  final String storagePath;
  final String mediaType;
  final int fileSizeBytes;
  final int maxViews;
  final int viewCount;
  final DateTime? viewedAt;
  final String? viewedByUserId;
  final DateTime? screenshotDetectedAt;
  final bool screenshotNotified;
  final DateTime expiresAt;
  final DateTime createdAt;
  final int? durationSeconds; // Duration in seconds for audio messages

  const ChatMediaModel({
    required this.id,
    required this.messageId,
    required this.uploaderUserId,
    required this.storagePath,
    required this.mediaType,
    required this.fileSizeBytes,
    this.maxViews = 1,
    this.viewCount = 0,
    this.viewedAt,
    this.viewedByUserId,
    this.screenshotDetectedAt,
    required this.screenshotNotified,
    required this.expiresAt,
    required this.createdAt,
    this.durationSeconds,
  });

  /// Create from Supabase JSON response
  factory ChatMediaModel.fromJson(Map<String, dynamic> json) {
    return ChatMediaModel(
      id: json['id'] as String,
      messageId: json['message_id'] as String,
      uploaderUserId: json['uploader_user_id'] as String,
      storagePath: json['storage_path'] as String,
      mediaType: json['media_type'] as String,
      fileSizeBytes: json['file_size_bytes'] as int,
      maxViews: json['max_views'] as int? ?? 1,
      viewCount: json['view_count'] as int? ?? 0,
      viewedAt: json['viewed_at'] != null
          ? DateTime.parse(json['viewed_at'] as String)
          : null,
      viewedByUserId: json['viewed_by_user_id'] as String?,
      screenshotDetectedAt: json['screenshot_detected_at'] != null
          ? DateTime.parse(json['screenshot_detected_at'] as String)
          : null,
      screenshotNotified: json['screenshot_notified'] as bool? ?? false,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      durationSeconds: json['duration_seconds'] as int?,
    );
  }

  /// Convert to JSON for insert
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'uploader_user_id': uploaderUserId,
      'storage_path': storagePath,
      'media_type': mediaType,
      'file_size_bytes': fileSizeBytes,
      'max_views': maxViews,
      'view_count': viewCount,
      'viewed_at': viewedAt?.toIso8601String(),
      'viewed_by_user_id': viewedByUserId,
      'screenshot_detected_at': screenshotDetectedAt?.toIso8601String(),
      'screenshot_notified': screenshotNotified,
      'expires_at': expiresAt.toIso8601String(),
    };
  }

  /// Create insert payload
  static Map<String, dynamic> toInsertJson({
    required String messageId,
    required String uploaderUserId,
    required String storagePath,
    required ChatMediaType mediaType,
    required int fileSizeBytes,
    int maxViews = 1,
    int? durationSeconds,
  }) {
    return {
      'message_id': messageId,
      'uploader_user_id': uploaderUserId,
      'storage_path': storagePath,
      'media_type': mediaType.value,
      'file_size_bytes': fileSizeBytes,
      'max_views': maxViews,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
    };
  }

  /// Convert to domain entity
  ChatMediaInfo toEntity() {
    return ChatMediaInfo(
      id: id,
      messageId: messageId,
      uploaderUserId: uploaderUserId,
      storagePath: storagePath,
      mediaType: ChatMediaType.fromValue(mediaType),
      fileSizeBytes: fileSizeBytes,
      maxViews: maxViews,
      viewCount: viewCount,
      viewedAt: viewedAt,
      viewedByUserId: viewedByUserId,
      screenshotDetected: screenshotDetectedAt != null,
      expiresAt: expiresAt,
      createdAt: createdAt,
      durationSeconds: durationSeconds,
    );
  }

  /// Create from domain entity
  factory ChatMediaModel.fromEntity(ChatMediaInfo entity) {
    return ChatMediaModel(
      id: entity.id,
      messageId: entity.messageId,
      uploaderUserId: entity.uploaderUserId,
      storagePath: entity.storagePath,
      mediaType: entity.mediaType.value,
      fileSizeBytes: entity.fileSizeBytes,
      maxViews: entity.maxViews,
      viewCount: entity.viewCount,
      viewedAt: entity.viewedAt,
      viewedByUserId: entity.viewedByUserId,
      screenshotDetectedAt: null,
      screenshotNotified: false,
      expiresAt: entity.expiresAt,
      createdAt: entity.createdAt,
      durationSeconds: entity.durationSeconds,
    );
  }
}
