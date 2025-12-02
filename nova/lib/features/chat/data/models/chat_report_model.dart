import 'package:nova/features/chat/domain/entities/chat_report.dart';

/// Data model for ChatReport with JSON serialization.
class ChatReportModel {
  final String id;
  final String messageId;
  final String reporterUserId;
  final String reason;
  final String status;
  final String? reviewedByModeratorId;
  final DateTime? reviewedAt;
  final String? moderatorNotes;
  final DateTime createdAt;

  const ChatReportModel({
    required this.id,
    required this.messageId,
    required this.reporterUserId,
    required this.reason,
    required this.status,
    this.reviewedByModeratorId,
    this.reviewedAt,
    this.moderatorNotes,
    required this.createdAt,
  });

  /// Create from Supabase JSON response
  factory ChatReportModel.fromJson(Map<String, dynamic> json) {
    return ChatReportModel(
      id: json['id'] as String,
      messageId: json['message_id'] as String,
      reporterUserId: json['reporter_user_id'] as String,
      reason: json['reason'] as String,
      status: json['status'] as String? ?? 'pending',
      reviewedByModeratorId: json['reviewed_by_moderator_id'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      moderatorNotes: json['moderator_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert to JSON for insert
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'reporter_user_id': reporterUserId,
      'reason': reason,
      'status': status,
    };
  }

  /// Create insert payload
  static Map<String, dynamic> toInsertJson({
    required String messageId,
    required String reporterUserId,
    required ChatReportReason reason,
  }) {
    return {
      'message_id': messageId,
      'reporter_user_id': reporterUserId,
      'reason': reason.value,
    };
  }

  /// Convert to domain entity
  ChatReport toEntity() {
    return ChatReport(
      id: id,
      messageId: messageId,
      reporterUserId: reporterUserId,
      reason: ChatReportReason.fromValue(reason),
      status: ChatReportStatus.fromValue(status),
      reviewedByModeratorId: reviewedByModeratorId,
      reviewedAt: reviewedAt,
      moderatorNotes: moderatorNotes,
      createdAt: createdAt,
    );
  }

  /// Create from domain entity
  factory ChatReportModel.fromEntity(ChatReport entity) {
    return ChatReportModel(
      id: entity.id,
      messageId: entity.messageId,
      reporterUserId: entity.reporterUserId,
      reason: entity.reason.value,
      status: entity.status.value,
      reviewedByModeratorId: entity.reviewedByModeratorId,
      reviewedAt: entity.reviewedAt,
      moderatorNotes: entity.moderatorNotes,
      createdAt: entity.createdAt,
    );
  }
}
